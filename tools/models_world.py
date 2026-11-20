# -*- coding: utf-8 -*-
"""道具、着陆点环境、星图场景体素模型"""
import math, random
from voxlib import VoxModel

PROP_SCALE = 0.1
ENV_SCALE = 0.25


def hash3(x, y, z, seed):
    h = (x * 374761393 + y * 668265263 + z * 2147483647 + seed * 144665) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def vnoise(x, y, z, seed=0):
    """三维值噪声，取值 0..1"""
    xi, yi, zi = math.floor(x), math.floor(y), math.floor(z)
    xf, yf, zf = x - xi, y - yi, z - zi
    def s(t): return t * t * (3 - 2 * t)
    u, v, w = s(xf), s(yf), s(zf)
    def L(a, b, t): return a + (b - a) * t
    c = [[[hash3(xi + i, yi + j, zi + k, seed) for k in (0, 1)] for j in (0, 1)] for i in (0, 1)]
    return L(L(L(c[0][0][0], c[0][0][1], w), L(c[0][1][0], c[0][1][1], w), v),
             L(L(c[1][0][0], c[1][0][1], w), L(c[1][1][0], c[1][1][1], w), v), u)


def patch_paint(m, key, alts, freq=0.18, seed=1):
    """用低频噪声把 key 颜色分成块状色斑（比逐体素抖色更省面数）"""
    for p, k in list(m.v.items()):
        if k != key:
            continue
        n = vnoise(p[0] * freq, p[1] * freq, p[2] * freq, seed)
        for thr, alt in alts:
            if n > thr:
                m.v[p] = alt


# ---------------- 道具 ----------------

def make_meteor_shard():
    m = VoxModel('prop_meteor_shard', '陨石碎片', 'item',
                 PROP_SCALE, '核心资源。上古陨石炸裂后的碎片，集齐数量后可在星门召唤台召唤伙伴。')
    m.mat('rock', '#3A3346', rough=0.85)
    m.mat('rock_l', '#564C66', rough=0.85)
    m.mat('crys', '#5CF2DC', rough=0.05, emit=2.2)
    m.mat('crys2', '#E0458C', rough=0.05, emit=1.8)
    m.mat('vein', '#9DF7EC', rough=0.1, emit=1.2)
    m.ell(0, 3.5, 0, 4.5, 3.5, 4, 'rock')
    patch_paint(m, 'rock', [(0.6, 'rock_l')], 0.4, 2)
    # 晶体
    m.box(-1, 6, -1, 0, 11, 0, 'crys')
    m.box(-1, 11, 0, -1, 12, 0, 'crys')
    m.box(1, 5, 1, 2, 9, 2, 'crys')
    m.box(-4, 4, 0, -3, 7, 1, 'crys2')
    m.box(2, 5, -3, 3, 7, -2, 'crys')
    m.box(-2, 5, 3, -2, 6, 3, 'crys2')
    m.paint(lambda x, y, z, k: k in ('rock', 'rock_l') and ((x + z) % 5 == 0) and y in (2, 3), 'vein')
    return m


def make_supply_crate():
    m = VoxModel('prop_supply_crate', '补给箱', 'item', PROP_SCALE,
                 '常见物资。打开后获得食物与零件，是维持旅途的基本消耗品。')
    m.mat('steel', '#5C7FA8', metal=0.5, rough=0.45)
    m.mat('steel_d', '#3E5878', metal=0.5, rough=0.5)
    m.mat('amber', '#F5A524', rough=0.5)
    m.mat('dark', '#2B2F3A', metal=0.4, rough=0.5)
    m.mat('label', '#E8E1D0', rough=0.7)
    m.box(0, 0, -3, 4, 7, 3, 'steel')
    m.box(0, 0, -3, 4, 0, 3, 'dark')
    m.box(0, 7, -3, 4, 7, 3, 'steel_d')
    m.box(4, 1, -3, 4, 6, -3, 'steel_d'); m.box(4, 1, 3, 4, 6, 3, 'steel_d')
    m.box(0, 3, 4, 4, 3, 4, 'amber')
    m.box(5, 4, -1, 5, 5, 0, 'dark')
    m.box(0, 4, 4, 1, 5, 4, 'label')
    m.mirror()
    return m


def make_ammo_box():
    m = VoxModel('prop_ammo_box', '弹药箱', 'item', PROP_SCALE,
                 '队员的弹药补给。弹药耗尽的枪手只能用枪托近战。')
    m.mat('olive', '#6C7A4F', rough=0.6)
    m.mat('olive_d', '#4E5A38', rough=0.65)
    m.mat('brass', '#E2B84A', metal=0.9, rough=0.25)
    m.mat('dark', '#2B2F3A', rough=0.5)
    m.box(0, 0, -2, 3, 4, 2, 'olive')
    m.box(0, 4, -2, 3, 4, 2, 'olive_d')
    m.box(0, 2, 3, 3, 2, 3, 'dark')
    m.mat('tip', '#B5733A', metal=0.9, rough=0.3)
    for x in (0, 2):
        m.box(x, 5, -1, x, 6, -1, 'brass'); m.put(x, 7, -1, 'tip')
        m.box(x, 5, 1, x, 7, 1, 'brass'); m.put(x, 8, 1, 'tip')
    m.mirror()
    return m


