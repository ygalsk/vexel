const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;
const ecs_world = @import("ecs_world");
const World = ecs_world.World;
const Entity = ecs_world.Entity;
const Position = ecs_world.Position;
const Velocity = ecs_world.Velocity;
const SpriteComp = ecs_world.SpriteComp;
const Animation = ecs_world.Animation;
const Collider = ecs_world.Collider;
const Tag = ecs_world.Tag;
const ComponentId = ecs_world.ComponentId;

// --- Upvalue helpers ---

fn pushUpvalueClosure(lua: *Lua, ptr: anytype, func: zlua.CFn) void {
    lua.pushLightUserdata(ptr);
    lua.pushClosure(func, 1);
}

fn getUpvalue(lua: *Lua, comptime T: type) *T {
    const ptr = lua.toPointer(Lua.upvalueIndex(1)) catch unreachable;
    return @ptrCast(@constCast(@alignCast(ptr)));
}

/// Extract an Entity from a light userdata argument at the given stack index.
/// +1 offset avoids null pointer when entity 0 gen 0 encodes as u64(0).
fn toEntity(lua: *Lua, idx: i32) Entity {
    const ptr = lua.toPointer(idx) catch {
        lua.raiseErrorStr("expected entity (light userdata)", .{});
    };
    return Entity.fromU64(@intFromPtr(ptr) - 1);
}

fn pushEntity(lua: *Lua, ent: Entity) void {
    lua.pushLightUserdata(@ptrFromInt(ent.toU64() + 1));
}

// --- engine.world.spawn() ---

fn lSpawn(lua: *Lua) i32 {
    const world = getUpvalue(lua, World);
    const ent = world.spawn() catch {
        lua.raiseErrorStr("world.spawn: allocation failed", .{});
    };
    pushEntity(lua, ent);
    return 1;
}

// --- engine.world.despawn(entity) ---

fn lDespawn(lua: *Lua) i32 {
    const world = getUpvalue(lua, World);
    const ent = toEntity(lua, 1);

    // Collect and unref Lua component refs before despawn
    var refs: std.ArrayList(i32) = .{};
    defer refs.deinit(world.allocator);
    world.collectLuaRefs(ent, &refs);
    for (refs.items) |ref| {
        lua.unref(zlua.registry_index, ref);
    }

    lua.pushBoolean(world.despawn(ent));
    return 1;
}

// --- engine.world.is_alive(entity) ---

fn lIsAlive(lua: *Lua) i32 {
    const world = getUpvalue(lua, World);
    const ent = toEntity(lua, 1);
    lua.pushBoolean(world.isAlive(ent));
    return 1;
}

// --- engine.world.set(entity, component_name, table) ---

fn lSet(lua: *Lua) i32 {
    const world = getUpvalue(lua, World);
    const ent = toEntity(lua, 1);

    if (!world.isAlive(ent)) {
        lua.raiseErrorStr("world.set: entity is not alive", .{});
    }

    const name = lua.toString(2) catch {
        lua.raiseErrorStr("world.set: expected component name string", .{});
    };

    if (ComponentId.fromString(name)) |comp_id| {
        setZigComponent(lua, world, ent, comp_id);
    } else {
        setLuaComponent(lua, world, ent, name);
    }
    return 0;
}

