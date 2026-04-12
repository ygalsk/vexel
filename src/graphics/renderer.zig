const std = @import("std");
const vaxis = @import("vaxis");
const Kitty = @import("kitty");
const Compositing = @import("compositing");
const ImageMod = @import("image");
const SpritePlacer = @import("sprite_placer");

const Renderer = @This();

/// Color as RGBA 0-255 — canonical definition lives in compositing.zig
pub const Color = Compositing.Color;
pub const ImageHandle = ImageMod.ImageHandle;
pub const ImageManager = ImageMod;

pub fn colorToVaxis(c: Color) vaxis.Cell.Color {
    return .{ .rgb = .{ c.r, c.g, c.b } };
}

/// Screen dimensions in terminal cells
pub const ScreenInfo = struct {
    cols: u16,
    rows: u16,
    x_pixel: u16,
    y_pixel: u16,

    /// Pixel width of one cell
    pub fn cellWidth(self: ScreenInfo) u16 {
        if (self.cols == 0) return 8;
        return self.x_pixel / self.cols;
    }

    /// Pixel height of one cell
    pub fn cellHeight(self: ScreenInfo) u16 {
        if (self.rows == 0) return 16;
        return self.y_pixel / self.rows;
    }
};

pub const PixelMode = struct {
    allocator: std.mem.Allocator,
    kitty_backend: *Kitty,
    compositor: *Compositing,
    sprite_placer: *SpritePlacer,
    image_manager: ?*ImageManager = null,

    pub fn deinit(self: *PixelMode) void {
        self.sprite_placer.deinit();
        self.allocator.destroy(self.sprite_placer);
        self.compositor.deinit();
        self.allocator.destroy(self.compositor);
        self.kitty_backend.deinit();
        self.allocator.destroy(self.kitty_backend);
    }
};

pub const SpriteMode = enum { compositor, placer };

vx: *vaxis.Vaxis,
screen_info: ScreenInfo,
pixel_mode: ?PixelMode = null,
sprite_mode: SpriteMode = .compositor,

pub fn init(vx: *vaxis.Vaxis, winsize: vaxis.Winsize) Renderer {
    return .{
        .vx = vx,
        .screen_info = .{
            .cols = winsize.cols,
            .rows = winsize.rows,
            .x_pixel = winsize.x_pixel,
            .y_pixel = winsize.y_pixel,
        },
    };
}

pub fn initPixelMode(self: *Renderer, allocator: std.mem.Allocator, writer: *std.io.Writer) !void {
    const kitty = try allocator.create(Kitty);
    kitty.* = try Kitty.init(allocator, self.vx, writer);

    const comp = try allocator.create(Compositing);
    comp.* = try Compositing.init(allocator, kitty, self.vx);

    const placer = try allocator.create(SpritePlacer);
    placer.* = SpritePlacer.init(allocator);

    self.pixel_mode = .{
        .allocator = allocator,
        .kitty_backend = kitty,
        .compositor = comp,
        .sprite_placer = placer,
    };
}

pub fn deinitPixelMode(self: *Renderer) void {
    if (self.pixel_mode) |*pm| {
        pm.deinit();
        self.pixel_mode = null;
    }
}

pub fn flushPixels(self: *Renderer) !void {
    const pm = self.pixel_mode orelse return;
    try pm.compositor.flush();
    pm.sprite_placer.flush(self.vx);
}

pub fn clearSprites(self: *Renderer) void {
    const pm = self.pixel_mode orelse return;
    pm.sprite_placer.clear();
}

pub fn markAllPixelsDirty(self: *Renderer) void {
    const pm = self.pixel_mode orelse return;
    pm.compositor.markAllDirty();
}

/// Handle terminal resize: mark compositor dirty and invalidate sprite caches.
pub fn onResize(self: *Renderer) void {
    self.markAllPixelsDirty();
    self.invalidateAllTerminalImages();
}

/// Invalidate all cached terminal images (upscale factor is stale after resize).
/// Frees kitty-side images and clears cached data so sprites re-upload at correct scale.
fn invalidateAllTerminalImages(self: *Renderer) void {
    const pm = self.pixel_mode orelse return;
    const mgr = pm.image_manager orelse return;
    for (0..mgr.slots.items.len) |i| {
        const handle: ImageMod.ImageHandle = @intCast(i);
        const ids = mgr.freeTerminalData(handle);
        for (ids) |maybe_id| {
            if (maybe_id) |id| pm.kitty_backend.freeImage(id);
        }
    }
}

