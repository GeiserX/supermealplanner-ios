#!/usr/bin/env python3
"""Draw the placeholder app icon: a plate on a dark table, 1024x1024, no dependencies.

The real icon comes from the design round; this exists so a build and an upload have something
valid, and so the icon in the repository is reproducible rather than a binary nobody can redraw.

    python3 tools/make-icon.py SuperMealPlanner/Assets.xcassets/AppIcon.appiconset/icon-1024.png
"""

from __future__ import annotations

import struct
import sys
import zlib

SIZE = 1024
TABLE = (20, 22, 28)       # the dark background the whole app uses
PLATE = (242, 240, 235)
RIM = (214, 210, 200)
FOOD = (226, 122, 58)      # one warm spot, so the icon is not a grey disc


def circle(x: float, y: float, cx: float, cy: float, r: float) -> bool:
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def pixel(x: int, y: int) -> tuple[int, int, int]:
    c = SIZE / 2
    if circle(x, y, c, c, SIZE * 0.40):
        if circle(x, y, c, c, SIZE * 0.36):
            if circle(x, y, c * 1.06, c * 0.94, SIZE * 0.13):
                return FOOD
            return PLATE
        return RIM
    return TABLE


def main(path: str) -> None:
    rows = bytearray()
    for y in range(SIZE):
        rows.append(0)  # filter: none
        for x in range(SIZE):
            rows.extend(pixel(x, y))

    def chunk(kind: bytes, data: bytes) -> bytes:
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(bytes(rows), 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)


if __name__ == "__main__":
    main(sys.argv[1])
