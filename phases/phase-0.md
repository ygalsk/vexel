# Phase 0: Skeleton — DONE

## Goal
New repo, build system with all deps, terminal init, Lua integration, main loop.

## Deliverables
- [x] `build.zig` + `build.zig.zon` with libvaxis, ziglua, zqlite
- [x] Terminal init via vaxis (alt screen, raw mode, capability query)
- [x] Lua 5.4 state init, load `main.lua`, call `engine.load/update/draw`
- [x] Input event translation (key press/release, mouse)
- [x] Basic text + rect rendering via vaxis cells
- [x] `engine.graphics.draw_text()`, `draw_rect()`, `clear()`, `get_size()`
- [x] `engine.on_key()`, `engine.on_mouse()` callbacks
- [x] `engine.quit_game()` + `engine.should_quit`
- [x] 60fps frame cap with dt timing
- [x] Hello World test game (`games/hello/main.lua`)

## Test Game
"Hello World" — prints text, responds to arrow keys to move text around, 'q' or Ctrl+C to quit.

## Files Created
```
build.zig, build.zig.zon
src/main.zig
src/engine/input.zig
src/graphics/renderer.zig
src/scripting/lua_engine.zig
src/scripting/lua_api.zig
games/hello/main.lua
```
