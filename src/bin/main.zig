const std = @import("std");
const vaxis = @import("vaxis");
const App = @import("app").App;

// --- Global state for panic/signal cleanup ---
// The root source file's `panic` fn is used by Zig as the custom panic handler.
// We need globals so the handler can restore the terminal before crashing.

var g_cleanup_tty: ?*vaxis.Tty = null;
var g_cleanup_vx: ?*vaxis.Vaxis = null;

/// Custom panic handler: restore terminal before crashing.
pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    if (g_cleanup_vx) |vx| {
        if (g_cleanup_tty) |t| {
            vx.exitAltScreen(t.writer()) catch {};
        }
    }
    std.debug.defaultPanic(msg, ret_addr);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.fs.File.stderr().writeAll("Usage: vexel <project_directory>\n") catch {};
        std.process.exit(1);
    }

    var app = try App.init(allocator, .{ .project_dir = args[1] });
    defer app.deinit();

    // Enable panic cleanup now that terminal is in alt-screen
    g_cleanup_tty = &app.tty;
    g_cleanup_vx = &app.vx;

    try app.run();
}
