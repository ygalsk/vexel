const std = @import("std");
const vaxis = @import("vaxis");
const Kitty = @import("kitty");
const ImageMod = @import("image");

pub const MAX_LAYERS: u8 = 8;
pub const DEFAULT_WIDTH: u16 = 320;
pub const DEFAULT_HEIGHT: u16 = 180;

pub const Rect = ImageMod.Rect;

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    pub fn fromHex(hex: u32) Color {
        return .{
            .r = @truncate(hex >> 16),
            .g = @truncate(hex >> 8),
            .b = @truncate(hex),
            .a = 255,
        };
    }

    /// Pack color into a pixel buffer at the given offset.
    pub inline fn write(color: Color, pixels: []u8, offset: usize) void {
        pixels[offset] = color.r;
        pixels[offset + 1] = color.g;
        pixels[offset + 2] = color.b;
        pixels[offset + 3] = color.a;
    }

    /// Pack RGBA into a u32 in memory-layout order (R at byte 0).
    pub inline fn pack(color: Color) u32 {
        return @as(u32, color.r) |
            (@as(u32, color.g) << 8) |
            (@as(u32, color.b) << 16) |
            (@as(u32, color.a) << 24);
    }
};

const Layer = struct {
    pixels: []u8,
    dirty: bool,
    has_content: bool,
    visible: bool,
};

const Compositor = @This();

allocator: std.mem.Allocator,
kitty: *Kitty,
vx: *vaxis.Vaxis,
layers: [MAX_LAYERS]Layer,
width: u16,
height: u16,
active_layer: u8,
composite_buf: []u8,
composite_image: ?vaxis.Image,
pending_free_id: ?u32,
any_dirty: bool,

pub fn init(allocator: std.mem.Allocator, kitty: *Kitty, vx: *vaxis.Vaxis) !Compositor {
    const buf_size = @as(usize, DEFAULT_WIDTH) * @as(usize, DEFAULT_HEIGHT) * 4;

    var comp: Compositor = .{
        .allocator = allocator,
        .kitty = kitty,
        .vx = vx,
        .layers = undefined,
        .width = DEFAULT_WIDTH,
        .height = DEFAULT_HEIGHT,
        .active_layer = 0,
        .composite_buf = try allocator.alloc(u8, buf_size),
        .composite_image = null,
        .pending_free_id = null,
        .any_dirty = false,
    };
    @memset(comp.composite_buf, 0);

    for (&comp.layers) |*layer| {
        layer.pixels = try allocator.alloc(u8, buf_size);
        @memset(layer.pixels, 0);
        layer.dirty = false;
        layer.has_content = false;
        layer.visible = true;
    }

    return comp;
}

pub fn deinit(self: *Compositor) void {
    self.freeAllImages();
    for (&self.layers) |*layer| {
        self.allocator.free(layer.pixels);
    }
    self.allocator.free(self.composite_buf);
}

/// Change the logical pixel resolution. Reallocates all layer buffers.
pub fn setResolution(self: *Compositor, w: u16, h: u16) !void {
    if (w == self.width and h == self.height) return;

    const buf_size = @as(usize, w) * @as(usize, h) * 4;
    for (&self.layers) |*layer| {
        self.allocator.free(layer.pixels);
        layer.pixels = try self.allocator.alloc(u8, buf_size);
        @memset(layer.pixels, 0);
        layer.dirty = true;
        layer.has_content = false;
    }
    self.allocator.free(self.composite_buf);
    self.composite_buf = try self.allocator.alloc(u8, buf_size);
    @memset(self.composite_buf, 0);
    if (self.pending_free_id) |old_id| {
        self.kitty.freeImage(old_id);
        self.pending_free_id = null;
    }
    if (self.composite_image) |img| {
        self.kitty.freeImage(img.id);
        self.composite_image = null;
    }
    self.width = w;
    self.height = h;
    self.any_dirty = true;
}

/// Set which layer subsequent draw calls target.
pub fn setActiveLayer(self: *Compositor, layer: u8) void {
    self.active_layer = if (layer >= MAX_LAYERS) MAX_LAYERS - 1 else layer;
}

