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

test "key translation" {
    const key = vaxis.Key{ .codepoint = 'a', .mods = .{} };
    const ev = translateKey(key, .press);
    try std.testing.expectEqualStrings("a", ev.name);
    try std.testing.expectEqual(KeyEvent.Action.press, ev.action);
}
