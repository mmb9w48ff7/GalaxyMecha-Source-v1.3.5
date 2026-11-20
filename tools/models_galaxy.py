# -*- coding: utf-8 -*-
"""陨星银河 新增资产：两位新伙伴、玩家战斗机、海贼旗舰、跃迁星门、海贼要塞、富矿小行星、漂浮货舱、武器特效"""
import math, random
from voxlib import VoxModel
from models_chars import base_palette, chibi, CHAR_SCALE
from models_world import vnoise, patch_paint, asteroid


def make_yeyuan():
    m = VoxModel('char_yeyuan', '夜鸢 · 领航员', 'crew', CHAR_SCALE,
                 '前星海贼团的领航员，叛逃后加入舰队。雷达范围扩大 50%，跃迁后护盾立即充满。')
    base_palette(m, skin='#F1CDB8', skin_sh='#D9AE98')
    m.mat('suit', '#2C2440', rough=0.6)
    m.mat('suit2', '#1C1730', rough=0.6)
    m.mat('trim', '#B47CFF', rough=0.3, emit=0.8)
    m.mat('boots', '#1C1730', rough=0.5)
    m.mat('belt', '#B47CFF', rough=0.4)
    m.mat('hair', '#3B2A5C', rough=0.6)
    m.mat('hair_sh', '#241A3A', rough=0.6)
    m.mat('scarf', '#E0458C', rough=0.7)
    chibi(m, 'suit', 'suit2', 'boots', 'belt', 'hair', 'hair_sh', iris='#B47CFF', glove='suit2')
    # 齐肩短发
    m.boxm(4, 11, -4, 4, 13, 3, 'hair')
    m.boxm(0, 11, -4, 3, 11, -4, 'hair_sh')
    # 单片目镜
    m.mat('lens', '#5CF2DC', rough=0.05, emit=1.4)
    m.box(1, 13, 5, 2, 14, 5, 'lens')
    m.box(3, 14, 5, 4, 14, 5, 'trim')
    # 长围巾
    m.boxm(0, 10, -2, 2, 10, 2, 'scarf')
    m.box(1, 5, -3, 2, 10, -3, 'scarf')
    m.box(2, 3, -4, 2, 6, -4, 'scarf')
    # 发光线条
    m.boxm(2, 5, 2, 2, 9, 2, 'trim')
    # 星图板
    m.mat('pad', '#2E9FA6', rough=0.2, emit=0.9)
    m.box(-6, 6, 1, -5, 9, 4, 'suit2')
    m.box(-6, 7, 2, -6, 8, 3, 'pad')
    return m


def make_shuangling():
    m = VoxModel('char_shuangling', '霜铃 · 导弹手', 'crew', CHAR_SCALE,
                 '冰原星出身的爆破专家。导弹携带量 +2，导弹伤害 +40%。')
    base_palette(m)
    m.mat('suit', '#E8F2FA', rough=0.5)
    m.mat('suit2', '#9CC3DE', rough=0.5)
    m.mat('trim', '#57B8FF', rough=0.3, emit=0.7)
    m.mat('boots', '#3E6E99', rough=0.5)
    m.mat('belt', '#3E6E99', rough=0.5)
    m.mat('hair', '#BFE6FF', rough=0.5)
    m.mat('hair_sh', '#7FB9E0', rough=0.5)
    chibi(m, 'suit', 'suit2', 'boots', 'belt', 'hair', 'hair_sh', iris='#57B8FF', glove='boots')
    # 双丸子头
    m.boxm(3, 19, -1, 5, 21, 1, 'hair')
    m.boxm(4, 21, 0, 4, 21, 0, 'trim')
    # 背后导弹仓
    m.mat('pod', '#3E6E99', metal=0.6, rough=0.35)
    m.mat('tip', '#FF7A3A', rough=0.3, emit=1.2)
    m.boxm(0, 6, -4, 3, 11, -2, 'pod')
    for x in (0, 2):
        m.box(x, 12, -3, x, 12, -3, 'tip'); m.box(-1 - x, 12, -3, -1 - x, 12, -3, 'tip')
    m.boxm(1, 6, 2, 1, 9, 2, 'trim')
    m.box(0, 7, 2, -1, 7, 2, 'trim')
    # 遥控器
    m.box(-5, 5, 1, -5, 6, 2, 'pod'); m.put(-5, 7, 2, 'tip')
    return m


