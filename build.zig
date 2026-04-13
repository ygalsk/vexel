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

    const zqlite_dep = b.dependency("zqlite", .{
        .target = target,
        .optimize = optimize,
    });

    const zigimg_dep = b.dependency("zigimg", .{
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
        },
    });

    const sprite_placer_mod = b.createModule(.{
        .root_source_file = b.path("src/graphics/sprite_placer.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "vaxis", .module = vaxis_dep.module("vaxis") },
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

    const renderer_mod = b.createModule(.{
        .root_source_file = b.path("src/graphics/renderer.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "vaxis", .module = vaxis_dep.module("vaxis") },
            .{ .name = "kitty", .module = kitty_mod },
            .{ .name = "compositing", .module = compositing_mod },
            .{ .name = "image", .module = image_mod },
            .{ .name = "sprite_placer", .module = sprite_placer_mod },
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

    const scene_mod = b.createModule(.{
        .root_source_file = b.path("src/engine/scene.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zlua", .module = zlua_dep.module("zlua") },
            .{ .name = "renderer", .module = renderer_mod },
            .{ .name = "compositing", .module = compositing_mod },
        },
    });

    const timer_mod = b.createModule(.{
        .root_source_file = b.path("src/engine/timer.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zlua", .module = zlua_dep.module("zlua") },
        },
    });

    // --- ECS modules ---
    const ecs_entity_mod = b.createModule(.{
        .root_source_file = b.path("src/ecs/entity.zig"),
        .target = target,
        .optimize = optimize,
    });

    const ecs_component_store_mod = b.createModule(.{
        .root_source_file = b.path("src/ecs/component_store.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "entity", .module = ecs_entity_mod },
        },
    });

    const ecs_world_mod = b.createModule(.{
        .root_source_file = b.path("src/ecs/world.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "entity", .module = ecs_entity_mod },
            .{ .name = "component_store", .module = ecs_component_store_mod },
        },
    });

    const tilemap_mod = b.createModule(.{
        .root_source_file = b.path("src/graphics/tilemap.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "renderer", .module = renderer_mod },
        },
    });

    const db_mod = b.createModule(.{
        .root_source_file = b.path("src/persistence/db.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zqlite", .module = zqlite_dep.module("zqlite") },
        },
    });

    const audio_mod = if (zaudio_dep) |dep| b.createModule(.{
        .root_source_file = b.path("src/audio/audio.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zaudio", .module = dep.module("root") },
        },
    }) else null;

    const lua_engine_mod = b.createModule(.{
        .root_source_file = b.path("src/scripting/lua_engine.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zlua", .module = zlua_dep.module("zlua") },
        },
    });

    const lua_ecs_mod = b.createModule(.{
        .root_source_file = b.path("src/scripting/lua_ecs.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zlua", .module = zlua_dep.module("zlua") },
            .{ .name = "ecs_world", .module = ecs_world_mod },
        },
    });

    const lua_api_mod = b.createModule(.{
        .root_source_file = b.path("src/scripting/lua_api.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zlua", .module = zlua_dep.module("zlua") },
            .{ .name = "renderer", .module = renderer_mod },
            .{ .name = "image", .module = image_mod },
            .{ .name = "scene", .module = scene_mod },
            .{ .name = "input", .module = input_mod },
            .{ .name = "timer", .module = timer_mod },
            .{ .name = "db", .module = db_mod },
            .{ .name = "tilemap", .module = tilemap_mod },
            .{ .name = "lua_ecs", .module = lua_ecs_mod },
            .{ .name = "ecs_world", .module = ecs_world_mod },
        },
    });
    if (audio_mod) |am| {
        lua_api_mod.addImport("audio", am);
    }

    // --- Library module (for downstream Zig projects) ---
    const vexel_mod = b.addModule("vexel", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "renderer", .module = renderer_mod },
            .{ .name = "image", .module = image_mod },
            .{ .name = "input", .module = input_mod },
            .{ .name = "scene", .module = scene_mod },
            .{ .name = "lua_engine", .module = lua_engine_mod },
            .{ .name = "lua_api", .module = lua_api_mod },
            .{ .name = "timer", .module = timer_mod },
            .{ .name = "db", .module = db_mod },
            .{ .name = "ecs_world", .module = ecs_world_mod },
        },
    });
    // Audio is optional — only wire it if enabled
    if (audio_mod) |am| {
        vexel_mod.addImport("audio", am);
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
                .{ .name = "zlua", .module = zlua_dep.module("zlua") },
                .{ .name = "zqlite", .module = zqlite_dep.module("zqlite") },
                .{ .name = "renderer", .module = renderer_mod },
                .{ .name = "image", .module = image_mod },
                .{ .name = "input", .module = input_mod },
                .{ .name = "scene", .module = scene_mod },
                .{ .name = "lua_engine", .module = lua_engine_mod },
                .{ .name = "lua_api", .module = lua_api_mod },
                .{ .name = "timer", .module = timer_mod },
                .{ .name = "db", .module = db_mod },
                .{ .name = "ecs_world", .module = ecs_world_mod },
            },
        }),
    });
    if (audio_mod) |am| {
        exe.root_module.addImport("audio", am);
    }
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
    const run_step = b.step("run", "Run a game: zig build run -- path/to/game/");
    run_step.dependOn(&run_cmd.step);

    // --- Test step ---
    const test_step = b.step("test", "Run unit tests");

    const test_modules = [_]struct { path: []const u8, imports: []const std.Build.Module.Import } {
        .{ .path = "src/ecs/entity.zig", .imports = &.{} },
        .{ .path = "src/ecs/component_store.zig", .imports = &.{
            .{ .name = "entity", .module = ecs_entity_mod },
        }},
        .{ .path = "src/ecs/world.zig", .imports = &.{
            .{ .name = "entity", .module = ecs_entity_mod },
            .{ .name = "component_store", .module = ecs_component_store_mod },
        }},
        .{ .path = "src/engine/input.zig", .imports = &.{
            .{ .name = "vaxis", .module = vaxis_dep.module("vaxis") },
        }},
        .{ .path = "src/graphics/kitty.zig", .imports = &.{
            .{ .name = "vaxis", .module = vaxis_dep.module("vaxis") },
        }},
        .{ .path = "src/graphics/image.zig", .imports = &.{
            .{ .name = "zigimg", .module = zigimg_dep.module("zigimg") },
        }},
        .{ .path = "src/graphics/sprite_placer.zig", .imports = &.{
            .{ .name = "vaxis", .module = vaxis_dep.module("vaxis") },
        }},
        .{ .path = "src/graphics/compositing.zig", .imports = &.{
            .{ .name = "vaxis", .module = vaxis_dep.module("vaxis") },
            .{ .name = "kitty", .module = kitty_mod },
            .{ .name = "image", .module = image_mod },
        }},
        .{ .path = "src/graphics/renderer.zig", .imports = &.{
            .{ .name = "vaxis", .module = vaxis_dep.module("vaxis") },
            .{ .name = "kitty", .module = kitty_mod },
            .{ .name = "compositing", .module = compositing_mod },
            .{ .name = "image", .module = image_mod },
            .{ .name = "sprite_placer", .module = sprite_placer_mod },
        }},
        .{ .path = "src/scripting/lua_engine.zig", .imports = &.{
            .{ .name = "zlua", .module = zlua_dep.module("zlua") },
        }},
        .{ .path = "src/engine/scene.zig", .imports = &.{
            .{ .name = "zlua", .module = zlua_dep.module("zlua") },
            .{ .name = "renderer", .module = renderer_mod },
            .{ .name = "compositing", .module = compositing_mod },
        }},
        .{ .path = "src/engine/timer.zig", .imports = &.{
            .{ .name = "zlua", .module = zlua_dep.module("zlua") },
        }},
        .{ .path = "src/graphics/tilemap.zig", .imports = &.{
            .{ .name = "renderer", .module = renderer_mod },
        }},
        .{ .path = "src/persistence/db.zig", .imports = &.{
            .{ .name = "zqlite", .module = zqlite_dep.module("zqlite") },
        }},
        .{ .path = "src/scripting/lua_api.zig", .imports = &.{
            .{ .name = "zlua", .module = zlua_dep.module("zlua") },
            .{ .name = "renderer", .module = renderer_mod },
            .{ .name = "image", .module = image_mod },
            .{ .name = "scene", .module = scene_mod },
            .{ .name = "input", .module = input_mod },
            .{ .name = "timer", .module = timer_mod },
            .{ .name = "db", .module = db_mod },
            .{ .name = "tilemap", .module = tilemap_mod },
            .{ .name = "audio", .module = audio_mod.? },
            .{ .name = "lua_ecs", .module = lua_ecs_mod },
            .{ .name = "ecs_world", .module = ecs_world_mod },
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
}
