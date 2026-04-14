const std = @import("std");
const vaxis = @import("vaxis");
const lua_engine_mod = @import("lua_engine");
const lua_api = @import("lua_api");
const Renderer = @import("renderer");
const ImageManager = @import("image");
const input_mod = @import("input");
const SceneManager = @import("scene");
const AudioSystem = @import("audio").AudioSystem;
const TimerSystem = @import("timer").TimerSystem;
const SaveDb = @import("db").SaveDb;
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

// --- Global state for panic/signal cleanup ---

var g_cleanup_tty: ?*vaxis.Tty = null;
var g_cleanup_vx: ?*vaxis.Vaxis = null;
var g_signal_received: std.atomic.Value(bool) = std.atomic.Value(bool).init(false);

/// Custom panic handler: restore terminal before crashing.
pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    if (g_cleanup_vx) |vx| {
        if (g_cleanup_tty) |t| {
            vx.exitAltScreen(t.writer()) catch {};
        }
    }
    std.debug.defaultPanic(msg, ret_addr);
}

fn signalHandler(_: c_int) callconv(.c) void {
    g_signal_received.store(true, .release);
}

fn stderrPrint(comptime fmt: []const u8, args: anytype) void {
    var buf: [1024]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch "vexel: error\n";
    std.fs.File.stderr().writeAll(msg) catch {};
}

fn logLuaError(
    lua_eng: *lua_engine_mod,
    comptime context: []const u8,
    err: anyerror,
) void {
    const msg = lua_eng.lua.toString(-1) catch "unknown error";
    stderrPrint("Lua error in {s}: {s} ({any})\n", .{ context, msg, err });
    lua_eng.lua.pop(1);
}

fn fatalLuaError(
    vx: *vaxis.Vaxis,
    writer: *IoWriter,
    lua_eng: *lua_engine_mod,
    comptime context: []const u8,
    err: anyerror,
) noreturn {
    vx.exitAltScreen(writer) catch {};
    const msg = lua_eng.lua.toString(-1) catch "unknown error";
    stderrPrint("Lua error in {s}: {s} ({any})\n", .{ context, msg, err });
    std.process.exit(1);
}

