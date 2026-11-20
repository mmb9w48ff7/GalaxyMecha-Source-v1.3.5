# -*- coding: utf-8 -*-
"""宇宙银河机甲 · 6 台原创体素机甲（v0.9.3 造型重做）
单体素 0.06 米，身高约 4 米，面朝 +Z。参考写实系人形机甲的比例与分件逻辑（小头、宽肩、窄腰、
裙甲、长腿大脚、背包推进器），但所有头部、胸口、盾牌、武器均为原创造型：
不使用 V 形额角、面罩竖纹口部、红黄三色胸口进气格栅、红十字盾等任何既有作品的标志性元素。
造型工具见 mechkit.py。"""
import math
from voxlib import VoxModel
from mechkit import Mech, base, visor, core, head_base, shade

RIGHT = -1   # 右手（武器手）在镜像后的 -x 侧
# Q 版比例（头放大倍数, 腿压缩倍数）：保持原版造型，6 台统一
CHIBI = {k: (1.60, 0.75) for k in ('mech_azure', 'mech_blaze', 'mech_halo', 'mech_forge', 'mech_frost', 'mech_starfall')}
def dsh(mid):
    """Q 版后身体整体下移的格数（手持长柄武器的下端必须高于它，否则会插进地面）"""
    return int(round(36 * (1 - CHIBI[mid][1])))



def rx(x):
    """把右半边坐标 x 映射到右手侧（-1-x）"""
    return -1 - x


def glow_mats(m, eye, core_c, thr, acc, eye_e=1.6, core_e=1.8):
    m.mat('a', acc, rough=0.3, emit=0.7)
    m.mat('e', eye, rough=0.1, emit=eye_e)
    m.mat('g', thr, rough=0.2, emit=2.2)
    m.mat('core', core_c, rough=0.05, emit=core_e)


# ================================================================ 苍星
def make_azure():
    m = Mech('mech_azure', '苍星',
             '均衡型主力机。白青分色的标准骨架，手持长管星轨射线枪，左臂装有脉冲护臂，脑后圆环雷达负责锁定，胸口的陨石晶核为全身供能。专属驾驶员：星璃。')
    m.tone('w', '#E9EDF3'); m.tone('s', '#1F7F9E', 0.4, 0.4); m.tone('f', '#353A4A', 0.7, 0.45)     # 白 + 深青分色（避开常见“白蓝红黄”经典机甲配色）
    glow_mats(m, '#7DFBEA', '#5CF2DC', '#9DF7EC', '#5CF2DC')
    P = dict(W='w', S='s', F='f', A='a', E='e', G='g')
    base(m, P); visor(m, P)
    # 头部：圆润低脊 + 两侧圆形传感舱 + 脑后圆环雷达（不使用头顶刃冠 / V 形天线，轮廓与经典机甲明显不同）
    m.part = 'head'
    m.cbox(0, 0, 63, 64, -3, 2, 'w'); m.cbox(0, 1, 62, 62, -4, 3, 's'); m.cbox(0, 0, 64, 64, 3, 3, 'a')
    m.cbox(4, 6, 58, 61, -2, 2, 's', c=1); m.cbox(5, 5, 60, 61, 3, 3, 'a')      # 侧传感舱
    import math
    prev = None
    for deg in range(-90, 91, 6):                                              # 脑后雷达环（半圆，镜像后成整圆；相邻点之间补点，保证面相连）
        x = int(round(5.5 * math.cos(math.radians(deg)))); y = 61 + int(round(5.5 * math.sin(math.radians(deg))))
        m.box(x, y, -6, x, y, -5, 's' if deg % 24 else 'a')
        if prev and prev[0] != x and prev[1] != y: m.box(x, prev[1], -6, x, prev[1], -5, 's')
        prev = (x, y)
    m.cbox(0, 1, 57, 66, -5, -4, 'f', c=0)                                     # 脊板：把雷达环牢牢接在头后
    m.part = 'body'
    m.mirror()
    core(m, 'core')
    m.rig['muzzleR'] = [(-13.0, 27.0, 21.0)]
    m.part = 'armR'
    # 光束步枪（右手）
    m.box(rx(13), 21, 0, rx(12), 25, 2, 'f')                               # 握把
    m.cbox(rx(14), rx(11), 25, 29, -6, 10, 's', c=1, edges='x', center=False)
    m.box(rx(14), 29, -2, rx(11), 29, 8, 'w')                              # 上导轨
    m.box(rx(13), 26, 11, rx(12), 27, 19, 'f')                             # 枪管
    m.box(rx(14), 25, 15, rx(11), 28, 16, 'w')                             # 枪口制退
    m.box(rx(13), 26, 20, rx(12), 27, 20, 'e')
    m.box(rx(13), 30, -1, rx(12), 31, 5, 'f'); m.box(rx(13), 30, 6, rx(12), 31, 6, 'a')   # 瞄准镜
    m.box(rx(13), 22, 5, rx(12), 24, 7, 'f')                               # 弹匣
    m.box(rx(14), 26, -9, rx(11), 28, -7, 'w')                             # 枪托
    # 左前臂脉冲护臂（取代盾牌）：外挂护甲 + 青色光刃发射槽 + 前指尖刺
    m.part = 'armL'
    m.cbox(15, 17, 24, 38, -4, 9, 'f', c=1, center=False)
    m.box(15, 25, -4, 17, 37, -4, 's'); m.box(15, 25, 9, 17, 37, 9, 's')
    m.box(16, 26, -3, 16, 36, 8, 'w')
    m.box(17, 27, 0, 17, 35, 7, 'e')                                         # 光刃发射槽（发光）
    m.box(15, 30, 10, 17, 31, 13, 'w'); m.box(16, 30, 14, 16, 30, 16, 'a')   # 前指尖刺
    m.part = 'body'
    m.chibi(*CHIBI[m.id])
    return m.finish({'w', 's'})


