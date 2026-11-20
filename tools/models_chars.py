# -*- coding: utf-8 -*-
"""角色与敌人体素模型（Q 版比例，单体素 0.08 米，身高约 1.6-1.7 米）"""
from voxlib import VoxModel

CHAR_SCALE = 0.08


def base_palette(m, skin='#F6D2B8', skin_sh='#E3B49A'):
    m.mat('skin', skin, rough=0.8)
    m.mat('skin_sh', skin_sh, rough=0.8)
    m.mat('eye', '#1C2140', rough=0.3)
    m.mat('eye_hi', '#FFFFFF', rough=0.2, emit=0.2)
    m.mat('blush', '#F59AA6', rough=0.8)
    m.mat('mouth', '#B5545C', rough=0.8)


def chibi(m, suit, suit2, boots, belt, hair, hair_sh, eye_color='#1C2140', iris=None,
          sleeve=None, glove=None):
    """标准 Q 版身体：腿 0-4，躯干 5-10，头 11-18（8x8x8），面朝 +Z。
    先构建右半边（x>=0）再镜像。"""
    m.mat('eye', eye_color, rough=0.3)
    sleeve = sleeve or suit
    glove = glove or 'skin'
    # 靴子
    m.boxm(1, 0, -1, 2, 1, 2, boots)
    # 腿
    m.boxm(1, 2, -1, 2, 3, 1, suit2)
    # 胯部
    m.boxm(0, 3, -1, 2, 4, 1, suit2)
    # 躯干
    m.boxm(0, 5, -1, 2, 10, 1, suit)
    m.boxm(0, 5, -1, 2, 5, 1, belt)
    # 手臂
    m.boxm(3, 6, -1, 3, 10, 0, sleeve)
    m.boxm(3, 5, -1, 3, 5, 0, glove)
    # 脖子
    m.boxm(0, 10, 0, 0, 10, 0, 'skin_sh')
    # 头
    m.boxm(0, 11, -3, 3, 18, 4, 'skin')
    # 头发外壳：顶部、后脑、两侧
    m.boxm(0, 17, -4, 4, 19, 5, hair)
    m.boxm(4, 12, -4, 4, 18, 3, hair)
    m.boxm(0, 11, -4, 3, 18, -4, hair)
    # 刘海（正面 z=5）
    m.boxm(0, 17, 5, 3, 17, 5, hair)
    m.boxm(2, 16, 5, 3, 16, 5, hair)
    m.box(0, 16, 5, 0, 16, 5, hair)
    m.boxm(4, 13, 4, 4, 16, 5, hair)
    m.boxm(1, 19, -3, 3, 19, 3, hair_sh)
    # 五官（正面 z=4 表层）
    for x in (1, 2):
        m.put(x, 13, 4, 'eye'); m.put(x, 14, 4, 'eye')
        m.put(-1 - x, 13, 4, 'eye'); m.put(-1 - x, 14, 4, 'eye')
    if iris:
        m.mat('iris', iris, rough=0.3, emit=0.15)
        m.put(1, 13, 4, 'iris'); m.put(-2, 13, 4, 'iris')
    m.put(2, 14, 4, 'eye_hi'); m.put(-3, 14, 4, 'eye_hi')
    m.put(3, 12, 4, 'blush'); m.put(-4, 12, 4, 'blush')
    m.put(0, 12, 4, 'mouth'); m.put(-1, 12, 4, 'mouth')
    # 眉毛
    m.put(1, 15, 4, hair_sh); m.put(2, 15, 4, hair_sh)
    m.put(-2, 15, 4, hair_sh); m.put(-3, 15, 4, hair_sh)


