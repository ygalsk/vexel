const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;
const Renderer = @import("renderer");
const Compositing = @import("compositing");

const SceneManager = @This();

// --- Types ---

const SceneEntry = struct {
    name: []const u8, // allocated copy
    table_ref: i32, // Lua registry ref to scene table
};

pub const TransitionKind = enum {
    none,
    fade,
    slide_left,
    slide_right,
    wipe,

    pub fn fromString(s: []const u8) TransitionKind {
        if (std.mem.eql(u8, s, "fade")) return .fade;
        if (std.mem.eql(u8, s, "slide_left")) return .slide_left;
        if (std.mem.eql(u8, s, "slide_right")) return .slide_right;
        if (std.mem.eql(u8, s, "wipe")) return .wipe;
        return .none;
    }
};

const Transition = struct {
    kind: TransitionKind,
    duration: f64,
    elapsed: f64,
    from_buf: []u8, // snapshot of outgoing scene (captured once at transition start)
    to_buf: []u8, // scratch buffer for incoming scene each frame
};

// --- Fields ---

allocator: std.mem.Allocator,
lua: *Lua,
renderer: *Renderer,

registry: std.StringHashMapUnmanaged(SceneEntry),
stack: std.ArrayListUnmanaged([]const u8), // stack of scene names
transition: ?Transition,
cached_active_ref: i32, // cached registry ref for top of stack (zlua.ref_no = invalid)

// --- Public API ---

pub fn init(allocator: std.mem.Allocator, lua: *Lua, renderer: *Renderer) SceneManager {
    return .{
        .allocator = allocator,
        .lua = lua,
        .renderer = renderer,
        .registry = .{},
        .stack = .{},
        .transition = null,
        .cached_active_ref = zlua.ref_no,
    };
}

pub fn deinit(self: *SceneManager) void {
    // Unref all scene tables
    var it = self.registry.iterator();
    while (it.next()) |entry| {
        self.lua.unref(zlua.registry_index, entry.value_ptr.table_ref);
        self.allocator.free(entry.value_ptr.name);
    }
    self.registry.deinit(self.allocator);

    // Free stack entries (names are owned by registry, not stack)
    self.stack.deinit(self.allocator);

    // Free transition buffers
    if (self.transition) |t| {
        self.allocator.free(t.from_buf);
        self.allocator.free(t.to_buf);
    }
}

pub fn registerScene(self: *SceneManager, name: []const u8, table_ref: i32) !void {
    if (self.registry.getPtr(name)) |existing| {
        self.lua.unref(zlua.registry_index, existing.table_ref);
        existing.table_ref = table_ref;
        self.invalidateCache();
    } else {
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);
        try self.registry.put(self.allocator, name_copy, .{
            .name = name_copy,
            .table_ref = table_ref,
        });
    }
}

pub fn hasScenes(self: *const SceneManager) bool {
    return self.registry.count() > 0;
}

pub fn pushScene(self: *SceneManager, name: []const u8, data_ref: i32) !void {
    // Pause current scene
    if (self.currentSceneRef()) |ref| {
        self.callSceneCallback(ref, "pause", 0);
    }

    try self.stack.append(self.allocator, name);
    self.invalidateCache();

    // Call load(data) on new scene
    if (self.getSceneRef(name)) |ref| {
        if (data_ref != zlua.ref_no) {
            _ = self.lua.rawGetIndex(zlua.registry_index, data_ref);
            self.callSceneCallback(ref, "load", 1);
            self.lua.unref(zlua.registry_index, data_ref);
        } else {
            self.callSceneCallback(ref, "load", 0);
        }
    }
}

pub fn popScene(self: *SceneManager, data_ref: i32) !void {
    if (self.stack.items.len == 0) return;

    // Call unload on current
    if (self.currentSceneRef()) |ref| {
        self.callSceneCallback(ref, "unload", 0);
    }

    _ = self.stack.pop();
    self.invalidateCache();

    // Call resume(data) on new top
    if (self.currentSceneRef()) |ref| {
        if (data_ref != zlua.ref_no) {
            _ = self.lua.rawGetIndex(zlua.registry_index, data_ref);
            self.callSceneCallback(ref, "resume", 1);
            self.lua.unref(zlua.registry_index, data_ref);
        } else {
            self.callSceneCallback(ref, "resume", 0);
        }
    }
}

