# Compositor Performance

## Done: /dev/shm file transfer (Kitty)

Upload went from **35% → 0% CPU** at 1080×720 60fps. Replaced base64-over-tty (4.1MB/frame) with `/dev/shm` temp file transfer (~80 bytes/frame over tty). Double-buffered. Ghostty falls back to base64 (`KITTY_PID` detection).

**Files:** `src/graphics/kitty.zig`

## Remaining hotspots (Kitty, 1080×720, ReleaseSafe)

| %CPU | Symbol | Cause |
|------|--------|-------|
| 28% | `flattenLayers` | Pixel-by-pixel alpha blend, 3.1MB |
| 26% | `memset` | `clearLayer`/`clearAll` zeros ~9.3MB/frame |
| 13% | `memcpy` | First-layer copy in flattenLayers |
| 14% | `Vaxis.render` | Terminal cell rendering (not ours) |

## Ideas

- **memset**: Track drawn bounding box per layer, only clear that region.
- **flattenLayers**: SIMD batch 4 pixels, fast-path all-opaque/all-transparent groups.
- **memcpy**: Write first layer directly into composite_buf instead of copy.
- **Ghostty**: PNG (`f=100`) before base64 would shrink payload ~6×. base64 is 37% on Ghostty.
- **Kitty frame patching**: `a=f` with x,y sub-rect offsets — send only dirty regions.