fn setZigComponent(lua: *Lua, world: *World, ent: Entity, comp_id: ComponentId) void {
    switch (comp_id) {
        .position => {
            var pos = Position{};
            readOptionalFloat(lua, 3, "x", &pos.x);
            readOptionalFloat(lua, 3, "y", &pos.y);
            world.positions.set(ent, pos) catch {
                lua.raiseErrorStr("world.set: allocation failed", .{});
            };
        },
        .velocity => {
            var vel = Velocity{};
            readOptionalFloat(lua, 3, "vx", &vel.vx);
            readOptionalFloat(lua, 3, "vy", &vel.vy);
            world.velocities.set(ent, vel) catch {
                lua.raiseErrorStr("world.set: allocation failed", .{});
            };
        },
        .sprite => {
            var sc = SpriteComp{};
            // "image" accepts integer handle or VexelImage userdata
            sc.image_handle = readImageHandle(lua, 3, "image");
            readOptionalU8(lua, 3, "layer", &sc.layer);
            readOptionalBool(lua, 3, "flip_x", &sc.flip_x);
            readOptionalBool(lua, 3, "flip_y", &sc.flip_y);
            readOptionalU8(lua, 3, "scale", &sc.scale);
            world.sprites.set(ent, sc) catch {
                lua.raiseErrorStr("world.set: allocation failed", .{});
            };
        },
        .animation => {
            var anim = Animation{};
            readOptionalFloat(lua, 3, "speed", &anim.speed);
            readOptionalBool(lua, 3, "loop", &anim.loop);

            // Read frames array: {0, 1, 2, 3}
            if (lua.getField(3, "frames") == .table) {
                const len = lua.rawLen(-1);
                const count: u8 = if (len > 32) 32 else @intCast(len);
                var i: u8 = 0;
                while (i < count) : (i += 1) {
                    _ = lua.rawGetIndex(-1, @intCast(@as(u32, i) + 1));
                    anim.frames[i] = @intCast(lua.toInteger(-1) catch 0);
                    lua.pop(1);
                }
                anim.frame_count = count;
            }
            lua.pop(1);

            // Optional sheet override (accepts integer or userdata)
            const sheet = readImageHandle(lua, 3, "sheet");
            if (sheet != 0) anim.sheet_handle = sheet;

            // Optional on_complete callback
            if (lua.getField(3, "on_complete") == .function) {
                lua.pushValue(-1);
                anim.on_complete_ref = lua.ref(zlua.registry_index) catch ecs_world.ref_none;
            }
            lua.pop(1);

            // Set initial frame on sprite if present
            if (anim.frame_count > 0) {
                if (world.sprites.get(ent)) |sprite| {
                    sprite.frame = anim.frames[0];
                }
            }

            world.animations.set(ent, anim) catch {
                lua.raiseErrorStr("world.set: allocation failed", .{});
            };
        },
        .collider => {
            var c = Collider{};
            readOptionalFloat(lua, 3, "w", &c.w);
            readOptionalFloat(lua, 3, "h", &c.h);
            readOptionalBool(lua, 3, "solid", &c.solid);
            world.colliders.set(ent, c) catch {
                lua.raiseErrorStr("world.set: allocation failed", .{});
            };
        },
        .tag => {
            var t = Tag{};
            t.player = readBoolField(lua, 3, "player");
            t.enemy = readBoolField(lua, 3, "enemy");
            t.pickup = readBoolField(lua, 3, "pickup");
            t.projectile = readBoolField(lua, 3, "projectile");
            world.tags.set(ent, t) catch {
                lua.raiseErrorStr("world.set: allocation failed", .{});
            };
        },
    }
}

fn setLuaComponent(lua: *Lua, world: *World, ent: Entity, name: []const u8) void {
    const store = world.getLuaStore(name) catch {
        lua.raiseErrorStr("world.set: allocation failed", .{});
    };

    // Unref old value if present
    if (store.remove(ent.index)) |old_ref| {
        lua.unref(zlua.registry_index, old_ref);
    }

    // Store new value as registry ref
    lua.pushValue(3); // push the value (arg 3)
    const ref = lua.ref(zlua.registry_index) catch {
        lua.raiseErrorStr("world.set: failed to create ref", .{});
    };
    store.set(ent.index, ref) catch {
        lua.unref(zlua.registry_index, ref);
        lua.raiseErrorStr("world.set: allocation failed", .{});
    };
}

// --- engine.world.get(entity, component_name) ---

fn lGet(lua: *Lua) i32 {
    const world = getUpvalue(lua, World);
    const ent = toEntity(lua, 1);

    if (!world.isAlive(ent)) {
        lua.pushNil();
        return 1;
    }

    const name = lua.toString(2) catch {
        lua.raiseErrorStr("world.get: expected component name string", .{});
    };

    if (ComponentId.fromString(name)) |comp_id| {
        return getZigComponent(lua, world, ent, comp_id);
    } else {
        return getLuaComponent(lua, world, ent, name);
    }
}

