# Graph Report - .  (2026-04-13)

## Corpus Check
- 43 files · ~358,567 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 759 nodes · 1112 edges · 61 communities detected
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 56 edges (avg confidence: 0.83)
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
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Community 49|Community 49]]
- [[_COMMUNITY_Community 50|Community 50]]
- [[_COMMUNITY_Community 51|Community 51]]
- [[_COMMUNITY_Community 52|Community 52]]
- [[_COMMUNITY_Community 53|Community 53]]
- [[_COMMUNITY_Community 54|Community 54]]
- [[_COMMUNITY_Community 55|Community 55]]
- [[_COMMUNITY_Community 56|Community 56]]
- [[_COMMUNITY_Community 57|Community 57]]
- [[_COMMUNITY_Community 58|Community 58]]
- [[_COMMUNITY_Community 59|Community 59]]
- [[_COMMUNITY_Community 60|Community 60]]

## God Nodes (most connected - your core abstractions)
1. `getUpvalue()` - 50 edges
2. `Vexel Terminal Game Engine` - 20 edges
3. `AudioSystem` - 17 edges
4. `ui/battle_screen.lua (Battle Scene)` - 17 edges
5. `World` - 12 edges
6. `handle_submenu_input()` - 11 edges
7. `Phase 9: Codecritter Port (Overview)` - 11 edges
8. `ui/dungeon_screen.lua (Dungeon Exploration Scene)` - 11 edges
9. `Castle Tileset` - 11 edges
10. `TimerSystem` - 10 edges

## Surprising Connections (you probably didn't know these)
- `Dungeon System` --references--> `Phase 5: Tilemap & Persistence (SQLite)`  [INFERRED]
  games/codecritter/DESIGN.md → phases/phase-5.md
- `Music Track Map` --references--> `Phase 4: Audio System (miniaudio/zaudio)`  [INFERRED]
  games/codecritter/DESIGN.md → phases/phase-4.md
- `Codecritter Game` --references--> `Phase 9: Codecritter Port (Overview)`  [EXTRACTED]
  games/codecritter/DESIGN.md → phases/phase-9.md
- `Codecritter Core Loop` --implements--> `dungeon/run.lua (Active Run State)`  [INFERRED]
  games/codecritter/DESIGN.md → phases/phase-9.3.md
- `Codecritter Type System (7 Types)` --references--> `Type Attack Effects (Per-Type Visuals)`  [EXTRACTED]
  games/codecritter/DESIGN.md → phases/phase-9.8.md

## Hyperedges (group relationships)
- **Battle Resolution Pipeline (Engine + AI + Status + Stats)** — phase91_battle_engine_lua, phase91_battle_ai_lua, phase91_battle_status_lua, phase91_critter_stats_lua, phase91_data_types_lua [EXTRACTED 0.95]
- **Dungeon → Battle → Dungeon Scene Flow** — phase93_ui_dungeon_screen_lua, phase92_ui_battle_screen_lua, phase93_dungeon_run_lua, phase3_scene_stack [EXTRACTED 0.95]
- **Phase 9 Sub-Phase Roadmap (9.1–9.9)** — phase91_data_layer, phase92_battle_screen, phase93_dungeon_exploration, phase94_shop_between_floors, phase95_hub, phase96_full_game_flow, phase97_persistence_sqlite, phase98_polish, phase99_meta_progression [EXTRACTED 1.00]
- **Rendering Subsystem: Kitty Protocol + Compositor + Layers** — design_kitty_protocol, arch_layer_model, arch_module_compositing, arch_module_kitty [INFERRED 0.90]
- **Lua Scripting Bridge: Engine + API + ECS Bindings** — arch_module_lua_engine, arch_module_lua_api, progress_src_lua_ecs [EXTRACTED 0.95]
- **Phase Implementation Lifecycle: Design → Progress → Source** — design_phase5, progress_phase5_done, progress_game_roguelike [INFERRED 0.85]

## Communities

### Community 0 - "Community 0"
Cohesion: 0.04
Nodes (87): Achievements (Commits System), Archetype System (7 Archetypes), Art Direction (640x360, 16x16 tiles), Battle System, Catch System, Codecritter Game, Codecritter Core Loop, Critter Biology (Stats System) (+79 more)

