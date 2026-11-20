# -*- coding: utf-8 -*-
"""陨星银河 · 玩法数据（Lua 与 HTML 共用）。数值单位：米、米/秒、度/秒、秒。"""
import math, random

GOODS = [
    dict(id='food', name='食物', base=24, desc='罐头与营养膏，矿区永远缺。'),
    dict(id='ore', name='矿石', base=40, desc='富矿小行星里采出的金属矿。'),
    dict(id='parts', name='零件', base=70, desc='飞船维修零件，星港工坊大量收购。'),
    dict(id='medicine', name='医疗品', base=95, desc='抗辐射药剂，前哨站的刚需。'),
    dict(id='luxury', name='奢侈品', base=180, desc='赤环星系出产的晶石饰品，灰烬星港的富人很喜欢。'),
]

SHIPS = [
    dict(id='ship_stardust', name='星尘号', price=0, hull=100, shield=60, speed=70, turn=70, cargo=20, guns=1, missiles=2,
         desc='退役货运艇，什么都能干一点。'),
    dict(id='ship_firefly', name='流萤号', price=12000, hull=80, shield=80, speed=115, turn=95, cargo=10, guns=1, missiles=2,
         desc='高速快艇，甩开海贼的首选。'),
    dict(id='ship_anvil', name='铁砧号', price=22000, hull=280, shield=110, speed=55, turn=50, cargo=60, guns=2, missiles=3,
         desc='重型货舰，跑商赚钱最快。'),
    dict(id='ship_redhawk', name='赤隼号', price=28000, hull=150, shield=130, speed=95, turn=85, cargo=12, guns=2, missiles=4,
         desc='中型战斗机，对抗海贼的主力。'),
]

LASERS = [dict(id='laser1', name='脉冲激光 Mk1', price=0, dmg=6, rof=6),
          dict(id='laser2', name='脉冲激光 Mk2', price=5000, dmg=10, rof=6),
          dict(id='laser3', name='晶能激光 Mk3', price=14000, dmg=16, rof=7)]
SHIELDS = [dict(id='shield1', name='护盾发生器 Mk1', price=0, mult=1.0, regen=4),
           dict(id='shield2', name='护盾发生器 Mk2', price=6000, mult=1.5, regen=7),
           dict(id='shield3', name='晶能护盾 Mk3', price=15000, mult=2.0, regen=11)]
MISSILE = dict(price=350, dmg=60, speed=220, turn=140)

ENEMIES = [
    dict(id='ship_pirate_interceptor', name='海贼截击机', hull=40, shield=20, speed=85, turn=80, dmg=4, rof=3, range=420, bounty=300),
    dict(id='ship_pirate_gunship', name='海贼炮舰', hull=160, shield=60, speed=50, turn=45, dmg=7, rof=3, range=500, bounty=900),
    dict(id='ship_pirate_flagship', name='赤髑号', hull=900, shield=300, speed=40, turn=30, dmg=10, rof=5, range=650, bounty=8000, boss=True),
]

CREW = [
    dict(id='char_xingli', name='星璃', role='枪手', buff='激光伤害 +25%', fx=dict(laserDmg=0.25)),
    dict(id='char_chiyan', name='赤焰', role='重装', buff='船体上限 +30%', fx=dict(hull=0.3)),
    dict(id='char_yuexi', name='月汐', role='医疗', buff='护盾回复 +50%，停靠时免费修理', fx=dict(shieldRegen=0.5, freeRepair=1)),
    dict(id='char_hupo', name='琥珀', role='工程师', buff='采矿产量翻倍，货舱 +10', fx=dict(mining=1.0, cargo=10)),
    dict(id='char_yeyuan', name='夜鸢', role='领航员', buff='雷达范围 +50%，跃迁后护盾充满', fx=dict(radar=0.5, jumpShield=1)),
    dict(id='char_shuangling', name='霜铃', role='导弹手', buff='导弹 +2，导弹伤害 +40%', fx=dict(missiles=2, missileDmg=0.4)),
]
SUMMON_COST = 5

START = dict(system='ashfall', credits=1500, shards=3, ship='ship_stardust', crew=['char_xingli'],
             cargo=dict(), laser='laser1', shieldGen='shield1')

