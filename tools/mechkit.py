# -*- coding: utf-8 -*-
"""机甲体块造型工具（v0.9.3 造型重做）
单体素 0.06 米，身高约 64 格（≈3.9 米），面朝 +Z，先建右半边（x>=0）再镜像。
造型语言：英雄比例（小头、宽胸、窄腰、长腿）、分层装甲板、倒角体块、色块分区、
发光点缀只用在眼部 / 核心 / 推进口。全部为原创设计，不使用任何既有作品的标志性部件
（不用 V 形额角、不用三色胸口进气格栅、不用口部面罩竖纹）。"""
import math
from voxlib import VoxModel

SCALE = 0.06


def shade(hexc, k):
    h = hexc.lstrip('#'); c = [int(h[i:i + 2], 16) for i in (0, 2, 4)]
    if k < 1: c = [int(v * k) for v in c]
    else: c = [int(v + (255 - v) * (k - 1)) for v in c]
    return '#' + ''.join('%02X' % max(0, min(255, v)) for v in c)


class Mech(VoxModel):
    def __init__(self, mid, name, desc):
        super().__init__(mid, name, 'mech', SCALE, desc)

    def tone(self, key, hexc, metal=0.35, rough=0.4):
        """主色 + 亮面 + 暗面三档"""
        self.mat(key, hexc, metal=metal, rough=rough)
        self.mat(key + '_lt', shade(hexc, 1.32), metal=metal, rough=max(0.1, rough - 0.1))
        self.mat(key + '_dk', shade(hexc, 0.58), metal=metal, rough=min(1, rough + 0.15))

    # ---------------------------------------------------- 形体
    def cbox(self, x0, x1, y0, y1, z0, z1, k, c=1, edges='xyz', center=None):
        """倒角方块。edges 中的字母表示哪类棱倒角：
        y = 竖棱（xz 平面转角），x = 沿 x 的横棱（yz 转角），z = 沿 z 的横棱（xy 转角）。
        x0 == 0 时视为贴中线（镜像后连成一体），中线一侧不倒角。"""
        xa, xb = sorted((x0, x1)); ya, yb = sorted((y0, y1)); za, zb = sorted((z0, z1))
        if center is None: center = (xa == 0)
        nx = (xb - xa + 1) * (2 if center else 1); ny = yb - ya + 1; nz = zb - za + 1
        ey = 'y' in edges and nx >= 3 and nz >= 3
        ex = 'x' in edges and ny >= 3 and nz >= 3
        ez = 'z' in edges and nx >= 3 and ny >= 3
        for x in range(xa, xb + 1):
            dx = (xb - x) if center else min(x - xa, xb - x)
            for y in range(ya, yb + 1):
                dy = min(y - ya, yb - y)
                for z in range(za, zb + 1):
                    dz = min(z - za, zb - z)
                    cut = False
                    if ey and dx + dz < c: cut = True
                    if ex and dy + dz < c: cut = True
                    if ez and dx + dy < c: cut = True
                    if not cut: self.put(x, y, z, k)

    def slab(self, y0, y1, f, k, c=0):
        """逐层截面：f(y) -> (x0, x1, z0, z1)；c>0 时每层截面四角倒角"""
        for y in range(min(y0, y1), max(y0, y1) + 1):
            r = f(y)
            if r is None: continue
            x0, x1, z0, z1 = [int(round(v)) for v in r]
            for x in range(x0, x1 + 1):
                for z in range(z0, z1 + 1):
                    dx = (x1 - x) if x0 == 0 else min(x - x0, x1 - x)
                    if c and (x1 - x0) >= 2 and (z1 - z0) >= 2 and dx + min(z - z0, z1 - z) < c: continue
                    self.put(x, y, z, k)

    def line(self, pts, k, r=0):
        """三维折线（体素化），r 为粗细半径"""
        for (a, b) in zip(pts, pts[1:]):
            n = int(max(abs(b[i] - a[i]) for i in range(3))) * 2 + 1
            for s in range(n + 1):
                t = s / n
                p = [a[i] + (b[i] - a[i]) * t for i in range(3)]
                for dx in range(-r, r + 1):
                    for dy in range(-r, r + 1):
                        for dz in range(-r, r + 1):
                            if dx * dx + dy * dy + dz * dz <= r * r:
                                self.put(int(round(p[0])) + dx, int(round(p[1])) + dy, int(round(p[2])) + dz, k)

    def recolor(self, x0, x1, y0, y1, z0, z1, k, only=None):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            for y in range(min(y0, y1), max(y0, y1) + 1):
                for z in range(min(z0, z1), max(z0, z1) + 1):
                    if (x, y, z) in self.v and (only is None or self.v[(x, y, z)] in only):
                        self.v[(x, y, z)] = k

    def chibi(self, head=1.6, leg=0.75):
        """Q 版比例后处理：头放大 head 倍（绕颈部），腿纵向压缩到 leg 倍（以髋为不动点），其余部件整体下移使脚底仍在 y=0。
        体素、部件标记、关节挂点（rig）同步变换，因此动作与枪口位置不受影响。"""
        if getattr(self, '_chibi', False): return
        self._chibi = True
        import math
        D = int(round(36 * (1 - leg))); V, T = self.v, self.tags
        isleg = lambda t: t.startswith('thigh') or t.startswith('shin')
        nv, nt = {}, {}
        for (x, y, z), k in V.items():                              # 躯干 / 手臂：整体下移
            t = T.get((x, y, z), 'body')
            if isleg(t) or t == 'head': continue
            nv[(x, y - D, z)] = k; nt[(x, y - D, z)] = t
        legs = {}
        for (x, y, z), k in V.items():                              # 腿：纵向压缩
            t = T.get((x, y, z), 'body')
            if isleg(t): legs[(x, y, z)] = (k, t)
        cols = {}
        for (x, y, z) in legs: cols.setdefault((x, z), True)
        top = int((38 - 36) * leg + 36 - D) + 1
        for (x, z) in cols:
            for yt in range(0, top + 1):
                ys = int(round(36 - ((36 - D) - yt) / leg))
                if (x, ys, z) in legs:
                    k, t = legs[(x, ys, z)]; nv[(x, yt, z)] = k; nt[(x, yt, z)] = t
        hv = {p: V[p] for p in V if T.get(p, 'body') == 'head'}       # 头：绕颈部放大
        if hv:
            px, py, pz = 0.0, 57.0, 0.5
            xs = [p[0] for p in hv]; ys = [p[1] for p in hv]; zs = [p[2] for p in hv]
            def rngf(lo, hi, c): return range(int(math.floor(c + (lo - c) * head)) - 1, int(math.ceil(c + (hi + 1 - c) * head)) + 1)
            for tx in rngf(min(xs), max(xs), px):
                for ty in rngf(min(ys), max(ys), py):
                    for tz in rngf(min(zs), max(zs), pz):
                        sx = int(math.floor(px + (tx + 0.5 - px) / head)); sy = int(math.floor(py + (ty + 0.5 - py) / head)); sz = int(math.floor(pz + (tz + 0.5 - pz) / head))
                        if (sx, sy, sz) in hv:
                            nv[(tx, ty - D, tz)] = hv[(sx, sy, sz)]; nt[(tx, ty - D, tz)] = 'head'
        self.v, self.tags = nv, nt
        legrig = ('hipL', 'hipR', 'kneeL', 'kneeR', 'footL', 'footR')
        def mv(name, p):
            if isinstance(p[0], (list, tuple)): return [mv(name, q) for q in p]
            y = (p[1] - 36) * leg + 36 - D if name in legrig else p[1] - D
            return (p[0], y, p[2])
        self.rig = {n: mv(n, p) for n, p in self.rig.items()}
        # 脚底归零：取整后最低的小腿体素若不在 y=0（如 leg=0.82 时落在 y=1），整体下移，保证机甲站在地面上（不悬空、不插地）
        floor = min((p[1] for p, t in self.tags.items() if t.startswith('shin')), default=0)
        if floor != 0:
            self.v = {(x, y - floor, z): k for (x, y, z), k in self.v.items()}; self.tags = {(x, y - floor, z): t for (x, y, z), t in self.tags.items()}
            def sh(p):
                if isinstance(p[0], (list, tuple)): return [sh(q) for q in p]
                return (p[0], p[1] - floor, p[2])
            self.rig = {n: sh(p) for n, p in self.rig.items()}

    def finish(self, tones):
        self.chibi()
        """亮边：顶面暴露且侧面暴露的装甲棱角提亮，形成体块轮廓高光"""
        V = self.v; paint = {}
        for (x, y, z), k in V.items():
            if k not in tones: continue
            if (x, y + 1, z) in V: continue
            side = sum(1 for d in ((1, 0, 0), (-1, 0, 0), (0, 0, 1), (0, 0, -1)) if (x + d[0], y, z + d[2]) not in V)
            if side >= 1: paint[(x, y, z)] = k + '_lt'
        V.update(paint)
        return self


