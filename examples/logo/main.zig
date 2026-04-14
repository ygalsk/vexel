const std = @import("std");
const vexel = @import("vexel");
const logo_shader = @import("logo_shader");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();

    var app = try vexel.App.init(gpa.allocator(), .{ .project_dir = "." });
    defer app.deinit();

    app.registerPixelShader("logo", logo_shader.render_pixel);

    try app.run();
}
