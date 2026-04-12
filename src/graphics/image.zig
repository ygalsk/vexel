const std = @import("std");
const zigimg = @import("zigimg");

const ImageManager = @This();

pub const ImageHandle = u32;

pub const Rect = struct {
    x: u32,
    y: u32,
    w: u32,
    h: u32,
};

/// Terminal-side image (uploaded via kitty graphics protocol).
pub const TerminalImage = struct {
    id: u32,
    width: u16,
    height: u16,
};

/// Flip variant for terminal image caching.
pub const FlipVariant = enum(u2) {
    none = 0,
    flip_x = 1,
    flip_y = 2,
    flip_both = 3,
};

const Image = struct {
    pixels: []u8,
    width: u32,
    height: u32,
    tile_w: u16,
    tile_h: u16,
    frame_cols: u16,
    frame_rows: u16,
    ref_count: u16,
    path_key: []const u8,
    // Terminal-side images (uploaded to kitty), indexed by FlipVariant
    terminal_images: [4]?TerminalImage = .{ null, null, null, null },
    // Lazily-allocated flipped pixel buffers (indices: 0=flip_x, 1=flip_y, 2=flip_both)
    flipped_pixels: [3]?[]u8 = .{ null, null, null },
};

const Slot = union(enum) {
    occupied: Image,
    free: ?u32, // next free index (linked list)
};

allocator: std.mem.Allocator,
game_dir: []const u8,
slots: std.ArrayList(Slot),
first_free: ?u32,
path_cache: std.StringHashMap(ImageHandle),

pub fn init(allocator: std.mem.Allocator, game_dir: []const u8) ImageManager {
    return .{
        .allocator = allocator,
        .game_dir = game_dir,
        .slots = .{},
        .first_free = null,
        .path_cache = std.StringHashMap(ImageHandle).init(allocator),
    };
}

pub fn deinit(self: *ImageManager) void {
    for (self.slots.items) |*slot| {
        switch (slot.*) {
            .occupied => |*img| self.freeImageData(img),
            .free => {},
        }
    }
    self.slots.deinit(self.allocator);
    self.path_cache.deinit();
}

pub fn loadImage(self: *ImageManager, path: []const u8) !ImageHandle {
    return self.loadInternal(path, 0, 0);
}

pub fn loadSpriteSheet(self: *ImageManager, path: []const u8, tile_w: u16, tile_h: u16) !ImageHandle {
    return self.loadInternal(path, tile_w, tile_h);
}

fn loadInternal(self: *ImageManager, path: []const u8, tile_w: u16, tile_h: u16) !ImageHandle {
    // Check cache — but only reuse if tile dimensions match
    if (self.path_cache.get(path)) |existing| {
        const slot = &self.slots.items[existing];
        switch (slot.*) {
            .occupied => |*img| {
                if (img.tile_w == tile_w and img.tile_h == tile_h) {
                    img.ref_count += 1;
                    return existing;
                }
            },
            .free => {
                // Stale cache entry — remove it
                _ = self.path_cache.remove(path);
            },
        }
    }

    // Resolve path relative to game directory
    const full_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ self.game_dir, path });
    defer self.allocator.free(full_path);

    // Load via zigimg
    var read_buf: [8192]u8 = undefined;
    var image = zigimg.Image.fromFilePath(self.allocator, full_path, &read_buf) catch {
        return error.ImageLoadFailed;
    };
    defer image.deinit(self.allocator);

    // Convert to RGBA32
    image.convert(self.allocator, .rgba32) catch {
        return error.ImageConvertFailed;
    };

    // Copy pixel data to our own buffer
    const w: u32 = @intCast(image.width);
    const h: u32 = @intCast(image.height);
    const byte_count = @as(usize, w) * @as(usize, h) * 4;
    const raw = image.rawBytes();
    if (raw.len < byte_count) return error.ImageDataTooSmall;

    const pixels = try self.allocator.alloc(u8, byte_count);
    @memcpy(pixels, raw[0..byte_count]);

    // Calculate frame grid for sprite sheets
    var frame_cols: u16 = 1;
    var frame_rows: u16 = 1;
    if (tile_w > 0 and tile_h > 0) {
        frame_cols = @intCast(w / @as(u32, tile_w));
        frame_rows = @intCast(h / @as(u32, tile_h));
        if (frame_cols == 0) frame_cols = 1;
        if (frame_rows == 0) frame_rows = 1;
    }

    // Allocate path key for cache
    const path_key = try self.allocator.dupe(u8, path);

    const img = Image{
        .pixels = pixels,
        .width = w,
        .height = h,
        .tile_w = tile_w,
        .tile_h = tile_h,
        .frame_cols = frame_cols,
        .frame_rows = frame_rows,
        .ref_count = 1,
        .path_key = path_key,
    };

    // Allocate a slot
    const handle = try self.allocSlot(img);

    // Cache it (path_key is owned by the image, safe for hashmap key)
    try self.path_cache.put(path_key, handle);

    return handle;
}

