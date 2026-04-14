# Vexel Architecture

## Module Structure

```
src/
  root.zig            — Library entry point: re-exports public engine types
  bin/
    main.zig          — Standalone binary: parse args, load project dir, run main loop

  engine/
    input.zig         — Key/mouse event translation from vaxis to engine types
    timer.zig         — Timer/tween system: one-shot, repeating, interpolation with easing
    scene.zig         — Scene stack: push/pop/switch with transitions (fade, slide, wipe)

  graphics/
    renderer.zig      — Kitty-based rendering: text, rects, clear, screen info
    kitty.zig         — Kitty graphics protocol: upload, place, animate, z-index
    image.zig         — Image loading (PNG via zigimg), sprite sheets, atlas
    compositing.zig   — Layer compositing, alpha blending, dirty-rect tracking
    tilemap.zig       — Tilemap rendering: viewport culling, smooth scrolling
    
  audio/
    audio.zig         — miniaudio wrapper via zaudio: device management, sound slots, playback
    
  scripting/
    lua_engine.zig    — Lua state lifecycle, project loading, callback dispatch
    lua_api.zig       — Register engine.* functions into Lua (graphics, input, etc.)
    lua_bind.zig      — Two-tier compile-time binding for user Zig modules
    lua_ecs.zig       — ECS bridge: entity spawning, component access, iteration from Lua

  ecs/
    entity.zig        — Entity type (generation-counted IDs), EntityPool
    component_store.zig — Generic ComponentStore(T), LuaComponentStore
    world.zig         — ECS World: entities, components, built-in systems

  persistence/
    db.zig            — SQLite wrapper (zqlite) + key-value save API
```

## Rendering Pipeline

```
Lua code
    │
    ▼
Rendering API  ←  draw_sprite, draw_rect, draw_text, draw_tilemap, ...
    │
    ▼
Kitty Graphics Protocol
    │
    ├── PNG/RGBA pixel upload via APC escape sequences
    ├── Image IDs for reuse without retransmission
    ├── Multiple placements per image (sprite sheets → sub-rects)
    ├── Z-index layering: images behind text (z < 0) or above (z > 0)
    ├── Animation frames with composition
    └── Compositing: alpha blending, source rect clipping
```

## Layer Model

```
┌─────────────────────────────────┐
│         Screen Buffer           │
│  (pixel buffer, kitty-backed)   │
├─────────────────────────────────┤
│  Layer 0: Background            │
│  Layer 1: Content               │
│  Layer 2: Detail / effects      │
│  Layer 3: Interface             │
│  Layer 4: Overlay               │
└─────────────────────────────────┘
```

Kitty protocol maps layers directly to z-index placements. Synchronized output (Mode 2026) for flicker-free updates. Dirty-rect tracking: only re-render cells/regions that changed.

## Main Loop

```
init:
    detect terminal capabilities (kitty graphics, keyboard protocol)
    init audio system (graceful fallback if no device)
    init Lua state + sandbox
    load project/main.lua
    call engine.load()

loop (~60fps):
    poll input events (non-blocking)
    dispatch input to Lua callbacks
    call engine.update(dt)
    call engine.draw()
    composite layers → frame buffer
    diff against previous frame
    emit terminal escape sequences for changed regions
    synchronized output flush

cleanup:
    call engine.quit()
    close Lua state
    restore terminal
```

## Zig ↔ Lua Boundary

All Lua-callable functions live in `src/scripting/lua_api.zig`. They follow a consistent pattern:

1. **`EngineContext`** (`lua_api.zig:44`) holds pointers to every subsystem (renderer, audio, input, scene, timer, ECS world, persistence). It's the single struct that bridges Zig and Lua.

2. **`getUpvalue()`** extracts the `EngineContext` (or a subsystem pointer) from a Lua C closure's upvalue slot. Every `engine.*` function is registered as a closure with its context pointer baked in. This is the standard Lua C API pattern for threading state through callbacks — it appears ~50 times across the scripting layer because every bound function uses it.

3. **`pushUpvalueClosure()`** is the registration side — it stores a pointer as upvalue 1 and wraps a Zig function as a Lua C closure.

### Module binding (`lua_bind.zig`)

User-registered Zig modules (via `app.registerModule()`) use a compile-time binding system. Pure Zig functions with simple types (`f64`, `i32`, `bool`) are auto-wrapped — the binding system generates Lua stack extraction and result pushing at comptime. Zero Lua knowledge required.

## Compositor Internals

`src/graphics/compositing.zig` manages the 8-layer pixel buffer:

- Each layer is an independent RGBA pixel buffer at the virtual resolution
- `set_layer(n)` directs subsequent pixel draws to layer n
- Per-frame: layers are alpha-blended bottom-to-top into a single composite buffer
- **Dirty-rect tracking**: only regions that changed since last frame are recomposed and sent to the terminal
- The composite buffer is diffed against the previous frame to minimize terminal escape sequences

## Lua API

See [docs/lua-api.md](docs/lua-api.md) for the full Lua API reference.