pub fn getActiveLayer(self: *const Compositor) u8 {
    return self.active_layer;
}

pub fn setPixel(self: *Compositor, x: i32, y: i32, color: Color) void {
    if (x < 0 or y < 0) return;
    const ux: usize = @intCast(x);
    const uy: usize = @intCast(y);
    if (ux >= self.width or uy >= self.height) return;

    const layer = &self.layers[self.active_layer];
    const offset = (uy * @as(usize, self.width) + ux) * 4;
    color.write(layer.pixels, offset);
    self.markLayerDirty(layer);
}

/// Blit a flat array of packed u32 RGBA colors onto the active layer at (x, y).
/// The colors slice must have exactly w * h entries (row-major).
pub fn blitBuffer(self: *Compositor, x: i32, y: i32, w: i32, h: i32, colors: []const u32) void {
    if (w <= 0 or h <= 0) return;

    // Clip destination rect to layer bounds
    const x0: i32 = @max(0, x);
    const y0: i32 = @max(0, y);
    const x1: i32 = @min(@as(i32, self.width), x + w);
    const y1: i32 = @min(@as(i32, self.height), y + h);
    if (x0 >= x1 or y0 >= y1) return;

    const layer = &self.layers[self.active_layer];
    const dst_stride: usize = @as(usize, self.width) * 4;
    const src_w: usize = @intCast(w);

    // Source offset for clipping
    const src_x0: usize = @intCast(x0 - x);
    const src_y0: usize = @intCast(y0 - y);
    const cols: usize = @intCast(x1 - x0);
    const rows: usize = @intCast(y1 - y0);

    var row: usize = 0;
    while (row < rows) : (row += 1) {
        const src_row_start = (src_y0 + row) * src_w + src_x0;
        const dst_row_off = @as(usize, @intCast(y0)) + row;
        const dst_off_start = dst_row_off * dst_stride + @as(usize, @intCast(x0)) * 4;

        const src_slice = colors[src_row_start..][0..cols];
        const dst_bytes = layer.pixels[dst_off_start..][0 .. cols * 4];
        const aligned: []align(@alignOf(u32)) u8 = @alignCast(dst_bytes);
        @memcpy(std.mem.bytesAsSlice(u32, aligned), src_slice);
    }
    self.markLayerDirty(layer);
}

pub fn drawRect(self: *Compositor, x: i32, y: i32, w: i32, h: i32, color: Color) void {
    // Clip to buffer bounds
    const x0: usize = @intCast(@max(0, x));
    const y0: usize = @intCast(@max(0, y));
    const x1: usize = @intCast(@max(0, @min(@as(i32, self.width), x + w)));
    const y1: usize = @intCast(@max(0, @min(@as(i32, self.height), y + h)));
    if (x0 >= x1 or y0 >= y1) return;

    const layer = &self.layers[self.active_layer];
    const stride: usize = @as(usize, self.width) * 4;
    const color_u32 = color.pack();

    var py = y0;
    while (py < y1) : (py += 1) {
        const row_start = py * stride;
        const row_bytes = layer.pixels[row_start + x0 * 4 .. row_start + x1 * 4];
        const aligned: []align(@alignOf(u32)) u8 = @alignCast(row_bytes);
        @memset(std.mem.bytesAsSlice(u32, aligned), color_u32);
    }
    self.markLayerDirty(layer);
}

/// Line using Bresenham's algorithm.
pub fn drawLine(self: *Compositor, x1: i32, y1: i32, x2: i32, y2: i32, color: Color) void {
    var cx = x1;
    var cy = y1;

    const dx: i32 = @intCast(@abs(x2 - x1));
    const dy: i32 = -@as(i32, @intCast(@abs(y2 - y1)));
    const sx: i32 = if (x1 < x2) 1 else -1;
    const sy: i32 = if (y1 < y2) 1 else -1;
    var err = dx + dy;

    const layer = &self.layers[self.active_layer];
    var drew = false;

    while (true) {
        if (cx >= 0 and cy >= 0 and cx < self.width and cy < self.height) {
            const ux: usize = @intCast(cx);
            const uy: usize = @intCast(cy);
            const offset = (uy * @as(usize, self.width) + ux) * 4;
            color.write(layer.pixels, offset);
            drew = true;
        }
        if (cx == x2 and cy == y2) break;
        const e2 = err * 2;
        if (e2 >= dy) {
            err += dy;
            cx += sx;
        }
        if (e2 <= dx) {
            err += dx;
            cy += sy;
        }
    }

    if (drew) self.markLayerDirty(layer);
}

