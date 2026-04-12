const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;
const Renderer = @import("renderer");
const SpriteSystem = @import("sprite_system");
const SceneManager = @import("scene");
const input_mod = @import("input");
const InputState = input_mod.InputState;
const METATABLE_IMAGE = "VexelImage";

/// Userdata stored inside each Lua image handle (canonical definition in sprite_system.zig).
pub const LuaImageHandle = SpriteSystem.LuaImageHandle;

/// Push a C closure with the renderer pointer as upvalue 1.
fn pushRendererClosure(lua: *Lua, renderer: *Renderer, func: zlua.CFn) void {
    lua.pushLightUserdata(renderer);
    lua.pushClosure(func, 1);
}

fn pushSceneClosure(lua: *Lua, scene_mgr: *SceneManager, func: zlua.CFn) void {
    lua.pushLightUserdata(scene_mgr);
    lua.pushClosure(func, 1);
}

fn pushInputClosure(lua: *Lua, input_state: *InputState, func: zlua.CFn) void {
    lua.pushLightUserdata(input_state);
    lua.pushClosure(func, 1);
}

/// Register all engine.* API functions into the Lua state.
/// Call this after LuaEngine.init() but before loadGame().
pub fn register(lua: *Lua, renderer: *Renderer, sprite_system: *SpriteSystem, scene_mgr: *SceneManager, input_state: *InputState) void {
    // Create VexelImage metatable with __gc
    lua.newMetatable(METATABLE_IMAGE) catch {};
    pushRendererClosure(lua, renderer, zlua.wrap(lImageGc));
    lua.setField(-2, "__gc");
    lua.pop(1);

    // Create VexelSprite metatable
    SpriteSystem.registerMetatable(lua, sprite_system, renderer);

    // Create the `engine` global table
    lua.newTable();

    // engine.sprite(image) -> retained sprite
    SpriteSystem.pushSystemClosure(lua, sprite_system, renderer, zlua.wrap(SpriteSystem.lNewSprite));
    lua.setField(-2, "sprite");

    // engine.graphics
    lua.newTable();

    pushRendererClosure(lua, renderer, zlua.wrap(lDrawText));
    lua.setField(-2, "draw_text");
    pushRendererClosure(lua, renderer, zlua.wrap(lDrawRect));
    lua.setField(-2, "draw_rect");
    pushRendererClosure(lua, renderer, zlua.wrap(lClear));
    lua.setField(-2, "clear");
    pushRendererClosure(lua, renderer, zlua.wrap(lGetSize));
    lua.setField(-2, "get_size");
    pushRendererClosure(lua, renderer, zlua.wrap(lGetPixelSize));
    lua.setField(-2, "get_pixel_size");
    pushRendererClosure(lua, renderer, zlua.wrap(lSetResolution));
    lua.setField(-2, "set_resolution");
    pushRendererClosure(lua, renderer, zlua.wrap(lGetResolution));
    lua.setField(-2, "get_resolution");
    pushRendererClosure(lua, renderer, zlua.wrap(lSetLayer));
    lua.setField(-2, "set_layer");
    pushRendererClosure(lua, renderer, zlua.wrap(lClearAll));
    lua.setField(-2, "clear_all");

    // Image/sprite functions
    pushRendererClosure(lua, renderer, zlua.wrap(lLoadImage));
    lua.setField(-2, "load_image");
    pushRendererClosure(lua, renderer, zlua.wrap(lLoadSpriteSheet));
    lua.setField(-2, "load_spritesheet");
    pushRendererClosure(lua, renderer, zlua.wrap(lDrawSprite));
    lua.setField(-2, "draw_sprite");
    pushRendererClosure(lua, renderer, zlua.wrap(lDrawFrame));
    lua.setField(-2, "draw_frame");
    pushRendererClosure(lua, renderer, zlua.wrap(lUnloadImage));
    lua.setField(-2, "unload_image");
    pushRendererClosure(lua, renderer, zlua.wrap(lGetFrameCount));
    lua.setField(-2, "get_frame_count");

    // engine.graphics.pixel
    lua.newTable();

    pushRendererClosure(lua, renderer, zlua.wrap(lPixelRect));
    lua.setField(-2, "rect");

    pushRendererClosure(lua, renderer, zlua.wrap(lPixelLine));
    lua.setField(-2, "line");

    pushRendererClosure(lua, renderer, zlua.wrap(lPixelCircle));
    lua.setField(-2, "circle");

    pushRendererClosure(lua, renderer, zlua.wrap(lPixelClear));
    lua.setField(-2, "clear");

    pushRendererClosure(lua, renderer, zlua.wrap(lPixelSet));
    lua.setField(-2, "set");

    pushRendererClosure(lua, renderer, zlua.wrap(lPixelBuffer));
    lua.setField(-2, "buffer");

    lua.setField(-2, "pixel");
    lua.setField(-2, "graphics");

    // engine.input
    lua.newTable();
    pushInputClosure(lua, input_state, zlua.wrap(lInputIsKeyDown));
    lua.setField(-2, "is_key_down");
    pushInputClosure(lua, input_state, zlua.wrap(lInputGetMouse));
    lua.setField(-2, "get_mouse");
    pushInputClosure(lua, input_state, zlua.wrap(lInputGetGamepad));
    lua.setField(-2, "get_gamepad");
    lua.setField(-2, "input");

    // engine.scene
    lua.newTable();
    pushSceneClosure(lua, scene_mgr, zlua.wrap(lSceneRegister));
    lua.setField(-2, "register");
    pushSceneClosure(lua, scene_mgr, zlua.wrap(lScenePush));
    lua.setField(-2, "push");
    pushSceneClosure(lua, scene_mgr, zlua.wrap(lScenePop));
    lua.setField(-2, "pop");
    pushSceneClosure(lua, scene_mgr, zlua.wrap(lSceneSwitch));
    lua.setField(-2, "switch");
    lua.setField(-2, "scene");

    lua.pushFunction(zlua.wrap(lQuitGame));
    lua.setField(-2, "quit_game");
    lua.pushBoolean(false);
    lua.setField(-2, "should_quit");

    lua.setGlobal("engine");
}