def make_captain():
    m = VoxModel('char_captain', '舰长 · 罗汉', 'crew', CHAR_SCALE,
                 '玩家角色。退役货运驾驶员，捡到第一块陨石碎片后踏上星路。')
    base_palette(m)
    m.mat('jacket', '#6B4A33', rough=0.85)
    m.mat('jacket_sh', '#4E3423', rough=0.85)
    m.mat('pants', '#2D3550', rough=0.8)
    m.mat('boots', '#22242C', rough=0.6)
    m.mat('belt', '#C9A15A', metal=0.6, rough=0.4)
    m.mat('hair', '#3A2A20', rough=0.9)
    m.mat('hair_sh', '#2A1E17', rough=0.9)
    m.mat('scarf', '#F5A524', rough=0.8)
    m.mat('cap', '#2D3550', rough=0.8)
    m.mat('badge', '#F5A524', metal=0.5, rough=0.3, emit=0.4)
    chibi(m, 'jacket', 'pants', 'boots', 'belt', 'hair', 'hair_sh', sleeve='jacket_sh', glove='boots')
    # 夹克敞开露出内衬
    m.box(0, 6, 2, -1, 9, 2, 'pants')
    m.box(0, 6, 2, -1, 6, 2, 'belt')
    # 围巾
    m.boxm(0, 10, -1, 2, 10, 2, 'scarf')
    m.box(2, 8, 2, 2, 9, 2, 'scarf')
    # 舰长帽
    m.boxm(0, 19, -4, 4, 20, 4, 'cap')
    m.boxm(0, 19, 5, 3, 19, 7, 'cap')
    m.box(0, 20, 5, -1, 20, 5, 'badge')
    m.carve(-5, 17, 5, 4, 17, 5)
    m.boxm(0, 18, 5, 3, 18, 5, 'hair')
    # 手枪
    m.mat('gun', '#3B4256', metal=0.8, rough=0.35)
    m.box(-4, 5, 1, -4, 5, 3, 'gun')
    m.box(-4, 4, 0, -4, 4, 0, 'gun')
    return m


def make_xingli():
    m = VoxModel('char_xingli', '星璃 · 枪手', 'crew', CHAR_SCALE,
                 '远程输出。用陨石碎片召唤的第一位伙伴，擅长持续射击，自动锁定最近的敌人。')
    base_palette(m)
    m.mat('suit', '#26305C', rough=0.6)
    m.mat('suit2', '#1B2244', rough=0.6)
    m.mat('trim', '#5CF2DC', rough=0.4, emit=0.6)
    m.mat('boots', '#E8E3D6', rough=0.5)
    m.mat('belt', '#5CF2DC', rough=0.4, emit=0.4)
    m.mat('hair', '#4FD6D0', rough=0.6)
    m.mat('hair_sh', '#2E9FA6', rough=0.6)
    chibi(m, 'suit', 'suit2', 'boots', 'belt', 'hair', 'hair_sh', iris='#4FD6D0', glove='boots')
    # 发光线条
    m.boxm(2, 6, 2, 2, 10, 2, 'trim')
    m.boxm(3, 9, 1, 3, 9, 1, 'trim')
    m.box(-1, 10, 2, 0, 10, 2, 'trim')
    # 高马尾
    m.box(-1, 18, -5, 0, 19, -5, 'hair')
    m.box(-1, 11, -6, 0, 18, -6, 'hair')
    m.box(-1, 9, -7, 0, 13, -7, 'hair_sh')
    m.box(-1, 19, -5, 0, 19, -5, 'trim')
    # 发饰
    m.put(4, 18, 3, 'trim'); m.put(4, 17, 3, 'trim')
    # 步枪
    m.mat('gun', '#E8E3D6', metal=0.3, rough=0.35)
    m.mat('gun_d', '#3B4256', metal=0.7, rough=0.35)
    m.box(-5, 6, -1, -5, 7, 6, 'gun')
    m.box(-5, 7, 7, -5, 7, 8, 'gun_d')
    m.box(-5, 5, 2, -5, 5, 2, 'gun_d')
    m.box(-5, 8, 3, -5, 8, 4, 'trim')
    m.box(-5, 6, 7, -5, 6, 7, 'trim')
    return m