def make_fuel_canister():
    m = VoxModel('prop_fuel_canister', '燃料罐', 'item', PROP_SCALE,
                 '飞船燃料。航行每跳一格都会消耗，燃料归零就只能在原地等待救援。')
    m.mat('red', '#E2552F', metal=0.4, rough=0.4)
    m.mat('red_d', '#A83A1E', metal=0.4, rough=0.45)
    m.mat('white', '#E8E1D0', rough=0.6)
    m.mat('metal', '#9AA3B5', metal=0.9, rough=0.3)
    m.mat('gauge', '#7CF29A', rough=0.2, emit=1.4)
    m.cyl('y', 0, 0, 3.2, 0, 9, 'red')
    m.cyl('y', 0, 0, 3.2, 0, 0, 'red_d')
    m.cyl('y', 0, 0, 3.3, 3, 4, 'white')
    m.cyl('y', 0, 0, 1.5, 10, 11, 'metal')
    m.box(-1, 5, 3, 0, 7, 3, 'gauge')
    m.box(-2, 10, -1, 1, 10, 0, 'metal')
    return m


def make_medkit():
    m = VoxModel('prop_medkit', '医疗包', 'item', PROP_SCALE,
                 '恢复一名队员 50% 生命。月汐在场时效果提升。')
    m.mat('white', '#F2F0EA', rough=0.5)
    m.mat('white_d', '#CFCBC0', rough=0.5)
    m.mat('green', '#4CC27A', rough=0.4, emit=0.5)
    m.mat('dark', '#2B2F3A', rough=0.5)
    m.box(0, 0, -2, 3, 4, 2, 'white')
    m.box(0, 0, -2, 3, 0, 2, 'white_d')
    m.box(0, 5, -1, 1, 5, 0, 'dark')
    m.mirror()
    m.box(-1, 1, 3, 0, 3, 3, 'green'); m.box(-2, 2, 3, 1, 2, 3, 'green')
    m.box(-1, 4, -1, 0, 4, 1, 'green'); m.box(-2, 4, 0, 1, 4, 0, 'green')
    return m


def make_scrap_pile():
    m = VoxModel('prop_scrap_pile', '废料堆', 'item', PROP_SCALE,
                 '可拆解的金属废料。琥珀在场时拆解速度翻倍，用来升级飞船。')
    m.mat('m1', '#7A8296', metal=0.85, rough=0.4)
    m.mat('m2', '#5A6175', metal=0.8, rough=0.45)
    m.mat('rust', '#9C5A33', metal=0.4, rough=0.8)
    m.mat('amber', '#F5A524', rough=0.5)
    m.mat('wire', '#E0458C', rough=0.5)
    rnd = random.Random(42)
    keys = ['m1', 'm2', 'rust', 'm1', 'm2', 'amber']
    for i in range(26):
        r = 6 - i * 0.18
        cx = rnd.uniform(-r, r); cz = rnd.uniform(-r, r)
        h = max(0, int(5 - math.hypot(cx, cz) * 0.7))
        w, d, hh = rnd.randint(1, 4), rnd.randint(1, 4), rnd.randint(1, 2)
        m.box(int(cx), h, int(cz), int(cx) + w - 1, h + hh - 1, int(cz) + d - 1, rnd.choice(keys))
    m.box(-5, 0, -5, 5, 0, 5, 'm2')
    m.carve(-5, 0, -5, -4, 0, -4); m.carve(4, 0, 4, 5, 0, 5)
    m.box(-2, 6, 0, 3, 6, 0, 'wire'); m.box(3, 5, 0, 3, 6, 0, 'wire')
    return m


def make_cargo_container():
    m = VoxModel('prop_cargo_container', '货运集装箱', 'item', PROP_SCALE,
                 '送货任务的货物。装进货柜后占用 2 格，送达目的地结算信用点。')
    m.mat('blue', '#2E5E9E', metal=0.5, rough=0.5)
    m.mat('blue_d', '#1F4373', metal=0.5, rough=0.55)
    m.mat('white', '#E8E1D0', rough=0.6)
    m.mat('dark', '#2B2F3A', rough=0.5)
    m.mat('amber', '#F5A524', rough=0.5)
    m.box(0, 0, -11, 5, 11, 11, 'blue')
    for z in range(-10, 11, 2):
        m.box(6, 1, z, 6, 10, z, 'blue_d')
    m.box(0, 0, -11, 6, 0, 11, 'dark'); m.box(0, 11, -11, 6, 11, 11, 'dark')
    m.box(0, 0, 12, 6, 11, 12, 'blue_d')
    m.box(0, 1, 13, 0, 10, 13, 'dark'); m.box(3, 1, 13, 3, 10, 13, 'dark')
    m.box(7, 6, -6, 7, 8, 2, 'white')
    m.box(7, 6, 3, 7, 8, 4, 'amber')
    m.mirror()
    return m


