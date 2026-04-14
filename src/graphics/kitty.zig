const std = @import("std");
const vaxis = @import("vaxis");

const Kitty = @This();

const IoWriter = std.io.Writer;

/// Transport mode for uploading pixel data to the terminal.
/// Probed at startup via `probeTransport()` — no terminal-name detection.
pub const TransportMode = enum {
    posix_shm, // Kitty t=s: POSIX shared memory (zero-copy)
    tmpfile, // Kitty t=t: temp file in /dev/shm
    base64, // Kitty t=d: inline base64 (universal fallback)
};

allocator: std.mem.Allocator,
vx: *vaxis.Vaxis,
writer: *IoWriter,
encode_buf: []u8,
next_file_id: u32,
transport: TransportMode,

/// Image IDs for file-based uploads start here to avoid collisions with vaxis's sequential IDs.
const FILE_ID_BASE: u32 = 0x40000000;

/// Ghostty requires "tty-graphics-protocol" in the filename for t=t transport.
/// Kitty doesn't care about the name. This prefix satisfies both.
const SHM_PREFIX = "/dev/shm/tty-graphics-protocol-vexel-";

// Probe image IDs — outside normal range
const PROBE_ID_TT: u32 = 0x7FFFFFFE;
const PROBE_ID_TS: u32 = 0x7FFFFFFD;

