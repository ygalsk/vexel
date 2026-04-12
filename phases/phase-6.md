# Phase 6: Robustness

## Goal
Harden the engine so Lua errors, panics, and signals don't leave the terminal in a broken state.

## Deliverables

- [ ] Error recovery — Lua errors don't crash the engine
- [ ] Terminal restore on panic — clean up raw mode, alt screen
- [ ] Graceful degradation logging — warn on missing capabilities
- [ ] Signal handling — SIGINT, SIGTERM clean shutdown

## Files
```
src/main.zig                — MODIFY (panic handler, signal handler, graceful shutdown)
src/scripting/lua_engine.zig — MODIFY (protected Lua calls, error recovery)
src/graphics/renderer.zig   — MODIFY (terminal restore on panic)
```
