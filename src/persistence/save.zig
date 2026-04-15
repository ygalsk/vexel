const std = @import("std");
const Allocator = std.mem.Allocator;

pub const SaveFs = struct {
    allocator: Allocator,
    saves_dir: []const u8,

    pub fn init(allocator: Allocator, project_dir: []const u8) SaveFs {
        return .{
            .allocator = allocator,
            .saves_dir = project_dir,
        };
    }

    /// Write content to saves/<name>.lua atomically (write tmp, then rename).
    pub fn writeFile(self: *SaveFs, name: []const u8, content: []const u8) !void {
        try validateName(name);
        var dir = try self.ensureSavesDir();
        defer dir.close();

        // Write to temp file first
        const tmp_name = try std.fmt.allocPrint(self.allocator, ".{s}.tmp", .{name});
        defer self.allocator.free(tmp_name);

        const file_name = try std.fmt.allocPrint(self.allocator, "{s}.lua", .{name});
        defer self.allocator.free(file_name);

        const tmp_file = try dir.createFile(tmp_name, .{});
        errdefer dir.deleteFile(tmp_name) catch {};
        try tmp_file.writeAll(content);
        tmp_file.close();

        // Atomic rename
        dir.rename(tmp_name, file_name) catch |err| {
            dir.deleteFile(tmp_name) catch {};
            return err;
        };
    }

    /// Read saves/<name>.lua, returns content or null if not found.
    /// Caller owns returned memory.
    pub fn readFile(self: *SaveFs, name: []const u8) !?[]const u8 {
        try validateName(name);
        const path = try self.buildPath(name);
        defer self.allocator.free(path);

        const file = std.fs.openFileAbsolute(path, .{}) catch |err| {
            if (err == error.FileNotFound) return null;
            return err;
        };
        defer file.close();

        return try file.readToEndAlloc(self.allocator, 1024 * 1024); // 1MB limit
    }

    /// Delete saves/<name>.lua. No error if file doesn't exist.
    pub fn deleteFile(self: *SaveFs, name: []const u8) !void {
        try validateName(name);
        const path = try self.buildPath(name);
        defer self.allocator.free(path);

        std.fs.deleteFileAbsolute(path) catch |err| {
            if (err == error.FileNotFound) return;
            return err;
        };
    }

    /// List save file names (without .lua extension). Caller owns returned slices.
    pub fn listFiles(self: *SaveFs, allocator: Allocator) ![][]const u8 {
        const dir_path = try std.fs.path.join(self.allocator, &.{ self.saves_dir, "saves" });
        defer self.allocator.free(dir_path);

        var dir = std.fs.openDirAbsolute(dir_path, .{ .iterate = true }) catch |err| {
            if (err == error.FileNotFound) return &.{};
            return err;
        };
        defer dir.close();

        var names: std.ArrayListUnmanaged([]const u8) = .empty;
        errdefer {
            for (names.items) |n| allocator.free(n);
            names.deinit(allocator);
        }

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;
            if (std.mem.endsWith(u8, entry.name, ".lua")) {
                const stem = entry.name[0 .. entry.name.len - 4];
                try names.append(allocator, try allocator.dupe(u8, stem));
            }
        }

        return try names.toOwnedSlice(allocator);
    }

    fn buildPath(self: *SaveFs, name: []const u8) ![]const u8 {
        const file_name = try std.fmt.allocPrint(self.allocator, "{s}.lua", .{name});
        defer self.allocator.free(file_name);
        return try std.fs.path.join(self.allocator, &.{ self.saves_dir, "saves", file_name });
    }

    fn ensureSavesDir(self: *SaveFs) !std.fs.Dir {
        const dir_path = try std.fs.path.join(self.allocator, &.{ self.saves_dir, "saves" });
        defer self.allocator.free(dir_path);
        std.fs.makeDirAbsolute(dir_path) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };
        return try std.fs.openDirAbsolute(dir_path, .{});
    }

    fn validateName(name: []const u8) !void {
        if (name.len == 0) return error.InvalidName;
        for (name) |c| {
            if (c == '/' or c == '\\' or c == 0) return error.InvalidName;
        }
        if (std.mem.indexOf(u8, name, "..") != null) return error.InvalidName;
    }

    pub const Error = error{InvalidName};
};

test "validateName rejects bad names" {
    try SaveFs.validateName("player");
    try SaveFs.validateName("high_score");
    try std.testing.expectError(error.InvalidName, SaveFs.validateName(""));
    try std.testing.expectError(error.InvalidName, SaveFs.validateName("../escape"));
    try std.testing.expectError(error.InvalidName, SaveFs.validateName("a/b"));
    try std.testing.expectError(error.InvalidName, SaveFs.validateName("a\\b"));
}

test "write and read round-trip" {
    const allocator = std.testing.allocator;
    var save = SaveFs.init(allocator, "/tmp");

    // Clean up from prior runs
    save.deleteFile("test_roundtrip") catch {};

    try save.writeFile("test_roundtrip", "return { score = 42 }");
    const content = try save.readFile("test_roundtrip");
    defer if (content) |c| allocator.free(c);

    try std.testing.expectEqualStrings("return { score = 42 }", content.?);

    // Clean up
    try save.deleteFile("test_roundtrip");

    // Read non-existent returns null
    const missing = try save.readFile("nonexistent");
    try std.testing.expect(missing == null);
}