### Community 1 - "Community 1"
Cohesion: 0.06
Nodes (69): bindLuaParams(), checkDbHandle(), checkImageHandle(), checkSoundHandle(), EngineContext, getUpvalue(), lAudioLoad(), lAudioSetMasterVolume() (+61 more)

### Community 2 - "Community 2"
Cohesion: 0.04
Nodes (54): Dirty-Rect Tracking, Layer Model (5-Layer Compositor), Main Loop (~60fps), audio.zig — miniaudio Wrapper, compositing.zig — Layer Compositing, db.zig — SQLite Wrapper + KV Save API, image.zig — Image Loading and Sprite Sheets, input.zig — Key/Mouse Event Translation (+46 more)

### Community 3 - "Community 3"
Cohesion: 0.06
Nodes (22): clear(), clearSprites(), colorToVaxis(), deinitPixelMode(), drawRect(), drawSprite(), DrawSpriteOpts, drawText() (+14 more)

### Community 4 - "Community 4"
Cohesion: 0.09
Nodes (35): Idle Animation State, Run Animation State, Explosion Animation, Explosion Sprite Sheet, Fire Effect, Fire Skull Animation Frames, Fire Skull Enemy, Fire Skull Sprite Sheet (+27 more)

### Community 5 - "Community 5"
Cohesion: 0.09
Nodes (11): Animation, AnimationEvent, Collider, ComponentId, LuaComponentStore, Position, SpriteComp, SpriteRenderEntry (+3 more)

### Community 6 - "Community 6"
Cohesion: 0.12
Nodes (17): blendPixel(), blitBuffer(), blitImage(), Color, compositeOnly(), deinit(), div255(), drawCircle() (+9 more)

### Community 7 - "Community 7"
Cohesion: 0.15
Nodes (25): getEntityAtIndex(), getLuaComponent(), getUpvalue(), getZigComponent(), lCount(), lDespawn(), lEach(), lEachIterator() (+17 more)

### Community 8 - "Community 8"
Cohesion: 0.17
Nodes (22): blendFade(), blendSlide(), blendTransition(), blendWipe(), callSceneCallback(), callSceneCallbackWithNumber(), currentSceneRef(), draw() (+14 more)

### Community 9 - "Community 9"
Cohesion: 0.13
Nodes (24): allocSlot(), deinit(), FlipVariant, freeImageData(), freeTerminalData(), getAllTerminalIds(), getFlippedPixels(), getFrameCount() (+16 more)

### Community 10 - "Community 10"
Cohesion: 0.24
Nodes (22): active_player(), add_msg(), begin_defeat_sequence(), begin_victory_sequence(), check_end_conditions(), draw_menu_bg(), enter_submenu(), exit_submenu() (+14 more)

### Community 11 - "Community 11"
Cohesion: 0.1
Nodes (6): Timer, TimerSlot, TimerSystem, Tween, TweenProp, TweenSlot

### Community 12 - "Community 12"
Cohesion: 0.16
Nodes (4): AudioSystem, LoadOpts, PlayOpts, SoundSlot

### Community 13 - "Community 13"
Cohesion: 0.2
Nodes (13): advance_frame(), engine.draw(), engine.load(), engine.on_key(), engine.update(), hsv_to_rgb(), init_particles(), make_color() (+5 more)

### Community 14 - "Community 14"
Cohesion: 0.21
Nodes (11): first_row_in(), M.hp_bar(), M.hp_bar_sprite(), M.message_panel(), M.panel_row_y(), M.panel_text(), M.status_icon(), M.text() (+3 more)

### Community 15 - "Community 15"
Cohesion: 0.14
Nodes (9): Action, Button, GamepadState, getGamepadState(), InputState, KeyEvent, keyName(), MouseEvent (+1 more)

### Community 16 - "Community 16"
Cohesion: 0.22
Nodes (13): cacheEngineRef(), callDraw(), callEngineFunc(), callLoad(), callOnKey(), callOnMouse(), callQuit(), callUpdate() (+5 more)

