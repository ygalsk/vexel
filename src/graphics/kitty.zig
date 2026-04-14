const std = @import("std");
const vaxis = @import("vaxis");

const Kitty = @This();

allocator: std.mem.Allocator,
vx: *vaxis.Vaxis,
writer: *std.io.Writer,
encode_buf: []u8,
next_file_id: u32,
file_idx: u1,
use_shm: bool,

/// Image IDs for file-based uploads start here to avoid collisions with vaxis's sequential IDs.
const FILE_ID_BASE: u32 = 0x40000000;

const SHM_PATHS = [2][]const u8{ "/dev/shm/vexel-frame-0", "/dev/shm/vexel-frame-1" };
const SHM_PATHS_B64 = blk: {
    var result: [2][std.base64.standard.Encoder.calcSize(SHM_PATHS[0].len)]u8 = undefined;
    for (SHM_PATHS, 0..) |path, i| {
        _ = std.base64.standard.Encoder.encode(&result[i], path);
    }
    break :blk result;
};

pub fn init(allocator: std.mem.Allocator, vx: *vaxis.Vaxis, writer: *std.io.Writer) !Kitty {
    const initial_size = comptime std.base64.standard.Encoder.calcSize(320 * 180 * 4);
    const buf = try allocator.alloc(u8, initial_size);

    return .{
        .allocator = allocator,
        .vx = vx,
        .writer = writer,
        .encode_buf = buf,
        .next_file_id = FILE_ID_BASE,
        .file_idx = 0,
        .use_shm = std.posix.getenv("KITTY_PID") != null,
    };
}

pub fn deinit(self: *Kitty) void {
    self.allocator.free(self.encode_buf);
    // Clean up any leftover temp files
    std.fs.deleteFileAbsolute(SHM_PATHS[0]) catch {};
    std.fs.deleteFileAbsolute(SHM_PATHS[1]) catch {};
}

/// Check if the terminal supports kitty graphics protocol.
pub fn isSupported(self: *const Kitty) bool {
    return self.vx.caps.kitty_graphics;
}

/// Upload raw RGBA pixel data. Uses /dev/shm file transfer on Kitty, base64 elsewhere.
pub fn uploadRgba(self: *Kitty, pixels: []const u8, width: u16, height: u16) !vaxis.Image {
    if (self.vx.caps.kitty_graphics and self.use_shm) {
        return self.uploadViaFile(pixels, width, height) catch
            self.uploadViaBase64(pixels, width, height);
    }
    return self.uploadViaBase64(pixels, width, height);
}

/// File-based upload: write pixels to /dev/shm (RAM-backed), send ~80 byte escape.
/// Double-buffered to avoid overwriting data kitty is still reading.
fn uploadViaFile(self: *Kitty, pixels: []const u8, width: u16, height: u16) !vaxis.Image {
    const idx = self.file_idx;
    self.file_idx +%= 1;

    const path = SHM_PATHS[idx];
    const file = std.fs.createFileAbsolute(path, .{}) catch return error.Unexpected;
    defer file.close();
    file.writeAll(pixels) catch return error.Unexpected;

    const id = self.next_file_id;
    self.next_file_id +%= 1;

    const encoded_path = &SHM_PATHS_B64[idx];

    // Kitty protocol: f=32 (RGBA), t=t (temp file — kitty deletes after reading)
    self.writer.print(
        "\x1b_Gf=32,s={d},v={d},i={d},t=t,S={d};{s}\x1b\\",
        .{ width, height, id, pixels.len, encoded_path },
    ) catch return error.Unexpected;
    self.writer.flush() catch {};

    return .{
        .id = id,
        .width = width,
        .height = height,
    };
}

/// Base64 upload fallback for terminals without file-based transmission.
fn uploadViaBase64(self: *Kitty, pixels: []const u8, width: u16, height: u16) !vaxis.Image {
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
    if (id >= FILE_ID_BASE) {
        self.writer.print("\x1b_Ga=d,d=I,i={d};\x1b\\", .{id}) catch return;
        self.writer.flush() catch {};
    } else {
        self.vx.freeImage(self.writer, id);
    }
}

test "calcSize for small buffer" {
    const size = std.base64.standard.Encoder.calcSize(16);
    try std.testing.expect(size > 0);
}
