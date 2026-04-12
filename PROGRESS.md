# Vexel Progress

## Phase Status

| Phase | Name | Status |
|-------|------|--------|
| 0 | Skeleton | Done |
| 1 | Kitty Graphics + Pixel Rendering | Done (adapted) |
| 2 | Image & Sprite Support | Done |
| 3 | Input & Scene Management | Done |
| 4 | Audio | Not started |
| 5 | Tilemap & Persistence | Not started |
| 6 | Polish & Codecritter Port | Partially started (1/17) |

## What's Built

### Phase 0 — Skeleton
- Build system (Zig 0.15.2 + libvaxis + ziglua + zqlite + zigimg)
- Terminal init via vaxis (alt screen, raw mode, kitty keyboard)
- Lua 5.4 integration with `engine.load/update/draw/quit` lifecycle
- Input translation (keyboard + mouse)
- Basic cell-based text and rectangle rendering
- 60fps frame cap with delta timing
- Test game: `games/hello/`

### Phase 1 — Kitty Graphics (adapted)
Phase 1's original plan included sub-cell/sextant rendering. The implementation instead went full pixel via the kitty graphics protocol compositor, which is strictly more capable. Sub-cell primitives were not needed.

- Kitty graphics protocol: RGBA upload, image ID management, placement, deletion
- Pixel buffer compositor with 8 layers, dirty tracking, alpha blending
- Primitive drawing: `pixel.rect`, `pixel.line`, `pixel.circle`, `pixel.clear`
- Virtual resolution system (`set_resolution` / `get_resolution`)
- Layer control (`set_layer`, `clear_all`)
- Sprite placer mode for per-frame kitty image placements (avoids re-compositing)
- Test game: `games/bounce/`

### Phase 2 — Image & Sprite Support
- PNG loading via zigimg with RGBA conversion
- Image caching with path-based dedup and ref counting
- Sprite sheet slicing (tile dimensions, frame grid)
- Retained sprite system with proxy tables and metamethods
- Animation system: frame lists, speed, looping, on_complete callbacks
- Flip variants (x/y/both) with lazy pixel buffer generation
- Pre-scaled terminal image upload for crisp pixel art
- GC finalizers for automatic resource cleanup
- Test games: `games/sprites/`, `games/platformer/`

### Phase 3 — Input & Scene Management
- Input state tracker: key-down table, mouse position/buttons, gamepad abstraction
- Input state queries: `engine.input.is_key_down(key)`, `engine.input.get_mouse()`, `engine.input.get_gamepad()`
- Scene manager with push/pop/switch stack operations
- Scene callbacks: load, update, draw, on_key, on_mouse, unload, pause, resume
- Scene-to-scene data passing via registry refs
- Transition system: fade (alpha lerp), slide_left, slide_right, wipe
- Custom transition duration with compositor snapshot blending
- Legacy mode: existing games without scenes work unchanged
- Lua `require()` support from game directories
- Test game: `games/scenes/` (menu → dragon flight → pause)

## Source Files

```
src/main.zig                    — Entry point, main loop, event handling
src/engine/input.zig            — Key/mouse event translation, input state tracker
src/engine/scene.zig            — Scene manager (stack, transitions, legacy mode)
src/graphics/renderer.zig       — High-level rendering facade
src/graphics/kitty.zig          — Kitty graphics protocol (upload, free)
src/graphics/compositing.zig    — Layer compositor (pixel buffer, blending)
src/graphics/image.zig          — Image loading, caching, sprite sheets
src/graphics/sprite_placer.zig  — Per-frame kitty image placements
src/scripting/lua_engine.zig    — Lua state management, lifecycle calls
src/scripting/lua_api.zig       — Lua API bindings (engine.* table)
src/scripting/sprite_system.zig — Retained sprite system, animations
```
