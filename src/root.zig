//! Vexel — terminal graphics runtime library.
//!
//! Zig 0.15 + Lua 5.4, Kitty graphics protocol, 60fps.
//!
//! ## Quick start (library usage)
//!
//! ```zig
//! const vexel = @import("vexel");
//!
//! pub fn main() !void {
//!     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//!     defer _ = gpa.deinit();
//!
//!     var app = try vexel.App.init(gpa.allocator(), .{ .project_dir = "." });
//!     defer app.deinit();
//!
//!     // Optional: register Zig modules callable from Lua
//!     app.registerModule("mymod", MyZigModule);
//!
//!     try app.run();
//! }
//! ```
//!
//! ## Hybrid Zig+Lua
//!
//! For compute-heavy work, write a Zig struct with pub functions and register it
//! via `App.registerModule`. Pure functions (Zig args/return) are auto-wrapped.
//! Functions needing engine access take `(*EngineContext, *Lua)` — see
//! `examples/fractal-zig/` for a complete example.

/// High-level application facade. Wraps all engine subsystems (renderer, input,
/// audio, ECS, Lua VM, scenes, timers, persistence) behind init/run/deinit.
/// Register Zig modules with `registerModule()` before calling `run()`.
pub const App = @import("app").App;

/// Engine context passed to tier-2 Lua-bound Zig functions. Provides direct
/// access to subsystems (renderer, input, audio, ECS world, etc.) for
/// operations that bypass the Lua stack — e.g. blitting pixel buffers.
pub const EngineContext = @import("lua_api").EngineContext;

/// Lua 5.4 VM handle (from zlua). Used as a parameter type in tier-2
/// Lua-bound functions to read arguments and push return values.
pub const Lua = @import("zlua").Lua;
