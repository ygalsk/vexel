const std = @import("std");
const vaxis = @import("vaxis");

const Kitty = @This();

allocator: std.mem.Allocator,
vx: *vaxis.Vaxis,
writer: *std.io.Writer,
encode_buf: []u8,

pub fn init(allocator: std.mem.Allocator, vx: *vaxis.Vaxis, writer: *std.io.Writer) !Kitty {
    // Pre-allocate base64 buffer for default 320x180 RGBA
    const initial_size = comptime std.base64.standard.Encoder.calcSize(320 * 180 * 4);
    const buf = try allocator.alloc(u8, initial_size);

    return .{
        .allocator = allocator,
        .vx = vx,
        .writer = writer,
        .encode_buf = buf,
    };
}

pub fn deinit(self: *Kitty) void {
    self.allocator.free(self.encode_buf);
}

/// Check if the terminal supports kitty graphics protocol.
pub fn isSupported(self: *const Kitty) bool {
    return self.vx.caps.kitty_graphics;
}

/// Upload raw RGBA pixel data as a kitty graphics image.
/// The data is base64-encoded internally; vaxis handles chunked transmission.
pub fn uploadRgba(self: *Kitty, pixels: []const u8, width: u16, height: u16) !vaxis.Image {
    const needed = std.base64.standard.Encoder.calcSize(pixels.len);
    if (needed > self.encode_buf.len) {
        self.allocator.free(self.encode_buf);
        self.encode_buf = try self.allocator.alloc(u8, needed);
    }

    const encoded = std.base64.standard.Encoder.encode(self.encode_buf, pixels);
    return self.vx.transmitPreEncodedImage(self.writer, encoded, width, height, .rgba);
}

/// Free a previously uploaded image from terminal memory.
pub fn freeImage(self: *Kitty, id: u32) void {
    self.vx.freeImage(self.writer, id);
}

test "calcSize for small buffer" {
    const size = std.base64.standard.Encoder.calcSize(16);
    try std.testing.expect(size > 0);
}
