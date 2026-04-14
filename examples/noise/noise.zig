/// 2D simplex noise — registered into Lua via vexel.App.registerModule.
///
/// Single pub function with scalar args, auto-wrapped by lua_bind.

const F2: f64 = 0.5 * (@sqrt(3.0) - 1.0);
const G2: f64 = (3.0 - @sqrt(3.0)) / 6.0;

const grad = [12][2]f64{
    .{ 1, 1 },  .{ -1, 1 },  .{ 1, -1 },  .{ -1, -1 },
    .{ 1, 0 },  .{ -1, 0 },  .{ 0, 1 },   .{ 0, -1 },
    .{ 1, 1 },  .{ -1, 1 },  .{ 1, -1 },  .{ -1, -1 },
};

const perm = blk: {
    const p = [256]u8{
        151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225,
        140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148,
        247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32,
        57, 177, 33, 88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68, 175,
        74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83, 111, 229, 122,
        60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54,
        65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132, 187, 208, 89, 18, 169,
        200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186, 3, 64,
        52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85, 212,
        207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183, 170, 213,
        119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172, 9,
        129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112, 104,
        218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162, 241,
        81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106, 157,
        184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93,
        222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180,
    };
    var table: [512]u8 = undefined;
    for (0..512) |i| table[i] = p[i & 255];
    break :blk table;
};

pub fn simplex2d(xin: f64, yin: f64) f64 {
    const s = (xin + yin) * F2;
    const i: i32 = @intFromFloat(@floor(xin + s));
    const j: i32 = @intFromFloat(@floor(yin + s));

    const t: f64 = @as(f64, @floatFromInt(i + j)) * G2;
    const x0 = xin - (@as(f64, @floatFromInt(i)) - t);
    const y0 = yin - (@as(f64, @floatFromInt(j)) - t);

    const di: i32 = if (x0 > y0) 1 else 0;
    const dj: i32 = if (x0 > y0) 0 else 1;

    const x1 = x0 - @as(f64, @floatFromInt(di)) + G2;
    const y1 = y0 - @as(f64, @floatFromInt(dj)) + G2;
    const x2 = x0 - 1.0 + 2.0 * G2;
    const y2 = y0 - 1.0 + 2.0 * G2;

    const ii: usize = @intCast(i & 255);
    const jj: usize = @intCast(j & 255);

    var n: f64 = 0;

    var d = 0.5 - x0 * x0 - y0 * y0;
    if (d > 0) {
        d *= d;
        const gi = perm[ii + perm[jj]] % 12;
        n += d * d * (grad[gi][0] * x0 + grad[gi][1] * y0);
    }

    d = 0.5 - x1 * x1 - y1 * y1;
    if (d > 0) {
        d *= d;
        const gi = perm[@as(usize, @intCast(@as(i32, @intCast(ii)) + di)) + perm[@as(usize, @intCast(@as(i32, @intCast(jj)) + dj))]] % 12;
        n += d * d * (grad[gi][0] * x1 + grad[gi][1] * y1);
    }

    d = 0.5 - x2 * x2 - y2 * y2;
    if (d > 0) {
        d *= d;
        const gi = perm[@as(usize, @intCast(@as(i32, @intCast(ii)) + 1)) + perm[@as(usize, @intCast(@as(i32, @intCast(jj)) + 1))]] % 12;
        n += d * d * (grad[gi][0] * x2 + grad[gi][1] * y2);
    }

    return 70.0 * n;
}
