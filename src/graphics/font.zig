const std = @import("std");
const Compositing = @import("compositing");
const Color = Compositing.Color;
const TrueType = @import("TrueType");

pub const GlyphMetric = struct {
    x: u16,
    y: u16,
    glyph_w: u8,
    height: u8,
    /// Positive = below baseline; negative = above baseline (typical for ascenders).
    y_offset: i8,
    /// Cursor advance width. May differ from glyph_w for proportional fonts.
    width: u8,
};

pub const DrawOpts = struct {
    /// Maximum pixel width before wrapping. null = no limit.
    width: ?u16 = null,
    alignment: Align = .left,
    wrap: Wrap = .none,

    pub const Align = enum { left, center, right };
    pub const Wrap = enum { word, char, none };
};

pub const FontAtlas = struct {
    allocator: std.mem.Allocator,
    /// Flat RGBA pixel data for the atlas texture.
    pixels: []u8,
    atlas_w: u16,
    atlas_h: u16,
    /// Per-glyph metrics, indexed by codepoint − 0x20. Only ASCII 0x20..0x7F.
    glyphs: [96]GlyphMetric,
    glyph_h: u16,
    line_height: u16,

    /// Build a FontAtlas from a flat RGBA bitmap laid out as a grid of fixed-size
    /// glyphs starting at ASCII 0x20 (' '), row-major.
    ///
    /// The bitmap must be exactly cols*glyph_w wide and rows*glyph_h tall where
    /// cols*rows >= 96 (covers 0x20..0x7F).
    pub fn loadFromBitmap(
        allocator: std.mem.Allocator,
        rgba: []const u8,
        bitmap_w: u16,
        bitmap_h: u16,
        glyph_w: u8,
        glyph_h: u8,
    ) !FontAtlas {
        const cols: u16 = @divFloor(bitmap_w, glyph_w);
        if (cols == 0) return error.InvalidGlyphSize;
        const rows: u16 = @divFloor(bitmap_h, glyph_h);
        if (@as(u32, cols) * @as(u32, rows) < 96) return error.BitmapTooSmall;
        const pixels = try allocator.dupe(u8, rgba);
        errdefer allocator.free(pixels);

        var glyphs: [96]GlyphMetric = undefined;
        for (0..96) |i| {
            const col: u16 = @intCast(i % cols);
            const row: u16 = @intCast(i / cols);
            glyphs[i] = .{
                .x = col * glyph_w,
                .y = row * glyph_h,
                .glyph_w = glyph_w,
                .height = glyph_h,
                .y_offset = 0,
                .width = glyph_w,
            };
        }

        return .{
            .allocator = allocator,
            .pixels = pixels,
            .atlas_w = bitmap_w,
            .atlas_h = bitmap_h,
            .glyphs = glyphs,
            .glyph_h = glyph_h,
            .line_height = glyph_h,
        };
    }

    /// Build a FontAtlas by rasterizing a TrueType/OpenType font at a given pixel height.
    /// Covers ASCII codepoints 0x20..0x7E (95 glyphs; slot 95 reserved for DEL/unused).
    /// Atlas pixels are RGBA: white (255,255,255) with alpha from the rasterizer.
    pub fn loadFromTtf(
        allocator: std.mem.Allocator,
        ttf_data: []const u8,
        pixel_height: u16,
    ) !FontAtlas {
        const tt = try TrueType.load(ttf_data);
        const scale = tt.scaleForPixelHeight(@floatFromInt(pixel_height));

        const vm = tt.verticalMetrics();
        // ascent/descent are in font units; scale to pixels
        const ascent: i32 = @intFromFloat(@round(@as(f32, @floatFromInt(vm.ascent)) * scale));
        const descent: i32 = @intFromFloat(@round(@as(f32, @floatFromInt(vm.descent)) * scale));
        const line_h: u16 = @intCast(@max(0, ascent - descent));

        // --- Pass 1: rasterize all glyphs, collect metrics ---
        const GLYPH_COUNT = 96;
        const GlyphData = struct {
            pixels_start: usize, // byte offset into raw_alpha
            bm: TrueType.GlyphBitmap,
            advance: u8,
            y_offset: i8,
        };

        var glyph_data: [GLYPH_COUNT]GlyphData = undefined;
        var raw_alpha = std.ArrayListUnmanaged(u8){};
        defer raw_alpha.deinit(allocator);

        var total_area: usize = 0;
        for (0..GLYPH_COUNT) |i| {
            const cp: u21 = @intCast(0x20 + i);
            const glyph_idx = tt.codepointGlyphIndex(cp);
            const start = raw_alpha.items.len;

            const bm = TrueType.glyphBitmap(&tt, allocator, &raw_alpha, glyph_idx, scale, scale) catch |err| switch (err) {
                error.GlyphNotFound => TrueType.GlyphBitmap.empty,
                else => return err,
            };

            const hm = TrueType.glyphHMetrics(&tt, glyph_idx);
            const advance_f: f32 = @as(f32, @floatFromInt(hm.advance_width)) * scale;
            const advance: u8 = @intCast(@min(255, @max(1, @as(i32, @intFromFloat(@round(advance_f))))));

            // y_offset: bearing from draw cursor (top of cell = ascent line).
            // off_y from TrueType is the pixel-space offset from glyph origin to top of bitmap.
            // The cursor y we pass to drawText is the top of the cell.
            // We want: glyph top = cursor_y + ascent + off_y
            // (off_y is typically negative, e.g. -10 for a cap letter at size 12)
            const y_off_i: i32 = ascent + @as(i32, bm.off_y);
            const y_offset: i8 = @intCast(std.math.clamp(y_off_i, -128, 127));

            glyph_data[i] = .{
                .pixels_start = start,
                .bm = bm,
                .advance = advance,
                .y_offset = y_offset,
            };
            total_area += @as(usize, bm.width) * @as(usize, bm.height);
        }

        // --- Atlas sizing: square-ish, power-of-two width ---
        // Start from sqrt(total_area) rounded up to next power of two, min 64.
        const min_side = @max(64, std.math.sqrt(total_area) + 1);
        var atlas_w: u16 = 64;
        while (atlas_w < min_side) atlas_w *= 2;
        // Height: simulate packing to find required height, then round up.
        const atlas_h: u16 = blk: {
            var row_x: u16 = 0;
            var row_y: u16 = 0;
            var row_h: u16 = 0;
            for (glyph_data) |gd| {
                const gw: u16 = @intCast(gd.bm.width);
                const gh: u16 = @intCast(gd.bm.height);
                if (gw == 0 or gh == 0) continue;
                if (row_x + gw > atlas_w) {
                    row_y += row_h + 1;
                    row_x = 0;
                    row_h = 0;
                }
                row_x += gw + 1;
                row_h = @max(row_h, gh);
            }
            const h: u16 = row_y + row_h + 1;
            // Round up to power of two, min 64
            var ph: u16 = 64;
            while (ph < h) ph *= 2;
            break :blk ph;
        };

        // --- Allocate atlas RGBA buffer ---
        const atlas_pixels = try allocator.alloc(u8, @as(usize, atlas_w) * @as(usize, atlas_h) * 4);
        errdefer allocator.free(atlas_pixels);
        @memset(atlas_pixels, 0);

        // --- Pass 2: pack glyphs into atlas ---
        var glyphs: [GLYPH_COUNT]GlyphMetric = undefined;
        var row_x: u16 = 0;
        var row_y: u16 = 0;
        var row_h: u16 = 0;
        const atlas_stride: usize = @as(usize, atlas_w) * 4;

        for (0..GLYPH_COUNT) |i| {
            const gd = glyph_data[i];
            const gw: u16 = @intCast(gd.bm.width);
            const gh: u16 = @intCast(gd.bm.height);

            if (gw == 0 or gh == 0) {
                // Empty glyph (space etc.) — no pixels to pack
                glyphs[i] = .{
                    .x = 0,
                    .y = 0,
                    .glyph_w = 0,
                    .height = 0,
                    .y_offset = 0,
                    .width = gd.advance,
                };
                continue;
            }

            if (row_x + gw > atlas_w) {
                row_y += row_h + 1;
                row_x = 0;
                row_h = 0;
            }

            // Write alpha pixels into atlas as RGBA (white * alpha)
            const alpha_slice = raw_alpha.items[gd.pixels_start..][0 .. @as(usize, gw) * @as(usize, gh)];
            for (0..gh) |py| {
                const dst_row = (row_y + py) * atlas_stride;
                for (0..gw) |px| {
                    const a = alpha_slice[py * gw + px];
                    const dst = dst_row + (row_x + px) * 4;
                    @as(*align(1) u32, @ptrCast(&atlas_pixels[dst])).* = 0x00FFFFFF | (@as(u32, a) << 24);
                }
            }

            glyphs[i] = .{
                .x = row_x,
                .y = row_y,
                .glyph_w = @intCast(gw),
                .height = @intCast(gh),
                .y_offset = gd.y_offset,
                .width = gd.advance,
            };

            row_x += gw + 1;
            row_h = @max(row_h, gh);
        }

        return .{
            .allocator = allocator,
            .pixels = atlas_pixels,
            .atlas_w = atlas_w,
            .atlas_h = atlas_h,
            .glyphs = glyphs,
            .glyph_h = @intCast(pixel_height),
            .line_height = line_h,
        };
    }

    pub fn deinit(self: *FontAtlas) void {
        self.allocator.free(self.pixels);
    }

    /// Return the pixel width of a single line of text (no wrapping).
    pub fn measureText(self: *const FontAtlas, text: []const u8) u16 {
        var w: u16 = 0;
        for (text) |ch| {
            if (ch < 0x20 or ch > 0x7F) continue;
            w +|= self.glyphs[ch - 0x20].width;
        }
        return w;
    }

    /// Render text onto the compositor's active layer.
    pub fn drawText(
        self: *const FontAtlas,
        comp: *Compositing,
        x: i32,
        y: i32,
        text: []const u8,
        color: Color,
        opts: DrawOpts,
    ) void {
        var cursor_y: i32 = y;
        const max_w: ?u16 = opts.width;

        var cursor_x: i32 = alignedLineX(self, text, 0, x, opts.alignment, max_w, opts.wrap);
        // pixels_used: content pixels placed on current line, for wrap threshold checks.
        // Tracked separately from cursor_x so alignment offset doesn't skew the comparison.
        var pixels_used: u16 = 0;

        var i: usize = 0;
        while (i < text.len) {
            if (text[i] == '\n') {
                cursor_y += self.line_height;
                i += 1;
                cursor_x = alignedLineX(self, text, i, x, opts.alignment, max_w, opts.wrap);
                pixels_used = 0;
                continue;
            }

            if (opts.wrap == .word and max_w != null) {
                const mw = max_w.?;
                const word_end_idx = wordEnd(text, i);
                const word_w = self.measureText(text[i..word_end_idx]);
                if (pixels_used > 0 and @as(u32, pixels_used) + @as(u32, word_w) > @as(u32, mw)) {
                    cursor_y += self.line_height;
                    if (text[i] == ' ') i += 1;
                    cursor_x = alignedLineX(self, text, i, x, opts.alignment, max_w, opts.wrap);
                    pixels_used = 0;
                    continue;
                }
            }

            const ch = text[i];
            i += 1;

            if (ch < 0x20 or ch > 0x7F) continue;

            const g = self.glyphs[ch - 0x20];

            if (opts.wrap == .char and max_w != null) {
                const mw = max_w.?;
                if (pixels_used > 0 and @as(u32, pixels_used) + @as(u32, g.width) > @as(u32, mw)) {
                    cursor_y += self.line_height;
                    cursor_x = alignedLineX(self, text, i - 1, x, opts.alignment, max_w, opts.wrap);
                    pixels_used = 0;
                }
            }

            self.blitGlyph(comp, cursor_x, cursor_y, g, color);
            cursor_x += g.width;
            pixels_used +|= g.width;
        }
    }

    /// Blit a single glyph onto the active compositor layer, applying color tint.
    /// Atlas pixels are treated as a mask: only the alpha channel is used.
    fn blitGlyph(
        self: *const FontAtlas,
        comp: *Compositing,
        dst_x: i32,
        dst_y: i32,
        g: GlyphMetric,
        tint: Color,
    ) void {
        if (g.glyph_w == 0 or g.height == 0) return;
        const glyph_top: i32 = dst_y + @as(i32, g.y_offset);
        comp.blitAlphaMask(
            self.pixels,
            @as(usize, self.atlas_w) * 4,
            @as(i32, g.x),
            @as(i32, g.y),
            @as(i32, g.glyph_w),
            @as(i32, g.height),
            dst_x,
            glyph_top,
            tint,
        );
    }
};

