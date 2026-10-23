"""生成 1024x1024 的 App 图标（纯标准库，无需 Pillow）。

图形：紫蓝渐变底 + 白色麦克风剪影，用 SDF（有向距离场）做抗锯齿。
运行：python tools/make_icon.py
"""

import math
import struct
import zlib
from pathlib import Path

SIZE = 1024
OUT = Path(__file__).resolve().parents[1] / "VoiceNote" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset" / "icon-1024.png"


def lerp(a, b, t):
    return a + (b - a) * t


def smoothstep(edge0, edge1, x):
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)


def sd_rounded_box(px, py, cx, cy, hw, hh, r):
    qx = abs(px - cx) - (hw - r)
    qy = abs(py - cy) - (hh - r)
    ax = max(qx, 0.0)
    ay = max(qy, 0.0)
    return math.hypot(ax, ay) + min(max(qx, qy), 0.0) - r


def sd_ring_lower(px, py, cx, cy, radius, thickness):
    """下半圆环（U 形），上半部分裁掉"""
    ring = abs(math.hypot(px - cx, py - cy) - radius) - thickness / 2
    return max(ring, cy - py)


def mic_distance(px, py):
    # 话筒主体
    d = sd_rounded_box(px, py, 512, 440, 76, 150, 76)
    # U 形支架
    d = min(d, sd_ring_lower(px, py, 512, 440, 190, 44))
    # 立杆
    d = min(d, sd_rounded_box(px, py, 512, 668, 22, 38, 8))
    # 底座
    d = min(d, sd_rounded_box(px, py, 512, 728, 95, 26, 26))
    return d


def build_pixels():
    rows = []
    top = (0.42, 0.47, 0.98)
    bottom = (0.62, 0.40, 0.94)
    for y in range(SIZE):
        row = bytearray()
        for x in range(SIZE):
            t = (x + y) / (2 * (SIZE - 1))
            r = lerp(top[0], bottom[0], t)
            g = lerp(top[1], bottom[1], t)
            b = lerp(top[2], bottom[2], t)

            # 左上角柔光
            glow = max(0.0, 1.0 - math.hypot(x - 210, y - 150) / 700.0)
            glow = glow * glow * 0.16
            r = lerp(r, 1.0, glow)
            g = lerp(g, 1.0, glow)
            b = lerp(b, 1.0, glow)

            # 麦克风剪影
            dist = mic_distance(x, y)
            alpha = 1.0 - smoothstep(-0.9, 0.9, dist)
            if alpha > 0:
                r = lerp(r, 1.0, alpha)
                g = lerp(g, 1.0, alpha)
                b = lerp(b, 1.0, alpha)

            row += bytes((int(r * 255), int(g * 255), int(b * 255)))
        rows.append(bytes(row))
    return rows


def write_png(path, rows):
    raw = b"".join(b"\x00" + row for row in rows)

    def chunk(tag, data):
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


if __name__ == "__main__":
    write_png(OUT, build_pixels())
    print("icon written:", OUT, OUT.stat().st_size, "bytes")
