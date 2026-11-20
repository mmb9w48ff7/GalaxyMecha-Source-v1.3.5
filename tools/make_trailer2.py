# -*- coding: utf-8 -*-
"""宣传片 v2：游戏内逐帧录制的动态镜头 + 动态字幕 + 转场 + 配乐音效。
流程：tools/record_trailer.py 逐帧录制各镜头到 marketing/trailer_frames/<镜头>/f00000.jpg，然后运行本脚本合成：
    python3 tools/make_trailer2.py        -> marketing/宇宙银河机甲_宣传片_动态版.mp4
输出：1920x1080 / 30fps / H.264(High, yuv420p) + AAC / 横屏 16:9。"""
import os, subprocess, random, math, sys
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FR = os.environ.get('TRAILER_FRAMES', os.path.join(ROOT, 'marketing', 'trailer_frames'))
ST = os.path.join(ROOT, 'marketing', 'trailer_stills'); TMP = os.path.join(ROOT, 'marketing', '_tmp'); os.makedirs(TMP, exist_ok=True)
AUD = os.path.join(ROOT, 'assets', 'audio')
OUT = os.environ.get('TRAILER_OUT', os.path.join(ROOT, 'marketing', '宇宙银河机甲_宣传片_动态版.mp4'))
W, H, FPS = 1920, 1080, 30
FONT = '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc'
def font(sz):
    for idx in (2, 0, 1, 3):
        try: return ImageFont.truetype(FONT, sz, index=idx)
        except Exception: pass
    return ImageFont.load_default()
def run(cmd): subprocess.run(cmd, check=True)

