# Vexel

**Terminal graphics runtime — write Lua, not C.**

Pixel-perfect rendering, 8-layer compositing, audio, persistence, and an entity system. All in the terminal. All from Lua.

```lua
function engine.load()
    engine.graphics.set_resolution(320, 180)
end

function engine.draw()
    engine.graphics.pixel.rect(10, 10, 100, 60, 0xFF3366FF)
    engine.graphics.draw_text(2, 1, "hello from vexel", 0xFFFFFFFF)
end
```

```bash
zig build run -- my-project/    # project dir must contain main.lua
```

## What is this?

Vexel is a batteries-included terminal graphics runtime. The Zig core handles rendering, input, audio, and protocol negotiation. You write Lua.

Games, dashboards, visualizations, interactive tools — if it runs in a terminal and needs pixels, Vexel runs it.

**Backend: Kitty graphics protocol.** Pixel-perfect output on Kitty and compatible terminals (Ghostty falls back to base64 upload).

## Batteries included (all opt-in)

| Module | What it does |
|--------|-------------|
| **Graphics** | 8-layer pixel compositor, primitives, images, spritesheets, tilemaps |
| **Scenes** | Screen stack with push/pop/switch and transitions (fade, slide, wipe) |
| **ECS** | Sparse-set entity system with built-in movement, animation, and rendering |
| **Audio** | WAV/OGG/MP3 playback, volume, panning, fade in/out |
| **Input** | Keyboard, mouse, virtual gamepad |
| **Timers** | One-shot, repeating, tweens with easing |
| **Persistence** | Key-value store + raw SQLite |

## Build

Requires Zig 0.15.2.

```bash
zig build                        # compile
zig build run -- examples/bounce/   # run an example
zig build test                   # unit tests
```

## Docs

- [Lua API Reference](.claude/rules/vexel-engine.md) — full API surface
- [Architecture](ARCHITECTURE.md) — module structure, rendering pipeline, main loop
- [Design](DESIGN.md) — philosophy, phases, dependencies

## License

TBD
