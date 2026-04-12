# Phase 7: Performance

## Goal
Profile and optimize the rendering pipeline, compositing, and memory usage.

## Deliverables

- [x] Cache Lua function refs — store `luaL_ref` for update/draw/on_key/on_mouse at load time to avoid per-frame `getGlobal("engine")` lookups
- [ ] Profile rendering pipeline — identify bottlenecks
- [ ] Dirty-rect optimization — minimize kitty graphics redraws
- [ ] Incremental compositing — skip re-compositing unchanged lower layers
- [ ] Image atlas packing — reduce number of kitty image uploads
- [ ] Frame budget monitoring — warn when update+draw exceeds 16ms
- [ ] Memory profiling — track allocations per frame
- [ ] Row-at-a-time `@memset` for drawRect/drawHLine — fill contiguous pixel spans in bulk instead of per-pixel writes

## Files
```
src/graphics/compositing.zig  — MODIFY (dirty-rect, incremental compositing, memset)
src/graphics/kitty.zig        — MODIFY (atlas packing, dirty-rect redraws)
src/graphics/renderer.zig     — MODIFY (frame budget monitoring)
src/main.zig                  — MODIFY (profiling hooks)
```
