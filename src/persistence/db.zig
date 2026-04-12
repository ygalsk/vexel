const std = @import("std");
const zqlite = @import("zqlite");

const Allocator = std.mem.Allocator;

pub const Db = struct {
    conn: zqlite.Conn,

    pub fn open(path: [:0]const u8) !Db {
        const flags = zqlite.OpenFlags.Create | zqlite.OpenFlags.EXResCode;
        const conn = try zqlite.open(path.ptr, flags);
        return .{ .conn = conn };
    }

    pub fn close(self: *Db) void {
        self.conn.close();
    }

    pub fn execNoArgs(self: *Db, sql: [:0]const u8) !void {
        try self.conn.execNoArgs(sql);
    }
};

pub const SaveDb = struct {
    db: ?Db,
    game_dir: []const u8,
    allocator: Allocator,

    pub fn init(allocator: Allocator, game_dir: []const u8) SaveDb {
        return .{
            .db = null,
            .game_dir = game_dir,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SaveDb) void {
        if (self.db) |*db| {
            db.close();
        }
    }

    fn ensureOpen(self: *SaveDb) !*Db {
        if (self.db) |*db| return db;

        // Build path: game_dir/save.db
        const path = try std.fs.path.joinZ(self.allocator, &.{ self.game_dir, "save.db" });
        defer self.allocator.free(path);

        self.db = try Db.open(path);

        // Create kv table if it doesn't exist
        try self.db.?.conn.execNoArgs(
            "CREATE TABLE IF NOT EXISTS kv_store (key TEXT PRIMARY KEY, value TEXT)",
        );

        return &self.db.?;
    }

    pub fn set(self: *SaveDb, key: [:0]const u8, value: [:0]const u8) !void {
        const db = try self.ensureOpen();
        try db.conn.exec(
            "INSERT OR REPLACE INTO kv_store (key, value) VALUES (?1, ?2)",
            .{ key, value },
        );
    }

    pub fn get(self: *SaveDb, key: [:0]const u8) !?[]const u8 {
        const db = try self.ensureOpen();
        if (try db.conn.row("SELECT value FROM kv_store WHERE key = ?1", .{key})) |row| {
            defer row.deinit();
            return row.text(0);
        }
        return null;
    }
};
