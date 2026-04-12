# Phase 5: Tilemap & Persistence

## Goal
Tilemap rendering with scrolling viewport. SQLite persistence for game saves. Timer/tween system.

## Deliverables

### Tilemap Renderer (`src/graphics/tilemap.zig`)
- [x] Accept map data as 1D array of tile indices (row-major, 1-based; 0 = empty)
- [x] Render visible portion of map to screen (viewport culling)
- [x] Scrolling viewport with camera position
- [x] Smooth scrolling (sub-pixel camera offsets)
- [x] Dev-assigned compositor layers (0-7)

### Persistence (`src/persistence/db.zig`)
- [x] SQLite wrapper via zqlite
- [x] Open/close database files
- [x] Execute SQL statements with parameters
- [x] Query results as Lua tables
- [x] Simple key-value save API (sugar over SQLite)
- [x] Auto-create save.db in game directory

### Lua API — Tilemap
- [x] `engine.graphics.draw_tilemap(tileset, map_data, opts)` — render tilemap with camera
- [x] Uses existing `load_spritesheet` for tileset loading

### Lua API — Persistence
- [x] `engine.db.open(path)` → db userdata
- [x] `db:exec(sql, ...)` — execute with bind parameters
- [x] `db:query(sql, ...)` → array of row tables
- [x] `db:close()` (also auto-closes via GC)
- [x] `engine.save.set(key, value)` — simple key-value
- [x] `engine.save.get(key)` → value or nil

### Timers & Tweens (`src/engine/timer.zig`)
- [x] `engine.timer.after(seconds, callback)` → handle
- [x] `engine.timer.every(seconds, callback)` → handle
- [x] `engine.timer.cancel(handle)`
- [x] `engine.tween(target, props, duration, easing?, on_complete?)` → handle
- [x] Easing functions: linear, ease_in, ease_out, ease_in_out

## Test Game
Mini roguelike with procedural map and save/load. Demonstrates:
- Tilemap rendering with scrolling
- Procedural map generation in Lua
- Save/load game state via engine.save
- Timer-based animations (blinking, timed messages)
- Tween for smooth camera following

## Files
```
src/engine/timer.zig             — NEW
src/graphics/tilemap.zig         — NEW
src/persistence/db.zig           — NEW
src/scripting/lua_api.zig        — MODIFIED (tilemap + db + timer APIs)
src/main.zig                     — MODIFIED (timer + save_db init)
build.zig                        — MODIFIED (new modules)
games/roguelike/main.lua         — NEW test game
games/roguelike/assets/tileset.png — NEW (4-tile 8x8 tileset)
```