def make_chiyan():
    m = VoxModel('char_chiyan', '赤焰 · 重装', 'crew', CHAR_SCALE,
                 '前排坦克。厚重护甲吸收伤害，近战锤击可以震退一圈敌人。')
    base_palette(m, skin='#F3C9A8', skin_sh='#DDA98A')
    m.mat('armor', '#E2552F', metal=0.4, rough=0.45)
    m.mat('armor_d', '#9E3320', metal=0.4, rough=0.5)
    m.mat('suit2', '#2B2F3A', rough=0.7)
    m.mat('boots', '#2B2F3A', metal=0.3, rough=0.5)
    m.mat('belt', '#F5A524', metal=0.5, rough=0.4)
    m.mat('hair', '#D6332A', rough=0.6)
    m.mat('hair_sh', '#9E2018', rough=0.6)
    chibi(m, 'armor', 'suit2', 'boots', 'belt', 'hair', 'hair_sh', iris='#F5A524', sleeve='armor_d', glove='boots')
    # 短发：剪掉后脑下部
    # （只剪头发，不能动头骨：原来 carve 整层 y=12 会把头挖空，头部中间出现一层空洞）
    for (x, y, z) in list(m.v):
        if m.v[(x, y, z)] in ('hair', 'hair_sh') and ((z == -4 and y <= 13) or (y == 12 and x in (4, -5))): m.put(x, y, z, None)
    m.boxm(0, 12, -3, 3, 12, 3, 'skin')                                   # 确保头骨这一层是实心的
    m.boxm(4, 13, 4, 4, 15, 5, 'hair')
    # 呆毛
    m.box(0, 20, 1, 0, 21, 1, 'hair'); m.box(1, 21, 0, 1, 21, 0, 'hair')
    # 大肩甲
    m.boxm(3, 9, -2, 5, 11, 1, 'armor')
    m.boxm(4, 11, -2, 5, 11, 1, 'armor_d')
    # 胸甲加厚
    m.boxm(0, 7, 2, 2, 9, 2, 'armor')
    m.box(0, 8, 2, -1, 8, 2, 'belt')
    # 战锤
    m.mat('hammer', '#5A6175', metal=0.85, rough=0.3)
    m.mat('core', '#F5A524', rough=0.3, emit=1.6)
    m.box(-5, 4, 0, -5, 12, 0, 'armor_d')
    m.box(-7, 12, -2, -3, 15, 2, 'hammer')
    m.box(-6, 13, 3, -4, 14, 3, 'core')
    m.box(-6, 13, -3, -4, 14, -3, 'core')
    return m


def make_yuexi():
    m = VoxModel('char_yuexi', '月汐 · 医疗', 'crew', CHAR_SCALE,
                 '后排治疗。随身的医疗浮游机会自动为生命最低的队员回血。')
    base_palette(m)
    m.mat('suit', '#EDEAF5', rough=0.55)
    m.mat('suit2', '#C9C3DD', rough=0.55)
    m.mat('trim', '#9B7BEA', rough=0.4, emit=0.5)
    m.mat('boots', '#9B7BEA', rough=0.5)
    m.mat('belt', '#9B7BEA', rough=0.4)
    m.mat('hair', '#DCD6F7', rough=0.6)
    m.mat('hair_sh', '#ADA2DB', rough=0.6)
    chibi(m, 'suit', 'suit2', 'boots', 'belt', 'hair', 'hair_sh', iris='#9B7BEA', glove='suit2')
    # 及腰长发
    m.boxm(0, 6, -5, 4, 18, -5, 'hair')
    m.boxm(1, 6, -6, 3, 15, -6, 'hair_sh')
    m.boxm(4, 9, -4, 4, 12, 2, 'hair')
    # 医疗十字
    m.box(0, 8, 2, -1, 8, 2, 'trim'); m.put(0, 9, 2, 'trim'); m.put(-1, 9, 2, 'trim')
    m.put(0, 7, 2, 'trim'); m.put(-1, 7, 2, 'trim')
    # 裙摆
    m.boxm(0, 4, -2, 3, 5, 2, 'suit')
    m.boxm(0, 4, 2, 3, 4, 2, 'trim')
    # 发卡
    m.put(3, 18, 5, 'trim'); m.put(3, 18, 4, 'trim')
    # 医疗浮游机（漂浮在肩旁）
    m.mat('drone', '#FFFFFF', metal=0.2, rough=0.3)
    m.mat('heal', '#7CF29A', rough=0.3, emit=1.4)
    m.box(-8, 15, 1, -6, 17, 3, 'drone')
    m.box(-7, 16, 4, -7, 16, 4, 'heal')
    m.box(-9, 16, 2, -9, 16, 2, 'trim'); m.box(-5, 16, 2, -5, 16, 2, 'trim')
    return m


