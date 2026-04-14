//! Vexel — terminal graphics runtime library.
//!
//! Two usage modes:
//!   1. Standalone: `zig build run -- path/to/project/` (uses src/bin/main.zig)
//!   2. Library: import "vexel" in your Zig project, embed the Lua runtime
//!
//! See examples/ for Lua project examples.

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
