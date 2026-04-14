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

/// High-level application facade. Wraps all engine subsystems (renderer, input,
/// audio, ECS, Lua VM, scenes, timers, persistence) behind init/run/deinit.
/// Register Zig modules with `registerModule()` before calling `run()`.
pub const App = @import("app").App;
