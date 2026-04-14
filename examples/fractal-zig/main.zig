/// Fractal viewer — hybrid Zig+Lua example.
///
/// Demonstrates using Vexel as a library:
///   - Heavy fractal computation runs in Zig (render_buffer)
///   - UI, controls, and animation state live in Lua (main.lua)
///   - The `fractal` module is registered with one line; Lua calls it naturally
///
/// Run: zig build run-fractal-zig
const std = @import("std");
const vexel = @import("vexel");

/// Native fractal computation module exposed to Lua.
///
/// Tier 1 functions (pure, auto-wrapped):
///   fractal.mandelbrot(cx, cy, max_iter) -> iter_count
///
/// Tier 2 functions (engine-aware, direct renderer access):
///   fractal.render_buffer(zoom, cx, cy, max_iter, is_julia, color_offset, julia_cr, julia_ci)
const fractal = struct {
    /// Single-point Mandelbrot iteration count. Auto-wrapped for Lua.
    pub fn mandelbrot(cx: f64, cy: f64, max_iter: i32) i32 {
        var zr: f64 = 0;
        var zi: f64 = 0;
        var i: i32 = 0;
        while (i < max_iter) : (i += 1) {
            const zr2 = zr * zr;
            const zi2 = zi * zi;
            if (zr2 + zi2 > 4.0) return i;
            zi = 2.0 * zr * zi + cy;
            zr = zr2 - zi2 + cx;
        }
        return max_iter;
    }

    /// Compute full fractal frame and blit directly to the renderer.
    /// Pixels never cross the Lua boundary — orders of magnitude faster than
    /// computing in Lua or returning a Lua table of 2M values.
    pub fn render_buffer(ctx: *vexel.EngineContext, lua: *vexel.Lua) i32 {
        const zoom = lua.toNumber(1) catch 1.0;
        const center_x = lua.toNumber(2) catch -0.5;
        const center_y = lua.toNumber(3) catch 0.0;
        const max_iter: u32 = @intCast(lua.toInteger(4) catch 32);
        const is_julia = lua.toBoolean(5);
        const color_offset = lua.toNumber(6) catch 0.0;
        const julia_cr = lua.toNumber(7) catch -0.7;
        const julia_ci = lua.toNumber(8) catch 0.27;

        const renderer = ctx.renderer;
        const res = renderer.pixelGetResolution();
        const w: u32 = res.w;
        const h: u32 = res.h;
        if (w == 0 or h == 0) return 0;

        const colors = cachedBuffer(w * h) orelse return 0;

        const fw: f64 = @floatFromInt(w);
        const fh: f64 = @floatFromInt(h);

        if (is_julia) {
            computeJulia(colors, w, h, fw, fh, zoom, julia_cr, julia_ci, max_iter, color_offset);
        } else {
            computeMandelbrot(colors, w, h, fw, fh, zoom, center_x, center_y, max_iter, color_offset);
        }

        renderer.pixelSetLayer(0);
        renderer.pixelBlitBuffer(0, 0, @intCast(w), @intCast(h), colors);
        return 0;
    }
};

var cached_buf: ?[]u32 = null;
var cached_len: usize = 0;

fn cachedBuffer(len: usize) ?[]u32 {
    if (cached_buf != null and cached_len >= len) return cached_buf.?[0..len];
    const alloc = std.heap.page_allocator;
    if (cached_buf) |buf| alloc.free(buf[0..cached_len]);
    cached_buf = alloc.alloc(u32, len) catch return null;
    cached_len = len;
    return cached_buf.?[0..len];
}

fn computeMandelbrot(
    colors: []u32,
    w: u32,
    h: u32,
    fw: f64,
    fh: f64,
    zoom: f64,
    center_x: f64,
    center_y: f64,
    max_iter: u32,
    color_offset: f64,
) void {
    const scale = 3.5 / (zoom * fw);
    const aspect_scale = scale * (fw / fh);

    for (0..h) |py| {
        const row_offset = py * w;
        const ci0 = center_y + (@as(f64, @floatFromInt(py)) - fh * 0.5) * aspect_scale;

        for (0..w) |px| {
            const cr = center_x + (@as(f64, @floatFromInt(px)) - fw * 0.5) * scale;
            var zr: f64 = 0;
            var zi: f64 = 0;
            var iter: u32 = 0;
            while (iter < max_iter) : (iter += 1) {
                const zr2 = zr * zr;
                const zi2 = zi * zi;
                if (zr2 + zi2 > 4.0) break;
                zi = 2.0 * zr * zi + ci0;
                zr = zr2 - zi2 + cr;
            }
            colors[row_offset + px] = makeColor(iter, max_iter, color_offset);
        }
    }
}

fn computeJulia(
    colors: []u32,
    w: u32,
    h: u32,
    fw: f64,
    fh: f64,
    zoom: f64,
    cr: f64,
    ci: f64,
    max_iter: u32,
    color_offset: f64,
) void {
    const sx = 2.5 * 3.5 / (zoom * fw);
    const sy = sx * (fw / fh);

    for (0..h) |py| {
        const row_offset = py * w;
        const y0 = (@as(f64, @floatFromInt(py)) - fh * 0.5) * sy;

        for (0..w) |px| {
            var zr = (@as(f64, @floatFromInt(px)) - fw * 0.5) * sx;
            var zi = y0;
            var iter: u32 = 0;
            while (iter < max_iter) : (iter += 1) {
                const zr2 = zr * zr;
                const zi2 = zi * zi;
                if (zr2 + zi2 > 4.0) break;
                zi = 2.0 * zr * zi + ci;
                zr = zr2 - zi2 + cr;
            }
            colors[row_offset + px] = makeColor(iter, max_iter, color_offset);
        }
    }
}

fn makeColor(iter: u32, max_iter: u32, color_offset: f64) u32 {
    if (iter >= max_iter) return 0xFF000000; // black, full alpha
    const t = @as(f64, @floatFromInt(iter)) / @as(f64, @floatFromInt(max_iter)) + color_offset;
    const tau = 6.283185307179586;
    const r: u8 = @intFromFloat(127.5 * (1.0 + @sin(tau * t)));
    const g: u8 = @intFromFloat(127.5 * (1.0 + @sin(tau * t + 2.094)));
    const b: u8 = @intFromFloat(127.5 * (1.0 + @sin(tau * t + 4.189)));
    // Pack as RGBA (R at byte 0) with full alpha — matches compositor layout
    return @as(u32, r) | (@as(u32, g) << 8) | (@as(u32, b) << 16) | (@as(u32, 255) << 24);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var app = try vexel.App.init(gpa.allocator(), .{
        .project_dir = ".",
    });
    defer app.deinit();

    app.registerModule("fractal", fractal);

    try app.run();
}