def make_summon_altar():
    m = VoxModel('prop_summon_altar', '星门召唤台', 'item', PROP_SCALE,
                 '用陨石碎片启动的召唤装置。消耗碎片随机召唤一位伙伴加入舰队。')
    m.mat('stone', '#3F3A52', rough=0.8)
    m.mat('stone_l', '#5A5470', rough=0.8)
    m.mat('gold', '#E2B84A', metal=0.9, rough=0.25)
    m.mat('crys', '#5CF2DC', rough=0.05, emit=2.4)
    m.mat('crys2', '#E0458C', rough=0.05, emit=2.0)
    m.mat('rune', '#9DF7EC', rough=0.1, emit=1.4)
    # 八角台座
    m.cyl('y', 0, 0, 14.5, 0, 1, 'stone')
    m.cyl('y', 0, 0, 12.5, 2, 2, 'stone_l')
    m.cyl('y', 0, 0, 10.5, 3, 3, 'stone')
    # 发光符文环
    for a in range(0, 360, 6):
        x = int(round(math.cos(math.radians(a)) * 11.5)); z = int(round(math.sin(math.radians(a)) * 11.5))
        m.put(x, 2, z, 'rune')
    # 立柱 + 拱门
    for a in range(0, 360, 60):
        cx = math.cos(math.radians(a)) * 12; cz = math.sin(math.radians(a)) * 12
        m.cyl('y', cx, cz, 1.3, 2, 9, 'stone_l')
        m.cyl('y', cx, cz, 1.6, 10, 10, 'gold')
        m.put(int(round(cx)), 11, int(round(cz)), 'crys')
    # 中央悬浮晶体
    m.box(-1, 8, -1, 0, 18, 0, 'crys')
    m.box(-2, 10, -1, 1, 15, 0, 'crys')
    m.box(-1, 10, -2, 0, 15, 1, 'crys')
    m.box(-1, 19, -1, 0, 19, 0, 'crys2')
    m.box(-1, 7, -1, 0, 7, 0, 'crys2')
    # 晶体支架
    m.cyl('y', 0, 0, 3.5, 4, 4, 'gold')
    m.cyl('y', 0, 0, 2.5, 5, 5, 'stone_l')
    return m


def make_console():
    m = VoxModel('prop_console', '控制台', 'item', PROP_SCALE,
                 '遗弃站点的终端。破解后会显示附近据点的位置和任务。')
    m.mat('body', '#4A4F5E', metal=0.6, rough=0.4)
    m.mat('body_d', '#2B2F3A', metal=0.6, rough=0.45)
    m.mat('screen', '#5CF2DC', rough=0.1, emit=1.6)
    m.mat('screen_d', '#2E9FA6', rough=0.1, emit=0.8)
    m.mat('btn', '#F5A524', rough=0.3, emit=0.8)
    m.mat('btn2', '#E0458C', rough=0.3, emit=0.8)
    m.box(0, 0, -3, 5, 8, 1, 'body')
    m.box(0, 0, -3, 5, 1, 1, 'body_d')
    for z in range(2, 6):
        m.box(0, 8 - (z - 2), z, 5, 8 - (z - 2), z, 'body_d')
    m.box(0, 9, -3, 5, 15, -2, 'body')
    m.box(0, 10, -1, 4, 14, -1, 'screen')
    m.box(0, 11, -1, 3, 11, -1, 'screen_d'); m.box(0, 13, -1, 2, 13, -1, 'screen_d')
    m.mirror()
    m.put(-3, 8, 2, 'btn'); m.put(1, 8, 2, 'btn2'); m.put(3, 7, 3, 'btn'); m.put(-1, 7, 3, 'btn2')
    return m


def make_turret():
    m = VoxModel('prop_turret', '防御炮塔', 'item', PROP_SCALE,
                 '琥珀架设的自动炮塔。持续 30 秒，优先攻击晶化生物。')
    m.mat('base', '#4A4F5E', metal=0.6, rough=0.4)
    m.mat('base_d', '#2B2F3A', metal=0.6, rough=0.45)
    m.mat('yellow', '#F2C230', rough=0.5)
    m.mat('metal', '#9AA3B5', metal=0.9, rough=0.3)
    m.mat('eye', '#5CF2DC', rough=0.1, emit=2.0)
    m.cyl('y', 0, 0, 6, 0, 1, 'base_d')
    for a in (45, 135, 225, 315):
        x = int(round(math.cos(math.radians(a)) * 6)); z = int(round(math.sin(math.radians(a)) * 6))
        m.box(x - 1, 0, z - 1, x, 0, z, 'yellow')
    m.cyl('y', 0, 0, 2.2, 2, 6, 'base')
    m.box(-4, 7, -4, 3, 11, 3, 'yellow')
    m.box(-4, 11, -4, 3, 11, 3, 'base_d')
    m.box(-2, 9, 4, 1, 10, 4, 'eye')
    for x in (-3, 2):
        m.box(x, 8, 4, x, 8, 11, 'metal')
        m.box(x, 9, 5, x, 9, 9, 'metal')
    m.box(-5, 7, -2, -5, 10, 1, 'base_d'); m.box(4, 7, -2, 4, 10, 1, 'base_d')
    return m


