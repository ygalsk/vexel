/// Raymarching SDF renderer — registered into Lua via vexel.App.registerModule.
///
/// Single pub function: render_pixel(px, py, w, h, time) -> packed RGB i32.
/// Handles camera, ray marching, SDF scene, normals, and lighting internally.

const std = @import("std");
const math = std.math;

const MAX_STEPS: u32 = 64;
const MAX_DIST: f64 = 50.0;
const SURF_DIST: f64 = 0.001;

const SHADOW_STEPS: u32 = 32;
const SHADOW_SURF: f64 = 0.01;

const SceneHit = struct { dist: f64, mat: u8 };

fn sdSphere(p: [3]f64, r: f64) f64 {
    return @sqrt(p[0] * p[0] + p[1] * p[1] + p[2] * p[2]) - r;
}

fn sdTorus(p: [3]f64, r1: f64, r2: f64) f64 {
    const q0 = @sqrt(p[0] * p[0] + p[2] * p[2]) - r1;
    return @sqrt(q0 * q0 + p[1] * p[1]) - r2;
}

fn sdPlane(p: [3]f64) f64 {
    return p[1] + 1.0;
}

fn scene(p: [3]f64, cos_t: f64, sin_t: f64, sin_t13: f64) SceneHit {
    // Rotating torus
    const tp = [3]f64{
        p[0] * cos_t - p[2] * sin_t,
        p[1],
        p[0] * sin_t + p[2] * cos_t,
    };
    const torus = sdTorus(tp, 0.8, 0.25);

    // Floating sphere
    const sp = [3]f64{
        p[0] - 1.5,
        p[1] - sin_t13 * 0.3,
        p[2],
    };
    const sphere = sdSphere(sp, 0.5);

    const plane = sdPlane(p);

    // Return closest hit with material ID
    if (torus <= sphere and torus <= plane) return .{ .dist = torus, .mat = 1 };
    if (sphere <= plane) return .{ .dist = sphere, .mat = 2 };
    return .{ .dist = plane, .mat = 0 };
}

fn sceneDist(p: [3]f64, cos_t: f64, sin_t: f64, sin_t13: f64) f64 {
    return scene(p, cos_t, sin_t, sin_t13).dist;
}

const MarchResult = struct { t: f64, mat: u8 };

fn march(ro: [3]f64, rd: [3]f64, cos_t: f64, sin_t: f64, sin_t13: f64) MarchResult {
    var t: f64 = 0;
    var mat: u8 = 0;
    for (0..MAX_STEPS) |_| {
        const p = [3]f64{
            ro[0] + rd[0] * t,
            ro[1] + rd[1] * t,
            ro[2] + rd[2] * t,
        };
        const hit = scene(p, cos_t, sin_t, sin_t13);
        mat = hit.mat;
        t += hit.dist;
        if (hit.dist < SURF_DIST or t > MAX_DIST) break;
    }
    return .{ .t = t, .mat = mat };
}

fn marchShadow(ro: [3]f64, rd: [3]f64, cos_t: f64, sin_t: f64, sin_t13: f64) f64 {
    var t: f64 = 0;
    for (0..SHADOW_STEPS) |_| {
        const p = [3]f64{
            ro[0] + rd[0] * t,
            ro[1] + rd[1] * t,
            ro[2] + rd[2] * t,
        };
        const d = sceneDist(p, cos_t, sin_t, sin_t13);
        t += d;
        if (d < SHADOW_SURF or t > MAX_DIST) break;
    }
    return t;
}

fn normal(p: [3]f64, cos_t: f64, sin_t: f64, sin_t13: f64) [3]f64 {
    const e: f64 = 0.001;
    const d = sceneDist(p, cos_t, sin_t, sin_t13);
    return normalize(.{
        sceneDist(.{ p[0] + e, p[1], p[2] }, cos_t, sin_t, sin_t13) - d,
        sceneDist(.{ p[0], p[1] + e, p[2] }, cos_t, sin_t, sin_t13) - d,
        sceneDist(.{ p[0], p[1], p[2] + e }, cos_t, sin_t, sin_t13) - d,
    });
}