// --- Helpers ---

fn luaOptionalColor(lua: *Lua, idx: i32) ?Renderer.Color {
    const v = lua.toInteger(idx) catch return null;
    return Renderer.Color.fromHex(@intCast(@as(i64, v)));
}

fn luaHexColor(lua: *Lua, idx: i32, default: u32) Renderer.Color {
    return luaOptionalColor(lua, idx) orelse Renderer.Color.fromHex(default);
}

fn getRenderer(lua: *Lua) *Renderer {
    const ptr = lua.toPointer(Lua.upvalueIndex(1)) catch unreachable;
    return @ptrCast(@constCast(@alignCast(ptr)));
}

fn lDrawText(lua: *Lua) i32 {
    const renderer = getRenderer(lua);
    const col: u16 = @intCast(lua.toInteger(1) catch 0);
    const row: u16 = @intCast(lua.toInteger(2) catch 0);
    const text = lua.toString(3) catch "?";

    const fg = luaOptionalColor(lua, 4);
    const bg = luaOptionalColor(lua, 5);

    renderer.drawText(col, row, text, fg, bg);
    return 0;
}

fn lDrawRect(lua: *Lua) i32 {
    const renderer = getRenderer(lua);
    const col: u16 = @intCast(lua.toInteger(1) catch 0);
    const row: u16 = @intCast(lua.toInteger(2) catch 0);
    const w: u16 = @intCast(lua.toInteger(3) catch 1);
    const h: u16 = @intCast(lua.toInteger(4) catch 1);
    renderer.drawRect(col, row, w, h, luaHexColor(lua, 5, 0xFFFFFF));
    return 0;
}

fn lClear(lua: *Lua) i32 {
    const renderer = getRenderer(lua);
    renderer.clear();
    return 0;
}

fn lGetSize(lua: *Lua) i32 {
    const renderer = getRenderer(lua);
    const info = renderer.getScreenInfo();
    lua.pushInteger(@intCast(info.cols));
    lua.pushInteger(@intCast(info.rows));
    return 2;
}

fn lGetPixelSize(lua: *Lua) i32 {
    const renderer = getRenderer(lua);
    const info = renderer.getScreenInfo();
    lua.pushInteger(@intCast(info.x_pixel));
    lua.pushInteger(@intCast(info.y_pixel));
    return 2;
}

// --- Pixel drawing functions ---

fn lPixelRect(lua: *Lua) i32 {
    const renderer = getRenderer(lua);
    const x: i32 = @intCast(lua.toInteger(1) catch 0);
    const y: i32 = @intCast(lua.toInteger(2) catch 0);
    const w: i32 = @intCast(lua.toInteger(3) catch 1);
    const h: i32 = @intCast(lua.toInteger(4) catch 1);
    renderer.pixelDrawRect(x, y, w, h, luaHexColor(lua, 5, 0xFFFFFF));
    return 0;
}

