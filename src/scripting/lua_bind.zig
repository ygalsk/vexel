const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;

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
