# Contributing to Vexel

Vexel has two faces — a **Lua runtime** for making terminal games and a **Zig library** for embedding terminal graphics. Contributions to either side are welcome.

## Prerequisites

- Zig 0.15.2
- A terminal that supports the Kitty graphics protocol (Kitty, Ghostty)

```bash
zig build                          # compile
zig build run -- examples/bounce/  # run an example
zig build test                     # unit tests
```

## Path A: Lua examples and API proposals

You don't need to know Zig. You need to know Lua and the [Lua API](docs/lua-api.md).

### Adding an example

Each example is a directory under `examples/` containing at least a `main.lua`:

```
examples/my-example/
  main.lua
  assets/        (optional — images, sounds)
```

Run it with `zig build run -- examples/my-example/`.

Look at `examples/bounce/` for a minimal starting point.

### Proposing new API surface

Open an issue first. Describe the Lua interface you want — what the function signature looks like, what it returns, and a short example of how you'd use it in a game. We'll discuss the design before anyone writes code.

## Path B: Engine internals (Zig)

Read [ARCHITECTURE.md](ARCHITECTURE.md) to understand the module structure, rendering pipeline, and the Zig-Lua boundary.

Key things to know:

- **`src/scripting/lua_api.zig`** registers all `engine.*` functions. New Lua-facing functions go here.
- **`src/scripting/lua_bind.zig`** implements the auto-wrapping binding system for user-registered Zig modules.
- **`src/scripting/lua_ecs.zig`** bridges the ECS to Lua.
- **`src/root.zig`** re-exports the public library API. If you add a new subsystem, expose it here.
- See [`examples/`](examples/) for complete Lua examples (boids, bounce, fractal).

### Adding a new `engine.*` function

1. Write the implementation as a Zig function in the appropriate subsystem (e.g., `src/graphics/renderer.zig`).
2. Add a Lua wrapper in `src/scripting/lua_api.zig` — follow the existing `lFunctionName` pattern. The wrapper extracts args from the Lua stack via `getUpvalue()` and the `lua.*` API, calls your Zig function, and pushes results back.
3. Register it in the `register()` function's module table (e.g., under `engine.graphics`).
4. Document it in `docs/lua-api.md`.

## Code style

- Match existing style. No reformatting adjacent code.
- Surgical changes — touch only what the PR requires.
- No speculative features or abstractions for single use.
- Run `zig build test` before submitting.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
