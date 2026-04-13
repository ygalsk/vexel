# Vexel
Terminal game engine. Zig 0.15.2 + libvaxis + ziglua (Lua 5.4) + zqlite + zaudio (miniaudio).

## Build
```
zig build                        # compile
zig build run -- games/hello/   # run hello world test game
zig build test                   # unit tests
```

## Design Philosophy — NON-NEGOTIABLE
- Ousterhout: deep modules, simple interfaces, strategic not tactical programming
- Aristotelian decomposition: genus/species relationships, reason from first principles
- Before designing a subsystem: research how LÖVE, Raylib, SDL handle the same problem
- Prefer fewer, deeper modules

## Workflow — NON-NEGOTIABLE
- Discuss major steps and design decisions with user BEFORE implementing or writing up a plan
- After every `/simplify`: update `PROGRESS.md`, stage all files, write a commit

## UI/UX — NON-NEGOTIABLE
- Apply Apple Human Interface Guidelines: clarity, deference, depth
- Apply Nielsen's 10 heuristics: visibility, feedback, consistency, error prevention, minimal design
- UI decisions must be justified against one of these — no arbitrary choices

## Zig Gotchas (0.15.2 / vaxis 0.5.1)
- `tty.writer()` → `*std.Io.Writer`; `vx.resize(allocator, writer, winsize)`
- `std.Thread.sleep(ns)` not `std.time.sleep`
- `lua.toPointer()` → error union, needs `catch` + `@constCast` for mutable ptr
- GCC 15: `link_gc_sections = true` on executables
- No `std.fmt.allocPrintZ` — use `allocPrint` with manual null terminator
- `win.writeCell(col, row, cell)` — positional args, not struct

## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- After modifying code files in this session, run `python3 -c "from graphify.watch import _rebuild_code; from pathlib import Path; _rebuild_code(Path('.'))"` to keep the graph current