pub fn init(allocator: std.mem.Allocator, vx: *vaxis.Vaxis, writer: *IoWriter, transport: TransportMode) !Kitty {
    const initial_size = comptime std.base64.standard.Encoder.calcSize(320 * 180 * 4);
    const buf = try allocator.alloc(u8, initial_size);

    return .{
        .allocator = allocator,
        .vx = vx,
        .writer = writer,
        .encode_buf = buf,
        .next_file_id = FILE_ID_BASE,
        .transport = transport,
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

// ── Transport probing ──────────────────────────────────────────────────

/// Detect the fastest supported Kitty graphics transport mode.
/// Sends 1×1 test images via each mode and checks for the terminal's ACK.
///
/// MUST be called before the vaxis event loop starts — requires exclusive
/// TTY read access. Call after tty.init() but before loop.start().
pub fn probeTransport(tty_fd: std.posix.fd_t, writer: *IoWriter) TransportMode {
    // /dev/shm required for both t=t and t=s
    const shm_ok = blk: {
        const f = std.fs.createFileAbsolute("/dev/shm/vexel-probe", .{}) catch break :blk false;
        f.close();
        std.fs.deleteFileAbsolute("/dev/shm/vexel-probe") catch {};
        break :blk true;
    };
    if (!shm_ok) {
        logTransport("no /dev/shm, using base64");
        return .base64;
    }

    // Drain any stale input before probing
    drainTty(tty_fd);

    // Probe t=t (temp file) — works with Kitty, likely Ghostty/WezTerm
    if (probeTmpfile(tty_fd, writer)) {
        logTransport("using tmpfile (t=t)");
        return .tmpfile;
    }

    // Probe t=s (POSIX shared memory) — WezTerm added this explicitly
    if (probePosixShm(tty_fd, writer)) {
        logTransport("using posix_shm (t=s)");
        return .posix_shm;
    }

    logTransport("using base64 (t=d)");
    return .base64;
}

/// Send a 1×1 probe image via the given transport mode and check for terminal ACK.
fn probeMode(
    tty_fd: std.posix.fd_t,
    writer: *IoWriter,
    comptime transport: []const u8,
    comptime file_path: []const u8,
    comptime payload: []const u8,
    probe_id: u32,
) bool {
    const pixel = [_]u8{ 0, 0, 0, 0 }; // 1×1 transparent RGBA

    const file = std.fs.createFileAbsolute(file_path, .{}) catch return false;
    file.writeAll(&pixel) catch {
        file.close();
        return false;
    };
    file.close();

    var b64_buf: [108]u8 = undefined;
    const encoded = std.base64.standard.Encoder.encode(&b64_buf, payload);

    writer.print(
        "\x1b_Gf=32,s=1,v=1,i={d},t=" ++ transport ++ ",S=4;{s}\x1b\\",
        .{ probe_id, encoded },
    ) catch return false;
    writer.flush() catch return false;

    const ok = readAck(tty_fd);

    // Delete probe image from terminal memory
    writer.print("\x1b_Ga=d,d=I,i={d};\x1b\\", .{probe_id}) catch {};
    writer.flush() catch {};

    // If terminal didn't consume the file, clean it up ourselves
    if (!ok) std.fs.deleteFileAbsolute(file_path) catch {};

    return ok;
}

fn probeTmpfile(tty_fd: std.posix.fd_t, writer: *IoWriter) bool {
    const path = "/dev/shm/tty-graphics-protocol-vexel-probe-tt";
    return probeMode(tty_fd, writer, "t", path, path, PROBE_ID_TT);
}

fn probePosixShm(tty_fd: std.posix.fd_t, writer: *IoWriter) bool {
    const shm_name = "/tty-graphics-protocol-vexel-probe-shm";
    return probeMode(tty_fd, writer, "s", "/dev/shm" ++ shm_name, shm_name, PROBE_ID_TS);
}

/// Read a Kitty graphics protocol response from the TTY.
/// Returns true if the response contains ";OK", false on error or timeout.
fn readAck(tty_fd: std.posix.fd_t) bool {
    var buf: [256]u8 = undefined;
    var total: usize = 0;

    // Poll up to 300ms total (3 × 100ms)
    for (0..3) |_| {
        var fds = [_]std.posix.pollfd{.{
            .fd = tty_fd,
            .events = std.posix.POLL.IN,
            .revents = 0,
        }};

        const ready = std.posix.poll(&fds, 100) catch return false;
        if (ready == 0) continue;

        if (fds[0].revents & std.posix.POLL.IN != 0) {
            const n = std.posix.read(tty_fd, buf[total..]) catch return false;
            if (n == 0) continue;
            total += n;

            const response = buf[0..total];
            if (std.mem.indexOf(u8, response, ";OK") != null) return true;
            // Got a complete APC response that isn't OK — fail fast
            if (std.mem.indexOf(u8, response, "\x1b\\") != null) return false;
        }
        if (total >= buf.len) break;
    }
    return false;
}

fn drainTty(tty_fd: std.posix.fd_t) void {
    var buf: [256]u8 = undefined;
    while (true) {
        var fds = [_]std.posix.pollfd{.{
            .fd = tty_fd,
            .events = std.posix.POLL.IN,
            .revents = 0,
        }};
        const ready = std.posix.poll(&fds, 0) catch return;
        if (ready == 0) return;
        _ = std.posix.read(tty_fd, &buf) catch return;
    }
}

fn logTransport(msg: []const u8) void {
    var buf: [128]u8 = undefined;
    const s = std.fmt.bufPrint(&buf, "vexel: transport: {s}\n", .{msg}) catch return;
    std.fs.File.stderr().writeAll(s) catch {};
}

// ── Upload paths ───────────────────────────────────────────────────────

/// Upload raw RGBA pixel data using the best available transport.
/// Falls back at runtime if a previously-working transport fails.
pub fn uploadRgba(self: *Kitty, pixels: []const u8, width: u16, height: u16) !vaxis.Image {
    switch (self.transport) {
        .posix_shm => {
            return self.uploadViaPosixShm(pixels, width, height) catch {
                self.transport = .tmpfile;
                return self.uploadViaFile(pixels, width, height) catch {
                    self.transport = .base64;
                    logTransport("shm+tmpfile failed at runtime, using base64");
                    return self.uploadViaBase64(pixels, width, height);
                };
            };
        },
        .tmpfile => {
            return self.uploadViaFile(pixels, width, height) catch {
                self.transport = .base64;
                logTransport("tmpfile failed at runtime, using base64");
                return self.uploadViaBase64(pixels, width, height);
            };
        },
        .base64 => return self.uploadViaBase64(pixels, width, height),
    }
}

/// t=t: Write pixels to /dev/shm, send ~80 byte escape with file path.
fn uploadViaFile(self: *Kitty, pixels: []const u8, width: u16, height: u16) !vaxis.Image {
    const id = self.next_file_id;
    self.next_file_id +%= 1;

    var path_buf: [80]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, SHM_PREFIX ++ "{d}", .{id}) catch return error.Unexpected;

    const file = std.fs.createFileAbsolute(path, .{}) catch return error.Unexpected;
    defer file.close();
    file.writeAll(pixels) catch return error.Unexpected;

    var b64_buf: [108]u8 = undefined;
    const encoded_path = std.base64.standard.Encoder.encode(&b64_buf, path);

    self.writer.print(
        "\x1b_Gf=32,s={d},v={d},i={d},t=t,S={d};{s}\x1b\\",
        .{ width, height, id, pixels.len, encoded_path },
    ) catch return error.Unexpected;
    self.writer.flush() catch {};

    return .{ .id = id, .width = width, .height = height };
}

/// t=s: Write pixels to /dev/shm, send escape with POSIX shm name.
fn uploadViaPosixShm(self: *Kitty, pixels: []const u8, width: u16, height: u16) !vaxis.Image {
    const id = self.next_file_id;
    self.next_file_id +%= 1;

    // POSIX shm name → maps to /dev/shm/... on Linux
    var name_buf: [64]u8 = undefined;
    const shm_name = std.fmt.bufPrint(&name_buf, "/tty-graphics-protocol-vexel-{d}", .{id}) catch return error.Unexpected;

    var path_buf: [80]u8 = undefined;
    const file_path = std.fmt.bufPrint(&path_buf, "/dev/shm{s}", .{shm_name}) catch return error.Unexpected;

    const file = std.fs.createFileAbsolute(file_path, .{}) catch return error.Unexpected;
    defer file.close();
    file.writeAll(pixels) catch return error.Unexpected;

    var b64_buf: [88]u8 = undefined;
    const encoded = std.base64.standard.Encoder.encode(&b64_buf, shm_name);

    self.writer.print(
        "\x1b_Gf=32,s={d},v={d},i={d},t=s,S={d};{s}\x1b\\",
        .{ width, height, id, pixels.len, encoded },
    ) catch return error.Unexpected;
    self.writer.flush() catch {};

    return .{ .id = id, .width = width, .height = height };
}

/// t=d: Base64-encode entire pixel buffer inline.
fn uploadViaBase64(self: *Kitty, pixels: []const u8, width: u16, height: u16) !vaxis.Image {
    const needed = std.base64.standard.Encoder.calcSize(pixels.len);
    if (needed > self.encode_buf.len) {
        self.allocator.free(self.encode_buf);
        self.encode_buf = try self.allocator.alloc(u8, needed);
    }

    const encoded = std.base64.standard.Encoder.encode(self.encode_buf, pixels);
    return self.vx.transmitPreEncodedImage(self.writer, encoded, width, height, .rgba);
}

// ── Image management ───────────────────────────────────────────────────

/// Free a previously uploaded image from terminal memory.
pub fn freeImage(self: *Kitty, id: u32) void {
    if (id >= FILE_ID_BASE) {
        self.writer.print("\x1b_Ga=d,d=I,i={d};\x1b\\", .{id}) catch return;
        self.writer.flush() catch {};
    } else {
        self.vx.freeImage(self.writer, id);
    }
}

/// Emit a Kitty image placement escape directly to the TTY,
/// bypassing the vaxis cell grid. Positions at top-left, fills screen.
/// Saves/restores cursor so vaxis's internal position tracking stays correct.
pub fn placeImageDirect(self: *Kitty, img_id: u32, cols: u16, rows: u16) void {
    // \x1b7 = DECSC (save cursor+attrs), \x1b8 = DECRC (restore)
    self.writer.print(
        "\x1b7\x1b[1;1H\x1b_Ga=p,i={d},r={d},c={d},z=-10,C=1\x1b\\\x1b8",
        .{ img_id, rows, cols },
    ) catch {};
    self.writer.flush() catch {};
}

/// Remove any leftover /dev/shm/vexel-* files from previous runs or crashes.
fn cleanupShmFiles() void {
    var dir = std.fs.openDirAbsolute("/dev/shm", .{ .iterate = true }) catch return;
    defer dir.close();
    var it = dir.iterate();
    while (it.next() catch null) |entry| {
        if (std.mem.startsWith(u8, entry.name, "tty-graphics-protocol-vexel-")) {
            dir.deleteFile(entry.name) catch {};
        }
    }
}

test "calcSize for small buffer" {
    const size = std.base64.standard.Encoder.calcSize(16);
    try std.testing.expect(size > 0);
}
