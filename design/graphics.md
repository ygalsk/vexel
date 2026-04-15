# Graphics

The graphics pipeline turns Lua draw calls into pixels on a terminal. Three layers of abstraction, each with a clear job.

## Mental Model

```
Lua draw calls
    |
    v
Compositor (8 RGBA layers, virtual resolution)
    |  flatten visible layers, alpha-blend
    v
Kitty transport (upload composite as single image)
    |  posix_shm > tmpfile > base64
    v
Terminal (Kitty graphics protocol placement)
```

**Think of the compositor as a software GPU.** Each layer is a full RGBA framebuffer at virtual resolution (default 320x180). Lua code draws to the "active layer" — primitives, blits, shader output all go into that layer's pixel buffer. At flush time, visible layers are flattened bottom-to-top with premultiplied alpha blending, producing a single composite buffer that gets uploaded to the terminal as one Kitty image.

### Two sprite modes

Sprites can render two ways, selected per-frame. Both modes are handled by `SpritePlacer.drawSprite()`:

- **Compositor mode** (`.compositor`): blit sprite pixels into a layer buffer via `compositor.blitImage()` — they become part of the composited image. Simple, correct, but every sprite pixel goes through the upload path.
- **Placer mode** (`.placer`): upload the sprite image once to the terminal (via `ImageManager.uploadVariant()`), then place it at cell coordinates with sub-pixel offsets via Kitty protocol. The terminal composites. Faster for many sprites, but coordinate mapping is trickier (virtual-to-terminal pixel math).

The main loop uses placer mode. Compositor mode exists for cases where sprites need to participate in layer blending.

**No facade layer.** Previously a `Renderer` facade routed draw calls to the right backend. That indirection was removed — `SpritePlacer` handles mode dispatch directly, and `App` owns all subsystems (compositor, sprite_placer, image_mgr) as peers.

## Key Files

| File | LOC | Role |
|------|-----|------|
| `src/graphics/compositing.zig` | 743 | 8-layer framebuffers, dirty tracking, alpha blend, flatten |
| `src/graphics/kitty.zig` | 328 | Kitty graphics protocol, transport probing, image upload |
| `src/graphics/image.zig` | 441 | Image/spritesheet loading, ref-counting, flip variants, terminal upload + pre-scaling |
| `src/graphics/sprite_placer.zig` | 236 | Sprite drawing (both modes), placement list, virtual→terminal coord mapping |

## Compositor Internals

### Dirty-rect tracking

Every draw call expands a per-layer bounding box (`drawn_bbox`). At flush, only the union of all layers' dirty regions gets composited and uploaded. On a typical frame where a game draws a few sprites and some UI, this might be 10% of the full resolution.

The bbox lifecycle is a two-frame rotation:
1. Frame N: draws expand `drawn_bbox`
2. Flush: flatten only the union of all `drawn_bbox` + `prev_bbox` regions
3. Post-flush: `drawn_bbox` becomes `prev_bbox`, `drawn_bbox` resets to empty

`prev_bbox` ensures that regions from the *last* frame that are now empty get recomposited (cleared).

### Alpha blending

All pixel data is **premultiplied alpha** — both loaded images and compositor colors premultiply on write. Blending uses src-over: `dst = src + dst * (1 - src_a)`.

The flatten pass uses SIMD:
- AVX2 path (8 pixels / 256-bit) where available
- SSE2 fallback (4 pixels / 128-bit)
- Scalar remainder

### Image lifecycle (double-buffering)

The compositor holds one Kitty image at a time (`composite_image`). When a new composite is uploaded, the *old* image isn't freed immediately — it's scheduled as `pending_free_id` and freed at the *start of the next flush*. This avoids a frame where no image is visible (the terminal renders the old image while the new one uploads).

## Kitty Transport

At startup, `probeTransport()` sends 1x1 test images via each transport mode and reads the terminal's ACK:

1. **posix_shm** (`t=s`): write pixels to `/dev/shm`, send shm name. Zero-copy on Kitty terminal.
2. **tmpfile** (`t=t`): write to `/dev/shm/tty-graphics-protocol-vexel-*`, send base64-encoded path. Works with Ghostty/WezTerm (filename prefix required).
3. **base64** (`t=d`): inline-encode entire pixel buffer. Universal fallback, highest bandwidth.

Runtime fallback: if a transport fails mid-session, it downgrades automatically (shm -> tmpfile -> base64).

Cleanup: `deinit()` iterates `/dev/shm/tty-graphics-protocol-vexel-*` and removes leftover files from crashes.

## Image Manager

`src/graphics/image.zig` — self-contained image lifecycle. Slot-based handle system with a free list (same pattern as [[audio#Slot Pattern|audio]]). Features:

- **Path cache**: same file path returns same handle (ref-counted). Tile dimensions must match for cache hit.
- **Premultiply on load**: zigimg decodes to RGBA32, then alpha is premultiplied immediately
- **Spritesheet grid**: tile_w/tile_h define a frame grid; `getFrameRect()` computes source rects
- **Flip variants**: lazy-allocated flipped pixel buffers (none/flip_x/flip_y/flip_both), cached per handle
- **Terminal upload**: `uploadVariant()` handles pre-scaling (nearest-neighbor for crisp pixel art) and Kitty upload. Each flip variant gets a separate terminal image. This was previously in `Renderer` — now ImageManager is self-sufficient for the full load→upload lifecycle.

On resize, `invalidateAllTerminal()` frees all terminal images. SpritePlacer re-uploads on demand when a variant is missing.

## Decisions

### Why 8 layers?
Matches the common pattern in retro engines (background, midground, sprites, UI, overlay, etc). PICO-8 and similar have fewer, but 8 is cheap (just memory) and avoids artificial constraints. Each layer is `width * height * 4` bytes — at 320x180 that's ~225KB per layer, ~1.8MB total.

### Why premultiplied alpha everywhere?
Premultiplied makes src-over blending a single multiply-add per channel instead of a divide. It also handles edge cases correctly (partially transparent sprites over transparent backgrounds). Every serious compositor (Cairo, Skia, wgpu) uses premultiplied internally.

### Why a single composite upload instead of per-layer images?
Tried per-layer Kitty images initially — the terminal's own compositing was unreliable across terminal emulators (z-index support varies). One composite image is universally supported and simpler to reason about.

### Why virtual resolution instead of native terminal pixels?
Games target a fixed resolution for consistent visuals regardless of terminal size. The compositor upscales to fill the terminal. This also means all Lua game code works in predictable coordinates (320x180) rather than dealing with varying terminal geometries.

### Shader writes directly to layer buffer
Originally, `lPixelShade` allocated a temporary buffer, ran the shader, then memcpy'd to the layer. This was a per-frame alloc+free of `w*h*4` bytes. Now shaders write directly into the layer via `getActiveLayerSlice()`, eliminating the allocation entirely.

## Open Questions

- Compositor flatten is the hottest path at higher resolutions (1080x720). The SIMD blend helps but `memset`/`memcpy` of large buffers still dominates. Worth investigating partial uploads or tiled compositing?
- Sprite placer mode has complex virtual-to-terminal coordinate math. Could simplify if we dropped support for sub-cell pixel offsets.