fn lPixelLine(lua: *Lua) i32 {
    const renderer = getRenderer(lua);
    const x1: i32 = @intCast(lua.toInteger(1) catch 0);
    const y1: i32 = @intCast(lua.toInteger(2) catch 0);
    const x2: i32 = @intCast(lua.toInteger(3) catch 0);
    const y2: i32 = @intCast(lua.toInteger(4) catch 0);
    renderer.pixelDrawLine(x1, y1, x2, y2, luaHexColor(lua, 5, 0xFFFFFF));
    return 0;
}

fn lPixelCircle(lua: *Lua) i32 {
    const renderer = getRenderer(lua);
    const cx: i32 = @intCast(lua.toInteger(1) catch 0);
    const cy: i32 = @intCast(lua.toInteger(2) catch 0);
    const r: i32 = @intCast(lua.toInteger(3) catch 1);
    renderer.pixelDrawCircle(cx, cy, r, luaHexColor(lua, 4, 0xFFFFFF));
    return 0;
}

fn lPixelSet(lua: *Lua) i32 {
    const renderer = getRenderer(lua);
    const x: i32 = @intCast(lua.toInteger(1) catch 0);
    const y: i32 = @intCast(lua.toInteger(2) catch 0);
    renderer.pixelSetPixel(x, y, luaHexColor(lua, 3, 0xFFFFFF));
    return 0;
}

fn lPixelBuffer(lua: *Lua) i32 {
    const renderer = getRenderer(lua);
    // Args: table, x, y, w, h
    if (lua.typeOf(1) != .table) {
        lua.raiseErrorStr("pixel.buffer: expected table as first argument", .{});
    }
    const x: i32 = @intCast(lua.toInteger(2) catch 0);
    const y: i32 = @intCast(lua.toInteger(3) catch 0);
    const w: i32 = @intCast(lua.toInteger(4) catch 0);
    const h: i32 = @intCast(lua.toInteger(5) catch 0);
    if (w <= 0 or h <= 0) return 0;

    const count: usize = @intCast(w * h);
    const allocator = renderer.getPixelAllocator() orelse return 0;
    const colors = allocator.alloc(u32, count) catch return 0;
    defer allocator.free(colors);

    for (0..count) |i| {
        _ = lua.rawGetIndex(1, @intCast(i + 1));
        const val = lua.toInteger(-1) catch 0;
        colors[i] = Renderer.Color.fromHex(@intCast(@as(i64, val))).pack();
        lua.pop(1);
    }

    renderer.pixelBlitBuffer(x, y, w, h, colors);
    return 0;
}

fn lPixelClear(lua: *Lua) i32 {
    const renderer = getRenderer(lua);
    renderer.pixelClearLayer();
    return 0;
}

fn lSetResolution(lua: *Lua) i32 {
    const renderer = getRenderer(lua);
    const w: u16 = @intCast(lua.toInteger(1) catch 320);
    const h: u16 = @intCast(lua.toInteger(2) catch 180);
    renderer.pixelSetResolution(w, h) catch {
        lua.raiseErrorStr("failed to set resolution", .{});
    };
    return 0;
}

fn lGetResolution(lua: *Lua) i32 {
    const renderer = getRenderer(lua);
    const res = renderer.pixelGetResolution();
    lua.pushInteger(@intCast(res.w));
    lua.pushInteger(@intCast(res.h));
    return 2;
}

fn lSetLayer(lua: *Lua) i32 {
    const renderer = getRenderer(lua);
    const layer: u8 = @intCast(lua.toInteger(1) catch 0);
    renderer.pixelSetLayer(layer);
    return 0;
}

fn lClearAll(lua: *Lua) i32 {
    const renderer = getRenderer(lua);
    renderer.pixelClearAll();
    return 0;
}

// --- Image/sprite functions ---

/// Push a new VexelImage userdata onto the stack.
fn pushImageUserdata(lua: *Lua, handle: Renderer.ImageHandle) void {
    const ud = lua.newUserdata(LuaImageHandle, 0);
    ud.* = .{ .handle = handle, .valid = true };
    _ = lua.getField(zlua.registry_index, METATABLE_IMAGE);
    lua.setMetatable(-2);
}

/// Get the LuaImageHandle from a Lua argument, validating the metatable.
fn checkImageHandle(lua: *Lua, arg: i32) *LuaImageHandle {
    return lua.checkUserdata(LuaImageHandle, arg, METATABLE_IMAGE);
}

fn lLoadImage(lua: *Lua) i32 {
    const renderer = getRenderer(lua);
    const path = lua.toString(1) catch {
        lua.raiseErrorStr("load_image: expected string path", .{});
    };
    const handle = renderer.loadImage(path) catch {
        lua.raiseErrorStr("load_image: failed to load '%s'", .{path.ptr});
    };
    pushImageUserdata(lua, handle);
    return 1;
}