/// Filled circle using midpoint algorithm with horizontal scanline fill.
pub fn drawCircle(self: *Compositor, cx: i32, cy: i32, r: i32, color: Color) void {
    if (r <= 0) return;

    const layer = &self.layers[self.active_layer];
    const color_u32 = color.pack();
    var x: i32 = r;
    var y: i32 = 0;
    var err: i32 = 1 - r;
    var drew = false;

    while (x >= y) {
        drew = drawHLineRaw(layer, self.width, self.height, cx - x, cx + x, cy + y, color_u32) or drew;
        drew = drawHLineRaw(layer, self.width, self.height, cx - x, cx + x, cy - y, color_u32) or drew;
        drew = drawHLineRaw(layer, self.width, self.height, cx - y, cx + y, cy + x, color_u32) or drew;
        drew = drawHLineRaw(layer, self.width, self.height, cx - y, cx + y, cy - x, color_u32) or drew;

        y += 1;
        if (err <= 0) {
            err += 2 * y + 1;
        } else {
            x -= 1;
            err += 2 * (y - x) + 1;
        }
    }

    if (drew) self.markLayerDirty(layer);
}

/// Write a horizontal line of pixels to a layer without marking dirty. Returns true if any pixels were written.
fn drawHLineRaw(layer: *Layer, buf_w: u16, buf_h: u16, x1: i32, x2: i32, y: i32, color_u32: u32) bool {
    if (y < 0 or y >= buf_h) return false;
    const start: usize = @intCast(@max(0, x1));
    const end: usize = @intCast(@max(0, @min(@as(i32, buf_w), x2 + 1)));
    if (start >= end) return false;

    const uy: usize = @intCast(y);
    const row_start = uy * @as(usize, buf_w) * 4;
    const row_bytes = layer.pixels[row_start + start * 4 .. row_start + end * 4];
    const aligned: []align(@alignOf(u32)) u8 = @alignCast(row_bytes);
    @memset(std.mem.bytesAsSlice(u32, aligned), color_u32);
    return true;
}

