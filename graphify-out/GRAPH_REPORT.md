# Graph Report - .  (2026-04-14)

## Corpus Check
- 28 files · ~26,391 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 432 nodes · 663 edges · 26 communities detected
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 11 edges (avg confidence: 0.78)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Lua API Bindings|Lua API Bindings]]
- [[_COMMUNITY_Renderer Core|Renderer Core]]
- [[_COMMUNITY_ECS World & Components|ECS World & Components]]
- [[_COMMUNITY_Design Philosophy & Architecture|Design Philosophy & Architecture]]
- [[_COMMUNITY_Pixel Compositor|Pixel Compositor]]
- [[_COMMUNITY_Lua ECS Bridge|Lua ECS Bridge]]
- [[_COMMUNITY_Scene Management|Scene Management]]
- [[_COMMUNITY_Image & Spritesheet Loading|Image & Spritesheet Loading]]
- [[_COMMUNITY_Timers & Tweens|Timers & Tweens]]
- [[_COMMUNITY_Audio System|Audio System]]
- [[_COMMUNITY_Input Handling|Input Handling]]
- [[_COMMUNITY_Lua Engine Lifecycle|Lua Engine Lifecycle]]
- [[_COMMUNITY_Entity Pool|Entity Pool]]
- [[_COMMUNITY_SQLite Persistence|SQLite Persistence]]
- [[_COMMUNITY_Example Games|Example Games]]
- [[_COMMUNITY_Main Entry & Error Handling|Main Entry & Error Handling]]
- [[_COMMUNITY_Sprite Placer|Sprite Placer]]
- [[_COMMUNITY_Kitty Protocol|Kitty Protocol]]
- [[_COMMUNITY_Tilemap Rendering|Tilemap Rendering]]
- [[_COMMUNITY_Component Store|Component Store]]
- [[_COMMUNITY_ECS Module Docs|ECS Module Docs]]
- [[_COMMUNITY_Build System|Build System]]
- [[_COMMUNITY_Library Root|Library Root]]
- [[_COMMUNITY_Tilemap Module|Tilemap Module]]
- [[_COMMUNITY_Timer Module|Timer Module]]
- [[_COMMUNITY_Distribution Model|Distribution Model]]

