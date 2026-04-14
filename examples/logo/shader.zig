/// VEXEL logo SDF shader — 5 animated phases driven by a 2D distance field.
///
/// Signature: render_pixel(px, py, w, h, time, phase, progress) -> packed 0xRRGGBB.
/// Uniforms from Lua: time (elapsed seconds), phase (0-4), progress (0-1 within phase).

const std = @import("std");
const math = std.math;

// ── Font data ──────────────────────────────────────────────────────────

// 4 unique glyphs, 9 rows each. Bit 6 = col 0 (leftmost), bit 0 = col 6.
const glyphs = [4][9]u8{
    // V
    .{ 0b1000001, 0b1000001, 0b1000001, 0b0100010, 0b0100010, 0b0010100, 0b0010100, 0b0001000, 0b0001000 },
    // E
    .{ 0b1111111, 0b1000000, 0b1000000, 0b1000000, 0b1111110, 0b1000000, 0b1000000, 0b1000000, 0b1111111 },
    // X
    .{ 0b1000001, 0b0100010, 0b0010100, 0b0001000, 0b0001000, 0b0001000, 0b0010100, 0b0100010, 0b1000001 },
    // L
    .{ 0b1000000, 0b1000000, 0b1000000, 0b1000000, 0b1000000, 0b1000000, 0b1000000, 0b1000000, 0b1111111 },
};

// VEXEL: indices into glyphs array
const letter_glyph = [5]u3{ 0, 1, 2, 1, 3 };

// ── Layout constants ───────────────────────────────────────────────────

const SCALE: f64 = 16.0;
const HALF: f64 = SCALE / 2.0;
const COLS: u32 = 7;
const ROWS: u32 = 9;
const LETTER_W: f64 = @as(f64, @floatFromInt(COLS)) * SCALE; // 112
const LETTER_H: f64 = @as(f64, @floatFromInt(ROWS)) * SCALE; // 144
const GAP: f64 = 2.0 * SCALE; // 32
const NUM_LETTERS: u32 = 5;
const TOTAL_W: f64 = @as(f64, @floatFromInt(NUM_LETTERS)) * LETTER_W + @as(f64, @floatFromInt(NUM_LETTERS - 1)) * GAP; // 688

// These depend on canvas size — computed for 1080x720
const REF_W: f64 = 1080.0;
const REF_H: f64 = 720.0;
const START_X: f64 = (REF_W - TOTAL_W) / 2.0; // 196
const START_Y: f64 = (REF_H - LETTER_H) / 2.0; // 288

// Background color
const BG: i32 = 0x0a0a1a;

// ── Precomputed SDF buffer ────────────────────────────────────────────

const BUF_W: usize = @intFromFloat(REF_W);
const BUF_H: usize = @intFromFloat(REF_H);
const BUF_LEN: usize = BUF_W * BUF_H;

var sdf_dist_buf: [BUF_LEN]f32 = undefined;
var sdf_letter_buf: [BUF_LEN]i8 = undefined;
var sdf_initialized: bool = false;

fn initSdf() void {
    for (0..BUF_H) |row| {
        const py: f64 = @floatFromInt(row);
        const off = row * BUF_W;
        for (0..BUF_W) |col| {
            const px: f64 = @floatFromInt(col);
            const result = textSdf(px, py);
            sdf_dist_buf[off + col] = @floatCast(result.dist);
            sdf_letter_buf[off + col] = @intCast(result.letter);
        }
    }
    sdf_initialized = true;
}

fn lookupSdf(px: f64, py: f64) SdfResult {
    const col: usize = @intFromFloat(@max(0.0, @min(REF_W - 1.0, px)));
    const row: usize = @intFromFloat(@max(0.0, @min(REF_H - 1.0, py)));
    const idx = row * BUF_W + col;
    return .{
        .dist = @floatCast(sdf_dist_buf[idx]),
        .letter = @intCast(sdf_letter_buf[idx]),
    };
}

