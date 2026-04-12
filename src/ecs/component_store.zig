const std = @import("std");
const entity_mod = @import("entity");
const Entity = entity_mod.Entity;

/// Sparse-set based storage for a single Zig component type.
/// Dense arrays for contiguous iteration; sparse map for O(1) lookup by entity.
pub fn ComponentStore(comptime T: type) type {
    return struct {
        const Self = @This();

        dense_entities: std.ArrayList(Entity),
        dense_data: std.ArrayList(T),
        sparse: std.AutoHashMap(u32, u32), // entity.index -> dense index
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .dense_entities = .{},
                .dense_data = .{},
                .sparse = std.AutoHashMap(u32, u32).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.dense_entities.deinit(self.allocator);
            self.dense_data.deinit(self.allocator);
            self.sparse.deinit();
        }

        pub fn set(self: *Self, ent: Entity, component: T) !void {
            if (self.sparse.get(ent.index)) |dense_idx| {
                self.dense_data.items[dense_idx] = component;
            } else {
                const dense_idx: u32 = @intCast(self.dense_entities.items.len);
                try self.dense_entities.append(self.allocator, ent);
                try self.dense_data.append(self.allocator, component);
                try self.sparse.put(ent.index, dense_idx);
            }
        }

        pub fn get(self: *Self, ent: Entity) ?*T {
            const dense_idx = self.sparse.get(ent.index) orelse return null;
            return &self.dense_data.items[dense_idx];
        }

        pub fn getConst(self: *const Self, ent: Entity) ?T {
            const dense_idx = self.sparse.get(ent.index) orelse return null;
            return self.dense_data.items[dense_idx];
        }

        pub fn contains(self: *const Self, ent: Entity) bool {
            return self.sparse.contains(ent.index);
        }

        /// Remove a component. Swaps with last element for O(1) removal.
        pub fn remove(self: *Self, ent: Entity) bool {
            const dense_idx = self.sparse.get(ent.index) orelse return false;
            const last_idx: u32 = @intCast(self.dense_entities.items.len - 1);

            if (dense_idx != last_idx) {
                // Swap with last
                const last_entity = self.dense_entities.items[last_idx];
                self.dense_entities.items[dense_idx] = last_entity;
                self.dense_data.items[dense_idx] = self.dense_data.items[last_idx];
                self.sparse.put(last_entity.index, dense_idx) catch unreachable;
            }

            _ = self.dense_entities.pop();
            _ = self.dense_data.pop();
            _ = self.sparse.remove(ent.index);
            return true;
        }

        /// Remove all components for entities whose index appears in the given set.
        pub fn removeByIndex(self: *Self, index: u32) void {
            const dense_idx = self.sparse.get(index) orelse return;
            const last_idx: u32 = @intCast(self.dense_entities.items.len - 1);

            if (dense_idx != last_idx) {
                const last_entity = self.dense_entities.items[last_idx];
                self.dense_entities.items[dense_idx] = last_entity;
                self.dense_data.items[dense_idx] = self.dense_data.items[last_idx];
                self.sparse.put(last_entity.index, dense_idx) catch unreachable;
            }

            _ = self.dense_entities.pop();
            _ = self.dense_data.pop();
            _ = self.sparse.remove(index);
        }

        pub fn entities(self: *const Self) []const Entity {
            return self.dense_entities.items;
        }

        pub fn items(self: *Self) []T {
            return self.dense_data.items;
        }

        pub fn len(self: *const Self) u32 {
            return @intCast(self.dense_entities.items.len);
        }
    };
}

// --- Tests ---

test "component store set/get/remove" {
    const Vec2 = struct { x: f32, y: f32 };
    var store = ComponentStore(Vec2).init(std.testing.allocator);
    defer store.deinit();

    const e1 = Entity{ .index = 0, .generation = 0 };
    const e2 = Entity{ .index = 1, .generation = 0 };

    try store.set(e1, .{ .x = 10, .y = 20 });
    try store.set(e2, .{ .x = 30, .y = 40 });

    try std.testing.expectEqual(@as(u32, 2), store.len());

    const v1 = store.get(e1).?;
    try std.testing.expectEqual(@as(f32, 10), v1.x);

    // Overwrite
    try store.set(e1, .{ .x = 99, .y = 88 });
    try std.testing.expectEqual(@as(f32, 99), store.get(e1).?.x);

    // Remove with swap
    try std.testing.expect(store.remove(e1));
    try std.testing.expect(!store.contains(e1));
    try std.testing.expect(store.contains(e2));
    try std.testing.expectEqual(@as(u32, 1), store.len());

    // e2 data still accessible after swap
    try std.testing.expectEqual(@as(f32, 30), store.get(e2).?.x);
}

test "component store remove last element" {
    var store = ComponentStore(u32).init(std.testing.allocator);
    defer store.deinit();

    const e = Entity{ .index = 5, .generation = 0 };
    try store.set(e, 42);
    try std.testing.expect(store.remove(e));
    try std.testing.expectEqual(@as(u32, 0), store.len());
}

test "component store iteration" {
    var store = ComponentStore(f32).init(std.testing.allocator);
    defer store.deinit();

    var i: u32 = 0;
    while (i < 5) : (i += 1) {
        try store.set(Entity{ .index = i, .generation = 0 }, @floatFromInt(i));
    }

    var sum: f32 = 0;
    for (store.items()) |val| {
        sum += val;
    }
    try std.testing.expectEqual(@as(f32, 10), sum); // 0+1+2+3+4
}
