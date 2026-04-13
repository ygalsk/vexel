"""Higher-level drawing primitives built on pxcli's set_pixel/fill_rect/line."""


def circle(canvas, cx, cy, r, color, filled=False):
    """Midpoint circle algorithm. Outline or filled."""
    x, y, d = r, 0, 1 - r
    if filled:
        _fill_circle_points(canvas, cx, cy, x, y, color)
    else:
        _plot_circle_points(canvas, cx, cy, x, y, color)
    while x > y:
        y += 1
        if d < 0:
            d += 2 * y + 1
        else:
            x -= 1
            d += 2 * (y - x) + 1
        if filled:
            _fill_circle_points(canvas, cx, cy, x, y, color)
        else:
            _plot_circle_points(canvas, cx, cy, x, y, color)


def _plot_circle_points(canvas, cx, cy, x, y, color):
    for dx, dy in [
        (x, y), (-x, y), (x, -y), (-x, -y),
        (y, x), (-y, x), (y, -x), (-y, -x),
    ]:
        px, py = cx + dx, cy + dy
        if 0 <= px < canvas.width and 0 <= py < canvas.height:
            canvas.set_pixel(px, py, color)


def _fill_circle_points(canvas, cx, cy, x, y, color):
    for dy, dx in [(y, x), (-y, x), (x, y), (-x, y)]:
        x0 = max(0, cx - dx)
        x1 = min(canvas.width - 1, cx + dx)
        py = cy + dy
        if 0 <= py < canvas.height and x0 <= x1:
            canvas.fill_rect(x0, py, x1 - x0 + 1, 1, color)


def ellipse(canvas, cx, cy, rx, ry, color, filled=False):
    """Midpoint ellipse. Outline or filled."""
    rx2, ry2 = rx * rx, ry * ry
    x, y = 0, ry
    px, py_val = 0, 2 * rx2 * y

    if filled:
        canvas.fill_rect(max(0, cx - x), cy + y, min(2 * x + 1, canvas.width), 1, color)
        canvas.fill_rect(max(0, cx - x), cy - y, min(2 * x + 1, canvas.width), 1, color)
    else:
        _plot_ellipse_points(canvas, cx, cy, x, y, color)

    d1 = ry2 - rx2 * ry + 0.25 * rx2
    while px < py_val:
        x += 1
        px += 2 * ry2
        if d1 < 0:
            d1 += ry2 + px
        else:
            y -= 1
            py_val -= 2 * rx2
            d1 += ry2 + px - py_val
        if filled:
            _fill_ellipse_row(canvas, cx, cy, x, y, color)
        else:
            _plot_ellipse_points(canvas, cx, cy, x, y, color)

    d2 = ry2 * (x + 0.5) ** 2 + rx2 * (y - 1) ** 2 - rx2 * ry2
    while y > 0:
        y -= 1
        py_val -= 2 * rx2
        if d2 > 0:
            d2 += rx2 - py_val
        else:
            x += 1
            px += 2 * ry2
            d2 += ry2 - py_val + px
        if filled:
            _fill_ellipse_row(canvas, cx, cy, x, y, color)
        else:
            _plot_ellipse_points(canvas, cx, cy, x, y, color)


def _plot_ellipse_points(canvas, cx, cy, x, y, color):
    for dx, dy in [(x, y), (-x, y), (x, -y), (-x, -y)]:
        px, py = cx + dx, cy + dy
        if 0 <= px < canvas.width and 0 <= py < canvas.height:
            canvas.set_pixel(px, py, color)


def _fill_ellipse_row(canvas, cx, cy, x, y, color):
    x0 = max(0, cx - x)
    x1 = min(canvas.width - 1, cx + x)
    if x0 <= x1:
        for row in [cy + y, cy - y]:
            if 0 <= row < canvas.height:
                canvas.fill_rect(x0, row, x1 - x0 + 1, 1, color)


def outline_rect(canvas, x, y, w, h, color):
    """1px border rectangle (no fill)."""
    canvas.fill_rect(x, y, w, 1, color)          # top
    canvas.fill_rect(x, y + h - 1, w, 1, color)  # bottom
    canvas.fill_rect(x, y + 1, 1, h - 2, color)  # left
    canvas.fill_rect(x + w - 1, y + 1, 1, h - 2, color)  # right


def copy_region(canvas, sx, sy, sw, sh, dx, dy):
    """Copy a rectangular region. Reads via get_pixel, writes via set_pixel.
    Use sparingly — each pixel is a subprocess call."""
    pixels = []
    for row in range(sh):
        for col in range(sw):
            c = canvas.get_pixel(sx + col, sy + row)
            if c and c != "transparent" and not c.endswith("00"):
                pixels.append((col, row, c))
    for col, row, c in pixels:
        canvas.set_pixel(dx + col, dy + row, c)


def shift_region(canvas, x, y, w, h, dx, dy, bg="transparent"):
    """Move a region by (dx, dy). Clears the source area."""
    pixels = []
    for row in range(h):
        for col in range(w):
            c = canvas.get_pixel(x + col, y + row)
            if c and c != "transparent" and not c.endswith("00"):
                pixels.append((col, row, c))
    # Clear source
    canvas.fill_rect(x, y, w, h, bg)
    # Write at destination
    for col, row, c in pixels:
        canvas.set_pixel(x + dx + col, y + dy + row, c)


def mirror_h(canvas, x, y, w, h):
    """Mirror a region horizontally in-place."""
    pixels = []
    for row in range(h):
        for col in range(w):
            c = canvas.get_pixel(x + col, y + row)
            pixels.append((col, row, c))
    for col, row, c in pixels:
        canvas.set_pixel(x + (w - 1 - col), y + row, c)
