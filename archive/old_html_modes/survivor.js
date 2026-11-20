/* 陨星银河 · 星海突围（割草模式）
 * 一局 8 分钟：拖动移动、自动开火、拾取能量三选一升级，两位星魂少女随行释放技能，8 分钟首领赤髑号。
 * 依赖：VoxEngine（渲染）与 __game.api（存档、图标、布局）。
 */
(function () {
  'use strict';
  var E = window.VoxEngine;
  if (!E) return;
  var DEG = Math.PI / 180, RUN_TIME = 480;
  var G, A, view;
  function rand(a, b) { return a + Math.random() * (b - a); }
  function clamp(x, a, b) { return x < a ? a : x > b ? b : x; }
  function lerp(a, b, t) { return a + (b - a) * t; }
  function d2(ax, az, bx, bz) { var dx = ax - bx, dz = az - bz; return dx * dx + dz * dz; }
  function pick(list) { return list[Math.floor(Math.random() * list.length)]; }
  function mmss(t) { t = Math.max(0, Math.floor(t)); return (t / 60 < 10 ? '0' : '') + Math.floor(t / 60) + ':' + (t % 60 < 10 ? '0' : '') + (t % 60); }

  // ------------------------------------------------------------------ 数据
  var ENEMY = {
    crawler: { name: '晶化爬虫', model: 'enemy_crystal_crawler', scale: 3, hp: 12, spd: 9.5, dmg: 6, xp: 1 },
    grunt: { name: '海贼喽啰', model: 'enemy_pirate_grunt', scale: 2.6, hp: 24, spd: 7.2, dmg: 8, xp: 2, float: true },
    inter: { name: '海贼截击机', model: 'ship_pirate_interceptor', scale: 0.9, hp: 30, spd: 11, dmg: 7, xp: 3, keep: 22, shoot: { cd: 3.2, spd: 20, dmg: 6, n: 1, spread: 0 } },
    heavy: { name: '海贼重炮手', model: 'enemy_pirate_heavy', scale: 3, hp: 85, spd: 4.5, dmg: 12, xp: 6, shoot: { cd: 4, spd: 16, dmg: 7, n: 3, spread: 22 } },
    brute: { name: '晶核巨兽', model: 'enemy_crystal_brute', scale: 3.4, hp: 650, spd: 5, dmg: 22, xp: 40, elite: true },
    gunship: { name: '海贼炮舰', model: 'ship_pirate_gunship', scale: 1.2, hp: 950, spd: 4, dmg: 20, xp: 60, elite: true, keep: 28, shoot: { cd: 2.2, spd: 18, dmg: 9, n: 5, spread: 50 } },
    boss: { name: '赤髑号', model: 'ship_pirate_flagship', scale: 1.5, hp: 7000, spd: 3.2, dmg: 30, xp: 0, boss: true, keep: 30, shoot: { cd: 3.4, spd: 15, dmg: 10, ring: 20 } }
  };
  var EVENTS = [
    { t: 90, ring: 'crawler', n: 36 }, { t: 150, ring: 'grunt', n: 24 }, { t: 240, elite: 'brute', msg: '精英来袭：晶核巨兽' },
    { t: 270, ring: 'crawler', n: 50 }, { t: 360, elite: 'gunship', msg: '精英来袭：海贼炮舰' }, { t: 390, ring: 'inter', n: 18 },
    { t: 420, ring: 'crawler', n: 60 }, { t: 450, msg: '警告：赤髑号正在接近' }, { t: RUN_TIME, boss: true, msg: '首领出现：赤髑号' }
  ];
  // 武器与被动：每级数值表
  var UPG = {
    laser: { kind: 'weapon', name: '脉冲激光', max: 6, desc: ['自动射击最近的敌人', '伤害 +30%', '弹道 +1', '射速 +30%', '弹道 +1，穿透 +1', '伤害 +40%，穿透 +1'],
      dmg: [12, 16, 16, 16, 16, 22], n: [1, 1, 2, 2, 3, 3], cd: [0.42, 0.42, 0.42, 0.32, 0.32, 0.32], pierce: [0, 0, 0, 0, 1, 2] },
    missile: { kind: 'weapon', name: '追踪导弹', max: 5, desc: ['定时发射追踪导弹，命中后爆炸', '导弹 +1', '伤害 +40%', '导弹 +1', '冷却 -30%'],
      dmg: [25, 25, 35, 35, 35], n: [1, 2, 2, 3, 3], cd: [2.4, 2.4, 2.4, 2.4, 1.7] },
    nova: { kind: 'weapon', name: '护盾脉冲', max: 5, desc: ['定时释放冲击波，击退周围敌人', '伤害 +50%', '范围 +30%，冷却 -15%', '伤害 +35%', '范围 +25%，伤害 +30%'],
      dmg: [15, 22, 22, 30, 40], r: [9, 9, 12, 12, 15], cd: [3, 3, 2.6, 2.6, 2.6] },
    blades: { kind: 'weapon', name: '晶刃环', max: 5, desc: ['陨石晶刃环绕飞船，切割接触的敌人', '晶刃 +1', '伤害 +50%', '晶刃 +1', '晶刃 +1，伤害 +35%'],
      dmg: [8, 8, 12, 12, 16], n: [2, 3, 3, 4, 5] },
    hull: { kind: 'passive', name: '船体强化', max: 5, desc: ['船体上限 +25，并立即修复 25'] },
    engine: { kind: 'passive', name: '引擎超频', max: 5, desc: ['移动速度 +8%'] },
    magnet: { kind: 'passive', name: '引力收集器', max: 5, desc: ['拾取范围 +35%'] },
    power: { kind: 'passive', name: '火控核心', max: 5, desc: ['所有伤害 +10%'] },
    cooling: { kind: 'passive', name: '冷却回路', max: 5, desc: ['所有冷却 -7%'] },
    repair: { kind: 'passive', name: '纳米修复', max: 5, desc: ['每秒修复船体 +0.6'] }
  };
  // 舰员技能：伤害 = 基础 x (1 + 0.35 x (等级-1))，冷却 = 基础 x (1 - 0.1 x (等级-1))，范围 = 基础 x (1 + 0.15 x (等级-1))，5 级觉醒数量翻倍
  var CREW = {
    char_xingli: { skill: '狙击光束', cd: 2.5, dmg: 40, area: 1, desc: '每 2.5 秒射出穿透光束，优先打击最强的敌人', awake: '觉醒：同时射出 2 道光束',
      lines: ['锁定。', '别乱动，我在瞄准。', '目标清除。'] },
    char_chiyan: { skill: '烈焰冲锋', cd: 6, dmg: 60, area: 1, desc: '每 6 秒朝前方冲锋，撞飞沿途敌人', awake: '觉醒：连续冲锋 2 次',
      lines: ['让开让开！', '交给我正面！', '冲啊——'] },
    char_yuexi: { skill: '星愈光环', cd: 8, dmg: 12, area: 1, desc: '持续修复船体，每 8 秒释放一次治疗脉冲', awake: '觉醒：治疗脉冲同时伤害周围敌人',
      lines: ['伤口交给我。', '撑住，马上就好。', '大家都还在吧？'] },
    char_hupo: { skill: '速建炮塔', cd: 9, dmg: 10, area: 1, desc: '每 9 秒架设一座自动炮塔，持续 8 秒', awake: '觉醒：每次架设 2 座炮塔',
      lines: ['炮塔上线！', '这个我改过，威力翻倍。', '扳手才是正义。'] },
    char_yeyuan: { skill: '引力陷阱', cd: 7, dmg: 12, area: 1, desc: '每 7 秒在敌群中制造引力井，并扩大拾取范围', awake: '觉醒：同时制造 2 个引力井',
      lines: ['航线修正完毕。', '它们逃不掉的。', '跟着我的标记走。'] },
    char_shuangling: { skill: '冰霜导弹雨', cd: 5, dmg: 30, area: 1, desc: '每 5 秒召唤 6 枚导弹轰炸敌群', awake: '觉醒：导弹数量翻倍',
      lines: ['点火——发射！', '烟花时间到了！', '再来一轮？'] }
  };
  var PIX = function (rows, colors) {
    var pal = [], idx = {}, px = '', B = '0123456789abcdefghijklmnopqrstuvwxyz';
    rows.forEach(function (r) { for (var i = 0; i < r.length; i++) { var c = r[i]; if (c === '.') { px += '.'; continue; } if (!(c in idx)) { idx[c] = pal.length; pal.push(colors[c]); } px += B[idx[c]]; } });
    return { w: rows[0].length, h: rows.length, pal: pal, px: px };
  };
  var ICON = {
    laser: PIX(['........', '.......a', '.....aa.', '...bb...', '.bb.....', 'c.......', '........', '........'], { a: '#9DF7EC', b: '#5CF2DC', c: '#2E9FA6' }),
    missile: PIX(['...aa...', '..abba..', '..abba..', '..abba..', '..abba..', '.cabbac.', '.c.dd.c.', '...ee...'], { a: '#D6332A', b: '#E8E3D6', c: '#3E6E99', d: '#FFB347', e: '#FF7A3A' }),
    nova: PIX(['..aaaa..', '.a....a.', 'a..bb..a', 'a.bccb.a', 'a.bccb.a', 'a..bb..a', '.a....a.', '..aaaa..'], { a: '#57B8FF', b: '#9DF7EC', c: '#FFFFFF' }),
    blades: PIX(['...a....', '..ab....', '.....aa.', 'a..c..ba', 'ab..c..a', '.aa.....', '....ba..', '....a...'], { a: '#5CF2DC', b: '#9DF7EC', c: '#E0458C' }),
    hull: PIX(['.aaaaaa.', 'abbbbbba', 'abccccba', 'abccccba', 'abccccba', '.abccba.', '..abba..', '...aa...'], { a: '#3E5878', b: '#7CF29A', c: '#2E7A4A' }),
    engine: PIX(['..aaaa..', '.abbbba.', '.abbbba.', '..aaaa..', '...cc...', '..cddc..', '..cddc..', '...cc...'], { a: '#5A6175', b: '#9AA3B5', c: '#FF8A3A', d: '#FFE7A3' }),
    magnet: PIX(['aa....aa', 'aa....aa', 'bb....bb', 'bb....bb', 'bb....bb', '.bb..bb.', '..bbbb..', '........'], { a: '#E8E3D6', b: '#E0458C' }),
    power: PIX(['....a...', '...aa...', '..aab...', '.aabbbb.', '....bba.', '....ba..', '...ba...', '...a....'], { a: '#F5A524', b: '#FFE7A3' }),
    cooling: PIX(['...a....', '.a.a.a..', '..aaa...', 'aaabaaa.', '..aaa...', '.a.a.a..', '...a....', '........'], { a: '#57B8FF', b: '#FFFFFF' }),
    repair: PIX(['...aa...', '...aa...', '.aaaaaa.', '.aaaaaa.', '...aa...', '...aa...', '........', '........'], { a: '#7CF29A' }),
    heal: PIX(['..a..a..', '.aaaaaa.', '.aaaaaa.', '..aaaa..', '...aa...', '........', '........', '........'], { a: '#FF6B8A' })
  };

  // ------------------------------------------------------------------ 状态
  var R = null, keys = {}, joy = { id: null, cx: 0, cy: 0, dx: 0, dy: 0 }, paused = false, stars = null;
  var ENV = { bg: [0.05, 0.05, 0.13], ambient: [0.42, 0.40, 0.55], fog: [5000, 9000],
    key: { dir: [0.35, -0.85, 0.4], color: [1, 0.92, 0.82], brightness: 1.15 },
    fill: { dir: [-0.5, -0.3, -0.6], color: [0.5, 0.8, 1.0], brightness: 0.45 }, bloom: { threshold: 0.5, mix: 1.0 } };

  function lv(id) { return R.lv[id] || 0; }
  function powerMult() { return 1 + 0.1 * lv('power'); }
  function cdMult() { return 1 - 0.07 * lv('cooling'); }
  function hullMax() { return 100 + 25 * lv('hull'); }
  function pickupR() { return 11 * (1 + 0.35 * lv('magnet')) * (R.crewIds.indexOf('char_yeyuan') >= 0 ? 1.3 : 1); }
  function speed() { return 15 * (1 + 0.08 * lv('engine')); }
  function xpNeed(l) { return Math.floor(5 + l * 4 + l * l * 0.35); }

  function newRun(crewIds) {
    var save = A.save();
    R = { t: 0, px: 0, pz: 0, vx: 0, vz: 0, yaw: 0, roll: 0, hull: 100, xp: 0, level: 1, kills: 0, elites: 0, shards: 0,
      lv: { laser: 1 }, crewIds: crewIds, crew: [], enemies: [], shots: [], ebullets: [], missiles: [], gems: [], pickups: [], parts: [], nums: [], bubbles: [],
      turrets: [], wells: [], dashes: [], beams: [], novas: [], timers: { laser: 0, missile: 0, nova: 0 }, spawnAcc: 0, evIdx: 0, iframe: 0,
      shake: 0, boss: null, won: false, over: false, banner: null, bannerT: 0, decor: [], shipModel: save.ship, god: false, pendingLevels: 0 };
    crewIds.forEach(function (id, i) { R.lv[id] = 1; R.crew.push({ id: id, slot: i, cd: 1.5 + i, x: 0, z: 0, dash: null }); });
    // 远景装饰：岩块随玩家循环摆放
    for (var i = 0; i < 14; i++) R.decor.push({ model: pick(['space_asteroid_a', 'space_asteroid_a', 'space_asteroid_b']), x: rand(-140, 140), z: rand(-140, 140), y: rand(-170, -110), s: rand(2, 4.5), yaw: rand(0, 360), spin: rand(-10, 10) });
    stars = stars || E.buildStars({ data: makeStars(), colors: [[0.92, 0.93, 1.0], [0.55, 0.95, 0.9], [1.0, 0.8, 0.5]] });
  }
  function makeStars() {
    var out = [];
    for (var i = 0; i < 500; i++) {
      var x = rand(-1, 1), y = rand(-1, 1), z = rand(-1, 1), l = Math.hypot(x, y, z) || 1, r = rand(3000, 3600);
      out.push(x / l * r, y / l * r, z / l * r, rand(6, 16), Math.random() < 0.7 ? 0 : (Math.random() < 0.66 ? 1 : 2));
    }
    return out;
  }

  // ------------------------------------------------------------------ 敌人
  function spawnEnemy(type, x, z) {
    var d = ENEMY[type], mesh = E.getMesh(d.model);
    var hpScale = 1 + R.t / 200;
    var e = { type: type, d: d, mesh: mesh, x: x, z: z, hp: d.hp * (d.boss ? 1 : hpScale), max: 0, r: Math.max(1.6, mesh.radius * d.scale * 0.55),
      fire: d.shoot ? rand(1, d.shoot.cd) : 0, flash: 0, contact: 0, yaw: 0, kx: 0, kz: 0, bob: rand(0, 6) };
    e.max = e.hp;
    R.enemies.push(e);
    if (d.boss) R.boss = e;
    return e;
  }
  function edgePos(extra) {
    var a = rand(0, Math.PI * 2), dist = 62 + (extra || 0);
    return [R.px + Math.cos(a) * dist, R.pz + Math.sin(a) * dist];
  }
  function mixType() {
    var t = R.t, r = Math.random();
    if (t < 60) return 'crawler';
    if (t < 120) return r < 0.7 ? 'crawler' : 'grunt';
    if (t < 180) return r < 0.5 ? 'crawler' : r < 0.8 ? 'grunt' : 'inter';
    if (t < 300) return r < 0.4 ? 'crawler' : r < 0.65 ? 'grunt' : r < 0.85 ? 'inter' : 'heavy';
    return r < 0.35 ? 'crawler' : r < 0.6 ? 'grunt' : r < 0.8 ? 'inter' : 'heavy';
  }
  function updateSpawns(dt) {
    var cap = R.boss ? 140 : 260;
    if (!R.boss || R.t < RUN_TIME + 60) {
      R.spawnAcc += dt * Math.min(9, 0.8 + R.t / 40) * (R.boss ? 0.4 : 1);
      while (R.spawnAcc >= 1) { R.spawnAcc -= 1; if (R.enemies.length < cap) { var p = edgePos(); spawnEnemy(mixType(), p[0], p[1]); } }
    }
    while (R.evIdx < EVENTS.length && R.t >= EVENTS[R.evIdx].t) {
      var ev = EVENTS[R.evIdx++];
      if (ev.msg) banner(ev.msg);
      if (ev.ring) for (var i = 0; i < ev.n; i++) { var a = i / ev.n * Math.PI * 2; spawnEnemy(ev.ring, R.px + Math.cos(a) * 58, R.pz + Math.sin(a) * 58); }
      if (ev.elite) { var p2 = edgePos(); spawnEnemy(ev.elite, p2[0], p2[1]); }
      if (ev.boss) { var p3 = edgePos(10); spawnEnemy('boss', p3[0], p3[1]); }
    }
  }
  function banner(msg) { R.banner = msg; R.bannerT = 3; }

  // 空间网格：用于分离与命中查询
  var grid = {}, CELL = 6;
  function buildGrid() {
    grid = {};
    for (var i = 0; i < R.enemies.length; i++) {
      var e = R.enemies[i], k = Math.floor(e.x / CELL) + ',' + Math.floor(e.z / CELL);
      (grid[k] || (grid[k] = [])).push(e);
    }
  }
  function near(x, z, r, fn) {
    var c0 = Math.floor((x - r) / CELL), c1 = Math.floor((x + r) / CELL), r0 = Math.floor((z - r) / CELL), r1 = Math.floor((z + r) / CELL);
    for (var cx = c0; cx <= c1; cx++) for (var cz = r0; cz <= r1; cz++) {
      var list = grid[cx + ',' + cz]; if (!list) continue;
      for (var i = 0; i < list.length; i++) if (fn(list[i]) === false) return;
    }
  }
  function nearestEnemy(x, z, maxR) {
    var best = null, bd = maxR * maxR;
    R.enemies.forEach(function (e) { var d = d2(x, z, e.x, e.z); if (d < bd && e.hp > 0) { bd = d; best = e; } });
    return best;
  }

  function hurtEnemy(e, dmg, kx, kz) {
    if (e.hp <= 0) return;
    var crit = Math.random() < 0.1; dmg *= powerMult() * (crit ? 2 : 1);
    e.hp -= dmg; e.flash = 0.08;
    if (kx || kz) { var m = e.d.boss ? 0.05 : e.d.elite ? 0.25 : 1; e.kx += kx * m; e.kz += kz * m; }
    if (R.nums.length < 70) R.nums.push({ x: e.x, z: e.z, y: e.r * 1.6, v: Math.round(dmg), crit: crit, life: 0.7 });
    if (e.hp <= 0) killEnemy(e);
  }
  function killEnemy(e) {
    R.kills++;
    sparks(e.x, 1.5, e.z, 'fx_spark', e.d.elite || e.d.boss ? 60 : 10, e.d.elite || e.d.boss ? 30 : 14, 0.8);
    sparks(e.x, 1.5, e.z, 'fx_debris', e.d.elite || e.d.boss ? 30 : 5, 12, 1.4);
    if (e.d.xp) {
      var xp = e.d.xp;
      while (xp > 0) { var v = xp >= 10 ? 10 : xp >= 5 ? 5 : 1; xp -= v; R.gems.push({ x: e.x + rand(-1.5, 1.5), z: e.z + rand(-1.5, 1.5), v: v }); }
    }
    if (Math.random() < 0.008 && !e.d.elite) R.pickups.push({ kind: 'heal', x: e.x, z: e.z, life: 40 });
    if (e.d.elite) { R.elites++; R.pickups.push({ kind: 'chest', x: e.x, z: e.z, life: 999 }); R.shake = 0.4; }
    if (e.d.boss) { R.won = true; R.shake = 1.2; R.shards += 5; banner('赤髑号被击沉！'); setTimeout(function () { endRun(true); }, 2200); }
  }
  function sparks(x, y, z, model, n, spd, life) {
    for (var i = 0; i < n && R.parts.length < 420; i++)
      R.parts.push({ model: model, x: x, y: y, z: z, vx: rand(-1, 1) * spd, vy: rand(0, 1) * spd * 0.6, vz: rand(-1, 1) * spd, life: life * rand(0.6, 1.2), max: life, size: rand(1.5, 3) });
  }
  function hurtPlayer(dmg) {
    if (R.iframe > 0 || R.god || R.over || R.won) return;
    R.hull -= dmg; R.iframe = 0.35; R.shake = Math.max(R.shake, 0.25);
    var f = document.getElementById('hitflash'); if (f) { f.style.opacity = 0.5; setTimeout(function () { f.style.opacity = 0; }, 90); }
    if (R.hull <= 0) { R.hull = 0; R.over = true; sparks(R.px, 1, R.pz, 'fx_spark', 80, 30, 1.2); setTimeout(function () { endRun(false); }, 1500); }
  }

  function updateEnemies(dt) {
    buildGrid();
    for (var i = 0; i < R.enemies.length; i++) {
      var e = R.enemies[i], d = e.d;
      if (e.hp <= 0) continue;
      var dx = R.px - e.x, dz = R.pz - e.z, dist = Math.hypot(dx, dz) || 1, nx = dx / dist, nz = dz / dist;
      var mvx = nx, mvz = nz;
      if (d.keep && dist < d.keep) { mvx = -nz * 0.9 - nx * 0.3; mvz = nx * 0.9 - nz * 0.3; }
      // 分离
      var sx = 0, sz = 0;
      near(e.x, e.z, e.r * 2, function (o) {
        if (o === e) return;
        var ox = e.x - o.x, oz = e.z - o.z, od = Math.hypot(ox, oz), min = e.r + o.r;
        if (od < min && od > 0.001) { sx += ox / od * (min - od); sz += oz / od * (min - od); }
      });
      var spd = d.spd * (e.slow ? 0.4 : 1);
      e.x += (mvx * spd + e.kx) * dt + sx * 0.5; e.z += (mvz * spd + e.kz) * dt + sz * 0.5;
      e.kx *= Math.exp(-dt * 6); e.kz *= Math.exp(-dt * 6);
      e.slow = false;
      e.yaw = Math.atan2(mvx, mvz) / DEG;
      e.flash -= dt; e.contact -= dt;
      if (dist < e.r + 2.3 && e.contact <= 0) { hurtPlayer(d.dmg); e.contact = 0.8; }
      if (d.shoot && dist < 55) {
        e.fire -= dt;
        if (e.fire <= 0) {
          e.fire = d.shoot.cd;
          if (d.shoot.ring) {
            for (var k = 0; k < d.shoot.ring; k++) { var a = k / d.shoot.ring * Math.PI * 2 + R.t; R.ebullets.push({ x: e.x, z: e.z, vx: Math.cos(a) * d.shoot.spd, vz: Math.sin(a) * d.shoot.spd, dmg: d.shoot.dmg, life: 5 }); }
            var aim = Math.atan2(dz, dx);
            for (k = -2; k <= 2; k++) R.ebullets.push({ x: e.x, z: e.z, vx: Math.cos(aim + k * 0.12) * d.shoot.spd * 1.4, vz: Math.sin(aim + k * 0.12) * d.shoot.spd * 1.4, dmg: d.shoot.dmg, life: 5 });
          } else {
            var base = Math.atan2(dz, dx);
            for (var j = 0; j < d.shoot.n; j++) {
              var off = d.shoot.n > 1 ? (j / (d.shoot.n - 1) - 0.5) * d.shoot.spread * DEG : 0;
              R.ebullets.push({ x: e.x, z: e.z, vx: Math.cos(base + off) * d.shoot.spd, vz: Math.sin(base + off) * d.shoot.spd, dmg: d.shoot.dmg, life: 4 });
            }
          }
        }
      }
      // 太远的普通敌人：重新放回视野边缘
      if (!d.elite && !d.boss && dist > 110) { var p = edgePos(); e.x = p[0]; e.z = p[1]; }
    }
    R.enemies = R.enemies.filter(function (e) { return e.hp > 0; });
  }

  // ------------------------------------------------------------------ 武器
  function updateWeapons(dt) {
    var L = UPG.laser, li = lv('laser') - 1, cm = cdMult();
    R.timers.laser -= dt;
    if (R.timers.laser <= 0) {
      var tgt = nearestEnemy(R.px, R.pz, 38);
      if (tgt) {
        R.timers.laser = L.cd[li] * cm;
        var base = Math.atan2(tgt.z - R.pz, tgt.x - R.px), n = L.n[li];
        for (var i = 0; i < n; i++) {
          var a = base + (n > 1 ? (i / (n - 1) - 0.5) * 0.28 : 0);
          R.shots.push({ x: R.px, z: R.pz, vx: Math.cos(a) * 62, vz: Math.sin(a) * 62, dmg: L.dmg[li], pierce: L.pierce[li], life: 0.9, hit: [] });
        }
      }
    }
    if (lv('missile')) {
      var M = UPG.missile, mi = lv('missile') - 1;
      R.timers.missile -= dt;
      if (R.timers.missile <= 0) {
        R.timers.missile = M.cd[mi] * cm;
        for (var k = 0; k < M.n[mi]; k++) {
          var t2 = R.enemies.length ? pick(R.enemies) : null;
          R.missiles.push({ x: R.px, z: R.pz, y: 1.5, yaw: rand(0, 360), spd: 30, target: t2, dmg: M.dmg[mi], splash: 5, life: 3 });
        }
      }
    }
    if (lv('nova')) {
      var N = UPG.nova, ni = lv('nova') - 1;
      R.timers.nova -= dt;
      if (R.timers.nova <= 0) { R.timers.nova = N.cd[ni] * cm; nova(R.px, R.pz, N.r[ni], N.dmg[ni], '#57B8FF'); }
    }
    if (lv('blades')) {
      var B = UPG.blades, bi = lv('blades') - 1, n2 = B.n[bi];
      R.bladeAng = (R.bladeAng || 0) + dt * 200;
      R.blades = [];
      for (var b = 0; b < n2; b++) {
        var ang = (R.bladeAng + b * 360 / n2) * DEG, bx = R.px + Math.cos(ang) * 7, bz = R.pz + Math.sin(ang) * 7;
        R.blades.push([bx, bz, ang]);
        near(bx, bz, 2.5, function (e) {
          if (d2(bx, bz, e.x, e.z) < (e.r + 1.2) * (e.r + 1.2) && (e.bladeCd || 0) <= R.t) { e.bladeCd = R.t + 0.35; hurtEnemy(e, B.dmg[bi], (e.x - R.px) * 0.6, (e.z - R.pz) * 0.6); }
        });
      }
    } else R.blades = null;
  }
  function nova(x, z, r, dmg, color, heal) {
    R.novas.push({ x: x, z: z, r: r, life: 0.45, color: color || '#57B8FF' });
    if (dmg) near(x, z, r + 3, function (e) {
      var dd = Math.sqrt(d2(x, z, e.x, e.z)) || 1;
      if (dd < r + e.r) hurtEnemy(e, dmg, (e.x - x) / dd * 22, (e.z - z) / dd * 22);
    });
  }
  function explode(x, z, r, dmg) {
    sparks(x, 1, z, 'fx_spark', 14, 16, 0.6);
    near(x, z, r + 3, function (e) { if (d2(x, z, e.x, e.z) < (r + e.r) * (r + e.r)) hurtEnemy(e, dmg, 0, 0); });
  }
  function updateShots(dt) {
    R.shots = R.shots.filter(function (s) {
      s.life -= dt; s.x += s.vx * dt; s.z += s.vz * dt;
      var dead = false;
      near(s.x, s.z, 4, function (e) {
        if (s.hit.indexOf(e) >= 0) return;
        if (d2(s.x, s.z, e.x, e.z) < (e.r + 0.6) * (e.r + 0.6)) {
          hurtEnemy(e, s.dmg, s.vx * 0.04, s.vz * 0.04); s.hit.push(e);
          sparks(s.x, 1.5, s.z, 'fx_spark_teal', 2, 8, 0.3);
          if (s.pierce-- <= 0) { dead = true; return false; }
        }
      });
      return !dead && s.life > 0;
    });
    R.missiles = R.missiles.filter(function (m) {
      m.life -= dt;
      if (!m.target || m.target.hp <= 0) m.target = nearestEnemy(m.x, m.z, 40);
      var want = m.target ? Math.atan2(m.target.x - m.x, m.target.z - m.z) / DEG : m.yaw;
      var diff = ((want - m.yaw + 540) % 360) - 180; m.yaw += clamp(diff, -400 * dt, 400 * dt);
      m.spd = Math.min(55, m.spd + dt * 60);
      m.x += Math.sin(m.yaw * DEG) * m.spd * dt; m.z += Math.cos(m.yaw * DEG) * m.spd * dt;
      if (Math.random() < 0.5) sparks(m.x, 1.5, m.z, 'fx_spark', 1, 3, 0.3);
      if (m.target && d2(m.x, m.z, m.target.x, m.target.z) < (m.target.r + 1) * (m.target.r + 1)) { explode(m.x, m.z, m.splash, m.dmg); return false; }
      if (m.life <= 0) { explode(m.x, m.z, m.splash, m.dmg * 0.5); return false; }
      return true;
    });
    R.ebullets = R.ebullets.filter(function (b) {
      b.life -= dt; b.x += b.vx * dt; b.z += b.vz * dt;
      if (d2(b.x, b.z, R.px, R.pz) < 2.2 * 2.2) { hurtPlayer(b.dmg); return false; }
      return b.life > 0;
    });
  }

  // ------------------------------------------------------------------ 舰员技能
  function crewStat(c) {
    var C = CREW[c.id], l = lv(c.id);
    return { dmg: C.dmg * (1 + 0.35 * (l - 1)), cd: C.cd * (1 - 0.1 * (l - 1)) * cdMult(), area: 1 + 0.15 * (l - 1), count: l >= 5 ? 2 : 1, lv: l };
  }
  function say(c) { R.bubbles = R.bubbles.filter(function (b) { return b.c !== c; }); R.bubbles.push({ c: c, text: pick(CREW[c.id].lines), life: 1.6 }); }
  function updateCrew(dt) {
    R.crew.forEach(function (c) {
      var side = c.slot === 0 ? -1 : 1;
      var hx = R.px + side * 6.5, hz = R.pz - 1.5;
      if (c.dash) {
        c.dash.t += dt; var k = Math.min(1, c.dash.t / c.dash.dur);
        c.x = lerp(c.dash.x0, c.dash.x1, k); c.z = lerp(c.dash.z0, c.dash.z1, k);
        near(c.x, c.z, 5 * c.dash.area, function (e) {
          if (c.dash.hit.indexOf(e) < 0 && d2(c.x, c.z, e.x, e.z) < Math.pow(3.5 * c.dash.area + e.r, 2)) {
            c.dash.hit.push(e); hurtEnemy(e, c.dash.dmg, c.dash.dx * 30, c.dash.dz * 30);
          }
        });
        sparks(c.x, 2, c.z, 'fx_spark', 2, 6, 0.4);
        if (k >= 1) { c.dash.left--; if (c.dash.left > 0) startDash(c, c.dash.dmg, c.dash.area, c.dash.left); else c.dash = null; }
      } else { c.x = lerp(c.x || hx, hx, 1 - Math.exp(-dt * 8)); c.z = lerp(c.z || hz, hz, 1 - Math.exp(-dt * 8)); }
      var st = crewStat(c);
      if (c.id === 'char_yuexi') R.hull = Math.min(hullMax(), R.hull + dt * 1.5 * (1 + 0.35 * (st.lv - 1)));
      c.cd -= dt;
      if (c.cd > 0) return;
      c.cd = st.cd;
      if (c.id === 'char_xingli') {
        var targets = R.enemies.slice().sort(function (a, b) { return b.hp - a.hp; }).filter(function (e) { return d2(R.px, R.pz, e.x, e.z) < 50 * 50; }).slice(0, st.count);
        if (!targets.length) { c.cd = 0.5; return; }
        targets.forEach(function (t) { beam(c.x, c.z, t.x, t.z, st.dmg, 1.6 * st.area); });
        say(c);
      } else if (c.id === 'char_chiyan') {
        startDash(c, st.dmg, st.area, st.count); say(c);
      } else if (c.id === 'char_yuexi') {
        R.hull = Math.min(hullMax(), R.hull + 12 * (1 + 0.35 * (st.lv - 1)));
        nova(R.px, R.pz, 10 * st.area, st.lv >= 5 ? st.dmg * 2 : 0, '#7CF29A', true); say(c);
      } else if (c.id === 'char_hupo') {
        for (var i = 0; i < st.count; i++) R.turrets.push({ x: R.px + rand(-6, 6), z: R.pz + rand(-6, 6), life: 8, fire: 0, dmg: st.dmg, yaw: 0 });
        say(c);
      } else if (c.id === 'char_yeyuan') {
        for (var w = 0; w < st.count; w++) {
          var t = R.enemies.length ? pick(R.enemies.filter(function (e) { return d2(R.px, R.pz, e.x, e.z) < 40 * 40; })) : null;
          if (t) R.wells.push({ x: t.x, z: t.z, r: 11 * st.area, life: 3, dmg: st.dmg });
        }
        say(c);
      } else if (c.id === 'char_shuangling') {
        var n = 6 * st.count;
        for (var m = 0; m < n; m++) {
          var tt = R.enemies.length ? pick(R.enemies) : null, tx = tt ? tt.x : R.px + rand(-25, 25), tz = tt ? tt.z : R.pz + rand(-25, 25);
          R.missiles.push({ x: tx + rand(-1, 1), z: tz + rand(-1, 1), y: 32 + m * 3, fall: true, yaw: 0, dmg: st.dmg, splash: 5 * st.area, life: 5, tx: tx, tz: tz, spd: 0 });
        }
        say(c);
      }
    });
    // 炮塔
    R.turrets = R.turrets.filter(function (tu) {
      tu.life -= dt; tu.fire -= dt;
      var t = nearestEnemy(tu.x, tu.z, 32);
      if (t) {
        tu.yaw = Math.atan2(t.x - tu.x, t.z - tu.z) / DEG;
        if (tu.fire <= 0) { tu.fire = 0.35; var a = Math.atan2(t.z - tu.z, t.x - tu.x); R.shots.push({ x: tu.x, z: tu.z, vx: Math.cos(a) * 60, vz: Math.sin(a) * 60, dmg: tu.dmg, pierce: 0, life: 0.8, hit: [] }); }
      }
      return tu.life > 0;
    });
    // 引力井
    R.wells = R.wells.filter(function (w) {
      w.life -= dt;
      near(w.x, w.z, w.r + 3, function (e) {
        var dx = w.x - e.x, dz = w.z - e.z, dd = Math.hypot(dx, dz) || 1;
        if (dd < w.r) { if (!e.d.boss) { e.x += dx / dd * Math.min(dd, 14 * dt); e.z += dz / dd * Math.min(dd, 14 * dt); } e.slow = true; e.wellCd = (e.wellCd || 0) - dt; if (e.wellCd <= 0) { e.wellCd = 0.5; hurtEnemy(e, w.dmg * 0.5, 0, 0); } }
      });
      if (Math.random() < 0.8) { var a = rand(0, Math.PI * 2); R.parts.push({ model: 'fx_spark_teal', x: w.x + Math.cos(a) * w.r, y: 1, z: w.z + Math.sin(a) * w.r, vx: -Math.cos(a) * w.r * 1.5, vy: 0, vz: -Math.sin(a) * w.r * 1.5, life: 0.6, max: 0.6, size: 2 }); }
      return w.life > 0;
    });
    // 天降导弹
    R.missiles.forEach(function (m) { if (m.fall) { m.y -= dt * 60; if (m.y <= 0.5) { m.done = true; explode(m.tx, m.tz, m.splash, m.dmg); } } });
    R.missiles = R.missiles.filter(function (m) { return !m.done; });
    R.beams = R.beams.filter(function (b) { b.life -= dt; return b.life > 0; });
  }
  function startDash(c, dmg, area, left) {
    var dir = Math.hypot(R.vx, R.vz) > 0.5 ? Math.atan2(R.vx, R.vz) : R.yaw * DEG;
    var t = nearestEnemy(R.px, R.pz, 35); if (t) dir = Math.atan2(t.x - R.px, t.z - R.pz);
    var len = 26 * area, dx = Math.sin(dir), dz = Math.cos(dir);
    c.dash = { t: 0, dur: 0.38, x0: c.x, z0: c.z, x1: R.px + dx * len, z1: R.pz + dz * len, dx: dx, dz: dz, dmg: dmg, area: area, hit: [], left: left };
  }
  function beam(x0, z0, x1, z1, dmg, width) {
    var dx = x1 - x0, dz = z1 - z0, l = Math.hypot(dx, dz) || 1; dx /= l; dz /= l;
    var len = 60;
    R.beams.push({ x: x0, z: z0, dx: dx, dz: dz, len: len, life: 0.18 });
    R.enemies.forEach(function (e) {
      var rx = e.x - x0, rz = e.z - z0, t = rx * dx + rz * dz;
      if (t < 0 || t > len) return;
      var px = rx - dx * t, pz = rz - dz * t;
      if (px * px + pz * pz < (e.r + width) * (e.r + width)) hurtEnemy(e, dmg, dx * 8, dz * 8);
    });
  }

  // ------------------------------------------------------------------ 拾取与升级
  function updatePickups(dt) {
    var pr = pickupR(), pr2 = pr * pr;
    R.gems = R.gems.filter(function (g) {
      var dd = d2(g.x, g.z, R.px, R.pz);
      if (dd < pr2 || g.pull) {
        g.pull = true; var d = Math.sqrt(dd) || 1, sp = 40 + (pr - Math.min(pr, d)) * 4;
        g.x += (R.px - g.x) / d * sp * dt; g.z += (R.pz - g.z) / d * sp * dt;
      }
      if (dd < 2.5 * 2.5) { gainXp(g.v); return false; }
      return true;
    });
    if (R.gems.length > 400) R.gems.splice(0, R.gems.length - 400);
    R.pickups = R.pickups.filter(function (p) {
      p.life -= dt;
      if (d2(p.x, p.z, R.px, R.pz) < 3.5 * 3.5) {
        if (p.kind === 'heal') { R.hull = Math.min(hullMax(), R.hull + 30); A.toast('船体修复 30'); }
        else { var s = 1 + (Math.random() < 0.4 ? 1 : 0); R.shards += s; R.hull = Math.min(hullMax(), R.hull + 20); A.toast('精英货舱：陨石碎片 x' + s + '，船体修复 20'); R.pendingLevels++; }
        return false;
      }
      return p.life > 0;
    });
  }
  function gainXp(v) {
    R.xp += v;
    while (R.xp >= xpNeed(R.level)) { R.xp -= xpNeed(R.level); R.level++; R.pendingLevels++; }
  }
  function choices() {
    var weapons = Object.keys(UPG).filter(function (k) { return UPG[k].kind === 'weapon' && lv(k) > 0; }).length;
    var passives = Object.keys(UPG).filter(function (k) { return UPG[k].kind === 'passive' && lv(k) > 0; }).length;
    var pool = [];
    Object.keys(UPG).forEach(function (k) {
      var u = UPG[k], l = lv(k);
      if (l >= u.max) return;
      if (l === 0 && u.kind === 'weapon' && weapons >= 4) return;
      if (l === 0 && u.kind === 'passive' && passives >= 4) return;
      pool.push({ id: k, w: u.kind === 'weapon' ? 1.2 : 1 });
    });
    R.crewIds.forEach(function (id) { if (lv(id) < 5) pool.push({ id: id, w: 1.6 }); });
    var out = [];
    while (out.length < 3 && pool.length) {
      var sum = pool.reduce(function (s, p) { return s + p.w; }, 0), r = Math.random() * sum, i = 0;
      while (r > pool[i].w) { r -= pool[i].w; i++; }
      out.push(pool[i].id); pool.splice(i, 1);
    }
    if (!out.length) out.push('heal');
    return out;
  }
  function applyChoice(id) {
    if (id === 'heal') { R.hull = Math.min(hullMax(), R.hull + 40); return; }
    R.lv[id] = lv(id) + 1;
    if (id === 'hull') R.hull = Math.min(hullMax(), R.hull + 25);
  }
  function choiceInfo(id) {
    if (id === 'heal') return { name: '紧急维修', tag: '回复', icon: A.iconSVG(ICON.heal, 120), text: '修复 40 点船体' };
    var next = lv(id) + 1;
    if (CREW[id]) {
      var c = CREW[id], g = A.byId(G.crew, id);
      var text = next === 1 ? c.desc : next === 5 ? c.awake : '伤害 +35%，冷却 -10%，范围 +15%';
      return { name: g.name + '：' + c.skill, tag: '舰员 Lv' + next, icon: A.catIcon(id, 76), text: text, crew: true };
    }
    var u = UPG[id], d = u.desc[Math.min(next - 1, u.desc.length - 1)];
    return { name: u.name, tag: (u.kind === 'weapon' ? '武器' : '强化') + ' Lv' + next, icon: A.iconSVG(ICON[id], 120), text: d };
  }

  // ------------------------------------------------------------------ 玩家移动
  function updatePlayer(dt) {
    var mx = joy.dx, mz = joy.dy;
    if (keys.KeyA || keys.ArrowLeft) mx = -1; if (keys.KeyD || keys.ArrowRight) mx = 1;
    if (keys.KeyW || keys.ArrowUp) mz = 1; if (keys.KeyS || keys.ArrowDown) mz = -1;
    var l = Math.hypot(mx, mz); if (l > 1) { mx /= l; mz /= l; }
    var sp = speed();
    R.vx = lerp(R.vx, mx * sp, 1 - Math.exp(-dt * 10)); R.vz = lerp(R.vz, mz * sp, 1 - Math.exp(-dt * 10));
    R.px += R.vx * dt; R.pz += R.vz * dt;
    if (Math.hypot(R.vx, R.vz) > 1) {
      var want = Math.atan2(R.vx, R.vz) / DEG, diff = ((want - R.yaw + 540) % 360) - 180;
      R.yaw += clamp(diff, -540 * dt, 540 * dt); R.roll = lerp(R.roll, clamp(-diff * 0.6, -35, 35), 1 - Math.exp(-dt * 6));
    } else R.roll = lerp(R.roll, 0, 1 - Math.exp(-dt * 4));
    R.hull = Math.min(hullMax(), R.hull + 0.6 * lv('repair') * dt);
    R.iframe -= dt;
  }
  function updateParts(dt) {
    R.parts = R.parts.filter(function (p) { p.life -= dt; p.x += p.vx * dt; p.y += p.vy * dt; p.z += p.vz * dt; p.vx *= 0.96; p.vz *= 0.96; p.vy -= 10 * dt; return p.life > 0; });
    R.nums = R.nums.filter(function (n) { n.life -= dt; n.y += dt * 5; return n.life > 0; });
    R.bubbles = R.bubbles.filter(function (b) { b.life -= dt; return b.life > 0; });
    R.novas = R.novas.filter(function (n) { n.life -= dt; return n.life > 0; });
    R.bannerT -= dt;
    R.shake = Math.max(0, R.shake - dt * 1.5);
  }
  function step(dt) {
    if (!R || paused || R.over && !R.won) { if (R && R.over) updateParts(dt); return; }
    R.t += dt;
    updatePlayer(dt); updateSpawns(dt); updateEnemies(dt); updateWeapons(dt); updateCrew(dt); updateShots(dt); updatePickups(dt); updateParts(dt);
    if (R.pendingLevels > 0 && !R.over) openLevelUp();
  }

  // ------------------------------------------------------------------ 渲染
  var lastVP = null;
  function camEye() {
    var sh = R.shake, ox = sh ? rand(-1, 1) * sh : 0, oz = sh ? rand(-1, 1) * sh : 0;
    return { eye: [R.px + ox, 46, R.pz - 30 + oz], target: [R.px, 0, R.pz + 3] };
  }
  function render() {
    var t = R.t, draws = [], m = E.trs;
    function add(model, x, y, z, yaw, pitch, roll, s) { var mesh = E.getMesh(model); if (mesh) draws.push({ mesh: mesh, m: m([x, y, z], yaw, pitch, roll, s), s: s }); }
    R.decor.forEach(function (d) {
      var wx = R.px + ((d.x - R.px * 0.7) % 280 + 420) % 280 - 140, wz = R.pz + ((d.z - R.pz * 0.7) % 280 + 420) % 280 - 140;
      add(d.model, wx, d.y, wz, d.yaw + d.spin * t, 20, 0, d.s);
    });
    if (!R.over || R.won) add(R.shipModel, R.px, 1.2 + Math.sin(t * 3) * 0.15, R.pz, R.yaw, 0, R.roll, 1);
    R.crew.forEach(function (c) { add(c.id, c.x, 2.4 + Math.sin(t * 2.4 + c.slot * 2) * 0.35, c.z, c.dash ? Math.atan2(c.dash.dx, c.dash.dz) / DEG : 180, c.dash ? 25 : 0, 0, 3.2); });
    R.enemies.forEach(function (e) {
      var s = e.d.scale * (e.flash > 0 ? 1.12 : 1), y = e.d.float ? 1 + Math.sin(t * 3 + e.bob) * 0.4 : (e.d.model.indexOf('ship') === 0 ? 1.5 : 0);
      add(e.d.model, e.x, y, e.z, e.yaw, 0, 0, s);
    });
    R.shots.forEach(function (s) { add('fx_laser_player', s.x, 1.5, s.z, Math.atan2(s.vx, s.vz) / DEG, 0, 0, 2.6); });
    R.ebullets.forEach(function (b) { add('fx_spark', b.x, 1.5, b.z, t * 300, t * 200, 0, 7); });
    R.missiles.forEach(function (mm) { add('fx_missile', mm.x, mm.y, mm.z, mm.yaw, mm.fall ? 90 : 0, 0, 2.2); });
    R.beams.forEach(function (b) { for (var k = 0; k < b.len; k += 4) add('fx_laser_player', b.x + b.dx * k, 2, b.z + b.dz * k, Math.atan2(b.dx, b.dz) / DEG, 0, 0, 3.2); });
    if (R.blades) R.blades.forEach(function (b) { add('fx_spark_teal', b[0], 1.5, b[1], t * 400, 45, 0, 9); });
    R.turrets.forEach(function (tu) { add('prop_turret', tu.x, 0, tu.z, tu.yaw, 0, 0, 2.6); });
    R.gems.forEach(function (g) { add(g.v >= 10 ? 'prop_meteor_shard' : 'fx_spark_teal', g.x, 1 + Math.sin(t * 4 + g.x) * 0.2, g.z, t * 120, g.v >= 10 ? 0 : 45, 0, g.v >= 10 ? 1.6 : g.v >= 5 ? 7 : 4.5); });
    R.pickups.forEach(function (p) { add(p.kind === 'heal' ? 'prop_medkit' : 'prop_loot_pod', p.x, 1.5, p.z, t * 90, 0, 0, p.kind === 'heal' ? 4 : 3.4); });
    R.novas.forEach(function (n) {
      var k = 1 - n.life / 0.45, rr = n.r * (0.3 + 0.7 * k), seg = 28;
      for (var i = 0; i < seg; i++) { var a = i / seg * Math.PI * 2; add(n.color === '#7CF29A' ? 'fx_spark_teal' : 'fx_shield', n.x + Math.cos(a) * rr, 1, n.z + Math.sin(a) * rr, 0, 0, 0, 6 * (1 - k * 0.6)); }
    });
    R.wells.forEach(function (w) { add('fx_spark_teal', w.x, 1.5, w.z, t * 500, t * 300, 0, 14 + Math.sin(t * 20) * 3); });
    R.parts.forEach(function (p) { var s = p.size * clamp(p.life / p.max, 0.15, 1) * 2; add(p.model, p.x, p.y, p.z, p.life * 200, p.life * 140, 0, s); });
    var c = camEye(), aspect = view().w / view().h;
    lastVP = E.render({ env: ENV, eye: c.eye, target: c.target, fov: A.fitFov(50, aspect), aspect: aspect, near: 1, far: 6000, draws: draws, stars: stars, shadow: null });
  }
  function drawOverlay() {
    var V = view(), cv = document.getElementById('hud2d'), ctx = cv.getContext('2d'), s = V.s, w = V.w, h = V.h;
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, cv.width, cv.height);
    if (!lastVP) return;
    ctx.setTransform(V.dpr, 0, 0, V.dpr, 0, 0);
    function P(x, y, z) { return E.project(lastVP, [x, y, z], w, h); }
    var u = Math.max(0.55, s * 1.5);
    // 船体血条
    var pp = P(R.px, 0, R.pz - 3.5);
    if (pp && !R.over) {
      var bw = 60 * u, bh = 7 * u;
      ctx.fillStyle = 'rgba(9,12,34,.85)'; ctx.fillRect(pp[0] - bw / 2 - 2, pp[1] - 2, bw + 4, bh + 4);
      ctx.fillStyle = R.hull / hullMax() < 0.3 ? '#E0458C' : '#7CF29A'; ctx.fillRect(pp[0] - bw / 2, pp[1], bw * R.hull / hullMax(), bh);
    }
    // 拾取范围（淡圈）
    // 伤害数字
    ctx.textAlign = 'center';
    R.nums.forEach(function (n) {
      var q = P(n.x, n.y, n.z); if (!q) return;
      ctx.globalAlpha = clamp(n.life / 0.35, 0, 1);
      ctx.font = '700 ' + Math.round((n.crit ? 17 : 12) * u) + 'px "Noto Sans SC", sans-serif';
      ctx.lineWidth = 3 * u; ctx.strokeStyle = 'rgba(9,12,34,.9)'; ctx.strokeText(n.v, q[0], q[1]);
      ctx.fillStyle = n.crit ? '#F5A524' : '#EDE6D6'; ctx.fillText(n.v, q[0], q[1]);
    });
    ctx.globalAlpha = 1;
    // 舰员台词气泡
    R.bubbles.forEach(function (b) {
      var q = P(b.c.x, 7.5, b.c.z); if (!q) return;
      ctx.font = '700 ' + Math.round(13 * u) + 'px "Noto Sans SC", sans-serif';
      var tw = ctx.measureText(b.text).width + 16 * u, th = 24 * u;
      ctx.globalAlpha = clamp(b.life / 0.3, 0, 1);
      ctx.fillStyle = 'rgba(237,230,214,.95)'; ctx.fillRect(q[0] - tw / 2, q[1] - th, tw, th);
      ctx.beginPath(); ctx.moveTo(q[0] - 5 * u, q[1]); ctx.lineTo(q[0] + 5 * u, q[1]); ctx.lineTo(q[0], q[1] + 6 * u); ctx.fill();
      ctx.fillStyle = '#1A2046'; ctx.textBaseline = 'middle'; ctx.fillText(b.text, q[0], q[1] - th / 2); ctx.textBaseline = 'alphabetic';
      ctx.globalAlpha = 1;
    });
    // 首领 / 精英的屏幕外箭头
    R.enemies.forEach(function (e) {
      if (!e.d.elite && !e.d.boss) return;
      var q = P(e.x, 0, e.z); if (q && q[0] > 0 && q[0] < w && q[1] > 0 && q[1] < h) return;
      var ang = Math.atan2(-(e.z - R.pz), e.x - R.px), rr = Math.min(w, h) * 0.42, ex = w / 2 + Math.cos(ang) * rr, ey = h / 2 + Math.sin(ang) * rr;
      ctx.save(); ctx.translate(ex, ey); ctx.rotate(ang); ctx.fillStyle = e.d.boss ? '#FF4D6A' : '#E0458C';
      ctx.beginPath(); ctx.moveTo(16 * u, 0); ctx.lineTo(-9 * u, -10 * u); ctx.lineTo(-9 * u, 10 * u); ctx.fill(); ctx.restore();
    });
    // 浮动摇杆
    if (joy.id !== null) {
      ctx.strokeStyle = 'rgba(92,242,220,.7)'; ctx.lineWidth = 3 * u; var jr = 60 * u;
      ctx.strokeRect(joy.cx - jr, joy.cy - jr, jr * 2, jr * 2);
      ctx.fillStyle = 'rgba(237,230,214,.55)'; ctx.fillRect(joy.cx + joy.dx * jr - 24 * u, joy.cy - joy.dy * jr - 24 * u, 48 * u, 48 * u);
    }
  }

  // ------------------------------------------------------------------ 界面
  var ui = function () { return document.getElementById('ui'); }, hud = {};
  function el(tag, cls, html) { var e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; }
  function buildHUD() {
    var u = ui(); u.innerHTML = '';
    var top = el('section', 'sv-top');
    top.innerHTML = '<div class="sv-xp"><i></i><b></b></div><div class="sv-row"><div class="sv-left"><span class="sv-hull"></span><span class="sv-kills"></span><span class="sv-sd"></span></div>' +
      '<div class="sv-time"></div><div class="sv-right"></div></div><div class="sv-slots"></div><div class="sv-boss" hidden><b>赤髑号</b><div class="sv-bossbar"><i></i></div></div><div class="sv-banner" hidden></div>';
    u.appendChild(top);
    var pb = el('button', 'sbtn sv-pause', '暂停'); pb.onclick = openPause; top.querySelector('.sv-right').appendChild(pb);
    var crew = el('section', 'sv-crew');
    R.crew.forEach(function (c) {
      var g = A.byId(G.crew, c.id), card = el('div', 'panel sv-cc');
      card.innerHTML = '<span class="ic">' + A.catIcon(c.id, 54) + '</span><div><b>' + g.name + '</b><small>' + CREW[c.id].skill + '</small><div class="sv-cd"><i></i></div></div><em></em>';
      crew.appendChild(card); c.card = card;
    });
    u.appendChild(crew);
    hud = { top: top, t: 0 };
  }
  function updateHUD(dt) {
    hud.t -= dt; if (hud.t > 0) return; hud.t = 0.1;
    var top = hud.top, need = xpNeed(R.level);
    top.querySelector('.sv-xp i').style.width = (R.xp / need * 100) + '%';
    top.querySelector('.sv-xp b').textContent = 'Lv ' + R.level;
    top.querySelector('.sv-time').textContent = R.boss ? '首领战' : mmss(RUN_TIME - R.t);
    top.querySelector('.sv-hull').textContent = '船体 ' + Math.ceil(R.hull) + ' / ' + hullMax();
    top.querySelector('.sv-kills').textContent = '击破 ' + R.kills;
    top.querySelector('.sv-sd').innerHTML = A.resIcon('shard', 30) + ' ' + R.shards;
    var slots = Object.keys(UPG).filter(function (k) { return lv(k) > 0; }).map(function (k) {
      return '<span class="sv-slot">' + A.iconSVG(ICON[k], 34) + '<b>' + lv(k) + '</b></span>';
    }).join('');
    if (top._slots !== slots) { top.querySelector('.sv-slots').innerHTML = slots; top._slots = slots; }
    var bossBox = top.querySelector('.sv-boss');
    bossBox.hidden = !R.boss || R.boss.hp <= 0;
    if (R.boss) bossBox.querySelector('i').style.width = clamp(R.boss.hp / R.boss.max, 0, 1) * 100 + '%';
    var bn = top.querySelector('.sv-banner'); bn.hidden = !(R.bannerT > 0); if (R.bannerT > 0) bn.textContent = R.banner;
    R.crew.forEach(function (c) {
      var st = crewStat(c);
      c.card.querySelector('.sv-cd i').style.width = clamp(1 - c.cd / st.cd, 0, 1) * 100 + '%';
      c.card.querySelector('em').textContent = 'Lv ' + st.lv;
    });
  }
  function modal(html) { var m = el('div', 'sv-modal'); m.innerHTML = html; ui().appendChild(m); return m; }
  function openLevelUp() {
    paused = true; R.pendingLevels--;
    var ids = choices();
    var m = modal('<div class="sv-lu"><h1>升级！</h1><p>选择一项强化</p><div class="sv-cards"></div></div>');
    var box = m.querySelector('.sv-cards');
    ids.forEach(function (id) {
      var info = choiceInfo(id), b = el('button', 'sv-card' + (info.crew ? ' crew' : ''));
      b.innerHTML = '<span class="tag' + (info.crew ? ' shard' : '') + '">' + info.tag + '</span><span class="ic">' + info.icon + '</span><b>' + info.name + '</b><p>' + info.text + '</p>';
      b.onclick = function () { applyChoice(id); m.remove(); paused = false; R.gems.forEach(function (g) { if (d2(g.x, g.z, R.px, R.pz) < 45 * 45) g.pull = true; }); if (R.pendingLevels > 0) openLevelUp(); };
      box.appendChild(b);
    });
  }
  function openPause() {
    if (paused) return;
    paused = true;
    var m = modal('<div class="panel sv-pbox"><h1>暂停</h1><button class="btn primary" id="sv-res">继续</button><button class="btn" id="sv-quit">放弃本局</button>' +
      '<p class="note">拖动屏幕任意位置移动，武器自动开火。电脑可用 WASD 或方向键移动，Esc 暂停。</p></div>');
    m.querySelector('#sv-res').onclick = function () { m.remove(); paused = false; };
    m.querySelector('#sv-quit').onclick = function () { m.remove(); paused = false; R.over = true; endRun(false, true); };
  }
  function endRun(win, quit) {
    if (!R || R.ended) return;
    R.ended = true; paused = true;
    var credits = R.kills * 5 + R.level * 60 + (win ? 3000 : 0) + Math.floor(R.t) * 2;
    var save = A.save();
    save.credits += credits; save.shards += R.shards; A.writeSave();
    var m = modal('<div class="panel sv-pbox"><h1>' + (win ? '突围成功' : quit ? '已撤离' : '飞船被击毁') + '</h1>' +
      '<dl class="sv-res"><div><dt>存活时间</dt><dd>' + mmss(R.t) + '</dd></div><div><dt>击破</dt><dd>' + R.kills + '</dd></div><div><dt>等级</dt><dd>' + R.level + '</dd></div>' +
      '<div><dt>信用点</dt><dd>+' + credits.toLocaleString('zh-CN') + '</dd></div><div><dt>陨石碎片</dt><dd>+' + R.shards + '</dd></div></dl>' +
      '<p class="note">奖励已存入舰队账户，可以在开放太空模式的星港里买船、召唤舰员。</p>' +
      '<div class="sv-btns"><button class="btn primary" id="sv-again">再来一局</button><button class="btn" id="sv-title">回到标题</button></div></div>');
    m.querySelector('#sv-again').onclick = function () { openPrep(); };
    m.querySelector('#sv-title').onclick = function () { R = null; A.showTitle(); };
  }
  var prepSel = [];
  function openPrep() {
    A.setMode('survivor'); R = null; paused = false;
    var save = A.save(), u = ui(); u.innerHTML = '';
    if (!prepSel.length) prepSel = save.crew.slice(0, 2);
    if (prepSel.length < 2) prepSel = prepSel.concat(G.crew.map(function (c) { return c.id; }).filter(function (id) { return prepSel.indexOf(id) < 0; }).slice(0, 2 - prepSel.length));
    var box = el('section', 'panel sv-prep');
    var html = '<h1>星海突围</h1><p class="sv-intro">在虫群与海贼的包围中坚持 8 分钟，击沉赤髑号。选择 2 位星魂少女随行，她们会在战斗中释放技能。</p><div class="sv-pick">';
    G.crew.forEach(function (c) {
      var own = save.crew.indexOf(c.id) >= 0, on = prepSel.indexOf(c.id) >= 0, k = CREW[c.id];
      html += '<button class="sv-pc' + (on ? ' on' : '') + '" data-id="' + c.id + '"><span class="ic">' + A.catIcon(c.id, 64) + '</span><div><b>' + c.name + (own ? '' : '<i>试用</i>') + '</b><span>' + k.skill + '</span><small>' + k.desc + '</small></div></button>';
    });
    html += '</div><div class="sv-btns"><button class="btn primary" id="sv-go">出击</button><button class="btn" id="sv-back">返回</button></div>';
    box.innerHTML = html; u.appendChild(box);
    box.querySelectorAll('.sv-pc').forEach(function (b) {
      b.onclick = function () {
        var id = b.dataset.id, i = prepSel.indexOf(id);
        if (i >= 0) prepSel.splice(i, 1); else { prepSel.push(id); if (prepSel.length > 2) prepSel.shift(); }
        openPrep();
      };
    });
    box.querySelector('#sv-go').onclick = function () { if (prepSel.length < 2) { A.toast('请选择 2 位舰员'); return; } start(prepSel.slice()); };
    box.querySelector('#sv-back').onclick = function () { A.showTitle(); };
  }
  function start(crewIds) {
    newRun(crewIds); paused = false; buildHUD();
    if (window.__game && window.__game.W && window.__game.W.god) R.god = true;
    A.toast('拖动屏幕任意位置移动，武器会自动开火');
  }

  // ------------------------------------------------------------------ 输入
  window.addEventListener('keydown', function (e) {
    if (A && A.mode() !== 'survivor') return;
    keys[e.code] = true;
    if (e.code === 'Escape' && R && !R.ended) openPause();
  });
  window.addEventListener('keyup', function (e) { keys[e.code] = false; });
  window.addEventListener('blur', function () { keys = {}; joy.id = null; joy.dx = joy.dy = 0; });
  function bindPointer() {
    var cv = E.canvas;
    cv.addEventListener('pointerdown', function (e) {
      if (A.mode() !== 'survivor' || !R || paused) return;
      var r = cv.getBoundingClientRect(); joy.id = e.pointerId; joy.cx = e.clientX - r.left; joy.cy = e.clientY - r.top; joy.dx = joy.dy = 0;
      cv.setPointerCapture(e.pointerId);
    });
    cv.addEventListener('pointermove', function (e) {
      if (e.pointerId !== joy.id) return;
      var r = cv.getBoundingClientRect(), x = e.clientX - r.left - joy.cx, y = e.clientY - r.top - joy.cy, R0 = 60 * Math.max(0.55, view().s * 1.5), l = Math.hypot(x, y);
      if (l > R0) { x = x / l * R0; y = y / l * R0; }
      joy.dx = x / R0; joy.dy = -y / R0;
    });
    function up(e) { if (e.pointerId === joy.id) { joy.id = null; joy.dx = joy.dy = 0; } }
    cv.addEventListener('pointerup', up); cv.addEventListener('pointercancel', up);
  }

  // ------------------------------------------------------------------ 对外接口
  function view() { return A.view(); }
  function frame(dt) {
    if (!R) { // 准备界面：缓慢旋转的背景
      var V = view();
      E.render({ env: ENV, eye: [Math.sin(performance.now() / 8000) * 30, 46, -30], target: [0, 0, 3], fov: A.fitFov(50, V.w / V.h), aspect: V.w / V.h, near: 1, far: 6000, draws: [], stars: stars || (stars = E.buildStars({ data: makeStars(), colors: [[0.92, 0.93, 1.0], [0.55, 0.95, 0.9], [1.0, 0.8, 0.5]] })), shadow: null });
      var cv = document.getElementById('hud2d'); cv.getContext('2d').clearRect(0, 0, cv.width, cv.height);
      return;
    }
    step(dt);
    render(); drawOverlay();
    if (!R.ended && hud.top) updateHUD(dt);
  }
  window.Survivor = {
    init: function (api) { A = api; G = window.GAME_DATA; bindPointer(); },
    open: openPrep, frame: frame,
    debug: {
      run: function () { return R; },
      start: start,
      step: function (n, dt) { for (var i = 0; i < n; i++) { step(dt || 1 / 30); if (paused && R && R.pendingLevels >= 0 && document.querySelector('.sv-card')) { document.querySelector('.sv-card').click(); } } },
      levelUp: function () { if (R) { R.pendingLevels++; } },
      move: function (dx, dy) { joy.dx = dx; joy.dy = dy; },
      skipTo: function (t) { if (R) { R.t = t; R.evIdx = 0; while (R.evIdx < EVENTS.length && EVENTS[R.evIdx].t < t - 1) R.evIdx++; } },
      god: function (on) { if (R) R.god = on; },
      clear: function () { if (R) R.enemies.filter(function (e) { return !e.d.boss; }).forEach(function (e) { e.hp = 0; killEnemy(e); }); if (R) R.enemies = R.enemies.filter(function (e) { return e.hp > 0; }); }
    }
  };
})();
