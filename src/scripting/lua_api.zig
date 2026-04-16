const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;
const Compositing = @import("compositing");
const SpritePlacer = @import("sprite_placer");
const ImageMod = @import("image");
const lua_bind = @import("lua_bind");
const input_mod = @import("input");
const InputState = input_mod.InputState;
const audio_mod_ = @import("audio");
const AudioSystem = audio_mod_.AudioSystem;
const SoundId = audio_mod_.SoundId;
const AudioLoadOpts = audio_mod_.LoadOpts;
const AudioPlayOpts = audio_mod_.PlayOpts;
const SaveFs = @import("save").SaveFs;
const font_mod = @import("font");
const FontAtlas = font_mod.FontAtlas;
const DrawOpts = font_mod.DrawOpts;
const METATABLE_IMAGE = "VexelImage";
const METATABLE_SOUND = "VexelSound";
const METATABLE_FONT = "VexelFont";

const Color = Compositing.Color;

/// Userdata stored inside each Lua image handle.
pub const LuaImageHandle = struct {
    handle: ImageMod.ImageHandle,
    valid: bool,
};

/// Push a C closure with a pointer as upvalue 1.
fn pushUpvalueClosure(lua: *Lua, ptr: anytype, func: zlua.CFn) void {
    lua.pushLightUserdata(ptr);
    lua.pushClosure(func, 1);
}

/// Push a C closure with two pointers as upvalues.
fn pushUpvalueClosure2(lua: *Lua, ptr1: anytype, ptr2: anytype, func: zlua.CFn) void {
    lua.pushLightUserdata(ptr1);
    lua.pushLightUserdata(ptr2);
    lua.pushClosure(func, 2);
}

/// Extract a typed pointer from upvalue 1 of a C closure.
fn getUpvalue(lua: *Lua, comptime T: type) *T {
    const ptr = lua.toPointer(Lua.upvalueIndex(1)) catch unreachable;
    return @ptrCast(@constCast(@alignCast(ptr)));
}

/// Extract a typed pointer from upvalue 2 of a C closure.
fn getUpvalue2(lua: *Lua, comptime T: type) *T {
    const ptr = lua.toPointer(Lua.upvalueIndex(2)) catch unreachable;
    return @ptrCast(@constCast(@alignCast(ptr)));
}

pub const EngineContext = struct {
    compositor: *Compositing,
    sprite_placer: *SpritePlacer,
    screen_info: *SpritePlacer.ScreenInfo,
    image_manager: *ImageMod,
    shader_registry: *lua_bind.ShaderRegistry,
    input_state: *InputState,
    audio_system: ?*AudioSystem,
    save_fs: *SaveFs,
    default_font: *FontAtlas,
};

/// Heap-allocated FontAtlas wrapped in Lua userdata.
pub const LuaFontHandle = struct {
    font: *FontAtlas,
    valid: bool,
};