/// Blit a sub-rectangle of source RGBA pixels onto the active layer.
/// Supports integer scaling (nearest-neighbor), clipping, alpha blending, and flip.
pub fn blitImage(
    self: *Compositor,
    src: []const u8,
    src_w: u32,
    src_h: u32,
    src_rect: Rect,
    dst_x: i32,
    dst_y: i32,
    flip_x: bool,
    flip_y: bool,
    scale: u8,
) void {
    const sr_x = @min(src_rect.x, src_w);
    const sr_y = @min(src_rect.y, src_h);
    const sr_w = @min(src_rect.w, src_w - sr_x);
    const sr_h = @min(src_rect.h, src_h - sr_y);
    if (sr_w == 0 or sr_h == 0) return;

    const s: u32 = @max(1, scale);
    const scaled_w: u32 = sr_w * s;
    const scaled_h: u32 = sr_h * s;

    const dst_w: u32 = self.width;
    const dst_h: u32 = self.height;

    const vis_x0: i32 = @max(0, dst_x);
    const vis_y0: i32 = @max(0, dst_y);
    const vis_x1: i32 = @min(@as(i32, @intCast(dst_w)), dst_x + @as(i32, @intCast(scaled_w)));
    const vis_y1: i32 = @min(@as(i32, @intCast(dst_h)), dst_y + @as(i32, @intCast(scaled_h)));
    if (vis_x0 >= vis_x1 or vis_y0 >= vis_y1) return;

    const layer = &self.layers[self.active_layer];
    const dst_stride: usize = @as(usize, dst_w) * 4;
    const src_stride: usize = @as(usize, src_w) * 4;

    const off_x: u32 = @intCast(vis_x0 - dst_x);
    const off_y: u32 = @intCast(vis_y0 - dst_y);

    const rows: usize = @intCast(vis_y1 - vis_y0);
    const cols: usize = @intCast(vis_x1 - vis_x0);

    const dst_base_row: usize = @intCast(vis_y0);
    var dy: usize = 0;
    while (dy < rows) : (dy += 1) {
        const dst_row_off = (dst_base_row + dy) * dst_stride;

        const src_row_local = (off_y + @as(u32, @intCast(dy))) / s;
        const src_row_idx = if (flip_y) sr_h - 1 - src_row_local else src_row_local;
        const src_row_off = @as(usize, sr_y + src_row_idx) * src_stride;

        var dx: usize = 0;
        while (dx < cols) : (dx += 1) {
            const dst_off = dst_row_off + (@as(usize, @intCast(vis_x0)) + dx) * 4;

            const src_col_local = (off_x + @as(u32, @intCast(dx))) / s;
            const src_col_idx = if (flip_x) sr_w - 1 - src_col_local else src_col_local;
            const src_off = src_row_off + @as(usize, sr_x + src_col_idx) * 4;

            blendPixel(layer.pixels, dst_off, src, src_off);
        }
    }
    self.markLayerDirty(layer);
}

pub fn clearLayer(self: *Compositor) void {
    const layer = &self.layers[self.active_layer];
    @memset(layer.pixels, 0);
    layer.dirty = true;
    layer.has_content = false;
    self.any_dirty = true;
}

pub fn clearAll(self: *Compositor) void {
    for (&self.layers) |*layer| {
        if (!layer.has_content) continue;
        @memset(layer.pixels, 0);
        layer.dirty = true;
        layer.has_content = false;
        self.any_dirty = true;
    }
}

/// Mark all layers as dirty (e.g., after terminal resize).
pub fn markAllDirty(self: *Compositor) void {
    for (&self.layers) |*layer| {
        layer.dirty = true;
    }
    self.any_dirty = true;
}

/// Flatten all visible layers into the composite buffer, upload as a single image.
/// Old images are freed at the start of the NEXT flush — after vx.render() has
/// placed the replacement — so there is never a frame with no image visible.
pub fn flush(self: *Compositor) !void {
    // Free the image from the PREVIOUS frame (it has now been rendered over)
    if (self.pending_free_id) |old_id| {
        self.kitty.freeImage(old_id);
        self.pending_free_id = null;
    }

    // Check if any layer with actual content changed
    var content_dirty = false;
    if (self.any_dirty) {
        for (&self.layers) |*layer| {
            if (layer.dirty and layer.has_content) {
                content_dirty = true;
                break;
            }
        }
    }

    if (!content_dirty) {
        // Nothing with content changed — just re-place existing image
        if (self.composite_image) |img| {
            const win = self.vx.window();
            img.draw(win, .{
                .z_index = -10,
                .scale = .fill,
            }) catch {};
        }
        if (self.any_dirty) {
            for (&self.layers) |*layer| {
                layer.dirty = false;
            }
            self.any_dirty = false;
        }
        return;
    }

    self.flattenLayers();

    const new_img = try self.kitty.uploadRgba(self.composite_buf, self.width, self.height);

    // Place new image (behind text)
    const win = self.vx.window();
    new_img.draw(win, .{
        .z_index = -10,
        .scale = .fill,
    }) catch {};

    // Schedule the old image for deletion on NEXT flush (after render)
    if (self.composite_image) |old| {
        self.pending_free_id = old.id;
    }
    self.composite_image = new_img;

    // Clear dirty flags
    for (&self.layers) |*layer| {
        layer.dirty = false;
    }
    self.any_dirty = false;
}

/// Flatten all layers into composite_buf without uploading to the terminal.
/// Used by the scene manager to snapshot a scene's rendered output for transitions.
pub fn compositeOnly(self: *Compositor) void {
    self.flattenLayers();
}

