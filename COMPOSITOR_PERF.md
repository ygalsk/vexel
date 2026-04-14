# Compositor Performance

## Done: /dev/shm file transfer (Kitty)

Upload went from **35% → 0% CPU** at 1080×720 60fps. Replaced base64-over-tty (4.1MB/frame) with `/dev/shm` temp file transfer (~80 bytes/frame over tty). Double-buffered.

**Files:** `src/graphics/kitty.zig`

## Done: Dirty bounding box per layer

Replaced full-buffer memset/memcpy/blend with bounded operations. Each layer tracks `drawn_bbox` (current frame) and `prev_bbox` (previous frame). `clearLayer` only zeros the previous drawn region. `flattenLayers` only composites the union of all layer bboxes.

**Expected:** 26% memset + partial 13% memcpy → ~2-5%. A 100×100 sprite clears 40KB instead of 3.1MB.

**Files:** `src/graphics/compositing.zig`

## Done: Premultiplied alpha + SIMD blend

Switched from straight alpha (division per pixel) to premultiplied alpha (Pixman's formula). Blend is now `dst = src + dst * (1 - src_a) / 255` — no division. `flattenLayers` processes 4 pixels at a time via `@Vector(16, u8)` (maps to SSE2 on x86-64). Image pixels premultiplied at load time.

**Expected:** 28% blend → ~7-10%.

**Files:** `src/graphics/compositing.zig`, `src/graphics/image.zig`

## Done: Capability-based shm detection

Replaced `KITTY_PID` env var sniffing with `/dev/shm` filesystem probe. Any terminal on Linux with `/dev/shm` gets shm upload attempted (Kitty, Ghostty, WezTerm, etc.). On first shm failure, permanently falls back to base64. No more terminal-specific env var checks.

**Files:** `src/graphics/kitty.zig`

## Remaining hotspots (Kitty, 1080×720, ReleaseSafe)

| %CPU | Symbol | Cause |
|------|--------|-------|
| 14% | `Vaxis.render` | Terminal cell rendering (not ours) |

## Ideas (future)

- **Ghostty zlib compression**: `o=z` flag for zlib-compressed base64 payload. Blocked by Zig 0.15.2's incomplete `std.compress.flate.Compress` (streaming path has `@panic("TODO")`). `Simple` API works but only does huffman (no LZ77). Revisit when Zig's compress API matures.
- **Kitty frame patching**: `a=f` with x,y sub-rect offsets — send only dirty regions. With shm the tty bandwidth is already ~80 bytes; main savings would be reducing Kitty's GPU re-upload cost.
- **Persistent shm file handles**: Keep two `/dev/shm` fds open across frames, seek+write instead of open/close per dirty frame. Needs profiling to see if the syscall pair matters.
- **next_file_id wrap**: Starts at `0x40000000`, wraps u32 after ~2.3 years at 60fps continuous dirty. Could collide with vaxis ID space on wrap.