// ── SDF core ───────────────────────────────────────────────────────────

const SdfResult = struct { dist: f64, letter: i32 };

fn letterX(li: u32) f64 {
    return START_X + @as(f64, @floatFromInt(li)) * (LETTER_W + GAP);
}

/// Signed distance from point (px, py) to the VEXEL text.
/// Negative = inside a letter, positive = outside.
fn textSdf(px: f64, py: f64) SdfResult {
    var best_dist: f64 = 1e9;
    var best_letter: i32 = -1;

    // Check each letter (with early skip based on x distance to letter bbox)
    for (0..NUM_LETTERS) |li| {
        const lx = letterX(@intCast(li));
        // Quick reject: if pixel is far from this letter's x range, skip
        const dx_to_letter = if (px < lx) lx - px else if (px > lx + LETTER_W) px - (lx + LETTER_W) else 0.0;
        if (dx_to_letter > best_dist) continue;

        const glyph = &glyphs[letter_glyph[li]];
        for (0..ROWS) |r| {
            const row_bits = glyph[r];
            if (row_bits == 0) continue;
            const cy = START_Y + @as(f64, @floatFromInt(r)) * SCALE + HALF;

            for (0..COLS) |c| {
                // Bit 6 = col 0, bit 0 = col 6
                if (row_bits & (@as(u8, 1) << @intCast(6 - c)) == 0) continue;

                const cx = lx + @as(f64, @floatFromInt(c)) * SCALE + HALF;

                // Signed box distance
                const dx = @abs(px - cx) - HALF;
                const dy = @abs(py - cy) - HALF;
                const outside = @sqrt(@max(dx, 0.0) * @max(dx, 0.0) + @max(dy, 0.0) * @max(dy, 0.0));
                const inside = @min(@max(dx, dy), 0.0);
                const sd = outside + inside;

                if (sd < best_dist) {
                    best_dist = sd;
                    best_letter = @intCast(li);
                }
            }
        }
    }

    return .{ .dist = best_dist, .letter = best_letter };
}

// ── Helpers ────────────────────────────────────────────────────────────

fn clamp01(x: f64) f64 {
    return @max(0.0, @min(1.0, x));
}

fn lerp(a: f64, b: f64, t: f64) f64 {
    return a + (b - a) * t;
}

fn packRgb(r: f64, g: f64, b: f64) i32 {
    const ri: i32 = @intFromFloat(clamp01(r) * 255.0);
    const gi: i32 = @intFromFloat(clamp01(g) * 255.0);
    const bi: i32 = @intFromFloat(clamp01(b) * 255.0);
    return ri * 65536 + gi * 256 + bi;
}

fn hash(x: f64, y: f64) f64 {
    const v = @sin(x * 12.9898 + y * 78.233) * 43758.5453;
    return v - @floor(v);
}

fn hsvToRgb(h_in: f64, s: f64, v: f64) [3]f64 {
    var h = h_in - @floor(h_in); // fract
    if (h < 0) h += 1.0;
    const i: u32 = @intFromFloat(h * 6.0);
    const f = h * 6.0 - @as(f64, @floatFromInt(i));
    const p = v * (1.0 - s);
    const q = v * (1.0 - f * s);
    const t = v * (1.0 - (1.0 - f) * s);
    return switch (i % 6) {
        0 => .{ v, t, p },
        1 => .{ q, v, p },
        2 => .{ p, v, t },
        3 => .{ p, q, v },
        4 => .{ t, p, v },
        else => .{ v, p, q },
    };
}

/// Fade envelope: 0→1 over first 10% of progress, 1→0 over last 10%.
fn fadeEnvelope(progress: f64) f64 {
    if (progress < 0.1) return progress / 0.1;
    if (progress > 0.9) return (1.0 - progress) / 0.1;
    return 1.0;
}

// ── Phase renderers ────────────────────────────────────────────────────

