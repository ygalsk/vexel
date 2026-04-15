# Scripting

The Lua bridge is the entire user-facing API. Everything a game author touches goes through this layer.

## Mental Model

```
main.lua (user code)
    |
    | engine.graphics.pixel.rect(...)
    v
lua_api.zig (40+ C closures registered as engine.*)
    |
    | getUpvalue() -> typed Zig pointer
    v
Compositor / SpritePlacer / ImageManager / AudioSystem / InputState / SaveDb
```

**lua_api.zig is a flat dispatch table, not a module hierarchy.** The `engine.graphics.pixel` nesting is just Lua table structure — underneath, each function is a standalone C closure with a Zig pointer captured as upvalue 1. There's no object-oriented dispatch or method resolution.

### The upvalue pattern

Every engine function is registered as a Lua closure with one upvalue: a light userdata pointer to the owning Zig subsystem. When called, `getUpvalue(lua, *Compositor)` (or `*SpritePlacer`, `*ImageManager`, etc.) extracts and casts this pointer. This avoids global state — multiple engine instances could theoretically coexist (though currently there's only one).

### Three layers of Lua<->Zig binding

1. **lua_api.zig** (1034 LOC): Hand-written C closures for engine API. Each function manually reads Lua stack args, calls Zig, pushes results. Necessary because these functions interact with complex state ([[graphics|compositor]], images, audio handles). Also defines `CellContext` (text/rect drawing with dirty tracking) and `EngineContext` (the subsystem pointer bundle passed to `register()`).

2. **lua_bind.registerModule()** (247 LOC): Auto-wrapping for pure functions. Give it a Zig struct, it reflects over public functions and generates Lua wrappers automatically. Only supports simple types: `i32, i64, f32, f64, bool`. Used for user-defined Zig modules exposed to Lua (math helpers, SDF functions, etc).

3. **lua_engine.zig** (173 LOC): VM lifecycle. Init, load `main.lua`, set `package.path`, call lifecycle hooks (`load`, `update`, `draw`, `on_key`, `on_mouse`, `quit`). Thin wrapper — just manages the VM and invokes callbacks.

## Key Files

| File | LOC | Role |
|------|-----|------|
| `src/scripting/lua_api.zig` | 1034 | Hand-written engine API bindings (40+ functions), CellContext, EngineContext |
| `src/scripting/lua_bind.zig` | 247 | Auto-wrap pure Zig functions + pixel shader dispatch |
| `src/scripting/lua_engine.zig` | 173 | VM lifecycle, game loading, callback invocation |

## Pixel Shader Dispatch

The shader system lets Zig do the heavy per-pixel math while Lua just says "run this shader with these uniforms."

```
Lua: engine.graphics.pixel.shade("sdf", time)
  -> lPixelShade finds "sdf" in ShaderRegistry
  -> dispatch writes directly into compositor layer buffer (getActiveLayerSlice)
  -> thread pool splits rows across cores
```

**ShaderRegistry** stores up to 8 named shaders. Each shader is a type-erased `ShaderDispatch` function pointer created at comptime by `registerPixelShader()`:

1. Validates signature: `fn(px, py, w, h, ...uniforms: f64) i32`
2. Generates a dispatch closure that:
   - Reads uniform values from Lua stack
   - Splits pixel rows across thread pool workers
   - Each worker calls the Zig function per-pixel, writes packed RGBA into the buffer

There are also **simulation shaders** (`registerSimulation`): same registry, but the function gets the whole buffer and runs serially. For cellular automata, fluid sims, etc where pixels read neighbors.

### Thread pool

Global `g_pool` in lua_bind.zig. Explicitly managed: `initPool()` at `App.run()` start, `deinitPool()` at `App.deinit()`. Was previously lazy-initialized and leaked.

## Handle Types

Three metatabled userdata types in Lua:

- **VexelImage**: wraps `ImageHandle` (u32 slot index into [[graphics#Image Manager|ImageManager]]). Has `__gc` metamethod that calls `unloadImage` on collection.
- **VexelSound**: wraps `SoundId` (u32 slot index into [[audio|AudioSystem]]). Has `__gc` + method table (play, stop, pause, resume, set_volume, set_pan, fade_in, fade_out).

## Hot Reload

F5 triggers `hotReload()` in [[app]]:
1. Stop all audio
2. Destroy Lua VM entirely
3. Reset input state
4. Create fresh VM
5. Re-register all `engine.*` API functions (`registerLuaApi()`)
6. Reload `main.lua`, call `engine.load()`

This is a full teardown/rebuild — no incremental reloading. Image handles from the old VM are orphaned (GC'd when the old VM was destroyed). The Zig-side image manager, compositor, and sprite placer persist across reloads.

## Decisions

### Why hand-written bindings instead of all auto-wrapped?
The engine API functions do complex things: parse option tables, create metatabled userdata, handle optional parameters, interact with multiple subsystems. Auto-wrapping only works for pure `f64 -> f64` style functions. Trying to auto-wrap the engine API would require a DSL more complex than the manual code.

### Why upvalue closures instead of a global engine pointer?
Upvalues are the Lua-idiomatic way to capture context. A global would work but couples the binding code to a singleton assumption. The upvalue pattern came from studying how LOVE2D and Defold structure their Lua bindings.

### Why not LuaJIT?
Lua 5.4 via ziglua gives native Zig interop without FFI complexity. LuaJIT would be faster for pure Lua code but harder to integrate with Zig's type system and allocator model. For a terminal graphics runtime where the hot path is in Zig shaders, Lua interpretation speed isn't the bottleneck.

## Open Questions

- lua_api.zig at 1034 LOC is the largest file. Could split into lua_api_graphics.zig, lua_api_audio.zig, etc. — but that's just moving code around without reducing complexity. Worth doing only if it becomes hard to navigate.
