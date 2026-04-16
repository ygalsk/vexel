const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // --- Dependencies ---
    const vaxis_dep = b.dependency("vaxis", .{
        .target = target,
        .optimize = optimize,
    });

    const zlua_dep = b.dependency("zlua", .{
        .target = target,
        .optimize = optimize,
        .lang = .lua54,
    });

    const zigimg_dep = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    });

    const truetype_dep = b.dependency("TrueType", .{
        .target = target,
        .optimize = optimize,
    });

    const audio_enabled = b.option(bool, "audio", "Enable audio support (requires audio device)") orelse true;

    const zaudio_dep = if (audio_enabled) b.dependency("zaudio", .{}) else null;

    // --- Engine modules ---
    const kitty_mod = b.createModule(.{
        .root_source_file = b.path("src/graphics/kitty.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "vaxis", .module = vaxis_dep.module("vaxis") },
        },
    });

    const image_mod = b.createModule(.{
        .root_source_file = b.path("src/graphics/image.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zigimg", .module = zigimg_dep.module("zigimg") },
            .{ .name = "kitty", .module = kitty_mod },
        },
    });

    const compositing_mod = b.createModule(.{
        .root_source_file = b.path("src/graphics/compositing.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "vaxis", .module = vaxis_dep.module("vaxis") },
            .{ .name = "kitty", .module = kitty_mod },
            .{ .name = "image", .module = image_mod },
        },
    });

    const font_mod = b.createModule(.{
        .root_source_file = b.path("src/graphics/font.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "compositing", .module = compositing_mod },
            .{ .name = "TrueType", .module = truetype_dep.module("TrueType") },
        },
    });

    const default_font_mod = b.createModule(.{
        .root_source_file = b.path("src/graphics/default_font.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "compositing", .module = compositing_mod },
            .{ .name = "font", .module = font_mod },
        },
    });

    const sprite_placer_mod = b.createModule(.{
        .root_source_file = b.path("src/graphics/sprite_placer.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "vaxis", .module = vaxis_dep.module("vaxis") },
            .{ .name = "compositing", .module = compositing_mod },
            .{ .name = "image", .module = image_mod },
            .{ .name = "kitty", .module = kitty_mod },
        },
    });

    const lua_bind_mod = b.createModule(.{
        .root_source_file = b.path("src/scripting/lua_bind.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zlua", .module = zlua_dep.module("zlua") },
            .{ .name = "compositing", .module = compositing_mod },
        },
    });

    const input_mod = b.createModule(.{
        .root_source_file = b.path("src/engine/input.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "vaxis", .module = vaxis_dep.module("vaxis") },
        },
    });

    const save_mod = b.createModule(.{
        .root_source_file = b.path("src/persistence/save.zig"),
        .target = target,
        .optimize = optimize,
    });

    const audio_mod = if (zaudio_dep) |dep| b.createModule(.{
        .root_source_file = b.path("src/audio/audio.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zaudio", .module = dep.module("root") },
        },
    }) else null;

    const engine_log_mod = b.createModule(.{
        .root_source_file = b.path("src/engine/log.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lua_engine_mod = b.createModule(.{
        .root_source_file = b.path("src/scripting/lua_engine.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zlua", .module = zlua_dep.module("zlua") },
        },
    });

    const lua_api_mod = b.createModule(.{
        .root_source_file = b.path("src/scripting/lua_api.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zlua", .module = zlua_dep.module("zlua") },
            .{ .name = "compositing", .module = compositing_mod },
            .{ .name = "sprite_placer", .module = sprite_placer_mod },
            .{ .name = "image", .module = image_mod },
            .{ .name = "lua_bind", .module = lua_bind_mod },
            .{ .name = "input", .module = input_mod },
            .{ .name = "save", .module = save_mod },
            .{ .name = "font", .module = font_mod },
        },
    });
    if (audio_mod) |am| {
        lua_api_mod.addImport("audio", am);
    }

    const app_mod = b.createModule(.{
        .root_source_file = b.path("src/app.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "vaxis", .module = vaxis_dep.module("vaxis") },
            .{ .name = "zlua", .module = zlua_dep.module("zlua") },
            .{ .name = "kitty", .module = kitty_mod },
            .{ .name = "compositing", .module = compositing_mod },
            .{ .name = "sprite_placer", .module = sprite_placer_mod },
            .{ .name = "image", .module = image_mod },
            .{ .name = "input", .module = input_mod },
            .{ .name = "lua_engine", .module = lua_engine_mod },
            .{ .name = "lua_api", .module = lua_api_mod },
            .{ .name = "lua_bind", .module = lua_bind_mod },
            .{ .name = "save", .module = save_mod },
            .{ .name = "font", .module = font_mod },
            .{ .name = "default_font", .module = default_font_mod },
            .{ .name = "engine_log", .module = engine_log_mod },
        },
    });
    if (audio_mod) |am| {
        app_mod.addImport("audio", am);
    }

    // --- Library module (for downstream Zig projects) ---
    const vexel_mod = b.addModule("vexel", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "app", .module = app_mod },
        },
    });
    // Link C libraries into the module so downstream consumers get them automatically
    if (zaudio_dep) |dep| {
        vexel_mod.linkLibrary(dep.artifact("miniaudio"));
    }

    // --- Executable ---
    const exe = b.addExecutable(.{
        .name = "vexel",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bin/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vaxis", .module = vaxis_dep.module("vaxis") },
                .{ .name = "app", .module = app_mod },
            },
        }),
    });
    exe.link_gc_sections = true;
    if (zaudio_dep) |dep| {
        exe.linkLibrary(dep.artifact("miniaudio"));
    }

    b.installArtifact(exe);

    // --- Run step ---
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run a project: zig build run -- path/to/project/");
    run_step.dependOn(&run_cmd.step);

    // --- Test step ---
    const test_step = b.step("test", "Run unit tests");

    const test_modules = [_]struct { path: []const u8, imports: []const std.Build.Module.Import } {
        .{ .path = "src/engine/input.zig", .imports = &.{
            .{ .name = "vaxis", .module = vaxis_dep.module("vaxis") },
        }},
        .{ .path = "src/graphics/kitty.zig", .imports = &.{
            .{ .name = "vaxis", .module = vaxis_dep.module("vaxis") },
        }},
        .{ .path = "src/graphics/image.zig", .imports = &.{
            .{ .name = "zigimg", .module = zigimg_dep.module("zigimg") },
            .{ .name = "kitty", .module = kitty_mod },
        }},
        .{ .path = "src/graphics/compositing.zig", .imports = &.{
            .{ .name = "vaxis", .module = vaxis_dep.module("vaxis") },
            .{ .name = "kitty", .module = kitty_mod },
            .{ .name = "image", .module = image_mod },
        }},
        .{ .path = "src/graphics/font.zig", .imports = &.{
            .{ .name = "compositing", .module = compositing_mod },
            .{ .name = "TrueType", .module = truetype_dep.module("TrueType") },
        }},
        .{ .path = "src/graphics/default_font.zig", .imports = &.{
            .{ .name = "compositing", .module = compositing_mod },
            .{ .name = "font", .module = font_mod },
        }},
        .{ .path = "src/graphics/sprite_placer.zig", .imports = &.{
            .{ .name = "vaxis", .module = vaxis_dep.module("vaxis") },
            .{ .name = "compositing", .module = compositing_mod },
            .{ .name = "image", .module = image_mod },
            .{ .name = "kitty", .module = kitty_mod },
        }},
        .{ .path = "src/scripting/lua_engine.zig", .imports = &.{
            .{ .name = "zlua", .module = zlua_dep.module("zlua") },
        }},
        .{ .path = "src/persistence/save.zig", .imports = &.{
        }},
    };

    for (test_modules) |tm| {
        const unit_test = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(tm.path),
                .target = target,
                .optimize = optimize,
                .imports = tm.imports,
            }),
        });
        unit_test.link_gc_sections = true;
        const run_test = b.addRunArtifact(unit_test);
        test_step.dependOn(&run_test.step);
    }

    {
        const lua_api_test = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/scripting/lua_api.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "zlua", .module = zlua_dep.module("zlua") },
                    .{ .name = "compositing", .module = compositing_mod },
                    .{ .name = "sprite_placer", .module = sprite_placer_mod },
                    .{ .name = "image", .module = image_mod },
                    .{ .name = "lua_bind", .module = lua_bind_mod },
                    .{ .name = "input", .module = input_mod },
                    .{ .name = "save", .module = save_mod },
                    .{ .name = "font", .module = font_mod },
                },
            }),
        });
        if (audio_mod) |am| lua_api_test.root_module.addImport("audio", am);
        lua_api_test.link_gc_sections = true;
        test_step.dependOn(&b.addRunArtifact(lua_api_test).step);
    }

}
