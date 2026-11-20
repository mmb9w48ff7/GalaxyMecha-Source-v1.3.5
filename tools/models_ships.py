# -*- coding: utf-8 -*-
"""飞船体素模型（单体素 0.2 米）。飞船就是公路旅行里的那辆车：运货、载人、被追。"""
from voxlib import VoxModel

SHIP_SCALE = 0.2


def stripes(m, cond, k1, k2, period=2):
    def f(x, y, z, old):
        return cond(x, y, z, old)
    for p, old in list(m.v.items()):
        x, y, z = p
        if cond(x, y, z, old):
            m.v[p] = k1 if ((z + y) // period) % 2 == 0 else k2


def make_stardust():
    m = VoxModel('ship_stardust', '星尘号', 'ship', SHIP_SCALE,
                 '初始货运艇。车头驾驶舱加背负式货柜，4 个座位，燃料 100。',)
    m.mat('hull', '#D9D2C0', metal=0.2, rough=0.45)
    m.mat('hull_d', '#B3AA94', metal=0.2, rough=0.5)
    m.mat('dark', '#2B2F3A', metal=0.4, rough=0.5)
    m.mat('amber', '#F5A524', rough=0.5)
    m.mat('amber_d', '#C47F12', rough=0.5)
    m.mat('metal', '#7A8296', metal=0.85, rough=0.35)
    m.mat('glass', '#6FD3F5', metal=0.1, rough=0.08, emit=0.45)
    m.mat('glow', '#5CF2DC', rough=0.2, emit=2.4)
    m.mat('light', '#FFE7A3', rough=0.2, emit=1.8)
    m.mat('tail', '#FF4D6A', rough=0.2, emit=1.4)
    # 主舱体
    m.box(0, 3, -10, 5, 9, 6, 'hull')
    # 驾驶舱（斜面车头）
    for z in range(7, 13):
        top = 9 - max(0, z - 8)
        xw = 5 if z <= 10 else 4
        m.box(0, 3, z, xw, top, z, 'hull')
    # 挡风玻璃沿斜面
    for z in range(9, 12):
        top = 9 - max(0, z - 8)
        m.box(0, top, z, 4, top, z, 'glass')
    m.box(5, 7, 6, 5, 8, 9, 'glass')
    # 车头保险杠与大灯
    m.box(0, 3, 13, 4, 5, 13, 'dark')
    m.box(3, 5, 13, 4, 5, 13, 'light')
    m.box(0, 3, 12, 4, 3, 13, 'dark')
    # 底部
    m.paint(lambda x, y, z, k: y == 3 and k == 'hull', 'hull_d')
    # 侧面警示条纹
    stripes(m, lambda x, y, z, k: x == 5 and y == 4 and -10 <= z <= 10, 'amber', 'dark', 2)
    # 侧门
    m.box(5, 5, -2, 5, 8, -2, 'hull_d'); m.box(5, 5, 1, 5, 8, 1, 'hull_d')
    m.box(5, 8, -1, 5, 8, 0, 'hull_d')
    # 背负货柜
    m.box(0, 10, -10, 4, 13, 3, 'amber')
    for z in (-10, -6, -2, 2):
        m.box(0, 10, z, 5, 13, z, 'amber_d')
    m.box(0, 13, -9, 3, 13, 1, 'amber_d')
    m.box(5, 10, -10, 5, 10, 3, 'dark')
    # 引擎吊舱
    m.box(6, 5, -9, 6, 7, -3, 'dark')
    m.cyl('z', 8.5, 6, 2.6, -12, -2, 'hull_d')
    m.cyl('z', 8.5, 6, 2.6, -2, -2, 'dark')
    m.cyl('z', 8.5, 6, 2.6, -8, -6, 'amber')
    m.cyl('z', 8.5, 6, 2.2, -13, -13, 'dark')
    m.cyl('z', 8.5, 6, 1.6, -14, -14, 'glow')
    # 尾部
    m.box(0, 3, -11, 5, 9, -11, 'dark')
    m.box(4, 8, -11, 5, 9, -11, 'tail')
    # 主推进器
    m.cyl('z', 0, 6, 2.2, -12, -12, 'metal')
    m.cyl('z', 0, 6, 1.5, -13, -13, 'glow')
    # 起落架
    m.box(4, 1, -7, 4, 2, -7, 'metal'); m.box(4, 1, 4, 4, 2, 4, 'metal')
    m.box(3, 0, -9, 5, 0, 6, 'dark')
    # 车顶灯
    m.box(3, 9, 7, 4, 9, 7, 'light')
    m.mirror()
    # 天线（不对称）
    m.box(2, 14, 0, 2, 16, 0, 'metal')
    m.put(2, 17, 0, 'tail')
    m.box(-4, 14, -8, -2, 14, -6, 'metal')
    m.dither('hull', 'hull_d', 0.05, seed=11)
    return m


def make_anvil():
    m = VoxModel('ship_anvil', '铁砧号', 'ship', SHIP_SCALE,
                 '重型货舰。双侧挂载集装箱，载货量是星尘号的 3 倍，速度慢、油耗高。')
    m.mat('hull', '#6C7A4F', metal=0.3, rough=0.55)
    m.mat('hull_d', '#4E5A38', metal=0.3, rough=0.6)
    m.mat('dark', '#2B2F3A', metal=0.4, rough=0.5)
    m.mat('metal', '#7A8296', metal=0.85, rough=0.35)
    m.mat('cont_o', '#E07A2E', rough=0.6)
    m.mat('cont_o2', '#B85A1A', rough=0.6)
    m.mat('cont_t', '#2F8F8A', rough=0.6)
    m.mat('cont_t2', '#1F6B67', rough=0.6)
    m.mat('glass', '#6FD3F5', rough=0.08, emit=0.45)
    m.mat('glow', '#FFB347', rough=0.2, emit=2.4)
    m.mat('light', '#FFE7A3', rough=0.2, emit=1.8)
    m.mat('amber', '#F5A524', rough=0.5)
    # 脊梁
    m.box(0, 6, -18, 2, 9, 12, 'hull_d')
    # 驾驶舱模块
    for z in range(10, 19):
        top = 11 - max(0, z - 14)
        m.box(0, 4, z, 5, top, z, 'hull')
    m.box(0, 8, 18, 4, 9, 18, 'glass')
    m.box(5, 9, 12, 5, 10, 16, 'glass')
    m.box(0, 4, 19, 4, 5, 19, 'dark')
    m.box(3, 6, 19, 4, 6, 19, 'light')
    # 集装箱（侧挂）
    m.box(3, 2, -15, 8, 7, -5, 'cont_o')
    for z in range(-15, -4, 2):
        m.box(8, 2, z, 8, 7, z, 'cont_o2')
    m.box(3, 2, -3, 8, 7, 7, 'cont_t')
    for z in range(-3, 8, 2):
        m.box(8, 2, z, 8, 7, z, 'cont_t2')
    m.box(3, 8, -15, 6, 8, 7, 'dark')
    # 散热片
    for z in range(-16, -5, 3):
        m.box(0, 10, z, 1, 14, z, 'metal')
    # 引擎块
    m.box(0, 3, -24, 6, 12, -19, 'hull')
    m.box(0, 3, -19, 6, 3, -19, 'amber')
    for cy in (5.5, 10.0):
        m.cyl('z', 3.5, cy, 2.2, -26, -25, 'dark')
        m.cyl('z', 3.5, cy, 1.6, -27, -27, 'glow')
    # 起落架
    m.box(5, 0, -20, 6, 2, -20, 'metal'); m.box(5, 0, 14, 6, 3, 14, 'metal')
    m.mirror()
    m.dither('hull', 'hull_d', 0.08, seed=21)
    return m


def make_firefly():
    m = VoxModel('ship_firefly', '流萤号', 'ship', SHIP_SCALE,
                 '高速快艇。只有 2 个座位，但油耗极低，能甩开大部分海贼追击。')
    m.mat('hull', '#EEF1F4', metal=0.3, rough=0.35)
    m.mat('lime', '#9BE15D', rough=0.4)
    m.mat('lime_d', '#5FA83A', rough=0.45)
    m.mat('dark', '#2B2F3A', metal=0.4, rough=0.45)
    m.mat('glass', '#6FD3F5', rough=0.05, emit=0.5)
    m.mat('glow', '#E8FF7A', rough=0.2, emit=2.6)
    m.mat('light', '#FFE7A3', rough=0.2, emit=1.8)
    m.ell(0, 5, 0, 3.6, 2.6, 13, 'hull')
    m.paint(lambda x, y, z, k: y <= 3, 'lime_d')
    m.ell(0, 7.2, 5, 2.1, 1.7, 4.2, 'glass')
    # 后掠翼
    for z in range(-8, 3):
        span = 4 + int((2 - z) * 0.85)
        m.box(3, 4, z, span, 4, z, 'lime')
        m.put(span, 5, z, 'dark')
    m.box(3, 5, -8, 11, 5, -8, 'lime_d')
    m.box(12, 4, -9, 12, 6, -8, 'light')
    # 尾翼
    for i in range(5):
        m.box(2, 6 + i, -12 + i, 2, 6 + i, -10 + i, 'lime')
    # 主引擎
    m.cyl('z', 0, 5, 2.7, -15, -12, 'dark')
    m.cyl('z', 0, 5, 2.0, -16, -16, 'glow')
    # 机头条纹
    m.paint(lambda x, y, z, k: k == 'hull' and z in (8, 9), 'lime')
    m.mirror()
    return m


def make_pirate_interceptor():
    m = VoxModel('ship_pirate_interceptor', '海贼截击机', 'ship', SHIP_SCALE,
                 '海贼的追击单位。在航线上随机出现，追上后会强制进入战斗。')
    m.mat('red', '#B8323F', metal=0.3, rough=0.45)
    m.mat('red_d', '#7A1E2A', metal=0.3, rough=0.5)
    m.mat('black', '#1F1A22', metal=0.4, rough=0.45)
    m.mat('metal', '#7A8296', metal=0.85, rough=0.3)
    m.mat('eye', '#FF4D6A', rough=0.1, emit=2.2)
    m.mat('glow', '#FF7A5A', rough=0.2, emit=2.4)
    m.mat('glass', '#E05A6A', rough=0.05, emit=0.4)
    # 机身（向前收窄）
    for z in range(-8, 11):
        hw = 3 if z < 1 else max(1, 3 - (z - 1) // 3)
        y0 = 2 if z < 1 else 3
        y1 = 7 if z < 1 else 6
        m.box(0, y0, z, hw, y1, z, 'red' if z >= -2 else 'black')
    # 骷髅机头
    m.box(0, 4, 11, 1, 5, 11, 'black')
    m.put(1, 5, 10, 'eye')
    m.box(0, 3, 10, 0, 3, 11, 'metal')
    # 座舱
    m.box(0, 7, 1, 1, 7, 4, 'glass')
    # 前掠锯齿翼
    for z in range(-6, 5):
        span = 5 + int((z + 6) * 0.8)
        m.box(4, 4, z, span, 4, z, 'red_d')
        if z % 2 == 0:
            m.put(span + 1, 4, z, 'red')
    m.box(4, 4, -6, 5, 4, -6, 'black')
    m.box(4, 5, -5, 4, 5, 2, 'black')
    m.box(13, 3, 4, 13, 6, 4, 'metal')
    m.box(13, 6, 5, 13, 6, 6, 'metal')
    # 引擎
    m.cyl('z', 2.5, 4.5, 1.8, -10, -9, 'metal')
    m.cyl('z', 2.5, 4.5, 1.2, -11, -11, 'glow')
    # 背鳍
    m.box(0, 8, -7, 0, 10, -5, 'black')
    m.mirror()
    return m


def make_pirate_gunship():
    m = VoxModel('ship_pirate_gunship', '海贼炮舰', 'ship', SHIP_SCALE,
                 '海贼据点的守卫舰。两座炮塔交叉射击，击沉后可以拖走残骸换钱。')
    m.mat('red', '#B8323F', metal=0.3, rough=0.45)
    m.mat('red_d', '#7A1E2A', metal=0.3, rough=0.5)
    m.mat('black', '#1F1A22', metal=0.4, rough=0.45)
    m.mat('plate', '#4A4F5E', metal=0.7, rough=0.4)
    m.mat('metal', '#7A8296', metal=0.85, rough=0.3)
    m.mat('eye', '#FF4D6A', rough=0.1, emit=2.2)
    m.mat('glow', '#FF7A5A', rough=0.2, emit=2.4)
    m.mat('bone', '#E8E1D0', rough=0.6)
    # 主舰体
    m.box(0, 2, -14, 7, 10, 8, 'plate')
    m.box(0, 10, -12, 5, 11, 6, 'black')
    # 撞角
    for z in range(9, 17):
        hw = max(0, 7 - (z - 8))
        top = max(3, 10 - (z - 8))
        m.box(0, 2, z, hw, top, z, 'red')
    m.box(0, 4, 17, 0, 5, 17, 'black')
    m.put(1, 6, 15, 'eye')
    # 红色装甲带
    m.box(8, 3, -12, 8, 8, 6, 'red_d')
    # 侧面骷髅标志（对称部分）
    m.box(9, 5, -4, 9, 7, -1, 'bone')
    m.put(9, 6, -3, 'black'); m.put(9, 6, -2, 'black')
    m.box(9, 4, -3, 9, 4, -2, 'bone')
    # 炮塔
    for tz in (-8, 3):
        m.cyl('y', 0, tz + 0.5, 2.6, 12, 13, 'red')
        m.box(-1, 14, tz - 1, 0, 14, tz + 1, 'black')
        m.box(1, 12, tz, 1, 12, tz + 6, 'metal')
        m.box(1, 12, tz + 7, 1, 12, tz + 7, 'eye')
    # 引擎
    for cx, cy in ((4.5, 4.5), (4.5, 8.5)):
        m.cyl('z', cx, cy, 1.8, -16, -15, 'metal')
        m.cyl('z', cx, cy, 1.2, -17, -17, 'glow')
    m.mirror()
    m.dither('plate', 'black', 0.07, seed=5)
    return m


def all_ships():
    return [make_stardust(), make_anvil(), make_firefly(), make_pirate_interceptor(), make_pirate_gunship()]