pub fn pixelDrawRect(self: *Renderer, x: i32, y: i32, w: i32, h: i32, color: Color) void {
    const pm = self.pixel_mode orelse return;
    pm.compositor.drawRect(x, y, w, h, color);
}

pub fn pixelDrawLine(self: *Renderer, x1: i32, y1: i32, x2: i32, y2: i32, color: Color) void {
    const pm = self.pixel_mode orelse return;
    pm.compositor.drawLine(x1, y1, x2, y2, color);
}

pub fn pixelDrawCircle(self: *Renderer, cx: i32, cy: i32, r: i32, color: Color) void {
    const pm = self.pixel_mode orelse return;
    pm.compositor.drawCircle(cx, cy, r, color);
}

pub fn pixelClearLayer(self: *Renderer) void {
    const pm = self.pixel_mode orelse return;
    pm.compositor.clearLayer();
}

pub fn pixelClearAll(self: *Renderer) void {
    const pm = self.pixel_mode orelse return;
    pm.compositor.clearAll();
}

pub fn pixelSetResolution(self: *Renderer, w: u16, h: u16) !void {
    const pm = self.pixel_mode orelse return;
    try pm.compositor.setResolution(w, h);
}

pub fn pixelGetResolution(self: *const Renderer) struct { w: u16, h: u16 } {
    const pm = self.pixel_mode orelse return .{ .w = 0, .h = 0 };
    return .{ .w = pm.compositor.width, .h = pm.compositor.height };
}

pub fn pixelSetLayer(self: *Renderer, layer: u8) void {
    const pm = self.pixel_mode orelse return;
    pm.compositor.setActiveLayer(layer);
}

pub fn setImageManager(self: *Renderer, mgr: *ImageManager) void {
    if (self.pixel_mode) |*pm| {
        pm.image_manager = mgr;
    }
}

pub fn loadImage(self: *Renderer, path: []const u8) !ImageHandle {
    const pm = self.pixel_mode orelse return error.NoImageManager;
    const mgr = pm.image_manager orelse return error.NoImageManager;
    const handle = try mgr.loadImage(path);
    self.uploadVariant(handle, .none);
    return handle;
}

pub fn loadSpriteSheet(self: *Renderer, path: []const u8, tile_w: u16, tile_h: u16) !ImageHandle {
    const pm = self.pixel_mode orelse return error.NoImageManager;
    const mgr = pm.image_manager orelse return error.NoImageManager;
    const handle = try mgr.loadSpriteSheet(path, tile_w, tile_h);
    self.uploadVariant(handle, .none);
    return handle;
}

pub fn unloadImage(self: *Renderer, handle: ImageHandle) void {
    const pm = self.pixel_mode orelse return;
    const mgr = pm.image_manager orelse return;
    // Free all terminal-side images for this handle
    const ids = mgr.freeTerminalData(handle);
    for (ids) |maybe_id| {
        if (maybe_id) |id| pm.kitty_backend.freeImage(id);
    }
    mgr.unloadImage(handle);
}

pub const DrawSpriteOpts = struct {
    frame: ?u32 = null,
    flip_x: bool = false,
    flip_y: bool = false,
    scale: u8 = 1,
};

