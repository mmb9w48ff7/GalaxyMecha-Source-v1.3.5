# -*- coding: utf-8 -*-
"""把网页版（preview/src）里的玩法数据导出成 UrhoX 用的 Lua：scripts/cosmic/Data.lua
数据来源：window.Cosmic 的纯数据字段（机甲 / 驾驶员 / 章节 / 技能形态 / 元素 / 进化 / 召唤概率……）+ cosmic_run.js 里的 ENEMY 敌人表。
用法：python3 tools/export_cosmic_data.py     需要 playwright + chromium 与 node。"""
import os, json, subprocess, re, asyncio, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from voxlib import lua_value
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEYS = ['GRADE', 'MECHS', 'CHARS', 'CHAPTERS', 'MOD_FORMS', 'ELEMENTS', 'MOD_TAGS', 'RARITY', 'EVO', 'GOLD_FX', 'SUMMON', 'DC_MODS', 'LOGIN_REWARDS', 'REACT_HINT',
        'CHIP_SERIES', 'TRAITS', 'INV_MAX', 'TASKS', 'DAILY_SUPPLY', 'MOD_RARITY_MULT', 'LV_MAX', 'DC_TIME', 'REFUND', 'CHIP_STATS', 'VARIANTS', 'EVO_PASS_LV', 'MATCH_BONUS', 'IDLE_CAP_H']
def enemy_table():
    src = open(os.path.join(ROOT, 'preview', 'src', 'cosmic_run.js'), encoding='utf-8').read()
    i = src.index('var ENEMY = {'); j = src.index('{', i); depth = 0
    for k in range(j, len(src)):
        depth += src[k] == '{'; depth -= src[k] == '}'
        if depth == 0: break
    code = 'var t=' + src[j:k + 1] + ';console.log(JSON.stringify(t))'
    return json.loads(subprocess.run(['node', '-e', code], capture_output=True, text=True, check=True).stdout)
async def cosmic():
    from playwright.async_api import async_playwright
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path=os.environ.get('CHROMIUM', '/opt/pw-browsers/chromium-1243/chrome-linux64/chrome'), args=['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--no-sandbox'])
        pg = await b.new_page(); await pg.goto('file://' + os.path.join(ROOT, 'preview', 'index.html')); await pg.wait_for_timeout(1200)
        d = await pg.evaluate("(keys) => { const C = window.Cosmic, o = {}; keys.forEach(k => { if (C[k] !== undefined && typeof C[k] !== 'function') o[k] = JSON.parse(JSON.stringify(C[k], (kk, v) => typeof v === 'function' ? undefined : v)); }); return o; }", KEYS)
        await b.close(); return d
def main():
    data = asyncio.run(cosmic()); data['ENEMY'] = enemy_table()
    out = os.path.join(ROOT, 'scripts', 'cosmic', 'Data.lua'); os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'w', encoding='utf-8') as f: f.write('-- 由 tools/export_cosmic_data.py 自动生成：宇宙银河机甲玩法数据（请勿手改）\nreturn ' + lua_value(data) + '\n')
    print(out, {k: (len(v) if hasattr(v, '__len__') else v) for k, v in data.items()})
if __name__ == '__main__': main()
