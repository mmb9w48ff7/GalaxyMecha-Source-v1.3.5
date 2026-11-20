# -*- coding: utf-8 -*-
"""把网页版 cosmic_data.js / cosmic_run.js 转成 UrhoX 用的 Lua（scripts/jsrt/CosmicData.lua、CosmicRun.lua）。
网页版是唯一的玩法源码；这里只做两件事：①极少量的“界面钩子补丁”（把结算数据存进 R.result，供 NanoVG 界面显示）；②调用 tools/xpile/transpile.js。
用法：python3 tools/build_xpile.py            （需要 node 与 acorn：NODE_PATH 或 /opt/npm-tools/node_modules）"""
import os, subprocess, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'preview', 'src'); OUT = os.path.join(ROOT, 'scripts', 'jsrt'); TMP = '/tmp/xpile_build'; os.makedirs(TMP, exist_ok=True)
def patch(text, pairs):
    for a, b in pairs:
        assert text.count(a) == 1, '补丁锚点必须唯一：' + a[:60]
        text = text.replace(a, b)
    return text
run = open(os.path.join(SRC, 'cosmic_run.js'), encoding='utf-8').read()
run = patch(run, [("    var m = modal('<div class=\"panel sv-pbox\"><h1>' + (R.daily ?",
    "    R.result = { win: win, retreat: retreat, credits: credits, src: src, first: first, dgUnlock: dgUnlock, dcScore: dcScoreV, dcFirst: dcFirst, achNow: achNow, fragTxt: fragTxt };\n    var m = modal('<div class=\"panel sv-pbox\"><h1>' + (R.daily ?")])
open(os.path.join(TMP, 'cosmic_run.js'), 'w', encoding='utf-8').write(run)
T = os.path.join(ROOT, 'tools', 'xpile', 'transpile.js')
def go(args):
    r = subprocess.run(['node', T] + args, capture_output=True, text=True, env={**os.environ, 'NODE_PATH': '/opt/npm-tools/node_modules'}); print(r.stdout.strip()); 
    if r.returncode: print(r.stderr); sys.exit(1)
go([os.path.join(TMP, 'cosmic_run.js'), os.path.join(OUT, 'CosmicRun.lua'), '--name=run'])
go([os.path.join(SRC, 'cosmic_data.js'), os.path.join(OUT, 'CosmicData.lua'), '--name=data', '--skiplines=241-293', '--skip=b64buf,loadAudio,stopMusic'])
