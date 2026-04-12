# Phase 1: Kitty Graphics + Pixel Rendering — DONE (adapted)

## Goal
Pixel-level rendering through kitty graphics protocol. Original plan included sub-cell primitives via half-blocks and sextants — replaced by full-pixel compositor which is strictly more capable.

## Deliverables

### Kitty Graphics Core (`src/graphics/kitty.zig`)
- [x] Upload RGBA pixel data via kitty graphics protocol (base64 encoded)
- [x] Image ID management — vaxis handles IDs, compositor tracks composite_image
- [x] Image placement — position images at cell coordinates with pixel offsets (sprite_placer.zig)
- [x] Sub-rect rendering — clip source images for sprite sheet frames (blitImage + clip_region)
- [x] Z-index layering — place images behind text (`z < 0`) or above (`z > 0`)
- [x] Image deletion — free server-side images when no longer needed
- [x] Capability check — verify kitty graphics support at startup

### Pixel Primitives (`src/graphics/compositing.zig`)
Replaced the sub-cell approach (half-blocks, sextants) with a full-pixel compositor. Drawing happens on in-memory RGBA buffers, composited and uploaded as a single kitty image per frame.

- [x] ~~Half-block renderer~~ — replaced by pixel compositor
- [x] ~~Sextant renderer~~ — replaced by pixel compositor
- [x] Pixel buffer — in-memory RGBA buffer per layer for primitive drawing
- [x] `pixel.rect(x, y, w, h, color)` in pixel coordinates
- [x] `pixel.line(x1, y1, x2, y2, color)` — Bresenham's
- [x] `pixel.circle(cx, cy, r, color)` — midpoint circle

### Layer Compositing (`src/graphics/compositing.zig`)
- [x] Layer stack — 8 ordered layers with per-layer dirty tracking
- [x] Dirty tracking — per-layer dirty flags, skip re-composite when unchanged
- [x] Map layers to kitty z-index placements
- [x] `engine.graphics.set_layer(n)` Lua API

### Lua API Extensions
- [x] `engine.graphics.pixel.rect(x, y, w, h, color)`
- [x] `engine.graphics.pixel.line(x1, y1, x2, y2, color)`
- [x] `engine.graphics.pixel.circle(cx, cy, r, color)`
- [x] `engine.graphics.get_resolution()` — returns logical pixel dimensions
- [x] `engine.graphics.set_resolution(w, h)` — set virtual resolution
- [x] `engine.graphics.set_layer(n)`

### Coordinate System
- [x] Virtual pixel grid with configurable resolution (default 320×180)
- [x] `engine.graphics.get_resolution()` returns virtual pixel dimensions
- [x] All pixel drawing APIs work in virtual pixel coordinates

## Test Game
Bouncing ball with pixel-smooth movement (`games/bounce/`). Demonstrates:
- Smooth movement at pixel resolution
- Color-filled primitives (rect, circle)
- Line drawing
- Layer ordering

## Files
```
src/graphics/kitty.zig       — Kitty protocol wrapper (RGBA upload, free)
src/graphics/compositing.zig — Layer compositor, pixel primitives, alpha blending
src/graphics/renderer.zig    — MODIFIED (pixel mode, sprite placer)
src/graphics/sprite_placer.zig — Per-frame kitty image placements
src/scripting/lua_api.zig    — MODIFIED (pixel drawing + layer Lua API)
games/bounce/main.lua        ��� Test game
```
