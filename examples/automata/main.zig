const std = @import("std");
const vexel = @import("vexel");
const ca = @import("ca");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();

    var app = try vexel.App.init(gpa.allocator(), .{ .project_dir = "." });
    defer app.deinit();

    app.registerSimulation("automata", ca.shade);

    try app.run();
}