pub fn switchScene(self: *SceneManager, name: []const u8, kind: TransitionKind, duration: f64, data_ref: i32) !void {
    if (kind == .none or duration <= 0) {
        // Instant switch — no transition
        if (self.stack.items.len > 0) {
            if (self.currentSceneRef()) |ref| {
                self.callSceneCallback(ref, "unload", 0);
            }
            self.stack.items[self.stack.items.len - 1] = name;
            self.invalidateCache();
        } else {
            try self.stack.append(self.allocator, name);
            self.invalidateCache();
        }
        if (self.getSceneRef(name)) |ref| {
            if (data_ref != zlua.ref_no) {
                _ = self.lua.rawGetIndex(zlua.registry_index, data_ref);
                self.callSceneCallback(ref, "load", 1);
                self.lua.unref(zlua.registry_index, data_ref);
            } else {
                self.callSceneCallback(ref, "load", 0);
            }
        }
        return;
    }

    // Start transition — snapshot the outgoing scene once
    const compositor = self.getCompositor() orelse return;
    const buf_size = @as(usize, compositor.width) * @as(usize, compositor.height) * 4;

    const from_buf = try self.allocator.alloc(u8, buf_size);
    errdefer self.allocator.free(from_buf);
    const to_buf = try self.allocator.alloc(u8, buf_size);
    errdefer self.allocator.free(to_buf);

    // Render outgoing scene into from_buf (done once, not per-frame)
    if (self.currentSceneRef()) |ref| {
        self.renderer.pixelClearAll();
        self.callSceneCallback(ref, "draw", 0);
        compositor.compositeOnly();
        @memcpy(from_buf[0..buf_size], compositor.composite_buf[0..buf_size]);
    } else {
        @memset(from_buf, 0);
    }

    self.transition = .{
        .kind = kind,
        .duration = duration,
        .elapsed = 0,
        .from_buf = from_buf,
        .to_buf = to_buf,
    };

    // Unload outgoing, replace stack top with new scene
    if (self.stack.items.len > 0) {
        if (self.currentSceneRef()) |ref| {
            self.callSceneCallback(ref, "unload", 0);
        }
        self.stack.items[self.stack.items.len - 1] = name;
        self.invalidateCache();
    } else {
        try self.stack.append(self.allocator, name);
        self.invalidateCache();
    }

    // Load the incoming scene
    if (self.getSceneRef(name)) |ref| {
        if (data_ref != zlua.ref_no) {
            _ = self.lua.rawGetIndex(zlua.registry_index, data_ref);
            self.callSceneCallback(ref, "load", 1);
            self.lua.unref(zlua.registry_index, data_ref);
        } else {
            self.callSceneCallback(ref, "load", 0);
        }
    }
}

pub fn update(self: *SceneManager, dt: f64) void {
    if (self.transition) |*t| {
        t.elapsed += dt;
        if (t.elapsed >= t.duration) {
            self.allocator.free(t.from_buf);
            self.allocator.free(t.to_buf);
            self.transition = null;
        }
        // During transition, still call update on incoming scene
        if (self.currentSceneRef()) |ref| {
            self.callSceneCallbackWithNumber(ref, "update", dt);
        }
        return;
    }

    if (self.currentSceneRef()) |ref| {
        self.callSceneCallbackWithNumber(ref, "update", dt);
    }
}

pub fn draw(self: *SceneManager) void {
    if (self.transition) |*t| {
        const compositor = self.getCompositor() orelse return;
        const buf_size = @as(usize, compositor.width) * @as(usize, compositor.height) * 4;
        const progress: f64 = @min(1.0, t.elapsed / t.duration);

        // Render incoming scene into to_buf (from_buf was captured at transition start)
        self.renderer.pixelClearAll();
        if (self.currentSceneRef()) |ref| {
            self.callSceneCallback(ref, "draw", 0);
        }
        compositor.compositeOnly();
        @memcpy(t.to_buf[0..buf_size], compositor.composite_buf[0..buf_size]);

        // Blend from_buf (outgoing snapshot) + to_buf (incoming) into composite_buf
        blendTransition(compositor.composite_buf, t.from_buf, t.to_buf, t.kind, progress, compositor.width, compositor.height);
        compositor.markAllDirty();
        return;
    }

    if (self.currentSceneRef()) |ref| {
        self.callSceneCallback(ref, "draw", 0);
    }
}

