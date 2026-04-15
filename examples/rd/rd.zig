const std = @import("std");

const MAX_W: usize = 320;
const MAX_H: usize = 180;
const MAX_SIZE: usize = MAX_W * MAX_H;

// Double-buffered chemical concentrations
var a: [MAX_SIZE]f32 = undefined;
var b: [MAX_SIZE]f32 = undefined;
var na: [MAX_SIZE]f32 = undefined;
var nb: [MAX_SIZE]f32 = undefined;
var sim_w: usize = 0;
var sim_h: usize = 0;
var initialized: bool = false;

fn seedSpot(cx: i32, cy: i32, radius: i32) void {
    const r2 = radius * radius;
    var dy: i32 = -radius;
    while (dy <= radius) : (dy += 1) {
        var dx: i32 = -radius;
        while (dx <= radius) : (dx += 1) {
            if (dx * dx + dy * dy > r2) continue;
            const px = cx + dx;
            const py = cy + dy;
            if (px < 0 or px >= @as(i32, @intCast(sim_w)) or
                py < 0 or py >= @as(i32, @intCast(sim_h))) continue;
            const idx = @as(usize, @intCast(py)) * sim_w + @as(usize, @intCast(px));
            b[idx] = 1.0;
            a[idx] = 0.0;
        }
    }
}

fn initSim(w: usize, h: usize) void {
    sim_w = w;
    sim_h = h;
    const size = w * h;
    @memset(a[0..size], 1.0);
    @memset(b[0..size], 0.0);
    // Seed a few spots
    const cx: i32 = @intCast(w / 2);
    const cy: i32 = @intCast(h / 2);
    seedSpot(cx, cy, 8);
    seedSpot(cx - 40, cy - 20, 6);
    seedSpot(cx + 40, cy + 20, 6);
    initialized = true;
}

// 9-point weighted Laplacian (standard for reaction-diffusion)
inline fn laplacian(grid: *const [MAX_SIZE]f32, x: usize, y: usize, w: usize, h: usize) f32 {
    const xm = if (x == 0) w - 1 else x - 1;
    const xp = if (x == w - 1) 0 else x + 1;
    const ym = if (y == 0) h - 1 else y - 1;
    const yp = if (y == h - 1) 0 else y + 1;
    const center = grid[y * w + x];
    const cardinal = grid[ym * w + x] + grid[yp * w + x] + grid[y * w + xm] + grid[y * w + xp];
    const diagonal = grid[ym * w + xm] + grid[ym * w + xp] + grid[yp * w + xm] + grid[yp * w + xp];
    return 0.2 * cardinal + 0.05 * diagonal - center;
}

fn stepSim(w: usize, h: usize, feed: f32, kill: f32) void {
    const da: f32 = 1.0;
    const db: f32 = 0.5;

    for (0..h) |y| {
        for (0..w) |x| {
            const i = y * w + x;
            const av = a[i];
            const bv = b[i];
            const abb = av * bv * bv;
            const la = laplacian(&a, x, y, w, h);
            const lb = laplacian(&b, x, y, w, h);
            na[i] = std.math.clamp(av + da * la - abb + feed * (1.0 - av), 0.0, 1.0);
            nb[i] = std.math.clamp(bv + db * lb + abb - (feed + kill) * bv, 0.0, 1.0);
        }
    }
    @memcpy(a[0 .. w * h], na[0 .. w * h]);
    @memcpy(b[0 .. w * h], nb[0 .. w * h]);
}

inline fn colormap(t: f32) u32 {
    const v = std.math.clamp(t, 0.0, 1.0);
    const r: u8 = if (v > 0.75) @intFromFloat((v - 0.75) * 4.0 * 200.0) else 0;
    const g: u8 = if (v > 0.5) @intFromFloat((v - 0.5) * 4.0 * 255.0) else 0;
    const b_ch: u8 = if (v < 0.5)
        @intFromFloat(v * 2.0 * 255.0)
    else
        @intFromFloat((1.0 - (v - 0.5) * 2.0) * 255.0 + 100.0);
    return 0xFF000000 | (@as(u32, r) << 16) | (@as(u32, g) << 8) | b_ch;
}

pub fn shade(buf: []u32, w: u16, h: u16, uniforms: []const f64) void {
    const fw: usize = @min(@as(usize, w), MAX_W);
    const fh: usize = @min(@as(usize, h), MAX_H);

    const feed: f32 = if (uniforms.len > 0) @floatCast(uniforms[0]) else 0.055;
    const kill: f32 = if (uniforms.len > 1) @floatCast(uniforms[1]) else 0.062;
    const mx: i32 = if (uniforms.len > 2) @intFromFloat(uniforms[2]) else -1;
    const my: i32 = if (uniforms.len > 3) @intFromFloat(uniforms[3]) else -1;
    const painting: bool = if (uniforms.len > 4) uniforms[4] > 0.5 else false;
    const do_reset: bool = if (uniforms.len > 5) uniforms[5] > 0.5 else false;

    if (!initialized or do_reset or sim_w != fw or sim_h != fh) {
        initSim(fw, fh);
    }

    // Paint chemical B at mouse position
    if (painting and mx >= 0 and my >= 0) {
        seedSpot(mx, my, 5);
    }

    // Run 5 simulation steps per frame for faster convergence
    for (0..5) |_| stepSim(fw, fh, feed, kill);

    // Render B concentration to pixel buffer
    const size = fw * fh;
    for (0..size) |i| {
        buf[i] = colormap(b[i]);
    }
}
