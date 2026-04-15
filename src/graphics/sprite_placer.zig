const std = @import("std");
const vaxis = @import("vaxis");
const Compositing = @import("compositing");
const ImageMod = @import("image");
const Kitty = @import("kitty");

const SpritePlacer = @This();

pub const ImageHandle = ImageMod.ImageHandle;

/// Screen dimensions in terminal cells.
pub const ScreenInfo = struct {
    cols: u16,
    rows: u16,
    x_pixel: u16,
    y_pixel: u16,

    pub fn cellWidth(self: ScreenInfo) u16 {
        if (self.cols == 0) return 8;
        return self.x_pixel / self.cols;
    }

    pub fn cellHeight(self: ScreenInfo) u16 {
        if (self.rows == 0) return 16;
        return self.y_pixel / self.rows;
    }
};

pub const SpriteMode = enum { compositor, placer };

pub const DrawSpriteOpts = struct {
    frame: ?u32 = null,
    flip_x: bool = false,
    flip_y: bool = false,
    scale: u8 = 1,
};

pub const SpritePlacement = struct {
    terminal_image_id: u32,
    // Source crop in the spritesheet (pixel coordinates)
    clip_x: u16,
    clip_y: u16,
    clip_w: u16,
    clip_h: u16,
    // Destination cell position
    col: u16,
    row: u16,
    // Sub-cell pixel offset
    pixel_offset_x: u16,
    pixel_offset_y: u16,
    // How many cells this sprite spans
    span_cols: u16,
    span_rows: u16,
    // Z-index for layering
    z_index: i32,
};

allocator: std.mem.Allocator,
image_manager: *ImageMod,
compositor: *Compositing,
screen_info: *ScreenInfo,
sprite_mode: *SpriteMode, // borrowed; must outlive this SpritePlacer
placements: std.ArrayList(SpritePlacement),

pub fn init(
    allocator: std.mem.Allocator,
    image_manager: *ImageMod,
    compositor: *Compositing,
    screen_info: *ScreenInfo,
    sprite_mode: *SpriteMode,
) SpritePlacer {
    return .{
        .allocator = allocator,
        .image_manager = image_manager,
        .compositor = compositor,
        .screen_info = screen_info,
        .sprite_mode = sprite_mode,
        .placements = .{},
    };
}

pub fn deinit(self: *SpritePlacer) void {
    self.placements.deinit(self.allocator);
}

/// Clear all placements for the new frame.
pub fn clear(self: *SpritePlacer) void {
    self.placements.clearRetainingCapacity();
}

/// Write all placements into vaxis cells. Call this before vx.render().
pub fn flush(self: *const SpritePlacer, vx: *vaxis.Vaxis) void {
    if (self.placements.items.len == 0) return;
    const win = vx.window();

    for (self.placements.items) |p| {
        if (p.col >= win.width or p.row >= win.height) continue;

        win.writeCell(p.col, p.row, .{
            .image = .{
                .img_id = p.terminal_image_id,
                .options = .{
                    .clip_region = .{
                        .x = p.clip_x,
                        .y = p.clip_y,
                        .width = p.clip_w,
                        .height = p.clip_h,
                    },
                    .pixel_offset = .{
                        .x = p.pixel_offset_x,
                        .y = p.pixel_offset_y,
                    },
                    .size = .{
                        .rows = p.span_rows,
                        .cols = p.span_cols,
                    },
                    .z_index = p.z_index,
                },
            },
        });
    }
}

pub fn drawSprite(self: *SpritePlacer, handle: ImageHandle, x: i32, y: i32, opts: DrawSpriteOpts) void {
    const mgr = self.image_manager;

    const frame_idx = opts.frame orelse 0;
    const src_rect = mgr.getFrameRect(handle, frame_idx) orelse return;

    if (self.sprite_mode.* == .compositor) {
        const info = mgr.getImageInfo(handle) orelse return;
        self.compositor.blitImage(
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
        mgr.uploadVariant(handle, variant, self.getSpriteUpscale());
        term_img = mgr.getTerminalImage(handle, variant);
    }
    const ti = term_img orelse return;

    const si = self.screen_info.*;
    const virt_w: u32 = self.compositor.width;
    const virt_h: u32 = self.compositor.height;
    const term_w: u32 = si.x_pixel;
    const term_h: u32 = si.y_pixel;
    const cw: u32 = si.cellWidth();
    const ch: u32 = si.cellHeight();
    if (cw == 0 or ch == 0 or virt_w == 0 or virt_h == 0) return;

    const info = mgr.getImageInfo(handle) orelse return;
    const upscale: u32 = if (info.width > 0) @as(u32, ti.width) / info.width else 1;

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

    // Clip region in the pre-scaled image
    const clip_x: u16 = @intCast(src_rect.x * upscale);
    const clip_y: u16 = @intCast(src_rect.y * upscale);
    const clip_w: u16 = @intCast(src_rect.w * upscale);
    const clip_h: u16 = @intCast(src_rect.h * upscale);

    // Display size in terminal pixels
    const display_w: u32 = @intCast(@divTrunc(@as(i64, frame_vw) * @as(i64, term_w), @as(i64, virt_w)));
    const display_h: u32 = @intCast(@divTrunc(@as(i64, frame_vh) * @as(i64, term_h), @as(i64, virt_h)));
    if (display_w == 0 or display_h == 0) return;

    const px: u32 = @intCast(tx);
    const py: u32 = @intCast(ty);
    const col: u16 = @intCast(@min(px / cw, si.cols -| 1));
    const row: u16 = @intCast(@min(py / ch, si.rows -| 1));
    const off_x: u16 = @intCast(px % cw);
    const off_y: u16 = @intCast(py % ch);

    const span_cols: u16 = @intCast(@min((display_w + cw - 1) / cw, si.cols - col));
    const span_rows: u16 = @intCast(@min((display_h + ch - 1) / ch, si.rows - row));

    const z_index: i32 = Compositing.layerSpriteZ(self.compositor.getActiveLayer());

    self.addPlacement(.{
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
fn getSpriteUpscale(self: *const SpritePlacer) u16 {
    const virt_w: u32 = self.compositor.width;
    const virt_h: u32 = self.compositor.height;
    if (virt_w == 0 or virt_h == 0) return 1;
    const si = self.screen_info.*;
    const sx: u16 = @intCast(@as(u32, si.x_pixel) / virt_w);
    const sy: u16 = @intCast(@as(u32, si.y_pixel) / virt_h);
    return @max(1, @min(sx, sy));
}

/// Register a sprite placement for this frame.
pub fn addPlacement(self: *SpritePlacer, placement: SpritePlacement) !void {
    try self.placements.append(self.allocator, placement);
}

