# Vexel Architecture

## Module Structure

```
src/
  engine/
    input.zig         — Key/mouse event translation from vaxis to engine types
    
  graphics/
    renderer.zig      — Kitty-based rendering: text, rects, clear, screen info
    kitty.zig         — (Phase 1) Kitty graphics protocol: upload, place, animate, z-index
    image.zig         — (Phase 2) Image loading (PNG via zigimg), sprite sheets, atlas
    compositing.zig   — (Phase 1) Layer compositing, alpha blending, dirty-rect tracking
    tilemap.zig       — (Phase 5) Tilemap rendering and scrolling
    
  audio/
    audio.zig         — miniaudio wrapper via zaudio: device management, sound slots, playback
    
  scripting/
    lua_engine.zig    — Lua state lifecycle, game loading, callback dispatch
    lua_api.zig       — Register engine.* functions into Lua (graphics, input, etc.)
    
  persistence/
    db.zig            — (Phase 5) SQLite wrapper (zqlite) exposed to Lua

  main.zig            — Standalone binary: parse args, load game dir, run main loop
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

See [LUA_API.md](LUA_API.md) for the full Lua-facing API surface.
