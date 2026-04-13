# Vexel Progress

## Phase Status

| Phase | Name | Status |
|-------|------|--------|
| 0 | Skeleton | Done |
| 1 | Kitty Graphics + Pixel Rendering | Done (adapted) |
| 2 | Image & Sprite Support | Done |
| 3 | Input & Scene Management | Done |
| 4 | Audio | Done |
| 5 | Tilemap & Persistence | Done |
| 6 | Robustness | Not started |
| 7 | Entity Component System | Done |
| 8 | Documentation | Not started |
| 9 | Codecritter Port | Not started |

## Recent
- Simplify battle UI: removed dead widgets (message_log, archetype_badge), hoisted per-frame table allocations (status_icon, rarity_stars), extracted menu background helper and minion labels constant

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

### Phase 4 — Audio
- miniaudio integration via zaudio (zig-gamedev) with high-level `ma_engine` API
- Audio device init/deinit with graceful fallback when no device available
- Load WAV, OGG, MP3 files (preloaded or streaming)
- Slot-based sound handle management with free list recycling
- Playback control: play, stop, pause, resume with per-sound options
- Volume control per sound and master volume
- Stereo panning (-1.0 left to 1.0 right)
- Fade in/out with millisecond duration
- Sound handles as Lua userdata with GC finalizers
- Optional build flag: `-Daudio=false` disables audio compilation
- Game-relative path resolution for asset loading
- Test game: `games/rhythm/` (4-lane rhythm game with music + SFX)

### Phase 5 — Tilemap & Persistence
- Timer system: one-shot (`after`) and repeating (`every`) timers with cancel
- Tween system: smooth interpolation of Lua table fields with easing functions
  - Easing: linear, ease_in, ease_out, ease_in_out (quadratic)
  - On-complete callbacks
- SQLite persistence via zqlite
  - Raw SQL: `engine.db.open/exec/query/close` with bind parameters
  - Key-value sugar: `engine.save.set/get` (auto-creates save.db in game dir)
  - DB handles as Lua userdata with GC finalizers
- Tilemap renderer: draw tile-based maps with sprite sheet tilesets
  - Viewport culling (only renders visible tiles)
  - Smooth scrolling via sub-pixel camera offsets
  - Dev-assigned compositor layers
- Test game: `games/roguelike/` (procedural dungeon, save/load, tween camera)

### Phase 7 — Entity Component System
- Sparse-set ECS with generation-counted entity IDs
- Built-in Zig components: Position, Velocity, SpriteComp, Animation, Collider, Tag
- Lua-defined components in sparse-set stores (dense iteration, O(1) indexed access)
- Built-in systems: movement (Position += Velocity * dt), animation ticking, sprite rendering
- Lua API: `engine.world.spawn/despawn/set/get/remove/is_alive/each/count`
- Iterator: `for entity, pos, vel in engine.world.each("position", "velocity") do`
- Sprites are first-class ECS citizens (replaced old SpriteSystem)
- Animation events fire Lua on_complete callbacks
- Layer-sorted rendering (0-7)
- Accepts VexelImage userdata or integer handles for sprite images
- Test game: `games/ecs-demo/` (knight + spawnable fire skulls)

## Source Files

```
src/main.zig                    — Entry point, main loop, event handling
src/engine/input.zig            — Key/mouse event translation, input state tracker
src/engine/scene.zig            — Scene manager (stack, transitions, legacy mode)
src/engine/timer.zig            — Timer/tween system (one-shot, repeating, interpolation)
src/graphics/renderer.zig       — High-level rendering facade
src/graphics/kitty.zig          — Kitty graphics protocol (upload, free)
src/graphics/compositing.zig    — Layer compositor (pixel buffer, blending)
src/graphics/image.zig          — Image loading, caching, sprite sheets
src/graphics/sprite_placer.zig  — Per-frame kitty image placements
src/graphics/tilemap.zig        — Tilemap renderer (sprite sheet tiles, viewport culling)
src/ecs/entity.zig              — Entity type (generation-counted IDs), EntityPool
src/ecs/component_store.zig     — Generic ComponentStore(T), LuaComponentStore
src/ecs/world.zig               — ECS World: entities, components, built-in systems
src/scripting/lua_engine.zig    — Lua state management, lifecycle calls
src/scripting/lua_api.zig       — Lua API bindings (engine.* table)
src/scripting/lua_ecs.zig       — ECS Lua bindings (engine.world.* table)
src/audio/audio.zig             — Audio system (zaudio/miniaudio wrapper)
src/persistence/db.zig          — SQLite wrapper (zqlite) + key-value save API
```