# ---------------- 着陆点环境 ----------------

def make_deck_tile():
    m = VoxModel('env_deck_tile', '金属甲板', 'env', ENV_SCALE,
                 '空间站地面瓦片，2 x 2 米，可无缝拼接。')
    m.mat('deck', '#5A6175', metal=0.7, rough=0.45)
    m.mat('deck_d', '#454B5C', metal=0.7, rough=0.5)
    m.mat('seam', '#2B2F3A', metal=0.5, rough=0.6)
    m.mat('light', '#5CF2DC', rough=0.2, emit=1.0)
    m.box(0, 0, 0, 7, 0, 7, 'deck')
    m.box(0, 0, 0, 7, 0, 0, 'seam'); m.box(0, 0, 0, 0, 0, 7, 'seam')
    m.box(2, 0, 2, 5, 0, 5, 'deck_d')
    m.put(1, 0, 1, 'light')
    return m


def make_rock_tile():
    m = VoxModel('env_rock_tile', '小行星地块', 'env', ENV_SCALE,
                 '小行星表面瓦片，2 x 2 米，自带起伏与色斑。')
    m.mat('rock', '#5B5268', rough=0.95)
    m.mat('rock_d', '#443D50', rough=0.95)
    m.mat('rock_l', '#73698A', rough=0.95)
    m.mat('dust', '#8C7F9E', rough=1.0)
    m.box(0, 0, 0, 7, 1, 7, 'rock')
    for x in range(8):
        for z in range(8):
            if vnoise(x * 0.4, 0, z * 0.4, 9) > 0.6:
                m.put(x, 2, z, 'rock_l')
    patch_paint(m, 'rock', [(0.55, 'rock_d')], 0.35, 4)
    m.put(5, 2, 2, 'dust'); m.put(2, 2, 6, 'dust')
    return m


