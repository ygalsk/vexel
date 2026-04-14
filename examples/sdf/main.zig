const std = @import("std");
const vexel = @import("vexel");
const sdf = @import("sdf");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();

    var app = try vexel.App.init(gpa.allocator(), .{ .project_dir = "." });
    defer app.deinit();

    app.registerModule("sdf", sdf);
    app.registerPixelShader("sdf", sdf.render_pixel);

    try app.run();
}