# ======================================================== 通用人形骨架
# 关键高度（格）：脚 0-4｜小腿 6-24｜膝 23-29｜大腿 28-36｜髋 35-38｜腰 38-43｜胸 43-55｜颈 55-57｜头 57-64
def legs(m, P):
    """腿：大脚掌、外扩踝甲、上窄下宽的小腿、块状膝甲、收窄的大腿"""
    W, S, F = P['W'], P['S'], P['F']
    lx = P.get('legx', 3); t = P.get('thick', 0)
    X1 = lx + 6 + t
    LS = P.get('legS', S); KN = P.get('knee', S)
    hx = (lx + X1 + 1) / 2.0                                                # 腿部中线（用于关节挂点）
    m.rig['hipL'] = (hx, 36.0, 0.5); m.rig['hipR'] = (-hx, 36.0, 0.5)
    m.rig['kneeL'] = (hx, 26.0, 0.5); m.rig['kneeR'] = (-hx, 26.0, 0.5)
    m.rig['footL'] = (hx, 0.0, 1.0); m.rig['footR'] = (-hx, 0.0, 1.0)
    m.part = 'shin'
    # 脚
    m.cbox(lx, X1, 0, 1, -6, 8, F, c=1, edges='y')                        # 鞋底
    m.cbox(lx, X1, 1, 4, -5, 5, LS, c=2, edges='yx')                       # 脚背
    m.cbox(lx + 1, X1 - 1, 1, 3, 5, 10, LS, c=1, edges='yx')               # 脚尖
    m.recolor(lx + 1, X1 - 1, 3, 3, 6, 9, LS + '_lt')
    m.cbox(lx + 1, X1 - 1, 1, 5, -7, -5, F, c=1, edges='y')                # 后跟
    m.cbox(lx + 1, X1 - 1, 4, 7, -2, 2, F)                                 # 踝关节
    # 小腿：下宽上窄
    def shin(y):
        n = 1 if y >= 19 else 0
        zb = -4 - (1 if 11 <= y <= 18 else 0)
        return (lx + n, X1 - n, zb, 5 - n)
    m.slab(7, 24, shin, W, c=2)
    m.slab(6, 10, lambda y: (lx - 1, X1 + 1, -5, 6), LS, c=2)              # 踝部护甲
    m.recolor(lx - 1, X1 + 1, 10, 10, -6, 7, LS + '_dk')
    m.cbox(lx + 1, X1 - 1, 11, 18, 6, 6, W + '_lt', c=1, edges='z')        # 小腿前凸板
    m.cbox(lx + 3, X1 - 3, 12, 17, 7, 7, P.get('shinplate', LS))
    m.cbox(X1 + 1, X1 + 1, 12, 19, -3, 2, W, c=1, edges='x')               # 外侧护板
    for y in (14, 16): m.box(X1 + 1, y, -2, X1 + 1, y, 1, F)
    m.slab(11, 18, lambda y: (lx + 1, X1 - 1, -6, -5), LS, c=1)            # 小腿肚推进口
    m.box(lx + 2, 11, -6, X1 - 2, 11, -6, P['G'])
    # 膝
    m.cbox(lx, X1, 23, 28, -3, 3, F)
    m.cbox(lx + 1, X1 - 1, 22, 29, 2, 6, KN, c=2, edges='yx')
    m.cbox(lx + 2, X1 - 2, 24, 27, 7, 7, KN + '_lt')
    # 大腿（比小腿窄一格）
    m.part = 'thigh'
    m.slab(28, 37, lambda y: (lx, X1 - 1, -3, 3), P.get('thigh', W), c=2)
    m.cbox(lx + 1, X1 - 2, 29, 32, 4, 4, P.get('thigh', W) + '_lt')
    m.recolor(lx, X1 - 1, 33, 33, -4, 5, P.get('thigh', W) + '_dk')
    m.cbox(lx - 1, lx + 4, 35, 38, -2, 2, F)                               # 髋关节
    m.part = 'body'