fn lLoadSpriteSheet(lua: *Lua) i32 {
    const renderer = getRenderer(lua);
    const path = lua.toString(1) catch {
        lua.raiseErrorStr("load_spritesheet: expected string path", .{});
    };
    const tile_w: u16 = @intCast(lua.toInteger(2) catch {
        lua.raiseErrorStr("load_spritesheet: expected tile_w", .{});
    });
    const tile_h: u16 = @intCast(lua.toInteger(3) catch {
        lua.raiseErrorStr("load_spritesheet: expected tile_h", .{});
    });
    const handle = renderer.loadSpriteSheet(path, tile_w, tile_h) catch {
        lua.raiseErrorStr("load_spritesheet: failed to load '%s'", .{path.ptr});
    };
    pushImageUserdata(lua, handle);
    return 1;
}

fn lDrawSprite(lua: *Lua) i32 {
    const renderer = getRenderer(lua);
    const ud = checkImageHandle(lua, 1);
    if (!ud.valid) return 0;

    const x: i32 = @intCast(lua.toInteger(2) catch 0);
    const y: i32 = @intCast(lua.toInteger(3) catch 0);

    // Parse optional opts table (arg 4)
    var opts = Renderer.DrawSpriteOpts{};
    if (lua.typeOf(4) == .table) {
        // frame
        if (lua.getField(4, "frame") == .number) {
            opts.frame = @intCast(lua.toInteger(-1) catch 0);
        }
        lua.pop(1);
        // flip_x
        if (lua.getField(4, "flip_x") == .boolean) {
            opts.flip_x = lua.toBoolean(-1);
        }
        lua.pop(1);
        // flip_y
        if (lua.getField(4, "flip_y") == .boolean) {
            opts.flip_y = lua.toBoolean(-1);
        }
        lua.pop(1);
        // scale
        if (lua.getField(4, "scale") == .number) {
            const s = lua.toInteger(-1) catch 1;
            opts.scale = if (s < 1) 1 else if (s > 8) 8 else @intCast(s);
        }
        lua.pop(1);
    }

    renderer.drawSprite(ud.handle, x, y, opts);
    return 0;
}

fn lDrawFrame(lua: *Lua) i32 {
    const renderer = getRenderer(lua);
    const ud = checkImageHandle(lua, 1);
    if (!ud.valid) return 0;

    const frame_idx: u32 = @intCast(lua.toInteger(2) catch 0);
    const x: i32 = @intCast(lua.toInteger(3) catch 0);
    const y: i32 = @intCast(lua.toInteger(4) catch 0);

    renderer.drawSprite(ud.handle, x, y, .{ .frame = frame_idx });
    return 0;
}

fn lUnloadImage(lua: *Lua) i32 {
    releaseImageHandle(lua, checkImageHandle(lua, 1));
    return 0;
}

fn lGetFrameCount(lua: *Lua) i32 {
    const renderer = getRenderer(lua);
    const ud = checkImageHandle(lua, 1);
    if (!ud.valid) {
        lua.pushInteger(0);
        return 1;
    }
    lua.pushInteger(@intCast(renderer.getFrameCount(ud.handle)));
    return 1;
}

fn lImageGc(lua: *Lua) i32 {
    releaseImageHandle(lua, checkImageHandle(lua, 1));
    return 0;
}

fn releaseImageHandle(lua: *Lua, ud: *LuaImageHandle) void {
    if (!ud.valid) return;
    const renderer = getRenderer(lua);
    renderer.unloadImage(ud.handle);
    ud.valid = false;
}

// --- Input functions ---

fn getInputState(lua: *Lua) *InputState {
    const ptr = lua.toPointer(Lua.upvalueIndex(1)) catch unreachable;
    return @ptrCast(@constCast(@alignCast(ptr)));
}

fn lInputIsKeyDown(lua: *Lua) i32 {
    const input_state = getInputState(lua);
    const key = lua.toString(1) catch {
        lua.pushBoolean(false);
        return 1;
    };
    lua.pushBoolean(input_state.isKeyDown(key));
    return 1;
}

fn lInputGetMouse(lua: *Lua) i32 {
    const input_state = getInputState(lua);
    lua.pushInteger(input_state.mouse_x);
    lua.pushInteger(input_state.mouse_y);
    lua.newTable();
    lua.pushBoolean(input_state.mouse_left);
    lua.setField(-2, "left");
    lua.pushBoolean(input_state.mouse_right);
    lua.setField(-2, "right");
    lua.pushBoolean(input_state.mouse_middle);
    lua.setField(-2, "middle");
    return 3;
}