### Community 17 - "Community 17"
Cohesion: 0.18
Nodes (2): Entity, EntityPool

### Community 18 - "Community 18"
Cohesion: 0.21
Nodes (12): Castle Tileset, Dark Green Color Palette, Pixel Art Style, Castle / Dungeon Theme, Chest / Container Tile, Castle Column Tile, Wooden Door Tile, Castle Platform Tile (+4 more)

### Community 19 - "Community 19"
Cohesion: 0.29
Nodes (2): Db, SaveDb

### Community 20 - "Community 20"
Cohesion: 0.22
Nodes (11): Arched Stone Columns, Dark Gothic Atmosphere, Castle Interior, Ivy/Vines Decoration, Pixel Art Style, Castle Background Scene, Stained Glass Window, Stone Brick Walls (+3 more)

### Community 21 - "Community 21"
Cohesion: 0.42
Nodes (6): Event, fatalLuaError(), handleKey(), logLuaError(), main(), stderrPrint()

### Community 22 - "Community 22"
Cohesion: 0.25
Nodes (0): 

### Community 23 - "Community 23"
Cohesion: 0.29
Nodes (1): SpritePlacement

### Community 24 - "Community 24"
Cohesion: 0.33
Nodes (0): 

### Community 25 - "Community 25"
Cohesion: 0.33
Nodes (0): 

### Community 26 - "Community 26"
Cohesion: 0.4
Nodes (2): M.calc_damage(), M.process_attack()

### Community 27 - "Community 27"
Cohesion: 0.33
Nodes (0): 

### Community 28 - "Community 28"
Cohesion: 0.47
Nodes (3): M.make_instance(), M.recalc_stats(), M.stat_at_level()

### Community 29 - "Community 29"
Cohesion: 0.4
Nodes (0): 

### Community 30 - "Community 30"
Cohesion: 0.4
Nodes (0): 

### Community 31 - "Community 31"
Cohesion: 0.5
Nodes (5): Blue Energy Orb Frame, Electro Shock Effect, Electro Shock Effect Sprite Sheet, Lightning / Electric Animation, Particle Dissolve Frames

### Community 32 - "Community 32"
Cohesion: 0.6
Nodes (5): Idle Animation, Female Ninja/Warrior Character, Pixel Art Style (16-bit RPG), Platformer Game, Idle Animation Sprite Sheet

### Community 33 - "Community 33"
Cohesion: 0.5
Nodes (5): Sky Background Layer, Full Moon Visual Element, Night Sky Scene, Parallax Background Layer, Pixel Art Visual Style

### Community 34 - "Community 34"
Cohesion: 0.5
Nodes (5): Mountains Background Asset, Background Parallax Layer, Desert Canyon / Rock Formation Theme, Pixel Art Visual Style, Scenes Demo Game

### Community 35 - "Community 35"
Cohesion: 0.6
Nodes (5): Floor Tile (Dungeon), Player Tile (@ Symbol), Stairs Tile (Descent Marker), Roguelike Tileset, Wall Tile (Stone)

### Community 36 - "Community 36"
Cohesion: 0.5
Nodes (0): 

### Community 37 - "Community 37"
Cohesion: 0.67
Nodes (4): Platformer Game, Walk Cycle Animation, Warrior/Mage Character, Walk Animation Sprite Sheet

### Community 38 - "Community 38"
Cohesion: 0.67
Nodes (4): Dragon Fly Animation, Dragon (Flying Creature), Dragon Fly Sprite Sheet, Pixel Art Fantasy Style

### Community 39 - "Community 39"
Cohesion: 0.67
Nodes (1): DrawTilemapOpts

### Community 40 - "Community 40"
Cohesion: 0.67
Nodes (1): Vec2

### Community 41 - "Community 41"
Cohesion: 0.67
Nodes (0): 

### Community 42 - "Community 42"
Cohesion: 0.67
Nodes (0): 

### Community 43 - "Community 43"
Cohesion: 0.67
Nodes (0): 

### Community 44 - "Community 44"
Cohesion: 0.67
Nodes (3): Lua Animation System (frame lists, speed, loop), Lua Retained Sprites System, Lua Sprites API Phase 2

