# Phase 6: Polish & Codecritter Port

## Goal
Performance optimization, documentation, and begin porting Codecritter as a Lua game.

## Deliverables

### Performance
- [ ] Profile rendering pipeline — identify bottlenecks
- [ ] Dirty-rect optimization — minimize kitty graphics redraws
- [ ] Incremental compositing — skip re-compositing unchanged lower layers
- [ ] Image atlas packing — reduce number of kitty image uploads
- [ ] Frame budget monitoring — warn when update+draw exceeds 16ms
- [ ] Memory profiling — track allocations per frame
- [ ] Cache Lua function refs — store `luaL_ref` for update/draw/on_key/on_mouse at load time to avoid per-frame `getGlobal("engine")` lookups
- [ ] Row-at-a-time `@memset` for drawRect/drawHLine — fill contiguous pixel spans in bulk instead of per-pixel writes

### Documentation
- [ ] API reference — all `engine.*` functions with signatures and examples
- [ ] Getting started guide — create a game from scratch
- [ ] Example games — annotated source for each test game
- [ ] Architecture docs — for engine contributors

### Codecritter Port
- [ ] Map Codecritter hub screen to Lua scene
- [ ] Map battle engine to Lua (data-driven, moves/species from JSON)
- [ ] Map dungeon engine to Lua
- [ ] Sprite rendering via kitty graphics
- [ ] SQLite persistence for roster/inventory
- [ ] Audio for battle/dungeon music + SFX

### Robustness
- [ ] Error recovery — Lua errors don't crash the engine
- [ ] Terminal restore on panic — clean up raw mode, alt screen
- [ ] Graceful degradation logging — warn on missing capabilities
- [ ] Signal handling — SIGINT, SIGTERM clean shutdown

## Files
```
docs/                        — NEW (API reference, guides)
games/codecritter/           — NEW (Codecritter as Lua game)
src/                         — MODIFY (optimizations throughout)
```
