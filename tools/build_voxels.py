# -*- coding: utf-8 -*-
"""
陨星公路 · 资产构建脚本
用法：python3 tools/build_voxels.py
输出：
  scripts/voxeldata/models/*.lua   —— UrhoX 运行时读取的模型数据（贪婪合并后的四边形）
  scripts/voxeldata/Catalog.lua    —— 图鉴目录
  scripts/voxeldata/Scenes.lua     —— 预览场景布局（摆放、动画、灯光、相机）
  preview/data/assets.js           —— HTML 预览用同一份数据
  source_art/vox/*.vox             —— MagicaVoxel 源文件，可直接打开修改
"""
import os, json, math, random, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

from voxlib import lua_value, write_vox, build_parts
from models_chars import all_chars
from models_ships import all_ships
from models_world import all_world
from models_galaxy import all_galaxy
from models_mechs import all_mechs
from models_enemies2 import all_enemies2
from gamedata import GAME

CATEGORIES = [
    ('mech', '机甲'), ('crew', '驾驶员'), ('enemy', '敌人'), ('ship', '飞船'),
    ('item', '道具'), ('env', '场景件'), ('space', '星图'),
]

TAU = math.pi * 2


def r3(v):
    return [round(float(x), 3) for x in v]


def build_all():
    models = all_mechs() + all_chars() + all_ships() + all_world() + all_galaxy() + all_enemies2()
    built = {}
    for m in models:
        b = m.build()
        built[m.id] = (m, b)
    return built


# ---------------------------------------------------------------- 场景
class Ground:
    """着陆点地面高度查询"""
    def __init__(self, model, built):
        self.cols = {}
        for (x, y, z) in model.v:
            if y > self.cols.get((x, z), -999):
                self.cols[(x, z)] = y
        self.scale = model.scale
        self.oy = model.pivot[1]

    def h(self, wx, wz):
        """角色脚底中心所在列及周围 3x3 列的最高点，避免脚陷进起伏的岩地"""
        vx = math.floor(wx / self.scale); vz = math.floor(wz / self.scale)
        top = max(self.cols.get((vx + dx, vz + dz), -999) for dx in (-1, 0, 1) for dz in (-1, 0, 1))
        return round((top + 1 - self.oy) * self.scale, 3)


def item(model, pos, yaw=0.0, scale=1.0, anim=None):
    d = dict(model=model, pos=r3(pos), yaw=round(yaw, 2), scale=round(scale, 3))
    if anim:
        d['anim'] = anim
    return d


def stars(seed, count, rmin, rmax, size):
    rnd = random.Random(seed)
    out = []
    for _ in range(count):
        while True:
            x, y, z = rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1)
            l = math.sqrt(x * x + y * y + z * z)
            if 0.2 < l <= 1:
                break
        r = rnd.uniform(rmin, rmax)
        c = rnd.choices([0, 1, 2], weights=[7, 2, 1])[0]
        out += [round(x / l * r, 2), round(y / l * r, 2), round(z / l * r, 2),
                round(size * rnd.uniform(0.5, 1.5), 2), c]
    return out


STAR_COLORS = [[0.92, 0.93, 1.0], [0.55, 0.95, 0.9], [1.0, 0.8, 0.5]]


