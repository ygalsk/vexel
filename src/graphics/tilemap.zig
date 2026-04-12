const std = @import("std");
const Renderer = @import("renderer");

pub const DrawTilemapOpts = struct {
    map_width: u32,
    cam_x: f64 = 0,
    cam_y: f64 = 0,
    layer: u8 = 0,
};

/// Render a tilemap using a sprite sheet tileset.
/// `map_data` is a flat array of tile indices (row-major, 1-based; 0 = empty).
/// `tile_w`/`tile_h` come from the sprite sheet frame dimensions.
pub fn renderTilemap(
    renderer: *Renderer,
    handle: Renderer.ImageHandle,
    map_data: []const u32,
    tile_w: u32,
    tile_h: u32,
    opts: DrawTilemapOpts,
) void {
    if (opts.map_width == 0 or tile_w == 0 or tile_h == 0) return;

    const map_h = @as(u32, @intCast(map_data.len)) / opts.map_width;
    if (map_h == 0) return;

    // Get viewport size in pixels
    const res = renderer.pixelGetResolution();
    const vp_w: i32 = @intCast(res.w);
    const vp_h: i32 = @intCast(res.h);

    // Camera offset (sub-pixel for smooth scrolling)
    const cx: i32 = @intFromFloat(opts.cam_x);
    const cy: i32 = @intFromFloat(opts.cam_y);

    // Calculate visible tile range
    const tw: i32 = @intCast(tile_w);
    const th: i32 = @intCast(tile_h);

    const start_col: u32 = if (cx >= 0) @intCast(@divFloor(cx, tw)) else 0;
    const start_row: u32 = if (cy >= 0) @intCast(@divFloor(cy, th)) else 0;
    const end_col: u32 = @min(opts.map_width, @as(u32, @intCast(@max(0, @divFloor(cx + vp_w, tw) + 2))));
    const end_row: u32 = @min(map_h, @as(u32, @intCast(@max(0, @divFloor(cy + vp_h, th) + 2))));

    const prev_mode = renderer.setSpriteMode(.compositor);
    defer _ = renderer.setSpriteMode(prev_mode);

    renderer.pixelSetLayer(opts.layer);

    var row: u32 = start_row;
    while (row < end_row) : (row += 1) {
        var col: u32 = start_col;
        while (col < end_col) : (col += 1) {
            const idx = row * opts.map_width + col;
            if (idx >= map_data.len) continue;

            const tile = map_data[idx];
            if (tile == 0) continue; // 0 = empty

            const px: i32 = @as(i32, @intCast(col)) * tw - cx;
            const py: i32 = @as(i32, @intCast(row)) * th - cy;

            // tile indices are 1-based in Lua; frame indices are 0-based
            renderer.drawSprite(handle, px, py, .{ .frame = tile - 1 });
        }
    }
}