### Community 45 - "Community 45"
Cohesion: 1.0
Nodes (0): 

### Community 46 - "Community 46"
Cohesion: 1.0
Nodes (0): 

### Community 47 - "Community 47"
Cohesion: 1.0
Nodes (0): 

### Community 48 - "Community 48"
Cohesion: 1.0
Nodes (0): 

### Community 49 - "Community 49"
Cohesion: 1.0
Nodes (0): 

### Community 50 - "Community 50"
Cohesion: 1.0
Nodes (0): 

### Community 51 - "Community 51"
Cohesion: 1.0
Nodes (2): Pixel Compositor (RGBA Layer Stack), Rationale: Pixel Compositor over Sub-cell Rendering

### Community 52 - "Community 52"
Cohesion: 1.0
Nodes (2): ECS Components (Position/Velocity/Sprite/Animation), ECS World (spawn/despawn/query)

### Community 53 - "Community 53"
Cohesion: 1.0
Nodes (2): timer.zig — Timer/Tween System, Lua Timers & Tweens API

### Community 54 - "Community 54"
Cohesion: 1.0
Nodes (2): Gamepad Abstraction (keyboard-mapped), Lua Input API (key/mouse/gamepad)

### Community 55 - "Community 55"
Cohesion: 1.0
Nodes (1): UX Principles (Apple HIG + Nielsen)

### Community 56 - "Community 56"
Cohesion: 1.0
Nodes (1): v1 Scope Boundary

### Community 57 - "Community 57"
Cohesion: 1.0
Nodes (1): Hello World Test Game

### Community 58 - "Community 58"
Cohesion: 1.0
Nodes (1): Bounce Test Game

### Community 59 - "Community 59"
Cohesion: 1.0
Nodes (1): Sprites Test Game (Gothic Castle)

### Community 60 - "Community 60"
Cohesion: 1.0
Nodes (1): Lua Graphics API Phase 1 (pixel drawing)

## Ambiguous Edges - Review These
- `Phase 3: Input & Scene Management` → `Phase 5: Tilemap & Persistence (SQLite)`  [AMBIGUOUS]
  phases/phase-5.md · relation: semantically_similar_to

## Knowledge Gaps
- **128 isolated node(s):** `Event`, `KeyEvent`, `Action`, `MouseEvent`, `Button` (+123 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 45`** (2 nodes): `build()`, `build.zig`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 46`** (2 nodes): `M.choose_move()`, `ai.lua`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 47`** (2 nodes): `M.get()`, `biomes.lua`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 48`** (2 nodes): `moves.lua`, `M.get()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 49`** (2 nodes): `species.lua`, `M.get()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 50`** (2 nodes): `types.lua`, `M.effectiveness()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 51`** (2 nodes): `Pixel Compositor (RGBA Layer Stack)`, `Rationale: Pixel Compositor over Sub-cell Rendering`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 52`** (2 nodes): `ECS Components (Position/Velocity/Sprite/Animation)`, `ECS World (spawn/despawn/query)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 53`** (2 nodes): `timer.zig — Timer/Tween System`, `Lua Timers & Tweens API`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 54`** (2 nodes): `Gamepad Abstraction (keyboard-mapped)`, `Lua Input API (key/mouse/gamepad)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 55`** (1 nodes): `UX Principles (Apple HIG + Nielsen)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 56`** (1 nodes): `v1 Scope Boundary`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 57`** (1 nodes): `Hello World Test Game`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 58`** (1 nodes): `Bounce Test Game`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 59`** (1 nodes): `Sprites Test Game (Gothic Castle)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 60`** (1 nodes): `Lua Graphics API Phase 1 (pixel drawing)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Phase 3: Input & Scene Management` and `Phase 5: Tilemap & Persistence (SQLite)`?**
  _Edge tagged AMBIGUOUS (relation: semantically_similar_to) - confidence is low._
- **What connects `Event`, `KeyEvent`, `Action` to the rest of the system?**
  _128 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.04 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.04 - nodes in this community are weakly interconnected._
- **Should `Community 3` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `Community 4` be split into smaller, more focused modules?**
  _Cohesion score 0.09 - nodes in this community are weakly interconnected._