def make_hupo():
    m = VoxModel('char_hupo', '琥珀 · 工程师', 'crew', CHAR_SCALE,
                 '辅助建造。能在着陆点快速架设炮塔，搜刮机械类物资时速度翻倍。')
    base_palette(m)
    m.mat('suit', '#F2C230', rough=0.7)
    m.mat('suit2', '#C9971C', rough=0.7)
    m.mat('trim', '#2B2F3A', rough=0.6)
    m.mat('boots', '#5B4636', rough=0.7)
    m.mat('belt', '#5B4636', rough=0.6)
    m.mat('hair', '#F08A2C', rough=0.6)
    m.mat('hair_sh', '#B85E14', rough=0.6)
    chibi(m, 'suit', 'suit2', 'boots', 'belt', 'hair', 'hair_sh', iris='#F08A2C', glove='trim')
    # 双马尾
    m.boxm(5, 15, -3, 6, 17, -2, 'hair')
    m.boxm(6, 9, -3, 7, 15, -2, 'hair')
    m.boxm(7, 8, -3, 7, 10, -2, 'hair_sh')
    m.boxm(5, 17, -3, 5, 17, -2, 'trim')
    # 护目镜
    m.mat('goggle', '#5CF2DC', rough=0.1, emit=0.5)
    m.boxm(0, 18, 5, 4, 18, 5, 'trim')
    m.boxm(1, 18, 6, 2, 19, 6, 'goggle')
    # 工装背带
    m.boxm(1, 6, 2, 1, 10, 2, 'suit2')
    m.box(0, 7, 2, -1, 8, 2, 'trim')
    # 大扳手
    m.mat('wrench', '#9AA3B5', metal=0.9, rough=0.3)
    m.box(-5, 3, 1, -5, 10, 1, 'wrench')
    m.box(-6, 10, 0, -4, 12, 2, 'wrench')
    m.carve(-5, 12, 1, -5, 12, 1)
    # 背包工具箱
    m.box(-2, 6, -2, 1, 9, -3, 'trim')
    m.box(-1, 9, -3, 0, 9, -3, 'suit')
    return m


