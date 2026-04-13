# Vexel Architecture

## Module Structure

```
src/
  root.zig            — Library entry point: re-exports public engine types
  bin/
    main.zig          — Standalone binary: parse args, load game dir, run main loop

  engine/
    input.zig         — Key/mouse event translation from vaxis to engine types
    timer.zig         — Timer/tween system: one-shot, repeating, interpolation with easing
    
  graphics/
    renderer.zig      — Kitty-based rendering: text, rects, clear, screen info
    kitty.zig         — Kitty graphics protocol: upload, place, animate, z-index
    image.zig         — Image loading (PNG via zigimg), sprite sheets, atlas
    compositing.zig   — Layer compositing, alpha blending, dirty-rect tracking
    tilemap.zig       — Tilemap rendering: viewport culling, smooth scrolling
    
  audio/
    audio.zig         — miniaudio wrapper via zaudio: device management, sound slots, playback
    
  scripting/
    lua_engine.zig    — Lua state lifecycle, game loading, callback dispatch
    lua_api.zig       — Register engine.* functions into Lua (graphics, input, etc.)
    
  ecs/
    entity.zig        — Entity type (generation-counted IDs), EntityPool
    component_store.zig — Generic ComponentStore(T), LuaComponentStore
    world.zig         — ECS World: entities, components, built-in systems

  persistence/
    db.zig            — SQLite wrapper (zqlite) + key-value save API
```

## Rendering Pipeline

```
Game code (Lua)
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
│  Layer 0: Background tilemap    │
│  Layer 1: Sprites / entities    │
│  Layer 2: Particles / effects   │
│  Layer 3: UI / HUD              │
│  Layer 4: Overlay / transitions │
└─────────────────────────────────┘
```

Kitty protocol maps layers directly to z-index placements. Synchronized output (Mode 2026) for flicker-free updates. Dirty-rect tracking: only re-render cells/regions that changed.

## Main Loop

```
init:
    detect terminal capabilities (kitty graphics, keyboard protocol)
    init audio system (graceful fallback if no device)
    init Lua state + sandbox
    load game/main.lua
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

## Lua Game API

See [.claude/rules/vexel-engine.md](.claude/rules/vexel-engine.md) for the full Lua API reference.