# 主线任务（按顺序解锁）
STORY = [
    dict(id='story1', title='第一单生意', giver='ashfall',
         text='把 5 箱零件送到碎石带的晶矿前哨。听说那边的老板手里有陨石碎片的线索。',
         kind='deliver', good='parts', count=5, target='rubble', reward=1500, shards=2, provide=True),
    dict(id='story2', title='碎石带的海贼', giver='rubble',
         text='星海贼团在碎石带拦截矿船。击落 4 艘海贼船，让矿工们能安心出港。',
         kind='bounty', system='rubble', count=4, reward=3000, shards=3),
    dict(id='story3', title='赤髑的巢穴', giver='rubble',
         text='海贼首领赤髑躲在赤环星系的要塞里，正在收集陨石碎片唤醒天殒核心。击沉他的旗舰赤髑号。',
         kind='boss', system='redring', reward=10000, shards=5),
]


def asteroid_field(seed, center, radius, count, models, scale_rng, flat=0.35):
    rnd = random.Random(seed)
    out = []
    for _ in range(count):
        while True:
            x, y, z = rnd.uniform(-1, 1), rnd.uniform(-1, 1) * flat, rnd.uniform(-1, 1)
            if x * x + (y / flat) ** 2 * flat + z * z <= 1:
                break
        out.append(dict(model=rnd.choice(models), pos=[round(center[0] + x * radius, 1), round(center[1] + y * radius, 1),
                                                         round(center[2] + z * radius, 1)],
                        yaw=round(rnd.uniform(0, 360), 1), pitch=round(rnd.uniform(0, 360), 1),
                        scale=round(rnd.uniform(*scale_rng), 2), spin=round(rnd.uniform(-12, 12), 1)))
    return out


STAR_COLORS = [[0.92, 0.93, 1.0], [0.55, 0.95, 0.9], [1.0, 0.8, 0.5]]


def stars(seed, count):
    rnd = random.Random(seed)
    out = []
    for _ in range(count):
        while True:
            x, y, z = rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1)
            l = math.sqrt(x * x + y * y + z * z)
            if 0.2 < l <= 1:
                break
        r = rnd.uniform(3000, 3600)
        out += [round(x / l * r, 1), round(y / l * r, 1), round(z / l * r, 1), round(rnd.uniform(6, 16), 1),
                rnd.choices([0, 1, 2], weights=[7, 2, 1])[0]]
    return out