def make_redhawk():
    m = VoxModel('ship_redhawk', '赤隼号', 'ship', 0.2,
                 '舰队工坊出品的中型战斗机。双联装机炮，机动性与护盾兼顾，是对抗海贼的主力。')
    m.mat('hull', '#E8E3D6', metal=0.3, rough=0.35)
    m.mat('red', '#D6332A', metal=0.3, rough=0.4)
    m.mat('red_d', '#8E1F18', metal=0.3, rough=0.45)
    m.mat('dark', '#2B2F3A', metal=0.5, rough=0.4)
    m.mat('metal', '#9AA3B5', metal=0.9, rough=0.25)
    m.mat('glass', '#FFB36B', rough=0.05, emit=0.6)
    m.mat('glow', '#FF8A3A', rough=0.2, emit=2.6)
    m.mat('light', '#FFE7A3', rough=0.2, emit=1.8)
    # 机身
    for z in range(-10, 14):
        hw = 3 if z < 6 else max(1, 3 - (z - 5) // 3)
        top = 6 if z < 8 else max(3, 6 - (z - 7) // 2)
        m.box(0, 2, z, hw - 1, top, z, 'hull')
    m.paint(lambda x, y, z, k: y <= 2, 'dark')
    m.paint(lambda x, y, z, k: k == 'hull' and x == 2 and 4 <= y <= 5, 'red')
    # 座舱
    m.box(0, 7, 2, 1, 7, 7, 'glass')
    m.box(0, 6, 8, 0, 6, 9, 'glass')
    # 三角翼
    for z in range(-9, 4):
        span = 3 + int((4 - z) * 0.75)
        m.box(3, 3, z, span, 3, z, 'red')
        m.put(span, 4, z, 'red_d')
    m.box(3, 3, -10, 12, 3, -10, 'red_d')
    # 翼端机炮
    m.box(9, 4, -2, 9, 4, 8, 'metal')
    m.box(9, 4, 9, 9, 4, 9, 'light')
    # 双引擎
    m.cyl('z', 1.5, 4, 1.8, -13, -11, 'dark')
    m.cyl('z', 1.5, 4, 1.2, -14, -14, 'glow')
    # 垂尾
    for i in range(5):
        m.box(3, 5 + i, -10 + i, 3, 5 + i, -8 + i, 'red')
    m.mirror()
    return m


def make_pirate_flagship():
    m = VoxModel('ship_pirate_flagship', '赤髑号', 'ship', 0.3,
                 '星海贼团首领赤髑的旗舰。舰首是巨大的骷髅撞角，舰体上的晶体炮台吸收了陨石碎片的力量。')
    m.mat('black', '#1F1A22', metal=0.5, rough=0.4)
    m.mat('plate', '#3A3340', metal=0.6, rough=0.4)
    m.mat('red', '#B8323F', metal=0.3, rough=0.45)
    m.mat('red_d', '#7A1E2A', metal=0.3, rough=0.5)
    m.mat('bone', '#E8E1D0', rough=0.6)
    m.mat('eye', '#FF4D6A', rough=0.1, emit=2.6)
    m.mat('crys', '#E0458C', rough=0.05, emit=2.2)
    m.mat('glow', '#FF7A5A', rough=0.2, emit=2.6)
    m.mat('metal', '#7A8296', metal=0.85, rough=0.3)
    # 主舰体
    for z in range(-26, 18):
        hw = 9 if z < 8 else 9 - (z - 7)
        if hw < 1:
            continue
        top = 10 if z < 10 else max(4, 10 - (z - 9))
        m.box(0, 0, z, hw - 1, top, z, 'plate')
    m.paint(lambda x, y, z, k: y <= 1, 'black')
    m.paint(lambda x, y, z, k: x == 8 and 3 <= y <= 6, 'red_d')
    # 骷髅撞角
    m.box(0, 2, 18, 3, 9, 22, 'bone')
    m.box(1, 6, 23, 2, 7, 23, 'eye')
    m.box(0, 2, 23, 3, 3, 23, 'bone')
    m.box(0, 4, 23, 0, 5, 23, 'black')
    m.carve(1, 4, 23, 1, 4, 23)
    # 舰桥
    m.box(0, 11, -18, 4, 16, -8, 'black')
    m.box(0, 14, -7, 3, 15, -7, 'eye')
    m.box(0, 17, -16, 1, 22, -15, 'metal')
    m.box(0, 23, -16, 0, 23, -15, 'eye')
    # 侧舷炮台（晶体）
    for tz in (-20, -6, 6):
        m.box(9, 4, tz, 11, 8, tz + 3, 'red')
        m.box(12, 6, tz + 1, 12, 6, tz + 2, 'crys')
    # 顶部晶体炮
    m.box(0, 11, 0, 2, 13, 4, 'red')
    m.box(0, 14, 1, 0, 17, 2, 'crys')
    # 骨刺
    for z in range(-24, 6, 6):
        m.box(0, 11, z, 0, 13 + (z % 4), z, 'bone')
    # 引擎
    for cx, cy in ((3.5, 3.5), (3.5, 8.0), (7.0, 5.5)):
        m.cyl('z', cx, cy, 2.0, -29, -27, 'metal')
        m.cyl('z', cx, cy, 1.4, -30, -30, 'glow')
    m.mirror()
    m.dither('plate', 'black', 0.06, seed=9)
    return m


def make_jumpgate():
    m = VoxModel('space_jumpgate', '跃迁星门', 'space', 0.5,
                 '连接星系的古代星门，由陨石碎片供能。飞入门环即可跃迁到相邻星系。', pivot='center')
    m.mat('frame', '#5A6175', metal=0.8, rough=0.35)
    m.mat('frame_d', '#3A3F4F', metal=0.8, rough=0.4)
    m.mat('amber', '#F5A524', rough=0.4)
    m.mat('ring', '#5CF2DC', rough=0.1, emit=2.4)
    m.mat('core', '#9DF7EC', rough=0.1, emit=1.2)
    R = 18
    for a in range(0, 360, 1):
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        for r in (R - 1, R, R + 1, R + 2):
            x = int(math.floor(ca * r)); y = int(math.floor(sa * r))
            for z in (-1, 0):
                m.put(x, y, z, 'frame' if r > R - 1 else 'ring')
    # 分段装甲块
    for a in range(0, 360, 45):
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        cx, cy = ca * (R + 1), sa * (R + 1)
        m.box(int(cx) - 2, int(cy) - 2, -3, int(cx) + 1, int(cy) + 1, 2, 'frame_d')
        m.box(int(cx) - 1, int(cy) - 1, 3, int(cx), int(cy), 3, 'amber')
    # 底座支架
    m.box(-3, -R - 8, -3, 2, -R - 2, 2, 'frame_d')
    m.box(-8, -R - 10, -6, 7, -R - 9, 5, 'frame')
    m.box(-1, -R - 6, 3, 0, -R - 4, 3, 'ring')
    return m


def make_pirate_base():
    m = asteroid('space_pirate_base', '海贼要塞 · 赤髑巢', '星海贼团的老巢。小行星上搭满了炮台与船坞，红色信标在很远处就能看见。', 77, 16, 11, 15)
    m.mat('plate', '#3A3340', metal=0.6, rough=0.4)
    m.mat('red', '#B8323F', metal=0.3, rough=0.45)
    m.mat('eye', '#FF4D6A', rough=0.1, emit=2.4)
    m.mat('metal', '#7A8296', metal=0.85, rough=0.3)
    m.mat('win', '#FFB36B', rough=0.2, emit=1.4)
    # 顶部建筑群
    tops = {}
    for (x, y, z) in m.v:
        if y > tops.get((x, z), -99):
            tops[(x, z)] = y
    def top(x, z):
        return tops.get((x, z), 0)
    for bx, bz, w, d, h, k in ((-6, -4, 6, 5, 7, 'plate'), (2, -2, 4, 7, 10, 'red'), (-3, 5, 5, 4, 5, 'plate'), (7, 4, 3, 3, 6, 'plate')):
        base = max(top(x, z) for x in range(bx, bx + w) for z in range(bz, bz + d)) - 1
        m.box(bx, base, bz, bx + w - 1, base + h, bz + d - 1, k)
        for yy in range(base + 2, base + h, 2):
            m.put(bx + w // 2, yy, bz + d, 'win')
        m.box(bx + w // 2, base + h + 1, bz + d // 2, bx + w // 2, base + h + 4, bz + d // 2, 'metal')
        m.put(bx + w // 2, base + h + 5, bz + d // 2, 'eye')
    # 船坞臂
    m.box(14, -1, -2, 24, 0, 1, 'metal')
    m.box(22, -3, -4, 24, 2, 3, 'red')
    m.box(-25, -1, -2, -14, 0, 1, 'metal')
    m.box(-25, -3, -4, -23, 2, 3, 'red')
    m.put(24, 3, 0, 'eye'); m.put(-25, 3, 0, 'eye')
    return m


def make_ore_asteroid():
    m = asteroid('space_ore_asteroid', '富矿小行星', '含金属矿脉的小行星。用武器击碎后会掉落矿石货舱。', 101, 6, 5, 6)
    m.mat('ore', '#F2B33D', metal=0.8, rough=0.35, emit=0.35)
    m.mat('ore2', '#C9822A', metal=0.8, rough=0.4)
    rnd = random.Random(5)
    for p in list(m.v.keys()):
        if m.is_surface(p):
            n = vnoise(p[0] * 0.5, p[1] * 0.5, p[2] * 0.5, 13)
            if n > 0.66:
                m.v[p] = 'ore'
            elif n > 0.6:
                m.v[p] = 'ore2'
    return m


def make_loot_pod():
    m = VoxModel('prop_loot_pod', '漂浮货舱', 'item', 0.1,
                 '被击毁的飞船或矿石留下的货舱。靠近后自动吸入货舱，可能装着货物、信用点或陨石碎片。', pivot='center')
    m.mat('shell', '#9AA3B5', metal=0.8, rough=0.3)
    m.mat('band', '#F5A524', rough=0.4)
    m.mat('dark', '#2B2F3A', metal=0.5, rough=0.4)
    m.mat('light', '#5CF2DC', rough=0.1, emit=2.4)
    m.cyl('z', 0, 0, 3.2, -5, 4, 'shell')
    m.cyl('z', 0, 0, 3.3, -1, 0, 'band')
    m.cyl('z', 0, 0, 2.2, -6, -6, 'dark'); m.cyl('z', 0, 0, 2.2, 5, 5, 'dark')
    m.box(-1, 3, -3, 0, 3, -2, 'light'); m.box(-1, -4, 1, 0, -4, 2, 'light')
    return m


def fx(mid, name, sx, sy, sz, color, emit, scale=0.1):
    m = VoxModel(mid, name, 'fx', scale, '战斗特效。', pivot='center')
    m.mat('c', color, rough=0.2, emit=emit)
    m.box(-(sx // 2), -(sy // 2), -(sz // 2), sx - sx // 2 - 1, sy - sy // 2 - 1, sz - sz // 2 - 1, 'c')
    return m


def make_missile():
    m = VoxModel('fx_missile', '导弹', 'fx', 0.1, '追踪导弹。', pivot='center')
    m.mat('body', '#E8E3D6', metal=0.5, rough=0.3)
    m.mat('tip', '#D6332A', rough=0.4)
    m.mat('fin', '#3E6E99', rough=0.4)
    m.mat('flame', '#FFB347', rough=0.2, emit=3.0)
    m.box(-1, -1, -5, 0, 0, 4, 'body')
    m.box(-1, -1, 5, 0, 0, 6, 'tip')
    m.box(-2, -1, -5, 1, 0, -4, 'fin'); m.box(-1, -2, -5, 0, 1, -4, 'fin')
    m.box(-1, -1, -7, 0, 0, -6, 'flame')
    return m


def all_galaxy():
    return [make_yeyuan(), make_shuangling(), make_redhawk(), make_pirate_flagship(),
            make_jumpgate(), make_pirate_base(), make_ore_asteroid(), make_loot_pod(),
            fx('fx_laser_player', '玩家激光', 1, 1, 14, '#5CF2DC', 3.0),
            fx('fx_laser_enemy', '海贼激光', 1, 1, 12, '#FF4D6A', 3.0),
            make_missile(),
            fx('fx_spark', '火花', 1, 1, 1, '#FFB347', 3.5),
            fx('fx_spark_teal', '晶体火花', 1, 1, 1, '#5CF2DC', 3.5),
            fx('fx_debris', '碎片', 1, 1, 1, '#4A4F5E', 0.0),
            fx('fx_shield', '护盾闪光', 1, 1, 1, '#57B8FF', 2.0),
            fx('fx_white', '染色光球', 1, 1, 1, '#FFFFFF', 1.6),
            fx('fx_white_bolt', '染色光弹', 1, 1, 10, '#FFFFFF', 1.6)]