fn handleKey(
    input_state: *input_mod.InputState,
    scene_mgr: *SceneManager,
    lua_eng: *lua_engine_mod,
    key: vaxis.Key,
    action: input_mod.KeyEvent.Action,
    has_scenes: bool,
) void {
    const ev = input_mod.translateKey(key, action);
    input_state.processKeyEvent(ev);
    if (has_scenes) {
        scene_mgr.onKey(ev.name, @tagName(ev.action));
    } else {
        lua_eng.callOnKey(ev.name, @tagName(ev.action)) catch |err| {
            logLuaError(lua_eng, "engine.on_key()", err);
        };
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse args: vexel <project_dir>
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        stderrPrint("Usage: vexel <project_directory>\n", .{});
        std.process.exit(1);
    }

    const project_dir = args[1];

    var tty_buf: [4096]u8 = undefined;
    var tty = try vaxis.Tty.init(&tty_buf);
    defer tty.deinit();

    var vx = try vaxis.init(allocator, .{
        .kitty_keyboard_flags = .{
            .report_events = true,
        },
    });
    defer vx.deinit(allocator, tty.writer());

    var loop: vaxis.Loop(Event) = .{ .tty = &tty, .vaxis = &vx };
    try loop.init();
    try loop.start();
    defer loop.stop();

    const writer = tty.writer();
    try vx.enterAltScreen(writer);

    // Enable panic/signal cleanup now that we're in alt screen
    g_cleanup_tty = &tty;
    g_cleanup_vx = &vx;

    vx.queryTerminal(writer, 1_000_000_000) catch {
        stderrPrint("Warning: terminal query timed out, using defaults\n", .{});
    };

    const winsize = vaxis.Tty.getWinsize(tty.fd) catch |err| blk: {
        stderrPrint("Warning: could not get terminal size ({any}), using 80x24\n", .{err});
        break :blk Winsize{
            .rows = 24,
            .cols = 80,
            .x_pixel = 640,
            .y_pixel = 384,
        };
    };
    try vx.resize(allocator, writer, winsize);

    var renderer = Renderer.init(&vx, winsize);

    renderer.initPixelMode(allocator, writer) catch |err| {
        if (err == error.NoGraphicsCapability) {
            stderrPrint("Error: terminal does not support kitty graphics protocol\n", .{});
            std.process.exit(1);
        }
        return err;
    };
    defer renderer.deinitPixelMode();

    var image_mgr = ImageManager.init(allocator, project_dir);
    defer image_mgr.deinit();
    renderer.setImageManager(&image_mgr);


    var input_state = input_mod.InputState.init(allocator);
    defer input_state.deinit();

    var audio_system = AudioSystem.init(allocator, project_dir);
    defer audio_system.deinit();
    if (!audio_system.available) {
        stderrPrint("Warning: audio device not available, audio disabled\n", .{});
    }

    var lua_eng = try lua_engine_mod.init(allocator, project_dir);
    defer lua_eng.deinit();

    var scene_mgr = SceneManager.init(allocator, lua_eng.lua, &renderer);
    defer scene_mgr.deinit();

    var timer_system = TimerSystem.init(allocator, lua_eng.lua);
    defer timer_system.deinit();

    var save_db = SaveDb.init(allocator, project_dir);
    defer save_db.deinit();

    var ecs_world = EcsWorld.init(allocator);
    defer ecs_world.deinit();

    const audio_ptr: ?*AudioSystem = if (audio_system.available) &audio_system else null;
    lua_api.register(lua_eng.lua, .{
        .renderer = &renderer,
        .scene_mgr = &scene_mgr,
        .input_state = &input_state,
        .audio_system = audio_ptr,
        .timer_system = &timer_system,
        .save_db = &save_db,
        .world = &ecs_world,
    });

    lua_eng.loadGame() catch |err| {
        fatalLuaError(&vx, writer, &lua_eng, "loadGame", err);
    };

    lua_eng.callLoad() catch |err| {
        fatalLuaError(&vx, writer, &lua_eng, "engine.load()", err);
    };

    // After load, switch to placer mode for per-frame sprites (avoids full compositor re-upload)
    renderer.sprite_mode = .placer;

    // Install signal handlers for clean shutdown
    const sa: posix.Sigaction = .{
        .handler = .{ .handler = signalHandler },
        .mask = posix.sigemptyset(),
        .flags = 0,
    };
    posix.sigaction(posix.SIG.INT, &sa, null);
    posix.sigaction(posix.SIG.TERM, &sa, null);

    const has_scenes = scene_mgr.hasScenes();

    var frame_arena = std.heap.ArenaAllocator.init(allocator);
    defer frame_arena.deinit();

    var timer = try std.time.Timer.start();
    var running = true;

    while (running) {
        // Check for signal-triggered shutdown
        if (g_signal_received.load(.acquire)) break;

        // Process all pending events
        while (loop.tryEvent()) |event| {
            switch (event) {
                .key_press => |key| {
                    // Ctrl+C or Ctrl+Q to quit
                    if (key.mods.ctrl and (key.codepoint == 'c' or key.codepoint == 'q')) {
                        running = false;
                        break;
                    }
                    handleKey(&input_state, &scene_mgr, &lua_eng, key, .press, has_scenes);
                },
                .key_release => |key| {
                    handleKey(&input_state, &scene_mgr, &lua_eng, key, .release, has_scenes);
                },
                .mouse => |mouse| {
                    const ev = input_mod.translateMouse(mouse);
                    input_state.processMouseEvent(ev);
                    if (has_scenes) {
                        scene_mgr.onMouse(ev.x, ev.y, ev.button.name(), ev.action.name());
                    } else {
                        lua_eng.callOnMouse(ev.x, ev.y, ev.button.name(), ev.action.name()) catch |err| {
                            logLuaError(&lua_eng, "engine.on_mouse()", err);
                        };
                    }
                },
                .winsize => |ws| {
                    vx.resize(allocator, writer, ws) catch {};
                    renderer.updateSize(ws);
                    renderer.onResize();
                },
                .focus_in, .focus_out => {},
            }
        }

        if (!running or lua_eng.shouldQuit() or g_signal_received.load(.acquire)) break;

        // Frame timing
        const dt_ns = timer.lap();
        const dt: f64 = @as(f64, @floatFromInt(dt_ns)) / 1_000_000_000.0;

        // Call update + draw (route to scene manager or lua engine directly)
        if (has_scenes) {
            scene_mgr.update(dt);
        } else {
            lua_eng.callUpdate(dt) catch |err| {
                logLuaError(&lua_eng, "engine.update()", err);
            };
        }
        timer_system.tick(dt);
        ecs_world.updateMovement(@floatCast(dt));

        // Reset frame arena for per-frame allocations
        _ = frame_arena.reset(.retain_capacity);
        const frame_alloc = frame_arena.allocator();

        // Tick ECS animations and fire Lua callbacks for completed ones
        var anim_events: std.ArrayList(AnimationEvent) = .{};
        ecs_world.tickAnimations(@floatCast(dt), frame_alloc, &anim_events);
        for (anim_events.items) |event| {
            if (event.on_complete_ref != ecs_world_mod.ref_none) {
                _ = lua_eng.lua.rawGetIndex(zlua.registry_index, event.on_complete_ref);
                lua_eng.lua.protectedCall(.{ .args = 0, .results = 0 }) catch {};
            }
        }

        renderer.clear();
        renderer.clearSprites();

        // Render ECS sprites sorted by layer (single pass)
        var sprite_entries: std.ArrayList(EcsWorld.SpriteRenderEntry) = .{};
        ecs_world.collectSprites(frame_alloc, &sprite_entries);
        std.sort.pdq(EcsWorld.SpriteRenderEntry, sprite_entries.items, {}, struct {
            fn lessThan(_: void, a: EcsWorld.SpriteRenderEntry, b: EcsWorld.SpriteRenderEntry) bool {
                return a.layer < b.layer;
            }
        }.lessThan);
        for (sprite_entries.items) |entry| {
            renderer.pixelSetLayer(entry.layer);
            renderer.drawSprite(entry.image_handle, entry.x, entry.y, .{
                .frame = entry.frame,
                .flip_x = entry.flip_x,
                .flip_y = entry.flip_y,
                .scale = entry.scale,
            });
        }
        if (has_scenes) {
            scene_mgr.draw();
        } else {
            lua_eng.callDraw() catch |err| {
                logLuaError(&lua_eng, "engine.draw()", err);
            };
        }

        // Flush pixel layers to terminal via kitty graphics
        renderer.flushPixels() catch {};

        // Render to terminal
        try vx.render(writer);

        // Cap at ~60fps — skip sleep if already behind
        const frame_ns: u64 = 16_666_667; // ~60fps
        const elapsed = timer.read();
        if (elapsed < frame_ns) {
            std.Thread.sleep(frame_ns - elapsed);
        }
    }

    // Cleanup
    lua_eng.callQuit() catch {};
}