fn phaseReveal(sdf: SdfResult, progress: f64) i32 {
    const threshold = lerp(120.0, -4.0, progress);
    const dist = sdf.dist;

    if (dist > threshold) return BG;

    // Frontier glow band (6px wide)
    const frontier = clamp01(1.0 - (threshold - dist) / 6.0);
    if (frontier > 0.01) {
        // White → cyan gradient at the frontier
        const r = lerp(0.27, 1.0, frontier);
        const g = lerp(0.73, 1.0, frontier);
        const b = lerp(1.0, 1.0, frontier);
        return packRgb(r, g, b);
    }

    // Interior: solid cyan
    if (dist < 0.0) return 0x44BBFF;

    return BG;
}

fn phaseNeonGlow(sdf: SdfResult, time: f64) i32 {
    const dist = sdf.dist;
    const li: f64 = @floatFromInt(sdf.letter);

    if (dist < 0.0) {
        // Interior: pulsing brightness per letter
        const pulse = 0.75 + 0.25 * @sin(time * 3.0 - li * 0.8);
        return packRgb(0.267 * pulse, 0.733 * pulse, 1.0 * pulse);
    }

    // Exterior: glow rings
    const falloff = @exp(-dist * 0.06);
    if (falloff < 0.01) return BG;

    // Animated ring pattern
    const ring = 0.5 + 0.5 * @sin(dist * 0.25 - time * 2.5 + li * 1.2);
    const intensity = falloff * ring;

    // Dark blue → bright cyan
    const r = 0.067 + intensity * 0.2;
    const g = 0.133 + intensity * 0.55;
    const b = 0.267 + intensity * 0.73;
    return packRgb(r, g, b);
}

fn phasePlasma(px: f64, py: f64, sdf: SdfResult, time: f64) i32 {
    const dist = sdf.dist;

    // Only render near/inside letters
    if (dist > 12.0) return BG;

    // Classic 4-frequency plasma
    const v1 = @sin(px * 0.02 + time * 1.1);
    const v2 = @sin(py * 0.03 - time * 0.7);
    const v3 = @sin((px + py) * 0.015 + time * 0.5);
    const hyp = @sqrt(px * px + py * py);
    const v4 = @sin(hyp * 0.008 - time * 1.3);
    const plasma = (v1 + v2 + v3 + v4 + 4.0) / 8.0; // normalize to [0, 1]

    const hue = plasma + time * 0.08;
    const rgb = hsvToRgb(hue, 0.85, 0.95);

    if (dist < 0.0) {
        // Full plasma inside
        return packRgb(rgb[0], rgb[1], rgb[2]);
    }

    // Glow bleed outside (0 < dist < 12)
    const bleed = @exp(-dist * 0.25);
    return packRgb(rgb[0] * bleed, rgb[1] * bleed, rgb[2] * bleed);
}

fn phaseChromatic(px: f64, py: f64, time: f64) i32 {
    const offset = @sin(time * 2.0) * 10.0;

    // Sample precomputed SDF at three offset positions for R, G, B
    const sdf_r = lookupSdf(px - offset, py);
    const sdf_g = lookupSdf(px, py);
    const sdf_b = lookupSdf(px + offset, py);

    // Edge width for glow
    const edge = 5.0;

    // Channel intensity from SDF: inside=1, edge glow, outside=0
    const r_raw = clamp01(1.0 - sdf_r.dist / edge);
    const g_raw = clamp01(1.0 - sdf_g.dist / edge);
    const b_raw = clamp01(1.0 - sdf_b.dist / edge);

    if (r_raw < 0.01 and g_raw < 0.01 and b_raw < 0.01) return BG;

    // Per-channel hue modulation (120 degrees apart) for color variety
    const rm = 0.65 + 0.35 * @sin(time * 1.5);
    const gm = 0.65 + 0.35 * @sin(time * 1.5 + 2.094);
    const bm = 0.65 + 0.35 * @sin(time * 1.5 + 4.189);

    return packRgb(r_raw * rm, g_raw * gm, b_raw * bm);
}

