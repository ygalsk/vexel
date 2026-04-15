# Vexel Progress

## 2026-04-15

### simplify: thread pool lifecycle, type cleanup
- Fixed thread pool leak: `g_pool` now has explicit `initPool()`/`deinitPool()` called from `App.run()`/`App.deinit()` (was: lazy-init on first shader dispatch, never cleaned up)
- Fixed `save_db` type: `?*void` → `void` when `!config.has_db` (nullable pointer-to-void is meaningless)
- Extracted `MAX_SIMULATION_UNIFORMS` constant (was magic `16`)

### simplify: optional db, hot-reload, shader threading
- Extracted `registerLuaApi()` helper — `lua_api.register(...)` was duplicated verbatim in `init()` and `hotReload()`
- Removed redundant error overlay field init in `init()` body (struct field defaults already cover it)
- Renamed `game_dir` → `project_dir` to match `Options` vocabulary
- Removed narrating comments in `hotReload()` and `renderErrorOverlay()`

### simplify: pixel shader system cleanup
- Eliminated per-frame alloc+memcpy in `lPixelShade` — shaders now write directly into compositor layer buffer via `getActiveLayerSlice()` (was: alloc w*h*4 bytes, fill, memcpy, free — every frame)
- Removed dead `n_uniforms` runtime parameter from `ShaderDispatch` (value was already baked at comptime)
- Flattened `ShaderEntry` single-field wrapper — `ShaderRegistry` stores `ShaderDispatch` directly
- Removed narrating comments in shader dispatch closure

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
