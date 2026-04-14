# Graph Report - .  (2026-04-14)

## Corpus Check
- 23 files · ~269,835 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 457 nodes · 709 edges · 26 communities detected
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 11 edges (avg confidence: 0.78)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]

## God Nodes (most connected - your core abstractions)
1. `getUpvalue()` - 50 edges
2. `AudioSystem` - 17 edges
3. `World` - 12 edges
4. `TimerSystem` - 10 edges
5. `checkSoundHandle()` - 10 edges
6. `currentSceneRef()` - 9 edges
7. `getUpvalue()` - 9 edges
8. `LuaComponentStore` - 9 edges
9. `flattenLayers()` - 8 edges
10. `markLayerDirty()` - 8 edges

## Surprising Connections (you probably didn't know these)
- `LÖVE Game Framework` --semantically_similar_to--> `Main Loop (60fps)`  [INFERRED] [semantically similar]
  DESIGN.md → ARCHITECTURE.md
- `Vexel Architecture Document` --references--> `Vexel Progress Tracker`  [INFERRED]
  ARCHITECTURE.md → PROGRESS.md
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

### Community 0 - "Community 0"
Cohesion: 0.06
Nodes (69): bindLuaParams(), checkDbHandle(), checkImageHandle(), checkSoundHandle(), EngineContext, getUpvalue(), lAudioLoad(), lAudioSetMasterVolume() (+61 more)

### Community 1 - "Community 1"
Cohesion: 0.05
Nodes (22): clear(), clearSprites(), colorToVaxis(), deinitPixelMode(), drawRect(), drawSprite(), DrawSpriteOpts, drawText() (+14 more)

### Community 2 - "Community 2"
Cohesion: 0.09
Nodes (24): BBox, blendPixel(), blendPixels4(), blendPixels8(), blitBuffer(), blitImage(), clearAll(), clearBBox() (+16 more)

### Community 3 - "Community 3"
Cohesion: 0.09
Nodes (11): Animation, AnimationEvent, Collider, ComponentId, LuaComponentStore, Position, SpriteComp, SpriteRenderEntry (+3 more)

### Community 4 - "Community 4"
Cohesion: 0.07
Nodes (30): Vexel Architecture Document, Vexel Project Config (CLAUDE.md), Apple Human Interface Guidelines, Aristotelian Decomposition, Dirty-Rect Tracking, Kitty Graphics Protocol, 8-Layer Compositor System, LÖVE Game Framework (+22 more)

### Community 5 - "Community 5"
Cohesion: 0.15
Nodes (25): getEntityAtIndex(), getLuaComponent(), getUpvalue(), getZigComponent(), lCount(), lDespawn(), lEach(), lEachIterator() (+17 more)

### Community 6 - "Community 6"
Cohesion: 0.17
Nodes (22): blendFade(), blendSlide(), blendTransition(), blendWipe(), callSceneCallback(), callSceneCallbackWithNumber(), currentSceneRef(), draw() (+14 more)

### Community 7 - "Community 7"
Cohesion: 0.13
Nodes (24): allocSlot(), deinit(), FlipVariant, freeImageData(), freeTerminalData(), getAllTerminalIds(), getFlippedPixels(), getFrameCount() (+16 more)

### Community 8 - "Community 8"
Cohesion: 0.1
Nodes (6): Timer, TimerSlot, TimerSystem, Tween, TweenProp, TweenSlot

### Community 9 - "Community 9"
Cohesion: 0.16
Nodes (4): AudioSystem, LoadOpts, PlayOpts, SoundSlot

### Community 10 - "Community 10"
Cohesion: 0.19
Nodes (14): cleanupShmFiles(), deinit(), drainTty(), init(), logTransport(), probePosixShm(), probeTmpfile(), probeTransport() (+6 more)

### Community 11 - "Community 11"
Cohesion: 0.14
Nodes (9): Action, Button, GamepadState, getGamepadState(), InputState, KeyEvent, keyName(), MouseEvent (+1 more)

### Community 12 - "Community 12"
Cohesion: 0.22
Nodes (13): cacheEngineRef(), callDraw(), callEngineFunc(), callLoad(), callOnKey(), callOnMouse(), callQuit(), callUpdate() (+5 more)

### Community 13 - "Community 13"
Cohesion: 0.18
Nodes (2): Entity, EntityPool

### Community 14 - "Community 14"
Cohesion: 0.29
Nodes (2): Db, SaveDb

### Community 15 - "Community 15"
Cohesion: 0.4
Nodes (7): advance_phase(), engine.draw(), engine.load(), engine.on_key(), engine.update(), hsv_to_rgb(), init_particles()

### Community 16 - "Community 16"
Cohesion: 0.42
Nodes (6): Event, fatalLuaError(), handleKey(), logLuaError(), main(), stderrPrint()

### Community 17 - "Community 17"
Cohesion: 0.29
Nodes (1): SpritePlacement

### Community 18 - "Community 18"
Cohesion: 0.67
Nodes (1): DrawTilemapOpts

### Community 19 - "Community 19"
Cohesion: 0.67
Nodes (1): Vec2

### Community 20 - "Community 20"
Cohesion: 0.67
Nodes (3): ECS Component Store (component_store.zig), ECS Entity Module (entity.zig), ECS World Module (world.zig)

### Community 21 - "Community 21"
Cohesion: 1.0
Nodes (0): 

### Community 22 - "Community 22"
Cohesion: 1.0
Nodes (0): 

### Community 23 - "Community 23"
Cohesion: 1.0
Nodes (1): Tilemap Module (tilemap.zig)

### Community 24 - "Community 24"
Cohesion: 1.0
Nodes (1): Timer Module (timer.zig)

### Community 25 - "Community 25"
Cohesion: 1.0
Nodes (1): Dual Distribution (Standalone + Library)

## Knowledge Gaps
- **62 isolated node(s):** `KeyEvent`, `Action`, `MouseEvent`, `Button`, `GamepadState` (+57 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 21`** (2 nodes): `build()`, `build.zig`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 22`** (1 nodes): `root.zig`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 23`** (1 nodes): `Tilemap Module (tilemap.zig)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 24`** (1 nodes): `Timer Module (timer.zig)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 25`** (1 nodes): `Dual Distribution (Standalone + Library)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `KeyEvent`, `Action`, `MouseEvent` to the rest of the system?**
  _62 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.09 - nodes in this community are weakly interconnected._
- **Should `Community 3` be split into smaller, more focused modules?**
  _Cohesion score 0.09 - nodes in this community are weakly interconnected._
- **Should `Community 4` be split into smaller, more focused modules?**
  _Cohesion score 0.07 - nodes in this community are weakly interconnected._
- **Should `Community 7` be split into smaller, more focused modules?**
  _Cohesion score 0.13 - nodes in this community are weakly interconnected._