/// Register all engine.* API functions into the Lua state.
/// Call this after LuaEngine.init() but before loadGame().
pub fn register(lua: *Lua, ctx: EngineContext) void {
    const compositor = ctx.compositor;
    const sprite_placer = ctx.sprite_placer;
    const screen_info = ctx.screen_info;
    const image_manager = ctx.image_manager;
    const shader_registry = ctx.shader_registry;
    const input_state = ctx.input_state;
    const audio_system = ctx.audio_system;
    const save_fs = ctx.save_fs;
    const default_font = ctx.default_font;

    // Create VexelImage metatable with __gc
    lua.newMetatable(METATABLE_IMAGE) catch {};
    pushUpvalueClosure(lua, image_manager, zlua.wrap(lImageGc));
    lua.setField(-2, "__gc");
    lua.pop(1);

    // Create VexelFont metatable with __gc
    lua.newMetatable(METATABLE_FONT) catch {};
    lua.pushFunction(zlua.wrap(lFontGc));
    lua.setField(-2, "__gc");
    lua.pop(1);

    // Create the `engine` global table
    lua.newTable();

    // engine.graphics
    lua.newTable();

    pushUpvalueClosure2(lua, compositor, default_font, zlua.wrap(lDrawText));
    lua.setField(-2, "draw_text");
    pushUpvalueClosure(lua, screen_info, zlua.wrap(lGetSize));
    lua.setField(-2, "get_size");
    pushUpvalueClosure(lua, screen_info, zlua.wrap(lGetPixelSize));
    lua.setField(-2, "get_pixel_size");

    pushUpvalueClosure(lua, image_manager, zlua.wrap(lLoadFont));
    lua.setField(-2, "load_font");
    lua.pushFunction(zlua.wrap(lUnloadFont));
    lua.setField(-2, "unload_font");
    pushUpvalueClosure(lua, default_font, zlua.wrap(lGetTextWidth));
    lua.setField(-2, "get_text_width");
    pushUpvalueClosure(lua, default_font, zlua.wrap(lGetTextHeight));
    lua.setField(-2, "get_text_height");
    pushUpvalueClosure(lua, compositor, zlua.wrap(lSetScissor));
    lua.setField(-2, "set_scissor");

    pushUpvalueClosure(lua, compositor, zlua.wrap(lSetResolution));
    lua.setField(-2, "set_resolution");
    pushUpvalueClosure(lua, compositor, zlua.wrap(lGetResolution));
    lua.setField(-2, "get_resolution");
    pushUpvalueClosure(lua, compositor, zlua.wrap(lSetLayer));
    lua.setField(-2, "set_layer");
    pushUpvalueClosure(lua, compositor, zlua.wrap(lClearAll));
    lua.setField(-2, "clear_all");

    // Image/sprite functions
    pushUpvalueClosure(lua, image_manager, zlua.wrap(lLoadImage));
    lua.setField(-2, "load_image");
    pushUpvalueClosure(lua, image_manager, zlua.wrap(lLoadSpriteSheet));
    lua.setField(-2, "load_spritesheet");
    pushUpvalueClosure(lua, sprite_placer, zlua.wrap(lDrawSprite));
    lua.setField(-2, "draw_sprite");
    pushUpvalueClosure(lua, sprite_placer, zlua.wrap(lDrawFrame));
    lua.setField(-2, "draw_frame");
    pushUpvalueClosure(lua, image_manager, zlua.wrap(lUnloadImage));
    lua.setField(-2, "unload_image");
    pushUpvalueClosure(lua, image_manager, zlua.wrap(lGetFrameCount));
    lua.setField(-2, "get_frame_count");

    // engine.graphics.pixel
    lua.newTable();

    pushUpvalueClosure(lua, compositor, zlua.wrap(lPixelRect));
    lua.setField(-2, "rect");

    pushUpvalueClosure(lua, compositor, zlua.wrap(lPixelLine));
    lua.setField(-2, "line");

    pushUpvalueClosure(lua, compositor, zlua.wrap(lPixelCircle));
    lua.setField(-2, "circle");

    pushUpvalueClosure(lua, compositor, zlua.wrap(lPixelClear));
    lua.setField(-2, "clear");

    pushUpvalueClosure(lua, compositor, zlua.wrap(lPixelSet));
    lua.setField(-2, "set");

    pushUpvalueClosure(lua, compositor, zlua.wrap(lPixelBuffer));
    lua.setField(-2, "buffer");

    pushUpvalueClosure2(lua, compositor, shader_registry, zlua.wrap(lPixelShade));
    lua.setField(-2, "shade");

    lua.setField(-2, "pixel");

    lua.setField(-2, "graphics");

    // engine.input
    lua.newTable();
    pushUpvalueClosure(lua, input_state, zlua.wrap(lInputIsKeyDown));
    lua.setField(-2, "is_key_down");
    pushUpvalueClosure(lua, input_state, zlua.wrap(lInputGetMouse));
    lua.setField(-2, "get_mouse");
    pushUpvalueClosure(lua, input_state, zlua.wrap(lInputGetGamepad));
    lua.setField(-2, "get_gamepad");
    lua.setField(-2, "input");

    // engine.audio
    if (audio_system) |audio| {
        // Create VexelSound metatable
        lua.newMetatable(METATABLE_SOUND) catch {};
        pushUpvalueClosure(lua, audio, zlua.wrap(lSoundGc));
        lua.setField(-2, "__gc");
        pushUpvalueClosure(lua, audio, zlua.wrap(lSoundIndex));
        lua.setField(-2, "__index");
        lua.pop(1);

        lua.newTable();
        pushUpvalueClosure(lua, audio, zlua.wrap(lAudioLoad));
        lua.setField(-2, "load");
        pushUpvalueClosure(lua, audio, zlua.wrap(lAudioSetMasterVolume));
        lua.setField(-2, "set_master_volume");
        pushUpvalueClosure(lua, audio, zlua.wrap(lAudioStopAll));
        lua.setField(-2, "stop_all");
        lua.setField(-2, "audio");
    }

    // engine.save
    lua.newTable();
    pushUpvalueClosure(lua, save_fs, zlua.wrap(lSaveWriteFile));
    lua.setField(-2, "write_file");
    pushUpvalueClosure(lua, save_fs, zlua.wrap(lSaveReadFile));
    lua.setField(-2, "read_file");
    pushUpvalueClosure(lua, save_fs, zlua.wrap(lSaveDeleteFile));
    lua.setField(-2, "delete_file");
    pushUpvalueClosure(lua, save_fs, zlua.wrap(lSaveListFiles));
    lua.setField(-2, "list_files");
    lua.setField(-2, "save");

    lua.pushFunction(zlua.wrap(lQuitGame));
    lua.setField(-2, "quit");
    lua.pushBoolean(false);
    lua.setField(-2, "should_quit");

    lua.setGlobal("engine");

    // Install Lua-side serializer (engine.save.write / engine.save.read)
    lua.doString(save_serializer_lua) catch {
        std.debug.print("Failed to load save serializer\n", .{});
    };
}

