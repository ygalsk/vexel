const std = @import("std");

pub const Logger = struct {
    file: ?std.fs.File,
    stderr_mirror: bool,
    last_error_time: ?i64,
    last_msg_hash: u64,
    last_msg_count: u32,
    last_flush_ms: i64,

    pub fn init(project_dir: []const u8) Logger {
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const path: ?[]const u8 = std.fmt.bufPrint(&path_buf, "{s}/vexel.log", .{project_dir}) catch null;

        var file: ?std.fs.File = null;
        if (path) |p| {
            const f = std.fs.cwd().openFile(p, .{ .mode = .write_only }) catch
                (std.fs.cwd().createFile(p, .{ .truncate = false }) catch null);
            if (f) |ff| {
                ff.seekFromEnd(0) catch {};
                writeSessionHeader(ff);
                file = ff;
            } else {
                stderrPrint("vexel: warning: could not open {s}, stderr-only logging\n", .{p});
            }
        }

        return .{
            .file = file,
            .stderr_mirror = !std.fs.File.stderr().isTty(),
            .last_error_time = null,
            .last_msg_hash = 0,
            .last_msg_count = 0,
            .last_flush_ms = std.time.milliTimestamp(),
        };
    }

    pub fn deinit(self: *Logger) void {
        if (self.last_msg_count > 1) self.flushDedupeCount();
        if (self.file) |f| f.close();
        self.file = null;
    }

    pub fn logError(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.last_error_time = std.time.milliTimestamp();
        self.writeLine("ERR", fmt, args);
    }

    pub fn logWarn(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.writeLine("WRN", fmt, args);
    }

    pub fn logInfo(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.writeLine("INF", fmt, args);
    }

    pub fn hasRecentError(self: *const Logger, now_ms: i64) bool {
        const t = self.last_error_time orelse return false;
        return (now_ms - t) < 5000;
    }

    pub fn lastErrorHMS(self: *const Logger) [8]u8 {
        return toHMS(self.last_error_time orelse 0);
    }

    fn writeLine(self: *Logger, level: []const u8, comptime fmt: []const u8, args: anytype) void {
        var msg_buf: [1024]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, fmt, args) catch "format error";

        const hash = fnv1a(msg);
        const now = std.time.milliTimestamp();

        if (hash == self.last_msg_hash and self.last_msg_count > 0) {
            self.last_msg_count += 1;
            if (now - self.last_flush_ms >= 1000) self.flushDedupeCount();
            return;
        }
        if (self.last_msg_count > 1) self.flushDedupeCount();

        self.last_msg_hash = hash;
        self.last_msg_count = 1;
        self.last_flush_ms = now;

        var line_buf: [1088]u8 = undefined;
        const hms = toHMS(now);
        const line = std.fmt.bufPrint(&line_buf, "[{s}] {s} {s}\n", .{ &hms, level, msg }) catch return;
        self.emit(line);
    }

    fn flushDedupeCount(self: *Logger) void {
        var buf: [48]u8 = undefined;
        const line = std.fmt.bufPrint(&buf, "    (x{d} repeated)\n", .{self.last_msg_count}) catch return;
        self.emit(line);
        self.last_msg_count = 1;
        self.last_flush_ms = std.time.milliTimestamp();
    }

    fn emit(self: *const Logger, line: []const u8) void {
        if (self.file) |f| f.writeAll(line) catch {};
        if (self.stderr_mirror) stderrPrint("{s}", .{line});
    }

    fn writeSessionHeader(f: std.fs.File) void {
        const now = std.time.milliTimestamp();
        const hms = toHMS(now);
        var buf: [64]u8 = undefined;
        const line = std.fmt.bufPrint(&buf, "=== vexel session {s} ===\n", .{&hms}) catch return;
        f.writeAll(line) catch {};
    }
};

fn toHMS(ms: i64) [8]u8 {
    const s = @divTrunc(if (ms >= 0) ms else 0, 1000);
    const sec: u64 = @intCast(@mod(s, 60));
    const min: u64 = @intCast(@mod(@divTrunc(s, 60), 60));
    const hour: u64 = @intCast(@mod(@divTrunc(s, 3600), 24));
    var buf: [8]u8 = undefined;
    _ = std.fmt.bufPrint(&buf, "{d:0>2}:{d:0>2}:{d:0>2}", .{ hour, min, sec }) catch {};
    return buf;
}

fn fnv1a(s: []const u8) u64 {
    var h: u64 = 14695981039346656037;
    for (s) |b| {
        h ^= b;
        h *%= 1099511628211;
    }
    return h;
}

fn stderrPrint(comptime fmt: []const u8, args: anytype) void {
    var buf: [1152]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
    std.fs.File.stderr().writeAll(msg) catch {};
}