/// Return the slice of text that forms the first visual line (for alignment pre-measure).
/// Uses the same wrap rules as drawText to find where the first break occurs.
fn firstLineText(text: []const u8, atlas: *const FontAtlas, max_w: u16, wrap: DrawOpts.Wrap) []const u8 {
    if (wrap == .none) return text;
    var w: u16 = 0;
    var i: usize = 0;
    while (i < text.len) {
        const ch = text[i];
        if (ch == '\n') return text[0..i];
        if (ch < 0x20 or ch > 0x7F) {
            i += 1;
            continue;
        }
        const gw = atlas.glyphs[ch - 0x20].width;
        if (wrap == .char and w > 0 and w + gw > max_w) return text[0..i];
        if (wrap == .word) {
            const word_end = wordEnd(text, i);
            const ww = atlas.measureText(text[i..word_end]);
            if (w > 0 and w + ww > max_w) return text[0..i];
        }
        w +|= gw;
        i += 1;
    }
    return text;
}

/// Return the index just past the next word (run of non-space chars starting at i).
fn wordEnd(text: []const u8, start: usize) usize {
    var i = start;
    // Include trailing space as part of word for measurement purposes
    while (i < text.len and text[i] != ' ' and text[i] != '\n') : (i += 1) {}
    return i;
}

