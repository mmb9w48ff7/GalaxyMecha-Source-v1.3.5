# -*- coding: utf-8 -*-
"""生成 UrhoX 发布包：dist/UrhoX_Release/（只含运行所需文件）。
用法（工程根目录）：python3 tools/build_xpile.py && python3 tools/build_urhox_release.py"""
import os, re, shutil, json, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'dist', 'UrhoX_Release'); VERSION = "1.3.5"
def cp(src, dst): os.makedirs(os.path.dirname(dst), exist_ok=True); shutil.copy2(src, dst)
def main():
    if os.path.exists(OUT): shutil.rmtree(OUT)
    S = os.path.join(ROOT, 'scripts')
    cp(os.path.join(S, 'main.lua'), os.path.join(OUT, 'scripts', 'main.lua'))
    for f in ("GameApp", "GameUI", "Hub", "UI", "Util", "Sound", "Sdk", "WebUI", "Sha256", "Keypad", "Redeem", "RedeemKey", "DevUI"): cp(os.path.join(S, 'cosmic', f + '.lua'), os.path.join(OUT, 'scripts', 'cosmic', f + '.lua'))
    for f in os.listdir(os.path.join(S, 'jsrt')):
        if f.endswith('.lua') and f != 'CosmicRunTrace.lua': cp(os.path.join(S, 'jsrt', f), os.path.join(OUT, 'scripts', 'jsrt', f))
    cp(os.path.join(S, 'game', 'VoxelBuilder.lua'), os.path.join(OUT, 'scripts', 'game', 'VoxelBuilder.lua'))
    for f in ('Rigs', 'Catalog', 'Scenes'): cp(os.path.join(S, 'voxeldata', f + '.lua'), os.path.join(OUT, 'scripts', 'voxeldata', f + '.lua'))     # Rigs：机甲分件挂点；Catalog / Scenes：像素图标
    # 需要的模型：运行代码里出现的字符串字面量 ∩ 可用模型，加上 6 台机甲的整机 / 分件 / 驾驶员
    avail = {f[:-4] for f in os.listdir(os.path.join(S, 'voxeldata', 'models')) if f.endswith('.lua')}
    srcs = [os.path.join(ROOT, 'preview', 'src', 'cosmic_run.js'), os.path.join(ROOT, 'preview', 'src', 'cosmic_data.js'), os.path.join(S, 'cosmic', 'Hub.lua'), os.path.join(S, 'jsrt', 'CosmicRun.lua')]
    lit = set()
    for p in srcs: lit |= set(re.findall(r"""['"]([a-z][a-z0-9_]+)['"]""", open(p, encoding='utf-8').read()))
    ids = {x for x in lit if x in avail}
    rigs = open(os.path.join(S, 'voxeldata', 'Rigs.lua'), encoding='utf-8').read()
    for mech in re.findall(r'^    (mech_[a-z]+) = \{', rigs, re.M):
        ids.add(mech)
        for part in ('body', 'head', 'uarmL', 'uarmR', 'armL', 'armR', 'thighL', 'thighR', 'shinL', 'shinR'): ids.add('%s__%s' % (mech, part))
    for c in avail:
        if c.startswith('char_') or c.startswith('enemy_') or c.startswith('ship_') or c.startswith('fx_') or c.startswith('sys_'): ids.add(c)
    for mid in sorted(ids): cp(os.path.join(S, 'voxeldata', 'models', mid + '.lua'), os.path.join(OUT, 'scripts', 'voxeldata', 'models', mid + '.lua'))
    snd = os.path.join(ROOT, 'assets', 'Sounds')
    for f in os.listdir(snd): cp(os.path.join(snd, f), os.path.join(OUT, 'assets', 'Sounds', f))
    os.makedirs(os.path.join(OUT, '.project'), exist_ok=True)
    open(os.path.join(OUT, '.project', 'resources.json'), 'w', encoding='utf-8').write(json.dumps({'preload_groups': [], 'groups': {'default': ['**']}}, indent=2) + '\n')
    open(os.path.join(OUT, '.project', 'settings.json'), 'w', encoding='utf-8').write(json.dumps({'build': {'asset_dirs': ['../assets', '../scripts']}}, indent=2) + '\n')
    for f in ('RELEASE_NOTES.md', '提审清单.md', '隐私政策模板.md', '用户协议模板.md', 'TapTap制造接入指南.md', 'UrhoX版与网页版一致性对照.md'):
        p = os.path.join(ROOT, 'docs', 'release', f)
        if os.path.exists(p): cp(p, os.path.join(OUT, 'docs', f))
    cp(os.path.join(ROOT, 'docs', 'UrhoX移植说明.md'), os.path.join(OUT, 'docs', 'UrhoX移植说明.md'))
    st = os.path.join(ROOT, 'marketing', 'store')
    if os.path.isdir(st):
        for f in os.listdir(st): cp(os.path.join(st, f), os.path.join(OUT, 'store', f))
    open(os.path.join(OUT, 'VERSION'), 'w').write(VERSION + '\n')
    n = sum(len(fs) for _, _, fs in os.walk(OUT)); size = sum(os.path.getsize(os.path.join(d, f)) for d, _, fs in os.walk(OUT) for f in fs)
    print('发布包：', OUT, n, '个文件', round(size / 1024 / 1024, 1), 'MB；模型', len(ids), '个')
if __name__ == '__main__': main()
