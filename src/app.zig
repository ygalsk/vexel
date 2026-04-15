const std = @import("std");
const vaxis = @import("vaxis");
const lua_engine_mod = @import("lua_engine");
const lua_api = @import("lua_api");
const lua_bind = @import("lua_bind");
const Renderer = @import("renderer");
const ImageManager = @import("image");
const input_mod = @import("input");
const SceneManager = @import("scene");
const config = @import("config");
const AudioSystem = @import("audio").AudioSystem;
const TimerSystem = @import("timer").TimerSystem;
const SaveDb = if (config.has_db) @import("db").SaveDb else void;
const zlua = @import("zlua");
const ecs_world_mod = @import("ecs_world");
const EcsWorld = ecs_world_mod.World;
const AnimationEvent = ecs_world_mod.AnimationEvent;

const posix = std.posix;
const Winsize = vaxis.Winsize;
const IoWriter = std.io.Writer;

const Event = union(enum) {
    key_press: vaxis.Key,
    key_release: vaxis.Key,
    mouse: vaxis.Mouse,
    winsize: Winsize,
    focus_in,
    focus_out,
};

/// High-level application handle for Vexel library consumers.
///
/// Wraps all engine subsystem init, the main loop, and cleanup.
///
/// ```
/// var app = try vexel.App.init(allocator, .{ .project_dir = "." });
/// defer app.deinit();
/// app.registerModule("mymod", MyModule);
/// try app.run();
/// ```
pub const App = struct {
    allocator: std.mem.Allocator,

    tty: vaxis.Tty,
    tty_buf: [4096]u8,
    vx: vaxis.Vaxis,
    loop: vaxis.Loop(Event),

    renderer: Renderer,
    image_mgr: ImageManager,
    input_state: input_mod.InputState,
    audio_system: AudioSystem,
    lua_eng: lua_engine_mod,
    scene_mgr: SceneManager,
    timer_system: TimerSystem,
    save_db: if (config.has_db) SaveDb else void,
    ecs_world: EcsWorld,
    project_dir: []const u8,

    // Error overlay state
    error_msg_buf: [512]u8 = undefined,
    error_msg_len: usize = 0,
    error_display_timer: f64 = 0,

    pub const Options = struct {
        project_dir: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator, opts: Options) !*App {
        var self = try allocator.create(App);
        errdefer allocator.destroy(self);

        self.allocator = allocator;
        self.tty_buf = undefined;

        self.tty = try vaxis.Tty.init(&self.tty_buf);
        errdefer self.tty.deinit();

        self.vx = try vaxis.init(allocator, .{
            .kitty_keyboard_flags = .{
                .report_events = true,
            },
        });
        errdefer self.vx.deinit(allocator, self.tty.writer());

        const writer = self.tty.writer();

        // Probe transport before event loop starts
        const transport = Renderer.probeTransport(self.tty.fd, writer);

        self.loop = .{ .tty = &self.tty, .vaxis = &self.vx };
        try self.loop.init();
        try self.loop.start();

        try self.vx.enterAltScreen(writer);
        try self.vx.setMouseMode(writer, true);

        self.vx.queryTerminal(writer, 1_000_000_000) catch {
            stderrPrint("Warning: terminal query timed out, using defaults\n", .{});
        };

        const winsize = vaxis.Tty.getWinsize(self.tty.fd) catch |err| blk: {
            stderrPrint("Warning: could not get terminal size ({any}), using 80x24\n", .{err});
            break :blk Winsize{
                .rows = 24,
                .cols = 80,
                .x_pixel = 640,
                .y_pixel = 384,
            };
        };
        try self.vx.resize(allocator, writer, winsize);

        self.renderer = Renderer.init(&self.vx, winsize);
        self.renderer.initPixelMode(allocator, writer, transport) catch |err| {
            if (err == error.NoGraphicsCapability) {
                stderrPrint("Error: terminal does not support kitty graphics protocol\n", .{});
                std.process.exit(1);
            }
            return err;
        };

        self.image_mgr = ImageManager.init(allocator, opts.project_dir);
        self.renderer.setImageManager(&self.image_mgr);

        self.input_state = input_mod.InputState.init(allocator);

        self.audio_system = AudioSystem.init(allocator, opts.project_dir);
        if (!self.audio_system.available) {
            stderrPrint("Warning: audio device not available, audio disabled\n", .{});
        }

        self.lua_eng = try lua_engine_mod.init(allocator, opts.project_dir);

        self.scene_mgr = SceneManager.init(allocator, self.lua_eng.lua, &self.renderer);

        self.timer_system = TimerSystem.init(allocator, self.lua_eng.lua);

        self.save_db = if (config.has_db) SaveDb.init(allocator, opts.project_dir) else {};

        self.ecs_world = EcsWorld.init(allocator);
        self.project_dir = opts.project_dir;

        self.registerLuaApi();

        return self;
    }

    /// Register a Zig module's public functions as a Lua global table.
    /// Call this after init() but before run().
    pub fn registerModule(self: *App, comptime name: [:0]const u8, comptime Module: type) void {
        lua_bind.registerModule(self.lua_eng.lua, name, Module);
    }

    /// Register a pixel shader function for batch dispatch via pixel.shade().
    /// The function must be: fn(px: f64, py: f64, w: f64, h: f64, ...uniforms) i32
    pub fn registerPixelShader(self: *App, comptime name: [:0]const u8, comptime func: anytype) void {
        lua_bind.registerPixelShader(&self.renderer.shader_registry, name, func);
    }

    /// Register a simulation shader for serial whole-buffer dispatch via pixel.shade().
    /// The function must be: fn(buf: []u32, w: u16, h: u16, uniforms: []const f64) void
    pub fn registerSimulation(self: *App, comptime name: [:0]const u8, comptime func: fn ([]u32, u16, u16, []const f64) void) void {
        lua_bind.registerSimulation(&self.renderer.shader_registry, name, func);
    }

    /// Load the Lua project and run the main loop until quit.
    pub fn run(self: *App) !void {
        const writer = self.tty.writer();

        self.lua_eng.loadGame() catch |err| {
            self.fatalLuaError(writer, "loadGame", err);
        };

        self.lua_eng.callLoad() catch |err| {
            self.fatalLuaError(writer, "engine.load()", err);
        };

        self.renderer.sprite_mode = .placer;

        // Signal handlers
        const sa: posix.Sigaction = .{
            .handler = .{ .handler = signalHandler },
            .mask = posix.sigemptyset(),
            .flags = 0,
        };
        posix.sigaction(posix.SIG.INT, &sa, null);
        posix.sigaction(posix.SIG.TERM, &sa, null);

        var has_scenes = self.scene_mgr.hasScenes();

        var frame_arena = std.heap.ArenaAllocator.init(self.allocator);
        defer frame_arena.deinit();

        var timer = try std.time.Timer.start();
        var running = true;
        var resized = true;

        while (running) {
            if (g_signal_received_global.load(.acquire)) break;

            while (self.loop.tryEvent()) |event| {
                switch (event) {
                    .key_press => |key| {
                        if (key.mods.ctrl and (key.codepoint == 'c' or key.codepoint == 'q')) {
                            running = false;
                            break;
                        }
                        if (key.codepoint == vaxis.Key.f5) {
                            self.hotReload();
                            has_scenes = self.scene_mgr.hasScenes();
                            continue;
                        }
                        self.handleKey(key, .press, has_scenes);
                    },
                    .key_release => |key| {
                        self.handleKey(key, .release, has_scenes);
                    },
                    .mouse => |mouse| {
                        var ev = input_mod.translateMouse(mouse);
                        // Convert cell coords to virtual pixel coords
                        const res = self.renderer.pixelGetResolution();
                        const info = self.renderer.getScreenInfo();
                        if (info.cols > 0 and info.rows > 0) {
                            ev.x = @intCast(@divTrunc(@as(i64, ev.x) * @as(i64, res.w), @as(i64, info.cols)));
                            ev.y = @intCast(@divTrunc(@as(i64, ev.y) * @as(i64, res.h), @as(i64, info.rows)));
                        }
                        self.input_state.processMouseEvent(ev);
                        if (has_scenes) {
                            self.scene_mgr.onMouse(ev.x, ev.y, ev.button.name(), ev.action.name());
                        } else {
                            self.lua_eng.callOnMouse(ev.x, ev.y, ev.button.name(), ev.action.name()) catch |err| {
                                self.logLuaError("engine.on_mouse()", err);
                            };
                        }
                    },
                    .winsize => |ws| {
                        self.vx.resize(self.allocator, writer, ws) catch {};
                        self.renderer.updateSize(ws);
                        self.renderer.onResize();
                        resized = true;
                    },
                    .focus_in, .focus_out => {},
                }
            }

            if (!running or self.lua_eng.shouldQuit() or g_signal_received_global.load(.acquire)) break;

            const dt_ns = timer.lap();
            const dt: f64 = @as(f64, @floatFromInt(dt_ns)) / 1_000_000_000.0;

            if (has_scenes) {
                self.scene_mgr.update(dt);
            } else {
                self.lua_eng.callUpdate(dt) catch |err| {
                    self.logLuaError("engine.update()", err);
                };
            }
            self.timer_system.tick(dt);
            self.ecs_world.updateMovement(@floatCast(dt));

            _ = frame_arena.reset(.retain_capacity);
            const frame_alloc = frame_arena.allocator();

            var anim_events: std.ArrayList(AnimationEvent) = .{};
            self.ecs_world.tickAnimations(@floatCast(dt), frame_alloc, &anim_events);
            for (anim_events.items) |event| {
                if (event.on_complete_ref != ecs_world_mod.ref_none) {
                    _ = self.lua_eng.lua.rawGetIndex(zlua.registry_index, event.on_complete_ref);
                    self.lua_eng.lua.protectedCall(.{ .args = 0, .results = 0 }) catch {};
                }
            }

            self.renderer.clear();
            self.renderer.clearSprites();

            var sprite_entries: std.ArrayList(EcsWorld.SpriteRenderEntry) = .{};
            self.ecs_world.collectSprites(frame_alloc, &sprite_entries);
            std.sort.pdq(EcsWorld.SpriteRenderEntry, sprite_entries.items, {}, struct {
                fn lessThan(_: void, a: EcsWorld.SpriteRenderEntry, b: EcsWorld.SpriteRenderEntry) bool {
                    return a.layer < b.layer;
                }
            }.lessThan);
            for (sprite_entries.items) |entry| {
                self.renderer.pixelSetLayer(entry.layer);
                self.renderer.drawSprite(entry.image_handle, entry.x, entry.y, .{
                    .frame = entry.frame,
                    .flip_x = entry.flip_x,
                    .flip_y = entry.flip_y,
                    .scale = entry.scale,
                });
            }

            if (has_scenes) {
                self.scene_mgr.draw();
            } else {
                self.lua_eng.callDraw() catch |err| {
                    self.logLuaError("engine.draw()", err);
                };
            }

            self.renderer.flushPixels() catch {};

            // Error overlay (drawn after flush so it appears on top of everything)
            if (self.error_display_timer > 0) {
                self.error_display_timer -= dt;
                self.renderErrorOverlay();
            }

            if (self.renderer.isCellDirty() or resized) {
                try self.vx.render(writer);
            }

            self.renderer.placeCompositeImage();
            self.renderer.resetCellDirty();
            resized = false;

            const frame_ns: u64 = 16_666_667;
            const elapsed = timer.read();
            if (elapsed < frame_ns) {
                std.Thread.sleep(frame_ns - elapsed);
            }
        }

        self.lua_eng.callQuit() catch {};
    }

    pub fn deinit(self: *App) void {
        const allocator = self.allocator;
        const writer = self.tty.writer();

        self.ecs_world.deinit();
        if (config.has_db) self.save_db.deinit();
        self.timer_system.deinit();
        self.scene_mgr.deinit();
        self.lua_eng.deinit();
        self.audio_system.deinit();
        self.input_state.deinit();
        self.image_mgr.deinit();
        self.renderer.deinitPixelMode();
        self.loop.stop();
        self.vx.deinit(allocator, writer);
        self.tty.deinit();

        allocator.destroy(self);
    }

    fn hotReload(self: *App) void {
        self.audio_system.stopAll();

        self.ecs_world.deinit();
        self.timer_system.deinit();
        self.scene_mgr.deinit();
        self.lua_eng.deinit();
        self.input_state.reset();

        self.lua_eng = lua_engine_mod.init(self.allocator, self.project_dir) catch {
            self.setErrorOverlay("[reload] failed to init Lua VM");
            return;
        };
        self.scene_mgr = SceneManager.init(self.allocator, self.lua_eng.lua, &self.renderer);
        self.timer_system = TimerSystem.init(self.allocator, self.lua_eng.lua);
        self.ecs_world = EcsWorld.init(self.allocator);
        self.registerLuaApi();

        self.lua_eng.loadGame() catch |err| {
            self.logLuaError("reload.loadGame", err);
            return;
        };
        self.lua_eng.callLoad() catch |err| {
            self.logLuaError("reload.engine.load()", err);
            return;
        };

        self.error_display_timer = 0;
        self.error_msg_len = 0;
    }

    fn setErrorOverlay(self: *App, msg: []const u8) void {
        const len = @min(msg.len, self.error_msg_buf.len);
        @memcpy(self.error_msg_buf[0..len], msg[0..len]);
        self.error_msg_len = len;
        self.error_display_timer = 5.0;
    }

    fn registerLuaApi(self: *App) void {
        const audio_ptr: ?*AudioSystem = if (self.audio_system.available) &self.audio_system else null;
        lua_api.register(self.lua_eng.lua, .{
            .renderer = &self.renderer,
            .scene_mgr = &self.scene_mgr,
            .input_state = &self.input_state,
            .audio_system = audio_ptr,
            .timer_system = &self.timer_system,
            .save_db = if (config.has_db) &self.save_db else null,
            .world = &self.ecs_world,
        });
    }

    fn handleKey(self: *App, key: vaxis.Key, action: input_mod.KeyEvent.Action, has_scenes: bool) void {
        const ev = input_mod.translateKey(key, action);
        self.input_state.processKeyEvent(ev);
        if (has_scenes) {
            self.scene_mgr.onKey(ev.name, @tagName(ev.action));
        } else {
            self.lua_eng.callOnKey(ev.name, @tagName(ev.action)) catch |err| {
                self.logLuaError("engine.on_key()", err);
            };
        }
    }

    fn logLuaError(self: *App, comptime context: []const u8, err: anyerror) void {
        const msg = self.lua_eng.lua.toString(-1) catch "unknown error";
        stderrPrint("Lua error in {s}: {s} ({any})\n", .{ context, msg, err });
        self.lua_eng.lua.pop(1);

        // Store for on-screen overlay
        const prefix = "[Lua] " ++ context ++ ": ";
        const max_msg = self.error_msg_buf.len - prefix.len;
        const clamped = if (msg.len > max_msg) msg[0..max_msg] else msg;
        @memcpy(self.error_msg_buf[0..prefix.len], prefix);
        @memcpy(self.error_msg_buf[prefix.len..][0..clamped.len], clamped);
        self.error_msg_len = prefix.len + clamped.len;
        self.error_display_timer = 5.0;
    }

    fn renderErrorOverlay(self: *App) void {
        const text = self.error_msg_buf[0..self.error_msg_len];
        const cols = self.renderer.getScreenInfo().cols;
        const display_len = if (text.len > cols) cols else @as(u16, @intCast(text.len));
        self.renderer.drawText(0, 0, text[0..display_len], .{ .r = 255, .g = 60, .b = 60 }, .{ .r = 0, .g = 0, .b = 0 });
    }

    fn fatalLuaError(self: *App, writer: *IoWriter, comptime context: []const u8, err: anyerror) noreturn {
        self.vx.exitAltScreen(writer) catch {};
        const msg = self.lua_eng.lua.toString(-1) catch "unknown error";
        stderrPrint("Lua error in {s}: {s} ({any})\n", .{ context, msg, err });
        std.process.exit(1);
    }
};

// Signal handling — must be global for the C signal handler callback
var g_signal_received_global: std.atomic.Value(bool) = std.atomic.Value(bool).init(false);

fn signalHandler(_: c_int) callconv(.c) void {
    g_signal_received_global.store(true, .release);
}

fn stderrPrint(comptime fmt: []const u8, args: anytype) void {
    var buf: [1024]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch "vexel: error\n";
    std.fs.File.stderr().writeAll(msg) catch {};
}
