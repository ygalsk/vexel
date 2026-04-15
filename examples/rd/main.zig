const std = @import("std");
const vexel = @import("vexel");
const rd = @import("rd");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();

    var app = try vexel.App.init(gpa.allocator(), .{ .project_dir = "." });
    defer app.deinit();

    app.registerSimulation("rd", rd.shade);

    try app.run();
}
