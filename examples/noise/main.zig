const std = @import("std");
const vexel = @import("vexel");
const noise = @import("noise");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();

    var app = try vexel.App.init(gpa.allocator(), .{ .project_dir = "." });
    defer app.deinit();

    app.registerModule("noise", noise);

    try app.run();
}
