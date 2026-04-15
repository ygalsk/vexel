const std = @import("std");
const math = std.math;

const G: usize = 32; // grid side length (32³ = 32,768 voxels)
const GSIZE: usize = G * G * G;

var grid: [GSIZE]bool = undefined;
var next_grid: [GSIZE]bool = undefined;
var initialized: bool = false;
var cam_angle: f32 = 0;
var prng: std.Random.DefaultPrng = undefined;

inline fn idx(x: usize, y: usize, z: usize) usize {
    return z * G * G + y * G + x;
}

fn initGrid() void {
    prng = std.Random.DefaultPrng.init(0xdeadbeef);
    const rng = prng.random();
    @memset(&grid, false);
    // Seed a 12³ cube in the center with ~30% fill
    const off = (G - 12) / 2;
    for (off..off + 12) |z| {
        for (off..off + 12) |y| {
            for (off..off + 12) |x| {
                grid[idx(x, y, z)] = rng.float(f32) < 0.30;
            }
        }
    }
    initialized = true;
}

fn countNeighbors(x: usize, y: usize, z: usize) u8 {
    var count: u8 = 0;
    const xi: i32 = @intCast(x);
    const yi: i32 = @intCast(y);
    const zi: i32 = @intCast(z);
    var dz: i32 = -1;
    while (dz <= 1) : (dz += 1) {
        var dy: i32 = -1;
        while (dy <= 1) : (dy += 1) {
            var dx: i32 = -1;
            while (dx <= 1) : (dx += 1) {
                if (dx == 0 and dy == 0 and dz == 0) continue;
                const gi: i32 = @intCast(G);
                const nx: usize = @intCast(@mod(xi + dx + gi, gi));
                const ny: usize = @intCast(@mod(yi + dy + gi, gi));
                const nz: usize = @intCast(@mod(zi + dz + gi, gi));
                if (grid[idx(nx, ny, nz)]) count += 1;
            }
        }
    }
    return count;
}

fn stepCA() void {
    for (0..G) |z| {
        for (0..G) |y| {
            for (0..G) |x| {
                const n = countNeighbors(x, y, z);
                const i = idx(x, y, z);
                // "Cloud" rule: born 13-26, survive 13-14
                next_grid[i] = if (grid[i])
                    (n >= 13 and n <= 14)
                else
                    (n >= 13 and n <= 26);
            }
        }
    }
    @memcpy(&grid, &next_grid);
}

// Ray march through the voxel grid.
// Returns packed RGB (with 0xFF000000 alpha) or 0 for background.
inline fn marchRay(ox: f32, oy: f32, oz: f32, dx: f32, dy: f32, dz: f32) u32 {
    const GF: f32 = @floatFromInt(G);
    // Step size: traverse at most G+1 grid units
    const step_size: f32 = 0.8;
    const max_steps: usize = @intFromFloat(GF * 1.8 / step_size);

    var rx = ox;
    var ry = oy;
    var rz = oz;

    for (0..max_steps) |_| {
        rx += dx * step_size;
        ry += dy * step_size;
        rz += dz * step_size;

        // Check bounds
        if (rx < 0 or rx >= GF or ry < 0 or ry >= GF or rz < 0 or rz >= GF) break;

        const gx = @as(usize, @intFromFloat(rx));
        const gy = @as(usize, @intFromFloat(ry));
        const gz = @as(usize, @intFromFloat(rz));

        if (grid[idx(gx, gy, gz)]) {
            // Compute a simple normal by looking at 6 neighbors
            const nx_p = if (gx + 1 < G and grid[idx(gx + 1, gy, gz)]) @as(f32, 1) else 0;
            const nx_m = if (gx > 0 and grid[idx(gx - 1, gy, gz)]) @as(f32, 1) else 0;
            const ny_p = if (gy + 1 < G and grid[idx(gx, gy + 1, gz)]) @as(f32, 1) else 0;
            const ny_m = if (gy > 0 and grid[idx(gx, gy - 1, gz)]) @as(f32, 1) else 0;
            const nz_p = if (gz + 1 < G and grid[idx(gx, gy, gz + 1)]) @as(f32, 1) else 0;
            const nz_m = if (gz > 0 and grid[idx(gx, gy, gz - 1)]) @as(f32, 1) else 0;

            var nnx = nx_m - nx_p;
            var nny = ny_m - ny_p;
            var nnz = nz_m - nz_p;
            // Normalize
            const nl = @sqrt(nnx * nnx + nny * nny + nnz * nnz);
            if (nl > 0.001) {
                nnx /= nl;
                nny /= nl;
                nnz /= nl;
            } else {
                nnx = -dx;
                nny = -dy;
                nnz = -dz;
            }

            // Lighting: key light from upper-right-front
            const lx: f32 = 0.577;
            const ly: f32 = 0.577;
            const lz: f32 = -0.577;
            const diffuse = math.clamp(nnx * lx + nny * ly + nnz * lz, 0.0, 1.0);
            const ambient: f32 = 0.25;
            const light = ambient + (1.0 - ambient) * diffuse;

            // Depth fog: fade distant voxels
            const dist = @sqrt((rx - ox) * (rx - ox) + (ry - oy) * (ry - oy) + (rz - oz) * (rz - oz));
            const fog = math.clamp(1.0 - dist / (GF * 1.5), 0.0, 1.0);
            const final_light = light * fog;

            // Color: warm orange-to-white based on y position (height)
            const ht = math.clamp(ry / GF, 0.0, 1.0);
            const r: u8 = @intFromFloat(math.clamp(final_light * (0.6 + ht * 0.4) * 255, 0, 255));
            const g: u8 = @intFromFloat(math.clamp(final_light * (0.3 + ht * 0.5) * 255, 0, 255));
            const b: u8 = @intFromFloat(math.clamp(final_light * (0.1 + ht * 0.6) * 255, 0, 255));

            return 0xFF000000 | (@as(u32, r) << 16) | (@as(u32, g) << 8) | b;
        }
    }
    return 0;
}