/// Return the aligned starting x for the line of text beginning at `pos`.
/// For .left alignment this is always `base_x`; for .center/.right we measure
/// the first visual line and offset accordingly.
fn alignedLineX(
    atlas: *const FontAtlas,
    text: []const u8,
    pos: usize,
    base_x: i32,
    alignment: DrawOpts.Align,
    mw: ?u16,
    wrap: DrawOpts.Wrap,
) i32 {
    if (alignment == .left) return base_x;
    const line = firstLineText(text[pos..], atlas, mw orelse std.math.maxInt(u16), wrap);
    const lw = atlas.measureText(line);
    return switch (alignment) {
        .left => base_x,
        .center => if (mw) |w|
            base_x + @as(i32, w / 2) - @as(i32, lw / 2)
        else
            base_x - @as(i32, lw / 2),
        .right => if (mw) |w|
            base_x + @as(i32, w) - @as(i32, lw)
        else
            base_x - @as(i32, lw),
    };
}

// --- Tests ---

// Minimum valid bitmap: 128×64 with 8×8 glyphs → 16 cols × 8 rows = 128 slots ≥ 96.
fn makeTestAtlas() !FontAtlas {
    const pixels = try std.testing.allocator.alloc(u8, 128 * 64 * 4);
    defer std.testing.allocator.free(pixels);
    @memset(pixels, 0);
    return FontAtlas.loadFromBitmap(std.testing.allocator, pixels, 128, 64, 8, 8);
}

