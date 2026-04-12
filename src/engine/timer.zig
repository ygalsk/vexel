const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;

const Allocator = std.mem.Allocator;

pub const TimerId = u32;

// --- Easing Functions ---

pub const EasingFn = *const fn (f64) f64;

pub fn easeLinear(t: f64) f64 {
    return t;
}

fn easeInQuad(t: f64) f64 {
    return t * t;
}

fn easeOutQuad(t: f64) f64 {
    return t * (2.0 - t);
}

fn easeInOutQuad(t: f64) f64 {
    if (t < 0.5) return 2.0 * t * t;
    return -1.0 + (4.0 - 2.0 * t) * t;
}

const easing_map = std.StaticStringMap(EasingFn).initComptime(.{
    .{ "linear", easeLinear },
    .{ "ease_in", easeInQuad },
    .{ "ease_out", easeOutQuad },
    .{ "ease_in_out", easeInOutQuad },
});

pub fn easingFromString(s: []const u8) EasingFn {
    return easing_map.get(s) orelse easeLinear;
}

// --- Timer ---

const Timer = struct {
    callback_ref: i32,
    remaining: f64,
    interval: ?f64, // null = one-shot, non-null = repeating
};

const TimerSlot = union(enum) {
    active: Timer,
    free: ?u32, // next free slot index
};

// --- Tween ---

pub const TweenProp = struct {
    field_name: [:0]const u8, // allocated
    start_val: f64,
    end_val: f64,
};

const Tween = struct {
    target_ref: i32,
    props: []TweenProp, // allocated
    duration: f64,
    elapsed: f64,
    easing: EasingFn,
    on_complete_ref: i32,
};

const TweenSlot = union(enum) {
    active: Tween,
    free: ?u32,
};

// --- TimerSystem ---

