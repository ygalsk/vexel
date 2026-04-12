const std = @import("std");
const vaxis = @import("vaxis");

const SpritePlacer = @This();

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
placements: std.ArrayList(SpritePlacement),

pub fn init(allocator: std.mem.Allocator) SpritePlacer {
    return .{
        .allocator = allocator,
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

/// Register a sprite placement for this frame.
pub fn addPlacement(self: *SpritePlacer, placement: SpritePlacement) !void {
    try self.placements.append(self.allocator, placement);
}

/// Write all placements into vaxis cells. Call this before vx.render().
pub fn flush(self: *const SpritePlacer, vx: *vaxis.Vaxis) void {
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

test "SpritePlacer init and deinit" {
    var sp = SpritePlacer.init(std.testing.allocator);
    defer sp.deinit();
    try sp.addPlacement(.{
        .terminal_image_id = 1,
        .clip_x = 0, .clip_y = 0, .clip_w = 16, .clip_h = 16,
        .col = 0, .row = 0,
        .pixel_offset_x = 0, .pixel_offset_y = 0,
        .span_cols = 2, .span_rows = 1,
        .z_index = -1,
    });
    try std.testing.expectEqual(@as(usize, 1), sp.placements.items.len);
    sp.clear();
    try std.testing.expectEqual(@as(usize, 0), sp.placements.items.len);
}
