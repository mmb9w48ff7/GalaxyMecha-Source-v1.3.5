# -*- coding: utf-8 -*-
"""把 mock 记录的 NanoVG 绘制命令（JSON）用 PIL 光栅化成 PNG，用来在没有真机时检查界面版式。"""
import json, math, sys
from PIL import Image, ImageDraw, ImageFont
FONT = '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc'
_fc = {}
def font(size):
    k = int(round(size))
    if k not in _fc: _fc[k] = ImageFont.truetype(FONT, max(6, k), index=2)   # SC
    return _fc[k]
def render(cmds, W=1920, H=1080, bg=(14, 18, 36), base=None):
    img = base.copy().convert('RGBA') if base else Image.new('RGBA', (W, H), bg + (255,))
    M = [1, 0, 0, 1, 0, 0]; stack = []; clip = None
    path = []; cur = None; fill = (255, 255, 255, 255); stroke = (255, 255, 255, 255); sw = 1; fs = 14; align = 1 + 8; ls = 0
    def T(x, y): return (M[0] * x + M[2] * y + M[4], M[1] * x + M[3] * y + M[5])
    def mul(a, b): return [a[0] * b[0] + a[2] * b[1], a[1] * b[0] + a[3] * b[1], a[0] * b[2] + a[2] * b[3], a[1] * b[2] + a[3] * b[3], a[0] * b[4] + a[2] * b[5] + a[4], a[1] * b[4] + a[3] * b[5] + a[5]]
    def blend_poly(pts, color):
        nonlocal img
        if len(pts) < 3 or color[3] == 0: return
        xs = [p[0] for p in pts]; ys = [p[1] for p in pts]; x0, y0, x1, y1 = int(math.floor(min(xs))), int(math.floor(min(ys))), int(math.ceil(max(xs))) + 1, int(math.ceil(max(ys))) + 1
        if clip: x0, y0, x1, y1 = max(x0, clip[0]), max(y0, clip[1]), min(x1, clip[2]), min(y1, clip[3])
        x0, y0, x1, y1 = max(0, x0), max(0, y0), min(W, x1), min(H, y1)
        if x1 <= x0 or y1 <= y0: return
        mask = Image.new('L', (x1 - x0, y1 - y0), 0); ImageDraw.Draw(mask).polygon([(p[0] - x0, p[1] - y0) for p in pts], fill=255)
        layer = Image.new('RGBA', (x1 - x0, y1 - y0), color[:3] + (0,)); a = mask.point(lambda v: v * color[3] // 255); layer.putalpha(a)
        reg = img.crop((x0, y0, x1, y1)); reg.alpha_composite(layer); img.paste(reg, (x0, y0))
    def text(s, x, y, color):
        nonlocal img
        f = font(fs); ha = align & 7; va = align & (8 | 16 | 32 | 64)
        if ls: w = sum(f.getlength(ch) + ls for ch in s)
        else: w = f.getlength(s)
        tx, ty = T(x, y); sc = math.sqrt(abs(M[0] * M[3] - M[1] * M[2]))
        if sc != 1: f = font(fs * sc); w = w * sc
        asc, desc = f.getmetrics(); h = asc + desc
        px = tx - (w / 2 if ha == 2 else (w if ha == 4 else 0))
        py = ty - (h / 2 if va == 16 else (asc if va == 64 else 0))
        L = Image.new('L', (int(w) + 8, h + 8), 0); d = ImageDraw.Draw(L)
        if ls:
            cx = 0
            for ch in s: d.text((cx, 0), ch, font=f, fill=255); cx += f.getlength(ch) + ls * sc
        else: d.text((0, 0), s, font=f, fill=255)
        layer = Image.new('RGBA', L.size, color[:3] + (0,)); layer.putalpha(L.point(lambda v: v * color[3] // 255))
        ix, iy = int(round(px)), int(round(py)); region = (ix, iy, ix + L.size[0], iy + L.size[1])
        if clip:
            c = (max(region[0], clip[0]), max(region[1], clip[1]), min(region[2], clip[2]), min(region[3], clip[3]))
            if c[2] <= c[0] or c[3] <= c[1]: return
            layer = layer.crop((c[0] - ix, c[1] - iy, c[2] - ix, c[3] - iy)); ix, iy = c[0], c[1]
        img.alpha_composite(layer, (max(0, ix), max(0, iy))) if ix >= 0 and iy >= 0 and ix < W and iy < H else None
    for c in cmds:
        op = c[0]
        if op == 'nvgSave': stack.append((list(M), clip))
        elif op == 'nvgRestore':
            if stack: M, clip = stack.pop()
        elif op == 'nvgTranslate': M = mul(M, [1, 0, 0, 1, c[1], c[2]])
        elif op == 'nvgScale': M = mul(M, [c[1], 0, 0, c[2], 0, 0])
        elif op == 'nvgRotate': a = c[1]; M = mul(M, [math.cos(a), math.sin(a), -math.sin(a), math.cos(a), 0, 0])
        elif op == 'nvgBeginPath': path = []; cur = None
        elif op == 'nvgRect': x, y, w, h = c[1:5]; path.append([T(x, y), T(x + w, y), T(x + w, y + h), T(x, y + h)])
        elif op == 'nvgRoundedRect': x, y, w, h = c[1:5]; path.append([T(x, y), T(x + w, y), T(x + w, y + h), T(x, y + h)])
        elif op == 'nvgCircle':
            x, y, r = c[1:4]; path.append([T(x + r * math.cos(a / 24 * 2 * math.pi), y + r * math.sin(a / 24 * 2 * math.pi)) for a in range(24)])
        elif op == 'nvgMoveTo': cur = [T(c[1], c[2])]; path.append(cur)
        elif op == 'nvgLineTo':
            if cur is None: cur = [T(c[1], c[2])]; path.append(cur)
            else: cur.append(T(c[1], c[2]))
        elif op == 'nvgArc':
            x, y, r, a0, a1 = c[1:6]; n = 16
            if cur is None: cur = []; path.append(cur)
            for i in range(n + 1): a = a0 + (a1 - a0) * i / n; cur.append(T(x + r * math.cos(a), y + r * math.sin(a)))
        elif op == 'nvgClosePath': cur = None
        elif op == 'nvgFillColor': fill = tuple(int(v) for v in c[1])
        elif op == 'nvgStrokeColor': stroke = tuple(int(v) for v in c[1])
        elif op == 'nvgStrokeWidth': sw = c[1]
        elif op == 'nvgFill':
            for p in path: blend_poly(p, fill)
        elif op == 'nvgStroke':
            for p in path:
                for i in range(len(p) - 1 + (1 if len(p) > 2 else 0)):
                    a, b = p[i], p[(i + 1) % len(p)]; dx, dy = b[0] - a[0], b[1] - a[1]; l = math.hypot(dx, dy) or 1; nx, ny = -dy / l * sw / 2, dx / l * sw / 2
                    blend_poly([(a[0] + nx, a[1] + ny), (b[0] + nx, b[1] + ny), (b[0] - nx, b[1] - ny), (a[0] - nx, a[1] - ny)], stroke)
        elif op == 'nvgFontSize': fs = c[1]
        elif op == 'nvgTextAlign': align = int(c[1])
        elif op == 'nvgTextLetterSpacing': ls = c[1]
        elif op == 'nvgText': text(c[3], c[1], c[2], fill)
        elif op == 'nvgTextBox':
            x, y, w, s = c[1], c[2], c[3], c[4]; f = font(fs); line = ''; yy = y
            for ch in s:
                if f.getlength(line + ch) > w and line: text(line, x, yy, fill); yy += fs * 1.5; line = ch
                else: line += ch
            if line: text(line, x, yy, fill)
        elif op == 'nvgScissor':
            x0, y0 = T(c[1], c[2]); x1, y1 = T(c[1] + c[3], c[2] + c[4]); clip = (int(x0), int(y0), int(x1), int(y1))
        elif op == 'nvgResetScissor': clip = None
    return img
if __name__ == '__main__':
    cmds = json.load(open(sys.argv[1])); render(cmds).convert('RGB').save(sys.argv[2])
