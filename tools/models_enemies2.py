# -*- coding: utf-8 -*-
"""v0.9.20 新增敌人：晶刺狙击手 / 盾卫 / 裂变晶体 / 自爆虫 / 幽影刺客（均为原创体素造型）。"""
from voxlib import VoxModel
CHAR_SCALE = 0.08


def make_sniper():
    m = VoxModel('enemy_crystal_sniper', '晶刺狙击手', 'enemy', CHAR_SCALE, '背负长炮管的晶化狙击手，远距离蓄力后射出贯穿光矢。')
    m.mat('shell', '#3B2650', rough=0.5); m.mat('shell_d', '#24163A', rough=0.55); m.mat('belly', '#6E4C8A', rough=0.7)
    m.mat('plate', '#5A4A78', rough=0.45); m.mat('crys', '#5CF2DC', rough=0.1, emit=1.8); m.mat('eye', '#FF4D6A', rough=0.1, emit=2.2)
    for z in (-4, 0, 4):                                                       # 外展再下垂的三对蜘蛛腿（带膝盖）
        m.box(3, 8, z, 6, 9, z, 'shell_d'); m.box(6, 3, z, 7, 8, z, 'shell_d'); m.box(6, 0, z, 8, 2, z, 'plate')
    m.ell(0, 10, 0, 5.5, 3.5, 6.5, 'shell'); m.ell(0, 8.5, 0, 4.5, 1.8, 5.5, 'belly')
    m.box(0, 12, 4, 3, 15, 8, 'plate'); m.put(1, 14, 9, 'eye'); m.put(2, 14, 9, 'eye')   # 头（护甲罩 + 目镜）
    m.mirror()
    m.box(-2, 13, -4, 1, 16, 4, 'plate')                                        # 炮座
    m.box(-1, 14, 4, 0, 15, 17, 'shell_d')                                      # 深色炮管（沿 z 向前）
    m.box(-1, 14, 17, 0, 15, 18, 'crys')                                        # 仅炮口发光
    m.box(-1, 17, -3, 0, 19, -2, 'crys'); m.box(2, 14, -2, 2, 16, -2, 'crys')   # 背部小晶刺
    m.dither('shell', 'shell_d', 0.12, seed=11)
    return m


def make_guard():
    m = VoxModel('enemy_shield_guard', '盾卫', 'enemy', CHAR_SCALE, '手持能量盾牌的重装海贼，正面几乎不受伤，要绕到背后或等盾牌破绽。')
    m.mat('arm', '#5A5F73', metal=0.4, rough=0.5); m.mat('arm_d', '#383C4D', metal=0.4, rough=0.55); m.mat('hz', '#E8A317', rough=0.6)
    m.mat('skin', '#C79A6E', rough=0.8); m.mat('shield', '#5CF2DC', rough=0.1, emit=1.3); m.mat('visor', '#FF4D6A', rough=0.1, emit=1.8)
    m.box(1, 0, -1, 3, 8, 2, 'arm_d')                                          # 腿
    m.box(-4, 9, -3, 4, 17, 3, 'arm'); m.box(-4, 15, -3, 4, 15, 3, 'hz')         # 躯干 + 警示条
    m.box(-3, 18, -2, 3, 23, 3, 'arm'); m.box(-2, 20, 3, 2, 21, 3, 'visor')       # 头盔 + 目镜
    m.box(5, 10, -2, 7, 16, 2, 'arm_d')                                        # 右臂
    m.box(-9, 6, 5, 2, 23, 6, 'arm_d')                                         # 能量盾牌底板（正面）
    m.box(-8, 7, 7, 1, 22, 7, 'shield'); m.box(-4, 12, 8, -2, 17, 8, 'hz')
    m.mirror()
    m.dither('arm', 'arm_d', 0.1, seed=3)
    return m