fn flattenLayers(self: *Compositor) void {
    const byte_count = @as(usize, self.width) * @as(usize, self.height) * 4;

    var first_copied = false;
    for (&self.layers) |*layer| {
        if (!layer.visible) continue;
        if (!layer.has_content) continue;

        if (!first_copied) {
            @memcpy(self.composite_buf[0..byte_count], layer.pixels[0..byte_count]);
            first_copied = true;
        } else {
            const pixel_count = byte_count / 4;
            var i: usize = 0;
            while (i < pixel_count) : (i += 1) {
                const off = i * 4;
                blendPixel(self.composite_buf, off, layer.pixels, off);
            }
        }
    }

    if (!first_copied) {
        @memset(self.composite_buf, 0);
    }
}

/// Free all kitty images from terminal memory.
pub fn freeAllImages(self: *Compositor) void {
    if (self.pending_free_id) |old_id| {
        self.kitty.freeImage(old_id);
        self.pending_free_id = null;
    }
    if (self.composite_image) |img| {
        self.kitty.freeImage(img.id);
        self.composite_image = null;
    }
}

/// Fast approximation of x / 255 for x in [0, 65535]. Exact for all u8*u8 products.
inline fn div255(x: u16) u16 {
    return @intCast((@as(u32, x) + 1 + (@as(u32, x) >> 8)) >> 8);
}

/// Alpha-blend a single pixel (src-over). Both offsets must be valid.
inline fn blendPixel(dst: []u8, dst_off: usize, src: []const u8, src_off: usize) void {
    const sa = src[src_off + 3];
    if (sa == 0) return;

    if (sa == 255) {
        dst[dst_off] = src[src_off];
        dst[dst_off + 1] = src[src_off + 1];
        dst[dst_off + 2] = src[src_off + 2];
        dst[dst_off + 3] = 255;
    } else {
        const s_a: u16 = sa;
        const d_a: u16 = dst[dst_off + 3];
        const inv_sa: u16 = 255 - s_a;
        const d_contrib = div255(d_a * inv_sa);
        const out_a = s_a + d_contrib;
        if (out_a == 0) return;
        dst[dst_off] = @intCast((@as(u16, src[src_off]) * s_a + @as(u16, dst[dst_off]) * d_contrib) / out_a);
        dst[dst_off + 1] = @intCast((@as(u16, src[src_off + 1]) * s_a + @as(u16, dst[dst_off + 1]) * d_contrib) / out_a);
        dst[dst_off + 2] = @intCast((@as(u16, src[src_off + 2]) * s_a + @as(u16, dst[dst_off + 2]) * d_contrib) / out_a);
        dst[dst_off + 3] = @intCast(out_a);
    }
}

fn markLayerDirty(self: *Compositor, layer: *Layer) void {
    layer.dirty = true;
    layer.has_content = true;
    self.any_dirty = true;
}

// --- Tests ---

test "Color.fromHex" {
    const c = Color.fromHex(0xFF8800);
    try std.testing.expectEqual(@as(u8, 0xFF), c.r);
    try std.testing.expectEqual(@as(u8, 0x88), c.g);
    try std.testing.expectEqual(@as(u8, 0x00), c.b);
    try std.testing.expectEqual(@as(u8, 0xFF), c.a);
}

test "drawRect clips to bounds" {
    // This tests the clipping logic without needing a full compositor
    const x0: usize = @intCast(@max(0, @as(i32, -5)));
    const y0: usize = @intCast(@max(0, @as(i32, -3)));
    const x1: usize = @intCast(@min(@as(i32, 320), @as(i32, -5) + 20));
    const y1: usize = @intCast(@min(@as(i32, 180), @as(i32, -3) + 10));
    try std.testing.expectEqual(@as(usize, 0), x0);
    try std.testing.expectEqual(@as(usize, 0), y0);
    try std.testing.expectEqual(@as(usize, 15), x1);
    try std.testing.expectEqual(@as(usize, 7), y1);
}