test "measureText basic" {
    var atlas = try makeTestAtlas();
    defer atlas.deinit();

    // Space (0x20) is glyph 0, width=8
    try std.testing.expectEqual(@as(u16, 8), atlas.measureText(" "));
    try std.testing.expectEqual(@as(u16, 24), atlas.measureText("   "));
}

test "measureText skips non-ASCII" {
    var atlas = try makeTestAtlas();
    defer atlas.deinit();

    try std.testing.expectEqual(@as(u16, 0), atlas.measureText("\x00\x01\xFF"));
}

test "loadFromBitmap rejects undersized bitmap" {
    // 16×8 with 8×8 glyphs → 2 cols × 1 row = 2 slots < 96
    var pixels = [_]u8{0} ** (16 * 8 * 4);
    const result = FontAtlas.loadFromBitmap(std.testing.allocator, &pixels, 16, 8, 8, 8);
    try std.testing.expectError(error.BitmapTooSmall, result);
}

test "loadFromBitmap glyph layout" {
    var atlas = try makeTestAtlas();
    defer atlas.deinit();

    // Glyph 0 (0x20 ' ') should be at (0,0)
    try std.testing.expectEqual(@as(u16, 0), atlas.glyphs[0].x);
    try std.testing.expectEqual(@as(u16, 0), atlas.glyphs[0].y);
    // Glyph 16 should be at (0, 8) — start of second row (16 cols per row)
    try std.testing.expectEqual(@as(u16, 0), atlas.glyphs[16].x);
    try std.testing.expectEqual(@as(u16, 8), atlas.glyphs[16].y);
    // Glyph 1 ('!') should be at (8, 0)
    try std.testing.expectEqual(@as(u16, 8), atlas.glyphs[1].x);
    try std.testing.expectEqual(@as(u16, 0), atlas.glyphs[1].y);
}
