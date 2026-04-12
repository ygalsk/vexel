# Phase 5: Tilemap & Persistence

## Goal
Tilemap rendering with scrolling viewport. SQLite persistence for game saves.

## Deliverables

### Tilemap Renderer (`src/graphics/tilemap.zig`)
- [ ] Load tileset image (PNG sprite sheet of tiles)
- [ ] Accept map data as 2D array of tile indices
- [ ] Render visible portion of map to screen
- [ ] Scrolling viewport with camera position
- [ ] Smooth scrolling (sub-tile pixel offsets)
- [ ] Multiple tilemap layers (ground, decoration, collision)

### Persistence (`src/persistence/db.zig`)
- [ ] SQLite wrapper via zqlite
- [ ] Open/close database files
- [ ] Execute SQL statements with parameters
- [ ] Query results as Lua tables
- [ ] Simple key-value save API (sugar over SQLite)

### Lua API — Tilemap
- [ ] `engine.graphics.load_tilemap(path, tile_w, tile_h)` → tilemap handle
- [ ] `engine.graphics.draw_tilemap(tilemap, map_data, offset_x, offset_y)`
- [ ] Camera control — set viewport position

### Lua API — Persistence
- [ ] `engine.db.open(path)` → db handle
- [ ] `db:exec(sql, ...)` — execute with bind parameters
- [ ] `db:query(sql, ...)` → array of row tables
- [ ] `db:close()`
- [ ] `engine.save.set(key, value)` — simple key-value
- [ ] `engine.save.get(key)` → value
- [ ] Auto-create save directory in game dir

### Timers & Tweens
- [ ] `engine.timer.after(seconds, callback)`
- [ ] `engine.timer.every(seconds, callback)`
- [ ] `engine.timer.cancel(handle)`
- [ ] `engine.tween(target, props, duration, easing)`
- [ ] Easing functions: linear, ease_in, ease_out, ease_in_out

## Test Game
Mini roguelike with procedural map and save/load. Demonstrates:
- Tilemap rendering with scrolling
- Procedural map generation in Lua
- Save/load game state via SQLite
- Timer-based animations

## Files
```
src/graphics/tilemap.zig     — NEW
src/persistence/db.zig       — NEW
src/scripting/lua_api.zig    — MODIFY (tilemap + db + timer APIs)
games/roguelike/main.lua     — NEW test game
games/roguelike/assets/      — NEW (tileset images)
```