// --- Helpers ---

fn luaOptionalColor(lua: *Lua, idx: i32) ?Color {
    const v = lua.toInteger(idx) catch return null;
    return Color.fromHex(@intCast(@as(i64, v)));
}

fn luaHexColor(lua: *Lua, idx: i32, default: u32) Color {
    return luaOptionalColor(lua, idx) orelse Color.fromHex(default);
}

fn lDrawText(lua: *Lua) i32 {
    const comp = getUpvalue(lua, Compositing);
    const default_font = getUpvalue2(lua, FontAtlas);
    const x: i32 = @intCast(lua.toInteger(1) catch 0);
    const y: i32 = @intCast(lua.toInteger(2) catch 0);
    const text = lua.toString(3) catch return 0;
    const color = luaHexColor(lua, 4, 0xFFFFFF);

    var opts = DrawOpts{};
    var atlas = default_font;

    if (lua.typeOf(5) == .table) {
        // opts.font: font userdata
        if (lua.getField(5, "font") == .userdata) {
            const ud = lua.toUserdata(LuaFontHandle, -1) catch null;
            if (ud) |h| {
                if (h.valid) atlas = h.font;
            }
        }
        lua.pop(1);

        // opts.width
        if (lua.getField(5, "width") == .number) {
            const w = lua.toInteger(-1) catch 0;
            if (w > 0) opts.width = @intCast(w);
        }
        lua.pop(1);

        // opts.align
        if (lua.getField(5, "align") == .string) {
            const s = lua.toString(-1) catch "";
            opts.alignment = std.meta.stringToEnum(DrawOpts.Align, s) orelse .left;
        }
        lua.pop(1);

        // opts.wrap
        if (lua.getField(5, "wrap") == .string) {
            const s = lua.toString(-1) catch "";
            opts.wrap = std.meta.stringToEnum(DrawOpts.Wrap, s) orelse .none;
        }
        lua.pop(1);
    }

    atlas.drawText(comp, x, y, text, color, opts);
    return 0;
}

fn lGetSize(lua: *Lua) i32 {
    const info = getUpvalue(lua, SpritePlacer.ScreenInfo);
    lua.pushInteger(@intCast(info.cols));
    lua.pushInteger(@intCast(info.rows));
    return 2;
}

fn lGetPixelSize(lua: *Lua) i32 {
    const info = getUpvalue(lua, SpritePlacer.ScreenInfo);
    lua.pushInteger(@intCast(info.x_pixel));
    lua.pushInteger(@intCast(info.y_pixel));
    return 2;
}

// --- Pixel drawing functions (upvalue: *Compositing) ---

fn lPixelRect(lua: *Lua) i32 {
    const comp = getUpvalue(lua, Compositing);
    const x: i32 = @intCast(lua.toInteger(1) catch 0);
    const y: i32 = @intCast(lua.toInteger(2) catch 0);
    const w: i32 = @intCast(lua.toInteger(3) catch 1);
    const h: i32 = @intCast(lua.toInteger(4) catch 1);
    comp.drawRect(x, y, w, h, luaHexColor(lua, 5, 0xFFFFFF));
    return 0;
}

fn lPixelLine(lua: *Lua) i32 {
    const comp = getUpvalue(lua, Compositing);
    const x1: i32 = @intCast(lua.toInteger(1) catch 0);
    const y1: i32 = @intCast(lua.toInteger(2) catch 0);
    const x2: i32 = @intCast(lua.toInteger(3) catch 0);
    const y2: i32 = @intCast(lua.toInteger(4) catch 0);
    comp.drawLine(x1, y1, x2, y2, luaHexColor(lua, 5, 0xFFFFFF));
    return 0;
}