pub fn unloadImage(self: *ImageManager, handle: ImageHandle) void {
    const img = self.getOccupied(handle) orelse return;
    if (img.ref_count > 1) {
        img.ref_count -= 1;
        return;
    }
    _ = self.path_cache.remove(img.path_key);
    self.freeImageData(img);
    self.slots.items[handle] = .{ .free = self.first_free };
    self.first_free = handle;
}

pub const ImageInfo = struct {
    pixels: []const u8,
    width: u32,
    height: u32,
};

pub fn getImageInfo(self: *const ImageManager, handle: ImageHandle) ?ImageInfo {
    const img = self.getOccupiedConst(handle) orelse return null;
    return ImageInfo{
        .pixels = img.pixels,
        .width = img.width,
        .height = img.height,
    };
}

pub fn getFrameRect(self: *const ImageManager, handle: ImageHandle, frame_index: u32) ?Rect {
    const img = self.getOccupiedConst(handle) orelse return null;
    if (img.tile_w == 0 or img.tile_h == 0) {
        return Rect{ .x = 0, .y = 0, .w = img.width, .h = img.height };
    }
    const total_frames = @as(u32, img.frame_cols) * @as(u32, img.frame_rows);
    const idx = if (frame_index >= total_frames) total_frames - 1 else frame_index;
    const col = idx % img.frame_cols;
    const row = idx / img.frame_cols;
    return Rect{
        .x = @as(u32, col) * @as(u32, img.tile_w),
        .y = @as(u32, row) * @as(u32, img.tile_h),
        .w = @as(u32, img.tile_w),
        .h = @as(u32, img.tile_h),
    };
}

pub fn getFrameCount(self: *const ImageManager, handle: ImageHandle) u32 {
    const img = self.getOccupiedConst(handle) orelse return 0;
    if (img.tile_w == 0 or img.tile_h == 0) return 1;
    return @as(u32, img.frame_cols) * @as(u32, img.frame_rows);
}

// --- Terminal image management ---

pub fn getTerminalImage(self: *const ImageManager, handle: ImageHandle, variant: FlipVariant) ?TerminalImage {
    const img = self.getOccupiedConst(handle) orelse return null;
    return img.terminal_images[@intFromEnum(variant)];
}

/// Cache a terminal-side image for a flip variant.
pub fn setTerminalImage(self: *ImageManager, handle: ImageHandle, variant: FlipVariant, ti: TerminalImage) void {
    const img = self.getOccupied(handle) orelse return;
    img.terminal_images[@intFromEnum(variant)] = ti;
}

pub fn getAllTerminalIds(self: *const ImageManager, handle: ImageHandle) [4]?u32 {
    const img = self.getOccupiedConst(handle) orelse return .{ null, null, null, null };
    return .{
        if (img.terminal_images[0]) |ti| ti.id else null,
        if (img.terminal_images[1]) |ti| ti.id else null,
        if (img.terminal_images[2]) |ti| ti.id else null,
        if (img.terminal_images[3]) |ti| ti.id else null,
    };
}