fn getZigComponent(lua: *Lua, world: *World, ent: Entity, comp_id: ComponentId) i32 {
    switch (comp_id) {
        .position => {
            const pos = world.positions.getConst(ent) orelse {
                lua.pushNil();
                return 1;
            };
            lua.newTable();
            lua.pushNumber(pos.x);
            lua.setField(-2, "x");
            lua.pushNumber(pos.y);
            lua.setField(-2, "y");
            return 1;
        },
        .velocity => {
            const vel = world.velocities.getConst(ent) orelse {
                lua.pushNil();
                return 1;
            };
            lua.newTable();
            lua.pushNumber(vel.vx);
            lua.setField(-2, "vx");
            lua.pushNumber(vel.vy);
            lua.setField(-2, "vy");
            return 1;
        },
        .sprite => {
            const sc = world.sprites.getConst(ent) orelse {
                lua.pushNil();
                return 1;
            };
            lua.newTable();
            lua.pushInteger(@intCast(sc.image_handle));
            lua.setField(-2, "image_handle");
            lua.pushInteger(@intCast(sc.layer));
            lua.setField(-2, "layer");
            lua.pushBoolean(sc.flip_x);
            lua.setField(-2, "flip_x");
            lua.pushBoolean(sc.flip_y);
            lua.setField(-2, "flip_y");
            lua.pushInteger(@intCast(sc.scale));
            lua.setField(-2, "scale");
            return 1;
        },
        .animation => {
            const anim = world.animations.getConst(ent) orelse {
                lua.pushNil();
                return 1;
            };
            lua.newTable();
            lua.pushNumber(anim.speed);
            lua.setField(-2, "speed");
            lua.pushBoolean(anim.loop);
            lua.setField(-2, "loop");
            lua.pushInteger(@intCast(anim.current_index));
            lua.setField(-2, "current_index");
            lua.pushInteger(@intCast(anim.frame_count));
            lua.setField(-2, "frame_count");
            return 1;
        },
        .collider => {
            const c = world.colliders.getConst(ent) orelse {
                lua.pushNil();
                return 1;
            };
            lua.newTable();
            lua.pushNumber(c.w);
            lua.setField(-2, "w");
            lua.pushNumber(c.h);
            lua.setField(-2, "h");
            lua.pushBoolean(c.solid);
            lua.setField(-2, "solid");
            return 1;
        },
        .tag => {
            const t = world.tags.getConst(ent) orelse {
                lua.pushNil();
                return 1;
            };
            lua.newTable();
            lua.pushBoolean(t.player);
            lua.setField(-2, "player");
            lua.pushBoolean(t.enemy);
            lua.setField(-2, "enemy");
            lua.pushBoolean(t.pickup);
            lua.setField(-2, "pickup");
            lua.pushBoolean(t.projectile);
            lua.setField(-2, "projectile");
            return 1;
        },
    }
}

fn getLuaComponent(lua: *Lua, world: *World, ent: Entity, name: []const u8) i32 {
    const store = world.getLuaStore(name) catch {
        lua.pushNil();
        return 1;
    };
    if (store.get(ent.index)) |ref| {
        _ = lua.rawGetIndex(zlua.registry_index, ref);
        return 1;
    }
    lua.pushNil();
    return 1;
}

// --- engine.world.remove(entity, component_name) ---

fn lRemove(lua: *Lua) i32 {
    const world = getUpvalue(lua, World);
    const ent = toEntity(lua, 1);

    const name = lua.toString(2) catch {
        lua.raiseErrorStr("world.remove: expected component name string", .{});
    };

    if (ComponentId.fromString(name)) |comp_id| {
        switch (comp_id) {
            .position => _ = world.positions.remove(ent),
            .velocity => _ = world.velocities.remove(ent),
            .sprite => _ = world.sprites.remove(ent),
            .animation => {
                // Unref callback before removing
                if (world.animations.getConst(ent)) |anim| {
                    if (anim.on_complete_ref != ecs_world.ref_none) {
                        lua.unref(zlua.registry_index, anim.on_complete_ref);
                    }
                }
                _ = world.animations.remove(ent);
            },
            .collider => _ = world.colliders.remove(ent),
            .tag => _ = world.tags.remove(ent),
        }
    } else {
        if (world.lua_stores.getPtr(name)) |store| {
            if (store.remove(ent.index)) |ref| {
                lua.unref(zlua.registry_index, ref);
            }
        }
    }
    return 0;
}

