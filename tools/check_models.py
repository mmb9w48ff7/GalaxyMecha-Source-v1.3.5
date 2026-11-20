# -*- coding: utf-8 -*-
"""体素模型错误检查：浮空碎块、仅靠棱角相连、左右不对称、悬空到地面以下、部件标记、挂点位置、体素重叠等。
用法：python3 tools/check_models.py            检查全部机甲与角色
      python3 tools/check_models.py mech_azure  只检查指定模型"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from collections import deque
import models_mechs as MM, models_chars as MC, models_galaxy as MG
N6 = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]
def comps(V, nbrs):
    seen, out = set(), []
    for p in V:
        if p in seen: continue
        q = deque([p]); seen.add(p); c = [p]
        while q:
            a = q.popleft()
            for d in nbrs:
                b = (a[0] + d[0], a[1] + d[1], a[2] + d[2])
                if b in V and b not in seen: seen.add(b); q.append(b); c.append(b)
        out.append(c)
    return sorted(out, key=len, reverse=True)
N26 = [(a, b, c) for a in (-1, 0, 1) for b in (-1, 0, 1) for c in (-1, 0, 1) if (a, b, c) != (0, 0, 0)]
def check(m, kind):
    V = m.v; rep = []
    c6 = comps(V, N6)
    if len(c6) > 1:
        small = [c for c in c6[1:]]
        c26 = comps(V, N26)
        edge_only = len(c6) - len(c26)
        floating = [c for c in c26[1:]]
        if floating: rep.append(('浮空碎块', '%d 块（共 %d 体素，位置例 %s）' % (len(floating), sum(len(c) for c in floating), floating[0][0])))
        # 仅靠棱角（对角）相连的细小块（斜线武器、晶体等）在渲染上没有问题，不计入错误
    # 对称（x -> -1-x），机甲排除两只手臂的武器；角色排除手持物
    skipTags = {'armL', 'armR', 'uarmL', 'uarmR'} if kind == 'mech' else set()
    mis = [p for p, k in V.items() if m.tags.get(p, 'body') not in skipTags and V.get((-1 - p[0], p[1], p[2])) is None]
    mism = [p for p, k in V.items() if m.tags.get(p, 'body') not in skipTags and (-1 - p[0], p[1], p[2]) in V and V[(-1 - p[0], p[1], p[2])].replace('_lt', '').replace('_dk', '') != k.replace('_lt', '').replace('_dk', '')]
    if len(mis) > 0.08 * len(V): rep.append(('左右不对称过多（可能误画）', '%d 个体素（占 %.1f%%）' % (len(mis), 100.0 * len(mis) / len(V))))
    ys = [p[1] for p in V]; 
    if min(ys) < 0: rep.append(('低于地面(y<0)', 'y 最低 %d，共 %d 个体素' % (min(ys), sum(1 for p in V if p[1] < 0))))
    floor = [p for p in V if p[1] == 0]
    if not floor: rep.append(('脚底不在 y=0', '最低 y=%d' % min(ys)))
    # 质心是否落在脚底范围内（站得稳）
    cx = sum(p[0] for p in V) / len(V); cz = sum(p[2] for p in V) / len(V)
    if floor:
        fx0, fx1 = min(p[0] for p in floor), max(p[0] for p in floor); fz0, fz1 = min(p[2] for p in floor), max(p[2] for p in floor)
        if kind == 'mech' and not (fx0 <= cx <= fx1 and fz0 - 4 <= cz <= fz1 + 4): rep.append(('质心不在脚底上方', '质心 x=%.1f z=%.1f，脚底 x[%d,%d] z[%d,%d]' % (cx, cz, fx0, fx1, fz0, fz1)))
    # 部件标记（机甲）
    if kind == 'mech':
        tc = {}
        for p in V: t = m.tags.get(p, 'body'); tc[t] = tc.get(t, 0) + 1
        need = ['head', 'body', 'armL', 'armR', 'thighL', 'thighR', 'shinL', 'shinR']
        miss = [t for t in need if tc.get(t, 0) == 0]
        if miss: rep.append(('缺少部件标记', ','.join(miss)))
        odd = [t for t in tc if t not in need and t not in ('uarmL', 'uarmR')]
        if odd: rep.append(('未知部件标记', ','.join(odd)))
        xs = [p[0] for p in V]; zs = [p[2] for p in V]
        for n, pt in m.rig.items():
            pts = pt if isinstance(pt[0], (list, tuple)) else [pt]
            for q in pts:
                if not (min(xs) - 6 <= q[0] <= max(xs) + 6 and min(ys) - 6 <= q[1] <= max(ys) + 6 and min(zs) - 6 <= q[2] <= max(zs) + 6): rep.append(('挂点超出模型包围盒', '%s %s' % (n, q)))
        need_rig = ['neck', 'waist', 'shoulderL', 'shoulderR', 'elbowL', 'elbowR', 'hipL', 'hipR', 'kneeL', 'kneeR', 'footL', 'footR']
        mr = [r for r in need_rig if r not in m.rig]
        if not any(r.startswith('muzzle') for r in m.rig): mr.append('任意枪口（muzzleL / muzzleR / muzzleP）')
        if mr: rep.append(('缺少挂点', ','.join(mr)))
    # 材质：未定义的材质键
    bad = sorted({k for k in V.values() if k not in m.pal})
    if bad: rep.append(('使用了未定义的材质', ','.join(bad)))
    # 面部（角色）：眼睛体素数量
    if kind == 'char':
        hole = [(x, y, z) for x in range(-4, 4) for y in range(11, 19) for z in range(-3, 5) if (x, y, z) not in V]
        if hole: rep.append(('头部有空洞', '头部 8x8x8 范围内缺 %d 个体素（层 y=%s）' % (len(hole), sorted({p[1] for p in hole}))))
        eyes = sum(1 for k in V.values() if k in ('eye', 'iris', 'iris_d'))
        if eyes < 6: rep.append(('眼睛体素过少', str(eyes)))
    return rep
def main():
    want = set(sys.argv[1:])
    items = [(m, 'mech') for m in MM.all_mechs() if m.id.startswith('mech_')] + [(m, 'char') for m in MC.all_chars() + MG.all_galaxy() if m.id.startswith('char_')]
    total = 0
    for m, kind in items:
        if want and m.id not in want: continue
        rep = check(m, kind); total += len(rep)
        xs = [p[0] for p in m.v]; ys = [p[1] for p in m.v]; zs = [p[2] for p in m.v]
        print('%-18s 体素 %5d  尺寸 %dx%dx%d  %s' % (m.id, len(m.v), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1, max(zs) - min(zs) + 1, '无问题' if not rep else '%d 类问题' % len(rep)))
        for k, v in rep: print('    - %s：%s' % (k, v))
    print('合计问题类别：', total)
if __name__ == '__main__': main()