def scene_cruise():
    items = [item('ship_stardust', (0, 0, 0), 0, 1, dict(type='hover', amp=0.18, speed=0.55, roll=4)),
             item('ship_pirate_interceptor', (3.0, 1.2, -10.5), 0, 1,
                  dict(type='chase', ax=2.6, az=3.0, speed=0.22, roll=14)),
             item('space_planet', (-175, -30, 55), 30, 1, dict(type='spin', speed=1.2)),
             item('space_station', (40, -8, 120), 0, 1, dict(type='spin', speed=5)),
             item('space_derelict', (-30, 9, 40), 40, 1,
                  dict(type='drift', vel=-3.0, min=-80, max=120, spin=4, tumble=2))]
    rnd = random.Random(5)
    for i in range(14):
        side = -1 if i % 2 == 0 else 1
        x = side * rnd.uniform(9, 42)
        y = rnd.uniform(-16, 14)
        z = rnd.uniform(-70, 100)
        mid = 'space_asteroid_b' if i % 4 == 1 else 'space_asteroid_a'
        sc = rnd.uniform(0.35, 1.1) if abs(x) < 18 else rnd.uniform(0.6, 1.6)
        items.append(item(mid, (x, y, z), rnd.uniform(0, 360), sc,
                          dict(type='drift', vel=-rnd.uniform(7, 13), min=-70, max=100,
                               spin=rnd.uniform(-20, 20), tumble=rnd.uniform(-15, 15))))
    for z in (20, 70):
        items.append(item('space_beacon', (-6.5, -2.2, z), 90, 1,
                          dict(type='drift', vel=-10, min=-60, max=90, spin=0, tumble=0)))
    return dict(
        id='cruise', name='星际航行', hint='公路旅行的“开车”环节：飞船沿航线前进，岩块与信标从身边掠过，海贼在后方追击。',
        hud='cruise',
        env=dict(bg=[0.05, 0.06, 0.15], ambient=[0.32, 0.30, 0.45], fog=[220, 900],
                 key=dict(dir=[-0.5, -0.6, 0.6], color=[1.0, 0.92, 0.82], brightness=1.15),
                 fill=dict(dir=[0.6, -0.2, -0.7], color=[0.45, 0.6, 1.0], brightness=0.45),
                 shadows=False, bloom=dict(threshold=0.55, mix=0.9)),
        camera=dict(target=[0, 1.0, -0.8], yaw=74, pitch=14, dist=17.5, fov=45,
                    minDist=8, maxDist=30, minPitch=-10, maxPitch=60, autoRotate=0),
        stars=dict(data=stars(17, 520, 170, 300, 0.9), colors=STAR_COLORS),
        items=items)


