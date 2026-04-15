const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;

const LuaEngine = @This();

lua: *Lua,
allocator: std.mem.Allocator,
game_dir: []const u8,
engine_ref: i32 = zlua.ref_no,

pub fn init(allocator: std.mem.Allocator, game_dir: []const u8) !LuaEngine {
    const lua = try Lua.init(allocator);
    lua.openLibs();

    return .{
        .lua = lua,
        .allocator = allocator,
        .game_dir = game_dir,
    };
}

pub fn deinit(self: *LuaEngine) void {
    if (self.engine_ref != zlua.ref_no) {
        self.lua.unref(zlua.registry_index, self.engine_ref);
    }
    self.lua.deinit();
}

/// Load and execute the game's main.lua
pub fn loadGame(self: *LuaEngine) !void {
    // Set package.path to include the game directory for require()
    self.setupPackagePath() catch {};

    const path_z = try std.fmt.allocPrintSentinel(self.allocator, "{s}/main.lua", .{self.game_dir}, 0);
    defer self.allocator.free(path_z);

    try self.lua.doFile(path_z);
    self.cacheEngineRef();
}

fn setupPackagePath(self: *LuaEngine) !void {
    const lua_type = self.lua.getGlobal("package") catch return;
    if (lua_type != .table) {
        self.lua.pop(1);
        return;
    }
    // Get existing package.path
    const existing_type = self.lua.getField(-1, "path");
    const existing = if (existing_type == .string) (self.lua.toString(-1) catch "") else "";
    self.lua.pop(1);

    // Build new path: <game_dir>/?.lua;<game_dir>/?/init.lua;<existing>
    const new_path_z = try std.fmt.allocPrintSentinel(self.allocator, "{s}/?.lua;{s}/?/init.lua;{s}", .{ self.game_dir, self.game_dir, existing }, 0);
    defer self.allocator.free(new_path_z);

    _ = self.lua.pushString(new_path_z);
    self.lua.setField(-2, "path");
    self.lua.pop(1); // pop package table
}

/// Call engine.load() if it exists
pub fn callLoad(self: *LuaEngine) !void {
    try self.callEngineFunc("load", 0);
}

/// Call engine.update(dt) — dt in seconds
pub fn callUpdate(self: *LuaEngine, dt: f64) !void {
    if (try self.getEngineFunc("update")) {
        self.lua.pushNumber(@floatCast(dt));
        try self.lua.protectedCall(.{ .args = 1, .results = 0 });
    }
}

/// Call engine.draw()
pub fn callDraw(self: *LuaEngine) !void {
    try self.callEngineFunc("draw", 0);
}

/// Call engine.on_key(key_name, action)
pub fn callOnKey(self: *LuaEngine, key_name: []const u8, action: []const u8) !void {
    if (try self.getEngineFunc("on_key")) {
        _ = self.lua.pushString(key_name);
        _ = self.lua.pushString(action);
        try self.lua.protectedCall(.{ .args = 2, .results = 0 });
    }
}

/// Call engine.on_mouse(x, y, button, action)
pub fn callOnMouse(self: *LuaEngine, x: i32, y: i32, button: []const u8, action: []const u8) !void {
    if (try self.getEngineFunc("on_mouse")) {
        self.lua.pushInteger(x);
        self.lua.pushInteger(y);
        _ = self.lua.pushString(button);
        _ = self.lua.pushString(action);
        try self.lua.protectedCall(.{ .args = 4, .results = 0 });
    }
}

/// Call engine.quit() if it exists
pub fn callQuit(self: *LuaEngine) !void {
    try self.callEngineFunc("quit", 0);
}

pub fn shouldQuit(self: *LuaEngine) bool {
    if (!self.pushEngineTable()) return false;
    defer self.lua.pop(1);

    const field_type = self.lua.getField(-1, "should_quit");
    defer self.lua.pop(1);
    if (field_type != .boolean) return false;

    return self.lua.toBoolean(-1);
}

pub fn isDebugMode(self: *LuaEngine) bool {
    if (!self.pushEngineTable()) return false;
    defer self.lua.pop(1);

    const field_type = self.lua.getField(-1, "debug");
    defer self.lua.pop(1);
    if (field_type != .boolean) return false;

    return self.lua.toBoolean(-1);
}

// --- helpers ---

fn cacheEngineRef(self: *LuaEngine) void {
    if (self.engine_ref != zlua.ref_no) {
        self.lua.unref(zlua.registry_index, self.engine_ref);
        self.engine_ref = zlua.ref_no;
    }
    const lua_type = self.lua.getGlobal("engine") catch return;
    if (lua_type != .table) {
        self.lua.pop(1);
        return;
    }
    self.engine_ref = self.lua.ref(zlua.registry_index) catch {
        return;
    };
}

/// Push the engine table onto the stack. Returns true if successful.
fn pushEngineTable(self: *LuaEngine) bool {
    if (self.engine_ref != zlua.ref_no) {
        _ = self.lua.rawGetIndex(zlua.registry_index, self.engine_ref);
        if (self.lua.typeOf(-1) == .table) return true;
        self.lua.pop(1);
    }
    const lua_type = self.lua.getGlobal("engine") catch return false;
    if (lua_type != .table) {
        self.lua.pop(1);
        return false;
    }
    return true;
}

fn callEngineFunc(self: *LuaEngine, name: [:0]const u8, args: i32) !void {
    if (try self.getEngineFunc(name)) {
        try self.lua.protectedCall(.{ .args = args, .results = 0 });
    }
}

fn getEngineFunc(self: *LuaEngine, name: [:0]const u8) !bool {
    if (!self.pushEngineTable()) return false;

    const field_type = self.lua.getField(-1, name);
    if (field_type != .function) {
        self.lua.pop(2);
        return false;
    }

    self.lua.remove(-2);
    return true;
}

test "init and deinit" {
    var engine = try LuaEngine.init(std.testing.allocator, ".");
    defer engine.deinit();

    // engine global shouldn't exist yet
    try std.testing.expect(!engine.shouldQuit());
}