pub fn onKey(self: *SceneManager, key_name: []const u8, action: []const u8) void {
    // Block input during transitions
    if (self.transition != null) return;

    if (self.currentSceneRef()) |ref| {
        _ = self.lua.rawGetIndex(zlua.registry_index, ref);
        const field_type = self.lua.getField(-1, "on_key");
        if (field_type != .function) {
            self.lua.pop(2);
            return;
        }
        _ = self.lua.pushString(key_name);
        _ = self.lua.pushString(action);
        self.lua.protectedCall(.{ .args = 2, .results = 0 }) catch {
            self.logSceneError("on_key");
        };
        self.lua.pop(1); // pop scene table
    }
}

pub fn onMouse(self: *SceneManager, x: i32, y: i32, button: []const u8, action: []const u8) void {
    if (self.transition != null) return;

    if (self.currentSceneRef()) |ref| {
        _ = self.lua.rawGetIndex(zlua.registry_index, ref);
        const field_type = self.lua.getField(-1, "on_mouse");
        if (field_type != .function) {
            self.lua.pop(2);
            return;
        }
        self.lua.pushInteger(x);
        self.lua.pushInteger(y);
        _ = self.lua.pushString(button);
        _ = self.lua.pushString(action);
        self.lua.protectedCall(.{ .args = 4, .results = 0 }) catch {
            self.logSceneError("on_mouse");
        };
        self.lua.pop(1);
    }
}

// --- Helpers ---

fn currentSceneRef(self: *SceneManager) ?i32 {
    if (self.cached_active_ref != zlua.ref_no) return self.cached_active_ref;
    if (self.stack.items.len == 0) return null;
    const ref = self.getSceneRef(self.stack.items[self.stack.items.len - 1]) orelse return null;
    self.cached_active_ref = ref;
    return ref;
}

fn invalidateCache(self: *SceneManager) void {
    self.cached_active_ref = zlua.ref_no;
}

fn getSceneRef(self: *SceneManager, name: []const u8) ?i32 {
    const entry = self.registry.get(name) orelse return null;
    return entry.table_ref;
}

fn getCompositor(self: *SceneManager) ?*Compositing {
    return self.renderer.getCompositor();
}

fn logSceneError(self: *SceneManager, context: []const u8) void {
    const msg = self.lua.toString(-1) catch "unknown error";
    var buf: [512]u8 = undefined;
    const formatted = std.fmt.bufPrint(&buf, "Lua error in scene.{s}: {s}\n", .{ context, msg }) catch "vexel: scene error\n";
    std.fs.File.stderr().writeAll(formatted) catch {};
    self.lua.pop(1);
}

/// Call a zero-arg or data-arg callback on a scene table.
/// When args > 0, those values must already be on the Lua stack BEFORE this call.
/// Stack on entry: [...args...] (args values on top)
fn callSceneCallback(self: *SceneManager, table_ref: i32, func_name: [:0]const u8, args: u8) void {
    _ = self.lua.rawGetIndex(zlua.registry_index, table_ref);
    const field_type = self.lua.getField(-1, func_name);
    if (field_type != .function) {
        self.lua.pop(2); // pop nil + scene table
        if (args > 0) {
            self.lua.pop(@intCast(args)); // pop unused args
        }
        return;
    }

    if (args > 0) {
        // Stack: [...args...] [scene_table] [func]
        self.lua.remove(-2); // remove scene table: [...args...] [func]
        // Rotate func below args: [...] [func] [args...]
        self.lua.rotate(-@as(i32, @intCast(args)) - 1, 1);
        self.lua.protectedCall(.{ .args = args, .results = 0 }) catch {
            self.logSceneError(func_name);
        };
    } else {
        self.lua.remove(-2); // remove scene table: [func]
        self.lua.protectedCall(.{ .args = 0, .results = 0 }) catch {
            self.logSceneError(func_name);
        };
    }
}

fn callSceneCallbackWithNumber(self: *SceneManager, table_ref: i32, func_name: [:0]const u8, value: f64) void {
    _ = self.lua.rawGetIndex(zlua.registry_index, table_ref);
    const field_type = self.lua.getField(-1, func_name);
    if (field_type != .function) {
        self.lua.pop(2);
        return;
    }
    self.lua.remove(-2); // remove scene table
    self.lua.pushNumber(@floatCast(value));
    self.lua.protectedCall(.{ .args = 1, .results = 0 }) catch {
        self.logSceneError(func_name);
    };
}

