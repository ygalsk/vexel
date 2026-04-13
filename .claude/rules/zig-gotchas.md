---
paths:
  - "src/**/*.zig"
  - "build.zig"
  - "build.zig.zon"
---

# Zig Gotchas (0.15.2 / vaxis 0.5.1)

- `tty.writer()` -> `*std.Io.Writer`; `vx.resize(allocator, writer, winsize)`
- `std.Thread.sleep(ns)` not `std.time.sleep`
- `lua.toPointer()` -> error union, needs `catch` + `@constCast` for mutable ptr
- GCC 15: `link_gc_sections = true` on executables
- No `std.fmt.allocPrintZ` — use `allocPrint` with manual null terminator
- `win.writeCell(col, row, cell)` — positional args, not struct
