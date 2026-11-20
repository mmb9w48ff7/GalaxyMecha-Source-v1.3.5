# -*- coding: utf-8 -*-
"""合成宣传片 marketing/宇宙银河机甲_宣传片.mp4（1920x1080 / 30fps / H.264 + AAC / 横屏 16:9 / 约 32 秒）。
素材：marketing/trailer_stills/*.jpg（游戏内截图，由 Playwright 截取）；音乐：assets/audio/bgm_battle.ogg。
用法：python3 tools/make_trailer.py     需要 ffmpeg(libx264, aac)、Pillow、系统里的 Noto Sans CJK 字体。"""
import os, subprocess, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ST = os.path.join(ROOT, 'marketing', 'trailer_stills'); TMP = os.path.join(ROOT, 'marketing', '_tmp'); os.makedirs(TMP, exist_ok=True)
OUT = os.path.join(ROOT, 'marketing', '宇宙银河机甲_宣传片.mp4')
W, H, FPS, XF = 1920, 1080, 30, 0.35
FONT = '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc'
def font(sz):
    for idx in (2, 0, 1, 3):
        try: return ImageFont.truetype(FONT, sz, index=idx)
        except Exception: pass
    return ImageFont.load_default()

def caption(name, line1, line2=None, big=False, accent=(255, 200, 80)):
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    if not big:
        for y in range(H - 330, H):                                  # 底部渐变压暗，保证文字清晰
            a = int(210 * ((y - (H - 330)) / 330) ** 1.4); d.line([(0, y), (W, y)], fill=(5, 8, 24, a))
        d.text((110, H - 235), line1, font=font(84), fill=accent + (255,), stroke_width=4, stroke_fill=(10, 12, 34, 255))
        if line2: d.text((114, H - 125), line2, font=font(44), fill=(235, 238, 250, 255), stroke_width=3, stroke_fill=(10, 12, 34, 255))
    else:
        d.text((W // 2, 420), line1, font=font(190), fill=accent + (255,), anchor='mm', stroke_width=8, stroke_fill=(10, 12, 34, 255))
        if line2: d.text((W // 2, 610), line2, font=font(56), fill=(235, 238, 250, 255), anchor='mm', stroke_width=4, stroke_fill=(10, 12, 34, 255))
    p = os.path.join(TMP, name + '_cap.png'); im.save(p); return p

def starfield(name, seed):
    rnd = random.Random(seed); im = Image.new('RGB', (W, H), (6, 8, 26)); d = ImageDraw.Draw(im)
    for y in range(H): d.line([(0, y), (W, y)], fill=(6 + y // 60, 8 + y // 80, 26 + y // 28))
    for _ in range(420):
        x, y, r = rnd.randrange(W), rnd.randrange(H), rnd.choice([1, 1, 2, 2, 3]); c = rnd.choice([(235, 240, 255), (150, 240, 230), (255, 220, 160)]); d.rectangle([x, y, x + r, y + r], fill=c)
    p = os.path.join(TMP, name + '.jpg'); im.save(p, quality=92); return p

def bgpic(stem):
    return os.path.join(ST, stem + '.jpg')

# (背景图, 时长, 焦点(x,y 占画面比例), 起止缩放, 标题, 副标题, 是否大标题, 强调色)
CLIPS = [
    (starfield('intro', 3), 3.4, (0.5, 0.5), (1.0, 1.06), '宇宙银河机甲', '体素 Q 版 · 机甲割草 · 一局 6 分钟', True, (255, 200, 80)),
    (bgpic('mech_azure'), 1.9, (0.40, 0.55), (1.25, 1.55), '苍星  S', '均衡型 · 星轨射线枪 · 连发两击', False, (87, 184, 255)),
    (bgpic('mech_blaze'), 1.9, (0.40, 0.55), (1.25, 1.55), '炎铠  S', '重装型 · 三管散射炮 + 热能斧', False, (87, 184, 255)),
    (bgpic('mech_halo'), 1.9, (0.40, 0.55), (1.25, 1.55), '月辉  SS', '支援型 · 追踪光弹与治疗领域', False, (180, 124, 255)),
    (bgpic('mech_frost'), 1.9, (0.40, 0.55), (1.25, 1.55), '霜鸣  SS', '火力型 · 肩载导弹雨', False, (180, 124, 255)),
    (bgpic('mech_starfall'), 1.9, (0.40, 0.55), (1.25, 1.55), '天殒  SSR', '星核型 · 陨星坠击', False, (245, 165, 36)),
    (bgpic('mech_forge'), 2.2, (0.40, 0.55), (1.25, 1.6), '琥珀工兵  SSSR', '工程型 · 双臂机炮 + 炮台阵列', False, (255, 93, 122)),
    (bgpic('b_beam'), 1.8, (0.45, 0.62), (1.1, 1.5), '自动锁定 一键放技能', '射线贯穿，清空整条战线', False, (255, 200, 80)),
    (bgpic('b_forge'), 1.8, (0.5, 0.62), (1.1, 1.5), '炮台阵列', '把火力部署在战场上', False, (255, 200, 80)),
    (bgpic('b_frost'), 1.8, (0.5, 0.6), (1.05, 1.4), '导弹雨', '覆盖整片星域', False, (255, 200, 80)),
    (bgpic('b_star'), 1.8, (0.5, 0.62), (1.1, 1.5), '陨星坠击', '星核引来天外之火', False, (255, 200, 80)),
    (bgpic('b_boss'), 1.9, (0.5, 0.6), (1.0, 1.3), '首领激光', '看准红线，氮气躲开', False, (255, 120, 140)),
    (bgpic('b_swarm'), 1.9, (0.5, 0.62), (1.05, 1.4), '5 种新敌人 · 元素反应', '碎冰、爆燃、麻痹、湮灭', False, (255, 200, 80)),
    (bgpic('ui_work'), 1.9, (0.5, 0.5), (1.0, 1.1), '1080 张技能卡牌', '白 / 蓝 / 紫 / 金，自由搭配进化', False, (255, 200, 80)),
    (bgpic('ui_home'), 1.9, (0.7, 0.55), (1.0, 1.15), '危险等级 · 无尽模式', '挑战自己的极限', False, (255, 200, 80)),
    (bgpic('ui_summon'), 1.9, (0.5, 0.5), (1.0, 1.1), '召唤 SSSR 机甲', '稀有机甲等你唤醒', False, (255, 93, 122)),
    (bgpic('ui_daily'), 1.9, (0.4, 0.5), (1.0, 1.1), '每日挑战 · 7 日登录', '每天都有新规则', False, (255, 200, 80)),
    (starfield('outro', 9), 3.6, (0.5, 0.5), (1.0, 1.06), '宇宙银河机甲', 'TapTap 测试招募中 · 体素 Q 版 · 肉鸽割草', True, (255, 200, 80)),
]

def main():
    inputs, filt, caps = [], [], []
    for i, (img, dur, (fx, fy), (z0, z1), t1, t2, big, col) in enumerate(CLIPS):
        cap = caption('c%d' % i, t1, t2, big, col); frames = int(round(dur * FPS))
        inputs += ['-i', img]; caps.append(cap)
        zexp = "%0.4f+(%0.4f-%0.4f)*on/%d" % (z0, z1, z0, max(1, frames - 1))
        filt.append("[%d:v]scale=%d:-2,zoompan=z='%s':x='iw*%0.3f-iw/zoom/2':y='ih*%0.3f-ih/zoom/2':d=%d:s=%dx%d:fps=%d,format=yuva420p[b%d]" % (i, W * 3 // 2, zexp, fx, fy, frames, W, H, FPS, i))
    n = len(CLIPS)
    for i in range(n): inputs += ['-i', caps[i]]
    for i in range(n): filt.append("[b%d][%d:v]overlay=0:0:format=auto,format=yuv420p,setsar=1[v%d]" % (i, n + i, i))
    cur, t = 'v0', CLIPS[0][1]
    for i in range(1, n):
        off = t - XF; filt.append("[%s][v%d]xfade=transition=fade:duration=%0.2f:offset=%0.3f[x%d]" % (cur, i, XF, off, i)); cur = 'x%d' % i; t = off + CLIPS[i][1]
    total = t
    audio = os.path.join(ROOT, 'assets', 'audio', 'bgm_battle.ogg')
    cmd = ['ffmpeg', '-y', '-loglevel', 'error'] + inputs + ['-stream_loop', '-1', '-i', audio, '-filter_complex', ';'.join(filt), '-map', '[%s]' % cur, '-map', '%d:a' % (2 * n),
           '-t', '%0.2f' % total, '-af', 'volume=0.9,afade=t=in:d=0.8,afade=t=out:st=%0.2f:d=2' % (total - 2), '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', '-pix_fmt', 'yuv420p', '-r', str(FPS),
           '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart', OUT]
    subprocess.run(cmd, check=True); print(OUT, 'duration %.1fs' % total)

if __name__ == '__main__':
    main()
