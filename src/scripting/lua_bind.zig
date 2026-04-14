const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;
const Compositing = @import("compositing");
const Color = Compositing.Color;

/// Type-erased pixel shader dispatch function.
pub const ShaderDispatch = *const fn (buf: []u32, w: u16, h: u16, lua: *Lua) void;

const MAX_SHADERS = 8;

pub const ShaderRegistry = struct {
    names: [MAX_SHADERS][:0]const u8 = undefined,
    dispatchers: [MAX_SHADERS]ShaderDispatch = undefined,
    count: u8 = 0,

    pub fn register(self: *ShaderRegistry, name: [:0]const u8, dispatch: ShaderDispatch) void {
        if (self.count >= MAX_SHADERS) return;
        self.names[self.count] = name;
        self.dispatchers[self.count] = dispatch;
        self.count += 1;
    }

    pub fn find(self: *const ShaderRegistry, name: []const u8) ?ShaderDispatch {
        for (0..self.count) |i| {
            if (std.mem.eql(u8, self.names[i], name)) return self.dispatchers[i];
        }
        return null;
    }
};

/// Register a pixel shader function. The function must have the signature:
///   fn(px: f64, py: f64, w: f64, h: f64, ...uniforms) i32
/// where uniforms are f64 values passed from Lua.
pub fn registerPixelShader(
    registry: *ShaderRegistry,
    comptime name: [:0]const u8,
    comptime func: anytype,
) void {
    const FnType = @TypeOf(func);
    const info = @typeInfo(FnType).@"fn";

    // Validate: at least 4 params (px, py, w, h), all f64, returns i32
    if (info.params.len < 4) @compileError("pixel shader must have at least 4 parameters (px, py, w, h)");
    if (info.return_type.? != i32) @compileError("pixel shader must return i32");
    inline for (info.params) |p| {
        if (p.type.? != f64) @compileError("pixel shader parameters must all be f64");
    }

    const n_uniforms = info.params.len - 4;

    const dispatch = struct {
        fn inner(buf: []u32, w: u16, h: u16, lua: *Lua) void {
            var uniforms: [n_uniforms]f64 = undefined;
            inline for (0..n_uniforms) |i| {
                uniforms[i] = @floatCast(lua.toNumber(@intCast(i + 2)) catch 0.0);
            }

            const wf: f64 = @floatFromInt(w);
            const hf: f64 = @floatFromInt(h);
            const stride: usize = @intCast(w);

            for (0..@as(usize, h)) |row| {
                const py: f64 = @floatFromInt(row);
                const row_off = row * stride;
                for (0..@as(usize, w)) |col| {
                    const px: f64 = @floatFromInt(col);

                    var call_args: std.meta.ArgsTuple(FnType) = undefined;
                    call_args[0] = px;
                    call_args[1] = py;
                    call_args[2] = wf;
                    call_args[3] = hf;
                    inline for (0..n_uniforms) |i| {
                        call_args[4 + i] = uniforms[i];
                    }

                    const rgb: i32 = @call(.auto, func, call_args);
                    buf[row_off + col] = Color.fromHex(@intCast(rgb)).pack();
                }
            }
        }
    }.inner;

    registry.register(name, dispatch);
}

/// Register a Zig struct's public functions as a Lua global table.
///
/// Pure functions are auto-wrapped — zero Lua knowledge required:
///   `pub fn compute(x: f64, y: f64, n: i32) i32`
///   Supported param types: i32, i64, f32, f64, bool
///   Supported return types: i32, i64, f32, f64, bool, void
///
/// Example:
/// ```
/// const MyModule = struct {
///     pub fn add(a: f64, b: f64) f64 { return a + b; }
///     pub fn clamp(x: f64, lo: f64, hi: f64) f64 { ... }
/// };
/// lua_bind.registerModule(lua, "mymod", MyModule);
/// ```
pub fn registerModule(lua: *Lua, comptime name: [:0]const u8, comptime Module: type) void {
    lua.newTable();

    const decls = @typeInfo(Module).@"struct".decls;
    inline for (decls) |decl| {
        const func = @field(Module, decl.name);
        const FnType = @TypeOf(func);
        if (@typeInfo(FnType) != .@"fn") continue;

        lua.pushFunction(makeWrapper(Module, decl.name, FnType));
        lua.setField(-2, decl.name);
    }

    lua.setGlobal(name);
}

/// Generate a C function wrapper for a pure Zig function.
/// Extracts arguments from the Lua stack by type, calls the function, pushes the result.
fn makeWrapper(comptime Module: type, comptime name: []const u8, comptime FnType: type) zlua.CFn {
    const info = @typeInfo(FnType).@"fn";
    return struct {
        fn inner(state: ?*zlua.LuaState) callconv(.c) c_int {
            const lua: *Lua = @ptrCast(state.?);
            var call_args: std.meta.ArgsTuple(FnType) = undefined;

            inline for (info.params, 0..) |param, i| {
                const stack_idx: i32 = @intCast(i + 1);
                call_args[i] = extractArg(lua, param.type.?, stack_idx);
            }

            const result = @call(.auto, @field(Module, name), call_args);
            return pushResult(lua, @TypeOf(result), result);
        }
    }.inner;
}

/// Map Zig types to Lua stack extraction.
fn extractArg(lua: *Lua, comptime T: type, idx: i32) T {
    return switch (T) {
        f64 => @floatCast(lua.toNumber(idx) catch 0.0),
        f32 => @floatCast(lua.toNumber(idx) catch 0.0),
        i32 => @intCast(lua.toInteger(idx) catch 0),
        i64 => lua.toInteger(idx) catch 0,
        bool => lua.toBoolean(idx),
        else => @compileError("lua_bind: unsupported parameter type: " ++ @typeName(T)),
    };
}

/// Map Zig return types to Lua stack push. Returns number of Lua return values.
fn pushResult(lua: *Lua, comptime T: type, value: T) c_int {
    switch (T) {
        f64 => {
            lua.pushNumber(@floatCast(value));
            return 1;
        },
        f32 => {
            lua.pushNumber(@floatCast(value));
            return 1;
        },
        i32 => {
            lua.pushInteger(@intCast(value));
            return 1;
        },
        i64 => {
            lua.pushInteger(value);
            return 1;
        },
        bool => {
            lua.pushBoolean(value);
            return 1;
        },
        void => return 0,
        else => @compileError("lua_bind: unsupported return type: " ++ @typeName(T)),
    }
}