def scene_landing(ground):
    G = ground.h
    def at(model, x, z, yaw=0, scale=1, anim=None, dy=0.0):
        return item(model, (x, G(x, z) + dy, z), yaw, scale, anim)
    items = [item('env_landing_ground', (0, 0, 0)),
             item('env_landing_pad', (6.5, 0, 5.25)),
             item('ship_stardust', (6.5, 0.5, 5.25), -150, 1, dict(type='bob', amp=0.04, speed=0.4, phase=0))]
    # 前哨站：墙、门、天线、太阳能板、控制台
    items += [item('env_wall', (3.6, 0, -7.0)), item('env_door', (6.6, 0, -7.0)), item('env_wall', (9.6, 0, -7.0)),
              item('env_wall', (10.6, 0, -4.2), 90), item('env_antenna', (10.2, 0, -1.2), -40),
              item('env_solar', (3.4, 0, -5.2), 20), item('env_solar', (5.2, 0, -5.4), 20),
              item('prop_console', (8.4, 0, -5.9), 0),
              item('prop_cargo_container', (9.5, 0, 0.2), 90),
              item('prop_supply_crate', (7.4, 0, -3.6), 10), item('prop_supply_crate', (8.4, 0, -3.3), -15),
              item('prop_supply_crate', (7.9, 0.8, -3.45), 30),
              item('prop_fuel_canister', (3.2, 0, -2.6)), item('prop_fuel_canister', (3.8, 0, -2.9)),
              item('prop_ammo_box', (5.0, 0, -1.6), 25), item('prop_medkit', (5.8, 0, -1.9), -10),
              item('prop_turret', (2.7, 0, -0.4), -90, 1, dict(type='sway', amp=35, speed=0.18, phase=0))]
    # 队伍：朝 -X（敌人方向）
    items += [at('char_captain', 1.4, 1.7, -100, 1, dict(type='idle', amp=0.03, speed=0.9, sway=5, phase=0.0)),
              at('char_xingli', 0.2, 0.0, -80, 1, dict(type='idle', amp=0.03, speed=1.1, sway=8, phase=0.7)),
              at('char_chiyan', -1.4, 1.5, -95, 1, dict(type='idle', amp=0.04, speed=1.4, sway=6, phase=1.3)),
              at('char_yuexi', 2.0, -1.4, -110, 1, dict(type='idle', amp=0.05, speed=0.8, sway=10, phase=2.1)),
              at('char_hupo', 3.4, 0.5, -60, 1, dict(type='idle', amp=0.03, speed=1.0, sway=12, phase=2.8))]
    # 敌人：从右侧（-X）逼近
    def walk(model, a, b, speed, phase, yaw_hint=90):
        pa = (a[0], G(a[0], a[1]), a[1]); pb = (b[0], G(b[0], b[1]), b[1])
        return item(model, pa, yaw_hint, 1, dict(type='walk', to=r3(pb), speed=speed, phase=phase))
    items += [walk('enemy_pirate_grunt', (-7.5, 0.6), (-4.6, 0.9), 0.12, 0.0),
              walk('enemy_pirate_grunt', (-8.4, 2.6), (-5.4, 2.2), 0.10, 0.6),
              walk('enemy_pirate_grunt', (-6.8, -2.6), (-4.2, -1.8), 0.11, 1.2),
              at('enemy_pirate_heavy', -8.8, -0.9, 85, 1, dict(type='idle', amp=0.02, speed=0.5, sway=4, phase=0.4)),
              walk('enemy_crystal_crawler', (-9.5, 4.8), (-3.6, 3.4), 0.16, 0.2),
              walk('enemy_crystal_crawler', (-10.0, 6.4), (-5.0, 5.6), 0.13, 1.5),
              walk('enemy_crystal_crawler', (-8.0, -5.6), (-3.8, -3.6), 0.15, 0.9),
              at('enemy_crystal_brute', -9.8, -5.0, 60, 1, dict(type='idle', amp=0.05, speed=0.35, sway=6, phase=0.2))]
    # 资源与装饰
    items += [at('prop_meteor_shard', -7.0, 4.3, 0, 1, dict(type='spin', speed=40, amp=0.12, lift=0.25)),
              at('env_crystal_cluster', -9.0, 6.6, 20, 1.3, dict(type='pulse', amp=0.03, speed=0.6, phase=0)),
              at('env_crystal_cluster', -5.6, 7.2, -40, 0.9, dict(type='pulse', amp=0.04, speed=0.7, phase=1)),
              at('env_crystal_cluster', -10.4, 2.0, 70, 0.8, dict(type='pulse', amp=0.04, speed=0.5, phase=2)),
              at('prop_scrap_pile', -3.2, -5.6, 30), at('prop_scrap_pile', -1.0, 6.8, -20, 0.8),
              at('prop_supply_crate', -2.4, -6.6, 40)]
    return dict(
        id='landing', name='着陆搜刮', hint='公路旅行的“下车搜刮”环节：队员在前哨站周围搜集物资，海贼和晶化生物从右侧逼近，要在被包围前撤回飞船。',
        hud='landing',
        env=dict(bg=[0.07, 0.07, 0.17], ambient=[0.36, 0.33, 0.5], fog=[120, 600],
                 key=dict(dir=[0.45, -0.85, -0.35], color=[1.0, 0.93, 0.85], brightness=1.25),
                 fill=dict(dir=[-0.6, -0.4, 0.7], color=[0.45, 0.55, 1.0], brightness=0.35),
                 shadows=True, bloom=dict(threshold=0.6, mix=0.8)),
        camera=dict(target=[-0.8, 0, 2.8], yaw=6, pitch=52, dist=27, fov=40,
                    minDist=10, maxDist=40, minPitch=25, maxPitch=82, autoRotate=0),
        stars=dict(data=stars(23, 380, 140, 220, 0.8), colors=STAR_COLORS),
        items=items)


