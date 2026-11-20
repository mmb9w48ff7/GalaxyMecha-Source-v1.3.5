# -*- coding: utf-8 -*-
"""
陨星公路 · 体素资产工具库
- 程序化体素建模（box / 椭球 / 圆柱 / 镜像 / 抖色）
- 贪婪网格合并（按材质分组），输出四边形列表
- 导出：UrhoX Lua 数据模块、HTML 预览 JSON、MagicaVoxel .vox

坐标约定（与 UrhoX 一致）：Y 向上，Z 向前（模型正面朝 +Z），X 向右。
体素 (x,y,z) 占据 [x,x+1] x [y,y+1] x [z,z+1]。
"""
import math, random, struct
import numpy as np


def hex2rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


class VoxModel:
    def __init__(self, mid, name, category, scale, desc, pivot='bottom'):
        self.id = mid
        self.name = name
        self.category = category
        self.scale = scale          # 每个体素多少米
        self.desc = desc
        self.pivot = pivot          # bottom: 底面中心为原点; center: 包围盒中心
        self.v = {}
        self.pal = {}
        self.pal_order = []
        self.tags = {}              # 体素 -> 部件名（机甲分件动画用）
        self.part = 'body'          # 当前写入的部件名
        self.rig = {}               # 关节 / 枪口 / 喷口等挂点（体素坐标）

    # ---------- 材质 ----------
    def mat(self, key, hexc, metal=0.0, rough=0.7, emit=0.0):
        if key not in self.pal:
            self.pal_order.append(key)
        self.pal[key] = dict(hex=hexc, metal=metal, rough=rough, emit=emit)
        return key

    # ---------- 基础操作 ----------
    def put(self, x, y, z, k):
        if k is None:
            self.v.pop((x, y, z), None)
            self.tags.pop((x, y, z), None)
        else:
            self.v[(x, y, z)] = k
            self.tags[(x, y, z)] = self.part

    def box(self, x0, y0, z0, x1, y1, z1, k):
        xa, xb = sorted((x0, x1)); ya, yb = sorted((y0, y1)); za, zb = sorted((z0, z1))
        for x in range(xa, xb + 1):
            for y in range(ya, yb + 1):
                for z in range(za, zb + 1):
                    self.put(x, y, z, k)

    def boxm(self, x0, y0, z0, x1, y1, z1, k):
        """以 x=0 平面镜像的对称方块（x -> -1-x）"""
        self.box(x0, y0, z0, x1, y1, z1, k)
        self.box(-1 - x0, y0, z0, -1 - x1, y1, z1, k)

    def ell(self, cx, cy, cz, rx, ry, rz, k, recolor_only=False):
        for x in range(int(math.floor(cx - rx)) - 1, int(math.ceil(cx + rx)) + 1):
            for y in range(int(math.floor(cy - ry)) - 1, int(math.ceil(cy + ry)) + 1):
                for z in range(int(math.floor(cz - rz)) - 1, int(math.ceil(cz + rz)) + 1):
                    dx = (x + 0.5 - cx) / rx; dy = (y + 0.5 - cy) / ry; dz = (z + 0.5 - cz) / rz
                    if dx * dx + dy * dy + dz * dz <= 1.0:
                        if recolor_only and (x, y, z) not in self.v:
                            continue
                        self.put(x, y, z, k)

    def cyl(self, axis, c1, c2, r, a0, a1, k, r2=None):
        """axis 方向圆柱；c1,c2 为另两轴中心；a0..a1 轴向范围；r2 可做锥台"""
        a0, a1 = sorted((a0, a1))
        n = max(1, a1 - a0)
        for a in range(a0, a1 + 1):
            rr = r if r2 is None else r + (r2 - r) * (a - a0) / n
            for i in range(int(math.floor(c1 - rr)) - 1, int(math.ceil(c1 + rr)) + 1):
                for j in range(int(math.floor(c2 - rr)) - 1, int(math.ceil(c2 + rr)) + 1):
                    if (i + 0.5 - c1) ** 2 + (j + 0.5 - c2) ** 2 <= rr * rr:
                        if axis == 'x': self.put(a, i, j, k)
                        elif axis == 'y': self.put(i, a, j, k)
                        else: self.put(i, j, a, k)

    def mirror(self):
        for (x, y, z), k in list(self.v.items()):
            if x >= 0:
                self.v[(-1 - x, y, z)] = k
                t = self.tags.get((x, y, z), 'body')
                if t in ('arm', 'uarm', 'thigh', 'shin'):      # +x 为左侧，-x 为右侧（武器手）
                    self.tags[(x, y, z)] = t + 'L'; self.tags[(-1 - x, y, z)] = t + 'R'
                else:
                    self.tags[(-1 - x, y, z)] = t

    def paint(self, cond, k):
        for p, old in list(self.v.items()):
            if cond(p[0], p[1], p[2], old):
                self.v[p] = k

    def dither(self, k_from, k_to, prob, seed=1, surface_only=True):
        rnd = random.Random(seed)
        for p in sorted(self.v.keys()):
            if self.v[p] == k_from and rnd.random() < prob:
                if surface_only and not self.is_surface(p):
                    continue
                self.v[p] = k_to

    def is_surface(self, p):
        x, y, z = p
        for d in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)):
            if (x + d[0], y + d[1], z + d[2]) not in self.v:
                return True
        return False

    def carve(self, x0, y0, z0, x1, y1, z1):
        self.box(x0, y0, z0, x1, y1, z1, None)

    # ---------- 导出 ----------
    def bounds(self):
        xs = [p[0] for p in self.v]; ys = [p[1] for p in self.v]; zs = [p[2] for p in self.v]
        return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))

    def build(self):
        """返回导出用字典：材质与贪婪合并后的四边形"""
        (x0, y0, z0), (x1, y1, z1) = self.bounds()
        sx, sy, sz = x1 - x0 + 1, y1 - y0 + 1, z1 - z0 + 1
        used = [k for k in self.pal_order if any(v == k for v in self.v.values())]
        kidx = {k: i + 1 for i, k in enumerate(used)}
        grid = np.zeros((sx, sy, sz), dtype=np.int32)
        for (x, y, z), k in self.v.items():
            grid[x - x0, y - y0, z - z0] = kidx[k]
        quads = {i + 1: [] for i in range(len(used))}
        greedy(grid, quads)
        if isinstance(self.pivot, (tuple, list)):
            origin = [self.pivot[0] - x0, self.pivot[1] - y0, self.pivot[2] - z0]
        elif self.pivot == 'bottom':
            origin = [sx / 2.0, 0.0, sz / 2.0]
        else:
            origin = [sx / 2.0, sy / 2.0, sz / 2.0]
        mats = []
        for k in used:
            m = self.pal[k]
            mats.append(dict(key=k, color=[round(c, 4) for c in hex2rgb(m['hex'])], hex=m['hex'],
                             metallic=m['metal'], roughness=m['rough'], emissive=m['emit'],
                             quads=quads[kidx[k]]))
        nq = sum(len(m['quads']) // 6 for m in mats)
        return dict(id=self.id, name=self.name, category=self.category, desc=self.desc,
                    scale=self.scale, size=[sx, sy, sz], origin=origin, voxels=len(self.v),
                    quadCount=nq, mats=mats, _grid=grid, _used=used)


def build_parts(model, names):
    """按 model.tags 拆成多个部件模型；所有部件与整机共用同一原点，运行时只需绕关节旋转。
    返回 {part: dict(mats=[...], ...)}，格式与 build() 相同（不含 _grid）。"""
    full = model.build()
    (x0, y0, z0), (x1, y1, z1) = model.bounds()
    sx, sy, sz = full['size']
    out = {}
    for name in names:
        vox = {p: k for p, k in model.v.items() if (model.tags.get(p, 'body') == name) or (name == 'body' and model.tags.get(p, 'body') not in names)}
        if not vox: continue
        used = [k for k in model.pal_order if any(v == k for v in vox.values())]
        kidx = {k: i + 1 for i, k in enumerate(used)}
        grid = np.zeros((sx, sy, sz), dtype=np.int32)
        for (x, y, z), k in vox.items():
            grid[x - x0, y - y0, z - z0] = kidx[k]
        quads = {i + 1: [] for i in range(len(used))}
        greedy(grid, quads)
        mats = []
        for k in used:
            m = model.pal[k]
            mats.append(dict(key=k, color=[round(c, 4) for c in hex2rgb(m['hex'])], hex=m['hex'],
                             metallic=m['metal'], roughness=m['rough'], emissive=m['emit'], quads=quads[kidx[k]]))
        out[name] = dict(id=model.id + '__' + name, name=model.name, category='part', desc=model.desc, scale=model.scale,
                         size=full['size'], origin=full['origin'], voxels=len(vox),
                         quadCount=sum(len(m['quads']) // 6 for m in mats), mats=mats)
    return out, full, (x0, y0, z0)


def greedy(grid, quads):
    """贪婪网格合并。四边形编码：face, p, u0, v0, u1, v1
    face = axis*2 + (0: 正方向 / 1: 负方向)；u=(axis+1)%3, v=(axis+2)%3"""
    dims = grid.shape
    padded = np.pad(grid, 1)
    for axis in range(3):
        u = (axis + 1) % 3; v = (axis + 2) % 3
        for sign in (1, -1):
            face = axis * 2 + (0 if sign == 1 else 1)
            for s in range(dims[axis]):
                # 当前切片与相邻切片
                idx = [slice(1, -1)] * 3
                idx[axis] = s + 1
                cur = padded[tuple(idx)]
                idx[axis] = s + 1 + sign
                nb = padded[tuple(idx)]
                # 2D 数组的轴顺序是剩余轴的自然顺序，需要转成 (u, v)
                rem = [a for a in range(3) if a != axis]
                mask = np.where((cur > 0) & (nb == 0), cur, 0)
                if rem != [u, v]:
                    mask = mask.T
                mask = mask.copy()
                H, W = mask.shape  # H 沿 u, W 沿 v
                p = s + 1 if sign == 1 else s
                for i in range(H):
                    j = 0
                    while j < W:
                        c = mask[i, j]
                        if c == 0:
                            j += 1; continue
                        w = 1
                        while j + w < W and mask[i, j + w] == c:
                            w += 1
                        h = 1
                        done = False
                        while i + h < H:
                            for jj in range(j, j + w):
                                if mask[i + h, jj] != c:
                                    done = True; break
                            if done: break
                            h += 1
                        mask[i:i + h, j:j + w] = 0
                        quads[int(c)].extend([face, p, i, j, i + h, j + w])
                        j += w


def write_vox(path, built):
    """写出 MagicaVoxel .vox（MagicaVoxel 为 Z 向上：x->x, z->y, y->z）"""
    grid = built['_grid']
    sx, sy, sz = grid.shape
    if max(sx, sy, sz) > 256:
        return False
    xyzi = []
    for x in range(sx):
        for y in range(sy):
            for z in range(sz):
                c = int(grid[x, y, z])
                if c:
                    xyzi.append(struct.pack('<BBBB', x, z, y, c))
    size_chunk = b'SIZE' + struct.pack('<ii', 12, 0) + struct.pack('<iii', sx, sz, sy)
    xyzi_body = struct.pack('<i', len(xyzi)) + b''.join(xyzi)
    xyzi_chunk = b'XYZI' + struct.pack('<ii', len(xyzi_body), 0) + xyzi_body
    pal = []
    for i in range(256):
        if i < len(built['mats']):
            r, g, b = [int(round(c * 255)) for c in built['mats'][i]['color']]
            pal.append(struct.pack('<BBBB', r, g, b, 255))
        else:
            pal.append(struct.pack('<BBBB', 0, 0, 0, 255))
    rgba_chunk = b'RGBA' + struct.pack('<ii', 1024, 0) + b''.join(pal)
    children = size_chunk + xyzi_chunk + rgba_chunk
    main = b'MAIN' + struct.pack('<ii', 0, len(children)) + children
    with open(path, 'wb') as f:
        f.write(b'VOX ' + struct.pack('<i', 150) + main)
    return True


def lua_value(v, indent=0):
    sp = '    ' * indent
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int, np.integer)):
        return str(int(v))
    if isinstance(v, float):
        s = ('%.4f' % v).rstrip('0').rstrip('.')
        return s if s not in ('', '-0') else '0'
    if isinstance(v, str):
        return '"' + v.replace('\\', '\\\\').replace('"', '\\"') + '"'
    if isinstance(v, (list, tuple)):
        if all(isinstance(x, (int, np.integer)) for x in v) and len(v) > 12:
            # 长整数数组按行折叠
            parts = [str(int(x)) for x in v]
            lines = []
            for i in range(0, len(parts), 30):
                lines.append(sp + '    ' + ','.join(parts[i:i + 30]) + ',')
            return '{\n' + '\n'.join(lines) + '\n' + sp + '}'
        if all(not isinstance(x, (dict, list, tuple)) for x in v):
            return '{' + ', '.join(lua_value(x) for x in v) + '}'
        return '{\n' + ''.join(sp + '    ' + lua_value(x, indent + 1) + ',\n' for x in v) + sp + '}'
    if isinstance(v, dict):
        out = '{\n'
        for k, x in v.items():
            key = k if k.isidentifier() else '["%s"]' % k
            out += sp + '    ' + key + ' = ' + lua_value(x, indent + 1) + ',\n'
        return out + sp + '}'
    if v is None:
        return 'nil'
    raise TypeError(type(v))
