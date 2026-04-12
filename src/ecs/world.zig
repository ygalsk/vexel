const std = @import("std");
const entity_mod = @import("entity");
const component_store = @import("component_store");

pub const Entity = entity_mod.Entity;
pub const EntityPool = entity_mod.EntityPool;
pub const ComponentStore = component_store.ComponentStore;

/// Sentinel for "no Lua registry reference" (matches zlua.ref_no).
pub const ref_none: i32 = -2;

// --- Built-in component types ---

pub const Position = struct { x: f32 = 0, y: f32 = 0 };
pub const Velocity = struct { vx: f32 = 0, vy: f32 = 0 };
pub const SpriteComp = struct {
    image_handle: u32 = 0, // Renderer.ImageHandle (= u32)
    layer: u8 = 1,
    frame: u32 = 0,
    flip_x: bool = false,
    flip_y: bool = false,
    scale: u8 = 1,
    visible: bool = true,
};

pub const Animation = struct {
    frames: [32]u32 = [_]u32{0} ** 32,
    frame_count: u8 = 0,
    speed: f32 = 0.1,
    loop: bool = true,
    current_index: u8 = 0,
    timer: f32 = 0,
    on_complete_ref: i32 = ref_none,
    sheet_handle: u32 = std.math.maxInt(u32), // override image for animation
};

pub const Collider = struct { w: f32 = 0, h: f32 = 0, solid: bool = true };

pub const Tag = packed struct(u32) {
    player: bool = false,
    enemy: bool = false,
    pickup: bool = false,
    projectile: bool = false,
    _padding: u28 = 0,
};

/// Event emitted when a non-looping animation completes.
pub const AnimationEvent = struct {
    entity: Entity,
    on_complete_ref: i32,
};

/// Component type identifier for string-dispatched operations.
pub const ComponentId = enum {
    position,
    velocity,
    sprite,
    animation,
    collider,
    tag,

    pub const map = std.StaticStringMap(ComponentId).initComptime(.{
        .{ "position", .position },
        .{ "velocity", .velocity },
        .{ "sprite", .sprite },
        .{ "animation", .animation },
        .{ "collider", .collider },
        .{ "tag", .tag },
    });

    pub fn fromString(name: []const u8) ?ComponentId {
        return map.get(name);
    }
};

/// Lua component store: sparse-set holding Lua registry refs keyed by entity index.
/// Dense arrays for O(1) indexed access; sparse map for O(1) lookup by entity.
pub const LuaComponentStore = struct {
    dense_keys: std.ArrayList(u32), // entity indices (dense)
    dense_vals: std.ArrayList(i32), // Lua registry refs (dense, parallel)
    sparse: std.AutoHashMap(u32, u32), // entity.index -> dense index
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) LuaComponentStore {
        return .{
            .dense_keys = .{},
            .dense_vals = .{},
            .sparse = std.AutoHashMap(u32, u32).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LuaComponentStore) void {
        self.dense_keys.deinit(self.allocator);
        self.dense_vals.deinit(self.allocator);
        self.sparse.deinit();
    }

    pub fn set(self: *LuaComponentStore, index: u32, ref: i32) !void {
        if (self.sparse.get(index)) |dense_idx| {
            self.dense_vals.items[dense_idx] = ref;
        } else {
            const dense_idx: u32 = @intCast(self.dense_keys.items.len);
            try self.dense_keys.append(self.allocator, index);
            try self.dense_vals.append(self.allocator, ref);
            try self.sparse.put(index, dense_idx);
        }
    }

    pub fn get(self: *const LuaComponentStore, index: u32) ?i32 {
        const dense_idx = self.sparse.get(index) orelse return null;
        return self.dense_vals.items[dense_idx];
    }

    pub fn remove(self: *LuaComponentStore, index: u32) ?i32 {
        const dense_idx = self.sparse.get(index) orelse return null;
        const ref = self.dense_vals.items[dense_idx];
        const last_idx: u32 = @intCast(self.dense_keys.items.len - 1);

        if (dense_idx != last_idx) {
            const last_key = self.dense_keys.items[last_idx];
            self.dense_keys.items[dense_idx] = last_key;
            self.dense_vals.items[dense_idx] = self.dense_vals.items[last_idx];
            self.sparse.put(last_key, dense_idx) catch unreachable;
        }

        _ = self.dense_keys.pop();
        _ = self.dense_vals.pop();
        _ = self.sparse.remove(index);
        return ref;
    }

    pub fn contains(self: *const LuaComponentStore, index: u32) bool {
        return self.sparse.contains(index);
    }

    pub fn count(self: *const LuaComponentStore) u32 {
        return @intCast(self.dense_keys.items.len);
    }

    pub fn entityIndices(self: *const LuaComponentStore) []const u32 {
        return self.dense_keys.items;
    }
};

