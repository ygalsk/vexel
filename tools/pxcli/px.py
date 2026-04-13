"""Core pxcli wrapper — Canvas context manager for the pxcli daemon."""

import subprocess
import time

PXCLI = "/home/dkremer/.local/bin/pxcli"


def _run(*args, check=True):
    """Run a pxcli command, return stdout."""
    result = subprocess.run(
        [PXCLI, *args],
        capture_output=True, text=True, timeout=10,
    )
    if check and result.returncode != 0:
        raise RuntimeError(f"pxcli {' '.join(args)}: {result.stderr.strip()}")
    return result.stdout.strip()


class Canvas:
    """Context manager wrapping the pxcli daemon lifecycle.

    Usage:
        with Canvas(352, 32) as c:
            c.fill_rect(0, 0, 32, 32, "#1A4A4A")
            c.set_pixel(5, 5, "#50C8B0")
            c.export("out.png")
    """

    def __init__(self, width, height):
        self.width = width
        self.height = height
        # Kill any leftover daemon
        _run("stop", check=False)
        time.sleep(0.1)
        _run("start", "--headless", "--size", f"{width}x{height}")
        # Clear to transparent
        _run("clear", "transparent")

    def set_pixel(self, x, y, color):
        _run("set_pixel", str(x), str(y), color)

    def fill_rect(self, x, y, w, h, color):
        _run("fill_rect", str(x), str(y), str(w), str(h), color)

    def line(self, x1, y1, x2, y2, color):
        _run("line", str(x1), str(y1), str(x2), str(y2), color)

    def clear(self, color="transparent"):
        _run("clear", color)

    def get_pixel(self, x, y):
        return _run("get_pixel", str(x), str(y))

    def export(self, path):
        _run("export", path)

    def undo(self):
        _run("undo")

    def redo(self):
        _run("redo")

    def stop(self):
        _run("stop", check=False)

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.stop()
