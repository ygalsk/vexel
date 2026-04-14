const std = @import("std");
const vaxis = @import("vaxis");

const Kitty = @This();

allocator: std.mem.Allocator,
vx: *vaxis.Vaxis,
writer: *std.io.Writer,
encode_buf: []u8,
next_file_id: u32,
use_shm: bool,

/// Image IDs for file-based uploads start here to avoid collisions with vaxis's sequential IDs.
const FILE_ID_BASE: u32 = 0x40000000;

const SHM_PREFIX = "/dev/shm/vexel-";

pub fn init(allocator: std.mem.Allocator, vx: *vaxis.Vaxis, writer: *std.io.Writer) !Kitty {
    const initial_size = comptime std.base64.standard.Encoder.calcSize(320 * 180 * 4);
    const buf = try allocator.alloc(u8, initial_size);

    // File-based upload (t=t) requires the terminal to read from the local
    // filesystem. Currently only Kitty supports this — Ghostty, WezTerm, etc.
    // support Kitty graphics protocol but only via inline data (t=d).
    // We check two things:
    //   1. /dev/shm is writable (filesystem capability — fails on macOS, containers)
    //   2. Terminal is Kitty (protocol capability — only Kitty reads temp files)
    const shm_available = blk: {
        const probe = std.fs.createFileAbsolute("/dev/shm/vexel-probe", .{}) catch break :blk false;
        probe.close();
        std.fs.deleteFileAbsolute("/dev/shm/vexel-probe") catch {};
        break :blk true;
    };
    const supports_file_upload = std.posix.getenv("KITTY_WINDOW_ID") != null or
        std.posix.getenv("KITTY_PID") != null;

    // Clean up any leftover shm files from previous crashes
    cleanupShmFiles();

    const use_shm = shm_available and supports_file_upload;
    if (!use_shm) {
        var diag_buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&diag_buf, "vexel: shm disabled (shm_available={}, kitty_env={})\n", .{ shm_available, supports_file_upload }) catch "vexel: shm disabled\n";
        std.fs.File.stderr().writeAll(msg) catch {};
    }

    return .{
        .allocator = allocator,
        .vx = vx,
        .writer = writer,
        .encode_buf = buf,
        .next_file_id = FILE_ID_BASE,
        .use_shm = use_shm,
    };
}

pub fn deinit(self: *Kitty) void {
    self.allocator.free(self.encode_buf);
    cleanupShmFiles();
}

/// Check if the terminal supports kitty graphics protocol.
pub fn isSupported(self: *const Kitty) bool {
    return self.vx.caps.kitty_graphics;
}

/// Upload raw RGBA pixel data. Tries /dev/shm file transfer first, falls back to base64.
/// On first shm failure, permanently disables shm to avoid retrying every frame.
pub fn uploadRgba(self: *Kitty, pixels: []const u8, width: u16, height: u16) !vaxis.Image {
    if (self.use_shm) {
        return self.uploadViaFile(pixels, width, height) catch |err| {
            self.use_shm = false; // terminal doesn't support t=t — stop trying
            var buf: [128]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "vexel: shm upload failed ({}), falling back to base64\n", .{err}) catch "vexel: shm upload failed\n";
            std.fs.File.stderr().writeAll(msg) catch {};
            return self.uploadViaBase64(pixels, width, height);
        };
    }
    return self.uploadViaBase64(pixels, width, height);
}

/// File-based upload: write pixels to /dev/shm (RAM-backed), send ~80 byte escape.
/// Each upload gets a unique filename (using the image ID) so multiple uploads
/// per frame don't race — the terminal may batch-read from the pty.
fn uploadViaFile(self: *Kitty, pixels: []const u8, width: u16, height: u16) !vaxis.Image {
    const id = self.next_file_id;
    self.next_file_id +%= 1;

    // Build path: /dev/shm/vexel-{id}
    var path_buf: [48]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, SHM_PREFIX ++ "{d}", .{id}) catch {
        logShm("bufPrint failed");
        return error.Unexpected;
    };

    const file = std.fs.createFileAbsolute(path, .{}) catch {
        logShm("createFile failed");
        return error.Unexpected;
    };
    defer file.close();
    file.writeAll(pixels) catch {
        logShm("writeAll failed");
        return error.Unexpected;
    };

    // Base64-encode the path dynamically
    var b64_buf: [68]u8 = undefined; // 48 bytes -> 64 base64 chars
    const encoded_path = std.base64.standard.Encoder.encode(&b64_buf, path);

    // Kitty protocol: f=32 (RGBA), t=t (temp file — kitty deletes after reading)
    self.writer.print(
        "\x1b_Gf=32,s={d},v={d},i={d},t=t,S={d};{s}\x1b\\",
        .{ width, height, id, pixels.len, encoded_path },
    ) catch {
        logShm("writer.print failed");
        return error.Unexpected;
    };
    self.writer.flush() catch {};

    return .{
        .id = id,
        .width = width,
        .height = height,
    };
}

fn logShm(msg: []const u8) void {
    var buf: [128]u8 = undefined;
    const s = std.fmt.bufPrint(&buf, "vexel: shm: {s}\n", .{msg}) catch return;
    std.fs.File.stderr().writeAll(s) catch {};
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

/// Remove any leftover /dev/shm/vexel-* files from previous runs or crashes.
fn cleanupShmFiles() void {
    var dir = std.fs.openDirAbsolute("/dev/shm", .{ .iterate = true }) catch return;
    defer dir.close();
    var it = dir.iterate();
    while (it.next() catch null) |entry| {
        if (std.mem.startsWith(u8, entry.name, "vexel-")) {
            dir.deleteFile(entry.name) catch {};
        }
    }
}

test "calcSize for small buffer" {
    const size = std.base64.standard.Encoder.calcSize(16);
    try std.testing.expect(size > 0);
}
