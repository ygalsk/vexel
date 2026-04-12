const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;
const Renderer = @import("renderer");
const ImageMod = @import("image");

const SpriteSystem = @This();

pub const METATABLE_SPRITE = "VexelSprite";
const METATABLE_IMAGE = "VexelImage";

pub const SpriteId = u32;

pub const LuaImageHandle = struct {
    handle: Renderer.ImageHandle,
    valid: bool,
};

const AnimationState = struct {
    frames: []u32,
    speed: f32,
    loop: bool,
    sheet_handle: Renderer.ImageHandle,
    current_index: u32 = 0,
    timer: f32 = 0,
};

const RetainedSprite = struct {
    x: f32 = 0,
    y: f32 = 0,
    scale: u8 = 1,
    flip_x: bool = false,
    flip_y: bool = false,
    layer: u8 = 1,
    visible: bool = true,
    frame: u32 = 0,
    image_handle: Renderer.ImageHandle,
    anim: ?AnimationState = null,
    on_complete_ref: i32 = zlua.ref_no,
    anim_table_ref: i32 = zlua.ref_no,
    alive: bool = true,
};

const Slot = union(enum) {
    occupied: RetainedSprite,
    free: ?u32,
};

allocator: std.mem.Allocator,
slots: std.ArrayList(Slot),
first_free: ?u32 = null,

pub fn init(allocator: std.mem.Allocator) SpriteSystem {
    return .{
        .allocator = allocator,
        .slots = .{},
    };
}

pub fn deinit(self: *SpriteSystem) void {
    for (self.slots.items) |*slot| {
        switch (slot.*) {
            .occupied => |*sprite| self.clearAnimation(sprite, null),
            .free => {},
        }
    }
    self.slots.deinit(self.allocator);
}

pub fn createSprite(self: *SpriteSystem, handle: Renderer.ImageHandle) !SpriteId {
    const sprite = RetainedSprite{ .image_handle = handle };

    if (self.first_free) |free_idx| {
        const slot = &self.slots.items[free_idx];
        self.first_free = slot.free;
        slot.* = .{ .occupied = sprite };
        return free_idx;
    }

    try self.slots.append(self.allocator, .{ .occupied = sprite });
    return @intCast(self.slots.items.len - 1);
}

pub fn destroySprite(self: *SpriteSystem, id: SpriteId, lua: *Lua) void {
    if (id >= self.slots.items.len) return;
    const slot = &self.slots.items[id];
    switch (slot.*) {
        .occupied => |*sprite| {
            self.clearAnimation(sprite, lua);
            slot.* = .{ .free = self.first_free };
            self.first_free = id;
        },
        .free => {},
    }
}

/// Free animation state, Lua refs, and reset fields. Pass null for lua during deinit.
fn clearAnimation(self: *SpriteSystem, sprite: *RetainedSprite, lua: ?*Lua) void {
    if (sprite.anim) |anim| {
        self.allocator.free(anim.frames);
        sprite.anim = null;
    }
    if (lua) |l| {
        if (sprite.on_complete_ref != zlua.ref_no) {
            l.unref(zlua.registry_index, sprite.on_complete_ref);
            sprite.on_complete_ref = zlua.ref_no;
        }
        if (sprite.anim_table_ref != zlua.ref_no) {
            l.unref(zlua.registry_index, sprite.anim_table_ref);
            sprite.anim_table_ref = zlua.ref_no;
        }
    }
}

fn getSprite(self: *SpriteSystem, id: SpriteId) ?*RetainedSprite {
    if (id >= self.slots.items.len) return null;
    return switch (self.slots.items[id]) {
        .occupied => |*s| s,
        .free => null,
    };
}

/// Advance all active animation timers. Call once per frame before rendering.
pub fn updateAnimations(self: *SpriteSystem, dt: f32, lua: *Lua) void {
    for (self.slots.items) |*slot| {
        switch (slot.*) {
            .occupied => |*sprite| {
                if (!sprite.alive) continue;
                const anim = &(sprite.anim orelse continue);
                if (anim.frames.len == 0) continue;

                anim.timer += dt;
                while (anim.timer >= anim.speed) {
                    anim.timer -= anim.speed;
                    anim.current_index += 1;

                    if (anim.current_index >= anim.frames.len) {
                        if (anim.loop) {
                            anim.current_index = 0;
                        } else {
                            anim.current_index = @intCast(anim.frames.len - 1);
                            // Fire on_complete callback
                            if (sprite.on_complete_ref != zlua.ref_no) {
                                _ = lua.rawGetIndex(zlua.registry_index, sprite.on_complete_ref);
                                lua.protectedCall(.{ .args = 0, .results = 0 }) catch {};
                            }
                            break;
                        }
                    }
                }
                sprite.frame = anim.frames[anim.current_index];
            },
            .free => {},
        }
    }
}