fn lPixelCircle(lua: *Lua) i32 {
    const comp = getUpvalue(lua, Compositing);
    const cx: i32 = @intCast(lua.toInteger(1) catch 0);
    const cy: i32 = @intCast(lua.toInteger(2) catch 0);
    const r: i32 = @intCast(lua.toInteger(3) catch 1);
    comp.drawCircle(cx, cy, r, luaHexColor(lua, 4, 0xFFFFFF));
    return 0;
}

fn lPixelSet(lua: *Lua) i32 {
    const comp = getUpvalue(lua, Compositing);
    const x: i32 = @intCast(lua.toInteger(1) catch 0);
    const y: i32 = @intCast(lua.toInteger(2) catch 0);
    comp.setPixel(x, y, luaHexColor(lua, 3, 0xFFFFFF));
    return 0;
}

fn lPixelBuffer(lua: *Lua) i32 {
    const comp = getUpvalue(lua, Compositing);
    if (lua.typeOf(1) != .table) {
        lua.raiseErrorStr("pixel.buffer: expected table as first argument", .{});
    }
    const x: i32 = @intCast(lua.toInteger(2) catch 0);
    const y: i32 = @intCast(lua.toInteger(3) catch 0);
    const w: i32 = @intCast(lua.toInteger(4) catch 0);
    const h: i32 = @intCast(lua.toInteger(5) catch 0);
    if (w <= 0 or h <= 0) return 0;

    const count: usize = @intCast(w * h);
    const colors = comp.allocator.alloc(u32, count) catch return 0;
    defer comp.allocator.free(colors);

    for (0..count) |i| {
        _ = lua.rawGetIndex(1, @intCast(i + 1));
        const val = lua.toInteger(-1) catch 0;
        colors[i] = Color.fromHex(@intCast(@as(i64, val))).pack();
        lua.pop(1);
    }

    comp.blitBuffer(x, y, w, h, colors);
    return 0;
}

fn lPixelShade(lua: *Lua) i32 {
    const comp = getUpvalue(lua, Compositing);
    const registry = getUpvalue2(lua, lua_bind.ShaderRegistry);
    const name = lua.toString(1) catch {
        lua.raiseErrorStr("pixel.shade: expected shader name as first argument", .{});
    };
    const dispatch = registry.find(name) orelse {
        lua.raiseErrorStr("pixel.shade: unknown shader '%s'", .{name.ptr});
    };

    if (comp.width == 0 or comp.height == 0) return 0;

    const buf = comp.getActiveLayerSlice();
    dispatch(buf, comp.width, comp.height, lua);
    return 0;
}

fn lPixelClear(lua: *Lua) i32 {
    const comp = getUpvalue(lua, Compositing);
    comp.clearLayer();
    return 0;
}

// --- Font functions ---

fn pushFontUserdata(lua: *Lua, font: *FontAtlas) void {
    const ud = lua.newUserdata(LuaFontHandle, 0);
    ud.* = .{ .font = font, .valid = true };
    _ = lua.getField(zlua.registry_index, METATABLE_FONT);
    lua.setMetatable(-2);
}

fn releaseFontHandle(ud: *LuaFontHandle) void {
    if (!ud.valid) return;
    const alloc = ud.font.allocator;
    ud.font.deinit();
    alloc.destroy(ud.font);
    ud.valid = false;
}

fn lFontGc(lua: *Lua) i32 {
    releaseFontHandle(lua.checkUserdata(LuaFontHandle, 1, METATABLE_FONT));
    return 0;
}