def make_splitter():
    m = VoxModel('enemy_crystal_splitter', '裂变晶体', 'enemy', CHAR_SCALE, '鼓胀的晶化团块，被击破时会裂成几只爬虫。')
    m.mat('shell', '#3B2650', rough=0.5); m.mat('shell_d', '#24163A', rough=0.55); m.mat('core', '#E0458C', rough=0.1, emit=2.0); m.mat('crys', '#5CF2DC', rough=0.1, emit=1.6)
    m.ell(0, 7, 0, 8, 7, 8, 'shell')
    for (x, y, z, r) in ((0, 13, 0, 3), (4, 11, 3, 2), (-4, 11, -3, 2)):
        m.ell(x, y, z, r, r, r, 'shell_d')
    for z in (-5, -1, 3):                                                      # 发光裂缝
        m.box(-1, 3, z, 0, 12, z, 'core')
    m.box(-7, 7, 0, 7, 7, 0, 'core')
    m.box(-2, 14, -1, 1, 17, 1, 'crys'); m.box(5, 12, 3, 5, 15, 3, 'crys'); m.box(-5, 12, -3, -5, 14, -3, 'crys')
    for x, z in ((6, 2), (-6, 2), (5, -4), (-5, -4)):
        m.box(x, 0, z, x, 2, z, 'shell_d')
    m.put(3, 9, 8, 'crys'); m.put(-3, 9, 8, 'crys')
    return m


def make_bomber():
    m = VoxModel('enemy_bomber_bug', '自爆虫', 'enemy', CHAR_SCALE, '背着炸药囊的虫群先锋，贴近后短暂闪烁，随即自爆。')
    m.mat('shell', '#7A3B2B', rough=0.5); m.mat('shell_d', '#4A2218', rough=0.55); m.mat('bomb', '#FF8A3A', rough=0.1, emit=2.2); m.mat('eye', '#FFE36B', rough=0.1, emit=2.0)
    m.ell(0, 4, 0, 4.5, 3.5, 5.5, 'shell')
    m.ell(0, 6, -1, 3.5, 3, 3.5, 'bomb')                                       # 背部炸药囊
    m.box(0, 5, 5, 1, 7, 7, 'shell_d'); m.put(1, 7, 8, 'eye'); m.put(2, 6, 7, 'eye')
    m.box(2, 0, -3, 3, 3, -3, 'shell_d'); m.box(3, 0, 0, 4, 3, 0, 'shell_d'); m.box(2, 0, 3, 3, 3, 3, 'shell_d')
    m.mirror()
    m.box(0, 10, -3, 0, 13, -3, 'shell_d'); m.put(0, 14, -3, 'bomb')            # 引信
    m.dither('shell', 'shell_d', 0.15, seed=5)
    return m


def make_phantom():
    m = VoxModel('enemy_phantom_blade', '幽影刺客', 'enemy', CHAR_SCALE, '披着暗色斗篷的刺客，会瞬移到你背后挥刀。')
    m.mat('cloak', '#241A3A', rough=0.7); m.mat('cloak_d', '#140E24', rough=0.75); m.mat('blade', '#B47CFF', rough=0.1, emit=1.8); m.mat('eye', '#FF4D6A', rough=0.1, emit=2.2)
    m.box(1, 0, -1, 2, 7, 1, 'cloak_d')                                        # 腿
    m.box(-3, 8, -2, 3, 16, 2, 'cloak')                                        # 躯干
    for i in range(8):                                                         # 向后拖曳的斗篷
        m.box(-3 + i // 3, 8 - i // 2, -3 - i, 3 - i // 3, 15 - i, -3 - i, 'cloak_d')
    m.box(-2, 17, -1, 2, 21, 3, 'cloak'); m.put(1, 19, 4, 'eye'); m.put(-2, 19, 4, 'eye')
    m.box(4, 10, -1, 5, 15, 1, 'cloak')                                        # 手臂
    m.box(5, 12, 2, 5, 13, 14, 'blade'); m.box(5, 11, 12, 5, 14, 14, 'blade')   # 臂刃（向前）
    m.mirror()
    return m


def all_enemies2():
    return [make_sniper(), make_guard(), make_splitter(), make_bomber(), make_phantom()]
