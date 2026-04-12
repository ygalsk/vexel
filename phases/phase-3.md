# Phase 3: Input & Scene Management

## Goal
Full keyboard/mouse handling with kitty keyboard protocol. Scene stack with transitions.

## Deliverables

### Enhanced Input (`src/engine/input.zig`)
- [ ] Kitty keyboard protocol — full key press + release tracking
- [ ] Modifier keys as separate events
- [ ] Key repeat detection
- [ ] Mouse hover/drag tracking
- [ ] Gamepad-style abstraction (directional + action buttons mapped from keyboard)
- [ ] Input state queries — `engine.input.is_key_down("left")`

### Scene Management
- [ ] Scene stack — push, pop, switch
- [ ] Each scene has its own `load`, `update`, `draw`, `on_key`, `on_mouse`
- [ ] Scene-to-scene data passing
- [ ] `engine.scene.push("name", data)` — push new scene, pause current
- [ ] `engine.scene.pop()` — return to previous scene
- [ ] `engine.scene.switch("name", opts)` — replace current scene

### Transitions
- [ ] Fade transition (alpha interpolation)
- [ ] Slide transition (horizontal/vertical)
- [ ] Wipe transition
- [ ] Custom duration per transition
- [ ] `engine.scene.switch("name", { transition = "fade", duration = 0.5 })`

### Lua API
- [ ] `engine.input.is_key_down(key)` → boolean
- [ ] `engine.input.get_mouse()` → x, y, buttons
- [ ] `engine.scene.push(name, data)`
- [ ] `engine.scene.pop()`
- [ ] `engine.scene.switch(name, opts)`

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