/// engine.graphics.load_font(path, size)          — TTF at pixel_height=size
/// engine.graphics.load_font(path, glyph_w, glyph_h) — bitmap PNG
fn lLoadFont(lua: *Lua) i32 {
    const mgr = getUpvalue(lua, ImageMod);
    const rel_path = lua.toString(1) catch {
        lua.raiseErrorStr("load_font: expected string path", .{});
    };
    const size: u16 = @intCast(lua.toInteger(2) catch {
        lua.raiseErrorStr("load_font: expected integer size", .{});
    });

    const full_path = std.fmt.allocPrint(mgr.allocator, "{s}/{s}", .{ mgr.game_dir, rel_path }) catch {
        lua.raiseErrorStr("load_font: out of memory", .{});
    };
    defer mgr.allocator.free(full_path);

    const font_ptr = mgr.allocator.create(FontAtlas) catch {
        lua.raiseErrorStr("load_font: out of memory", .{});
    };
    errdefer mgr.allocator.destroy(font_ptr);

    // 3 args → bitmap PNG (glyph_w=size, glyph_h=arg3)
    if (lua.typeOf(3) == .number) {
        const glyph_h: u8 = @intCast(lua.toInteger(3) catch size);
        const glyph_w: u8 = @intCast(size);

        // Load PNG via image manager to get RGBA pixels
        const handle = mgr.loadImage(rel_path) catch {
            lua.raiseErrorStr("load_font: failed to load image '%s'", .{rel_path.ptr});
        };
        defer mgr.unloadImage(handle);

        const info = mgr.getImageInfo(handle) orelse {
            lua.raiseErrorStr("load_font: no pixel data for '%s'", .{rel_path.ptr});
        };

        font_ptr.* = FontAtlas.loadFromBitmap(
            mgr.allocator,
            info.pixels,
            @intCast(info.width),
            @intCast(info.height),
            glyph_w,
            glyph_h,
        ) catch {
            lua.raiseErrorStr("load_font: invalid bitmap font '%s'", .{rel_path.ptr});
        };
    } else {
        // 2 args → TTF
        const ttf_data = std.fs.cwd().readFileAlloc(mgr.allocator, full_path, 16 * 1024 * 1024) catch {
            lua.raiseErrorStr("load_font: failed to read '%s'", .{rel_path.ptr});
        };
        defer mgr.allocator.free(ttf_data);

        font_ptr.* = FontAtlas.loadFromTtf(mgr.allocator, ttf_data, size) catch {
            lua.raiseErrorStr("load_font: failed to rasterize TTF '%s'", .{rel_path.ptr});
        };
    }

    pushFontUserdata(lua, font_ptr);
    return 1;
}

/// engine.graphics.unload_font(font)
fn lUnloadFont(lua: *Lua) i32 {
    releaseFontHandle(lua.checkUserdata(LuaFontHandle, 1, METATABLE_FONT));
    return 0;
}

/// Resolve the FontAtlas to use: return ud.font if arg at idx is a valid VexelFont userdata,
/// otherwise return default.
fn resolveFont(lua: *Lua, idx: i32, default: *FontAtlas) *FontAtlas {
    if (lua.typeOf(idx) == .userdata) {
        if (lua.toUserdata(LuaFontHandle, idx) catch null) |ud| {
            if (ud.valid) return ud.font;
        }
    }
    return default;
}

/// engine.graphics.get_text_width(text, [font]) → int
fn lGetTextWidth(lua: *Lua) i32 {
    const default_font = getUpvalue(lua, FontAtlas);
    const text = lua.toString(1) catch {
        lua.pushInteger(0);
        return 1;
    };
    lua.pushInteger(@intCast(resolveFont(lua, 2, default_font).measureText(text)));
    return 1;
}

/// engine.graphics.get_text_height([font]) → int
fn lGetTextHeight(lua: *Lua) i32 {
    const default_font = getUpvalue(lua, FontAtlas);
    lua.pushInteger(@intCast(resolveFont(lua, 1, default_font).line_height));
    return 1;
}

/// engine.graphics.set_scissor(x,y,w,h) or set_scissor() to clear
fn lSetScissor(lua: *Lua) i32 {
    const comp = getUpvalue(lua, Compositing);
    if (lua.typeOf(1) == .nil or lua.typeOf(1) == .none) {
        comp.clearScissor();
    } else {
        const x: i32 = @intCast(lua.toInteger(1) catch 0);
        const y: i32 = @intCast(lua.toInteger(2) catch 0);
        const w: i32 = @intCast(lua.toInteger(3) catch 0);
        const h: i32 = @intCast(lua.toInteger(4) catch 0);
        comp.setScissor(x, y, w, h);
    }
    return 0;
}

fn lSetResolution(lua: *Lua) i32 {
    const comp = getUpvalue(lua, Compositing);
    const w: u16 = @intCast(lua.toInteger(1) catch 320);
    const h: u16 = @intCast(lua.toInteger(2) catch 180);
    comp.setResolution(w, h) catch {
        lua.raiseErrorStr("failed to set resolution", .{});
    };
    return 0;
}

fn lGetResolution(lua: *Lua) i32 {
    const comp = getUpvalue(lua, Compositing);
    lua.pushInteger(@intCast(comp.width));
    lua.pushInteger(@intCast(comp.height));
    return 2;
}

fn lSetLayer(lua: *Lua) i32 {
    const comp = getUpvalue(lua, Compositing);
    const layer: u8 = @intCast(lua.toInteger(1) catch 0);
    comp.setActiveLayer(layer);
    return 0;
}

fn lClearAll(lua: *Lua) i32 {
    const comp = getUpvalue(lua, Compositing);
    comp.clearAll();
    return 0;
}

// --- Image/sprite functions ---