SYSTEMS = [
    dict(id='ashfall', name='灰烬星系', desc='天殒坠落时最先被波及的星系，如今是银河边缘最大的货运枢纽。', danger='低',
         map=[0, 0],
         env=dict(bg=[0.05, 0.06, 0.15], ambient=[0.32, 0.30, 0.45],
                  key=dict(dir=[-0.5, -0.45, 0.75], color=[1.0, 0.9, 0.78], brightness=1.2),
                  fill=dict(dir=[0.6, -0.2, -0.7], color=[0.45, 0.6, 1.0], brightness=0.4), bloom=dict(threshold=0.55, mix=0.9)),
         decor=[dict(model='space_planet', pos=[-2600, -700, 3800], yaw=30, scale=14, spin=0.6)],
         stations=[dict(id='ashfall', name='灰烬星港', model='space_station', pos=[0, 0, 700], scale=3.0,
                        prices=dict(food=0.7, ore=1.3, parts=1.1, medicine=0.8, luxury=1.25))],
         gates=[dict(to='rubble', name='星门：碎石带', pos=[1900, 120, -900], yaw=-60)],
         asteroids=asteroid_field(11, [-900, 0, -500], 420, 36, ['space_asteroid_a', 'space_asteroid_a', 'space_asteroid_b'], (1.0, 3.5)),
         ore=asteroid_field(12, [-900, 0, -500], 380, 10, ['space_ore_asteroid'], (1.4, 2.2)),
         derelicts=[dict(model='space_derelict', pos=[700, -150, -1500], yaw=20, scale=3.0)],
         pirates=dict(max=2, types=['ship_pirate_interceptor'], spawns=[[600, 0, -1400], [-1400, 100, 300]]),
         spawn=dict(pos=[0, 0, 560], yaw=180)),
    dict(id='rubble', name='碎石带', desc='天殒碎片最密集的小行星带，矿工与海贼混居。', danger='中',
         map=[1, -0.4],
         env=dict(bg=[0.06, 0.05, 0.12], ambient=[0.34, 0.30, 0.42],
                  key=dict(dir=[0.4, -0.5, 0.75], color=[1.0, 0.85, 0.7], brightness=1.15),
                  fill=dict(dir=[-0.6, -0.2, -0.7], color=[0.5, 0.9, 0.85], brightness=0.45), bloom=dict(threshold=0.5, mix=1.0)),
         decor=[dict(model='space_planet', pos=[3200, 900, 2600], yaw=120, scale=9, spin=0.4)],
         stations=[dict(id='rubble', name='晶矿前哨', model='space_station', pos=[0, 0, 0], scale=2.6,
                        prices=dict(food=1.5, ore=0.6, parts=0.85, medicine=1.4, luxury=1.1))],
         gates=[dict(to='ashfall', name='星门：灰烬星系', pos=[-1700, 0, 700], yaw=60),
                dict(to='redring', name='星门：赤环星系', pos=[1800, -80, 1300], yaw=-120)],
         asteroids=asteroid_field(21, [300, 0, -700], 750, 80, ['space_asteroid_a', 'space_asteroid_b', 'space_asteroid_a'], (1.0, 4.0)),
         ore=asteroid_field(22, [300, 0, -700], 650, 24, ['space_ore_asteroid'], (1.4, 2.4)),
         derelicts=[dict(model='space_derelict', pos=[-700, 120, -900], yaw=-30, scale=3.5)],
         pirates=dict(max=4, types=['ship_pirate_interceptor', 'ship_pirate_interceptor', 'ship_pirate_gunship'],
                      spawns=[[900, 50, -1300], [-600, -80, -1500], [1300, 0, 300]]),
         spawn=dict(pos=[0, 0, 160], yaw=0)),
    dict(id='redring', name='赤环星系', desc='星海贼团盘踞的星系，红色星环下藏着赤髑的要塞。', danger='高',
         map=[2, 0.1],
         env=dict(bg=[0.09, 0.04, 0.08], ambient=[0.38, 0.28, 0.36],
                  key=dict(dir=[-0.3, -0.55, -0.8], color=[1.0, 0.75, 0.6], brightness=1.25),
                  fill=dict(dir=[0.6, -0.2, 0.7], color=[0.9, 0.4, 0.6], brightness=0.45), bloom=dict(threshold=0.5, mix=1.0)),
         decor=[dict(model='space_planet', pos=[-1800, -1200, -3600], yaw=-20, scale=22, spin=0.3)],
         stations=[dict(id='redring', name='琥珀贸易站', model='space_station', pos=[-1200, 0, -300], scale=3.0,
                        prices=dict(food=1.2, ore=1.15, parts=1.4, medicine=1.1, luxury=0.65))],
         gates=[dict(to='rubble', name='星门：碎石带', pos=[-200, 60, 1700], yaw=180)],
         asteroids=asteroid_field(31, [900, -50, 900], 600, 46, ['space_asteroid_a', 'space_asteroid_a', 'space_asteroid_b'], (1.0, 3.5)),
         ore=asteroid_field(32, [900, -50, 900], 500, 10, ['space_ore_asteroid'], (1.4, 2.2)),
         derelicts=[],
         base=dict(model='space_pirate_base', name='赤髑巢', pos=[1700, -100, 1700], scale=5.0),
         pirates=dict(max=5, types=['ship_pirate_interceptor', 'ship_pirate_interceptor', 'ship_pirate_gunship'],
                      spawns=[[1500, 0, 1300], [1300, 100, 2000], [300, 0, 1200]]),
         boss=dict(type='ship_pirate_flagship', pos=[1600, 60, 1350], story='story3'),
         spawn=dict(pos=[-200, 60, 1550], yaw=180)),
]

for s in SYSTEMS:
    s['stars'] = dict(data=stars(sum(map(ord, s['id'])) + 3, 420), colors=STAR_COLORS)


GAME = dict(goods=GOODS, ships=SHIPS, lasers=LASERS, shields=SHIELDS, missile=MISSILE, enemies=ENEMIES,
            crew=CREW, summonCost=SUMMON_COST, start=START, story=STORY, systems=SYSTEMS,
            tuning=dict(laserSpeed=650, laserLife=1.3, enemyLaserSpeed=420, aimAssistDeg=15, aimAssistRange=900,
                        dockRange=170, gateRange=140, pickupRange=30, magnetRange=110, boostMult=1.8, boostDrain=25,
                        boostRegen=12, shieldDelay=3.0, respawnDelay=50, radarRange=1600, repairCostPerHp=12))
