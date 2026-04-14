//! Vexel — terminal graphics runtime library.
//!
//! Two usage modes:
//!   1. Standalone: `zig build run -- path/to/project/` (uses src/bin/main.zig)
//!   2. Library: import "vexel" in your Zig project, embed the Lua runtime
//!
//! Library quick start:
//!   var app = try vexel.App.init(allocator, .{ .project_dir = "." });
//!   defer app.deinit();
//!   app.registerModule("mymod", MyZigModule);
//!   try app.run();
//!
//! See examples/fractal-zig/ for a complete hybrid Zig+Lua example.

pub const App = @import("app").App;
pub const lua_bind = @import("lua_bind");
pub const EngineContext = @import("lua_api").EngineContext;
pub const Lua = @import("zlua").Lua;

pub const Renderer = @import("renderer");
pub const ImageManager = @import("image");
pub const Input = @import("input");
pub const SceneManager = @import("scene");
pub const TimerSystem = @import("timer").TimerSystem;
pub const SaveDb = @import("db").SaveDb;
pub const LuaEngine = @import("lua_engine");
pub const LuaApi = @import("lua_api");
pub const ecs_world = @import("ecs_world");
pub const World = ecs_world.World;