def waist(m, P):
    W, S, F = P['W'], P['S'], P['F']
    SK = P.get('skirt', W); CR = P.get('crotch', S)
    m.rig['waist'] = (0.0, 40.0, 0.5)
    m.cbox(0, 2, 31, 39, -3, 4, CR, c=1, edges='yz')                       # 裆部
    m.cbox(0, 1, 33, 36, 5, 5, CR + '_dk')
    def fskirt(y):                                                          # 前裙甲：上贴下张，中间露出裆部
        off = (39 - y) // 2
        return (3, 7, 4 + off, 5 + off)
    m.slab(34, 39, fskirt, SK, c=1)
    m.recolor(3, 7, 34, 34, 0, 9, SK + '_dk')
    m.recolor(4, 6, 36, 37, 0, 10, P.get('skirtmark', S))
    def sskirt(y):
        off = (39 - y) // 3
        return (8 + off, 9 + off, -3, 3)
    m.slab(33, 39, sskirt, P.get('sskirt', S), c=1)
    m.slab(33, 39, lambda y: (0, 6, -5 - (39 - y) // 4, -4 - (39 - y) // 4), SK, c=1)  # 后裙甲
    m.cbox(0, 6, 38, 40, -4, 5, W, c=1, edges='y')                         # 腰带
    m.recolor(0, 6, 39, 39, 5, 5, W + '_dk')
    m.cbox(0, 1, 38, 40, 6, 6, P['A'])                                     # 腰扣
    m.cbox(0, 4, 40, 44, -3, 3, F)                                         # 腹部骨架
    for y in (41, 43): m.box(0, y, 4, 3, y, 4, F + '_lt')


def torso(m, P):
    W, S, F = P['W'], P['S'], P['F']
    cw = P.get('chestw', 8)
    CH = P.get('chest', S); CP = P.get('chestplate', S)
    def chest(y):                                                           # 倒梯形胸腔
        if y < 47: return (0, cw - 3, -4, 5)
        if y < 50: return (0, cw - 1, -5, 6)
        return (0, cw, -5, 6)
    m.slab(44, 55, chest, CH, c=2)
    def plate(y):                                                           # 胸甲两片，上厚下薄
        if y < 50: return (1, cw - 2, 7, 7)
        return (1, cw - 1, 7, 8)
    m.slab(48, 54, plate, CP, c=1)
    m.recolor(0, 0, 47, 54, 6, 9, CH + '_dk')                               # 中缝
    m.recolor(1, cw - 1, 54, 54, 7, 9, CP + '_lt')
    m.cbox(0, cw - 4, 43, 47, -4, 6, W, c=1, edges='yz')                   # 腹甲
    m.recolor(0, 1, 44, 46, 6, 6, W + '_dk')
    m.cbox(0, 4, 55, 56, -4, 4, W, c=1)                                    # 领口
    m.cbox(4, 5, 55, 57, -3, 2, W, c=1, edges='y')                         # 立领
    m.cbox(0, 1, 55, 58, -1, 2, F)                                         # 颈


def head_base(m, P, hy=57):
    W, S, F, E = P['W'], P['S'], P['F'], P['E']
    m.rig['neck'] = (0.0, float(hy), 0.5)
    m.part = 'head'
    m.cbox(0, 3, hy, hy + 7, -3, 4, P.get('helm', W), c=2, edges='yzx')    # 头盔
    m.cbox(0, 2, hy + 1, hy + 5, 5, 5, F)                                  # 面部
    m.cbox(0, 1, hy, hy + 2, 4, 6, P.get('chin', S))                       # 下颌
    m.cbox(4, 4, hy + 2, hy + 5, -2, 2, S)                                 # 耳部
    m.cbox(4, 4, hy + 3, hy + 4, 3, 3, P['A'])
    m.part = 'body'


def visor(m, P, hy=57):
    """一字环绕护目镜 + 眉檐"""
    E, W = P['E'], P.get('helm', P['W'])
    m.part = 'head'
    m.cbox(0, 3, hy + 3, hy + 4, 6, 6, E)
    m.put(3, hy + 3, 5, E); m.put(3, hy + 4, 5, E)
    m.cbox(0, 3, hy + 5, hy + 6, 5, 6, W)
    m.recolor(0, 3, hy + 6, hy + 6, 4, 6, W + '_lt')
    m.part = 'body'


def shoulder(m, P):
    W, S, F, AC = P['W'], P['S'], P['F'], P['A']
    sx = P.get('shx', 9); sw = P.get('shw', 5)
    SH, SH2 = P.get('sh', W), P.get('sh2', S)
    m.cbox(sx - 1, sx + 1, 47, 53, -3, 3, F)                               # 肩关节
    m.cbox(sx, sx + sw, 51, 56, -5, 5, SH, c=2, edges='yzx')               # 顶盖
    def lower(y):                                                           # 外倾挂板
        off = (51 - y) // 3
        return (sx + 1 + off, sx + sw + 1 + off, -5, 5)
    m.slab(45, 51, lower, SH2, c=2)
    m.recolor(sx, sx + sw + 4, 51, 51, -6, 6, SH2 + '_dk', only={SH2})
    m.cbox(sx + sw + 1, sx + sw + 1, 52, 54, -2, 2, AC)                   # 肩甲侧标
    m.recolor(sx, sx + sw, 56, 56, -4, 4, SH + '_lt')


def arm(m, P):
    W, S, F = P['W'], P['S'], P['F']
    ax = P.get('armx', 10)
    m.rig['shoulderL'] = (ax + 2.0, 47.5, 0.5); m.rig['shoulderR'] = (-(ax + 2.0), 47.5, 0.5)
    m.rig['elbowL'] = (ax + 2.0, 38.5, 0.5); m.rig['elbowR'] = (-(ax + 2.0), 38.5, 0.5)
    m.part = 'uarm'
    m.cbox(ax, ax + 3, 39, 48, -2, 2, F)                                   # 上臂
    m.cbox(ax, ax + 3, 41, 45, -3, 3, W, c=1)
    m.recolor(ax, ax + 3, 43, 43, -4, 4, W + '_dk')
    m.part = 'arm'
    m.cbox(ax, ax + 3, 37, 38, -2, 2, F)                                   # 肘
    m.cbox(ax + 1, ax + 2, 37, 40, -3, -3, S)
    if P.get('noforearm'):
        m.part = 'body'; return
    FO = P.get('fore', W)
    def fore(y):                                                            # 前臂：上窄下宽
        return (ax - 1, ax + 4 + (1 if y < 32 else 0), -3, 4 if y < 32 else 3)
    m.slab(28, 37, fore, FO, c=2)
    m.cbox(ax - 1, ax + 5, 28, 29, -4, 5, P.get('cuff', S), c=1, edges='y')
    m.cbox(ax + 5, ax + 5, 31, 35, -2, 2, FO + '_dk')
    # 手（握拳）
    m.cbox(ax, ax + 3, 23, 27, -2, 3, F, c=1, edges='xz')
    m.cbox(ax, ax + 3, 23, 25, 4, 4, F)
    m.recolor(ax, ax + 3, 25, 25, 3, 4, F + '_lt')
    m.part = 'body'


def backpack(m, P):
    W, S, F, G = P['W'], P['S'], P['F'], P['G']
    BP = P.get('bp', S); BS = P.get('bst', W)
    m.cbox(0, 5, 43, 54, -10, -5, BP, c=2)                                 # 背包本体
    m.recolor(0, 5, 48, 48, -11, -5, BP + '_dk')
    m.cbox(0, 2, 45, 52, -11, -11, F)
    for y in (46, 48, 50): m.box(0, y, -11, 1, y, -11, F + '_lt')
    m.cbox(1, 3, 39, 43, -10, -7, F, c=1, edges='y')                       # 主推进口
    m.cbox(1, 2, 39, 39, -9, -8, G)
    # 两侧推进筒：圆柱 + 喷口 + 顶盖
    m.cyl('y', 7.5, -9.5, 2.6, 42, 53, BS)
    m.cyl('y', 7.5, -9.5, 2.6, 52, 53, BS + '_lt')
    m.cyl('y', 7.5, -9.5, 1.6, 54, 54, F)
    m.cyl('y', 7.5, -9.5, 2.0, 38, 41, F, r2=2.6)
    m.cyl('y', 7.5, -9.5, 1.4, 38, 38, G)
    m.recolor(5, 10, 47, 47, -13, -6, BS + '_dk', only={BS})
    m.cbox(5, 6, 47, 52, -9, -6, F)                                         # 连接架
    # 尾喷口：主推进器后方的喇叭口（向后喷射），两侧推进筒喷口朝下（辅助 / 升降）
    m.cbox(1, 3, 40, 43, -12, -11, F, c=0)
    m.cbox(1, 3, 40, 43, -13, -13, F + '_lt', c=0)
    m.box(1, 41, -14, 3, 42, -14, G)
    m.rig['rearL'] = (2.5, 42.0, -14.0); m.rig['rearR'] = (-2.5, 42.0, -14.0)
    m.rig['vernL'] = (7.5, 38.0, -9.5); m.rig['vernR'] = (-7.5, 38.0, -9.5)


def base(m, P, parts=('legs', 'waist', 'torso', 'head', 'shoulder', 'arm', 'backpack')):
    if 'legs' in parts: legs(m, P)
    if 'waist' in parts: waist(m, P)
    if 'torso' in parts: torso(m, P)
    if 'head' in parts and not P.get('nohead'): head_base(m, P)
    if 'shoulder' in parts: shoulder(m, P)
    if 'arm' in parts: arm(m, P)
    if 'backpack' in parts: backpack(m, P)


def core(m, k, y0=48, y1=51, z=9):
    """胸口菱形能量核心（中线）"""
    for y in range(y0, y1 + 1):
        d = min(y - y0, y1 - y)
        m.box(0, y, z - 1, -1, y, z, k)
        if d >= 1: m.box(1, y, z - 1, -2, y, z - 1, k)
