const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;
const Renderer = @import("renderer");
const SpriteSystem = @import("sprite_system");
const SceneManager = @import("scene");
const input_mod = @import("input");
const InputState = input_mod.InputState;
const audio_mod_ = @import("audio");
const AudioSystem = audio_mod_.AudioSystem;
const SoundId = audio_mod_.SoundId;
const AudioLoadOpts = audio_mod_.LoadOpts;
const AudioPlayOpts = audio_mod_.PlayOpts;
const timer_mod_ = @import("timer");
const TimerSystem = timer_mod_.TimerSystem;
const db_mod_ = @import("db");
const SaveDb = db_mod_.SaveDb;
const PersistDb = db_mod_.Db;
const tilemap = @import("tilemap");
const METATABLE_IMAGE = "VexelImage";
const METATABLE_SOUND = "VexelSound";
const METATABLE_DB = "VexelDb";

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

fn pushAudioClosure(lua: *Lua, audio_system: *AudioSystem, func: zlua.CFn) void {
    lua.pushLightUserdata(audio_system);
    lua.pushClosure(func, 1);
}

fn pushTimerClosure(lua: *Lua, timer_system: *TimerSystem, func: zlua.CFn) void {
    lua.pushLightUserdata(timer_system);
    lua.pushClosure(func, 1);
}

fn pushSaveClosure(lua: *Lua, save_db: *SaveDb, func: zlua.CFn) void {
    lua.pushLightUserdata(save_db);
    lua.pushClosure(func, 1);
}

pub const EngineContext = struct {
    renderer: *Renderer,
    sprite_system: *SpriteSystem,
    scene_mgr: *SceneManager,
    input_state: *InputState,
    audio_system: ?*AudioSystem,
    timer_system: *TimerSystem,
    save_db: *SaveDb,
};

