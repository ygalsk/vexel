# Vexel Progress

## 2026-04-14

### simplify: tier-2 binding removal cleanup
- Removed dead `engine_ctx` field from `App` struct (only used during init, now inlined)
- Removed stale `lua_api`/`zlua` imports from `vexel_mod` in build.zig (root.zig no longer uses them)
- Replaced hand-rolled `extractArgTypes` + `ArgsTuple` with `std.meta.ArgsTuple` (~30 lines removed)
- Renamed `makeTier1Wrapper` → `makeWrapper` (tier distinction no longer exists)
- Fixed stale "excluding self/ctx params" comment

### bounce example: ECS sprite ball
- Switched ball rendering from `pixel.circle` to ECS sprite (128×128 spritesheet, layer 2)
- Resolution scaled to 1920×1080 with proportional ball/velocity values
- Fixed: `ball_sheet` hoisted to module scope to prevent GC while sprite entity holds the handle
- Fixed: magic `64` (sprite half-size) extracted to `SPRITE_HALF` constant
- Fixed: `ball_r` aligned to `64` to match sprite visual radius (was `60`, causing visual clipping at walls)
