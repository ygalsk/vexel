# Phase 3: Input & Scene Management

## Goal
Full keyboard/mouse handling with kitty keyboard protocol. Scene stack with transitions.

## Deliverables

### Enhanced Input (`src/engine/input.zig`)
- [x] Kitty keyboard protocol — full key press + release tracking
- [x] Modifier keys as separate events
- [x] Key repeat detection
- [x] Mouse hover/drag tracking
- [x] Gamepad-style abstraction (directional + action buttons mapped from keyboard)
- [x] Input state queries — `engine.input.is_key_down("left")`

### Scene Management
- [x] Scene stack — push, pop, switch
- [x] Each scene has its own `load`, `update`, `draw`, `on_key`, `on_mouse`
- [x] Scene-to-scene data passing
- [x] `engine.scene.push("name", data)` — push new scene, pause current
- [x] `engine.scene.pop()` — return to previous scene
- [x] `engine.scene.switch("name", opts)` — replace current scene

### Transitions
- [x] Fade transition (alpha interpolation)
- [x] Slide transition (horizontal/vertical)
- [x] Wipe transition
- [x] Custom duration per transition
- [x] `engine.scene.switch("name", { transition = "fade", duration = 0.5 })`

### Lua API
- [x] `engine.input.is_key_down(key)` → boolean
- [x] `engine.input.get_mouse()` → x, y, buttons
- [x] `engine.scene.push(name, data)`
- [x] `engine.scene.pop()`
- [x] `engine.scene.switch(name, opts)`

## Test Game
Menu → gameplay → pause → menu with transitions. Demonstrates:
- Scene stack (menu pushes gameplay, gameplay pushes pause)
- Fade/slide transitions between scenes
- Enhanced input handling (key state queries)

## Files
```
src/engine/input.zig         — MODIFY (enhanced input)
src/engine/scene.zig         — NEW
src/scripting/lua_api.zig    — MODIFY (scene + input APIs)
games/scenes/main.lua        — NEW test game
games/scenes/scenes/         — NEW (menu.lua, game.lua, pause.lua)
```