/// Render all alive+visible retained sprites via the existing drawSprite path.
pub fn renderAll(self: *const SpriteSystem, renderer: *Renderer) void {
    // Render in layer order (0..7) so layering is correct
    for (0..8) |layer| {
        for (self.slots.items) |slot| {
            switch (slot) {
                .occupied => |sprite| {
                    if (!sprite.alive or !sprite.visible) continue;
                    if (sprite.layer != @as(u8, @intCast(layer))) continue;

                    const draw_handle = if (sprite.anim) |anim| anim.sheet_handle else sprite.image_handle;

                    renderer.pixelSetLayer(sprite.layer);
                    renderer.drawSprite(draw_handle, @intFromFloat(sprite.x), @intFromFloat(sprite.y), .{
                        .frame = sprite.frame,
                        .flip_x = sprite.flip_x,
                        .flip_y = sprite.flip_y,
                        .scale = sprite.scale,
                    });
                },
                .free => {},
            }
        }
    }
}

// ── Lua C functions ──

/// Extract the SpriteSystem pointer from upvalue 1.
fn getSystem(lua: *Lua) *SpriteSystem {
    const ptr = lua.toPointer(Lua.upvalueIndex(1)) catch unreachable;
    return @ptrCast(@constCast(@alignCast(ptr)));
}

/// Extract the Renderer pointer from upvalue 2.
fn getRendererFromUpvalue(lua: *Lua) *Renderer {
    const ptr = lua.toPointer(Lua.upvalueIndex(2)) catch unreachable;
    return @ptrCast(@constCast(@alignCast(ptr)));
}

/// Extract the sprite ID from the proxy table at the given stack index.
fn getSpriteId(lua: *Lua, idx: i32) ?SpriteId {
    const field_type = lua.getField(idx, "_id");
    defer lua.pop(1);
    if (field_type != .number) return null;
    const id = lua.toInteger(-1) catch return null;
    if (id < 0) return null;
    return @intCast(id);
}

/// engine.sprite(image_handle) -> proxy table
pub fn lNewSprite(lua: *Lua) i32 {
    const system = getSystem(lua);

    // Arg 1: VexelImage userdata
    const image_ud = lua.checkUserdata(LuaImageHandle, 1, METATABLE_IMAGE);
    if (!image_ud.valid) {
        lua.raiseErrorStr("sprite: invalid image handle", .{});
    }

    const id = system.createSprite(image_ud.handle) catch {
        lua.raiseErrorStr("sprite: failed to allocate sprite", .{});
    };

    // Create proxy table
    lua.newTable();

    // Store sprite ID
    lua.pushInteger(@intCast(id));
    lua.setField(-2, "_id");

    // Set metatable
    _ = lua.getField(zlua.registry_index, METATABLE_SPRITE);
    lua.setMetatable(-2);

    return 1;
}

/// __index metamethod: read property or return method
pub fn lSpriteIndex(lua: *Lua) i32 {
    const system = getSystem(lua);
    const key = lua.toString(2) catch return 0;

    // Check for methods first
    if (std.mem.eql(u8, key, "destroy")) {
        // Push the destroy function (with system + renderer upvalues)
        lua.pushLightUserdata(system);
        lua.pushLightUserdata(@constCast(@ptrCast(getRendererFromUpvalue(lua))));
        lua.pushClosure(zlua.wrap(lSpriteDestroy), 2);
        return 1;
    }

    const id = getSpriteId(lua, 1) orelse return 0;
    const sprite = system.getSprite(id) orelse return 0;

    if (std.mem.eql(u8, key, "x")) {
        lua.pushNumber(sprite.x);
    } else if (std.mem.eql(u8, key, "y")) {
        lua.pushNumber(sprite.y);
    } else if (std.mem.eql(u8, key, "flip_x")) {
        lua.pushBoolean(sprite.flip_x);
    } else if (std.mem.eql(u8, key, "flip_y")) {
        lua.pushBoolean(sprite.flip_y);
    } else if (std.mem.eql(u8, key, "scale")) {
        lua.pushInteger(@intCast(sprite.scale));
    } else if (std.mem.eql(u8, key, "layer")) {
        lua.pushInteger(@intCast(sprite.layer));
    } else if (std.mem.eql(u8, key, "visible")) {
        lua.pushBoolean(sprite.visible);
    } else if (std.mem.eql(u8, key, "frame")) {
        lua.pushInteger(@intCast(sprite.frame));
    } else {
        lua.pushNil();
    }
    return 1;
}

