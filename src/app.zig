const std = @import("std");
const vaxis = @import("vaxis");
const lua_engine_mod = @import("lua_engine");
const lua_api = @import("lua_api");
const lua_bind = @import("lua_bind");
const Kitty = @import("kitty");
const Compositing = @import("compositing");
const SpritePlacer = @import("sprite_placer");
const ImageManager = @import("image");
const input_mod = @import("input");
const AudioSystem = @import("audio").AudioSystem;
const SaveFs = @import("save").SaveFs;

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

    kitty: *Kitty,
    compositor: *Compositing,
    sprite_placer: *SpritePlacer,
    image_mgr: ImageManager,
    screen_info: SpritePlacer.ScreenInfo,
    sprite_mode: SpritePlacer.SpriteMode,
    shader_registry: lua_bind.ShaderRegistry,
    cell_dirty: bool,
    cell_ctx: lua_api.CellContext,

    input_state: input_mod.InputState,
    audio_system: AudioSystem,
    lua_eng: lua_engine_mod,
    save_fs: SaveFs,
    project_dir: []const u8,

    // Error overlay state
    error_msg_buf: [512]u8 = undefined,
    error_msg_len: usize = 0,
    error_display_timer: f64 = 0,

    // FPS overlay state
    show_fps: bool = false,
    fps_accum: f64 = 0,
    fps_frame_count: u32 = 0,
    fps_display: f64 = 0,
    fps_buf: [16]u8 = undefined,
    fps_buf_len: usize = 0,

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
        const transport = Kitty.probeTransport(self.tty.fd, writer);

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

        self.screen_info = .{
            .cols = winsize.cols,
            .rows = winsize.rows,
            .x_pixel = winsize.x_pixel,
            .y_pixel = winsize.y_pixel,
        };

        self.kitty = try allocator.create(Kitty);
        self.kitty.* = Kitty.init(allocator, &self.vx, writer, transport) catch |err| {
            if (err == error.NoGraphicsCapability) {
                stderrPrint("Error: terminal does not support kitty graphics protocol\n", .{});
                std.process.exit(1);
            }
            return err;
        };

        self.compositor = try allocator.create(Compositing);
        self.compositor.* = try Compositing.init(allocator, self.kitty, &self.vx);

        self.image_mgr = ImageManager.init(allocator, opts.project_dir, self.kitty);

        self.sprite_mode = .compositor;
        self.sprite_placer = try allocator.create(SpritePlacer);
        self.sprite_placer.* = SpritePlacer.init(
            allocator,
            &self.image_mgr,
            self.compositor,
            &self.screen_info,
            &self.sprite_mode,
        );

        self.shader_registry = .{};
        self.cell_dirty = false;
        self.cell_ctx = .{
            .vx = &self.vx,
            .screen_info = &self.screen_info,
            .cell_dirty = &self.cell_dirty,
        };

        self.input_state = input_mod.InputState.init(allocator);

        self.audio_system = AudioSystem.init(allocator, opts.project_dir);
        if (!self.audio_system.available) {
            stderrPrint("Warning: audio device not available, audio disabled\n", .{});
        }

        self.lua_eng = try lua_engine_mod.init(allocator, opts.project_dir);

        self.save_fs = SaveFs.init(allocator, opts.project_dir);

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
        lua_bind.registerPixelShader(&self.shader_registry, name, func);
    }

    /// Register a simulation shader for serial whole-buffer dispatch via pixel.shade().
    /// The function must be: fn(buf: []u32, w: u16, h: u16, uniforms: []const f64) void
    pub fn registerSimulation(self: *App, comptime name: [:0]const u8, comptime func: fn ([]u32, u16, u16, []const f64) void) void {
        lua_bind.registerSimulation(&self.shader_registry, name, func);
    }

    /// Load the Lua project and run the main loop until quit.
    pub fn run(self: *App) !void {
        lua_bind.initPool();
        const writer = self.tty.writer();

        self.lua_eng.loadGame() catch |err| {
            self.fatalLuaError(writer, "loadGame", err);
        };

        self.lua_eng.callLoad() catch |err| {
            self.fatalLuaError(writer, "engine.load()", err);
        };

        self.sprite_mode = .placer;

        // Signal handlers
        const sa: posix.Sigaction = .{
            .handler = .{ .handler = signalHandler },
            .mask = posix.sigemptyset(),
            .flags = 0,
        };
        posix.sigaction(posix.SIG.INT, &sa, null);
        posix.sigaction(posix.SIG.TERM, &sa, null);

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
                            continue;
                        }
                        if (key.codepoint == vaxis.Key.f3) {
                            if (self.lua_eng.isDebugMode()) {
                                self.show_fps = !self.show_fps;
                            }
                            continue;
                        }
                        self.handleKey(key, .press);
                    },
                    .key_release => |key| {
                        self.handleKey(key, .release);
                    },
                    .mouse => |mouse| {
                        var ev = input_mod.translateMouse(mouse);
                        // Convert cell coords to virtual pixel coords
                        const res_w: i64 = self.compositor.width;
                        const res_h: i64 = self.compositor.height;
                        if (self.screen_info.cols > 0 and self.screen_info.rows > 0) {
                            ev.x = @intCast(@divTrunc(@as(i64, ev.x) * res_w, @as(i64, self.screen_info.cols)));
                            ev.y = @intCast(@divTrunc(@as(i64, ev.y) * res_h, @as(i64, self.screen_info.rows)));
                        }
                        self.input_state.processMouseEvent(ev);
                        self.lua_eng.callOnMouse(ev.x, ev.y, ev.button.name(), ev.action.name()) catch |err| {
                            self.logLuaError("engine.on_mouse()", err);
                        };
                    },
                    .winsize => |ws| {
                        self.vx.resize(self.allocator, writer, ws) catch {};
                        self.screen_info = .{
                            .cols = ws.cols,
                            .rows = ws.rows,
                            .x_pixel = ws.x_pixel,
                            .y_pixel = ws.y_pixel,
                        };
                        self.compositor.markAllDirty();
                        self.image_mgr.invalidateAllTerminal();
                        resized = true;
                    },
                    .focus_in, .focus_out => {},
                }
            }

            if (!running or self.lua_eng.shouldQuit() or g_signal_received_global.load(.acquire)) break;

            const dt_ns = timer.lap();
            const dt: f64 = @as(f64, @floatFromInt(dt_ns)) / 1_000_000_000.0;

            if (self.show_fps) {
                self.fps_frame_count += 1;
                self.fps_accum += dt;
                if (self.fps_accum >= 0.5) {
                    self.fps_display = @as(f64, @floatFromInt(self.fps_frame_count)) / self.fps_accum;
                    self.fps_frame_count = 0;
                    self.fps_accum = 0;
                    self.fps_buf_len = (std.fmt.bufPrint(&self.fps_buf, "FPS: {d:.0}", .{self.fps_display}) catch &.{}).len;
                }
            }

            self.lua_eng.callUpdate(dt) catch |err| {
                self.logLuaError("engine.update()", err);
            };

            self.cell_ctx.clear();
            self.sprite_placer.clear();

            self.lua_eng.callDraw() catch |err| {
                self.logLuaError("engine.draw()", err);
            };

            try self.compositor.flush();
            self.sprite_placer.flush(&self.vx);

            // Error overlay (drawn after flush so it appears on top of everything)
            if (self.error_display_timer > 0) {
                self.error_display_timer -= dt;
                self.renderErrorOverlay();
            }

            if (self.show_fps) {
                self.renderFpsOverlay();
            }

            if (self.cell_dirty or resized) {
                try self.vx.render(writer);
            }

            self.compositor.placeComposite();
            self.cell_dirty = false;
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
        lua_bind.deinitPool();
        const allocator = self.allocator;
        const writer = self.tty.writer();

        self.lua_eng.deinit();
        self.audio_system.deinit();
        self.input_state.deinit();
        self.image_mgr.deinit();
        self.sprite_placer.deinit();
        allocator.destroy(self.sprite_placer);
        self.compositor.deinit();
        allocator.destroy(self.compositor);
        self.kitty.deinit();
        allocator.destroy(self.kitty);
        self.loop.stop();
        self.vx.deinit(allocator, writer);
        self.tty.deinit();

        allocator.destroy(self);
    }

    fn hotReload(self: *App) void {
        self.audio_system.stopAll();

        self.lua_eng.deinit();
        self.input_state.reset();

        self.lua_eng = lua_engine_mod.init(self.allocator, self.project_dir) catch {
            self.setErrorOverlay("[reload] failed to init Lua VM");
            return;
        };
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
            .cell_ctx = &self.cell_ctx,
            .compositor = self.compositor,
            .sprite_placer = self.sprite_placer,
            .image_manager = &self.image_mgr,
            .shader_registry = &self.shader_registry,
            .input_state = &self.input_state,
            .audio_system = audio_ptr,
            .save_fs = &self.save_fs,
        });
    }

    fn handleKey(self: *App, key: vaxis.Key, action: input_mod.KeyEvent.Action) void {
        const ev = input_mod.translateKey(key, action);
        self.input_state.processKeyEvent(ev);
        self.lua_eng.callOnKey(ev.name, @tagName(ev.action)) catch |err| {
            self.logLuaError("engine.on_key()", err);
        };
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
        const cols = self.screen_info.cols;
        const display_len = if (text.len > cols) cols else @as(u16, @intCast(text.len));
        self.cell_ctx.drawText(0, 0, text[0..display_len], .{ .r = 255, .g = 60, .b = 60 }, .{ .r = 0, .g = 0, .b = 0 });
    }

    fn renderFpsOverlay(self: *App) void {
        if (self.fps_buf_len == 0) return;
        const cols = self.screen_info.cols;
        const len: u16 = @intCast(@min(self.fps_buf_len, cols));
        const col: u16 = cols -| len;
        self.cell_ctx.drawText(col, 0, self.fps_buf[0..self.fps_buf_len], .{ .r = 0, .g = 255, .b = 0 }, .{ .r = 0, .g = 0, .b = 0 });
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