/// The ECS world: owns entities and all component stores.
pub const World = struct {
    allocator: std.mem.Allocator,
    entities: EntityPool,

    // Zig component stores (engine-provided)
    positions: ComponentStore(Position),
    velocities: ComponentStore(Velocity),
    sprites: ComponentStore(SpriteComp),
    animations: ComponentStore(Animation),
    colliders: ComponentStore(Collider),
    tags: ComponentStore(Tag),

    // Lua component stores (game-defined, string-keyed)
    lua_stores: std.StringHashMap(LuaComponentStore),
    // Track allocated keys so we can free them
    lua_store_keys: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) World {
        return .{
            .allocator = allocator,
            .entities = EntityPool.init(allocator),
            .positions = ComponentStore(Position).init(allocator),
            .velocities = ComponentStore(Velocity).init(allocator),
            .sprites = ComponentStore(SpriteComp).init(allocator),
            .animations = ComponentStore(Animation).init(allocator),
            .colliders = ComponentStore(Collider).init(allocator),
            .tags = ComponentStore(Tag).init(allocator),
            .lua_stores = std.StringHashMap(LuaComponentStore).init(allocator),
            .lua_store_keys = .{},
        };
    }

    pub fn deinit(self: *World) void {
        self.entities.deinit();
        self.positions.deinit();
        self.velocities.deinit();
        self.sprites.deinit();
        self.animations.deinit();
        self.colliders.deinit();
        self.tags.deinit();

        var it = self.lua_stores.valueIterator();
        while (it.next()) |store| {
            // Note: Lua refs should be unref'd before world deinit (by caller)
            store.deinit();
        }
        self.lua_stores.deinit();

        for (self.lua_store_keys.items) |key| {
            self.allocator.free(key);
        }
        self.lua_store_keys.deinit(self.allocator);
    }

    pub fn spawn(self: *World) !Entity {
        return try self.entities.create();
    }

    /// Despawn an entity, removing it from ALL component stores.
    /// Returns the list of Lua refs that need to be unref'd by the caller.
    pub fn despawn(self: *World, ent: Entity) bool {
        if (!self.entities.isAlive(ent)) return false;

        // Remove from all Zig stores
        _ = self.positions.remove(ent);
        _ = self.velocities.remove(ent);
        _ = self.sprites.remove(ent);
        _ = self.animations.remove(ent);
        _ = self.colliders.remove(ent);
        _ = self.tags.remove(ent);

        // Remove from all Lua stores (refs need to be unref'd by caller via collectLuaRefs)
        var store_it = self.lua_stores.valueIterator();
        while (store_it.next()) |store| {
            _ = store.remove(ent.index);
        }

        return self.entities.destroy(ent);
    }

    /// Collect all Lua refs for an entity before despawn (so caller can unref them).
    pub fn collectLuaRefs(self: *World, ent: Entity, out: *std.ArrayList(i32)) void {
        // Animation on_complete refs
        if (self.animations.getConst(ent)) |anim| {
            if (anim.on_complete_ref != ref_none) {
                out.append(self.allocator, anim.on_complete_ref) catch {};
            }
        }

        // Lua component store refs
        var store_it = self.lua_stores.valueIterator();
        while (store_it.next()) |store| {
            if (store.get(ent.index)) |ref| {
                out.append(self.allocator, ref) catch {};
            }
        }
    }

    pub fn isAlive(self: *const World, ent: Entity) bool {
        return self.entities.isAlive(ent);
    }

    pub fn entityCount(self: *const World) u32 {
        return self.entities.count();
    }

    /// Get or create a Lua component store by name.
    pub fn getLuaStore(self: *World, name: []const u8) !*LuaComponentStore {
        if (self.lua_stores.getPtr(name)) |store| return store;

        const key = try self.allocator.dupe(u8, name);
        try self.lua_store_keys.append(self.allocator, key);
        try self.lua_stores.put(key, LuaComponentStore.init(self.allocator));
        return self.lua_stores.getPtr(key).?;
    }

    // --- Built-in systems ---

    /// Move all entities that have both Position and Velocity.
    pub fn updateMovement(self: *World, dt: f32) void {
        if (self.velocities.len() <= self.positions.len()) {
            for (self.velocities.entities(), self.velocities.items()) |ent, vel| {
                if (self.positions.get(ent)) |pos| {
                    pos.x += vel.vx * dt;
                    pos.y += vel.vy * dt;
                }
            }
        } else {
            for (self.positions.entities(), self.positions.items()) |ent, *pos| {
                if (self.velocities.getConst(ent)) |vel| {
                    pos.x += vel.vx * dt;
                    pos.y += vel.vy * dt;
                }
            }
        }
    }

    /// Tick all animations. Advances frame timers and updates SpriteComp.frame.
    /// Returns events for completed non-looping animations (caller fires Lua callbacks).
    pub fn tickAnimations(self: *World, dt: f32, alloc: std.mem.Allocator, events: *std.ArrayList(AnimationEvent)) void {
        for (self.animations.entities(), self.animations.items()) |ent, *anim| {
            if (anim.frame_count == 0) continue;

            anim.timer += dt;
            while (anim.timer >= anim.speed) {
                anim.timer -= anim.speed;
                anim.current_index += 1;

                if (anim.current_index >= anim.frame_count) {
                    if (anim.loop) {
                        anim.current_index = 0;
                    } else {
                        anim.current_index = anim.frame_count - 1;
                        if (anim.on_complete_ref != ref_none) {
                            events.append(alloc, .{
                                .entity = ent,
                                .on_complete_ref = anim.on_complete_ref,
                            }) catch {};
                            anim.on_complete_ref = ref_none;
                        }
                        break;
                    }
                }
            }

            // Update the sprite's current frame
            if (self.sprites.get(ent)) |sprite| {
                sprite.frame = anim.frames[anim.current_index];
            }
        }
    }

    /// Render info for a single sprite entity.
    pub const SpriteRenderEntry = struct {
        image_handle: u32,
        x: i32,
        y: i32,
        frame: u32,
        flip_x: bool,
        flip_y: bool,
        scale: u8,
        layer: u8,
    };

    /// Collect all renderable sprites (entities with Position + SpriteComp).
    /// Caller is responsible for sorting by layer and drawing.
    pub fn collectSprites(self: *World, alloc: std.mem.Allocator, out: *std.ArrayList(SpriteRenderEntry)) void {
        for (self.sprites.entities(), self.sprites.items()) |ent, sprite| {
            if (!sprite.visible) continue;
            const pos = self.positions.getConst(ent) orelse continue;

            // Use animation's sheet_handle if set, otherwise sprite's image
            const image = if (self.animations.getConst(ent)) |anim|
                (if (anim.sheet_handle != std.math.maxInt(u32)) anim.sheet_handle else sprite.image_handle)
            else
                sprite.image_handle;

            out.append(alloc, .{
                .image_handle = image,
                .x = @intFromFloat(pos.x),
                .y = @intFromFloat(pos.y),
                .frame = sprite.frame,
                .flip_x = sprite.flip_x,
                .flip_y = sprite.flip_y,
                .scale = sprite.scale,
                .layer = sprite.layer,
            }) catch {};
        }
    }
};