/// __newindex metamethod: write property
pub fn lSpriteNewIndex(lua: *Lua) i32 {
    const system = getSystem(lua);
    const key = lua.toString(2) catch return 0;
    const id = getSpriteId(lua, 1) orelse return 0;
    const sprite = system.getSprite(id) orelse return 0;

    if (std.mem.eql(u8, key, "x")) {
        sprite.x = @floatCast(lua.toNumber(3) catch 0);
    } else if (std.mem.eql(u8, key, "y")) {
        sprite.y = @floatCast(lua.toNumber(3) catch 0);
    } else if (std.mem.eql(u8, key, "flip_x")) {
        sprite.flip_x = lua.toBoolean(3);
    } else if (std.mem.eql(u8, key, "flip_y")) {
        sprite.flip_y = lua.toBoolean(3);
    } else if (std.mem.eql(u8, key, "scale")) {
        const s = lua.toInteger(3) catch 1;
        sprite.scale = if (s < 1) 1 else if (s > 8) 8 else @intCast(s);
    } else if (std.mem.eql(u8, key, "layer")) {
        const l = lua.toInteger(3) catch 1;
        sprite.layer = if (l < 0) 0 else if (l > 7) 7 else @intCast(l);
    } else if (std.mem.eql(u8, key, "visible")) {
        sprite.visible = lua.toBoolean(3);
    } else if (std.mem.eql(u8, key, "frame")) {
        sprite.frame = @intCast(lua.toInteger(3) catch 0);
        system.clearAnimation(sprite, lua);
    } else if (std.mem.eql(u8, key, "animation")) {
        setAnimation(system, sprite, lua);
    } else if (std.mem.eql(u8, key, "on_complete")) {
        // Unref old callback
        if (sprite.on_complete_ref != zlua.ref_no) {
            lua.unref(zlua.registry_index, sprite.on_complete_ref);
            sprite.on_complete_ref = zlua.ref_no;
        }
        if (lua.typeOf(3) == .function) {
            lua.pushValue(3);
            sprite.on_complete_ref = lua.ref(zlua.registry_index) catch zlua.ref_no;
        }
    } else {
        // Unknown property: store on the table via rawset so it doesn't loop
        lua.pushValue(2);
        lua.pushValue(3);
        lua.rawSetTable(1);
    }
    return 0;
}