pub fn drawSprite(self: *Renderer, handle: ImageHandle, x: i32, y: i32, opts: DrawSpriteOpts) void {
    const pm = self.pixel_mode orelse return;
    const mgr = pm.image_manager orelse return;

    const frame_idx = opts.frame orelse 0;
    const src_rect = mgr.getFrameRect(handle, frame_idx) orelse return;

    if (self.sprite_mode == .compositor) {
        // Static mode: blit to compositor layer (persists until cleared)
        const info = mgr.getImageInfo(handle) orelse return;
        pm.compositor.blitImage(
            info.pixels,
            info.width,
            info.height,
            src_rect,
            x,
            y,
            opts.flip_x,
            opts.flip_y,
            opts.scale,
        );
        return;
    }

    // Placer mode: render via terminal with pre-scaled sprites
    const variant: ImageMod.FlipVariant = @enumFromInt(
        @as(u2, @intFromBool(opts.flip_x)) | (@as(u2, @intFromBool(opts.flip_y)) << 1),
    );

    var term_img = mgr.getTerminalImage(handle, variant);
    if (term_img == null) {
        self.uploadVariant(handle, variant);
        term_img = mgr.getTerminalImage(handle, variant);
    }
    const ti = term_img orelse return;

    const si = self.screen_info;
    const virt_w: u32 = pm.compositor.width;
    const virt_h: u32 = pm.compositor.height;
    const term_w: u32 = si.x_pixel;
    const term_h: u32 = si.y_pixel;
    const cw: u32 = si.cellWidth();
    const ch: u32 = si.cellHeight();
    if (cw == 0 or ch == 0 or virt_w == 0 or virt_h == 0) return;

    // The uploaded image is pre-scaled by an integer factor (nearest-neighbor).
    // Derive that factor from the terminal image vs original image dimensions.
    const info = mgr.getImageInfo(handle) orelse return;
    const upscale: u32 = if (info.width > 0) @as(u32, ti.width) / info.width else 1;

    // Apply Lua-side scale parameter
    const s: u32 = @max(1, opts.scale);
    const frame_vw: i32 = @intCast(@as(u32, src_rect.w) * s);
    const frame_vh: i32 = @intCast(@as(u32, src_rect.h) * s);

    // Cull fully off-screen sprites in virtual coordinates
    if (x + frame_vw <= 0 or y + frame_vh <= 0) return;
    if (x >= @as(i32, @intCast(virt_w)) or y >= @as(i32, @intCast(virt_h))) return;

    // Map virtual pixel position to terminal pixel position
    const tx = @divTrunc(x * @as(i32, @intCast(term_w)), @as(i32, @intCast(virt_w)));
    const ty = @divTrunc(y * @as(i32, @intCast(term_h)), @as(i32, @intCast(virt_h)));
    if (tx < 0 or ty < 0) return;

    // Clip region in the pre-scaled image (scale up frame rect by upscale factor)
    const clip_x: u16 = @intCast(src_rect.x * upscale);
    const clip_y: u16 = @intCast(src_rect.y * upscale);
    const clip_w: u16 = @intCast(src_rect.w * upscale);
    const clip_h: u16 = @intCast(src_rect.h * upscale);

    // Display size in terminal pixels — use the exact virtual-to-terminal mapping
    // to match the compositor's .fill scaling
    const display_w: u32 = @intCast(@divTrunc(@as(i64, frame_vw) * @as(i64, term_w), @as(i64, virt_w)));
    const display_h: u32 = @intCast(@divTrunc(@as(i64, frame_vh) * @as(i64, term_h), @as(i64, virt_h)));
    if (display_w == 0 or display_h == 0) return;

    const px: u32 = @intCast(tx);
    const py: u32 = @intCast(ty);
    const col: u16 = @intCast(@min(px / cw, si.cols -| 1));
    const row: u16 = @intCast(@min(py / ch, si.rows -| 1));
    const off_x: u16 = @intCast(px % cw);
    const off_y: u16 = @intCast(py % ch);

    const span_cols: u16 = @intCast(@min((@as(u32, off_x) + display_w + cw - 1) / cw, si.cols - col));
    const span_rows: u16 = @intCast(@min((@as(u32, off_y) + display_h + ch - 1) / ch, si.rows - row));

    const active_layer: i32 = pm.compositor.getActiveLayer();
    const z_index: i32 = active_layer - 8;

    pm.sprite_placer.addPlacement(.{
        .terminal_image_id = ti.id,
        .clip_x = clip_x,
        .clip_y = clip_y,
        .clip_w = clip_w,
        .clip_h = clip_h,
        .col = col,
        .row = row,
        .pixel_offset_x = off_x,
        .pixel_offset_y = off_y,
        .span_cols = span_cols,
        .span_rows = span_rows,
        .z_index = z_index,
    }) catch {};
}

/// Calculate the integer scale factor to match virtual resolution → terminal pixels.
fn getSpriteUpscale(self: *const Renderer) u16 {
    const pm = self.pixel_mode orelse return 1;
    const virt_w: u32 = pm.compositor.width;
    const virt_h: u32 = pm.compositor.height;
    if (virt_w == 0 or virt_h == 0) return 1;
    const si = self.screen_info;
    const sx: u16 = @intCast(@as(u32, si.x_pixel) / virt_w);
    const sy: u16 = @intCast(@as(u32, si.y_pixel) / virt_h);
    return @max(1, @min(sx, sy));
}