def scene_summon():
    items = []
    for ix in range(-3, 3):
        for iz in range(-3, 2):
            items.append(item('env_deck_tile', (ix * 2 + 1, -0.25, iz * 2 + 1)))
    items += [item('prop_summon_altar', (0, 0, 0)),
              item('char_yuexi', (0, 0.42, 0.55), 0, 1, dict(type='bob', amp=0.07, speed=0.45, phase=0)),
              item('env_wall', (-3.0, 0, -4.6)), item('env_door', (0, 0, -4.6)), item('env_wall', (3.0, 0, -4.6)),
              item('env_crystal_cluster', (-3.6, 0, -2.6), 30, 1.1, dict(type='pulse', amp=0.04, speed=0.5, phase=0)),
              item('env_crystal_cluster', (3.8, 0, -2.2), -50, 0.9, dict(type='pulse', amp=0.04, speed=0.6, phase=1)),
              item('prop_console', (-3.2, 0, 0.8), 60),
              item('prop_meteor_shard', (2.6, 0.9, 1.0), 0, 1, dict(type='spin', speed=50, amp=0.1, lift=0.0)),
              item('prop_meteor_shard', (3.4, 0.7, 0.2), 0, 0.8, dict(type='spin', speed=-40, amp=0.1, lift=0.0)),
              item('prop_cargo_container', (4.6, 0, 2.0), 30, 0.8),
              item('char_captain', (-2.7, 0, 1.0), 140, 1, dict(type='idle', amp=0.02, speed=0.8, sway=4, phase=0)),
              item('char_xingli', (2.5, 0, 1.3), -150, 1, dict(type='idle', amp=0.03, speed=1.0, sway=6, phase=1))]
    return dict(
        id='summon', name='星门召唤', hint='消耗陨石碎片在星门召唤台召唤伙伴。新伙伴悬浮在晶体前登场。',
        hud='summon',
        env=dict(bg=[0.05, 0.05, 0.12], ambient=[0.30, 0.30, 0.48], fog=[18, 45],
                 key=dict(dir=[0.35, -0.8, -0.5], color=[0.9, 0.95, 1.0], brightness=0.95),
                 fill=dict(dir=[-0.4, -0.3, 0.85], color=[0.36, 0.95, 0.86], brightness=0.5),
                 shadows=True, bloom=dict(threshold=0.5, mix=1.1)),
        camera=dict(target=[-1.3, 1.2, 0.2], yaw=10, pitch=16, dist=9.6, fov=42,
                    minDist=4, maxDist=16, minPitch=0, maxPitch=70, autoRotate=0),
        stars=None, items=items)


GALLERY_ENV = dict(bg=[0.07, 0.08, 0.19], ambient=[0.4, 0.38, 0.52], fog=[200, 400],
                   key=dict(dir=[-0.45, -0.75, -0.5], color=[1.0, 0.95, 0.88], brightness=1.2),
                   fill=dict(dir=[0.6, -0.3, 0.7], color=[0.5, 0.65, 1.0], brightness=0.45),
                   shadows=True, bloom=dict(threshold=0.6, mix=0.8))



# ---------------------------------------------------------------- 像素图标
B36 = '0123456789abcdefghijklmnopqrstuvwxyz'


def make_icon(m, maxdim=22):
    """从模型生成像素图标：伙伴/敌人/道具/场景件用正视图，飞船/星图用侧视图"""
    side = m.category in ('ship', 'space')
    cells = {}
    for (x, y, z), k in m.v.items():
        if side:
            col, depth = z, x
        else:
            col, depth = -x, z
        key = (col, y)
        if key not in cells or depth > cells[key][0]:
            cells[key] = (depth, k)
    cols = [c for c, _ in cells]; rows = [r for _, r in cells]
    c0, c1, r0, r1 = min(cols), max(cols), min(rows), max(rows)
    W, H = c1 - c0 + 1, r1 - r0 + 1
    f = max(1, math.ceil(max(W, H) / maxdim))
    w, h = math.ceil(W / f), math.ceil(H / f)
    pal = []; pidx = {}
    rows_out = []
    for j in range(h):
        line = ''
        for i in range(w):
            best = None
            for dj in range(f):
                for di in range(f):
                    c = c0 + i * f + di; r = r1 - (j * f + dj)
                    if (c, r) in cells and (best is None or cells[(c, r)][0] > best[0]):
                        best = cells[(c, r)]
            if best is None:
                line += '.'
            else:
                hx = m.pal[best[1]]['hex']
                if hx not in pidx:
                    pidx[hx] = len(pal); pal.append(hx)
                line += B36[pidx[hx]]
        rows_out.append(line)
    return dict(w=w, h=h, pal=pal, px=''.join(rows_out))


