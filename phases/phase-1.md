# Phase 1: Kitty Graphics + Sub-cell Rendering

## Goal
Pixel-level rendering through kitty graphics protocol. Sub-cell resolution via half-blocks and sextants for text-mode primitives.

## Deliverables

### Kitty Graphics Core (`src/graphics/kitty.zig`)
- [ ] Upload RGBA pixel data via APC escape sequences (`a=T`, `f=32`)
- [ ] Image ID management — assign IDs, track uploaded images
- [ ] Image placement — position images at cell coordinates with pixel offsets
- [ ] Sub-rect rendering — clip source images for sprite sheet frames
- [ ] Z-index layering — place images behind text (`z < 0`) or above (`z > 0`)
- [ ] Image deletion — free server-side images when no longer needed
- [ ] Capability check — verify kitty graphics support at startup

### Sub-cell Primitives (`src/graphics/subcell.zig`)
- [ ] Half-block renderer (▄▀) — 1×2 sub-pixels per cell
- [ ] Sextant renderer (U+1FB00–1FB3B) — 2×3 sub-pixels per cell
- [ ] Pixel buffer — in-memory RGBA buffer for primitive drawing
- [ ] `draw_rect(x, y, w, h, color)` in sub-cell coordinates
- [ ] `draw_line(x1, y1, x2, y2, color)` — Bresenham's
- [ ] `draw_circle(cx, cy, r, color)` — midpoint circle

### Layer Compositing (`src/graphics/compositing.zig`)
- [ ] Layer stack — ordered planes with z-index
- [ ] Dirty-rect tracking — only re-render changed regions
- [ ] Map layers to kitty z-index placements
- [ ] `engine.graphics.set_layer(n)` Lua API

### Lua API Extensions
- [ ] `engine.graphics.draw_rect(x, y, w, h, color)` — sub-cell coordinates
- [ ] `engine.graphics.draw_line(x1, y1, x2, y2, color)`
- [ ] `engine.graphics.draw_circle(cx, cy, r, color)`
- [ ] `engine.graphics.get_resolution()` — returns logical pixel dimensions
- [ ] `engine.graphics.set_layer(n)`

### Coordinate System
- [ ] Define logical pixel grid based on terminal cell pixel size
- [ ] `engine.graphics.get_resolution()` returns sub-cell pixel dimensions
- [ ] All drawing APIs work in logical pixel coordinates

## Test Game
Bouncing ball with sub-pixel-smooth movement. Demonstrates:
- Smooth movement at sub-cell resolution
- Color-filled primitives (rect, circle)
- Line drawing
- Layer ordering

## Files
```
src/graphics/kitty.zig      — NEW
src/graphics/subcell.zig     — NEW
src/graphics/compositing.zig — NEW
src/graphics/renderer.zig    — MODIFY (add sub-cell + kitty backends)
src/scripting/lua_api.zig    — MODIFY (add new drawing functions)
games/bounce/main.lua        — NEW test game
```
