# Phase 7: Entity Component System

## Goal
Data-oriented ECS replacing the old standalone sprite system. Entities are composed from components (Position, Velocity, Sprite, Animation, Collider, Tag) and processed by built-in systems (movement, animation, rendering). Lua-defined components stored as registry refs.

## Deliverables

### Phase A: Core ECS (Zig)
- [x] `src/ecs/entity.zig` — Entity packed struct (u32 index + u16 generation), EntityPool with free list
- [x] `src/ecs/component_store.zig` — Generic `ComponentStore(T)` (dense arrays + sparse HashMap)
- [x] `src/ecs/world.zig` — World struct: spawn/despawn, typed stores, Lua stores, query helpers
- [x] Unit tests for entity lifecycle, component CRUD, query intersection
- [x] Wired into build.zig

### Phase B: Lua Bindings
- [x] `src/scripting/lua_ecs.zig` — engine.world.* (spawn, despawn, set, get, remove, is_alive, each, count)
- [x] Wired into lua_api.zig, main.zig, build.zig
- [x] String dispatch: known names → Zig stores, others → Lua component stores

### Phase C: ECS-Native Sprites + Systems
- [x] Animation component (32-frame inline array, speed, loop, on_complete_ref)
- [x] ECS sprite rendering in main loop (collectSprites → layer-sorted draw)
- [x] Animation ticking with event-based Lua callback dispatch
- [x] Movement system (Position += Velocity * dt)
- [x] Removed old SpriteSystem — sprites are first-class ECS citizens
- [x] Image handle reads VexelImage userdata or integer

### Phase D: Test Game
- [x] `games/ecs-demo/main.lua` — knight with animation, spawnable fire skulls, movement, despawn

## Architecture

```
Lua game code
    │
    ▼
engine.world.* API  ←  spawn, set, get, remove, each, despawn
    │
    ▼
World (src/ecs/world.zig)
    ├── EntityPool (generation-counted IDs)
    ├── ComponentStore(Position)   ─┐
    ├── ComponentStore(Velocity)    │  Zig components (typed, dense iteration)
    ├── ComponentStore(SpriteComp)  │
    ├── ComponentStore(Animation)   │
    ├── ComponentStore(Collider)    │
    ├── ComponentStore(Tag)        ─┘
    └── StringHashMap(LuaComponentStore)  ←  game-defined components (registry refs)
```

## Files
```
src/ecs/entity.zig            — Entity type, EntityPool
src/ecs/component_store.zig   — Generic ComponentStore(T), LuaComponentStore
src/ecs/world.zig             — World, built-in components, systems
src/scripting/lua_ecs.zig     — engine.world.* Lua bindings
src/scripting/lua_api.zig     — MODIFIED (register engine.world, removed SpriteSystem)
src/main.zig                  — MODIFIED (ECS tick + render in main loop)
build.zig                     — MODIFIED (ecs modules, removed sprite_system)
games/ecs-demo/main.lua       — Test game
```