def pixel_icon(rows, colors):
    pal = []; pidx = {}; out = ''
    for line in rows:
        for ch in line:
            if ch == '.':
                out += '.'
            else:
                hx = colors[ch]
                if hx not in pidx:
                    pidx[hx] = len(pal); pal.append(hx)
                out += B36[pidx[hx]]
    return dict(w=len(rows[0]), h=len(rows), pal=pal, px=out)


RES_ICONS = {
    'fuel': pixel_icon(['..aa....', '.abba...', 'acccca..', 'acddca..', 'acddca..', 'acccca..', 'acccca..', '.aaaa...'],
                       {'a': '#7A1E10', 'b': '#9AA3B5', 'c': '#E2552F', 'd': '#7CF29A'}),
    'supply': pixel_icon(['........', 'aaaaaaa.', 'abbbbba.', 'accccca.', 'abbbbba.', 'abbbbba.', 'aaaaaaa.', '........'],
                         {'a': '#1F3554', 'b': '#5C7FA8', 'c': '#F5A524'}),
    'shard': pixel_icon(['...a....', '..aba...', '..abaa..', '.abbba..', '.abcba..', 'ddabadd.', 'dddaddd.', '.ddddd..'],
                        {'a': '#2E9FA6', 'b': '#5CF2DC', 'c': '#E0458C', 'd': '#3A3346'}),
    'credit': pixel_icon(['..aaaa..', '.abbbba.', 'abbcbbba', 'abcccbba', 'abbcbbba', 'abcccbba', '.abbbba.', '..aaaa..'],
                         {'a': '#9C6B12', 'b': '#E2B84A', 'c': '#FFF1B8'}),
}

HUD = dict(
    resources=[dict(id='fuel', name='燃料', value='62/100'), dict(id='supply', name='补给', value='18'),
               dict(id='shard', name='陨石碎片', value='7'), dict(id='credit', name='信用点', value='1240')],
    cruise=dict(route=['灰烬星港', '碎石带', '遗弃舰 K-7', '海贼前哨', '琥珀贸易站'], progress=1.45,
                speed='航速 42', distance='距下一站 3.1 光分',
                event=dict(title='后方出现海贼截击机', body='对方正在逼近，约 20 秒后进入射程。',
                           actions=[dict(text='加速甩开', note='燃料 -8', primary=True),
                                    dict(text='停船迎战', note='进入战斗', primary=False)])),
    landing=dict(place='遗弃前哨', timer='撤离窗口 01:24', loot='物资 3 / 8', threat='威胁 高',
                 crew=[dict(model='char_captain', name='罗汉', role='舰长', hp=0.82, skill=0.4),
                       dict(model='char_xingli', name='星璃', role='枪手', hp=0.64, skill=1.0),
                       dict(model='char_chiyan', name='赤焰', role='重装', hp=0.91, skill=0.25),
                       dict(model='char_yuexi', name='月汐', role='医疗', hp=1.0, skill=0.7),
                       dict(model='char_hupo', name='琥珀', role='工程师', hp=0.47, skill=0.9)],
                 action='全员撤回飞船'),
    summon=dict(hero='char_yuexi', title='召唤成功', name='月汐', role='医疗', rarity='稀有',
                line='伤口交给我，你们只管往前冲。',
                stats=[dict(name='生命', v=0.6), dict(name='治疗', v=0.95), dict(name='攻击', v=0.3), dict(name='速度', v=0.55)],
                cost='消耗 5 碎片', action='再召唤一次'),
)


