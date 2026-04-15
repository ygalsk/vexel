const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vexel_dep = b.dependency("vexel", .{
        .target = target,
        .optimize = optimize,
    });

    const ca_mod = b.createModule(.{
        .root_source_file = b.path("ca.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "automata-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vexel", .module = vexel_dep.module("vexel") },
                .{ .name = "ca", .module = ca_mod },
            },
        }),
    });
    exe.link_gc_sections = true;

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the 3D cellular automata demo");
    run_step.dependOn(&run_cmd.step);
}