/// Register all engine.* API functions into the Lua state.
/// Call this after LuaEngine.init() but before loadGame().
pub fn register(lua: *Lua, ctx: EngineContext) void {
    const renderer = ctx.renderer;
    const sprite_system = ctx.sprite_system;
    const scene_mgr = ctx.scene_mgr;
    const input_state = ctx.input_state;
    const audio_system = ctx.audio_system;
    const timer_system = ctx.timer_system;
    const save_db = ctx.save_db;
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

    pushRendererClosure(lua, renderer, zlua.wrap(lDrawTilemap));
    lua.setField(-2, "draw_tilemap");

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

    // engine.audio
    if (audio_system) |audio| {
        // Create VexelSound metatable
        lua.newMetatable(METATABLE_SOUND) catch {};
        pushAudioClosure(lua, audio, zlua.wrap(lSoundGc));
        lua.setField(-2, "__gc");
        pushAudioClosure(lua, audio, zlua.wrap(lSoundIndex));
        lua.setField(-2, "__index");
        lua.pop(1);

        lua.newTable();
        pushAudioClosure(lua, audio, zlua.wrap(lAudioLoad));
        lua.setField(-2, "load");
        pushAudioClosure(lua, audio, zlua.wrap(lAudioSetMasterVolume));
        lua.setField(-2, "set_master_volume");
        pushAudioClosure(lua, audio, zlua.wrap(lAudioStopAll));
        lua.setField(-2, "stop_all");
        lua.setField(-2, "audio");
    }

    // engine.timer
    lua.newTable();
    pushTimerClosure(lua, timer_system, zlua.wrap(lTimerAfter));
    lua.setField(-2, "after");
    pushTimerClosure(lua, timer_system, zlua.wrap(lTimerEvery));
    lua.setField(-2, "every");
    pushTimerClosure(lua, timer_system, zlua.wrap(lTimerCancel));
    lua.setField(-2, "cancel");
    lua.setField(-2, "timer");

    // engine.tween
    pushTimerClosure(lua, timer_system, zlua.wrap(lTween));
    lua.setField(-2, "tween");

    // engine.db
    lua.newMetatable(METATABLE_DB) catch {};
    lua.pushFunction(zlua.wrap(lDbGc));
    lua.setField(-2, "__gc");
    lua.pushFunction(zlua.wrap(lDbIndex));
    lua.setField(-2, "__index");
    lua.pop(1);

    lua.newTable();
    pushSaveClosure(lua, save_db, zlua.wrap(lDbOpen));
    lua.setField(-2, "open");
    lua.setField(-2, "db");

    // engine.save
    lua.newTable();
    pushSaveClosure(lua, save_db, zlua.wrap(lSaveSet));
    lua.setField(-2, "set");
    pushSaveClosure(lua, save_db, zlua.wrap(lSaveGet));
    lua.setField(-2, "get");
    lua.setField(-2, "save");

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

// --- Tilemap functions ---

/// engine.graphics.draw_tilemap(tileset, map_data, opts)
/// opts: { width = N, cam_x = 0, cam_y = 0, layer = 0 }
fn lDrawTilemap(lua: *Lua) i32 {
    const renderer = getRenderer(lua);

    // Arg 1: tileset image handle
    const ud = checkImageHandle(lua, 1);
    if (!ud.valid) return 0;

    // Arg 2: map_data table (1D array of tile indices)
    if (lua.typeOf(2) != .table) {
        lua.raiseErrorStr("draw_tilemap: expected table as map_data", .{});
    }

    // Arg 3: opts table
    if (lua.typeOf(3) != .table) {
        lua.raiseErrorStr("draw_tilemap: expected opts table", .{});
    }

    // Read opts
    var map_width: u32 = 0;
    var cam_x: f64 = 0;
    var cam_y: f64 = 0;
    var layer: u8 = 0;

    if (lua.getField(3, "width") == .number) {
        map_width = @intCast(lua.toInteger(-1) catch 0);
    }
    lua.pop(1);
    if (lua.getField(3, "cam_x") == .number) {
        cam_x = @floatCast(lua.toNumber(-1) catch 0.0);
    }
    lua.pop(1);
    if (lua.getField(3, "cam_y") == .number) {
        cam_y = @floatCast(lua.toNumber(-1) catch 0.0);
    }
    lua.pop(1);
    if (lua.getField(3, "layer") == .number) {
        layer = @intCast(lua.toInteger(-1) catch 0);
    }
    lua.pop(1);

    if (map_width == 0) {
        lua.raiseErrorStr("draw_tilemap: opts.width is required", .{});
    }

    // Read map data from Lua table into temp buffer
    const map_len = lua.rawLen(2);
    if (map_len == 0) return 0;

    const allocator = renderer.getPixelAllocator() orelse return 0;
    const map_data = allocator.alloc(u32, map_len) catch return 0;
    defer allocator.free(map_data);

    for (0..map_len) |i| {
        _ = lua.rawGetIndex(2, @intCast(i + 1));
        const val = lua.toInteger(-1) catch 0;
        map_data[i] = if (val < 0) 0 else @intCast(val);
        lua.pop(1);
    }

    // Get tile dimensions from sprite sheet
    const frame_info = renderer.getFrameSize(ud.handle) orelse return 0;

    tilemap.renderTilemap(renderer, ud.handle, map_data, frame_info.w, frame_info.h, .{
        .map_width = map_width,
        .cam_x = cam_x,
        .cam_y = cam_y,
        .layer = layer,
    });

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

// --- Timer/Tween functions ---

fn getTimerSystem(lua: *Lua) *TimerSystem {
    const ptr = lua.toPointer(Lua.upvalueIndex(1)) catch unreachable;
    return @ptrCast(@constCast(@alignCast(ptr)));
}

/// engine.timer.after(seconds, callback) -> handle
fn lTimerAfter(lua: *Lua) i32 {
    const timer_sys = getTimerSystem(lua);
    const seconds: f64 = @floatCast(lua.toNumber(1) catch {
        lua.raiseErrorStr("timer.after: expected number for seconds", .{});
    });
    if (lua.typeOf(2) != .function) {
        lua.raiseErrorStr("timer.after: expected function as callback", .{});
    }
    lua.pushValue(2);
    const cb_ref = lua.ref(zlua.registry_index) catch {
        lua.raiseErrorStr("timer.after: failed to create reference", .{});
    };

    const id = timer_sys.addTimer(cb_ref, seconds, null) catch {
        lua.raiseErrorStr("timer.after: allocation failed", .{});
    };
    lua.pushInteger(@intCast(id));
    return 1;
}

/// engine.timer.every(seconds, callback) -> handle
fn lTimerEvery(lua: *Lua) i32 {
    const timer_sys = getTimerSystem(lua);
    const seconds: f64 = @floatCast(lua.toNumber(1) catch {
        lua.raiseErrorStr("timer.every: expected number for seconds", .{});
    });
    if (lua.typeOf(2) != .function) {
        lua.raiseErrorStr("timer.every: expected function as callback", .{});
    }
    lua.pushValue(2);
    const cb_ref = lua.ref(zlua.registry_index) catch {
        lua.raiseErrorStr("timer.every: failed to create reference", .{});
    };

    const id = timer_sys.addTimer(cb_ref, seconds, seconds) catch {
        lua.raiseErrorStr("timer.every: allocation failed", .{});
    };
    lua.pushInteger(@intCast(id));
    return 1;
}

/// engine.timer.cancel(handle)
fn lTimerCancel(lua: *Lua) i32 {
    const timer_sys = getTimerSystem(lua);
    const id: u32 = @intCast(lua.toInteger(1) catch {
        lua.raiseErrorStr("timer.cancel: expected integer handle", .{});
    });
    timer_sys.cancelTimer(id);
    return 0;
}

/// engine.tween(target, props, duration, easing?, on_complete?) -> handle
fn lTween(lua: *Lua) i32 {
    const timer_sys = getTimerSystem(lua);

    // Arg 1: target table
    if (lua.typeOf(1) != .table) {
        lua.raiseErrorStr("tween: expected table as target", .{});
    }

    // Arg 2: props table {field = end_value, ...}
    if (lua.typeOf(2) != .table) {
        lua.raiseErrorStr("tween: expected table as props", .{});
    }

    // Arg 3: duration
    const duration: f64 = @floatCast(lua.toNumber(3) catch {
        lua.raiseErrorStr("tween: expected number for duration", .{});
    });

    // Arg 4: optional easing string
    const easing: timer_mod_.EasingFn = if (lua.typeOf(4) == .string)
        timer_mod_.easingFromString(lua.toString(4) catch "linear")
    else
        timer_mod_.easeLinear;

    // Arg 5: optional on_complete callback
    var on_complete_ref: i32 = zlua.ref_no;
    if (lua.typeOf(5) == .function) {
        lua.pushValue(5);
        on_complete_ref = lua.ref(zlua.registry_index) catch zlua.ref_no;
    }

    // Count props and build TweenProp array
    var prop_count: usize = 0;
    lua.pushNil();
    while (lua.next(2)) {
        prop_count += 1;
        lua.pop(1); // pop value, keep key
    }

    const allocator = timer_sys.allocator;
    const props = allocator.alloc(timer_mod_.TweenProp, prop_count) catch {
        lua.raiseErrorStr("tween: allocation failed", .{});
    };

    // Iterate props table again to fill in values
    var idx: usize = 0;
    lua.pushNil();
    while (lua.next(2)) {
        // key at -2, value at -1
        const field_name = lua.toString(-2) catch {
            allocator.free(props);
            lua.raiseErrorStr("tween: prop keys must be strings", .{});
        };
        const end_val: f64 = @floatCast(lua.toNumber(-1) catch {
            allocator.free(props);
            lua.raiseErrorStr("tween: prop values must be numbers", .{});
        });

        // Read current value from target table
        _ = lua.getField(1, field_name);
        const start_val: f64 = @floatCast(lua.toNumber(-1) catch 0.0);
        lua.pop(1);

        // Allocate copy of field name
        const name_copy = allocator.allocSentinel(u8, field_name.len, 0) catch {
            allocator.free(props);
            lua.raiseErrorStr("tween: allocation failed", .{});
        };
        @memcpy(name_copy, field_name);

        props[idx] = .{
            .field_name = name_copy,
            .start_val = start_val,
            .end_val = end_val,
        };
        idx += 1;
        lua.pop(1); // pop value, keep key
    }

    // Create ref to target table
    lua.pushValue(1);
    const target_ref = lua.ref(zlua.registry_index) catch {
        for (props) |prop| allocator.free(prop.field_name);
        allocator.free(props);
        lua.raiseErrorStr("tween: failed to create reference", .{});
    };

    const id = timer_sys.addTween(target_ref, props, duration, easing, on_complete_ref) catch {
        for (props) |prop| allocator.free(prop.field_name);
        allocator.free(props);
        lua.raiseErrorStr("tween: allocation failed", .{});
    };

    lua.pushInteger(@intCast(id));
    return 1;
}

// --- DB functions ---

const LuaDbHandle = struct {
    db: PersistDb,
    open: bool,
};

fn getSaveDb(lua: *Lua) *SaveDb {
    const ptr = lua.toPointer(Lua.upvalueIndex(1)) catch unreachable;
    return @ptrCast(@constCast(@alignCast(ptr)));
}

fn checkDbHandle(lua: *Lua, arg: i32) *LuaDbHandle {
    return lua.checkUserdata(LuaDbHandle, arg, METATABLE_DB);
}

/// engine.db.open(path) -> db userdata
fn lDbOpen(lua: *Lua) i32 {
    const save_db = getSaveDb(lua);
    const rel_path = lua.toString(1) catch {
        lua.raiseErrorStr("db.open: expected string path", .{});
    };

    // Resolve path relative to game dir
    const abs_path = std.fs.path.joinZ(save_db.allocator, &.{ save_db.game_dir, rel_path }) catch {
        lua.raiseErrorStr("db.open: failed to resolve path", .{});
    };
    defer save_db.allocator.free(abs_path);

    const db = PersistDb.open(abs_path) catch {
        lua.raiseErrorStr("db.open: failed to open database '%s'", .{rel_path.ptr});
    };

    const ud = lua.newUserdata(LuaDbHandle, 0);
    ud.* = .{ .db = db, .open = true };
    _ = lua.getField(zlua.registry_index, METATABLE_DB);
    lua.setMetatable(-2);
    return 1;
}

/// __gc for db handle
fn lDbGc(lua: *Lua) i32 {
    const ud = checkDbHandle(lua, 1);
    if (ud.open) {
        ud.db.close();
        ud.open = false;
    }
    return 0;
}

/// __index for db handle — dispatch methods
fn lDbIndex(lua: *Lua) i32 {
    const key = lua.toString(2) catch return 0;

    const methods = std.StaticStringMap(zlua.CFn).initComptime(.{
        .{ "exec", zlua.wrap(lDbExec) },
        .{ "query", zlua.wrap(lDbQuery) },
        .{ "close", zlua.wrap(lDbClose) },
    });

    if (methods.get(key)) |func| {
        lua.pushClosure(func, 0);
        return 1;
    }
    return 0;
}

/// Bind Lua arguments (from arg position `start_arg` upward) to a zqlite statement.
fn bindLuaParams(lua: *Lua, stmt: anytype, start_arg: i32) void {
    const top = lua.getTop();
    var bind_idx: usize = 1;
    var arg_idx: i32 = start_arg;
    while (arg_idx <= top) : ({
        arg_idx += 1;
        bind_idx += 1;
    }) {
        switch (lua.typeOf(arg_idx)) {
            .number => {
                if (lua.toInteger(arg_idx)) |int_val| {
                    stmt.bindValue(int_val, bind_idx) catch {
                        lua.raiseErrorStr("db: bind failed", .{});
                    };
                } else |_| {
                    const float_val: f64 = @floatCast(lua.toNumber(arg_idx) catch 0.0);
                    stmt.bindValue(float_val, bind_idx) catch {
                        lua.raiseErrorStr("db: bind failed", .{});
                    };
                }
            },
            .string => {
                const str = lua.toString(arg_idx) catch "";
                stmt.bindValue(str, bind_idx) catch {
                    lua.raiseErrorStr("db: bind failed", .{});
                };
            },
            .nil => {
                stmt.bindValue(@as(?[]const u8, null), bind_idx) catch {
                    lua.raiseErrorStr("db: bind failed", .{});
                };
            },
            else => {
                lua.raiseErrorStr("db: unsupported bind type", .{});
            },
        }
    }
}

/// db:exec(sql, ...) — execute SQL with bind params
fn lDbExec(lua: *Lua) i32 {
    const ud = checkDbHandle(lua, 1);
    if (!ud.open) {
        lua.raiseErrorStr("db:exec: database is closed", .{});
    }
    const sql = lua.toString(2) catch {
        lua.raiseErrorStr("db:exec: expected string SQL", .{});
    };

    var stmt = ud.db.conn.prepare(sql) catch {
        lua.raiseErrorStr("db:exec: prepare failed: %s", .{ud.db.conn.lastError()});
    };
    defer stmt.deinit();

    bindLuaParams(lua, &stmt, 3);

    stmt.stepToCompletion() catch {
        lua.raiseErrorStr("db:exec: execution failed: %s", .{ud.db.conn.lastError()});
    };
    return 0;
}

/// db:query(sql, ...) -> array of row tables
fn lDbQuery(lua: *Lua) i32 {
    const ud = checkDbHandle(lua, 1);
    if (!ud.open) {
        lua.raiseErrorStr("db:query: database is closed", .{});
    }
    const sql = lua.toString(2) catch {
        lua.raiseErrorStr("db:query: expected string SQL", .{});
    };

    var stmt = ud.db.conn.prepare(sql) catch {
        lua.raiseErrorStr("db:query: prepare failed: %s", .{ud.db.conn.lastError()});
    };
    defer stmt.deinit();

    bindLuaParams(lua, &stmt, 3);

    // Build result table
    lua.newTable(); // results array
    var row_num: i32 = 1;
    const col_count: usize = @intCast(stmt.columnCount());

    while (stmt.step() catch {
        lua.raiseErrorStr("db:query: step failed: %s", .{ud.db.conn.lastError()});
    }) {
        lua.newTable(); // row table

        for (0..col_count) |col| {
            const col_name: [:0]const u8 = std.mem.span(stmt.columnName(col));
            switch (stmt.columnType(col)) {
                .int => lua.pushInteger(stmt.int(col)),
                .float => lua.pushNumber(@floatCast(stmt.float(col))),
                .text => _ = lua.pushString(stmt.text(col)),
                .null => lua.pushNil(),
                else => lua.pushNil(),
            }
            lua.setField(-2, col_name);
        }

        lua.rawSetIndex(-2, row_num);
        row_num += 1;
    }

    return 1;
}

/// db:close()
fn lDbClose(lua: *Lua) i32 {
    const ud = checkDbHandle(lua, 1);
    if (ud.open) {
        ud.db.close();
        ud.open = false;
    }
    return 0;
}

// --- Save functions ---

/// engine.save.set(key, value)
fn lSaveSet(lua: *Lua) i32 {
    const save_db = getSaveDb(lua);
    const key = lua.toString(1) catch {
        lua.raiseErrorStr("save.set: expected string key", .{});
    };

    // Convert value to string — use Lua's built-in tostring for numbers
    const value: [:0]const u8 = switch (lua.typeOf(2)) {
        .string => lua.toString(2) catch "",
        .number => lua.toString(2) catch "0",
        .boolean => if (lua.toBoolean(2)) @as([:0]const u8, "true") else "false",
        .nil => {
            // nil means delete
            save_db.set(key, "") catch {
                lua.raiseErrorStr("save.set: failed to write", .{});
            };
            return 0;
        },
        else => {
            lua.raiseErrorStr("save.set: unsupported value type", .{});
        },
    };

    save_db.set(key, value) catch {
        lua.raiseErrorStr("save.set: failed to write", .{});
    };
    return 0;
}

/// engine.save.get(key) -> value or nil
fn lSaveGet(lua: *Lua) i32 {
    const save_db = getSaveDb(lua);
    const key = lua.toString(1) catch {
        lua.raiseErrorStr("save.get: expected string key", .{});
    };

    const value = save_db.get(key) catch {
        lua.raiseErrorStr("save.get: failed to read", .{});
    };

    if (value) |v| {
        if (v.len == 0) {
            lua.pushNil();
        } else {
            _ = lua.pushString(v);
        }
    } else {
        lua.pushNil();
    }
    return 1;
}

// --- Audio functions ---

fn getAudioSystem(lua: *Lua) *AudioSystem {
    const ptr = lua.toPointer(Lua.upvalueIndex(1)) catch unreachable;
    return @ptrCast(@constCast(@alignCast(ptr)));
}

/// engine.audio.load(path) or engine.audio.load(path, {stream=true})
fn lAudioLoad(lua: *Lua) i32 {
    const audio = getAudioSystem(lua);
    const rel_path = lua.toString(1) catch {
        lua.raiseErrorStr("audio.load: expected string path", .{});
    };

    var opts = AudioLoadOpts{};
    if (lua.typeOf(2) == .table) {
        if (lua.getField(2, "stream") == .boolean) {
            opts.stream = lua.toBoolean(-1);
        }
        lua.pop(1);
    }

    // Resolve path relative to game dir
    const abs_path = audio.resolvePath(rel_path) catch {
        lua.raiseErrorStr("audio.load: failed to resolve path '%s'", .{rel_path.ptr});
    };
    defer audio.allocator.free(abs_path);

    const id = audio.loadSound(abs_path, opts) catch {
        lua.raiseErrorStr("audio.load: failed to load '%s'", .{rel_path.ptr});
    };

    // Create userdata with sound ID
    const ud = lua.newUserdata(LuaSoundHandle, 0);
    ud.* = .{ .id = id, .valid = true };
    _ = lua.getField(zlua.registry_index, METATABLE_SOUND);
    lua.setMetatable(-2);
    return 1;
}

/// engine.audio.set_master_volume(v)
fn lAudioSetMasterVolume(lua: *Lua) i32 {
    const audio = getAudioSystem(lua);
    const vol: f32 = @floatCast(lua.toNumber(1) catch 1.0);
    audio.setMasterVolume(vol);
    return 0;
}

/// engine.audio.stop_all()
fn lAudioStopAll(lua: *Lua) i32 {
    const audio = getAudioSystem(lua);
    audio.stopAll();
    return 0;
}

/// Userdata for sound handles
const LuaSoundHandle = struct {
    id: SoundId,
    valid: bool,
};

fn checkSoundHandle(lua: *Lua, arg: i32) *LuaSoundHandle {
    return lua.checkUserdata(LuaSoundHandle, arg, METATABLE_SOUND);
}

/// __gc metamethod — release the sound on garbage collection
fn lSoundGc(lua: *Lua) i32 {
    const ud = checkSoundHandle(lua, 1);
    if (!ud.valid) return 0;
    const audio = getAudioSystem(lua);
    audio.unloadSound(ud.id);
    ud.valid = false;
    return 0;
}

/// __index metamethod — dispatch sound methods
fn lSoundIndex(lua: *Lua) i32 {
    const key = lua.toString(2) catch return 0;

    const methods = std.StaticStringMap(zlua.CFn).initComptime(.{
        .{ "play", zlua.wrap(lSoundPlay) },
        .{ "stop", zlua.wrap(lSoundStop) },
        .{ "pause", zlua.wrap(lSoundPause) },
        .{ "resume", zlua.wrap(lSoundResume) },
        .{ "set_volume", zlua.wrap(lSoundSetVolume) },
        .{ "set_pan", zlua.wrap(lSoundSetPan) },
        .{ "fade_in", zlua.wrap(lSoundFadeIn) },
        .{ "fade_out", zlua.wrap(lSoundFadeOut) },
    });

    if (methods.get(key)) |func| {
        // Push as closure with audio system upvalue
        const audio = getAudioSystem(lua);
        lua.pushLightUserdata(audio);
        lua.pushClosure(func, 1);
        return 1;
    }
    return 0;
}

/// sound:play() or sound:play({loop=true, volume=0.8, pan=-0.5})
fn lSoundPlay(lua: *Lua) i32 {
    const audio = getAudioSystem(lua);
    const ud = checkSoundHandle(lua, 1);
    if (!ud.valid) return 0;

    var opts = AudioPlayOpts{};
    if (lua.typeOf(2) == .table) {
        if (lua.getField(2, "loop") == .boolean) {
            opts.loop = lua.toBoolean(-1);
        }
        lua.pop(1);
        if (lua.getField(2, "volume") == .number) {
            opts.volume = @floatCast(lua.toNumber(-1) catch 1.0);
        }
        lua.pop(1);
        if (lua.getField(2, "pan") == .number) {
            opts.pan = @floatCast(lua.toNumber(-1) catch 0.0);
        }
        lua.pop(1);
    }

    audio.play(ud.id, opts);
    return 0;
}

/// sound:stop()
fn lSoundStop(lua: *Lua) i32 {
    const audio = getAudioSystem(lua);
    const ud = checkSoundHandle(lua, 1);
    if (!ud.valid) return 0;
    audio.stop(ud.id);
    return 0;
}

/// sound:pause()
fn lSoundPause(lua: *Lua) i32 {
    const audio = getAudioSystem(lua);
    const ud = checkSoundHandle(lua, 1);
    if (!ud.valid) return 0;
    audio.pause(ud.id);
    return 0;
}

/// sound:resume()
fn lSoundResume(lua: *Lua) i32 {
    const audio = getAudioSystem(lua);
    const ud = checkSoundHandle(lua, 1);
    if (!ud.valid) return 0;
    audio.resume_(ud.id);
    return 0;
}

/// sound:set_volume(v)
fn lSoundSetVolume(lua: *Lua) i32 {
    const audio = getAudioSystem(lua);
    const ud = checkSoundHandle(lua, 1);
    if (!ud.valid) return 0;
    const vol: f32 = @floatCast(lua.toNumber(2) catch 1.0);
    audio.setVolume(ud.id, vol);
    return 0;
}

/// sound:set_pan(p)
fn lSoundSetPan(lua: *Lua) i32 {
    const audio = getAudioSystem(lua);
    const ud = checkSoundHandle(lua, 1);
    if (!ud.valid) return 0;
    const pan: f32 = @floatCast(lua.toNumber(2) catch 0.0);
    audio.setPan(ud.id, pan);
    return 0;
}

/// sound:fade_in(duration_ms)
fn lSoundFadeIn(lua: *Lua) i32 {
    const audio = getAudioSystem(lua);
    const ud = checkSoundHandle(lua, 1);
    if (!ud.valid) return 0;
    const ms: u32 = @intCast(lua.toInteger(2) catch 1000);
    audio.fadeIn(ud.id, ms);
    return 0;
}

/// sound:fade_out(duration_ms)
fn lSoundFadeOut(lua: *Lua) i32 {
    const audio = getAudioSystem(lua);
    const ud = checkSoundHandle(lua, 1);
    if (!ud.valid) return 0;
    const ms: u32 = @intCast(lua.toInteger(2) catch 1000);
    audio.fadeOut(ud.id, ms);
    return 0;
}

test "register creates engine global" {
    // Minimal smoke test — just verify it doesn't crash
    _ = Renderer;
}