# ---------------------------------------------------------------- 导出
def export(built):
    out_models = os.path.join(ROOT, 'scripts', 'voxeldata', 'models')
    out_vox = os.path.join(ROOT, 'source_art', 'vox')
    out_prev = os.path.join(ROOT, 'preview', 'data')
    for d in (out_models, out_vox, out_prev):
        os.makedirs(d, exist_ok=True)

    js_models = {}
    catalog = []
    total_q = 0
    for mid, (m, b) in built.items():
        mats_lua = []
        mats_js = []
        for mt in b['mats']:
            mats_lua.append(dict(color=mt['color'], metallic=mt['metallic'], roughness=mt['roughness'],
                                 emissive=mt['emissive'], quads=[int(q) for q in mt['quads']]))
            mats_js.append(dict(c=mt['color'], m=mt['metallic'], r=mt['roughness'], e=mt['emissive'],
                                q=[int(q) for q in mt['quads']]))
        info = dict(id=mid, name=b['name'], category=b['category'], desc=b['desc'], scale=b['scale'],
                    size=b['size'], origin=[round(o, 3) for o in b['origin']], voxels=b['voxels'],
                    quadCount=b['quadCount'])
        lua = dict(info); lua['mats'] = mats_lua
        with open(os.path.join(out_models, mid + '.lua'), 'w', encoding='utf-8') as f:
            f.write('-- 由 tools/build_voxels.py 自动生成，请勿手改。修改模型请编辑 tools/models_*.py 后重新构建。\n')
            f.write('-- 四边形编码：face, p, u0, v0, u1, v1（face = 轴*2 + 方向，u=(轴+1)%3, v=(轴+2)%3）\n')
            f.write('return ' + lua_value(lua) + '\n')
        js = dict(info); js['mats'] = mats_js
        js_models[mid] = js
        write_vox(os.path.join(out_vox, mid + '.vox'), b)
        total_q += b['quadCount']
        if b['category'] not in ('system', 'fx'):
            catalog.append(dict(id=mid, name=b['name'], category=b['category'], desc=b['desc'],
                                size=r3([s * b['scale'] for s in b['size']]), voxels=b['voxels'],
                                palette=[mt['hex'] for mt in b['mats']], icon=make_icon(m)))

    # 机甲分件（仅 HTML 版使用）：头 / 双臂 / 大腿 / 小腿 / 躯干，共用整机原点；rig 为关节、枪口、喷口挂点（米，模型局部坐标）
    PART_NAMES = ['body', 'head', 'uarmL', 'uarmR', 'armL', 'armR', 'thighL', 'thighR', 'shinL', 'shinR']
    def to_local(v, mn, origin, sc):
        if isinstance(v[0], (list, tuple)): return [to_local(p, mn, origin, sc) for p in v]
        return [round((v[i] - mn[i] - origin[i]) * sc, 4) for i in range(3)]
    rigs_lua = {}
    for mid, (m, b) in list(built.items()):
        if not mid.startswith('mech_'): continue
        parts, full, mn = build_parts(m, PART_NAMES)
        for name, pb in parts.items():
            js_models[mid + '__' + name] = dict(id=pb['id'], name=pb['name'], category='part', desc='', scale=pb['scale'], size=pb['size'],
                origin=[round(o, 3) for o in pb['origin']], voxels=pb['voxels'], quadCount=pb['quadCount'],
                mats=[dict(c=mt['color'], m=mt['metallic'], r=mt['roughness'], e=mt['emissive'], q=[int(q) for q in mt['quads']]) for mt in pb['mats']])
        js_models[mid]['parts'] = list(parts.keys())
        # UrhoX（Lua）版同样需要分件模型：与整机共用原点，写成 mech_xxx__部件.lua，并把关节 / 枪口 / 喷口挂点写入 Rigs.lua
        for name, pb in parts.items():
            lp = dict(id=pb['id'], name=pb['name'], category='part', desc='', scale=pb['scale'], size=pb['size'], origin=[round(o, 3) for o in pb['origin']],
                      voxels=pb['voxels'], quadCount=pb['quadCount'],
                      mats=[dict(color=mt['color'], metallic=mt['metallic'], roughness=mt['roughness'], emissive=mt['emissive'], quads=[int(q) for q in mt['quads']]) for mt in pb['mats']])
            with open(os.path.join(out_models, pb['id'] + '.lua'), 'w', encoding='utf-8') as f:
                f.write('-- 由 tools/build_voxels.py 自动生成：机甲分件（与整机共用原点）\nreturn ' + lua_value(lp) + '\n')
        js_models[mid]['rig'] = {k: to_local(v, mn, full['origin'], full['scale']) for k, v in m.rig.items()}
        rigs_lua[mid] = {k: v for k, v in js_models[mid]['rig'].items()} | {'parts': list(parts.keys())}

    with open(os.path.join(ROOT, 'scripts', 'voxeldata', 'Rigs.lua'), 'w', encoding='utf-8') as f:
        f.write('-- 由 tools/build_voxels.py 自动生成：机甲关节 / 枪口 / 喷口挂点（米，模型局部坐标，与整机同原点）\nreturn ' + lua_value(rigs_lua) + '\n')
    ground_m, ground_b = built['env_landing_ground']
    ground = Ground(ground_m, ground_b)
    scenes = [scene_cruise(), scene_landing(ground), scene_summon()]

    cat_order = {c: i for i, (c, _) in enumerate(CATEGORIES)}
    catalog.sort(key=lambda c: cat_order[c['category']])
    catalog_doc = dict(categories=[dict(id=c, name=n) for c, n in CATEGORIES], items=catalog)

    with open(os.path.join(ROOT, 'scripts', 'voxeldata', 'Catalog.lua'), 'w', encoding='utf-8') as f:
        f.write('-- 由 tools/build_voxels.py 自动生成：图鉴目录\nreturn ' + lua_value(catalog_doc) + '\n')
    scenes_doc = dict(gallery=dict(env=GALLERY_ENV), list=scenes, hud=HUD, resIcons=RES_ICONS)
    with open(os.path.join(ROOT, 'scripts', 'voxeldata', 'Scenes.lua'), 'w', encoding='utf-8') as f:
        f.write('-- 由 tools/build_voxels.py 自动生成：预览场景布局（与 HTML 预览共用同一份数据）\nreturn '
                + lua_value(scenes_doc) + '\n')

    with open(os.path.join(out_prev, 'assets.js'), 'w', encoding='utf-8') as f:
        f.write('// 由 tools/build_voxels.py 自动生成\n')
        f.write('window.VOX_MODELS=' + json.dumps(js_models, ensure_ascii=False, separators=(',', ':')) + ';\n')
        f.write('window.VOX_CATALOG=' + json.dumps(catalog_doc, ensure_ascii=False, separators=(',', ':')) + ';\n')
        f.write('window.VOX_SCENES=' + json.dumps(scenes_doc, ensure_ascii=False, separators=(',', ':')) + ';\n')
    with open(os.path.join(ROOT, 'scripts', 'voxeldata', 'GameData.lua'), 'w', encoding='utf-8') as f:
        f.write('-- 由 tools/build_voxels.py 自动生成：玩法数据（星系、商品、飞船、敌人、舰员、任务）\nreturn ' + lua_value(GAME) + '\n')
    with open(os.path.join(out_prev, 'assets.js'), 'a', encoding='utf-8') as f:
        f.write('window.GAME_DATA=' + json.dumps(GAME, ensure_ascii=False, separators=(',', ':')) + ';\n')
    print('models:', len(built), 'catalog:', len(catalog), 'total quads:', total_q)


if __name__ == '__main__':
    export(build_all())
