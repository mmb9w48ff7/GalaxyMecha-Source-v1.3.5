# -*- coding: utf-8 -*-
"""在多种屏幕比例下渲染关键界面，检查排布不被裁切：python3 tools/run_shot_multi.py"""
import sys, os, json, glob
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE); import luart
from nvg_render import render
from PIL import Image
os.chdir(os.path.dirname(HERE)); os.makedirs('/home/claude/work/ui', exist_ok=True)
RES = [(2400, 1080, '20x9'), (1728, 1080, '16x10'), (1440, 1080, '4x3'), (1280, 720, '16x9')]
KEEP = ['home', 'hangar', 'work_mods', 'daily', 'hud', 'levelup', 'result']
for (w, h, tag) in RES:
    os.environ['SHOT_W'] = str(w); os.environ['SHOT_H'] = str(h); os.environ['SHOT_TAG'] = tag + '_'
    st = luart.new()
    r = luart.dostring(st, '''package.path="scripts/?.lua;scripts/?/init.lua;"..package.path
local f,err=loadfile("tools/shot_ui.lua"); if not f then print("LOADERR",err) return end
local ok,e=xpcall(f, debug.traceback); if not ok then print("RUNTIME ERROR:\\n"..tostring(e):sub(1,500)) end''')
    for n in KEEP:
        p = '/tmp/ui_%s_%s.json' % (tag, n)
        if os.path.exists(p):
            render(json.load(open(p)), w, h).convert('RGB').save('/home/claude/work/ui/%s_%s.png' % (tag, n))
    print('完成', tag, w, h)
