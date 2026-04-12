# Vexel — Terminal Game Engine

A general-purpose terminal game engine. Zig core handles rendering, input, audio, and protocol negotiation. Lua 5.4 is the game scripting language. Games are directories of Lua scripts + assets.

**Backend: Kitty protocol only.** Pushes kitty graphics protocol and Unicode sub-cell rendering as far as they can go — pixel-perfect graphics, layered compositing, real audio.

Think LÖVE, but for the terminal.

## Distribution Model

Both library and standalone binary (same architecture):

- **Standalone binary** (primary): `vexel run mygame/` — loads `main.lua` from a game directory. Game authors write pure Lua. No Zig toolchain needed.
- **Zig library** (power users): engine is a Zig package. Games can mix Zig + Lua or use the engine API directly from Zig.

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for module structure and rendering pipeline.

## Implementation Phases

| Phase | Description | Status | Doc |
|-------|-------------|--------|-----|
| 0 | Skeleton | **Done** | [phases/phase-0.md](phases/phase-0.md) |
| 1 | Kitty Graphics + Sub-cell Rendering | Pending | [phases/phase-1.md](phases/phase-1.md) |
| 2 | Image & Sprite Support | Pending | [phases/phase-2.md](phases/phase-2.md) |
| 3 | Input & Scene Management | Pending | [phases/phase-3.md](phases/phase-3.md) |
| 4 | Audio | Pending | [phases/phase-4.md](phases/phase-4.md) |
| 5 | Tilemap & Persistence | Pending | [phases/phase-5.md](phases/phase-5.md) |
| 6 | Polish & Codecritter Port | Pending | [phases/phase-6.md](phases/phase-6.md) |

## Dependencies

| Dependency | Purpose |
|-----------|---------|
| libvaxis | Terminal I/O, kitty protocol, key events |
| ziglua (zlua) | Lua 5.4 embedding |
| zigimg | PNG/image loading (via vaxis transitive dep) |
| zqlite | SQLite persistence |
| miniaudio | Audio playback (Phase 4) |

## Open Questions

1. **Coordinate system**: fixed logical pixel grid (e.g., 320×180) scaled to terminal, or dynamic based on terminal dimensions?
2. **Tilemap format**: Tiled JSON? Custom Lua tables? Both?
3. **ECS or no**: provide entity-component system, or keep simple (game manages objects in Lua)?
4. **Networking**: multiplayer / networked play? (probably not for v1)
