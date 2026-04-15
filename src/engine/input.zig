const std = @import("std");
const vaxis = @import("vaxis");

/// Simplified key representation exposed to Lua
pub const KeyEvent = struct {
    name: []const u8,
    action: Action,
    shift: bool,
    ctrl: bool,
    alt: bool,

    pub const Action = enum { press, release, repeat };
};

/// Simplified mouse event exposed to Lua
pub const MouseEvent = struct {
    x: i32,
    y: i32,
    button: Button,
    action: Action,

    pub const Button = enum {
        left,
        right,
        middle,
        scroll_up,
        scroll_down,
        none,

        pub fn name(self: Button) []const u8 {
            return @tagName(self);
        }
    };
    pub const Action = enum {
        press,
        release,
        move,

        pub fn name(self: Action) []const u8 {
            return @tagName(self);
        }
    };
};

/// Translate a vaxis Key into our simplified KeyEvent
pub fn translateKey(key: vaxis.Key, action: KeyEvent.Action) KeyEvent {
    return .{
        .name = keyName(key),
        .action = action,
        .shift = key.mods.shift,
        .ctrl = key.mods.ctrl,
        .alt = key.mods.alt,
    };
}

/// Translate a vaxis Mouse into our simplified MouseEvent
pub fn translateMouse(mouse: vaxis.Mouse) MouseEvent {
    const button: MouseEvent.Button = switch (mouse.button) {
        .left => .left,
        .right => .right,
        .middle => .middle,
        .wheel_up => .scroll_up,
        .wheel_down => .scroll_down,
        else => .none,
    };
    const action: MouseEvent.Action = switch (mouse.type) {
        .press => .press,
        .release => .release,
        else => .move,
    };
    return .{
        .x = @intCast(mouse.col),
        .y = @intCast(mouse.row),
        .button = button,
        .action = action,
    };
}

fn keyName(key: vaxis.Key) []const u8 {
    return switch (key.codepoint) {
        vaxis.Key.escape => "escape",
        vaxis.Key.enter => "return",
        vaxis.Key.tab => "tab",
        vaxis.Key.backspace => "backspace",
        vaxis.Key.delete => "delete",
        vaxis.Key.left => "left",
        vaxis.Key.right => "right",
        vaxis.Key.up => "up",
        vaxis.Key.down => "down",
        vaxis.Key.home => "home",
        vaxis.Key.end => "end",
        vaxis.Key.page_up => "pageup",
        vaxis.Key.page_down => "pagedown",
        vaxis.Key.insert => "insert",
        vaxis.Key.space => "space",
        vaxis.Key.f1 => "f1",
        vaxis.Key.f2 => "f2",
        vaxis.Key.f3 => "f3",
        vaxis.Key.f4 => "f4",
        vaxis.Key.f5 => "f5",
        vaxis.Key.f6 => "f6",
        vaxis.Key.f7 => "f7",
        vaxis.Key.f8 => "f8",
        vaxis.Key.f9 => "f9",
        vaxis.Key.f10 => "f10",
        vaxis.Key.f11 => "f11",
        vaxis.Key.f12 => "f12",
        0x21...0x7e => {
            const table = comptime blk: {
                var t: [94][]const u8 = undefined;
                for (0x21..0x7f, 0..) |cp, i| {
                    t[i] = &[_]u8{@intCast(cp)};
                }
                break :blk t;
            };
            return table[key.codepoint - 0x21];
        },
        else => "unknown",
    };
}

// --- Input State Tracker ---

/// Tracks which keys are currently held, mouse position, and button state.
/// Key names from keyName() are all comptime/static strings, safe as HashMap keys.
pub const InputState = struct {
    keys_down: std.StringHashMapUnmanaged(void),
    mouse_x: i32,
    mouse_y: i32,
    mouse_left: bool,
    mouse_right: bool,
    mouse_middle: bool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) InputState {
        return .{
            .keys_down = .{},
            .mouse_x = 0,
            .mouse_y = 0,
            .mouse_left = false,
            .mouse_right = false,
            .mouse_middle = false,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InputState) void {
        self.keys_down.deinit(self.allocator);
    }

    pub fn reset(self: *InputState) void {
        self.keys_down.clearRetainingCapacity();
        self.mouse_x = 0;
        self.mouse_y = 0;
        self.mouse_left = false;
        self.mouse_right = false;
        self.mouse_middle = false;
    }

    pub fn processKeyEvent(self: *InputState, ev: KeyEvent) void {
        switch (ev.action) {
            .press => {
                self.keys_down.put(self.allocator, ev.name, {}) catch {};
            },
            .release => {
                _ = self.keys_down.remove(ev.name);
            },
            .repeat => {},
        }
    }

    pub fn processMouseEvent(self: *InputState, ev: MouseEvent) void {
        self.mouse_x = ev.x;
        self.mouse_y = ev.y;
        switch (ev.action) {
            .press => switch (ev.button) {
                .left => self.mouse_left = true,
                .right => self.mouse_right = true,
                .middle => self.mouse_middle = true,
                else => {},
            },
            .release => switch (ev.button) {
                .left => self.mouse_left = false,
                .right => self.mouse_right = false,
                .middle => self.mouse_middle = false,
                else => {},
            },
            .move => {},
        }
    }

    pub fn isKeyDown(self: *const InputState, key_name: []const u8) bool {
        return self.keys_down.contains(key_name);
    }
};

/// Gamepad-style abstraction mapped from keyboard keys.
pub const GamepadState = struct {
    up: bool,
    down: bool,
    left: bool,
    right: bool,
    a: bool,
    b: bool,
    start: bool,
    select: bool,
};

pub fn getGamepadState(input: *const InputState) GamepadState {
    return .{
        .up = input.isKeyDown("up") or input.isKeyDown("w"),
        .down = input.isKeyDown("down") or input.isKeyDown("s"),
        .left = input.isKeyDown("left") or input.isKeyDown("a"),
        .right = input.isKeyDown("right") or input.isKeyDown("d"),
        .a = input.isKeyDown("z"),
        .b = input.isKeyDown("x"),
        .start = input.isKeyDown("return"),
        .select = input.isKeyDown("escape"),
    };
}

test "key translation" {
    const key = vaxis.Key{ .codepoint = 'a', .mods = .{} };
    const ev = translateKey(key, .press);
    try std.testing.expectEqualStrings("a", ev.name);
    try std.testing.expectEqual(KeyEvent.Action.press, ev.action);
}

test "input state tracks key presses" {
    var state = InputState.init(std.testing.allocator);
    defer state.deinit();

    const press = translateKey(.{ .codepoint = 'a', .mods = .{} }, .press);
    state.processKeyEvent(press);
    try std.testing.expect(state.isKeyDown("a"));

    const release = translateKey(.{ .codepoint = 'a', .mods = .{} }, .release);
    state.processKeyEvent(release);
    try std.testing.expect(!state.isKeyDown("a"));
}

test "gamepad state maps keys" {
    var state = InputState.init(std.testing.allocator);
    defer state.deinit();

    state.processKeyEvent(translateKey(.{ .codepoint = vaxis.Key.left, .mods = .{} }, .press));
    state.processKeyEvent(translateKey(.{ .codepoint = 'z', .mods = .{} }, .press));
    const gp = getGamepadState(&state);
    try std.testing.expect(gp.left);
    try std.testing.expect(gp.a);
    try std.testing.expect(!gp.right);
}