# ================================================================ 炎铠
def make_blaze():
    m = Mech('mech_blaze', '炎铠',
             '重装突击机。加厚的红色装甲与双层肩甲，右手热能战斧，左臂三管散射炮，背负大型散热鳍。专属驾驶员：赤焰。')
    m.tone('w', '#D6332A', 0.4, 0.4); m.tone('s', '#2B2F3A', 0.55, 0.45); m.tone('f', '#4A5064', 0.8, 0.35)
    m.tone('gd', '#E2A23A', 0.7, 0.3)
    glow_mats(m, '#FFB347', '#FF7A3A', '#FF8A3A', '#F5A524')
    m.mat('heat', '#FF6A2A', rough=0.1, emit=2.2)
    P = dict(W='w', S='s', F='f', A='a', E='e', G='g', thick=1, chestw=9, shx=10, shw=6, armx=11,
             knee='w', legS='s', chest='w', chestplate='w', sh='w', sh2='s', bst='s', bp='w', skirt='w')
    base(m, P)
    # 头：厚重头盔 + 斜切双眼 + 头顶鬃脊 + 后掠侧角
    hy = 57
    m.part = 'head'
    m.cbox(0, 3, hy + 2, hy + 3, 6, 6, 'e'); m.put(3, hy + 3, 5, 'e')
    m.cbox(0, 3, hy + 4, hy + 6, 5, 6, 'w'); m.recolor(0, 0, hy + 4, hy + 6, 6, 6, 'gd')
    m.cbox(0, 0, hy + 7, hy + 9, -3, 4, 'gd'); m.cbox(0, 0, hy + 10, hy + 10, -2, 2, 'gd')
    m.line([(4, hy + 5, 1), (6, hy + 7, -1), (7, hy + 9, -4)], 'gd', r=0)
    m.line([(4, hy + 4, 0), (6, hy + 6, -2), (7, hy + 8, -5)], 'gd', r=0)
    m.part = 'body'
    # 双层肩甲 + 肩顶防撞角
    m.cbox(10, 17, 54, 58, -6, 5, 'w', c=2)
    m.recolor(10, 17, 58, 58, -5, 4, 'w_lt')
    m.cbox(17, 18, 50, 56, -4, 3, 'gd')
    m.cbox(12, 14, 59, 61, -2, 0, 's')
    # 胸口：横向散热口（热光）
    for y in (49, 51): m.box(1, y, 9, 6, y, 9, 'heat')
    m.cbox(1, 7, 48, 52, 8, 8, 's')
    for y in (49, 51): m.box(1, y, 9, 6, y, 9, 'heat')
    # 背负散热鳍
    for i, y in enumerate((44, 47, 50, 53)):
        m.cbox(6, 12 + i, y, y + 1, -12, -7, 's')
        m.box(12 + i, y, -12, 12 + i, y + 1, -7, 'heat')
    m.mirror()
    m.rig['muzzleL'] = [(16.5, 28.0, 13.0), (18.5, 28.0, 13.0), (17.5, 32.0, 13.0)]
    m.rig['axeEdge'] = (-12.5, 42.0, 11.0)
    m.part = 'armR'
    # 右手热能战斧
    B = dsh('mech_blaze') + 1
    m.box(rx(13), B, 0, rx(12), 46, 1, 'f')
    m.box(rx(13), B, 0, rx(12), B + 1, 1, 'gd')
    def blade(y):
        d = abs(y - 42)
        if d > 6: return None
        return (rx(14), rx(11), 2, 10 - d // 2)
    for y in range(36, 49):
        r = blade(y)
        if r: m.box(r[0], y, r[2], r[1], y, r[3], 's')
        if r: m.box(r[0], y, r[3] + 1, r[1], y, r[3] + 1, 'heat')
    m.box(rx(14), 39, -4, rx(11), 44, -1, 's'); m.box(rx(13), 41, -6, rx(12), 42, -5, 'gd')
    # 左臂三管散射炮
    m.part = 'armL'
    m.cbox(15, 19, 25, 34, -4, 8, 's', c=1, center=False)
    m.box(15, 34, -3, 19, 34, 6, 'w')
    for (yy, xx) in ((27, 16), (27, 18), (31, 17)):
        m.box(xx, yy, 9, xx, yy + 1, 11, 'f'); m.box(xx, yy, 12, xx, yy + 1, 12, 'heat')
    m.part = 'body'
    m.chibi(*CHIBI[m.id])
    return m.finish({'w', 's'})


# ================================================================ 月辉
def make_halo():
    m = Mech('mech_halo', '月辉',
             '支援型机甲。修长的白紫机身与长裙甲，背后光环发生器投射治疗力场，手持新月法杖。专属驾驶员：月汐。')
    m.tone('w', '#F2F0F8', 0.3, 0.35); m.tone('s', '#7A5BC9', 0.35, 0.4); m.tone('f', '#454A5C', 0.7, 0.4)
    glow_mats(m, '#C9B8FF', '#7CF29A', '#C9B8FF', '#B8A3F5')
    m.mat('halo', '#B47CFF', rough=0.05, emit=1.8)
    m.mat('heal', '#7CF29A', rough=0.05, emit=1.8)
    P = dict(W='w', S='s', F='f', A='a', E='e', G='g', chestw=7, shx=8, shw=4, armx=9,
             knee='s', sh='w', sh2='s', bst='w', skirt='w', sskirt='s')
    base(m, P); visor(m, P)
    # 修长：裙甲加长（侧裙甲延伸成翼裙）
    def wing(y):
        off = (39 - y) // 3
        return (8 + off, 9 + off, -4, 2)
    m.slab(26, 39, wing, 's', c=1)
    m.recolor(8, 14, 26, 27, -5, 3, 'w')
    m.slab(27, 39, lambda y: (0, 6, -5 - (39 - y) // 3, -4 - (39 - y) // 3), 'w', c=1)
    # 圆肩：顶盖改成圆弧
    m.cyl('x', 53.5, 0, 4.5, 8, 13, 'w')
    m.cyl('x', 53.5, 0, 3.2, 14, 14, 's')
    # 头：后掠长冠（发辫状）
    m.part = 'head'
    m.cbox(0, 0, 63, 65, -3, 2, 'w')
    for dz in range(0, 2):
        m.line([(2, 63, -1 - dz), (3, 64, -4 - dz), (3, 63, -8 - dz), (2, 60, -10 - dz)], 's')
    m.cbox(0, 1, 62, 63, 4, 5, 'heal')
    m.part = 'body'
    m.mirror()
    core(m, 'heal')
    # 背后光环
    for a in range(0, 360, 3):
        for r in (11.0, 11.8):
            x = int(math.floor(math.cos(math.radians(a)) * r)); y = int(round(math.sin(math.radians(a)) * r)) + 57
            m.put(x, y, -13, 'halo')
    for a in range(0, 360, 45):
        x = int(math.floor(math.cos(math.radians(a)) * 9.5)); y = int(round(math.sin(math.radians(a)) * 9.5)) + 57
        m.put(x, y, -13, 'w')
    m.box(-1, 55, -12, 0, 59, -11, 'f')
    m.box(-11, 57, -13, 10, 57, -13, 'w'); m.box(-1, 46, -13, 0, 68, -13, 'w')                  # 光环辐条：环与背部发生器面相连
    for a in range(0, 360, 90): pass
    m.rig['muzzleR'] = [(-12.0, 56.0, 1.0)]
    m.part = 'armR'
    # 右手新月法杖
    B = dsh('mech_halo') + 1
    m.box(rx(12), B, 0, rx(11), 52, 1, 'w')
    m.box(rx(12), B, 0, rx(11), B + 1, 1, 's')
    for a in range(200, 341, 10):
        z = int(round(math.cos(math.radians(a)) * 4)) + 1; y = int(round(math.sin(math.radians(a)) * -4)) + 56
        m.box(rx(12), y, z, rx(11), y, z, 's')
    m.box(rx(12), 53, 0, rx(11), 56, 1, 'heal')
    m.box(rx(13), 54, 0, rx(10), 55, 1, 'heal')
    m.part = 'body'
    m.chibi(*CHIBI[m.id])
    return m.finish({'w', 's'})


# ================================================================ 琥珀工兵
def make_forge():
    m = Mech('mech_forge', '琥珀工兵',
             '工程作业机改装的战斗机甲。敦实的黄色机身涂着警示条纹，双臂换装旋转机炮，背负起重臂可随时投放炮台。专属驾驶员：琥珀。')
    m.tone('w', '#F2C230', 0.35, 0.5); m.tone('s', '#3B3F4A', 0.5, 0.5); m.tone('f', '#5A6070', 0.7, 0.45)
    m.tone('mt', '#9AA3B5', 0.9, 0.3)
    glow_mats(m, '#FF9A3C', '#FFB347', '#FFB347', '#F08A2C', eye_e=1.9)
    P = dict(W='w', S='s', F='f', A='a', E='e', G='g', thick=1, chestw=9, shx=10, shw=6, armx=11,
             knee='s', legS='s', sh='w', sh2='s', bst='s', bp='w', skirt='w', nohead=True, noforearm=True)
    base(m, P)
    # 头：低矮半球头盔 + 三目横向传感条
    hy = 56
    m.rig['neck'] = (0.0, 56.0, 0.5)
    m.part = 'head'
    m.ell(0, hy + 3.5, 0.5, 4.6, 4.2, 4.8, 'w')
    m.carve(-6, hy - 2, -6, 6, hy - 1, 7)
    m.cbox(0, 3, hy, hy + 2, -3, 4, 's')
    m.cbox(0, 4, hy + 2, hy + 3, 4, 5, 's')
    for x in (0, 2): m.put(x, hy + 3, 6, 'e'); m.put(x, hy + 2, 6, 'e')
    m.recolor(0, 4, hy + 6, hy + 7, -4, 5, 'w_lt', only={'w'})
    m.cbox(4, 4, hy + 6, hy + 10, -1, -1, 'mt'); m.put(4, hy + 11, -1, 'e')   # 天线
    m.part = 'body'
    # 警示条纹（肩顶、胸口）
    m.paint(lambda x, y, z, k: k == 'w' and y >= 51 and x >= 10 and (y + z) % 4 < 2, 's')
    m.cbox(1, 6, 50, 52, 8, 8, 's')
    m.paint(lambda x, y, z, k: k == 's' and y in (50, 51, 52) and z == 8 and (x + y) % 4 < 2, 'w')
    # 双臂旋转机炮（取代前臂）
    m.part = 'arm'
    cx, cy = 13, 31.5
    m.cyl('z', cx, cy, 3.6, -5, 6, 's')
    m.cyl('z', cx, cy, 3.6, -5, -4, 'w')
    m.cyl('z', cx, cy, 3.9, 2, 3, 'w')
    for a in range(0, 360, 60):
        bx = cx + math.cos(math.radians(a)) * 1.9; by = cy + math.sin(math.radians(a)) * 1.9
        m.cyl('z', bx, by, 0.7, 7, 14, 'mt')
    m.cyl('z', cx, cy, 2.8, 12, 12, 'mt')
    m.cyl('z', cx, cy, 0.8, 7, 15, 'f')
    m.box(12, 33, 15, 13, 34, 15, 'e')
    m.box(10, 25, -3, 15, 27, 2, 's')                                       # 弹链箱
    m.part = 'body'
    m.mirror()
    m.rig['muzzleL'] = [(13.0, 31.5, 16.0)]; m.rig['muzzleR'] = [(-13.0, 31.5, 16.0)]
    m.rig['craneL'] = (5.5, 64.0, 2.5)
    # 起重臂（背部左侧）与吊钩
    m.cbox(4, 6, 50, 56, -12, -9, 'f')
    m.line([(5, 56, -11), (5, 70, -8)], 'mt', r=1)
    m.line([(5, 70, -8), (5, 69, 2)], 'mt', r=1)
    m.box(5, 61, -10, 5, 66, -10, 'a')
    m.box(5, 62, 2, 5, 68, 2, 'f'); m.box(4, 60, 1, 6, 61, 3, 'w')
    m.put(5, 71, -8, 'e')
    m.chibi(*CHIBI[m.id])
    return m.finish({'w', 's'})


# ================================================================ 霜鸣
def make_frost():
    m = Mech('mech_frost', '霜鸣',
             '远程炮击机。双肩大型导弹舱、背负长管轨道炮，长耳状传感器能锁定成群目标，右手榴弹发射器。专属驾驶员：霜铃。')
    m.tone('w', '#EAF4FB', 0.35, 0.35); m.tone('s', '#3E8FD6', 0.4, 0.4); m.tone('f', '#3A3F4F', 0.7, 0.45)
    m.tone('pod', '#2B4A6B', 0.5, 0.4)
    glow_mats(m, '#7CCBFF', '#57B8FF', '#9DD8FF', '#57B8FF')
    m.mat('tip', '#FF7A3A', rough=0.3, emit=1.2)
    P = dict(W='w', S='s', F='f', A='a', E='e', G='g', knee='s', sh='pod', sh2='s')
    base(m, P); visor(m, P)
    # 双肩导弹舱（取代肩顶盖）
    m.cbox(9, 17, 54, 61, -6, 5, 'pod', c=1)
    m.recolor(9, 17, 61, 61, -5, 4, 'pod_lt')
    m.cbox(10, 16, 55, 60, 6, 6, 'f')
    for x in (11, 13, 15):
        for y in (56, 59):
            m.put(x, y, 6, 'tip')
    m.box(9, 57, -6, 9, 58, 5, 's')
    # 长耳传感器
    m.part = 'head'
    for dz in (0, 1):
        m.line([(3, 62, 0 - dz), (4, 67, -2 - dz), (4, 71, -5 - dz)], 'w')
    m.line([(4, 66, -2), (4, 70, -5)], 's')
    m.put(4, 71, -6, 'a')
    m.part = 'body'
    m.mirror()
    # 背负长管轨道炮（越过右肩）
    m.cbox(-10, -6, 58, 62, -14, -4, 'pod', center=False)
    m.cyl('z', -8, 60, 1.6, -3, 20, 'w')
    m.cyl('z', -8, 60, 2.4, 6, 9, 's')
    m.cyl('z', -8, 60, 2.4, 17, 19, 's')
    m.cyl('z', -8, 60, 0.9, 20, 21, 'a')
    m.box(-9, 57, -9, -8, 58, -6, 'f')
    # 右手榴弹发射器
    m.rig['muzzleP'] = [(13.5, 57.5, 7.0), (-13.5, 57.5, 7.0)]
    m.rig['muzzleR'] = [(-12.0, 26.5, 15.0)]
    m.rig['rail'] = (-8.0, 60.0, 22.0)
    m.part = 'armR'
    m.cbox(rx(14), rx(11), 24, 29, -4, 9, 's', c=1, edges='x', center=False)
    m.cyl('z', -12, 26.5, 1.6, 10, 13, 'w')
    m.cyl('z', -12, 26.5, 0.8, 14, 14, 'tip')
    m.box(rx(13), 21, 1, rx(12), 24, 2, 'f')
    m.part = 'body'
    m.chibi(*CHIBI[m.id])
    return m.finish({'w', 's', 'pod'})


# ================================================================ 天殒
def make_starfall():
    m = Mech('mech_starfall', '天殒',
             'SSR 星核机甲。深空蓝与金色镶边的骑士式机身，背后四片晶翼展开时能召唤陨星坠击，手持星核长枪。专属驾驶员：夜鸢。')
    m.tone('w', '#262C4E', 0.6, 0.3); m.tone('s', '#C9A24A', 0.9, 0.25); m.tone('f', '#3A3F5A', 0.7, 0.35)
    glow_mats(m, '#FF5FA2', '#5CF2DC', '#E0A0FF', '#B47CFF', eye_e=1.8)
    m.mat('crys', '#B47CFF', rough=0.05, emit=1.6)
    m.mat('crys2', '#5CF2DC', rough=0.05, emit=1.4)
    P = dict(W='w', S='s', F='f', A='a', E='e', G='g', knee='s', legS='w', shinplate='a', chest='w', chestplate='w',
             sh='w', sh2='s', bst='w', bp='w', skirt='w', skirtmark='s', crotch='w', chin='s', shw=6)
    base(m, P)
    # 头：尖顶骑士盔 + 窄缝双眼 + 星冠
    hy = 57
    m.part = 'head'
    m.cbox(0, 3, hy + 3, hy + 3, 6, 6, 'e'); m.put(3, hy + 3, 5, 'e')
    m.cbox(0, 3, hy + 4, hy + 6, 5, 6, 'w'); m.recolor(0, 3, hy + 4, hy + 4, 6, 6, 's')
    m.cbox(0, 0, hy + 7, hy + 12, -1, 2, 's'); m.cbox(0, 0, hy + 12, hy + 13, 0, 1, 'crys')
    m.line([(2, hy + 7, 1), (4, hy + 10, 0)], 's'); m.put(4, hy + 11, 0, 'crys2')
    m.line([(4, hy + 5, 0), (6, hy + 8, -2)], 's')
    m.part = 'body'
    # 金色镶边
    m.paint(lambda x, y, z, k: k == 'w' and y in (44, 55) and z >= 4, 's')
    m.paint(lambda x, y, z, k: k == 'w' and 51 <= y <= 56 and x >= 9 and (x == 9 or y == 51), 's')
    # 腿部发光线
    m.paint(lambda x, y, z, k: k == 'w' and y in (14, 15) and x == 10, 'a')
    # 披风式后裙甲
    m.slab(16, 39, lambda y: (0, 7 - (39 - y) // 8, -6 - (39 - y) // 5, -5 - (39 - y) // 5), 'w', c=1)
    m.slab(16, 17, lambda y: (0, 4, -10, -9), 's')
    # 四片晶翼
    for i, (ang, ln, k) in enumerate(((35, 15, 'crys'), (60, 13, 'crys2'), (12, 12, 'crys2'), (85, 10, 'crys'))):
        ax0, ay0 = 5, 52
        dx = math.cos(math.radians(ang)); dy = math.sin(math.radians(ang))
        for s in range(ln + 1):
            x = ax0 + dx * s; y = ay0 + dy * s
            w = 2 if s < ln - 3 else 1
            for t in range(-w, w + 1):
                px = int(round(x - dy * t * 0.7)); py = int(round(y + dx * t * 0.7))
                m.put(px, py, -12 - s // 5, k if t != 0 else 's')
    m.cbox(3, 6, 49, 55, -12, -9, 's')
    m.mirror()
    core(m, 'core', y0=48, y1=52)
    m.rig['muzzleR'] = [(-13.0, 63.0, 1.0)]
    m.rig['wingL'] = (5.0, 52.0, -12.0)
    m.part = 'armR'
    # 右手星核长枪
    B = dsh('mech_starfall') + 1
    m.box(rx(13), B, 0, rx(12), 54, 1, 's')
    m.box(rx(14), 50, -1, rx(11), 51, 2, 's')
    for y in range(52, 61):
        w = 2 if y < 56 else (1 if y < 59 else 0)
        m.box(rx(12) - w, y, 0, rx(13) + w, y, 1, 'crys2')
    m.box(rx(13), 61, 0, rx(12), 62, 1, 'core')
    m.part = 'body'
    m.chibi(*CHIBI[m.id])
    return m.finish({'w', 's'})


# ================================================================ 系统件（保持不变）
def make_grid():
    m = VoxModel('sys_grid', '战场网格', 'system', 0.25, '3D 视角下的地面参照网格（细线，每 10 米一格）。')
    m.mat('line', '#24476E', rough=0.6, emit=0.12)
    n = 960
    for i in range(0, n + 1, 40):
        m.box(i, 0, 0, i, 0, n, 'line'); m.box(0, 0, i, n, 0, i, 'line')
    return m


def make_shadow():
    m = VoxModel('sys_shadow', '脚下阴影', 'system', 0.1, '模拟接触阴影。', pivot='center')
    m.mat('dark', '#04050C', rough=1.0)
    m.cyl('y', 0, 0, 10, 0, 0, 'dark')
    return m


def all_mechs():
    return [make_azure(), make_blaze(), make_halo(), make_forge(), make_frost(), make_starfall(), make_grid(), make_shadow()]