def make_pirate_grunt():
    m = VoxModel('enemy_pirate_grunt', '海贼喽啰', 'enemy', CHAR_SCALE,
                 '星海贼团的杂兵。成群出现，血量低但会围攻落单的队员。')
    m.mat('armor', '#3A3F4F', metal=0.5, rough=0.5)
    m.mat('armor_d', '#262A35', metal=0.5, rough=0.55)
    m.mat('red', '#E0458C', rough=0.6)
    m.mat('red_d', '#9C2A5E', rough=0.6)
    m.mat('visor', '#FF4D6A', rough=0.1, emit=1.8)
    m.mat('cloth', '#5C2B3A', rough=0.85)
    m.mat('grill', '#7A8296', metal=0.8, rough=0.35)
    m.mat('blade', '#C8D0DE', metal=0.9, rough=0.2)
    # 身体
    m.boxm(1, 0, -1, 2, 1, 2, 'armor_d')
    m.boxm(1, 2, -1, 2, 3, 1, 'cloth')
    m.boxm(0, 3, -1, 2, 4, 1, 'cloth')
    m.boxm(0, 5, -2, 3, 10, 1, 'armor')
    m.boxm(0, 5, -2, 3, 5, 1, 'armor_d')
    m.boxm(0, 7, 2, 1, 9, 2, 'red_d')
    m.boxm(4, 5, -1, 4, 9, 0, 'armor_d')
    # 头盔
    m.boxm(0, 11, -3, 3, 17, 3, 'armor')
    m.boxm(0, 11, 4, 3, 16, 4, 'armor_d')
    m.boxm(1, 14, 4, 2, 14, 4, 'visor')
    m.boxm(1, 15, 4, 1, 15, 4, 'visor')
    m.boxm(0, 11, 5, 2, 12, 5, 'grill')
    m.boxm(1, 11, 5, 1, 12, 5, 'armor_d')
    # 头巾
    m.boxm(0, 17, -4, 4, 18, 4, 'red')
    m.boxm(0, 19, -3, 3, 19, 2, 'red_d')
    m.mirror()
    m.box(-1, 14, -5, 0, 17, -5, 'red')
    m.box(-2, 12, -6, -1, 15, -6, 'red_d')
    # 肩膀尖刺
    m.box(-5, 10, -1, -5, 12, 0, 'grill')
    # 举起的弯刀
    m.box(5, 5, 0, 5, 6, 1, 'armor_d')
    m.box(5, 7, 0, 5, 7, 2, 'grill')
    m.box(5, 8, 1, 5, 15, 1, 'blade')
    m.box(5, 13, 2, 5, 16, 2, 'blade')
    return m


def make_pirate_heavy():
    m = VoxModel('enemy_pirate_heavy', '海贼重炮手', 'enemy', CHAR_SCALE,
                 '扛着肩炮的精英海贼。移动缓慢，炮弹有范围伤害，需要优先集火。')
    m.mat('armor', '#4A2F38', metal=0.5, rough=0.45)
    m.mat('armor_d', '#2A1B21', metal=0.5, rough=0.5)
    m.mat('plate', '#7A8296', metal=0.8, rough=0.35)
    m.mat('visor', '#FF4D6A', rough=0.1, emit=1.8)
    m.mat('hazard', '#F5A524', rough=0.5)
    m.mat('glow', '#FF7A3A', rough=0.2, emit=2.0)
    m.boxm(1, 0, -2, 3, 2, 3, 'armor_d')
    m.boxm(1, 3, -2, 3, 5, 1, 'armor')
    m.boxm(0, 5, -3, 5, 13, 2, 'plate')
    m.boxm(0, 6, 3, 3, 11, 3, 'armor')
    m.boxm(0, 9, 3, 1, 9, 3, 'hazard')
    m.boxm(6, 6, -2, 7, 11, 1, 'armor')
    m.boxm(6, 4, -2, 7, 5, 1, 'armor_d')
    # 头（嵌在肩里）
    m.boxm(0, 14, -2, 2, 18, 3, 'armor_d')
    m.boxm(0, 16, 4, 2, 16, 4, 'visor')
    m.mirror()
    # 右肩炮
    m.box(-8, 13, -4, -5, 16, 6, 'armor')
    m.box(-7, 14, 7, -6, 15, 9, 'plate')
    m.box(-7, 14, 10, -6, 15, 10, 'glow')
    m.box(-8, 16, -2, -5, 16, 2, 'hazard')
    # 背后燃料罐
    m.box(-2, 7, -5, 1, 13, -4, 'armor_d')
    m.box(-1, 13, -5, 0, 14, -5, 'glow')
    return m


