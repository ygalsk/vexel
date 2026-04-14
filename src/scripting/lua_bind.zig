const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;
const lua_api = @import("lua_api");

pub const EngineContext = lua_api.EngineContext;

/// Register a Zig struct's public functions as a Lua global table.
///
/// Two tiers of functions are supported:
///
/// **Tier 1 — Pure functions** (auto-wrapped, zero Lua knowledge):
///   `pub fn compute(x: f64, y: f64, n: i32) i32`
///   Supported param types: i32, i64, f32, f64, bool
///   Supported return types: i32, i64, f32, f64, bool, void
///
/// **Tier 2 — Engine-aware functions** (direct access to renderer/world/etc):
///   `pub fn render(ctx: *EngineContext, lua: *Lua) i32`
///   You extract Lua args and push returns manually. ctx provides engine subsystems.
///
/// Example:
/// ```
/// const MyModule = struct {
///     pub fn add(a: f64, b: f64) f64 { return a + b; }
///     pub fn blit(ctx: *EngineContext, lua: *Lua) i32 { ... }
/// };
/// lua_bind.registerModule(lua, "mymod", MyModule, &engine_ctx);
/// ```
pub fn registerModule(lua: *Lua, comptime name: [:0]const u8, comptime Module: type, ctx: *EngineContext) void {
    lua.newTable();

    const decls = @typeInfo(Module).@"struct".decls;
    inline for (decls) |decl| {
        const func = @field(Module, decl.name);
        const FnType = @TypeOf(func);
        if (@typeInfo(FnType) != .@"fn") continue;
        const info = @typeInfo(FnType).@"fn";

        if (comptime isTier2(info)) {
            lua.pushLightUserdata(@ptrCast(ctx));
            lua.pushClosure(makeTier2Wrapper(func), 1);
        } else {
            lua.pushFunction(makeTier1Wrapper(Module, decl.name, info));
        }
        lua.setField(-2, decl.name);
    }

    lua.setGlobal(name);
}

/// Detect tier 2 functions: first param is *EngineContext, second is *Lua.
fn isTier2(comptime info: std.builtin.Type.Fn) bool {
    if (info.params.len < 2) return false;
    const p0 = info.params[0].type orelse return false;
    const p1 = info.params[1].type orelse return false;
    return p0 == *EngineContext and p1 == *Lua;
}

/// Generate a C closure wrapper for a tier 2 function.
/// The EngineContext pointer is stored as upvalue 1.
fn makeTier2Wrapper(comptime func: anytype) zlua.CFn {
    return struct {
        fn inner(state: ?*zlua.LuaState) callconv(.c) c_int {
            const lua: *Lua = @ptrCast(state.?);
            const ptr = lua.toPointer(Lua.upvalueIndex(1)) catch unreachable;
            const ctx: *EngineContext = @ptrCast(@constCast(@alignCast(ptr)));
            return @call(.always_inline, func, .{ ctx, lua });
        }
    }.inner;
}

/// Generate a C function wrapper for a tier 1 (pure) function.
/// Extracts arguments from the Lua stack by type, calls the function, pushes the result.
fn makeTier1Wrapper(comptime Module: type, comptime name: []const u8, comptime info: std.builtin.Type.Fn) zlua.CFn {
    return struct {
        fn inner(state: ?*zlua.LuaState) callconv(.c) c_int {
            const lua: *Lua = @ptrCast(state.?);
            const args = comptime extractArgTypes(info);
            var call_args: ArgsTuple(args) = undefined;

            // Extract each argument from the Lua stack (1-indexed)
            inline for (args, 0..) |arg_type, i| {
                const stack_idx: i32 = @intCast(i + 1);
                call_args[i] = extractArg(lua, arg_type, stack_idx);
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

/// Extract parameter types from function info, excluding self/ctx params.
fn extractArgTypes(comptime info: std.builtin.Type.Fn) [info.params.len]type {
    var types: [info.params.len]type = undefined;
    inline for (info.params, 0..) |param, i| {
        types[i] = param.type.?;
    }
    return types;
}

/// Build a tuple type from an array of types.
fn ArgsTuple(comptime types: anytype) type {
    var fields: [types.len]std.builtin.Type.StructField = undefined;
    inline for (types, 0..) |T, i| {
        fields[i] = .{
            .name = std.fmt.comptimePrint("{d}", .{i}),
            .type = T,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(T),
        };
    }
    return @Type(.{ .@"struct" = .{
        .layout = .auto,
        .fields = &fields,
        .decls = &.{},
        .is_tuple = true,
    } });
}