fn phaseCrt(px: f64, py: f64, sdf: SdfResult, time: f64) i32 {
    // Horizontal glitch displacement
    var gpx = px;
    const row_bucket = @floor(py / 30.0);
    const glitch_hash = hash(row_bucket, @floor(time * 6.0));
    if (glitch_hash > 0.82) {
        gpx += (hash(row_bucket, @floor(time * 12.0)) - 0.5) * 50.0;
    }

    // Re-evaluate SDF with displaced coords if glitch active
    const eff_dist = if (gpx != px) lookupSdf(gpx, py).dist else sdf.dist;

    // Base: inside = letter color, outside = very dark
    var r: f64 = 0.0;
    var g: f64 = 0.0;
    var b: f64 = 0.0;

    if (eff_dist < 0.0) {
        // Cyan base
        r = 0.267;
        g = 0.733;
        b = 1.0;
    } else if (eff_dist < 3.0) {
        // Slight edge glow
        const edge = 1.0 - eff_dist / 3.0;
        r = 0.267 * edge;
        g = 0.733 * edge;
        b = 1.0 * edge;
    } else {
        // Dark background with faint noise
        const noise = hash(px * 0.1, py * 0.1 + time) * 0.03;
        return packRgb(0.04 + noise, 0.04 + noise, 0.1 + noise);
    }

    // Scanline darkening
    const scanline = 0.65 + 0.35 * @cos(py * math.pi);
    r *= scanline;
    g *= scanline;
    b *= scanline;

    // Phosphor sub-pixel coloring: every 3rd column boosts one channel
    const col_mod = @as(u32, @intFromFloat(@mod(@abs(gpx), 3.0)));
    switch (col_mod) {
        0 => {
            r *= 1.4;
            g *= 0.8;
            b *= 0.8;
        },
        1 => {
            r *= 0.8;
            g *= 1.4;
            b *= 0.8;
        },
        else => {
            r *= 0.8;
            g *= 0.8;
            b *= 1.4;
        },
    }

    // Vignette
    const ux = (px / REF_W) * 2.0 - 1.0;
    const uy = (py / REF_H) * 2.0 - 1.0;
    const vignette = 1.0 - 0.5 * (ux * ux + uy * uy);
    r *= vignette;
    g *= vignette;
    b *= vignette;

    // Occasional color flash (rare)
    const flash = hash(3.7, @floor(time * 4.0));
    if (flash > 0.93 and eff_dist < 0.0) {
        // Brief warm shift
        r = @min(r * 1.5, 1.0);
        g *= 0.7;
    }

    return packRgb(r, g, b);
}

// ── Entry point ────────────────────────────────────────────────────────

pub fn render_pixel(px: f64, py: f64, _: f64, _: f64, time: f64, phase_f: f64, progress: f64) i32 {
    if (!sdf_initialized) initSdf();

    const phase: u32 = @intFromFloat(@min(4.0, @max(0.0, phase_f)));
    const fade = fadeEnvelope(progress);

    // Lookup precomputed SDF (chromatic phase does its own offset lookups)
    const sdf = if (phase != 3) lookupSdf(px, py) else SdfResult{ .dist = 0, .letter = 0 };

    const raw = switch (phase) {
        0 => phaseReveal(sdf, progress),
        1 => phaseNeonGlow(sdf, time),
        2 => phasePlasma(px, py, sdf, time),
        3 => phaseChromatic(px, py, time),
        4 => phaseCrt(px, py, sdf, time),
        else => BG,
    };

    // Apply fade envelope
    if (fade >= 0.999) return raw;

    const ri: f64 = @floatFromInt((raw >> 16) & 0xFF);
    const gi: f64 = @floatFromInt((raw >> 8) & 0xFF);
    const bi: f64 = @floatFromInt(raw & 0xFF);
    return packRgb(ri / 255.0 * fade, gi / 255.0 * fade, bi / 255.0 * fade);
}