fn pushImageUserdata(lua: *Lua, handle: ImageMod.ImageHandle) void {
    const ud = lua.newUserdata(LuaImageHandle, 0);
    ud.* = .{ .handle = handle, .valid = true };
    _ = lua.getField(zlua.registry_index, METATABLE_IMAGE);
    lua.setMetatable(-2);
}

fn checkImageHandle(lua: *Lua, arg: i32) *LuaImageHandle {
    return lua.checkUserdata(LuaImageHandle, arg, METATABLE_IMAGE);
}

fn lLoadImage(lua: *Lua) i32 {
    const mgr = getUpvalue(lua, ImageMod);
    const path = lua.toString(1) catch {
        lua.raiseErrorStr("load_image: expected string path", .{});
    };
    const handle = mgr.loadImage(path) catch {
        lua.raiseErrorStr("load_image: failed to load '%s'", .{path.ptr});
    };
    mgr.uploadVariant(handle, .none, 1);
    pushImageUserdata(lua, handle);
    return 1;
}

fn lLoadSpriteSheet(lua: *Lua) i32 {
    const mgr = getUpvalue(lua, ImageMod);
    const path = lua.toString(1) catch {
        lua.raiseErrorStr("load_spritesheet: expected string path", .{});
    };
    const tile_w: u16 = @intCast(lua.toInteger(2) catch {
        lua.raiseErrorStr("load_spritesheet: expected tile_w", .{});
    });
    const tile_h: u16 = @intCast(lua.toInteger(3) catch {
        lua.raiseErrorStr("load_spritesheet: expected tile_h", .{});
    });
    const handle = mgr.loadSpriteSheet(path, tile_w, tile_h) catch {
        lua.raiseErrorStr("load_spritesheet: failed to load '%s'", .{path.ptr});
    };
    mgr.uploadVariant(handle, .none, 1);
    pushImageUserdata(lua, handle);
    return 1;
}

fn lDrawSprite(lua: *Lua) i32 {
    const placer = getUpvalue(lua, SpritePlacer);
    const ud = checkImageHandle(lua, 1);
    if (!ud.valid) return 0;

    const x: i32 = @intCast(lua.toInteger(2) catch 0);
    const y: i32 = @intCast(lua.toInteger(3) catch 0);

    var opts = SpritePlacer.DrawSpriteOpts{};
    if (lua.typeOf(4) == .table) {
        if (lua.getField(4, "frame") == .number) {
            opts.frame = @intCast(lua.toInteger(-1) catch 0);
        }
        lua.pop(1);
        if (lua.getField(4, "flip_x") == .boolean) {
            opts.flip_x = lua.toBoolean(-1);
        }
        lua.pop(1);
        if (lua.getField(4, "flip_y") == .boolean) {
            opts.flip_y = lua.toBoolean(-1);
        }
        lua.pop(1);
        if (lua.getField(4, "scale") == .number) {
            const s = lua.toInteger(-1) catch 1;
            opts.scale = if (s < 1) 1 else if (s > 8) 8 else @intCast(s);
        }
        lua.pop(1);
    }

    placer.drawSprite(ud.handle, x, y, opts);
    return 0;
}

fn lDrawFrame(lua: *Lua) i32 {
    const placer = getUpvalue(lua, SpritePlacer);
    const ud = checkImageHandle(lua, 1);
    if (!ud.valid) return 0;

    const frame_idx: u32 = @intCast(lua.toInteger(2) catch 0);
    const x: i32 = @intCast(lua.toInteger(3) catch 0);
    const y: i32 = @intCast(lua.toInteger(4) catch 0);

    placer.drawSprite(ud.handle, x, y, .{ .frame = frame_idx });
    return 0;
}

fn lUnloadImage(lua: *Lua) i32 {
    releaseImageHandle(lua, checkImageHandle(lua, 1));
    return 0;
}

fn lGetFrameCount(lua: *Lua) i32 {
    const mgr = getUpvalue(lua, ImageMod);
    const ud = checkImageHandle(lua, 1);
    if (!ud.valid) {
        lua.pushInteger(0);
        return 1;
    }
    lua.pushInteger(@intCast(mgr.getFrameCount(ud.handle)));
    return 1;
}

fn lImageGc(lua: *Lua) i32 {
    releaseImageHandle(lua, checkImageHandle(lua, 1));
    return 0;
}

fn releaseImageHandle(lua: *Lua, ud: *LuaImageHandle) void {
    if (!ud.valid) return;
    const mgr = getUpvalue(lua, ImageMod);
    mgr.unloadImage(ud.handle);
    ud.valid = false;
}

// --- Input functions ---