def cap_png(name, l1, l2, accent):
    """字幕块：左侧强调色竖条 + 大标题 + 副标题（透明底，由 ffmpeg 做滑入 / 淡入淡出）；标题过长时自动缩小字号"""
    CW = 1760; im = Image.new('RGBA', (CW, 250), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    sz = 92
    while sz > 52 and d.textlength(l1, font=font(sz)) > CW - 120: sz -= 4
    for x in range(CW):                                                # 左深右透的底板
        a = int(165 * max(0, 1 - x / CW) ** 0.9); d.line([(x, 10), (x, 240)], fill=(6, 9, 28, a))
    d.rectangle([0, 20, 12, 230], fill=accent + (255,))
    d.text((44, 30 + (92 - sz) // 2), l1, font=font(sz), fill=accent + (255,), stroke_width=4, stroke_fill=(8, 10, 30, 255))
    if l2: d.text((48, 148), l2, font=font(46), fill=(238, 241, 252, 255), stroke_width=3, stroke_fill=(8, 10, 30, 255))
    p = os.path.join(TMP, name + '.png'); im.save(p); return p
def title_png(name, l1, l2, accent=(255, 200, 80)):
    im = Image.new('RGBA', (1700, 420), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.text((850, 150), l1, font=font(200), fill=accent + (255,), anchor='mm', stroke_width=9, stroke_fill=(8, 10, 30, 255))
    d.text((850, 320), l2, font=font(58), fill=(238, 241, 252, 255), anchor='mm', stroke_width=4, stroke_fill=(8, 10, 30, 255))
    p = os.path.join(TMP, name + '.png'); im.save(p); return p
def starbg(name, seed):
    rnd = random.Random(seed); im = Image.new('RGB', (W, H)); d = ImageDraw.Draw(im)
    for y in range(H): d.line([(0, y), (W, y)], fill=(5 + y // 70, 7 + y // 90, 22 + y // 30))
    for _ in range(520):
        x, y, r = rnd.randrange(W), rnd.randrange(H), rnd.choice([1, 1, 2, 2, 3]); d.rectangle([x, y, x + r, y + r], fill=rnd.choice([(235, 240, 255), (150, 240, 230), (255, 220, 160)]))
    p = os.path.join(TMP, name + '.jpg'); im.save(p, quality=93); return p

# 镜头：(目录, 帧数, 字幕(标题, 副标题, 强调色) | None)
SHOTS = [
    ('a_intro', 90, None),
    ('m1_azure', 72, ('苍星  S', '均衡型 · 星轨射线枪连发两击', (87, 184, 255))),
    ('m2_blaze', 72, ('炎铠  S', '重装型 · 三管散射炮 + 热能斧', (87, 184, 255))),
    ('m3_halo', 72, ('月辉  SS', '支援型 · 追踪光弹与治疗领域', (180, 124, 255))),
    ('m4_frost', 72, ('霜鸣  SS', '火力型 · 肩载导弹雨', (180, 124, 255))),
    ('m5_starfall', 72, ('天殒  SSR', '星核型 · 陨星坠击', (245, 165, 36))),
    ('m6_forge', 72, ('琥珀工兵  SSSR', '工程型 · 双臂机炮 + 炮台阵列', (255, 93, 122))),
    ('c_boss', 105, ('首领战', '看准红线，氮气躲开激光', (255, 120, 140))),
    ('d_swarm', 90, ('元素反应', '碎冰 · 爆燃 · 麻痹 · 湮灭　5 种新敌人', (255, 200, 80))),
    ('f_outro', 90, None),
]
def encode_shot(name, n, cap, idx):
    out = os.path.join(TMP, 's%02d.mp4' % idx); dur = n / FPS
    grade = "eq=contrast=1.08:saturation=1.18:brightness=0.01,unsharp=5:5:0.6,vignette=PI/5.2"
    ins = ['-framerate', str(FPS), '-i', os.path.join(FR, name, 'f%05d.jpg')]; fc = ['[0:v]%s,format=yuv420p[g]' % grade]; last = 'g'
    if cap:
        p = cap_png('cap%02d' % idx, *cap); ins += ['-loop', '1', '-t', '%0.2f' % dur, '-i', p]
        fc.append("[1:v]format=rgba,fade=t=in:st=0.12:d=0.28:alpha=1,fade=t=out:st=%0.2f:d=0.25:alpha=1[c]" % (dur - 0.3))
        fc.append("[%s][c]overlay=x='60+(1-min(t/0.4\\,1))*-340':y=H-h-60:format=auto[o]" % last); last = 'o'
    if name == 'a_intro':
        t = title_png('title', '宇宙银河机甲', '体素 Q 版 · 机甲割草 · 一局 6 分钟'); ins += ['-loop', '1', '-t', '%0.2f' % dur, '-i', t]
    out_args = ['-t', '%0.3f' % dur, '-c:v', 'libx264', '-preset', 'medium', '-crf', '15', '-pix_fmt', 'yuv420p', '-r', str(FPS), out]
    if name == 'a_intro':
        fc.append("[1:v]format=rgba,fade=t=in:st=0.7:d=0.5:alpha=1,fade=t=out:st=%0.2f:d=0.35:alpha=1,scale=w='iw*(1.12-0.12*min(max(t-0.7\\,0)/0.6\\,1))':h=-1:eval=frame[t]" % (dur - 0.45))
        fc.append("[%s][t]overlay=x=(W-w)/2:y=(H-h)/2-80:format=auto[o2]" % last); last = 'o2'
    run(['ffmpeg', '-y', '-loglevel', 'error'] + ins + ['-filter_complex', ';'.join(fc), '-map', '[%s]' % last] + out_args)
    return out, dur
def feature_clip(name, cards, title, sub, dur, idx):
    """玩法特色：星空底 + UI 截图卡片从右侧滑入（带阴影），左上标题"""
    bg = starbg('bg' + name, idx)
    out = os.path.join(TMP, 's%02d.mp4' % idx); ins = ['-loop', '1', '-t', '%0.2f' % dur, '-i', bg]
    fc = []; last = '0:v'
    cp = cap_png('fcap%02d' % idx, title, sub, (255, 200, 80)); ins += ['-loop', '1', '-t', '%0.2f' % dur, '-i', cp]
    fc.append("[1:v]format=rgba,fade=t=in:st=0.1:d=0.3:alpha=1,fade=t=out:st=%0.2f:d=0.25:alpha=1[c]" % (dur - 0.3)); k = 2
    for j, (img, x, y, w) in enumerate(cards):
        ins += ['-loop', '1', '-t', '%0.2f' % dur, '-i', os.path.join(ST, img)]
        fc.append("[%d:v]scale=%d:-2,format=rgba,pad=iw+16:ih+16:8:8:color=0xFFC850@1[k%d]" % (k, w, j))
        d0 = 0.2 + 0.25 * j
        fc.append("[%s][k%d]overlay=x='%d+(1-min(max(t-%0.2f\\,0)/0.5\\,1))^3*1400':y='%d+6*sin(t*1.6+%d)':format=auto[b%d]" % (last, j, x, d0, y, j, j)); last = 'b%d' % j; k += 1
    fc.append("[%s][c]overlay=x='60+(1-min(t/0.4\\,1))*-340':y=40:format=auto,eq=contrast=1.05:saturation=1.1,format=yuv420p[o]" % last)
    run(['ffmpeg', '-y', '-loglevel', 'error'] + ins + ['-filter_complex', ';'.join(fc), '-map', '[o]', '-t', '%0.3f' % dur, '-c:v', 'libx264', '-preset', 'medium', '-crf', '15', '-pix_fmt', 'yuv420p', '-r', str(FPS), out])
    return out, dur
def outro_overlay(path, dur):
    """片尾：在 f_outro 镜头上叠加 Logo 与标语"""
    t = title_png('outro', '宇宙银河机甲', 'TapTap 测试招募中 · 体素 Q 版 · 肉鸽割草')
    out = os.path.join(TMP, 'outro_ov.mp4')
    fc = "[1:v]format=rgba,fade=t=in:st=0.5:d=0.6:alpha=1,scale=w='iw*(1.1-0.1*min(max(t-0.5\\,0)/0.7\\,1))':h=-1:eval=frame[t];[0:v][t]overlay=x=(W-w)/2:y=(H-h)/2-30:format=auto,fade=t=out:st=%0.2f:d=0.6,format=yuv420p[o]" % (dur - 0.6)
    run(['ffmpeg', '-y', '-loglevel', 'error', '-i', path, '-loop', '1', '-t', '%0.2f' % dur, '-i', t, '-filter_complex', fc, '-map', '[o]', '-t', '%0.3f' % dur, '-c:v', 'libx264', '-preset', 'medium', '-crf', '15', '-pix_fmt', 'yuv420p', '-r', str(FPS), out])
    return out

def main():
    clips = []; idx = 0
    for name, n, cap in SHOTS:
        p, d = encode_shot(name, n, cap, idx); clips.append((p, d, name)); idx += 1
    # 玩法特色卡片（插在首领战之后、片尾之前）
    f1 = feature_clip('f1', [('ui_work.jpg', 520, 250, 1180)], '1080 张技能卡牌', '白 / 蓝 / 紫 / 金，凑齐进化与元素反应', 2.6, 20)
    f2 = feature_clip('f2', [('ui_home.jpg', 120, 330, 900), ('ui_daily.jpg', 1000, 290, 840)], '危险等级 · 无尽模式 · 每日挑战', '每天都有新目标，永远有下一局', 2.8, 21)
    outp, od, _ = clips.pop()
    ov = outro_overlay(outp, od)
    seq = clips + [(f1[0], f1[1], 'f1'), (f2[0], f2[1], 'f2'), (ov, od, 'outro')]
    # 转场：机甲镜头之间用快速白闪，其余用淡入淡出
    XF = 0.18; inputs = []; fc = []
    for i, (p, d, nm) in enumerate(seq): inputs += ['-i', p]
    cur = '0:v'; t = seq[0][1]
    for i in range(1, len(seq)):
        trans = 'fadewhite' if seq[i][2].startswith('m') or seq[i][2] in ('c_boss', 'd_swarm') else 'fade'
        dd = 0.25 if trans == 'fade' else XF
        off = t - dd; fc.append("[%s][%d:v]xfade=transition=%s:duration=%0.2f:offset=%0.3f[x%d]" % (cur, i, trans, dd, off, i)); cur = 'x%d' % i; t = off + seq[i][1]
    total = t
    # 音频：BGM 循环 + 关键点音效（氮气 / 爆炸 / 胜利）
    bgm = os.path.join(AUD, 'bgm_battle.ogg'); sfx = [('sfx_nitro.ogg', 3.0, 1.0), ('sfx_boom.ogg', 5.4, 0.9), ('sfx_skill.ogg', 3.4, 0.8), ('sfx_nitro.ogg', 8.0, 1.0), ('sfx_win.ogg', total - 3.2, 1.0)]
    a_in = ['-stream_loop', '-1', '-i', bgm] + sum([['-i', os.path.join(AUD, s)] for s, _, _ in sfx], [])
    base = len(seq); afc = ["[%d:a]volume=0.85,afade=t=in:d=0.6,afade=t=out:st=%0.2f:d=2.2[m]" % (base, total - 2.2)]; mix = ['[m]']
    for j, (s, at, v) in enumerate(sfx): afc.append("[%d:a]adelay=%d,volume=%0.2f[e%d]" % (base + 1 + j, int(at * 1000), v, j)); mix.append('[e%d]' % j)
    afc.append("%samix=inputs=%d:normalize=0,alimiter=limit=0.95[a]" % (''.join(mix), len(mix)))
    cmd = ['ffmpeg', '-y', '-loglevel', 'error'] + inputs + a_in + ['-filter_complex', ';'.join(fc + afc), '-map', '[%s]' % cur, '-map', '[a]', '-t', '%0.2f' % total,
           '-c:v', 'libx264', '-profile:v', 'high', '-preset', 'medium', '-crf', '17', '-pix_fmt', 'yuv420p', '-r', str(FPS), '-c:a', 'aac', '-b:a', '256k', '-ar', '44100', '-ac', '2', '-movflags', '+faststart', OUT]
    run(cmd); print(OUT, 'duration %.2fs' % total)

if __name__ == '__main__':
    main()