// --- engine.world.each(name1, [name2], [name3]) -> iterator ---
// Returns a Lua iterator closure.
// Usage: for entity, comp1, comp2 in engine.world.each("position", "velocity") do ... end

fn lEach(lua: *Lua) i32 {
    const world = getUpvalue(lua, World);
    const n_args = lua.getTop();

    if (n_args < 1) {
        lua.raiseErrorStr("world.each: expected at least one component name", .{});
    }
    if (n_args > 3) {
        lua.raiseErrorStr("world.each: at most 3 component names supported", .{});
    }

    // Upvalues: world, name1, name2, name3, index
    lua.pushLightUserdata(world);
    var i: i32 = 1;
    while (i <= 3) : (i += 1) {
        if (i <= n_args) {
            lua.pushValue(i);
        } else {
            lua.pushNil();
        }
    }
    lua.pushInteger(0);
    lua.pushClosure(zlua.wrap(lEachIterator), 5);
    return 1;
}

fn lEachIterator(lua: *Lua) i32 {
    const world_ptr = lua.toPointer(Lua.upvalueIndex(1)) catch return 0;
    const world: *World = @ptrCast(@constCast(@alignCast(world_ptr)));

    // Read component names from upvalues
    const name1 = lua.toString(Lua.upvalueIndex(2)) catch return 0;
    const name2 = lua.toString(Lua.upvalueIndex(3)) catch null;
    const name3 = lua.toString(Lua.upvalueIndex(4)) catch null;

    // Read current iteration index
    var idx: u32 = @intCast(lua.toInteger(Lua.upvalueIndex(5)) catch 0);

    // Find the primary store to iterate (first component)
    // We iterate the smallest store for efficiency, but for simplicity in V1,
    // iterate the first component's store and filter by the others.

    while (true) {
        const ent = getEntityAtIndex(world, name1, idx) orelse return 0;
        idx += 1;

        // Update the stored index upvalue
        lua.pushInteger(@intCast(idx));
        lua.replace(Lua.upvalueIndex(5));

        // Check entity is alive (generation check)
        if (!world.isAlive(ent)) continue;

        // Check other components exist
        if (name2) |n2| {
            if (!hasComponent(world, ent, n2)) continue;
        }
        if (name3) |n3| {
            if (!hasComponent(world, ent, n3)) continue;
        }

        // Push entity
        pushEntity(lua, ent);

        // Push component values
        if (pushComponentValue(lua, world, ent, name1) == 0) continue;
        var n_results: i32 = 2; // entity + first component

        if (name2) |n2| {
            if (pushComponentValue(lua, world, ent, n2) == 0) continue;
            n_results += 1;
        }
        if (name3) |n3| {
            if (pushComponentValue(lua, world, ent, n3) == 0) continue;
            n_results += 1;
        }

        return n_results;
    }
}

/// Get the entity at dense index `idx` for the given component store.
fn getEntityAtIndex(world: *World, name: []const u8, idx: u32) ?Entity {
    if (ComponentId.fromString(name)) |comp_id| {
        const entities = switch (comp_id) {
            .position => world.positions.entities(),
            .velocity => world.velocities.entities(),
            .sprite => world.sprites.entities(),
            .animation => world.animations.entities(),
            .collider => world.colliders.entities(),
            .tag => world.tags.entities(),
        };
        if (idx >= entities.len) return null;
        return entities[idx];
    } else {
        const store = world.lua_stores.getPtr(name) orelse return null;
        const keys = store.entityIndices();
        if (idx >= keys.len) return null;
        const entity_index = keys[idx];
        if (entity_index >= world.entities.generations.items.len) return null;
        return Entity{
            .index = entity_index,
            .generation = world.entities.generations.items[entity_index],
        };
    }
}

/// Check if an entity has a given component.
fn hasComponent(world: *World, ent: Entity, name: []const u8) bool {
    if (ComponentId.fromString(name)) |comp_id| {
        return switch (comp_id) {
            .position => world.positions.contains(ent),
            .velocity => world.velocities.contains(ent),
            .sprite => world.sprites.contains(ent),
            .animation => world.animations.contains(ent),
            .collider => world.colliders.contains(ent),
            .tag => world.tags.contains(ent),
        };
    } else {
        const store = world.lua_stores.getPtr(name) orelse return false;
        return store.contains(ent.index);
    }
}

