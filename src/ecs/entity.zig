const std = @import("std");

/// Entity handle: generation-counted ID that detects stale references.
/// Packed into u64 for use as Lua light userdata.
pub const Entity = packed struct(u64) {
    index: u32,
    generation: u16,
    _padding: u16 = 0,

    pub const nil: Entity = .{ .index = std.math.maxInt(u32), .generation = 0 };

    pub fn isNil(self: Entity) bool {
        return self.index == std.math.maxInt(u32);
    }

    pub fn toU64(self: Entity) u64 {
        return @bitCast(self);
    }

    pub fn fromU64(val: u64) Entity {
        return @bitCast(val);
    }

    pub fn eql(a: Entity, b: Entity) bool {
        return a.index == b.index and a.generation == b.generation;
    }
};

/// Pool that manages entity allocation with generation tracking and a free list.
pub const EntityPool = struct {
    generations: std.ArrayList(u16),
    alive_flags: std.ArrayList(bool),
    free_list: std.ArrayList(u32),
    alive_count: u32 = 0,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) EntityPool {
        return .{
            .generations = .{},
            .alive_flags = .{},
            .free_list = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *EntityPool) void {
        self.generations.deinit(self.allocator);
        self.alive_flags.deinit(self.allocator);
        self.free_list.deinit(self.allocator);
    }

    pub fn create(self: *EntityPool) !Entity {
        if (self.free_list.items.len > 0) {
            const index = self.free_list.items[self.free_list.items.len - 1];
            self.free_list.items.len -= 1;
            self.alive_flags.items[index] = true;
            self.alive_count += 1;
            return .{ .index = index, .generation = self.generations.items[index] };
        }

        const index: u32 = @intCast(self.generations.items.len);
        try self.generations.append(self.allocator, 0);
        try self.alive_flags.append(self.allocator, true);
        self.alive_count += 1;
        return .{ .index = index, .generation = 0 };
    }

    pub fn destroy(self: *EntityPool, entity: Entity) bool {
        if (!self.isAlive(entity)) return false;
        self.alive_flags.items[entity.index] = false;
        self.generations.items[entity.index] +%= 1;
        self.free_list.append(self.allocator, entity.index) catch {};
        self.alive_count -= 1;
        return true;
    }

    pub fn isAlive(self: *const EntityPool, entity: Entity) bool {
        if (entity.isNil()) return false;
        if (entity.index >= self.generations.items.len) return false;
        return self.alive_flags.items[entity.index] and
            self.generations.items[entity.index] == entity.generation;
    }

    pub fn count(self: *const EntityPool) u32 {
        return self.alive_count;
    }
};

// --- Tests ---

test "entity nil" {
    const e = Entity.nil;
    try std.testing.expect(e.isNil());
    try std.testing.expect(!Entity.eql(e, Entity{ .index = 0, .generation = 0 }));
}

test "entity roundtrip u64" {
    const e = Entity{ .index = 42, .generation = 7 };
    const val = e.toU64();
    const e2 = Entity.fromU64(val);
    try std.testing.expect(Entity.eql(e, e2));
}

test "entity pool create and destroy" {
    var pool = EntityPool.init(std.testing.allocator);
    defer pool.deinit();

    const e1 = try pool.create();
    const e2 = try pool.create();
    try std.testing.expectEqual(@as(u32, 2), pool.count());
    try std.testing.expect(pool.isAlive(e1));
    try std.testing.expect(pool.isAlive(e2));

    try std.testing.expect(pool.destroy(e1));
    try std.testing.expectEqual(@as(u32, 1), pool.count());
    try std.testing.expect(!pool.isAlive(e1));
    try std.testing.expect(pool.isAlive(e2));
}

test "entity pool generation prevents stale access" {
    var pool = EntityPool.init(std.testing.allocator);
    defer pool.deinit();

    const e1 = try pool.create();
    try std.testing.expect(pool.destroy(e1));

    // Reuse the slot — new entity gets bumped generation
    const e3 = try pool.create();
    try std.testing.expectEqual(e1.index, e3.index);
    try std.testing.expect(e3.generation != e1.generation);

    // Old handle is stale
    try std.testing.expect(!pool.isAlive(e1));
    try std.testing.expect(pool.isAlive(e3));
}

test "entity pool nil not alive" {
    var pool = EntityPool.init(std.testing.allocator);
    defer pool.deinit();
    try std.testing.expect(!pool.isAlive(Entity.nil));
}
