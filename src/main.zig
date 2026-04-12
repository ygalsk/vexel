const std = @import("std");
const vaxis = @import("vaxis");
const lua_engine_mod = @import("lua_engine");
const lua_api = @import("lua_api");
const Renderer = @import("renderer");
const ImageManager = @import("image");
const SpriteSystem = @import("sprite_system");
const input_mod = @import("input");
const SceneManager = @import("scene");

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

fn stderrPrint(comptime fmt: []const u8, args: anytype) void {
    var buf: [1024]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch "vexel: error\n";
    std.fs.File.stderr().writeAll(msg) catch {};
}

fn handleLuaError(
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse args: vexel <game_dir>
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        stderrPrint("Usage: vexel <game_directory>\n", .{});
        std.process.exit(1);
    }

    const game_dir = args[1];

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
    try vx.queryTerminal(writer, 1_000_000_000);

    const winsize = vaxis.Tty.getWinsize(tty.fd) catch Winsize{
        .rows = 24,
        .cols = 80,
        .x_pixel = 640,
        .y_pixel = 384,
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

    var image_mgr = ImageManager.init(allocator, game_dir);
    defer image_mgr.deinit();
    renderer.setImageManager(&image_mgr);

    var sprite_system = SpriteSystem.init(allocator);
    defer sprite_system.deinit();

    var input_state = input_mod.InputState.init(allocator);
    defer input_state.deinit();

    var lua_eng = try lua_engine_mod.init(allocator, game_dir);
    defer lua_eng.deinit();

    var scene_mgr = SceneManager.init(allocator, lua_eng.lua, &renderer);
    defer scene_mgr.deinit();

    lua_api.register(lua_eng.lua, &renderer, &sprite_system, &scene_mgr, &input_state);

    lua_eng.loadGame() catch |err| {
        handleLuaError(&vx, writer, &lua_eng, "loadGame", err);
    };

    lua_eng.callLoad() catch |err| {
        handleLuaError(&vx, writer, &lua_eng, "engine.load()", err);
    };

    // After load, switch to placer mode for per-frame sprites (avoids full compositor re-upload)
    renderer.sprite_mode = .placer;

    var timer = try std.time.Timer.start();
    var running = true;

    while (running) {
        // Process all pending events
        while (loop.tryEvent()) |event| {
            switch (event) {
                .key_press => |key| {
                    // Ctrl+C or Ctrl+Q to quit
                    if (key.mods.ctrl and (key.codepoint == 'c' or key.codepoint == 'q')) {
                        running = false;
                        break;
                    }
                    const ev = input_mod.translateKey(key, .press);
                    input_state.processKeyEvent(ev);
                    scene_mgr.onKey(ev.name, @tagName(ev.action));
                },
                .key_release => |key| {
                    const ev = input_mod.translateKey(key, .release);
                    input_state.processKeyEvent(ev);
                    scene_mgr.onKey(ev.name, @tagName(ev.action));
                },
                .mouse => |mouse| {
                    const ev = input_mod.translateMouse(mouse);
                    input_state.processMouseEvent(ev);
                    scene_mgr.onMouse(ev.x, ev.y, ev.button.name(), ev.action.name());
                },
                .winsize => |ws| {
                    vx.resize(allocator, writer, ws) catch {};
                    renderer.updateSize(ws);
                    renderer.onResize();
                },
                .focus_in, .focus_out => {},
            }
        }

        if (!running or lua_eng.shouldQuit()) break;

        // Frame timing
        const dt_ns = timer.lap();
        const dt: f64 = @as(f64, @floatFromInt(dt_ns)) / 1_000_000_000.0;

        // Call update + draw via scene manager (handles legacy mode for existing games)
        scene_mgr.update(dt);
        sprite_system.updateAnimations(@floatCast(dt), lua_eng.lua);
        renderer.clear();
        renderer.clearSprites();
        sprite_system.renderAll(&renderer);
        scene_mgr.draw();

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