def make_crystal_crawler():
    m = VoxModel('enemy_crystal_crawler', '晶化爬虫', 'enemy', CHAR_SCALE,
                 '被陨石辐射改造的虫群。行动迅速，死后有几率掉落陨石碎片。')
    m.mat('shell', '#3B2650', rough=0.5)
    m.mat('shell_d', '#24163A', rough=0.55)
    m.mat('belly', '#6E4C8A', rough=0.7)
    m.mat('crys', '#5CF2DC', rough=0.1, emit=1.8)
    m.mat('crys2', '#E0458C', rough=0.1, emit=1.6)
    m.mat('eye', '#FFE36B', rough=0.1, emit=2.0)
    # 身体（扁长）
    m.ell(0, 4, 0, 5, 3, 8, 'shell')
    m.ell(0, 2.5, 0, 4, 1.5, 7, 'belly', recolor_only=False)
    m.paint(lambda x, y, z, k: y <= 2, 'belly')
    # 头
    m.ell(0, 4, 8, 3.5, 2.5, 3, 'shell_d')
    m.put(1, 5, 10, 'eye'); m.put(2, 4, 10, 'eye')
    # 颚
    m.box(1, 2, 10, 1, 3, 12, 'shell_d')
    m.box(2, 2, 12, 2, 2, 12, 'shell_d')
    # 腿
    for z in (-4, 0, 4):
        m.box(5, 3, z, 6, 3, z, 'shell_d')
        m.box(7, 0, z, 7, 3, z, 'shell_d')
    m.mirror()
    # 背部晶刺（不对称）
    m.box(0, 7, -2, 0, 11, -1, 'crys')
    m.box(1, 7, -1, 1, 9, -1, 'crys')
    m.box(-3, 6, 2, -2, 9, 3, 'crys2')
    m.box(2, 6, 3, 3, 8, 3, 'crys')
    m.box(-2, 6, -5, -1, 8, -4, 'crys')
    m.box(2, 6, -6, 2, 7, -6, 'crys2')
    m.dither('shell', 'shell_d', 0.12, seed=7)
    return m


def make_crystal_brute():
    m = VoxModel('enemy_crystal_brute', '晶核巨兽', 'enemy', CHAR_SCALE,
                 '陨石坠落点附近的守护者。岩石身躯嵌着巨大晶核，击破晶核才能造成有效伤害。')
    m.mat('rock', '#4B4458', rough=0.9)
    m.mat('rock_d', '#332E3E', rough=0.9)
    m.mat('rock_l', '#6A627A', rough=0.9)
    m.mat('core', '#E0458C', rough=0.1, emit=2.2)
    m.mat('crys', '#5CF2DC', rough=0.1, emit=1.6)
    # 腿
    m.boxm(2, 0, -2, 5, 7, 3, 'rock_d')
    # 躯干（宽大）
    m.ell(0, 15, 0, 9, 8, 6, 'rock')
    # 头（低垂）
    m.boxm(0, 19, 4, 3, 23, 8, 'rock_l')
    m.boxm(1, 21, 9, 2, 21, 9, 'crys')
    # 手臂（长到地面）
    m.boxm(9, 4, -2, 12, 20, 3, 'rock')
    m.boxm(9, 0, -2, 13, 4, 4, 'rock_d')
    m.mirror()
    # 胸口晶核
    m.box(-2, 13, 5, 1, 17, 7, 'core')
    m.box(-1, 14, 8, 0, 16, 8, 'core')
    # 背后晶簇
    m.box(-4, 20, -6, -3, 26, -4, 'crys')
    m.box(2, 19, -6, 3, 24, -5, 'crys')
    m.box(-1, 21, -7, 0, 28, -6, 'crys')
    m.box(10, 20, 0, 11, 23, 1, 'crys')
    m.dither('rock', 'rock_d', 0.18, seed=3)
    m.dither('rock', 'rock_l', 0.10, seed=4)
    return m


def all_chars():
    return [make_captain(), make_xingli(), make_chiyan(), make_yuexi(), make_hupo(),
            make_pirate_grunt(), make_pirate_heavy(), make_crystal_crawler(), make_crystal_brute()]