/// Generate (or return cached) flipped pixel data for a variant.
pub fn getFlippedPixels(self: *ImageManager, handle: ImageHandle, variant: FlipVariant) ?[]const u8 {
    if (variant == .none) {
        const info = self.getImageInfo(handle) orelse return null;
        return info.pixels;
    }
    const img = self.getOccupied(handle) orelse return null;
    const idx: usize = @intFromEnum(variant) - 1;
    if (img.flipped_pixels[idx]) |cached| return cached;

    const byte_count = @as(usize, img.width) * @as(usize, img.height) * 4;
    const buf = self.allocator.alloc(u8, byte_count) catch return null;
    const w: usize = @intCast(img.width);
    const h: usize = @intCast(img.height);
    const src = img.pixels;

    switch (variant) {
        .flip_x => {
            for (0..h) |y| {
                for (0..w) |x| {
                    const src_off = (y * w + x) * 4;
                    const dst_off = (y * w + (w - 1 - x)) * 4;
                    @memcpy(buf[dst_off..][0..4], src[src_off..][0..4]);
                }
            }
        },
        .flip_y => {
            for (0..h) |y| {
                const src_row = y * w * 4;
                const dst_row = (h - 1 - y) * w * 4;
                @memcpy(buf[dst_row..][0 .. w * 4], src[src_row..][0 .. w * 4]);
            }
        },
        .flip_both => {
            for (0..h) |y| {
                for (0..w) |x| {
                    const src_off = (y * w + x) * 4;
                    const dst_off = ((h - 1 - y) * w + (w - 1 - x)) * 4;
                    @memcpy(buf[dst_off..][0..4], src[src_off..][0..4]);
                }
            }
        },
        .none => unreachable,
    }

    img.flipped_pixels[idx] = buf;
    return buf;
}

/// Free terminal-side data for an image (flipped pixel buffers + clear terminal IDs).
/// Returns the terminal IDs that were active so caller can call kitty.freeImage on each.
pub fn freeTerminalData(self: *ImageManager, handle: ImageHandle) [4]?u32 {
    const ids = self.getAllTerminalIds(handle);
    const img = self.getOccupied(handle) orelse return ids;
    img.terminal_images = .{ null, null, null, null };
    for (&img.flipped_pixels) |*fp| {
        if (fp.*) |buf| {
            self.allocator.free(buf);
            fp.* = null;
        }
    }
    return ids;
}

// --- Internal ---

fn getOccupied(self: *ImageManager, handle: ImageHandle) ?*Image {
    if (handle >= self.slots.items.len) return null;
    return switch (self.slots.items[handle]) {
        .occupied => |*img| img,
        .free => null,
    };
}

fn getOccupiedConst(self: *const ImageManager, handle: ImageHandle) ?*const Image {
    if (handle >= self.slots.items.len) return null;
    return switch (self.slots.items[handle]) {
        .occupied => |*img| img,
        .free => null,
    };
}

fn freeImageData(self: *ImageManager, img: *Image) void {
    self.allocator.free(img.pixels);
    self.allocator.free(img.path_key);
    for (&img.flipped_pixels) |*fp| {
        if (fp.*) |buf| self.allocator.free(buf);
    }
}

fn allocSlot(self: *ImageManager, img: Image) !ImageHandle {
    if (self.first_free) |free_idx| {
        const slot = &self.slots.items[free_idx];
        self.first_free = switch (slot.*) {
            .free => |next| next,
            .occupied => unreachable,
        };
        slot.* = .{ .occupied = img };
        return free_idx;
    }
    // No free slots — append
    try self.slots.append(self.allocator, .{ .occupied = img });
    return @intCast(self.slots.items.len - 1);
}

// --- Tests ---

test "Rect frame calculation" {
    // Simulate a 64x32 sprite sheet with 16x16 tiles → 4 cols, 2 rows = 8 frames
    const tile_w: u16 = 16;
    const tile_h: u16 = 16;
    const img_w: u32 = 64;
    const frame_cols: u16 = @intCast(img_w / @as(u32, tile_w)); // 4

    // Frame 0 → (0, 0)
    const col0 = @as(u32, 0) % frame_cols;
    const row0 = @as(u32, 0) / frame_cols;
    try std.testing.expectEqual(@as(u32, 0), col0 * tile_w);
    try std.testing.expectEqual(@as(u32, 0), row0 * tile_h);

    // Frame 3 → (48, 0)
    const col3 = @as(u32, 3) % frame_cols;
    const row3 = @as(u32, 3) / frame_cols;
    try std.testing.expectEqual(@as(u32, 48), col3 * tile_w);
    try std.testing.expectEqual(@as(u32, 0), row3 * tile_h);

    // Frame 5 → (16, 16) — second row, second col
    const col5 = @as(u32, 5) % frame_cols;
    const row5 = @as(u32, 5) / frame_cols;
    try std.testing.expectEqual(@as(u32, 16), col5 * tile_w);
    try std.testing.expectEqual(@as(u32, 16), row5 * tile_h);
}