fn lInputIsKeyDown(lua: *Lua) i32 {
    const input_state = getUpvalue(lua, InputState);
    const key = lua.toString(1) catch {
        lua.pushBoolean(false);
        return 1;
    };
    lua.pushBoolean(input_state.isKeyDown(key));
    return 1;
}

fn lInputGetMouse(lua: *Lua) i32 {
    const input_state = getUpvalue(lua, InputState);
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
    const input_state = getUpvalue(lua, InputState);
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

// --- Save functions ---

/// engine.save.write_file(name, content)
fn lSaveWriteFile(lua: *Lua) i32 {
    const save_fs = getUpvalue(lua, SaveFs);
    const name = lua.toString(1) catch {
        lua.raiseErrorStr("save.write_file: expected string name", .{});
    };
    const content = lua.toString(2) catch {
        lua.raiseErrorStr("save.write_file: expected string content", .{});
    };

    save_fs.writeFile(name, content) catch |err| {
        if (err == error.InvalidName) {
            lua.raiseErrorStr("save.write_file: invalid name '%s'", .{name.ptr});
        }
        lua.raiseErrorStr("save.write_file: write failed", .{});
    };
    return 0;
}

/// engine.save.read_file(name) -> string or nil
fn lSaveReadFile(lua: *Lua) i32 {
    const save_fs = getUpvalue(lua, SaveFs);
    const name = lua.toString(1) catch {
        lua.raiseErrorStr("save.read_file: expected string name", .{});
    };

    const content = save_fs.readFile(name) catch |err| {
        if (err == error.InvalidName) {
            lua.raiseErrorStr("save.read_file: invalid name '%s'", .{name.ptr});
        }
        lua.raiseErrorStr("save.read_file: read failed", .{});
    };

    if (content) |c| {
        _ = lua.pushString(c);
        save_fs.allocator.free(c);
    } else {
        lua.pushNil();
    }
    return 1;
}

/// engine.save.delete_file(name)
fn lSaveDeleteFile(lua: *Lua) i32 {
    const save_fs = getUpvalue(lua, SaveFs);
    const name = lua.toString(1) catch {
        lua.raiseErrorStr("save.delete_file: expected string name", .{});
    };

    save_fs.deleteFile(name) catch |err| {
        if (err == error.InvalidName) {
            lua.raiseErrorStr("save.delete_file: invalid name '%s'", .{name.ptr});
        }
        lua.raiseErrorStr("save.delete_file: delete failed", .{});
    };
    return 0;
}

/// engine.save.list_files() -> array of name strings
fn lSaveListFiles(lua: *Lua) i32 {
    const save_fs = getUpvalue(lua, SaveFs);

    const names = save_fs.listFiles(save_fs.allocator) catch {
        lua.raiseErrorStr("save.list_files: failed to list", .{});
    };
    defer {
        for (names) |n| save_fs.allocator.free(n);
        save_fs.allocator.free(names);
    }

    lua.newTable();
    for (names, 1..) |name, i| {
        _ = lua.pushString(name);
        lua.rawSetIndex(-2, @intCast(i));
    }
    return 1;
}

/// Bundled Lua serializer — installs engine.save.write() and engine.save.read()
const save_serializer_lua =
    \\local function serialize_value(v, indent)
    \\    local t = type(v)
    \\    if t == "string" then
    \\        return string.format("%q", v)
    \\    elseif t == "number" then
    \\        if v ~= v then return "0/0"
    \\        elseif v == 1/0 then return "1/0"
    \\        elseif v == -1/0 then return "-1/0"
    \\        elseif v == math.floor(v) then return string.format("%d", v)
    \\        else return string.format("%.17g", v)
    \\        end
    \\    elseif t == "boolean" then
    \\        return tostring(v)
    \\    elseif t == "nil" then
    \\        return "nil"
    \\    elseif t == "table" then
    \\        if getmetatable(v) then error("cannot serialize table with metatable") end
    \\        local inner = indent .. "  "
    \\        local parts = {}
    \\        -- Array part
    \\        local n = #v
    \\        for i = 1, n do
    \\            parts[#parts+1] = inner .. serialize_value(v[i], inner)
    \\        end
    \\        -- Hash part
    \\        local seen = {}
    \\        for i = 1, n do seen[i] = true end
    \\        local keys = {}
    \\        for k in pairs(v) do
    \\            if not seen[k] then keys[#keys+1] = k end
    \\        end
    \\        table.sort(keys, function(a, b)
    \\            if type(a) == type(b) then return a < b end
    \\            return type(a) < type(b)
    \\        end)
    \\        for _, k in ipairs(keys) do
    \\            local ks
    \\            if type(k) == "string" and k:match("^[%a_][%w_]*$") then
    \\                ks = k
    \\            else
    \\                ks = "[" .. serialize_value(k, inner) .. "]"
    \\            end
    \\            parts[#parts+1] = inner .. ks .. " = " .. serialize_value(v[k], inner)
    \\        end
    \\        if #parts == 0 then return "{}" end
    \\        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
    \\    else
    \\        error("cannot serialize " .. t)
    \\    end
    \\end
    \\
    \\engine.save.write = function(name, tbl)
    \\    if type(tbl) ~= "table" then
    \\        error("save.write: expected table, got " .. type(tbl))
    \\    end
    \\    engine.save.write_file(name, "return " .. serialize_value(tbl, "") .. "\n")
    \\end
    \\
    \\engine.save.read = function(name)
    \\    local str = engine.save.read_file(name)
    \\    if not str then return nil end
    \\    local fn, err = load(str, "save:" .. name, "t", {})
    \\    if not fn then error("corrupt save '" .. name .. "': " .. err) end
    \\    return fn()
    \\end
;

// --- Audio functions ---

/// engine.audio.load(path) or engine.audio.load(path, {stream=true})
fn lAudioLoad(lua: *Lua) i32 {
    const audio = getUpvalue(lua, AudioSystem);
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
    const audio = getUpvalue(lua, AudioSystem);
    const vol: f32 = @floatCast(lua.toNumber(1) catch 1.0);
    audio.setMasterVolume(vol);
    return 0;
}

/// engine.audio.stop_all()
fn lAudioStopAll(lua: *Lua) i32 {
    const audio = getUpvalue(lua, AudioSystem);
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
    const audio = getUpvalue(lua, AudioSystem);
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
        const audio = getUpvalue(lua, AudioSystem);
        lua.pushLightUserdata(audio);
        lua.pushClosure(func, 1);
        return 1;
    }
    return 0;
}

/// sound:play() or sound:play({loop=true, volume=0.8, pan=-0.5})
fn lSoundPlay(lua: *Lua) i32 {
    const audio = getUpvalue(lua, AudioSystem);
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
    const audio = getUpvalue(lua, AudioSystem);
    const ud = checkSoundHandle(lua, 1);
    if (!ud.valid) return 0;
    audio.stop(ud.id);
    return 0;
}

/// sound:pause()
fn lSoundPause(lua: *Lua) i32 {
    const audio = getUpvalue(lua, AudioSystem);
    const ud = checkSoundHandle(lua, 1);
    if (!ud.valid) return 0;
    audio.pause(ud.id);
    return 0;
}

/// sound:resume()
fn lSoundResume(lua: *Lua) i32 {
    const audio = getUpvalue(lua, AudioSystem);
    const ud = checkSoundHandle(lua, 1);
    if (!ud.valid) return 0;
    audio.resume_(ud.id);
    return 0;
}

/// sound:set_volume(v)
fn lSoundSetVolume(lua: *Lua) i32 {
    const audio = getUpvalue(lua, AudioSystem);
    const ud = checkSoundHandle(lua, 1);
    if (!ud.valid) return 0;
    const vol: f32 = @floatCast(lua.toNumber(2) catch 1.0);
    audio.setVolume(ud.id, vol);
    return 0;
}

/// sound:set_pan(p)
fn lSoundSetPan(lua: *Lua) i32 {
    const audio = getUpvalue(lua, AudioSystem);
    const ud = checkSoundHandle(lua, 1);
    if (!ud.valid) return 0;
    const pan: f32 = @floatCast(lua.toNumber(2) catch 0.0);
    audio.setPan(ud.id, pan);
    return 0;
}

/// sound:fade_in(duration_ms)
fn lSoundFadeIn(lua: *Lua) i32 {
    const audio = getUpvalue(lua, AudioSystem);
    const ud = checkSoundHandle(lua, 1);
    if (!ud.valid) return 0;
    const ms: u32 = @intCast(lua.toInteger(2) catch 1000);
    audio.fadeIn(ud.id, ms);
    return 0;
}

/// sound:fade_out(duration_ms)
fn lSoundFadeOut(lua: *Lua) i32 {
    const audio = getUpvalue(lua, AudioSystem);
    const ud = checkSoundHandle(lua, 1);
    if (!ud.valid) return 0;
    const ms: u32 = @intCast(lua.toInteger(2) catch 1000);
    audio.fadeOut(ud.id, ms);
    return 0;
}

test "register creates engine global" {
    _ = Compositing;
}