// --- Transition blending ---

fn blendTransition(dst: []u8, from: []const u8, to: []const u8, kind: TransitionKind, progress: f64, width: u16, height: u16) void {
    switch (kind) {
        .fade => blendFade(dst, from, to, progress),
        .slide_left => blendSlide(dst, from, to, progress, width, height, true),
        .slide_right => blendSlide(dst, from, to, progress, width, height, false),
        .wipe => blendWipe(dst, from, to, progress, width, height),
        .none => @memcpy(dst, to),
    }
}

fn blendFade(dst: []u8, from: []const u8, to: []const u8, progress: f64) void {
    const t: u16 = @intFromFloat(@min(255.0, @max(0.0, progress * 255.0)));
    const inv_t: u16 = 255 - t;
    const pixel_count = dst.len / 4;
    var i: usize = 0;
    while (i < pixel_count) : (i += 1) {
        const off = i * 4;
        dst[off] = @intCast((@as(u16, from[off]) * inv_t + @as(u16, to[off]) * t) / 255);
        dst[off + 1] = @intCast((@as(u16, from[off + 1]) * inv_t + @as(u16, to[off + 1]) * t) / 255);
        dst[off + 2] = @intCast((@as(u16, from[off + 2]) * inv_t + @as(u16, to[off + 2]) * t) / 255);
        dst[off + 3] = @intCast((@as(u16, from[off + 3]) * inv_t + @as(u16, to[off + 3]) * t) / 255);
    }
}

fn blendSlide(dst: []u8, from: []const u8, to: []const u8, progress: f64, width: u16, height: u16, left: bool) void {
    const w: usize = width;
    const h: usize = height;
    const offset_px: usize = @intFromFloat(@min(@as(f64, @floatFromInt(w)), @max(0.0, progress * @as(f64, @floatFromInt(w)))));

    for (0..h) |y| {
        const row_start = y * w * 4;
        if (left) {
            // Old scene slides left, new scene enters from right
            if (offset_px < w) {
                const from_start = offset_px * 4;
                const copy_len = (w - offset_px) * 4;
                @memcpy(dst[row_start..][0..copy_len], from[row_start + from_start ..][0..copy_len]);
            }
            if (offset_px > 0) {
                const dst_start = (w - offset_px) * 4;
                const copy_len = offset_px * 4;
                @memcpy(dst[row_start + dst_start ..][0..copy_len], to[row_start..][0..copy_len]);
            }
        } else {
            // Old scene slides right, new scene enters from left
            if (offset_px < w) {
                const dst_start = offset_px * 4;
                const copy_len = (w - offset_px) * 4;
                @memcpy(dst[row_start + dst_start ..][0..copy_len], from[row_start..][0..copy_len]);
            }
            if (offset_px > 0) {
                const copy_len = offset_px * 4;
                @memcpy(dst[row_start..][0..copy_len], to[row_start + (w - offset_px) * 4 ..][0..copy_len]);
            }
        }
    }
}

fn blendWipe(dst: []u8, from: []const u8, to: []const u8, progress: f64, _: u16, height: u16) void {
    const h: usize = height;
    const cutoff: usize = @intFromFloat(@min(@as(f64, @floatFromInt(h)), @max(0.0, progress * @as(f64, @floatFromInt(h)))));
    const row_bytes = dst.len / h;

    // Rows above cutoff: show "to" scene
    if (cutoff > 0) {
        const to_len = cutoff * row_bytes;
        @memcpy(dst[0..to_len], to[0..to_len]);
    }
    // Rows below cutoff: show "from" scene
    if (cutoff < h) {
        const from_start = cutoff * row_bytes;
        const from_len = (h - cutoff) * row_bytes;
        @memcpy(dst[from_start..][0..from_len], from[from_start..][0..from_len]);
    }
}

// --- Tests ---

test "transition blend fade" {
    var from = [_]u8{ 255, 0, 0, 255 }; // red
    var to = [_]u8{ 0, 0, 255, 255 }; // blue
    var dst: [4]u8 = undefined;
    blendFade(&dst, &from, &to, 0.5);
    // Should be roughly half and half
    try std.testing.expect(dst[0] < 140 and dst[0] > 115); // r
    try std.testing.expect(dst[2] < 140 and dst[2] > 115); // b
}
