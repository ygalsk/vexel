const std = @import("std");
const zaudio = @import("zaudio");

const Allocator = std.mem.Allocator;

pub const SoundId = u32;

pub const LoadOpts = struct {
    stream: bool = false,
};

pub const PlayOpts = struct {
    loop: bool = false,
    volume: f32 = 1.0,
    pan: f32 = 0.0,
};

const SoundSlot = union(enum) {
    occupied: *zaudio.Sound,
    free: ?u32,
};

pub const AudioSystem = struct {
    engine: *zaudio.Engine,
    slots: std.ArrayList(SoundSlot),
    first_free: ?u32,
    allocator: Allocator,
    game_dir: []const u8,
    available: bool,

    pub fn init(allocator: Allocator, game_dir: []const u8) AudioSystem {
        zaudio.init(allocator);
        const engine = zaudio.Engine.create(zaudio.Engine.Config.init()) catch {
            return AudioSystem{
                .engine = undefined,
                .slots = .{},
                .first_free = null,
                .allocator = allocator,
                .game_dir = game_dir,
                .available = false,
            };
        };

        return AudioSystem{
            .engine = engine,
            .slots = .{},
            .first_free = null,
            .allocator = allocator,
            .game_dir = game_dir,
            .available = true,
        };
    }

    pub fn deinit(self: *AudioSystem) void {
        if (self.available) {
            for (self.slots.items) |*slot| {
                switch (slot.*) {
                    .occupied => |sound| sound.destroy(),
                    .free => {},
                }
            }
        }
        self.slots.deinit(self.allocator);
        if (self.available) {
            self.engine.destroy();
        }
        zaudio.deinit();
    }

    pub fn loadSound(self: *AudioSystem, path: [:0]const u8, opts: LoadOpts) !SoundId {
        if (!self.available) return error.AudioUnavailable;

        var flags = zaudio.Sound.Flags{};
        if (opts.stream) {
            flags.stream = true;
        }

        const sound = try self.engine.createSoundFromFile(path, .{ .flags = flags });

        if (self.first_free) |free_idx| {
            const slot = &self.slots.items[free_idx];
            self.first_free = switch (slot.*) {
                .free => |next| next,
                .occupied => unreachable,
            };
            slot.* = .{ .occupied = sound };
            return free_idx;
        } else {
            const id: u32 = @intCast(self.slots.items.len);
            try self.slots.append(self.allocator, .{ .occupied = sound });
            return id;
        }
    }

    pub fn unloadSound(self: *AudioSystem, id: SoundId) void {
        if (id >= self.slots.items.len) return;
        const slot = &self.slots.items[id];
        switch (slot.*) {
            .occupied => |sound| {
                sound.destroy();
                slot.* = .{ .free = self.first_free };
                self.first_free = id;
            },
            .free => {},
        }
    }

    fn getSound(self: *AudioSystem, id: SoundId) ?*zaudio.Sound {
        if (!self.available) return null;
        if (id >= self.slots.items.len) return null;
        return switch (self.slots.items[id]) {
            .occupied => |sound| sound,
            .free => null,
        };
    }

    pub fn play(self: *AudioSystem, id: SoundId, opts: PlayOpts) void {
        const sound = self.getSound(id) orelse return;
        sound.setVolume(opts.volume);
        sound.setPan(opts.pan);
        sound.setLooping(opts.loop);
        sound.start() catch {};
    }

    pub fn stop(self: *AudioSystem, id: SoundId) void {
        const sound = self.getSound(id) orelse return;
        sound.stop() catch {};
    }

    pub fn pause(self: *AudioSystem, id: SoundId) void {
        const sound = self.getSound(id) orelse return;
        sound.stop() catch {};
    }

    pub fn resume_(self: *AudioSystem, id: SoundId) void {
        const sound = self.getSound(id) orelse return;
        sound.start() catch {};
    }

    pub fn setVolume(self: *AudioSystem, id: SoundId, volume: f32) void {
        const sound = self.getSound(id) orelse return;
        sound.setVolume(volume);
    }

    pub fn setPan(self: *AudioSystem, id: SoundId, pan: f32) void {
        const sound = self.getSound(id) orelse return;
        sound.setPan(pan);
    }

    pub fn fadeIn(self: *AudioSystem, id: SoundId, duration_ms: u32) void {
        const sound = self.getSound(id) orelse return;
        const target = sound.getVolume();
        sound.setVolume(0);
        sound.setFadeInMilliseconds(0, target, duration_ms);
        sound.start() catch {};
    }

    pub fn fadeOut(self: *AudioSystem, id: SoundId, duration_ms: u32) void {
        const sound = self.getSound(id) orelse return;
        const current = sound.getVolume();
        sound.setFadeInMilliseconds(current, 0, duration_ms);
    }

    pub fn setMasterVolume(self: *AudioSystem, volume: f32) void {
        if (!self.available) return;
        self.engine.setVolume(volume) catch {};
    }

    pub fn stopAll(self: *AudioSystem) void {
        if (!self.available) return;
        for (self.slots.items) |slot| {
            switch (slot) {
                .occupied => |sound| sound.stop() catch {},
                .free => {},
            }
        }
    }

    pub fn resolvePath(self: *AudioSystem, rel_path: []const u8) ![:0]const u8 {
        if (rel_path.len > 0 and rel_path[0] == '/') {
            return try self.allocator.dupeZ(u8, rel_path);
        }
        const dir_len = self.game_dir.len;
        const needs_sep = dir_len > 0 and self.game_dir[dir_len - 1] != '/';
        const sep: []const u8 = if (needs_sep) "/" else "";
        // allocPrint with \x00 to get null-terminated string, matching project convention
        const full = try std.fmt.allocPrint(self.allocator, "{s}{s}{s}\x00", .{ self.game_dir, sep, rel_path });
        return full[0 .. full.len - 1 :0];
    }
};