// --- Tests ---

test "world spawn and despawn" {
    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const e1 = try world.spawn();
    const e2 = try world.spawn();
    try std.testing.expectEqual(@as(u32, 2), world.entityCount());

    try std.testing.expect(world.despawn(e1));
    try std.testing.expectEqual(@as(u32, 1), world.entityCount());
    try std.testing.expect(!world.isAlive(e1));
    try std.testing.expect(world.isAlive(e2));
}

test "world components" {
    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const e = try world.spawn();
    try world.positions.set(e, .{ .x = 10, .y = 20 });
    try world.velocities.set(e, .{ .vx = 5, .vy = -3 });

    const pos = world.positions.get(e).?;
    try std.testing.expectEqual(@as(f32, 10), pos.x);

    // Despawn removes all components
    try std.testing.expect(world.despawn(e));
    try std.testing.expect(!world.positions.contains(e));
    try std.testing.expect(!world.velocities.contains(e));
}

test "world movement system" {
    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const e1 = try world.spawn();
    try world.positions.set(e1, .{ .x = 0, .y = 0 });
    try world.velocities.set(e1, .{ .vx = 10, .vy = 20 });

    const e2 = try world.spawn();
    try world.positions.set(e2, .{ .x = 100, .y = 100 });
    // e2 has no velocity — should not move

    world.updateMovement(0.5);

    const p1 = world.positions.get(e1).?;
    try std.testing.expectEqual(@as(f32, 5), p1.x);
    try std.testing.expectEqual(@as(f32, 10), p1.y);

    const p2 = world.positions.get(e2).?;
    try std.testing.expectEqual(@as(f32, 100), p2.x);
}

test "world lua component stores" {
    var world = World.init(std.testing.allocator);
    defer world.deinit();

    const store = try world.getLuaStore("health");
    const e = try world.spawn();
    try store.set(e.index, 42); // fake ref

    try std.testing.expectEqual(@as(i32, 42), store.get(e.index).?);

    // Getting same name returns same store
    const store2 = try world.getLuaStore("health");
    try std.testing.expectEqual(@as(i32, 42), store2.get(e.index).?);
}

test "component id from string" {
    try std.testing.expectEqual(ComponentId.position, ComponentId.fromString("position").?);
    try std.testing.expectEqual(ComponentId.sprite, ComponentId.fromString("sprite").?);
    try std.testing.expect(ComponentId.fromString("health") == null);
}
