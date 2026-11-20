# -*- coding: utf-8 -*-
"""离线检查用：把体素模型按 3/4 视角画成 PNG（画家算法，逐体素面）"""
import math
from PIL import Image, ImageDraw
from voxlib import hex2rgb

FACES = [((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]),
         ((-1, 0, 0), [(0, 0, 0), (0, 1, 0), (0, 1, 1), (0, 0, 1)]),
         ((0, 1, 0), [(0, 1, 0), (1, 1, 0), (1, 1, 1), (0, 1, 1)]),
         ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
         ((0, 0, 1), [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]),
         ((0, 0, -1), [(0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0)])]


def render(model, size=360, yaw=35, pitch=25, bg=(24, 28, 52), fixed_s=None, extent_only=False):
    v = model.v
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    # 相机在 +Z 前方偏右上看向模型（左手系：x 右, y 上, z 前）
    def proj(p):
        x, y, z = p
        # 绕 y 旋转
        xr = x * cy - z * sy
        zr = x * sy + z * cy
        # 绕 x 俯仰
        yr = y * cp - zr * sp
        zr2 = y * sp + zr * cp
        return xr, yr, zr2
    light = (0.5, 0.8, 0.6)
    ln = math.sqrt(sum(c * c for c in light)); light = tuple(c / ln for c in light)
    polys = []
    for (x, y, z), k in v.items():
        m = model.pal[k]
        col = hex2rgb(m['hex'])
        for n, corners in FACES:
            if (x + n[0], y + n[1], z + n[2]) in v:
                continue
            pts = [proj((x + c[0], y + c[1], z + c[2])) for c in corners]
            depth = sum(p[2] for p in pts) / 4
            d = max(0, n[0] * light[0] + n[1] * light[1] + n[2] * light[2])
            sh = 0.45 + 0.6 * d
            e = m['emit']
            c = tuple(min(255, int(255 * min(1, ci * (sh + e * 0.5)))) for ci in col)
            polys.append((depth, pts, c))
    if not polys:
        return Image.new('RGB', (size, size), bg)
    xs = [p[0] for _, pts, _ in polys for p in pts]; ys = [p[1] for _, pts, _ in polys for p in pts]
    w = max(xs) - min(xs); h = max(ys) - min(ys)
    if extent_only: return max(w, h)
    s = fixed_s if fixed_s else (size * 0.86) / max(w, h)
    ox = size / 2 + (max(xs) + min(xs)) / 2 * s
    oy = (size * 0.93 + min(ys) * s) if fixed_s else (size / 2 + (max(ys) + min(ys)) / 2 * s)
    img = Image.new('RGB', (size, size), bg)
    dr = ImageDraw.Draw(img)
    polys.sort(key=lambda t: t[0])  # 远的先画（z 越大越靠近相机）
    for _, pts, c in polys:
        dr.polygon([(ox - p[0] * s, oy - p[1] * s) for p in pts], fill=c)
    return img


def sheet(models, path, cols=5, size=300, yaw=35, pitch=22):
    rows = (len(models) + cols - 1) // cols
    out = Image.new('RGB', (cols * size, rows * (size + 24)), (16, 20, 40))
    dr = ImageDraw.Draw(out)
    for i, m in enumerate(models):
        im = render(m, size, yaw, pitch)
        out.paste(im, ((i % cols) * size, (i // cols) * (size + 24)))
        dr.text(((i % cols) * size + 6, (i // cols) * (size + 24) + size + 4), m.id, fill=(230, 230, 230))
    out.save(path)
