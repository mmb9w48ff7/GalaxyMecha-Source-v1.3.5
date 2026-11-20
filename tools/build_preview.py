# -*- coding: utf-8 -*-
"""把数据、渲染器与游戏逻辑内联成单文件：
   preview/index.html       正式版
   preview/index_test.html  测试版（带测试面板）"""
import os, json, re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = os.path.join(ROOT, 'preview', 'src')
def rd(*p): return open(os.path.join(*p), encoding='utf-8').read()
# 只保留游戏需要的数据：模型、图鉴图标、资源图标、展示灯光
raw = rd(ROOT, 'preview', 'data', 'assets.js')
def grab(name):
    m = re.search(r'window\.' + name + r'=(.*?);\n', raw, re.S); return json.loads(m.group(1))
scenes = grab('VOX_SCENES')
data = ('window.VOX_MODELS=' + json.dumps(grab('VOX_MODELS'), ensure_ascii=False, separators=(',', ':')) + ';\n' +
        'window.VOX_CATALOG=' + json.dumps(grab('VOX_CATALOG'), ensure_ascii=False, separators=(',', ':')) + ';\n' +
        'window.VOX_SCENES=' + json.dumps({'resIcons': scenes['resIcons'], 'gallery': scenes['gallery']}, ensure_ascii=False, separators=(',', ':')) + ';\n')
if os.path.exists(os.path.join(ROOT, 'preview', 'data', 'audio.js')): data += rd(ROOT, 'preview', 'data', 'audio.js')
data = data.replace('</script', '<\\/script')
tpl = rd(src, 'index.template.html')
base = (tpl.replace('/*DATA*/', data).replace('/*ENGINE*/', rd(src, 'engine.js'))
           .replace('/*COSMIC*/', rd(src, 'cosmic_data.js') + '\n' + rd(src, 'cosmic_run.js') + '\n' + rd(src, 'cosmic_hub.js') + '\n' + rd(src, 'cosmic_redeem_key.js') + '\n' + rd(src, 'cosmic_dev.js'))
           .replace('/*BOOT*/', rd(src, 'boot.js')))
release = base.replace('<!--TEST-->', '').replace('/*TESTCSS*/', '')
test = (base.replace('<!--TEST-->', '<script>' + rd(src, 'test.js') + '</script>').replace('/*TESTCSS*/', rd(src, 'test.css'))
            .replace('<title>宇宙银河玩家</title>', '<title>宇宙银河玩家 测试版</title>'))
for name, html in (('index.html', release), ('index_test.html', test)):
    open(os.path.join(ROOT, 'preview', name), 'w', encoding='utf-8').write(html)
    print('preview/' + name, len(html.encode('utf-8')) // 1024, 'KB')
