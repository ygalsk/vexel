# Engine Core Architecture

> 18 nodes · cohesion 0.12

## Key Concepts

- **Main Loop (~60fps)** (5 connections) — `ARCHITECTURE.md`
- **audio.zig — miniaudio Wrapper** (4 connections) — `ARCHITECTURE.md`
- **lua_engine.zig — Lua State Lifecycle** (4 connections) — `ARCHITECTURE.md`
- **Lua Lifecycle Callbacks (load/update/draw/quit)** (4 connections) — `LUA_API.md`
- **input.zig — Key/Mouse Event Translation** (3 connections) — `ARCHITECTURE.md`
- **lua_api.zig — Engine API Bindings** (3 connections) — `ARCHITECTURE.md`
- **main.zig — Standalone Binary Entry Point** (3 connections) — `ARCHITECTURE.md`
- **Lua Scene Management API** (3 connections) — `LUA_API.md`
- **miniaudio Dependency** (2 connections) — `DESIGN.md`
- **Lua Audio API** (1 connections) — `LUA_API.md`
- **Lua Graphics API Phase 0 (text/rect/clear)** (1 connections) — `LUA_API.md`
- **Scene Transitions (fade/slide/wipe)** (1 connections) — `LUA_API.md`
- **src/audio/audio.zig** (1 connections) — `PROGRESS.md`
- **src/engine/input.zig** (1 connections) — `PROGRESS.md`
- **src/scripting/lua_api.zig** (1 connections) — `PROGRESS.md`
- **src/scripting/lua_engine.zig** (1 connections) — `PROGRESS.md`
- **src/main.zig** (1 connections) — `PROGRESS.md`
- **src/engine/scene.zig** (1 connections) — `PROGRESS.md`

## Relationships

- [[Core Engine Modules]] (2 shared connections)

## Source Files

- `ARCHITECTURE.md`
- `DESIGN.md`
- `LUA_API.md`
- `PROGRESS.md`

## Audit Trail

- EXTRACTED: 27 (68%)
- INFERRED: 13 (32%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*