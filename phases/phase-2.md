# Phase 2: Image & Sprite Support

## Goal
Load PNG images, slice sprite sheets, render sprites via kitty graphics protocol.

## Deliverables

### Image Loading (`src/graphics/image.zig`)
- [x] Load PNG files via zigimg
- [x] Convert to RGBA pixel buffer
- [x] Upload to terminal via kitty graphics protocol (compositor flattens all layers into single kitty image per frame)
- [x] Cache uploaded images — path-based dedup with ref counting
- [x] Unload/free images from both memory and terminal

### Sprite Sheets
- [x] Load sprite sheet PNG with tile dimensions (e.g., 16×16)
- [x] Slice into frames — calculate sub-rects via `getFrameRect()`
- [x] Render individual frames via compositor `blitImage()` with source rect clipping
- [x] Animation support — frame index in draw opts, timing managed in Lua

### Lua API
- [x] `engine.graphics.load_image(path)` → image handle
- [x] `engine.graphics.draw_sprite(image, x, y, opts)` — opts: frame, scale, flip_x, flip_y
- [x] `engine.graphics.load_spritesheet(path, tile_w, tile_h)` → sheet handle
- [x] `engine.graphics.draw_frame(sheet, frame_index, x, y)`
- [x] `engine.graphics.unload_image(image)` — free resources

### Image Handle Management
- [x] Lua userdata for image handles
- [x] GC finalizer to auto-unload when Lua collects
- [x] ~~Image atlas for small sprites~~ — Not needed: compositor already uploads single composited frame per flush, so individual images never go to kitty separately. Atlas optimization would add complexity with no bandwidth benefit.

## Test Game
Animated Terrible Knight in a gothic castle. Demonstrates:
- PNG sprite loading (castle background via `load_image`)
- Sprite sheet animation (knight walk/idle/slash/jump cycles, fire skull float)
- Multiple sprite sheets loaded simultaneously
- One-shot effect animations (explosions, electro-shock on attack)
- Background tile rendering (dark castle interior)
- Layered compositing (background → enemies → player → effects)
- Scale, flip_x, flip_y options
- `get_frame_count` for animation loops
- `unload_image` cleanup in quit callback

## Files
```
src/graphics/image.zig      — Image loading, caching, sprite sheet slicing
src/graphics/kitty.zig       — Kitty protocol wrapper (RGBA upload, free)
src/graphics/compositing.zig — Layer compositing, blitImage, blitImageScaled
src/graphics/renderer.zig    — High-level API facade, DrawSpriteOpts
src/scripting/lua_api.zig    — Lua bindings for all image/sprite functions
games/sprites/main.lua       — Test game (gothic castle scene)
games/sprites/assets/        — Knight, fire skull, explosion, castle sprites
```
