# -*- coding: utf-8 -*-
"""检查机甲分件：按部件染色，输出 前 / 后 两个视角的 PNG（preview/parts_check.png）。"""
import os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from models_mechs import all_mechs
from check_render import render

COL = {'body': '#8890A8', 'head': '#FFD166', 'armL': '#EF476F', 'armR': '#06D6A0', 'thighL': '#118AB2', 'thighR': '#073B4C',
       'shinL': '#B5179E', 'shinR': '#F77F00'}

def tinted(m):
    from voxlib import VoxModel
    t = VoxModel(m.id, m.name, 'mech', m.scale, '')
    for name, c in COL.items(): t.mat(name, c, metal=0.2, rough=0.5)
    for p in m.v:
        tag = m.tags.get(p, 'body')
        t.v[p] = tag if tag in COL else 'body'
    return t

if __name__ == '__main__':
    mechs = [m for m in all_mechs() if m.id.startswith('mech_')]
    W = 360
    sheet = Image.new('RGB', (W * len(mechs), W * 2), (24, 28, 52))
    for i, m in enumerate(mechs):
        t = tinted(m)
        sheet.paste(render(t, size=W, yaw=35, pitch=20), (i * W, 0))
        sheet.paste(render(t, size=W, yaw=215, pitch=20), (i * W, W))
        cnt = {}
        for p in m.v: cnt[m.tags.get(p, 'body')] = cnt.get(m.tags.get(p, 'body'), 0) + 1
        print(m.id, cnt)
    out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'preview', 'parts_check.png')
    sheet.save(out); print(out)