pub fn shade(buf: []u32, w: u16, h: u16, uniforms: []const f64) void {
    if (!initialized) initGrid();

    const dt: f32 = if (uniforms.len > 0) @floatCast(uniforms[0]) else 0.016;
    const speed: f32 = if (uniforms.len > 1) @floatCast(uniforms[1]) else 1.0;
    const do_reset: bool = if (uniforms.len > 2) uniforms[2] > 0.5 else false;

    if (do_reset) initGrid();

    cam_angle += dt * speed;

    // Step CA every other frame (too slow to do every frame)
    const frame_count = @as(u64, @intFromFloat(cam_angle / dt));
    if (frame_count % 2 == 0) stepCA();

    // Render at half resolution (160x90), upscale 2x
    const rw = w / 2;
    const rh = h / 2;
    const GF: f32 = @floatFromInt(G);
    const half = GF * 0.5;

    // Camera orbit around the center of the grid
    const cam_dist: f32 = GF * 1.6;
    const cam_x = half + cam_dist * @cos(cam_angle);
    const cam_y = half + GF * 0.4; // slightly above center
    const cam_z = half + cam_dist * @sin(cam_angle);

    // Look-at: center of the grid
    var look_x = half - cam_x;
    var look_y = half - cam_y;
    var look_z = half - cam_z;
    const look_len = @sqrt(look_x * look_x + look_y * look_y + look_z * look_z);
    look_x /= look_len;
    look_y /= look_len;
    look_z /= look_len;

    // Right vector: cross(look, world_up=(0,1,0))
    var right_x = look_z; // cross product with (0,1,0): (lz, 0, -lx)
    const right_y: f32 = 0;
    var right_z = -look_x;
    const right_len = @sqrt(right_x * right_x + right_z * right_z);
    right_x /= right_len;
    right_z /= right_len;

    // Up vector: cross(right, look)
    const up_x = right_y * look_z - right_z * look_y;
    const up_y = right_z * look_x - right_x * look_z;
    const up_z = right_x * look_y - right_y * look_x;

    const fov: f32 = 0.8; // focal length (higher = narrower FOV)
    const rw_f: f32 = @floatFromInt(rw);
    const rh_f: f32 = @floatFromInt(rh);

    for (0..rh) |py| {
        const pf_y: f32 = (@as(f32, @floatFromInt(py)) - rh_f * 0.5) / rh_f;
        for (0..rw) |px_| {
            const pf_x: f32 = (@as(f32, @floatFromInt(px_)) - rw_f * 0.5) / rh_f; // /rh for aspect ratio
            // Ray direction
            var rd_x = look_x * fov + right_x * pf_x + up_x * pf_y;
            var rd_y = look_y * fov + right_y * pf_x + up_y * pf_y;
            var rd_z = look_z * fov + right_z * pf_x + up_z * pf_y;
            const rd_len = @sqrt(rd_x * rd_x + rd_y * rd_y + rd_z * rd_z);
            rd_x /= rd_len;
            rd_y /= rd_len;
            rd_z /= rd_len;

            const color = marchRay(cam_x, cam_y, cam_z, rd_x, rd_y, rd_z);

            // Upscale 2x2
            const out_x = px_ * 2;
            const out_y = py * 2;
            const full_w: usize = @intCast(w);
            buf[out_y * full_w + out_x] = color;
            buf[out_y * full_w + out_x + 1] = color;
            buf[(out_y + 1) * full_w + out_x] = color;
            buf[(out_y + 1) * full_w + out_x + 1] = color;
        }
    }
}