fn normalize(v: [3]f64) [3]f64 {
    const len = @sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    if (len < 1e-10) return .{ 0, 1, 0 };
    return .{ v[0] / len, v[1] / len, v[2] / len };
}

fn dot(a: [3]f64, b: [3]f64) f64 {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

fn clamp01(x: f64) f64 {
    return @max(0.0, @min(1.0, x));
}

pub fn render_pixel(px: f64, py: f64, w: f64, h: f64, time: f64) i32 {
    // Hoist frame-constant trig
    const cos_t = @cos(time);
    const sin_t = @sin(time);
    const sin_t13 = @sin(time * 1.3);

    // UV: [-1, 1] with aspect correction
    const aspect = w / h;
    const u = (2.0 * px / w - 1.0) * aspect;
    const v = 1.0 - 2.0 * py / h;

    // Camera
    const ro = [3]f64{ 0, 0.5, -3.5 };
    const rd = normalize(.{ u, v, 1.5 });

    const result = march(ro, rd, cos_t, sin_t, sin_t13);

    if (result.t >= MAX_DIST) {
        // Sky gradient
        const sky = 0.3 + 0.4 * clamp01(v + 0.5);
        const ri: i32 = @intFromFloat(clamp01(sky * 0.3) * 255.0);
        const gi: i32 = @intFromFloat(clamp01(sky * 0.4) * 255.0);
        const bi: i32 = @intFromFloat(clamp01(sky * 0.7) * 255.0);
        return ri * 65536 + gi * 256 + bi;
    }

    const hit = [3]f64{
        ro[0] + rd[0] * result.t,
        ro[1] + rd[1] * result.t,
        ro[2] + rd[2] * result.t,
    };
    const n = normal(hit, cos_t, sin_t, sin_t13);

    // Light
    const light_dir = normalize(.{ -0.5, 0.8, -0.6 });
    const diff = clamp01(dot(n, light_dir));

    // Shadow ray (relaxed precision)
    const shadow_origin = [3]f64{
        hit[0] + n[0] * 0.03,
        hit[1] + n[1] * 0.03,
        hit[2] + n[2] * 0.03,
    };
    const shadow_t = marchShadow(shadow_origin, light_dir, cos_t, sin_t, sin_t13);
    const shadow: f64 = if (shadow_t < MAX_DIST) 0.3 else 1.0;

    // Specular — compute dot(rd, n) once
    const dn = 2.0 * dot(rd, n);
    const refl = [3]f64{
        rd[0] - dn * n[0],
        rd[1] - dn * n[1],
        rd[2] - dn * n[2],
    };
    const spec = math.pow(f64, clamp01(dot(refl, light_dir)), 16.0);

    // Material from march result — no re-evaluation needed
    var base_r: f64 = 0.4;
    var base_g: f64 = 0.4;
    var base_b: f64 = 0.4;
    switch (result.mat) {
        1 => { // torus
            base_r = 0.9;
            base_g = 0.3;
            base_b = 0.1;
        },
        2 => { // sphere
            base_r = 0.2;
            base_g = 0.5;
            base_b = 0.9;
        },
        else => { // plane — checkerboard
            const check: f64 = if ((@as(i32, @intFromFloat(@floor(hit[0]))) +% @as(i32, @intFromFloat(@floor(hit[2])))) & 1 == 0) 0.5 else 0.3;
            base_r = check;
            base_g = check;
            base_b = check;
        },
    }

    const ambient: f64 = 0.15;
    const light = ambient + diff * shadow * 0.85;
    const ri: i32 = @intFromFloat(clamp01(base_r * light + spec * shadow * 0.4) * 255.0);
    const gi: i32 = @intFromFloat(clamp01(base_g * light + spec * shadow * 0.3) * 255.0);
    const bi: i32 = @intFromFloat(clamp01(base_b * light + spec * shadow * 0.2) * 255.0);
    return ri * 65536 + gi * 256 + bi;
}