/// Upload a flip variant of an image to the terminal, pre-scaled for crisp rendering.
fn uploadVariant(self: *Renderer, handle: ImageHandle, variant: ImageMod.FlipVariant) void {
    const pm = self.pixel_mode orelse return;
    const mgr = pm.image_manager orelse return;
    const kitty = pm.kitty_backend;

    if (mgr.getTerminalImage(handle, variant) != null) return;

    const pixels = mgr.getFlippedPixels(handle, variant) orelse return;
    const info = mgr.getImageInfo(handle) orelse return;

    const scale: u32 = self.getSpriteUpscale();

    if (scale <= 1) {
        // No scaling needed — upload at native resolution
        const img = kitty.uploadRgba(pixels, @intCast(info.width), @intCast(info.height)) catch return;
        mgr.setTerminalImage(handle, variant, .{
            .id = img.id,
            .width = @intCast(info.width),
            .height = @intCast(info.height),
        });
        return;
    }

    // Pre-scale using nearest-neighbor for crisp pixel art
    const new_w: u32 = info.width * scale;
    const new_h: u32 = info.height * scale;
    const byte_count = @as(usize, new_w) * @as(usize, new_h) * 4;
    const scaled = pm.allocator.alloc(u8, byte_count) catch return;
    defer pm.allocator.free(scaled);

    const ow: usize = @intCast(info.width);
    for (0..@as(usize, new_h)) |dy| {
        const sy = dy / scale;
        const src_row = sy * ow * 4;
        const dst_row = dy * @as(usize, new_w) * 4;
        for (0..@as(usize, new_w)) |dx| {
            const sx = dx / scale;
            @memcpy(scaled[dst_row + dx * 4 ..][0..4], pixels[src_row + sx * 4 ..][0..4]);
        }
    }

    const img = kitty.uploadRgba(scaled, @intCast(new_w), @intCast(new_h)) catch return;
    mgr.setTerminalImage(handle, variant, .{
        .id = img.id,
        .width = @intCast(new_w),
        .height = @intCast(new_h),
    });
}

pub fn getFrameCount(self: *const Renderer, handle: ImageHandle) u32 {
    const pm = self.pixel_mode orelse return 0;
    const mgr = pm.image_manager orelse return 0;
    return mgr.getFrameCount(handle);
}

pub fn updateSize(self: *Renderer, winsize: vaxis.Winsize) void {
    self.screen_info = .{
        .cols = winsize.cols,
        .rows = winsize.rows,
        .x_pixel = winsize.x_pixel,
        .y_pixel = winsize.y_pixel,
    };
}

/// Draw text at a cell position
pub fn drawText(self: *Renderer, col: u16, row: u16, text: []const u8, fg: ?Color, bg: ?Color) void {
    const win = self.vx.window();
    const style: vaxis.Cell.Style = .{
        .fg = if (fg) |c| colorToVaxis(c) else .default,
        .bg = if (bg) |c| colorToVaxis(c) else .default,
    };

    _ = win.print(&.{.{ .text = text, .style = style }}, .{
        .row_offset = row,
        .col_offset = col,
        .wrap = .none,
    });
}

/// Fill a rectangle with a solid color (cell coordinates)
pub fn drawRect(self: *Renderer, col: u16, row: u16, w: u16, h: u16, color: Color) void {
    const win = self.vx.window();
    const style: vaxis.Cell.Style = .{
        .bg = colorToVaxis(color),
    };

    var y: u16 = row;
    while (y < row +| h and y < win.height) : (y += 1) {
        var x: u16 = col;
        while (x < col +| w and x < win.width) : (x += 1) {
            win.writeCell(x, y, .{
                .char = .{ .grapheme = " ", .width = 1 },
                .style = style,
            });
        }
    }
}

/// Clear the screen
pub fn clear(self: *Renderer) void {
    self.vx.window().clear();
}

/// Get screen dimensions
pub fn getScreenInfo(self: *const Renderer) ScreenInfo {
    return self.screen_info;
}