## God Nodes (most connected - your core abstractions)
1. `getUpvalue()` - 50 edges
2. `AudioSystem` - 17 edges
3. `World` - 12 edges
4. `TimerSystem` - 10 edges
5. `checkSoundHandle()` - 10 edges
6. `currentSceneRef()` - 9 edges
7. `getUpvalue()` - 9 edges
8. `LuaComponentStore` - 9 edges
9. `Vexel Design Document` - 8 edges
10. `callSceneCallback()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `LÖVE Game Framework` --semantically_similar_to--> `Main Loop (60fps)`  [INFERRED] [semantically similar]
  DESIGN.md → ARCHITECTURE.md
- `Vexel Progress Tracker` --references--> `Vexel Architecture Document`  [INFERRED]
  PROGRESS.md → ARCHITECTURE.md
- `libvaxis Dependency` --shares_data_with--> `Input Module (input.zig)`  [INFERRED]
  DESIGN.md → ARCHITECTURE.md
- `libvaxis Dependency` --shares_data_with--> `Renderer Module (renderer.zig)`  [INFERRED]
  DESIGN.md → ARCHITECTURE.md
- `Vexel Project Config (CLAUDE.md)` --references--> `LÖVE Game Framework`  [EXTRACTED]
  CLAUDE.md → DESIGN.md

## Hyperedges (group relationships)
- **Rendering Pipeline (Lua -> Renderer -> Kitty -> Compositor -> Terminal)** — module_lua_api, module_renderer, module_kitty, module_compositing, concept_layer_compositor [EXTRACTED 0.90]
- **ECS Subsystem (Entity + ComponentStore + World)** — module_ecs_entity, module_ecs_component, module_ecs_world [EXTRACTED 1.00]
- **Design Philosophy Triad (Ousterhout + Aristotelian + LÖVE Research)** — concept_ousterhout, concept_aristotelian, concept_love_framework [EXTRACTED 0.85]

## Communities

### Community 0 - "Lua API Bindings"
Cohesion: 0.06
Nodes (69): bindLuaParams(), checkDbHandle(), checkImageHandle(), checkSoundHandle(), EngineContext, getUpvalue(), lAudioLoad(), lAudioSetMasterVolume() (+61 more)

### Community 1 - "Renderer Core"
Cohesion: 0.06
Nodes (22): clear(), clearSprites(), colorToVaxis(), deinitPixelMode(), drawRect(), drawSprite(), DrawSpriteOpts, drawText() (+14 more)

### Community 2 - "ECS World & Components"
Cohesion: 0.09
Nodes (11): Animation, AnimationEvent, Collider, ComponentId, LuaComponentStore, Position, SpriteComp, SpriteRenderEntry (+3 more)

### Community 3 - "Design Philosophy & Architecture"
Cohesion: 0.07
Nodes (30): Vexel Architecture Document, Vexel Project Config (CLAUDE.md), Apple Human Interface Guidelines, Aristotelian Decomposition, Dirty-Rect Tracking, Kitty Graphics Protocol, 8-Layer Compositor System, LÖVE Game Framework (+22 more)

### Community 4 - "Pixel Compositor"
Cohesion: 0.12
Nodes (17): blendPixel(), blitBuffer(), blitImage(), Color, compositeOnly(), deinit(), div255(), drawCircle() (+9 more)

### Community 5 - "Lua ECS Bridge"
Cohesion: 0.15
Nodes (25): getEntityAtIndex(), getLuaComponent(), getUpvalue(), getZigComponent(), lCount(), lDespawn(), lEach(), lEachIterator() (+17 more)

### Community 6 - "Scene Management"
Cohesion: 0.17
Nodes (22): blendFade(), blendSlide(), blendTransition(), blendWipe(), callSceneCallback(), callSceneCallbackWithNumber(), currentSceneRef(), draw() (+14 more)

### Community 7 - "Image & Spritesheet Loading"
Cohesion: 0.13
Nodes (24): allocSlot(), deinit(), FlipVariant, freeImageData(), freeTerminalData(), getAllTerminalIds(), getFlippedPixels(), getFrameCount() (+16 more)

### Community 8 - "Timers & Tweens"
Cohesion: 0.1
Nodes (6): Timer, TimerSlot, TimerSystem, Tween, TweenProp, TweenSlot

### Community 9 - "Audio System"
Cohesion: 0.16
Nodes (4): AudioSystem, LoadOpts, PlayOpts, SoundSlot

### Community 10 - "Input Handling"
Cohesion: 0.14
Nodes (9): Action, Button, GamepadState, getGamepadState(), InputState, KeyEvent, keyName(), MouseEvent (+1 more)

### Community 11 - "Lua Engine Lifecycle"
Cohesion: 0.22
Nodes (13): cacheEngineRef(), callDraw(), callEngineFunc(), callLoad(), callOnKey(), callOnMouse(), callQuit(), callUpdate() (+5 more)

### Community 12 - "Entity Pool"
Cohesion: 0.18
Nodes (2): Entity, EntityPool

### Community 13 - "SQLite Persistence"
Cohesion: 0.29
Nodes (2): Db, SaveDb

### Community 14 - "Example Games"
Cohesion: 0.36
Nodes (8): engine.draw(), engine.load(), engine.on_key(), engine.update(), hsv_to_rgb(), init_particles(), make_color(), rgb_hex()

### Community 15 - "Main Entry & Error Handling"
Cohesion: 0.42
Nodes (6): Event, fatalLuaError(), handleKey(), logLuaError(), main(), stderrPrint()

### Community 16 - "Sprite Placer"
Cohesion: 0.29
Nodes (1): SpritePlacement

### Community 17 - "Kitty Protocol"
Cohesion: 0.33
Nodes (0): 

### Community 18 - "Tilemap Rendering"
Cohesion: 0.67
Nodes (1): DrawTilemapOpts

### Community 19 - "Component Store"
Cohesion: 0.67
Nodes (1): Vec2

### Community 20 - "ECS Module Docs"
Cohesion: 0.67
Nodes (3): ECS Component Store (component_store.zig), ECS Entity Module (entity.zig), ECS World Module (world.zig)

### Community 21 - "Build System"
Cohesion: 1.0
Nodes (0): 

### Community 22 - "Library Root"
Cohesion: 1.0
Nodes (0): 

### Community 23 - "Tilemap Module"
Cohesion: 1.0
Nodes (1): Tilemap Module (tilemap.zig)

### Community 24 - "Timer Module"
Cohesion: 1.0
Nodes (1): Timer Module (timer.zig)

### Community 25 - "Distribution Model"
Cohesion: 1.0
Nodes (1): Dual Distribution (Standalone + Library)

## Knowledge Gaps
- **61 isolated node(s):** `KeyEvent`, `Action`, `MouseEvent`, `Button`, `GamepadState` (+56 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Build System`** (2 nodes): `build()`, `build.zig`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Library Root`** (1 nodes): `root.zig`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Tilemap Module`** (1 nodes): `Tilemap Module (tilemap.zig)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Timer Module`** (1 nodes): `Timer Module (timer.zig)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Distribution Model`** (1 nodes): `Dual Distribution (Standalone + Library)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `KeyEvent`, `Action`, `MouseEvent` to the rest of the system?**
  _61 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Lua API Bindings` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `Renderer Core` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `ECS World & Components` be split into smaller, more focused modules?**
  _Cohesion score 0.09 - nodes in this community are weakly interconnected._
- **Should `Design Philosophy & Architecture` be split into smaller, more focused modules?**
  _Cohesion score 0.07 - nodes in this community are weakly interconnected._
- **Should `Pixel Compositor` be split into smaller, more focused modules?**
  _Cohesion score 0.12 - nodes in this community are weakly interconnected._
- **Should `Image & Spritesheet Loading` be split into smaller, more focused modules?**
  _Cohesion score 0.13 - nodes in this community are weakly interconnected._