def make_wall():
    m = VoxModel('env_wall', '站墙段', 'env', ENV_SCALE,
                 '前哨站外墙，3 米长。敌人会绕墙寻路，适合当作掩体。')
    m.mat('wall', '#6B7287', metal=0.6, rough=0.45)
    m.mat('wall_d', '#4A4F5E', metal=0.6, rough=0.5)
    m.mat('hazard', '#F5A524', rough=0.5)
    m.mat('dark', '#2B2F3A', rough=0.5)
    m.mat('light', '#FF4D6A', rough=0.2, emit=1.6)
    m.box(0, 0, 0, 11, 9, 1, 'wall')
    m.box(0, 0, 0, 11, 1, 1, 'wall_d')
    for x in range(12):
        m.put(x, 1, 2, 'hazard' if (x // 2) % 2 == 0 else 'dark')
    m.box(0, 0, 0, 0, 9, 1, 'dark'); m.box(11, 0, 0, 11, 9, 1, 'dark')
    m.box(1, 10, 0, 10, 10, 1, 'wall_d')
    m.box(3, 5, 2, 8, 6, 2, 'wall_d')
    m.put(5, 8, 2, 'light'); m.put(6, 8, 2, 'light')
    return m


def make_door():
    m = VoxModel('env_door', '气闸舱门', 'env', ENV_SCALE,
                 '前哨站入口。队员从这里进出建筑搜刮物资。')
    m.mat('wall', '#6B7287', metal=0.6, rough=0.45)
    m.mat('frame', '#F5A524', rough=0.5)
    m.mat('door', '#3E5878', metal=0.6, rough=0.4)
    m.mat('dark', '#2B2F3A', rough=0.5)
    m.mat('panel', '#7CF29A', rough=0.2, emit=1.4)
    m.box(0, 0, 0, 11, 10, 1, 'wall')
    m.box(3, 0, 0, 8, 7, 2, 'frame')
    m.box(4, 0, 1, 7, 6, 2, 'door')
    m.box(5, 0, 2, 6, 6, 2, 'dark')
    m.box(9, 3, 2, 9, 4, 2, 'panel')
    m.box(0, 10, 0, 11, 10, 1, 'dark')
    return m


def make_antenna():
    m = VoxModel('env_antenna', '通讯天线', 'env', ENV_SCALE,
                 '前哨站的信号塔。修好后可以在星图上提前看到下一站的情报。')
    m.mat('metal', '#9AA3B5', metal=0.9, rough=0.3)
    m.mat('metal_d', '#5A6175', metal=0.8, rough=0.4)
    m.mat('dish', '#E8E1D0', metal=0.3, rough=0.4)
    m.mat('light', '#FF4D6A', rough=0.2, emit=2.0)
    m.box(-2, 0, -2, 1, 0, 1, 'metal_d')
    for y in range(1, 16):
        m.put(-1, y, -1, 'metal'); m.put(0, y, 0, 'metal')
        if y % 3 == 0:
            m.box(-1, y, -1, 0, y, 0, 'metal_d')
    m.ell(0, 12, 2.5, 3.5, 3.5, 1.2, 'dish')
    m.box(0, 12, 4, 0, 12, 5, 'metal_d')
    m.box(-1, 16, -1, 0, 16, 0, 'light')
    return m


def make_solar():
    m = VoxModel('env_solar', '太阳能板', 'env', ENV_SCALE,
                 '为前哨站供电。被海贼击毁后站内照明会熄灭。')
    m.mat('panel', '#2E4E9E', metal=0.5, rough=0.15)
    m.mat('grid', '#9AA3B5', metal=0.9, rough=0.3)
    m.mat('post', '#5A6175', metal=0.8, rough=0.4)
    m.box(0, 0, 0, 0, 3, 0, 'post')
    for z in range(-3, 4):
        y = 4 + (z + 3) // 3
        m.box(-5, y, z, 5, y, z, 'panel')
    m.paint(lambda x, y, z, k: k == 'panel' and (x % 3 == 0 or z == 0), 'grid')
    return m


def make_crystal_cluster():
    m = VoxModel('env_crystal_cluster', '晶簇', 'env', PROP_SCALE,
                 '陨石坠落留下的晶体。可以开采少量陨石碎片，但会吸引晶化生物。')
    m.mat('rock', '#3A3346', rough=0.85)
    m.mat('c1', '#5CF2DC', rough=0.05, emit=1.8)
    m.mat('c2', '#E0458C', rough=0.05, emit=1.6)
    m.mat('c3', '#9DF7EC', rough=0.05, emit=1.2)
    m.ell(0, 0.5, 0, 6, 2, 5, 'rock')
    spikes = [(0, 0, 2, 16, 'c1'), (3, 2, 2, 10, 'c3'), (-4, 1, 2, 9, 'c2'), (1, -4, 1, 7, 'c1'),
              (-2, 3, 1, 6, 'c2'), (5, -2, 1, 5, 'c1')]
    for sx, sz, r, h, k in spikes:
        for y in range(1, h):
            rr = r if y < h * 0.7 else max(0, r - 1)
            lean = int(y * 0.15 * (1 if sx >= 0 else -1))
            m.box(sx - rr + lean, y, sz - rr, sx + rr - 1 + lean, y, sz + rr - 1, k)
    return m


def make_landing_pad():
    m = VoxModel('env_landing_pad', '着陆平台', 'env', ENV_SCALE,
                 '飞船停靠点。队员下船后从这里出发，撤离时必须回到平台。')
    m.mat('deck', '#5A6175', metal=0.7, rough=0.45)
    m.mat('deck_d', '#454B5C', metal=0.7, rough=0.5)
    m.mat('mark', '#F5A524', rough=0.5)
    m.mat('edge', '#2B2F3A', metal=0.5, rough=0.5)
    m.mat('light', '#5CF2DC', rough=0.2, emit=1.8)
    m.box(0, 0, 0, 13, 1, 13, 'deck')
    m.box(0, 0, 0, 13, 0, 13, 'deck_d')
    m.box(13, 0, 0, 13, 1, 13, 'edge')
    m.box(0, 1, 13, 13, 1, 13, 'edge')
    for i in range(0, 14, 3):
        m.put(13, 2, i, 'light'); m.put(i, 2, 13, 'light')
    # H 标记（右半）
    m.box(4, 1, -6, 5, 1, 5, 'mark')
    m.box(0, 1, -1, 4, 1, 0, 'mark')
    m.mirror()
    m.paint(lambda x, y, z, k: k == 'deck' and y == 1 and z < -0, 'deck')
    # 镜像 Z 方向
    for (x, y, z), k in list(m.v.items()):
        if z >= 0:
            m.v[(x, y, -1 - z)] = k
    return m


def make_landing_ground():
    m = VoxModel('env_landing_ground', '着陆点地面', 'env', ENV_SCALE,
                 '整块着陆场景地面：小行星岩地 + 前哨站甲板区 + 停机坪，24 x 18 米。',
                 pivot=(0, 6, 0))
    m.mat('rock', '#5B5268', rough=0.95)
    m.mat('rock_d', '#443D50', rough=0.95)
    m.mat('rock_l', '#73698A', rough=0.95)
    m.mat('crater', '#3A3346', rough=1.0)
    m.mat('glowdust', '#5CF2DC', rough=0.3, emit=0.9)
    m.mat('deck', '#5A6175', metal=0.7, rough=0.45)
    m.mat('deck_d', '#454B5C', metal=0.7, rough=0.5)
    m.mat('seam', '#2B2F3A', metal=0.5, rough=0.6)
    m.mat('hazard', '#F5A524', rough=0.5)
    W, D = 96, 72
    for x in range(-W // 2, W // 2):
        for z in range(-D // 2, D // 2):
            n = vnoise(x * 0.07, 0, z * 0.07, 3) * 0.7 + vnoise(x * 0.2, 1, z * 0.2, 5) * 0.3
            h = 2 + int(n * 3.2)
            # 边缘下沉，像一块漂浮的小行星
            edge = min(x + W // 2, W // 2 - 1 - x, z + D // 2, D // 2 - 1 - z)
            if edge < 4:
                h = max(0, h - (4 - edge))
            for y in range(0, h + 1):
                m.put(x, y, z, 'rock')
            # 底部向下收缩成岩块
            depth = 3 + min(edge, 10)
            for y in range(-depth, 0):
                m.put(x, y, z, 'rock_d')
    patch_paint(m, 'rock', [(0.55, 'rock_d'), (0.72, 'rock_l')], 0.12, 7)
    # 陨石坑
    for cx, cz, r in ((-30, 18, 7), (-26, -20, 5), (-6, -28, 4)):
        for x in range(cx - r, cx + r + 1):
            for z in range(cz - r, cz + r + 1):
                d = math.hypot(x - cx, z - cz)
                if d <= r:
                    top = max(y for y in range(-20, 12) if (x, y, z) in m.v)
                    cut = int((1 - d / r) * 3) + 1
                    for y in range(top - cut + 1, top + 1):
                        m.put(x, y, z, None)
                    m.put(x, top - cut, z, 'crater')
                    if d < r * 0.35 and hash3(x, 0, z, 3) > 0.5:
                        m.put(x, top - cut, z, 'glowdust')
                elif d <= r + 1.2:
                    top = max(y for y in range(-20, 12) if (x, y, z) in m.v)
                    m.put(x, top + 1, z, 'rock_l')
    # 停机坪平整区（x 12..40, z 8..34）
    for x in range(12, 41):
        for z in range(8, 35):
            for y in range(-20, 14):
                if y > 5:
                    m.put(x, y, z, None)
                elif y == 5 or (x, y, z) not in m.v and y >= 0:
                    m.put(x, y, z, 'rock_d')
    # 前哨站甲板区（x 8..44, z -30..6，平整高度 5）
    for x in range(8, 44):
        for z in range(-30, 6):
            for y in range(0, 12):
                if y > 5:
                    m.put(x, y, z, None)
                elif y == 5:
                    seam = (x % 8 == 0) or (z % 8 == 0)
                    k = 'seam' if seam else ('deck_d' if ((x // 8 + z // 8) % 2) else 'deck')
                    if x in (8, 43) or z in (-30, 5):
                        k = 'hazard' if ((x + z) // 2) % 2 == 0 else 'seam'
                    m.put(x, y, z, k)
                else:
                    if (x, y, z) not in m.v:
                        m.put(x, y, z, 'rock_d')
    return m


# ---------------- 星图 / 太空场景 ----------------

def asteroid(mid, name, desc, seed, rx, ry, rz, crystals=False):
    m = VoxModel(mid, name, 'space', 0.5, desc, pivot='center')
    m.mat('rock', '#5B5268', rough=0.95)
    m.mat('rock_d', '#3F384A', rough=0.95)
    m.mat('rock_l', '#7A6F90', rough=0.95)
    m.mat('crater', '#2F2A38', rough=1.0)
    m.mat('crys', '#5CF2DC', rough=0.05, emit=2.0)
    m.mat('crys2', '#E0458C', rough=0.05, emit=1.8)
    for x in range(-rx - 2, rx + 3):
        for y in range(-ry - 2, ry + 3):
            for z in range(-rz - 2, rz + 3):
                dx, dy, dz = (x + .5) / rx, (y + .5) / ry, (z + .5) / rz
                d = math.sqrt(dx * dx + dy * dy + dz * dz)
                n = vnoise(x * 0.25, y * 0.25, z * 0.25, seed)
                if d < 0.82 + n * 0.32:
                    m.put(x, y, z, 'rock')
    patch_paint(m, 'rock', [(0.58, 'rock_d'), (0.74, 'rock_l')], 0.22, seed + 1)
    rnd = random.Random(seed)
    surf = [p for p in m.v if m.is_surface(p)]
    for _ in range(4):
        c = rnd.choice(surf)
        for p in surf:
            if (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 + (p[2] - c[2]) ** 2 <= 4:
                m.v[p] = 'crater'
    if crystals:
        for _ in range(6):
            c = rnd.choice([p for p in surf if p[1] > 0])
            k = rnd.choice(['crys', 'crys', 'crys2'])
            for i in range(rnd.randint(2, 4)):
                m.put(c[0], c[1] + i, c[2], k)
    return m


def make_station():
    m = VoxModel('space_station', '贸易空间站', 'space', 0.5,
                 '星图上的商店节点。可以交货、买船、招募、补给燃料。', pivot='center')
    m.mat('hull', '#D9D2C0', metal=0.3, rough=0.45)
    m.mat('hull_d', '#9E9684', metal=0.3, rough=0.5)
    m.mat('dark', '#2B2F3A', metal=0.5, rough=0.5)
    m.mat('amber', '#F5A524', rough=0.5)
    m.mat('window', '#FFE7A3', rough=0.2, emit=1.6)
    m.mat('glow', '#5CF2DC', rough=0.2, emit=2.0)
    m.mat('panel', '#2E4E9E', metal=0.5, rough=0.15)
    # 环
    R = 16
    for a in range(0, 360, 2):
        cx = math.cos(math.radians(a)) * R; cz = math.sin(math.radians(a)) * R
        for y in range(-1, 2):
            m.ell(cx, y + 0.5, cz, 2.2, 1.0, 2.2, 'hull')
    for a in range(0, 360, 15):
        cx = int(round(math.cos(math.radians(a)) * (R + 2))); cz = int(round(math.sin(math.radians(a)) * (R + 2)))
        m.put(cx, 0, cz, 'window')
    # 辐条
    for a in (0, 90, 180, 270):
        for r in range(4, R - 1):
            x = int(round(math.cos(math.radians(a)) * r)); z = int(round(math.sin(math.radians(a)) * r))
            m.box(x, 0, z, x, 0, z, 'dark')
    # 中枢
    m.cyl('y', 0, 0, 4.5, -6, 6, 'hull_d')
    m.cyl('y', 0, 0, 5, -1, 1, 'amber')
    m.cyl('y', 0, 0, 3, 7, 11, 'hull')
    m.cyl('y', 0, 0, 1, 12, 15, 'dark')
    m.box(0, 16, 0, 0, 16, 0, 'glow')
    m.cyl('y', 0, 0, 2.5, -10, -7, 'dark')
    m.cyl('y', 0, 0, 1.5, -11, -11, 'glow')
    for y in (-4, 3):
        for a in range(0, 360, 30):
            x = int(round(math.cos(math.radians(a)) * 4.6)); z = int(round(math.sin(math.radians(a)) * 4.6))
            m.put(x, y, z, 'window')
    # 太阳能翼
    m.box(5, 9, -1, 14, 9, 0, 'dark')
    m.box(-15, 9, -1, -6, 9, 0, 'dark')
    m.box(6, 9, -4, 14, 9, 3, 'panel'); m.box(-15, 9, -4, -7, 9, 3, 'panel')
    return m


def make_planet():
    m = VoxModel('space_planet', '气态行星 · 赤环', 'space', 2.0,
                 '远景装饰。星图背景中的巨大行星，带有体素星环。', pivot='center')
    m.mat('b1', '#C46A4A', rough=0.9)
    m.mat('b2', '#E09A62', rough=0.9)
    m.mat('b3', '#8E4A5E', rough=0.9)
    m.mat('b4', '#F2C99A', rough=0.9)
    m.mat('ring', '#B8A7C9', rough=0.9)
    m.mat('ring2', '#7E6E94', rough=0.9)
    R = 14
    bands = ['b1', 'b2', 'b4', 'b2', 'b1', 'b3', 'b1', 'b2']
    for x in range(-R, R):
        for y in range(-R, R):
            for z in range(-R, R):
                d = math.sqrt((x + .5) ** 2 + (y + .5) ** 2 + (z + .5) ** 2)
                if R - 2.2 < d <= R:
                    wob = vnoise(x * 0.3, 0, z * 0.3, 2) * 2.5
                    bi = int((y + R + wob) / 3.6) % len(bands)
                    m.put(x, y, z, bands[bi])
    for a in range(0, 360, 1):
        for r in (19, 20, 21, 23, 24):
            x = int(math.floor(math.cos(math.radians(a)) * r)); z = int(math.floor(math.sin(math.radians(a)) * r))
            m.put(x, 0, z, 'ring' if r < 22 else 'ring2')
    # 星环倾斜：整体剪切
    tilted = {}
    for (x, y, z), k in m.v.items():
        tilted[(x, y + int(round(x * 0.22)), z)] = k
    m.v = tilted
    return m


def make_beacon():
    m = VoxModel('space_beacon', '航路信标', 'space', 0.2,
                 '星路上的路标。显示到下一站的距离，相当于公路旅行里的里程牌。')
    m.mat('post', '#5A6175', metal=0.8, rough=0.4)
    m.mat('sign', '#2B2F3A', metal=0.4, rough=0.5)
    m.mat('amber', '#F5A524', rough=0.4, emit=0.7)
    m.mat('light', '#5CF2DC', rough=0.1, emit=2.4)
    m.mat('red', '#FF4D6A', rough=0.1, emit=2.0)
    m.box(0, 0, 0, 0, 12, 0, 'post')
    m.box(-1, 0, -1, 1, 0, 1, 'post')
    m.box(-5, 8, 1, 5, 12, 1, 'sign')
    m.box(-4, 9, 2, 4, 9, 2, 'amber'); m.box(-4, 11, 2, 1, 11, 2, 'amber')
    m.box(3, 11, 2, 4, 11, 2, 'light')
    m.box(-1, 13, -1, 1, 14, 1, 'post')
    m.box(0, 15, 0, 0, 15, 0, 'red')
    m.box(-6, 10, 1, -6, 10, 1, 'light'); m.box(6, 10, 1, 6, 10, 1, 'light')
    return m


def make_derelict():
    m = VoxModel('space_derelict', '遗弃舰残骸', 'space', 0.25,
                 '搜刮节点。船体断成两截，内部可能还有补给，也可能有晶化虫巢。', pivot='center')
    m.mat('hull', '#8E8778', metal=0.4, rough=0.6)
    m.mat('hull_d', '#5E594E', metal=0.4, rough=0.7)
    m.mat('dark', '#1F1A22', rough=0.8)
    m.mat('rust', '#9C5A33', metal=0.3, rough=0.85)
    m.mat('crys', '#5CF2DC', rough=0.05, emit=2.0)
    m.mat('amber', '#F5A524', rough=0.5)
    m.mat('metal', '#7A8296', metal=0.85, rough=0.35)
    # 前半截（机头 + 驾驶舱），稍微偏转
    for z in range(0, 18):
        hw = 5 if z < 10 else max(1, 5 - (z - 9) // 2)
        top = 4 if z < 12 else max(0, 4 - (z - 11))
        m.box(-hw, -3, z, hw - 1, top, z, 'hull')
    m.box(-3, 2, 12, 2, 2, 14, 'dark')
    m.box(-5, -1, 2, -5, 0, 10, 'amber')
    # 后半截（引擎段），向下错开并带断口
    for z in range(-22, -5):
        m.box(-5, -6, z, 4, 1, z, 'hull')
    for cx in (-2.5, 2.5):
        m.cyl('z', cx + 0.0, -2.5, 2.2, -25, -23, 'metal')
        m.cyl('z', cx + 0.0, -2.5, 1.4, -26, -26, 'dark')
    m.box(-5, 2, -20, -2, 5, -12, 'hull_d')
    # 断口锯齿
    for x in range(-5, 5):
        for y in range(-6, 5):
            k = int(vnoise(x * 0.6, y * 0.6, 0, 8) * 4)
            for z in range(-5, -5 + k):
                if y <= 1:
                    m.put(x, y, z, 'hull_d')
            for z in range(0, 3 - k):
                m.put(x, y, z, None)
    m.paint(lambda x, y, z, k: k == 'hull' and z in (3 - 0, -6), 'dark')
    # 漂浮碎片
    m.box(6, 3, -3, 7, 4, -2, 'hull_d'); m.box(-8, -2, -4, -7, -2, -2, 'rust')
    m.box(1, 6, -2, 2, 6, -1, 'metal')
    patch_paint(m, 'hull', [(0.6, 'hull_d'), (0.8, 'rust')], 0.25, 12)
    m.box(-1, -2, -5, 0, 0, -5, 'crys'); m.box(2, -4, -6, 2, -2, -6, 'crys')
    return m


def make_pedestal():
    m = VoxModel('sys_pedestal', '展示台', 'system', 0.1, '图鉴展示用底座。')
    m.mat('base', '#2A3157', metal=0.5, rough=0.4)
    m.mat('top', '#363F6E', metal=0.5, rough=0.35)
    m.mat('ring', '#5CF2DC', rough=0.2, emit=1.4)
    m.cyl('y', 0, 0, 12, 0, 1, 'base')
    m.cyl('y', 0, 0, 11, 2, 2, 'top')
    for a in range(0, 360, 3):
        x = int(math.floor(math.cos(math.radians(a)) * 11.6)); z = int(math.floor(math.sin(math.radians(a)) * 11.6))
        m.put(x, 1, z, 'ring')
    return m


def all_world():
    return [make_meteor_shard(), make_supply_crate(), make_ammo_box(), make_fuel_canister(), make_medkit(),
            make_scrap_pile(), make_cargo_container(), make_summon_altar(), make_console(), make_turret(),
            make_landing_pad(), make_deck_tile(), make_rock_tile(), make_wall(), make_door(), make_antenna(),
            make_solar(), make_crystal_cluster(), make_landing_ground(),
            asteroid('space_asteroid_a', '小行星 · 甲', '航线两侧漂浮的岩块，远景装饰。', 31, 9, 7, 8),
            asteroid('space_asteroid_b', '晶脉小行星', '嵌有陨石晶体的小行星，可作为采集节点。', 47, 7, 6, 7, crystals=True),
            make_station(), make_planet(), make_beacon(), make_derelict(), make_pedestal()]
