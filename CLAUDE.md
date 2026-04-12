# Vexel

Terminal game engine. Zig 0.15.2 + libvaxis + ziglua (Lua 5.4) + zqlite.

## Build
```
zig build          # compile
zig build run -- games/hello/   # run hello world test game
zig build test     # unit tests
```

## Structure
```
src/engine/       # Input translation
src/graphics/     # Renderer (kitty protocol only)
src/scripting/    # Lua engine + API bindings
src/persistence/  # SQLite (Phase 5)
src/audio/        # Audio (Phase 4)
src/main.zig      # Standalone binary entry point
games/            # Test games (one per phase)
phases/           # Phase implementation plans with checklists
```

## Key Docs
- `DESIGN.md` — vision, distribution model, phase overview
- `ARCHITECTURE.md` — module structure, rendering pipeline, main loop
- `LUA_API.md` — full Lua-facing API reference
- `phases/phase-N.md` — detailed checklist per implementation phase

## Design Philosophy
- Follow John Ousterhout's principles (A Philosophy of Software Design): deep modules with simple interfaces, strategic not tactical programming, reduce complexity through good abstractions
- Aristotelian problem decomposition: break problems into fundamental categories, define clear genus/species relationships between concepts, reason from first principles
- When stuck or designing a new subsystem, do thorough web research on how existing game engines (LÖVE, Raylib, SDL) handle the same problem before implementing
- Prefer fewer, deeper modules over many shallow ones

## Workflow
- **NON-NEGOTIABLE**: Always discuss major steps and design decisions with the user BEFORE implementing. Never make architectural choices, API design decisions, or significant implementation changes silently.
- When starting a new phase or major feature, present key decisions and tradeoffs for user input first.

## Conventions
- Kitty graphics protocol only — no sixel, no unicode sub-cell fallback, no ASCII
- Lua 5.4 is the game scripting language
- Games are directories with a `main.lua` entry point
- Engine API exposed as `engine.*` global table in Lua
- Phase workflow: review phase doc → implement checklist items → test game → mark done

## Zig Gotchas (0.15.2 / vaxis 0.5.1)
- `vaxis.Tty.init(buffer)` — needs a `[]u8` buffer for the writer
- `tty.writer()` returns `*std.Io.Writer` (new buffered IO)
- `vx.resize(allocator, writer, winsize)` — takes allocator + writer
- `win.writeCell(col, row, cell)` — positional args, not struct
- `std.Thread.sleep(ns)` not `std.time.sleep`
- `std.fs.File.stderr().writeAll(bytes)` for stderr output
- No `std.fmt.allocPrintZ` — use `allocPrint` with manual null terminator
- `lua.toPointer()` returns error union, needs `catch`, plus `@constCast` for mutable ptr
- GCC 15 `.sframe` fix: `link_gc_sections = true` on executables