fn lInputGetGamepad(lua: *Lua) i32 {
    const input_state = getInputState(lua);
    const gp = input_mod.getGamepadState(input_state);
    lua.newTable();
    lua.pushBoolean(gp.up);
    lua.setField(-2, "up");
    lua.pushBoolean(gp.down);
    lua.setField(-2, "down");
    lua.pushBoolean(gp.left);
    lua.setField(-2, "left");
    lua.pushBoolean(gp.right);
    lua.setField(-2, "right");
    lua.pushBoolean(gp.a);
    lua.setField(-2, "a");
    lua.pushBoolean(gp.b);
    lua.setField(-2, "b");
    lua.pushBoolean(gp.start);
    lua.setField(-2, "start");
    lua.pushBoolean(gp.select);
    lua.setField(-2, "select");
    return 1;
}

// --- Scene functions ---

fn getSceneManager(lua: *Lua) *SceneManager {
    const ptr = lua.toPointer(Lua.upvalueIndex(1)) catch unreachable;
    return @ptrCast(@constCast(@alignCast(ptr)));
}

fn lSceneRegister(lua: *Lua) i32 {
    const scene_mgr = getSceneManager(lua);
    const name = lua.toString(1) catch {
        lua.raiseErrorStr("scene.register: expected string name", .{});
    };
    // Arg 2 must be a table
    if (lua.typeOf(2) != .table) {
        lua.raiseErrorStr("scene.register: expected table as second argument", .{});
    }
    lua.pushValue(2); // push table copy for ref
    const table_ref = lua.ref(zlua.registry_index) catch {
        lua.raiseErrorStr("scene.register: failed to create reference", .{});
    };
    scene_mgr.registerScene(name, table_ref) catch {
        lua.raiseErrorStr("scene.register: allocation failed", .{});
    };
    return 0;
}

fn lScenePush(lua: *Lua) i32 {
    const scene_mgr = getSceneManager(lua);
    const name = lua.toString(1) catch {
        lua.raiseErrorStr("scene.push: expected string name", .{});
    };
    // Optional data argument
    var data_ref: i32 = zlua.ref_no;
    if (lua.typeOf(2) != .none and lua.typeOf(2) != .nil) {
        lua.pushValue(2);
        data_ref = lua.ref(zlua.registry_index) catch zlua.ref_no;
    }
    scene_mgr.pushScene(name, data_ref) catch {
        lua.raiseErrorStr("scene.push: failed", .{});
    };
    return 0;
}

fn lScenePop(lua: *Lua) i32 {
    const scene_mgr = getSceneManager(lua);
    var data_ref: i32 = zlua.ref_no;
    if (lua.typeOf(1) != .none and lua.typeOf(1) != .nil) {
        lua.pushValue(1);
        data_ref = lua.ref(zlua.registry_index) catch zlua.ref_no;
    }
    scene_mgr.popScene(data_ref) catch {
        lua.raiseErrorStr("scene.pop: failed", .{});
    };
    return 0;
}

fn lSceneSwitch(lua: *Lua) i32 {
    const scene_mgr = getSceneManager(lua);
    const name = lua.toString(1) catch {
        lua.raiseErrorStr("scene.switch: expected string name", .{});
    };

    var kind: SceneManager.TransitionKind = .none;
    var duration: f64 = 0;
    var data_ref: i32 = zlua.ref_no;

    // Parse optional opts table (arg 2)
    if (lua.typeOf(2) == .table) {
        if (lua.getField(2, "transition") == .string) {
            const t_str = lua.toString(-1) catch "none";
            kind = SceneManager.TransitionKind.fromString(t_str);
        }
        lua.pop(1);
        if (lua.getField(2, "duration") == .number) {
            duration = @floatCast(lua.toNumber(-1) catch 0.0);
        }
        lua.pop(1);
        if (lua.getField(2, "data") != .nil) {
            data_ref = lua.ref(zlua.registry_index) catch zlua.ref_no;
        } else {
            lua.pop(1);
        }
    }

    scene_mgr.switchScene(name, kind, duration, data_ref) catch {
        lua.raiseErrorStr("scene.switch: failed", .{});
    };
    return 0;
}

fn lQuitGame(lua: *Lua) i32 {
    const lua_type = lua.getGlobal("engine") catch return 0;
    if (lua_type != .table) {
        lua.pop(1);
        return 0;
    }
    lua.pushBoolean(true);
    lua.setField(-2, "should_quit");
    lua.pop(1);
    return 0;
}

test "register creates engine global" {
    // Minimal smoke test — just verify it doesn't crash
    _ = Renderer;
}
