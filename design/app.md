# App

The central orchestrator. Owns all subsystems, runs the main loop, handles lifecycle.

## Mental Model

```
App.init()
  |  create TTY, vaxis, kitty, compositor, sprite_placer, image_mgr,
  |  input, audio, Lua VM, save DB, cell_ctx, shader_registry
  |  probe kitty transport, register Lua API
  v
App.run()
  |  load main.lua, call engine.load()
  |  install signal handlers (SIGINT, SIGTERM)
  |
  |  MAIN LOOP (60fps target):
  |    poll vaxis events -> translate -> InputState + Lua callbacks
  |    call engine.update(dt)
  |    clear cell_ctx + sprite_placer
  |    call engine.draw()
  |    flush compositor -> upload composite image
  |    flush sprite_placer -> write Kitty placements into vaxis cells
  |    render error/FPS overlay if active
  |    vx.render() (cell layer + sprite placements)
  |    place composite image (pixel layer, behind cells via z-index -20)
  |    sleep to fill 16.67ms frame
  v
App.deinit()
  |  cleanup in reverse init order
```

**The frame has a specific render order that matters:**
1. `compositor.flush()` — composites layers, uploads Kitty image
2. `sprite_placer.flush()` — writes Kitty placements into vaxis cells (before vx.render)
3. Error/FPS overlay draw (cell-based, so it appears via vaxis render)
4. `vx.render()` — pushes cell grid + sprite placements to terminal
5. `compositor.placeComposite()` — emits Kitty placement escape *after* vaxis render, with z-index -20 so pixels appear behind text/cell content

This ordering ensures sprite placements are part of the vaxis cell grid, the composite image placement happens after vaxis has written its cells, and that text drawn via `drawText` renders on top of pixel layers.

## Key File

`src/app.zig` — 466 LOC. Owns all subsystems directly as fields (no facade/renderer indirection). `CellContext` (defined in lua_api.zig) wraps vaxis text/rect drawing with dirty tracking.

## Input

`src/engine/input.zig` — 252 LOC.

Translates vaxis key/mouse events into simplified Lua-friendly representations. Two things happen with each event:

1. **InputState** updated (HashMap of currently-held key names, mouse position/buttons)
2. **Lua callback** fired (`engine.on_key` / `engine.on_mouse`)

Mouse coordinates are converted from cell coordinates to virtual pixel coordinates before reaching Lua: `virtual_x = cell_x * virtual_width / terminal_cols`.

**Gamepad abstraction**: `getGamepadState()` maps keyboard to a virtual gamepad (arrows/WASD -> dpad, z/x -> a/b, return -> start, escape -> select). Polled each frame by Lua via `engine.input.get_gamepad()`.

## Persistence

`src/persistence/save.zig` — file-based persistence.

**SaveFs**: sandboxed file I/O to `<project_dir>/saves/`. Atomic writes (tmp + rename). Lua-side serializer emits `return { ... }` format, loaded via sandboxed `load()`. Two API layers: raw file I/O (`write_file`/`read_file`) and table convenience (`write`/`read`).

## Hot Reload (F5)

See [[scripting#Hot Reload]] for details. From App's perspective: destroy Lua VM, recreate, re-register API, reload game. All Zig-side state (compositor, images, audio) persists. Audio is stopped but not unloaded.

## Error Handling

Two tiers:
- **Fatal**: Lua errors during `loadGame()` or `engine.load()` exit the process (these mean the game can't start at all). Terminal is restored first via `exitAltScreen`.
- **Non-fatal**: Lua errors during `update()`/`draw()`/`on_key()`/`on_mouse()` get logged to stderr AND displayed as a red text overlay for 5 seconds. The game keeps running — useful for iterating with hot reload.

## Signal Handling

`SIGINT` (Ctrl+C) and `SIGTERM` set a global atomic bool. The main loop checks it each iteration. This ensures clean shutdown (terminal restoration, resource cleanup) even when killed.

There's also a panic handler (not in app.zig, in main.zig) that restores the terminal before crashing — so a Zig panic doesn't leave the terminal in raw mode.

## Decisions

### Why no ECS, scenes, timers, or tweens?
Removed April 2026. No comparable framework (LOVE, Pyxel, Raylib, PICO-8) ships these as built-ins — they're universally implemented as user-land libraries. Shipping them in the engine:
- Forces one opinion on game architecture
- Creates maintenance burden for features games may not use
- Makes the engine harder to understand

Games that need ECS can `require` a Lua library. The engine's job is rendering, input, audio, and persistence.

### Why 60fps fixed frame target?
16.67ms frame time. Simple `sleep(remaining)` — no vsync, no adaptive framerate. Terminal rendering is inherently non-realtime; 60fps is more than enough and keeps CPU usage reasonable. The terminal is the bottleneck, not the frame target.

### Why placer mode as default sprite mode?
Set at the start of `run()`: `self.sprite_mode = .placer`. Placer mode uploads sprites once and lets the terminal composite them, which is faster for games with many sprites. Compositor mode (blit into layer buffer) is available but requires the sprites to participate in layer blending, which most games don't need.

### Why no Renderer facade?
Removed April 2026. The `Renderer` was a 507-LOC facade that routed draw calls to compositor, sprite_placer, or image_mgr. But it was a thin pass-through — every method just called through to the real subsystem. Removing it:
- Eliminated one level of indirection for every draw call
- Made ownership clear (App owns subsystems directly)
- Moved `uploadVariant()` into ImageManager where it belongs (image lifecycle is now self-contained)
- SpritePlacer handles both sprite modes directly via `drawSprite()`