pub const TimerSystem = struct {
    allocator: Allocator,
    lua: *Lua,

    timer_slots: std.ArrayList(TimerSlot),
    timer_first_free: ?u32,

    tween_slots: std.ArrayList(TweenSlot),
    tween_first_free: ?u32,

    pub fn init(allocator: Allocator, lua: *Lua) TimerSystem {
        return .{
            .allocator = allocator,
            .lua = lua,
            .timer_slots = .{},
            .timer_first_free = null,
            .tween_slots = .{},
            .tween_first_free = null,
        };
    }

    pub fn deinit(self: *TimerSystem) void {
        for (self.timer_slots.items) |*slot| {
            switch (slot.*) {
                .active => |timer| {
                    self.lua.unref(zlua.registry_index, timer.callback_ref);
                },
                .free => {},
            }
        }
        self.timer_slots.deinit(self.allocator);

        for (self.tween_slots.items) |*slot| {
            switch (slot.*) {
                .active => |tween| {
                    self.lua.unref(zlua.registry_index, tween.target_ref);
                    if (tween.on_complete_ref != zlua.ref_no) {
                        self.lua.unref(zlua.registry_index, tween.on_complete_ref);
                    }
                    for (tween.props) |prop| {
                        self.allocator.free(prop.field_name);
                    }
                    self.allocator.free(tween.props);
                },
                .free => {},
            }
        }
        self.tween_slots.deinit(self.allocator);
    }

    // --- Timer API ---

    pub fn addTimer(self: *TimerSystem, callback_ref: i32, delay: f64, interval: ?f64) !TimerId {
        const timer = Timer{
            .callback_ref = callback_ref,
            .remaining = delay,
            .interval = interval,
        };

        if (self.timer_first_free) |free_idx| {
            const slot = &self.timer_slots.items[free_idx];
            self.timer_first_free = slot.free;
            slot.* = .{ .active = timer };
            return free_idx;
        }

        try self.timer_slots.append(self.allocator, .{ .active = timer });
        return @intCast(self.timer_slots.items.len - 1);
    }

    pub fn cancelTimer(self: *TimerSystem, id: TimerId) void {
        if (id >= self.timer_slots.items.len) return;
        const slot = &self.timer_slots.items[id];
        switch (slot.*) {
            .active => |timer| {
                self.lua.unref(zlua.registry_index, timer.callback_ref);
                slot.* = .{ .free = self.timer_first_free };
                self.timer_first_free = id;
            },
            .free => {},
        }
    }

    // --- Tween API ---

    pub fn addTween(self: *TimerSystem, target_ref: i32, props: []TweenProp, duration: f64, easing: EasingFn, on_complete_ref: i32) !TimerId {
        const tween = Tween{
            .target_ref = target_ref,
            .props = props,
            .duration = duration,
            .elapsed = 0,
            .easing = easing,
            .on_complete_ref = on_complete_ref,
        };

        if (self.tween_first_free) |free_idx| {
            const slot = &self.tween_slots.items[free_idx];
            self.tween_first_free = slot.free;
            slot.* = .{ .active = tween };
            return free_idx;
        }

        try self.tween_slots.append(self.allocator, .{ .active = tween });
        return @intCast(self.tween_slots.items.len - 1);
    }

    pub fn cancelTween(self: *TimerSystem, id: TimerId) void {
        if (id >= self.tween_slots.items.len) return;
        const slot = &self.tween_slots.items[id];
        switch (slot.*) {
            .active => |tween| {
                self.lua.unref(zlua.registry_index, tween.target_ref);
                if (tween.on_complete_ref != zlua.ref_no) {
                    self.lua.unref(zlua.registry_index, tween.on_complete_ref);
                }
                for (tween.props) |prop| {
                    self.allocator.free(prop.field_name);
                }
                self.allocator.free(tween.props);
                slot.* = .{ .free = self.tween_first_free };
                self.tween_first_free = id;
            },
            .free => {},
        }
    }

    // --- Tick (called each frame) ---

    pub fn tick(self: *TimerSystem, dt: f64) void {
        self.tickTimers(dt);
        self.tickTweens(dt);
    }

    fn tickTimers(self: *TimerSystem, dt: f64) void {
        for (self.timer_slots.items, 0..) |*slot, i| {
            switch (slot.*) {
                .active => |*timer| {
                    timer.remaining -= dt;
                    if (timer.remaining <= 0) {
                        // Fire callback
                        _ = self.lua.rawGetIndex(zlua.registry_index, timer.callback_ref);
                        self.lua.protectedCall(.{ .args = 0, .results = 0 }) catch {};

                        if (timer.interval) |interval| {
                            // Repeating: reset remaining (accumulate overshoot)
                            timer.remaining += interval;
                        } else {
                            // One-shot: free slot
                            self.lua.unref(zlua.registry_index, timer.callback_ref);
                            slot.* = .{ .free = self.timer_first_free };
                            self.timer_first_free = @intCast(i);
                        }
                    }
                },
                .free => {},
            }
        }
    }

    fn tickTweens(self: *TimerSystem, dt: f64) void {
        for (self.tween_slots.items, 0..) |*slot, i| {
            switch (slot.*) {
                .active => |*tween| {
                    tween.elapsed += dt;
                    const finished = tween.elapsed >= tween.duration;
                    const raw_t = if (finished) 1.0 else tween.elapsed / tween.duration;
                    const t = tween.easing(raw_t);

                    // Push target table
                    _ = self.lua.rawGetIndex(zlua.registry_index, tween.target_ref);

                    // Interpolate and write each property
                    for (tween.props) |prop| {
                        const val = prop.start_val + (prop.end_val - prop.start_val) * t;
                        self.lua.pushNumber(@floatCast(val));
                        self.lua.setField(-2, prop.field_name);
                    }

                    self.lua.pop(1); // pop target table

                    if (finished) {
                        // Fire on_complete if set
                        if (tween.on_complete_ref != zlua.ref_no) {
                            _ = self.lua.rawGetIndex(zlua.registry_index, tween.on_complete_ref);
                            self.lua.protectedCall(.{ .args = 0, .results = 0 }) catch {};
                            self.lua.unref(zlua.registry_index, tween.on_complete_ref);
                        }

                        // Free tween
                        self.lua.unref(zlua.registry_index, tween.target_ref);
                        for (tween.props) |prop| {
                            self.allocator.free(prop.field_name);
                        }
                        self.allocator.free(tween.props);
                        slot.* = .{ .free = self.tween_first_free };
                        self.tween_first_free = @intCast(i);
                    }
                },
                .free => {},
            }
        }
    }
};