/// Push a component's value as a Lua table. Returns 1 on success, 0 if not found.
fn pushComponentValue(lua: *Lua, world: *World, ent: Entity, name: []const u8) i32 {
    if (ComponentId.fromString(name)) |comp_id| {
        return getZigComponent(lua, world, ent, comp_id);
    } else {
        return getLuaComponent(lua, world, ent, name);
    }
}

// --- engine.world.count() ---

fn lCount(lua: *Lua) i32 {
    const world = getUpvalue(lua, World);
    lua.pushInteger(@intCast(world.entityCount()));
    return 1;
}

// --- Table field reading helpers ---

fn readOptionalFloat(lua: *Lua, table_idx: i32, field: [:0]const u8, out: *f32) void {
    if (lua.getField(table_idx, field) == .number) {
        out.* = @floatCast(lua.toNumber(-1) catch 0);
    }
    lua.pop(1);
}

fn readOptionalBool(lua: *Lua, table_idx: i32, field: [:0]const u8, out: *bool) void {
    if (lua.getField(table_idx, field) == .boolean) {
        out.* = lua.toBoolean(-1);
    }
    lua.pop(1);
}

fn readOptionalU8(lua: *Lua, table_idx: i32, field: [:0]const u8, out: *u8) void {
    if (lua.getField(table_idx, field) == .number) {
        const v = lua.toInteger(-1) catch 0;
        out.* = if (v < 0) 0 else if (v > 255) 255 else @intCast(v);
    }
    lua.pop(1);
}

/// Read a boolean field from a table, returning false if not present.
fn readBoolField(lua: *Lua, table_idx: i32, field: [:0]const u8) bool {
    const result = if (lua.getField(table_idx, field) == .boolean)
        lua.toBoolean(-1)
    else
        false;
    lua.pop(1);
    return result;
}

/// Read an image handle from a table field. Accepts integer or VexelImage userdata.
fn readImageHandle(lua: *Lua, table_idx: i32, field: [:0]const u8) u32 {
    const field_type = lua.getField(table_idx, field);
    defer lua.pop(1);
    if (field_type == .number) {
        return @intCast(lua.toInteger(-1) catch 0);
    } else if (field_type == .userdata) {
        // VexelImage userdata: struct { handle: u32, valid: bool }
        // Read the first u32 field (the handle)
        const ptr = lua.toPointer(-1) catch return 0;
        const handle_ptr: *const u32 = @ptrCast(@alignCast(ptr));
        return handle_ptr.*;
    }
    return 0;
}

fn readOptionalU32(lua: *Lua, table_idx: i32, field: [:0]const u8, out: *u32) void {
    if (lua.getField(table_idx, field) == .number) {
        const v = lua.toInteger(-1) catch 0;
        out.* = if (v < 0) 0 else @intCast(v);
    }
    lua.pop(1);
}

// --- Registration ---

pub fn register(lua: *Lua, world: *World) void {
    lua.newTable();

    pushUpvalueClosure(lua, world, zlua.wrap(lSpawn));
    lua.setField(-2, "spawn");

    pushUpvalueClosure(lua, world, zlua.wrap(lDespawn));
    lua.setField(-2, "despawn");

    pushUpvalueClosure(lua, world, zlua.wrap(lIsAlive));
    lua.setField(-2, "is_alive");

    pushUpvalueClosure(lua, world, zlua.wrap(lSet));
    lua.setField(-2, "set");

    pushUpvalueClosure(lua, world, zlua.wrap(lGet));
    lua.setField(-2, "get");

    pushUpvalueClosure(lua, world, zlua.wrap(lRemove));
    lua.setField(-2, "remove");

    pushUpvalueClosure(lua, world, zlua.wrap(lEach));
    lua.setField(-2, "each");

    pushUpvalueClosure(lua, world, zlua.wrap(lCount));
    lua.setField(-2, "count");

    // Set as engine.world (assumes engine table is at -2 on stack)
    // Caller is responsible for placing this on the engine table.
    // This function leaves the world table on the stack.
}