/// Parse a Lua animation table (at stack index 3) and apply it to the sprite.
fn setAnimation(system: *SpriteSystem, sprite: *RetainedSprite, lua: *Lua) void {
    // nil clears the animation
    if (lua.typeOf(3) == .nil) {
        system.clearAnimation(sprite, lua);
        return;
    }

    if (lua.typeOf(3) != .table) return;

    // Identity check: if same table as current, don't restart
    if (sprite.anim_table_ref != zlua.ref_no) {
        _ = lua.rawGetIndex(zlua.registry_index, sprite.anim_table_ref);
        const same = lua.rawEqual(3, -1);
        lua.pop(1);
        if (same) return;
    }

    // Read sheet (optional, defaults to sprite's base image)
    const sheet_handle: Renderer.ImageHandle = blk: {
        const ft = lua.getField(3, "sheet");
        defer lua.pop(1);
        if (ft == .userdata) {
            const ud = lua.checkUserdata(LuaImageHandle, -1, METATABLE_IMAGE);
            if (ud.valid) break :blk ud.handle;
        }
        break :blk sprite.image_handle;
    };

    // Read speed
    const speed: f32 = blk: {
        if (lua.getField(3, "speed") == .number) {
            defer lua.pop(1);
            break :blk @floatCast(lua.toNumber(-1) catch 0.1);
        }
        lua.pop(1);
        break :blk 0.1;
    };

    // Read loop (default true)
    const loop: bool = blk: {
        if (lua.getField(3, "loop") == .boolean) {
            defer lua.pop(1);
            break :blk lua.toBoolean(-1);
        }
        lua.pop(1);
        break :blk true;
    };

    // Read frames (optional: if missing, use all frames 0..frame_count-1)
    const frames: []u32 = blk: {
        if (lua.getField(3, "frames") == .table) {
            defer lua.pop(1);
            const len = lua.rawLen(-1);
            if (len == 0) break :blk &[_]u32{};
            const frame_list = system.allocator.alloc(u32, len) catch return;
            for (0..len) |i| {
                _ = lua.rawGetIndex(-1, @intCast(i + 1));
                frame_list[i] = @intCast(lua.toInteger(-1) catch 0);
                lua.pop(1);
            }
            break :blk frame_list;
        }
        lua.pop(1);

        // No frames table: generate 0..frame_count-1
        const renderer = getRendererFromUpvalue(lua);
        const count = renderer.getFrameCount(sheet_handle);
        if (count == 0) break :blk &[_]u32{};
        const frame_list = system.allocator.alloc(u32, count) catch return;
        for (0..count) |i| {
            frame_list[i] = @intCast(i);
        }
        break :blk frame_list;
    };

    // Clear old animation state before setting new one
    system.clearAnimation(sprite, lua);
    lua.pushValue(3);
    sprite.anim_table_ref = lua.ref(zlua.registry_index) catch zlua.ref_no;

    sprite.anim = .{
        .frames = frames,
        .speed = speed,
        .loop = loop,
        .sheet_handle = sheet_handle,
        .current_index = 0,
        .timer = 0,
    };

    // Set initial frame
    if (frames.len > 0) {
        sprite.frame = frames[0];
    }
}

/// __gc metamethod: cleanup on garbage collection
pub fn lSpriteGc(lua: *Lua) i32 {
    const system = getSystem(lua);
    const id = getSpriteId(lua, 1) orelse return 0;
    system.destroySprite(id, lua);
    return 0;
}

/// sprite:destroy() -- explicit cleanup
pub fn lSpriteDestroy(lua: *Lua) i32 {
    const system = getSystem(lua);
    const id = getSpriteId(lua, 1) orelse return 0;
    system.destroySprite(id, lua);

    // Clear the _id so double-destroy is safe
    lua.pushNil();
    lua.setField(1, "_id");
    return 0;
}

/// Push a closure with both system and renderer as upvalues.
pub fn pushSystemClosure(lua: *Lua, system: *SpriteSystem, renderer: *Renderer, func: zlua.CFn) void {
    lua.pushLightUserdata(system);
    lua.pushLightUserdata(renderer);
    lua.pushClosure(func, 2);
}

/// Register the VexelSprite metatable. Call during API registration.
pub fn registerMetatable(lua: *Lua, system: *SpriteSystem, renderer: *Renderer) void {
    lua.newMetatable(METATABLE_SPRITE) catch {};

    pushSystemClosure(lua, system, renderer, zlua.wrap(lSpriteIndex));
    lua.setField(-2, "__index");

    pushSystemClosure(lua, system, renderer, zlua.wrap(lSpriteNewIndex));
    lua.setField(-2, "__newindex");

    pushSystemClosure(lua, system, renderer, zlua.wrap(lSpriteGc));
    lua.setField(-2, "__gc");

    lua.pop(1);
}

// ── Tests ──

test "init and deinit" {
    var system = SpriteSystem.init(std.testing.allocator);
    defer system.deinit();
}

test "create and destroy sprites" {
    var system = SpriteSystem.init(std.testing.allocator);
    defer system.deinit();

    const id1 = try system.createSprite(0);
    const id2 = try system.createSprite(1);
    try std.testing.expectEqual(@as(SpriteId, 0), id1);
    try std.testing.expectEqual(@as(SpriteId, 1), id2);

    // Sprite should be alive
    const s1 = system.getSprite(id1);
    try std.testing.expect(s1 != null);
    try std.testing.expect(s1.?.alive);
}

test "slot recycling" {
    var system = SpriteSystem.init(std.testing.allocator);
    defer system.deinit();

    const id1 = try system.createSprite(0);
    _ = try system.createSprite(1);

    // Can't call destroySprite without Lua, but we can verify free list manually
    system.slots.items[id1] = .{ .free = system.first_free };
    system.first_free = id1;

    // Next create should reuse the freed slot
    const id3 = try system.createSprite(2);
    try std.testing.expectEqual(id1, id3);
}
