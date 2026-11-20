/* 陨星银河 · 游戏逻辑（HTML 版）
 * 飞行、战斗、采矿、停靠交易、任务、船坞、召唤、星图、存档、图鉴。
 * 与 scripts/game/*.lua 保持相同的规则与数值（数值来自 GAME_DATA）。
 */
(function () {
  'use strict';
  var E = window.VoxEngine;
  if (!E) return;
  var G = window.GAME_DATA, MODELS = window.VOX_MODELS, CATALOG = window.VOX_CATALOG, SC = window.VOX_SCENES;
  var T = G.tuning, DEG = Math.PI / 180, DESIGN_W = 1920, DESIGN_H = 1080, DESIGN_ASPECT = DESIGN_W / DESIGN_H;
  var SAVE_KEY = 'meteor-galaxy-save-v1';

  // ------------------------------------------------------------------ 工具
  function byId(list, id) { for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i]; return null; }
  function clamp(x, a, b) { return x < a ? a : x > b ? b : x; }
  function lerp(a, b, t) { return a + (b - a) * t; }
  function add(a, b) { return [a[0] + b[0], a[1] + b[1], a[2] + b[2]]; }
  function sub(a, b) { return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]; }
  function mul(a, s) { return [a[0] * s, a[1] * s, a[2] * s]; }
  function len(a) { return Math.hypot(a[0], a[1], a[2]); }
  function dist(a, b) { return Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]); }
  function norm(a) { var l = len(a) || 1; return [a[0] / l, a[1] / l, a[2] / l]; }
  function dot(a, b) { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }
  // UrhoX：Quaternion(pitch, yaw, roll)，pitch 为正时机头向下
  function fwdOf(yaw, pitch) { var cp = Math.cos(pitch * DEG); return [Math.sin(yaw * DEG) * cp, -Math.sin(pitch * DEG), Math.cos(yaw * DEG) * cp]; }
  function rightOf(yaw) { return [Math.cos(yaw * DEG), 0, -Math.sin(yaw * DEG)]; }
  function anglesTo(d) { var n = norm(d); return [Math.atan2(n[0], n[2]) / DEG, -Math.asin(clamp(n[1], -1, 1)) / DEG]; }
  function wrap180(a) { a = (a + 180) % 360; if (a < 0) a += 360; return a - 180; }
  function rand(a, b) { return a + Math.random() * (b - a); }
  function fmt(n) { return Math.round(n).toLocaleString('zh-CN'); }
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
  function el(tag, cls, html) { var e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; }
  var B36 = '0123456789abcdefghijklmnopqrstuvwxyz';
  function iconSVG(ic, px) {
    var w = ic.w, h = ic.h, out = '<svg class="pix" viewBox="0 0 ' + w + ' ' + h + '" width="' + px + '" height="' + (px * h / w) + '" shape-rendering="crispEdges" aria-hidden="true">';
    for (var j = 0; j < h; j++) for (var i = 0; i < w; i++) {
      var ch = ic.px[j * w + i]; if (ch === '.') continue;
      out += '<rect x="' + i + '" y="' + j + '" width="1.02" height="1.02" fill="' + ic.pal[B36.indexOf(ch)] + '"/>';
    }
    return out + '</svg>';
  }
  function catIcon(id, px) { var c = byId(CATALOG.items, id); return c ? iconSVG(c.icon, px) : ''; }
  function resIcon(id, px) { return iconSVG(SC.resIcons[id], px); }
  function sysById(id) { return byId(G.systems, id); }
  function stationById(id) {
    for (var i = 0; i < G.systems.length; i++) { var s = byId(G.systems[i].stations, id); if (s) return { st: s, sys: G.systems[i] }; }
    return null;
  }

  // ------------------------------------------------------------------ 存档与属性
  var save = null;
  function newSave() {
    var s = G.start;
    return { system: s.system, credits: s.credits, shards: s.shards, ship: s.ship, crew: s.crew.slice(), cargo: {},
      laser: s.laser, shieldGen: s.shieldGen, missiles: byId(G.ships, s.ship).missiles, hullDmg: 0,
      story: 0, active: null, dockedAt: 'ashfall', kills: 0, played: 0 };
  }
  function loadSave() { try { var t = localStorage.getItem(SAVE_KEY); return t ? JSON.parse(t) : null; } catch (e) { return null; } }
  function writeSave() { try { localStorage.setItem(SAVE_KEY, JSON.stringify(save)); } catch (e) { /* 存储不可用时只在本次会话内保留进度 */ } }
  function crewFx() {
    var fx = { laserDmg: 0, hull: 0, shieldRegen: 0, freeRepair: 0, mining: 0, cargo: 0, radar: 0, jumpShield: 0, missiles: 0, missileDmg: 0 };
    save.crew.forEach(function (id) { var c = byId(G.crew, id); for (var k in c.fx) fx[k] += c.fx[k]; });
    return fx;
  }
  function stats() {
    var sh = byId(G.ships, save.ship), fx = crewFx(), la = byId(G.lasers, save.laser), sg = byId(G.shields, save.shieldGen);
    return { ship: sh, hullMax: Math.round(sh.hull * (1 + fx.hull)), shieldMax: Math.round(sh.shield * sg.mult),
      regen: sg.regen * (1 + fx.shieldRegen), laserDmg: la.dmg * (1 + fx.laserDmg), rof: la.rof, guns: sh.guns,
      cargoCap: sh.cargo + fx.cargo, missileCap: sh.missiles + fx.missiles, missileDmg: G.missile.dmg * (1 + fx.missileDmg),
      radar: T.radarRange * (1 + fx.radar), mining: 1 + fx.mining, speed: sh.speed, turn: sh.turn, fx: fx };
  }
  function cargoUsed() { var n = 0; for (var k in save.cargo) n += save.cargo[k]; return n; }
  function addCargo(good, n) { save.cargo[good] = (save.cargo[good] || 0) + n; if (save.cargo[good] <= 0) delete save.cargo[good]; }
  function priceOf(stId, good, selling) {
    var s = stationById(stId).st, g = byId(G.goods, good), p = g.base * s.prices[good];
    return Math.max(1, Math.round(selling ? p * 0.9 : p));
  }

  // ------------------------------------------------------------------ 世界
  var W = { sys: null, ents: [], projs: [], parts: [], t: 0, player: null, stars: null, spawnTimer: 0, target: null, nav: null, auto: false };
  var nextId = 1;
  function ent(o) { o.id = nextId++; o.mesh = E.getMesh(o.model); o.radius = (o.mesh ? o.mesh.radius : 2) * (o.scale || 1); o.roll = o.roll || 0; o.pitch = o.pitch || 0; W.ents.push(o); return o; }
  function loadSystem(id, arrive) {
    var sys = sysById(id);
    W.sys = sys; W.ents = []; W.projs = []; W.parts = []; W.target = null; W.nav = null; W.auto = false; W.spawnTimer = 3;
    W.stars = sys._vao || (sys._vao = E.buildStars(sys.stars));
    sys.decor.forEach(function (d) { ent({ kind: 'decor', model: d.model, pos: d.pos.slice(), yaw: d.yaw, scale: d.scale, spin: d.spin }); });
    sys.stations.forEach(function (s) { ent({ kind: 'station', model: s.model, pos: s.pos.slice(), yaw: 0, scale: s.scale, spin: 3, name: s.name, st: s }); });
    sys.gates.forEach(function (g) { ent({ kind: 'gate', model: 'space_jumpgate', pos: g.pos.slice(), yaw: g.yaw, scale: 2.5, name: g.name, to: g.to }); });
    if (sys.base) ent({ kind: 'base', model: sys.base.model, pos: sys.base.pos.slice(), yaw: 0, scale: sys.base.scale, name: sys.base.name, spin: 1 });
    sys.asteroids.forEach(function (a) {
      var crystal = a.model === 'space_asteroid_b';
      ent({ kind: crystal ? 'crystal' : 'rock', model: a.model, pos: a.pos.slice(), yaw: a.yaw, pitch: a.pitch, scale: a.scale, spin: a.spin, hp: crystal ? 150 : 0 });
    });
    sys.ore.forEach(function (a) { ent({ kind: 'ore', model: a.model, pos: a.pos.slice(), yaw: a.yaw, pitch: a.pitch, scale: a.scale, spin: a.spin, hp: 70 }); });
    sys.derelicts.forEach(function (d) { ent({ kind: 'rock', model: d.model, pos: d.pos.slice(), yaw: d.yaw, scale: d.scale, spin: 0.5 }); });
    // 玩家
    var st = stats(), p;
    var spawnPos = sys.spawn.pos.slice(), spawnYaw = sys.spawn.yaw;
    if (arrive) {
      var g = byId(sys.gates.map(function (x) { return { id: x.to, g: x }; }), arrive);
      if (g) { var gf = fwdOf(g.g.yaw, 0); spawnPos = add(g.g.pos, mul(gf, 160)); spawnYaw = g.g.yaw; }
    }
    p = ent({ kind: 'player', model: save.ship, pos: spawnPos, yaw: spawnYaw, pitch: 0, scale: 1, speed: 0, throttle: 0.4,
      hull: st.hullMax - save.hullDmg, shield: st.shieldMax, shieldCd: 0, fireCd: 0, missileCd: 0, boost: 100, vel: [0, 0, 0], gunSide: 0 });
    if (arrive && st.fx.jumpShield === 0) p.shield = Math.min(p.shield, st.shieldMax * 0.5);
    W.player = p;
    // 首领
    if (sys.boss && save.story === 2) spawnPirate(sys.boss.type, sys.boss.pos, true);
    for (var i = 0; i < Math.min(2, sys.pirates.max); i++) spawnPirate(null);
    cam.pos = null;
    save.system = id;
  }
  function spawnPirate(type, pos, boss) {
    var sys = W.sys, pd = sys.pirates;
    type = type || pd.types[Math.floor(Math.random() * pd.types.length)];
    var base = pos || pd.spawns[Math.floor(Math.random() * pd.spawns.length)];
    var d = byId(G.enemies, type);
    var p = add(base, [rand(-150, 150), rand(-60, 60), rand(-150, 150)]);
    return ent({ kind: 'pirate', model: type, def: d, pos: p, yaw: rand(0, 360), pitch: 0, scale: 1, speed: d.speed * 0.6,
      hull: d.hull, shield: d.shield, shieldCd: 0, fireCd: rand(0.5, 2), state: 'patrol', home: p.slice(), wp: p.slice(), timer: 0, boss: !!boss, name: d.name, vel: [0, 0, 0] });
  }

  // ------------------------------------------------------------------ 输入
  var keys = {}, input = { sx: 0, sy: 0, fire: false, boost: false, joy: false };
  window.addEventListener('keydown', function (e) {
    if (e.target && (e.target.tagName === 'INPUT')) return;
    keys[e.code] = true;
    if (mode === 'flight') {
      if (e.code === 'KeyQ') fireMissile();
      if (e.code === 'KeyT') cycleTarget();
      if (e.code === 'KeyE') interact();
      if (e.code === 'KeyM') openMap();
      if (e.code === 'KeyG') toggleAuto();
      if (e.code === 'Escape') openPause();
      if (e.code === 'Space') e.preventDefault();
    } else if (e.code === 'Escape' && (mode === 'map' || mode === 'pause')) resumeFlight();
  });
  window.addEventListener('keyup', function (e) { keys[e.code] = false; });
  window.addEventListener('blur', function () { keys = {}; input.fire = false; input.boost = false; });

  // ------------------------------------------------------------------ 飞行逻辑
  function steerToward(p, dir, turn, dt) {
    var a = anglesTo(dir), dy = wrap180(a[0] - p.yaw), dp = a[1] - p.pitch;
    var maxStep = turn * dt;
    p.yaw += clamp(dy, -maxStep, maxStep); p.pitch = clamp(p.pitch + clamp(dp, -maxStep, maxStep), -80, 80);
    return [dy, dp];
  }
  function updatePlayer(dt) {
    var p = W.player, st = stats();
    var sx = input.sx, sy = input.sy;
    if (keys.KeyA || keys.ArrowLeft) sx = -1; if (keys.KeyD || keys.ArrowRight) sx = 1;
    if (keys.KeyW || keys.ArrowUp) sy = 1; if (keys.KeyS || keys.ArrowDown) sy = -1;
    if (keys.KeyR) p.throttle = clamp(p.throttle + dt * 0.8, 0, 1);
    if (keys.KeyF) p.throttle = clamp(p.throttle - dt * 0.8, 0, 1);
    var manual = Math.abs(sx) > 0.15 || Math.abs(sy) > 0.15;
    if (manual && W.auto) { W.auto = false; toast('自动导航已关闭'); }
    var rollTarget = 0;
    if (W.auto && W.nav) {
      var d = dist(p.pos, W.nav.pos), reach = W.nav.kind === 'gate' ? T.gateRange * 0.6 : W.nav.radius + T.dockRange * 0.6;
      var r = steerToward(p, sub(W.nav.pos, p.pos), st.turn, dt);
      rollTarget = clamp(-r[0], -30, 30);
      p.throttle = d < reach ? 0 : d < reach + 400 ? 0.35 : 1;
      if (d < reach) { W.auto = false; toast('已抵达 ' + W.nav.name); }
    } else {
      p.yaw += sx * st.turn * dt;
      p.pitch = clamp(p.pitch - sy * st.turn * 0.8 * dt, -80, 80);
      rollTarget = -sx * 35;
    }
    p.roll = lerp(p.roll, rollTarget, 1 - Math.exp(-dt * 5));
    var boosting = (input.boost || keys.ShiftLeft || keys.ShiftRight) && p.boost > 0;
    p.boost = clamp(p.boost + (boosting ? -T.boostDrain : T.boostRegen) * dt, 0, 100);
    var targetSpeed = p.throttle * st.speed * (boosting ? T.boostMult : 1);
    p.speed = lerp(p.speed, targetSpeed, 1 - Math.exp(-dt * 1.6));
    p.boosting = boosting;
    p.vel = mul(fwdOf(p.yaw, p.pitch), p.speed);
    p.pos = add(p.pos, mul(p.vel, dt));
    // 武器
    p.fireCd -= dt; p.missileCd -= dt;
    if ((input.fire || keys.Space) && p.fireCd <= 0) { firePlayerLaser(st); p.fireCd = 1 / st.rof; }
    // 护盾
    p.shieldCd -= dt;
    if (p.shieldCd <= 0) p.shield = Math.min(st.shieldMax, p.shield + st.regen * dt);
  }
  function aimDir(p) {
    var f = fwdOf(p.yaw, p.pitch), t = W.target;
    if (t && t.kind === 'pirate' && W.ents.indexOf(t) >= 0) {
      var d = dist(p.pos, t.pos);
      if (d < T.aimAssistRange) {
        var lead = add(t.pos, mul(t.vel, d / T.laserSpeed)), dir = norm(sub(lead, p.pos));
        if (dot(dir, f) > Math.cos(T.aimAssistDeg * DEG)) return dir;
      }
    }
    return f;
  }
  function firePlayerLaser(st) {
    var p = W.player, dir = aimDir(p), right = rightOf(p.yaw), f = fwdOf(p.yaw, p.pitch);
    for (var g = 0; g < st.guns; g++) {
      var side = st.guns === 1 ? 0 : (g === 0 ? -1 : 1);
      var origin = add(add(p.pos, mul(f, p.radius * 0.9)), mul(right, side * p.radius * 0.6));
      W.projs.push({ model: 'fx_laser_player', pos: origin, vel: add(mul(dir, T.laserSpeed), p.vel), life: T.laserLife, dmg: st.laserDmg, owner: 'player' });
    }
  }
  function fireMissile() {
    var p = W.player, st = stats();
    if (save.missiles <= 0) { toast('导弹已用完，到星港船坞补充'); return; }
    if (p.missileCd > 0) return;
    var t = W.target && W.target.kind === 'pirate' ? W.target : nearestEnemy(1200);
    save.missiles--; p.missileCd = 0.6;
    W.projs.push({ model: 'fx_missile', missile: true, pos: add(p.pos, mul(fwdOf(p.yaw, p.pitch), p.radius)), yaw: p.yaw, pitch: p.pitch,
      speed: G.missile.speed, life: 6, dmg: st.missileDmg, owner: 'player', target: t });
  }
  function nearestEnemy(range) {
    var best = null, bd = range;
    W.ents.forEach(function (e) { if (e.kind === 'pirate') { var d = dist(e.pos, W.player.pos); if (d < bd) { bd = d; best = e; } } });
    return best;
  }
  function cycleTarget() {
    var p = W.player, list = W.ents.filter(function (e) { return e.kind === 'pirate' && dist(e.pos, p.pos) < stats().radar; });
    list.sort(function (a, b) { return dist(a.pos, p.pos) - dist(b.pos, p.pos); });
    var navs = W.ents.filter(function (e) { return e.kind === 'station' || e.kind === 'gate' || e.kind === 'base'; });
    list = list.concat(navs);
    if (!list.length) return;
    var i = list.indexOf(W.target);
    W.target = list[(i + 1) % list.length];
    if (W.target.kind !== 'pirate') W.nav = W.target;
  }
  function toggleAuto() {
    if (!W.nav) { var t = W.target && W.target.kind !== 'pirate' ? W.target : null; W.nav = t || byKind('station'); }
    W.auto = !W.auto && !!W.nav;
    toast(W.auto ? '自动导航：前往 ' + W.nav.name : '自动导航已关闭');
  }
  function byKind(k) { for (var i = 0; i < W.ents.length; i++) if (W.ents[i].kind === k) return W.ents[i]; return null; }

  function updatePirates(dt) {
    var p = W.player;
    W.ents.forEach(function (e) {
      if (e.kind !== 'pirate') return;
      var d = e.def, toP = sub(p.pos, e.pos), dp = len(toP);
      e.timer -= dt; e.fireCd -= dt; e.shieldCd -= dt;
      if (e.shieldCd <= 0) e.shield = Math.min(d.shield, e.shield + d.shield * 0.08 * dt);
      var aggro = e.boss ? 1500 : 1100;
      if (e.state === 'patrol' && (dp < aggro || e.hurt)) e.state = 'attack';
      var dir, spd = d.speed;
      if (e.state === 'patrol') {
        if (dist(e.pos, e.wp) < 60 || e.timer <= 0) { e.wp = add(e.home, [rand(-400, 400), rand(-120, 120), rand(-400, 400)]); e.timer = 12; }
        dir = sub(e.wp, e.pos); spd = d.speed * 0.5;
      } else if (e.state === 'evade') {
        dir = e.evadeDir; if (e.timer <= 0) e.state = 'attack';
      } else {
        var lead = add(p.pos, mul(p.vel, dp / T.enemyLaserSpeed));
        dir = sub(lead, e.pos);
        if (dp < (e.boss ? 260 : 110)) { e.state = 'evade'; e.timer = rand(1.5, 2.6); e.evadeDir = norm(add(norm(sub(e.pos, p.pos)), [rand(-1, 1), rand(-0.6, 0.6), rand(-1, 1)])); }
        if (dp > 2600) e.state = 'patrol';
      }
      var r = steerToward(e, dir, d.turn, dt);
      e.roll = lerp(e.roll, clamp(-r[0], -40, 40), 1 - Math.exp(-dt * 4));
      e.speed = lerp(e.speed, spd, 1 - Math.exp(-dt));
      e.vel = mul(fwdOf(e.yaw, e.pitch), e.speed);
      e.pos = add(e.pos, mul(e.vel, dt));
      // 开火
      if (e.state === 'attack' && dp < d.range && e.fireCd <= 0) {
        var aim = norm(sub(add(p.pos, mul(p.vel, dp / T.enemyLaserSpeed)), e.pos));
        var cone = e.boss ? 0.6 : Math.cos(10 * DEG);
        if (dot(aim, fwdOf(e.yaw, e.pitch)) > cone) {
          var spread = [rand(-0.03, 0.03), rand(-0.03, 0.03), rand(-0.03, 0.03)];
          W.projs.push({ model: 'fx_laser_enemy', pos: add(e.pos, mul(aim, e.radius)), vel: mul(norm(add(aim, spread)), T.enemyLaserSpeed), life: 2.2, dmg: d.dmg, owner: 'enemy' });
          e.fireCd = 1 / d.rof * rand(0.8, 1.3);
        }
      }
    });
  }
  // 线段与球体相交
  function segHit(a, b, c, r) {
    var ab = sub(b, a), ac = sub(c, a), l2 = dot(ab, ab), t = l2 > 0 ? clamp(dot(ac, ab) / l2, 0, 1) : 0;
    return dist(add(a, mul(ab, t)), c) < r;
  }
  function updateProjectiles(dt) {
    var keep = [];
    W.projs.forEach(function (pr) {
      pr.life -= dt;
      if (pr.missile) {
        if (pr.target && W.ents.indexOf(pr.target) >= 0) steerToward(pr, sub(pr.target.pos, pr.pos), G.missile.turn, dt);
        pr.vel = mul(fwdOf(pr.yaw, pr.pitch), pr.speed);
        if (Math.random() < 0.6) spark(pr.pos, 'fx_spark', 1, 6, 0.4);
      }
      var a = pr.pos, b = add(pr.pos, mul(pr.vel, dt)), hit = null;
      for (var i = 0; i < W.ents.length && !hit; i++) {
        var e = W.ents[i];
        if (pr.owner === 'player' && (e.kind === 'pirate' || e.kind === 'ore' || e.kind === 'crystal' || e.kind === 'rock' || e.kind === 'station' || e.kind === 'base')) {
          if (segHit(a, b, e.pos, e.radius * (e.kind === 'pirate' ? 1.1 : 0.85))) hit = e;
        } else if (pr.owner === 'enemy' && (e.kind === 'player' || e.kind === 'rock')) {
          if (segHit(a, b, e.pos, e.radius * (e.kind === 'player' ? 1.2 : 0.85))) hit = e;
        }
      }
      pr.pos = b;
      if (hit) { damage(hit, pr.dmg, pr.pos); spark(pr.pos, pr.owner === 'player' ? 'fx_spark_teal' : 'fx_spark', pr.missile ? 18 : 4, pr.missile ? 30 : 15, 0.5); return; }
      if (pr.life > 0) keep.push(pr);
    });
    W.projs = keep;
  }
  function damage(e, amount, at) {
    if (e.kind === 'player' && W.god) return;
    if (e.kind === 'pirate' || e.kind === 'player') {
      e.shieldCd = T.shieldDelay;
      var s = Math.min(e.shield, amount); e.shield -= s; e.hull -= amount - s;
      if (s > 0) spark(at, 'fx_shield', 3, 10, 0.3);
      if (e.kind === 'pirate') e.hurt = true;
      if (e.kind === 'player') { save.hullDmg = Math.max(0, stats().hullMax - e.hull); flashHit(); }
      if (e.hull <= 0) destroy(e);
    } else if (e.kind === 'ore' || e.kind === 'crystal') {
      e.hp -= amount;
      if (e.hp <= 0) destroy(e);
    }
  }
  function destroy(e) {
    explode(e.pos, e.radius);
    W.ents.splice(W.ents.indexOf(e), 1);
    if (W.target === e) W.target = null;
    if (e.kind === 'player') { gameOver(); return; }
    if (e.kind === 'pirate') {
      save.credits += e.def.bounty; save.kills++;
      toast('击落 ' + e.name + '，赏金 ' + fmt(e.def.bounty));
      var m = save.active;
      if (m && m.kind === 'bounty' && m.system === W.sys.id) { m.progress = (m.progress || 0) + 1; if (m.progress >= m.count) toast('任务目标完成：回到 ' + stationById(m.giver).st.name + ' 交付'); }
      if (e.boss) { if (m && m.kind === 'boss') { m.progress = 1; toast('赤髑号已被击沉！回到星港交付任务'); } dropLoot(e.pos, { shards: 3 }); dropLoot(e.pos, { credits: 2000 }); }
      var roll = Math.random();
      if (roll < 0.25) dropLoot(e.pos, { shards: 1 });
      else if (roll < 0.7) { var gd = G.goods[Math.floor(Math.random() * G.goods.length)].id; dropLoot(e.pos, { good: gd, n: 1 + Math.floor(Math.random() * 3) }); }
      else dropLoot(e.pos, { credits: 100 + Math.floor(Math.random() * 300) });
    } else if (e.kind === 'ore') {
      var n = 2 + Math.floor(Math.random() * 2);
      for (var i = 0; i < n; i++) dropLoot(e.pos, { good: 'ore', n: Math.round(2 * stats().mining) });
    } else if (e.kind === 'crystal') {
      if (Math.random() < 0.45) dropLoot(e.pos, { shards: 1 });
      dropLoot(e.pos, { good: 'ore', n: 2 });
    }
  }
  function dropLoot(at, contents) {
    ent({ kind: 'loot', model: 'prop_loot_pod', pos: add(at, [rand(-8, 8), rand(-8, 8), rand(-8, 8)]), yaw: rand(0, 360), scale: 2.2, spin: 60,
      vel: [rand(-6, 6), rand(-6, 6), rand(-6, 6)], contents: contents, life: 90, name: '漂浮货舱' });
  }
  function updateLoot(dt) {
    var p = W.player, st = stats();
    for (var i = W.ents.length - 1; i >= 0; i--) {
      var e = W.ents[i]; if (e.kind !== 'loot') continue;
      e.life -= dt; var d = dist(e.pos, p.pos);
      if (d < T.magnetRange) e.vel = mul(norm(sub(p.pos, e.pos)), 40 + (T.magnetRange - d));
      e.pos = add(e.pos, mul(e.vel, dt)); e.vel = mul(e.vel, 0.98);
      if (d < T.pickupRange + p.radius) {
        var c = e.contents, msg;
        if (c.shards) { save.shards += c.shards; msg = '获得陨石碎片 x' + c.shards; }
        else if (c.credits) { save.credits += c.credits; msg = '获得信用点 ' + fmt(c.credits); }
        else {
          var room = st.cargoCap - cargoUsed();
          if (room <= 0) { if (!e.warned) { toast('货舱已满'); e.warned = true; } continue; }
          var n = Math.min(room, c.n); addCargo(c.good, n); msg = '获得' + byId(G.goods, c.good).name + ' x' + n;
        }
        toast(msg); W.ents.splice(i, 1); continue;
      }
      if (e.life <= 0) W.ents.splice(i, 1);
    }
  }
  function updateCollisions(dt) {
    var p = W.player;
    W.ents.forEach(function (e) {
      if (e === p || e.kind === 'loot' || e.kind === 'decor' || e.kind === 'gate') return;
      var d = dist(e.pos, p.pos), r = e.radius * (e.kind === 'pirate' ? 1 : 0.8) + p.radius * 0.7;
      if (d < r && d > 0.001) {
        var n = norm(sub(p.pos, e.pos));
        p.pos = add(e.pos, mul(n, r));
        if (p.speed > 25 && !p.bumpCd) { damage(p, p.speed * 0.25, p.pos); p.bumpCd = 0.8; }
        p.speed *= 0.4;
      }
    });
    if (p.bumpCd) { p.bumpCd -= dt; if (p.bumpCd <= 0) p.bumpCd = 0; }
  }
  function spark(at, model, n, spd, life) {
    for (var i = 0; i < n && W.parts.length < 400; i++) {
      W.parts.push({ model: model, pos: at.slice(), vel: [rand(-1, 1) * spd, rand(-1, 1) * spd, rand(-1, 1) * spd], life: life * rand(0.6, 1.2), max: life, size: rand(1.5, 3) });
    }
  }
  function explode(at, radius) {
    var k = clamp(radius / 3, 1, 6);
    spark(at, 'fx_spark', Math.round(30 * k), 25 * k, 1.1);
    spark(at, 'fx_debris', Math.round(20 * k), 18 * k, 2.2);
    spark(at, 'fx_spark_teal', Math.round(8 * k), 12 * k, 0.8);
  }
  function updateParticles(dt) {
    W.parts = W.parts.filter(function (pa) { pa.life -= dt; pa.pos = add(pa.pos, mul(pa.vel, dt)); pa.vel = mul(pa.vel, 0.97); return pa.life > 0; });
  }
  function updateSpawns(dt) {
    var n = W.ents.filter(function (e) { return e.kind === 'pirate' && !e.boss; }).length;
    if (n < W.sys.pirates.max) { W.spawnTimer -= dt; if (W.spawnTimer <= 0) { spawnPirate(null); W.spawnTimer = T.respawnDelay * rand(0.6, 1.4); } }
  }
  // 可交互对象（停靠 / 跃迁）
  function interactable() {
    var p = W.player, best = null;
    W.ents.forEach(function (e) {
      if (e.kind === 'station' && dist(e.pos, p.pos) < e.radius + T.dockRange) best = e;
      if (e.kind === 'gate' && dist(e.pos, p.pos) < T.gateRange + e.radius * 0.4) best = e;
    });
    return best;
  }
  function interact() {
    var e = interactable(); if (!e) return;
    if (e.kind === 'station') dock(e.st.id);
    else jump(e.to);
  }

  // ------------------------------------------------------------------ 相机
  var cam = { pos: null, fov: 62 };
  function updateCamera(dt) {
    var p = W.player, f = fwdOf(p.yaw, p.pitch), D = p.radius * 2.4 + 5, H = p.radius * 0.75 + 1.2;
    var desired = add(add(p.pos, mul(f, -D)), [0, H, 0]);
    cam.pos = cam.pos ? add(cam.pos, mul(sub(desired, cam.pos), 1 - Math.exp(-dt * 7))) : desired;
    cam.target = add(p.pos, mul(f, 24));
    cam.fov = lerp(cam.fov, p.boosting ? 72 : 62, 1 - Math.exp(-dt * 3));
  }

  // ------------------------------------------------------------------ 渲染
  var view = { w: 1, h: 1, s: 1, safe: [0, 0, 0, 0] }, lastVP = null;
  function fitFov(fov, aspect) { return aspect >= DESIGN_ASPECT ? fov : 2 * Math.atan(Math.tan(fov * DEG / 2) * DESIGN_ASPECT / aspect) / DEG; }
  function drawsFor(list, t) {
    var out = [];
    list.forEach(function (e) {
      if (!e.mesh) return;
      var yaw = e.yaw + (e.spin || 0) * t * (e.kind === 'loot' ? 1 : 1);
      out.push({ mesh: e.mesh, m: E.trs(e.pos, e.kind === 'pirate' || e.kind === 'player' ? e.yaw : yaw, e.pitch || 0, e.roll || 0, e.scale || 1), s: e.scale || 1 });
    });
    return out;
  }
  function renderWorld(eye, target, fov) {
    var t = W.t, draws = drawsFor(W.ents, t);
    W.projs.forEach(function (pr) {
      var a = pr.missile ? [pr.yaw, pr.pitch] : anglesTo(pr.vel);
      draws.push({ mesh: E.getMesh(pr.model), m: E.trs(pr.pos, a[0], a[1], 0, pr.missile ? 3 : 3.2), s: 3 });
    });
    W.parts.forEach(function (pa) {
      var s = pa.size * clamp(pa.life / pa.max, 0.15, 1) * 2;
      draws.push({ mesh: E.getMesh(pa.model), m: E.trs(pa.pos, pa.life * 200, pa.life * 140, 0, s), s: s });
    });
    lastVP = E.render({ env: W.sys.env, eye: eye, target: target, fov: fitFov(fov, view.w / view.h), aspect: view.w / view.h,
      near: 0.5, far: 9000, draws: draws, stars: W.stars, shadow: null });
  }

  // ------------------------------------------------------------------ 画面布局（与 Layout.lua 一致）
  var app = document.getElementById('app'), stage = document.getElementById('stage'), ui = document.getElementById('ui');
  var hud2d = document.getElementById('hud2d'), ctx = hud2d.getContext('2d'), probe = document.getElementById('safe-probe');
  var quality = 'high';
  function layout() {
    var w = app.clientWidth, h = app.clientHeight, cs = getComputedStyle(probe);
    var safe = [parseFloat(cs.paddingLeft) || 0, parseFloat(cs.paddingRight) || 0, parseFloat(cs.paddingTop) || 0, parseFloat(cs.paddingBottom) || 0];
    stage.style.width = w + 'px'; stage.style.height = h + 'px';
    var s = Math.min(w / DESIGN_W, h / DESIGN_H);
    view = { w: w, h: h, s: s, safe: safe };
    ui.style.width = (w / s) + 'px'; ui.style.height = (h / s) + 'px'; ui.style.transform = 'scale(' + s + ')';
    ui.style.setProperty('--safe-l', (safe[0] / s) + 'px'); ui.style.setProperty('--safe-r', (safe[1] / s) + 'px');
    ui.style.setProperty('--safe-t', (safe[2] / s) + 'px'); ui.style.setProperty('--safe-b', (safe[3] / s) + 'px');
    var dpr = Math.min(window.devicePixelRatio || 1, quality === 'high' ? 2 : 1);
    E.resize(Math.max(1, Math.round(w * dpr)), Math.max(1, Math.round(h * dpr)));
    E.canvas.style.width = w + 'px'; E.canvas.style.height = h + 'px';
    hud2d.width = Math.round(w * dpr); hud2d.height = Math.round(h * dpr); hud2d.style.width = w + 'px'; hud2d.style.height = h + 'px';
    view.dpr = dpr;
  }
  window.addEventListener('resize', layout);
  new ResizeObserver(layout).observe(app);

  // ------------------------------------------------------------------ HUD（DOM + 2D 画布）
  var mode = 'title', hud = {}, toastTimer = null;
  function toast(msg) {
    var t = document.getElementById('toast'); t.textContent = msg; t.hidden = false;
    clearTimeout(toastTimer); toastTimer = setTimeout(function () { t.hidden = true; }, 2600);
  }
  function flashHit() { var f = document.getElementById('hitflash'); f.style.opacity = 0.55; setTimeout(function () { f.style.opacity = 0; }, 90); }
  function bar(cls) { return '<div class="bar ' + cls + '"><i></i></div>'; }
  function buildFlightHUD() {
    ui.innerHTML = '';
    var tl = el('section', 'panel h-status');
    tl.innerHTML = '<div class="h-row"><span class="h-lab">护盾</span>' + bar('sh') + '</div><div class="h-row"><span class="h-lab">船体</span>' + bar('hp') + '</div>' +
      '<div class="h-row"><span class="h-lab">加速</span>' + bar('bo') + '</div>' +
      '<div class="h-meta"><span class="h-spd"></span><span class="h-cr">' + resIcon('credit', 34) + '<b></b></span><span class="h-sd">' + resIcon('shard', 34) + '<b></b></span></div>';
    ui.appendChild(tl);
    var obj = el('section', 'h-obj'); obj.innerHTML = '<b class="h-sys"></b><span class="h-mis"></span>'; ui.appendChild(obj);
    var tg = el('section', 'panel h-target'); tg.innerHTML = '<b class="t-name"></b><span class="t-dist"></span>' + bar('tsh') + bar('thp'); tg.hidden = true; ui.appendChild(tg);
    var menu = el('div', 'h-menu');
    [['地图', openMap], ['暂停', openPause]].forEach(function (b) { var x = el('button', 'sbtn', b[0]); x.onclick = b[1]; menu.appendChild(x); });
    ui.appendChild(menu);
    // 油门
    var thr = el('div', 'throttle'); thr.innerHTML = '<span class="thr-lab">油门</span><div class="thr-track"><i class="thr-fill"></i><i class="thr-knob"></i></div>';
    ui.appendChild(thr);
    var track = thr.querySelector('.thr-track');
    function setThr(ev) { var r = track.getBoundingClientRect(); W.player.throttle = clamp(1 - (ev.clientY - r.top) / r.height, 0, 1); }
    track.addEventListener('pointerdown', function (ev) { track.setPointerCapture(ev.pointerId); setThr(ev); });
    track.addEventListener('pointermove', function (ev) { if (track.hasPointerCapture(ev.pointerId)) setThr(ev); });
    // 摇杆
    var zone = el('div', 'joyzone'), base = el('div', 'joy-base'), knob = el('div', 'joy-knob');
    zone.appendChild(base); zone.appendChild(knob); ui.appendChild(zone);
    var joyId = null, jc = [0, 0];
    function toDesign(ev) { var r = ui.getBoundingClientRect(); return [(ev.clientX - r.left) / view.s, (ev.clientY - r.top) / view.s]; }
    zone.addEventListener('pointerdown', function (ev) {
      zone.setPointerCapture(ev.pointerId); joyId = ev.pointerId; jc = toDesign(ev);
      var zr = zone.getBoundingClientRect(), zx = (zr.left - ui.getBoundingClientRect().left) / view.s, zy = (zr.top - ui.getBoundingClientRect().top) / view.s;
      base.style.left = (jc[0] - zx) + 'px'; base.style.top = (jc[1] - zy) + 'px'; knob.style.left = base.style.left; knob.style.top = base.style.top;
      zone.classList.add('on');
    });
    zone.addEventListener('pointermove', function (ev) {
      if (ev.pointerId !== joyId) return;
      var p = toDesign(ev), dx = p[0] - jc[0], dy = p[1] - jc[1], l = Math.hypot(dx, dy), R = 130;
      if (l > R) { dx = dx / l * R; dy = dy / l * R; }
      input.sx = dx / R; input.sy = -dy / R;
      knob.style.transform = 'translate(' + dx + 'px,' + dy + 'px)';
    });
    function joyEnd(ev) { if (ev.pointerId !== joyId) return; joyId = null; input.sx = 0; input.sy = 0; knob.style.transform = ''; zone.classList.remove('on'); }
    zone.addEventListener('pointerup', joyEnd); zone.addEventListener('pointercancel', joyEnd);
    // 右下按钮
    var pad = el('div', 'actpad');
    function hold(cls, label, on, off) {
      var b = el('button', 'abtn ' + cls, label);
      b.addEventListener('pointerdown', function (ev) { b.setPointerCapture(ev.pointerId); b.classList.add('down'); on(); });
      function up() { b.classList.remove('down'); if (off) off(); }
      b.addEventListener('pointerup', up); b.addEventListener('pointercancel', up);
      pad.appendChild(b); return b;
    }
    hold('fire', '开火', function () { input.fire = true; }, function () { input.fire = false; });
    hud.missile = hold('missile', '导弹<small></small>', fireMissile);
    hold('boost', '加速', function () { input.boost = true; }, function () { input.boost = false; });
    hold('tgt', '目标', cycleTarget);
    hud.auto = hold('auto', '导航', toggleAuto);
    ui.appendChild(pad);
    var act = el('button', 'btn primary interact'); act.hidden = true; act.onclick = interact; ui.appendChild(act);
    hud.root = ui; hud.tl = tl; hud.obj = obj; hud.tg = tg; hud.act = act; hud.thr = thr; hud.t = 0;
  }
  function setBar(root, cls, v) { var i = root.querySelector('.bar.' + cls + ' i'); if (i) i.style.width = clamp(v * 100, 0, 100) + '%'; }
  function missionLine() {
    var m = save.active;
    if (!m) return save.story < G.story.length ? '主线：前往 ' + stationById(G.story[save.story].giver).st.name + ' 接取「' + G.story[save.story].title + '」' : '自由航行：跑商、采矿、清剿海贼';
    if (m.kind === 'deliver') return m.title + '：把 ' + m.count + ' 箱' + byId(G.goods, m.good).name + '送到 ' + stationById(m.target).st.name + '（' + sysById(stationById(m.target).sys.id).name + '）';
    if (m.kind === 'bounty') return m.title + '：在' + sysById(m.system).name + '击落海贼 ' + Math.min(m.progress || 0, m.count) + ' / ' + m.count;
    if (m.kind === 'mining') return m.title + '：带 ' + m.count + ' 箱矿石回 ' + stationById(m.giver).st.name + '（货舱 ' + (save.cargo.ore || 0) + '）';
    if (m.kind === 'boss') return m.title + '：' + (m.progress ? '回到星港交付' : '前往赤环星系，击沉赤髑号');
    return '';
  }
  function updateFlightHUD(dt) {
    var p = W.player, st = stats();
    hud.t -= dt;
    setBar(hud.tl, 'sh', p.shield / st.shieldMax); setBar(hud.tl, 'hp', p.hull / st.hullMax); setBar(hud.tl, 'bo', p.boost / 100);
    hud.root.querySelector('.thr-fill').style.height = (p.throttle * 100) + '%';
    hud.root.querySelector('.thr-knob').style.bottom = 'calc(' + (p.throttle * 100) + '% - 18px)';
    var t = W.target && W.ents.indexOf(W.target) >= 0 ? W.target : null;
    if (!t) W.target = null;
    hud.tg.hidden = !t;
    if (t) {
      hud.tg.querySelector('.t-name').textContent = t.name || '';
      hud.tg.querySelector('.t-dist').textContent = fmt(dist(t.pos, p.pos)) + ' 米';
      var hasHp = t.kind === 'pirate';
      hud.tg.classList.toggle('nav', !hasHp);
      if (hasHp) { setBar(hud.tg, 'tsh', t.shield / t.def.shield); setBar(hud.tg, 'thp', t.hull / t.def.hull); }
    }
    var it = interactable();
    hud.act.hidden = !it;
    if (it) hud.act.textContent = it.kind === 'station' ? '停靠 ' + it.name : '跃迁 ' + sysById(it.to).name;
    hud.auto.classList.toggle('on', W.auto);
    if (hud.t <= 0) {
      hud.t = 0.15;
      hud.tl.querySelector('.h-spd').textContent = '航速 ' + Math.round(p.speed) + ' 米/秒';
      hud.tl.querySelector('.h-cr b').textContent = fmt(save.credits);
      hud.tl.querySelector('.h-sd b').textContent = save.shards;
      hud.missile.querySelector('small').textContent = save.missiles;
      hud.obj.querySelector('.h-sys').textContent = W.sys.name;
      hud.obj.querySelector('.h-mis').textContent = missionLine();
    }
  }
  // 2D 叠加层：准星、目标框、导航标记、雷达
  function drawHud2d() {
    var c = ctx, dpr = view.dpr, w = view.w, h = view.h, s = view.s;
    c.setTransform(1, 0, 0, 1, 0, 0); c.clearRect(0, 0, hud2d.width, hud2d.height);
    if (mode !== 'flight' || !lastVP) return;
    c.setTransform(dpr, 0, 0, dpr, 0, 0);
    var p = W.player, st = stats(), u = Math.max(0.6, s * 1.6);
    // 准星：机头前 300 米处
    var aim = E.project(lastVP, add(p.pos, mul(fwdOf(p.yaw, p.pitch), 300)), w, h);
    if (aim) {
      c.strokeStyle = 'rgba(237,230,214,.85)'; c.lineWidth = 2 * u;
      var a = 14 * u; c.beginPath();
      c.moveTo(aim[0] - a, aim[1]); c.lineTo(aim[0] - a / 3, aim[1]); c.moveTo(aim[0] + a / 3, aim[1]); c.lineTo(aim[0] + a, aim[1]);
      c.moveTo(aim[0], aim[1] - a); c.lineTo(aim[0], aim[1] - a / 3); c.moveTo(aim[0], aim[1] + a / 3); c.lineTo(aim[0], aim[1] + a); c.stroke();
    }
    c.font = '700 ' + Math.round(12 * u) + 'px "Noto Sans SC", "PingFang SC", sans-serif'; c.textAlign = 'center';
    W.ents.forEach(function (e) {
      var nav = e.kind === 'station' || e.kind === 'gate' || e.kind === 'base', enemy = e.kind === 'pirate', loot = e.kind === 'loot';
      if (!nav && !enemy && !loot) return;
      var d = dist(e.pos, p.pos);
      if ((enemy || loot) && d > st.radar) return;
      var sp = E.project(lastVP, e.pos, w, h), isT = e === W.target;
      var col = enemy ? '#E0458C' : loot ? '#5CF2DC' : (isT ? '#F5A524' : 'rgba(237,230,214,.75)');
      if (!sp || sp[0] < 0 || sp[0] > w || sp[1] < 0 || sp[1] > h) {
        if (!isT) return;
        // 屏幕外目标：边缘箭头
        var rel = sub(e.pos, p.pos), f = fwdOf(p.yaw, p.pitch), r = rightOf(p.yaw), upv = [Math.sin(p.yaw * DEG) * Math.sin(p.pitch * DEG), Math.cos(p.pitch * DEG), Math.cos(p.yaw * DEG) * Math.sin(p.pitch * DEG)];
        var ax = dot(rel, r), ay = dot(rel, upv), ang = Math.atan2(-ay, ax), R = Math.min(w, h) * 0.38;
        var ex = w / 2 + Math.cos(ang) * R, ey = h / 2 + Math.sin(ang) * R;
        c.save(); c.translate(ex, ey); c.rotate(ang); c.fillStyle = col; c.beginPath(); c.moveTo(14 * u, 0); c.lineTo(-8 * u, -9 * u); c.lineTo(-8 * u, 9 * u); c.fill(); c.restore();
        return;
      }
      var size = clamp(e.radius * 900 / Math.max(1, sp[2]) * s * 1.2, 10 * u, 90 * u);
      c.strokeStyle = col; c.lineWidth = (isT ? 3 : 2) * u;
      if (loot) { c.beginPath(); c.moveTo(sp[0], sp[1] - 7 * u); c.lineTo(sp[0] + 7 * u, sp[1]); c.lineTo(sp[0], sp[1] + 7 * u); c.lineTo(sp[0] - 7 * u, sp[1]); c.closePath(); c.stroke(); return; }
      var k = size * 0.35; c.beginPath();
      [[-1, -1], [1, -1], [1, 1], [-1, 1]].forEach(function (q) {
        var x = sp[0] + q[0] * size, y = sp[1] + q[1] * size;
        c.moveTo(x, y - q[1] * k); c.lineTo(x, y); c.lineTo(x - q[0] * k, y);
      });
      c.stroke();
      if (nav || isT) { c.fillStyle = col; c.fillText((e.name || '') + '  ' + fmt(d) + ' 米', sp[0], sp[1] + size + 16 * u); }
      if (isT && enemy) {
        var lead = E.project(lastVP, add(e.pos, mul(e.vel, d / T.laserSpeed)), w, h);
        if (lead) { c.beginPath(); c.arc(lead[0], lead[1], 6 * u, 0, Math.PI * 2); c.stroke(); }
      }
    });
    // 雷达（右上角）
    var R = 120 * s, cx = w - view.safe[1] - (36 + 140) * s, cy = view.safe[2] + (36 + 130) * s;
    c.fillStyle = 'rgba(9,12,34,.72)'; c.strokeStyle = 'rgba(92,242,220,.5)'; c.lineWidth = 2 * s;
    c.beginPath(); c.arc(cx, cy, R, 0, Math.PI * 2); c.fill(); c.stroke();
    c.beginPath(); c.arc(cx, cy, R * 0.5, 0, Math.PI * 2); c.stroke();
    c.fillStyle = '#F5A524'; c.beginPath(); c.moveTo(cx, cy - 9 * s); c.lineTo(cx + 7 * s, cy + 7 * s); c.lineTo(cx - 7 * s, cy + 7 * s); c.fill();
    var rr = rightOf(p.yaw), ff = [Math.sin(p.yaw * DEG), 0, Math.cos(p.yaw * DEG)];
    W.ents.forEach(function (e) {
      var col = e.kind === 'pirate' ? '#E0458C' : e.kind === 'loot' ? '#5CF2DC' : e.kind === 'station' ? '#F5A524' : e.kind === 'gate' ? '#9DF7EC' : e.kind === 'base' ? '#FF4D6A' : null;
      if (!col) return;
      var rel = sub(e.pos, p.pos), x = dot(rel, rr) / st.radar, z = dot(rel, ff) / st.radar, l = Math.hypot(x, z);
      if (l > 1) { if (e.kind === 'pirate' || e.kind === 'loot') return; x /= l; z /= l; }
      var sz = (e.kind === 'station' || e.kind === 'gate' || e.kind === 'base' ? 7 : 4.5) * s;
      c.fillStyle = col; c.fillRect(cx + x * R - sz / 2, cy - z * R - sz / 2, sz, sz);
    });
  }

  // ------------------------------------------------------------------ 星港
  var stationTab = 'trade', sideMissions = {};
  function dock(stId) {
    save.dockedAt = stId; W.auto = false;
    var st = stats();
    if (st.fx.freeRepair) save.hullDmg = 0;
    W.player.hull = st.hullMax - save.hullDmg;
    checkMissionOnDock(stId);
    if (!sideMissions[stId]) sideMissions[stId] = genSide(stId);
    writeSave();
    mode = 'station'; stationTab = 'trade'; renderStation();
  }
  function genSide(stId) {
    var here = stationById(stId), out = [], others = [];
    G.systems.forEach(function (s) { s.stations.forEach(function (x) { if (x.id !== stId) others.push(x); }); });
    var tgt = others[Math.floor(Math.random() * others.length)];
    var good = G.goods[Math.floor(Math.random() * 4)];
    out.push({ id: 'side-d-' + Date.now(), kind: 'deliver', title: '加急货运', giver: stId, good: good.id, count: 4 + Math.floor(Math.random() * 5), target: tgt.id, provide: true,
      reward: 900 + Math.floor(Math.random() * 6) * 150, shards: 0, text: '商会需要把一批' + good.name + '送到 ' + tgt.name + '，货物由我们提供。' });
    var bsys = here.sys.pirates.max > 0 ? here.sys : sysById('rubble');
    out.push({ id: 'side-b-' + Date.now(), kind: 'bounty', title: '清剿海贼', giver: stId, system: bsys.id, count: 2 + Math.floor(Math.random() * 3),
      reward: 1200 + Math.floor(Math.random() * 5) * 200, shards: Math.random() < 0.4 ? 1 : 0, text: '在' + bsys.name + '击落海贼船，回到这里领取赏金。' });
    out.push({ id: 'side-m-' + Date.now(), kind: 'mining', title: '矿石订单', giver: stId, count: 6 + Math.floor(Math.random() * 7),
      reward: 700 + Math.floor(Math.random() * 6) * 120, shards: Math.random() < 0.3 ? 1 : 0, text: '工坊急需矿石。去小行星带击碎富矿小行星，带矿石回来。' });
    return out;
  }
  function availableMissions(stId) {
    var list = [];
    if (save.story < G.story.length && G.story[save.story].giver === stId) list.push(Object.assign({ story: true }, G.story[save.story]));
    return list.concat(sideMissions[stId] || []);
  }
  function acceptMission(m) {
    if (save.active) { toast('先完成或放弃当前任务'); return; }
    if (m.provide) {
      var room = stats().cargoCap - cargoUsed();
      if (room < m.count) { toast('货舱空间不足，需要 ' + m.count + ' 格'); return; }
      addCargo(m.good, m.count);
    }
    save.active = JSON.parse(JSON.stringify(m)); save.active.progress = 0;
    if (!m.story) sideMissions[m.giver] = (sideMissions[m.giver] || []).filter(function (x) { return x.id !== m.id; });
    toast('已接受任务：' + m.title); writeSave(); renderStation();
  }
  function completeMission(m) {
    save.credits += m.reward; save.shards += m.shards || 0;
    toast('任务完成：' + m.title + '，获得 ' + fmt(m.reward) + ' 信用点' + (m.shards ? '、陨石碎片 x' + m.shards : ''));
    if (m.story) save.story++;
    save.active = null;
  }
  function checkMissionOnDock(stId) {
    var m = save.active; if (!m) return;
    if (m.kind === 'deliver' && m.target === stId && (save.cargo[m.good] || 0) >= m.count) { addCargo(m.good, -m.count); completeMission(m); }
    else if (m.kind === 'mining' && m.giver === stId && (save.cargo.ore || 0) >= m.count) { addCargo('ore', -m.count); completeMission(m); }
    else if ((m.kind === 'bounty' && (m.progress || 0) >= m.count) || (m.kind === 'boss' && m.progress)) completeMission(m);
  }
  function renderStation() {
    var info = stationById(save.dockedAt), st = stats();
    ui.innerHTML = '';
    var head = el('header', 'st-head');
    head.innerHTML = '<div><h1>' + esc(info.st.name) + '</h1><span>' + esc(info.sys.name) + '，危险度 ' + esc(info.sys.danger) + '</span></div>' +
      '<div class="st-res"><span>' + resIcon('credit', 40) + '<b>' + fmt(save.credits) + '</b></span><span class="is-shard">' + resIcon('shard', 40) + '<b>' + save.shards + '</b></span>' +
      '<span>' + resIcon('supply', 40) + '<b>' + cargoUsed() + ' / ' + st.cargoCap + '</b></span></div>';
    ui.appendChild(head);
    var nav = el('nav', 'st-nav');
    [['trade', '交易所'], ['missions', '任务板'], ['yard', '船坞'], ['crew', '舰员召唤']].forEach(function (t) {
      var b = el('button', 'st-tab' + (stationTab === t[0] ? ' on' : ''), t[1]); b.onclick = function () { stationTab = t[0]; renderStation(); }; nav.appendChild(b);
    });
    var launch = el('button', 'btn primary st-launch', '起飞'); launch.onclick = undock; nav.appendChild(launch);
    ui.appendChild(nav);
    var body = el('section', 'panel st-body'); ui.appendChild(body);
    if (stationTab === 'trade') renderTrade(body, info);
    else if (stationTab === 'missions') renderMissions(body, info);
    else if (stationTab === 'yard') renderYard(body, info);
    else renderCrew(body);
  }
  function renderTrade(body, info) {
    var st = stats(), html = '<table class="tbl"><thead><tr><th>商品</th><th>买入价</th><th>卖出价</th><th>货舱</th><th></th></tr></thead><tbody>';
    G.goods.forEach(function (g) {
      var bp = priceOf(info.st.id, g.id, false), sp = priceOf(info.st.id, g.id, true), have = save.cargo[g.id] || 0;
      var tag = info.st.prices[g.id] <= 0.75 ? '<em class="cheap">低价</em>' : info.st.prices[g.id] >= 1.3 ? '<em class="dear">高价</em>' : '';
      html += '<tr><td><b>' + g.name + '</b>' + tag + '<small>' + esc(g.desc) + '</small></td><td>' + bp + '</td><td>' + sp + '</td><td>' + have + '</td><td class="ops">' +
        '<button class="mini" data-a="buy" data-g="' + g.id + '" data-n="1">买 1</button><button class="mini" data-a="buy" data-g="' + g.id + '" data-n="5">买 5</button>' +
        '<button class="mini alt" data-a="sell" data-g="' + g.id + '" data-n="1">卖 1</button><button class="mini alt" data-a="sell" data-g="' + g.id + '" data-n="99">全卖</button></td></tr>';
    });
    body.innerHTML = html + '</tbody></table><p class="note">同一商品在不同星港价格不同。低价买入、高价卖出就是跑商的全部秘诀。</p>';
    body.querySelectorAll('button[data-a]').forEach(function (b) {
      b.onclick = function () {
        var g = b.dataset.g, n = +b.dataset.n;
        if (b.dataset.a === 'buy') {
          var price = priceOf(info.st.id, g, false); n = Math.min(n, st.cargoCap - cargoUsed(), Math.floor(save.credits / price));
          if (n <= 0) { toast(st.cargoCap - cargoUsed() <= 0 ? '货舱已满' : '信用点不足'); return; }
          save.credits -= price * n; addCargo(g, n);
        } else {
          n = Math.min(n, save.cargo[g] || 0); if (n <= 0) return;
          if (save.active && save.active.kind === 'deliver' && save.active.good === g && (save.cargo[g] - n) < save.active.count) { toast('这批货是任务货物，不能卖'); return; }
          save.credits += priceOf(info.st.id, g, true) * n; addCargo(g, -n);
        }
        writeSave(); renderStation();
      };
    });
  }
  function renderMissions(body, info) {
    var html = '';
    if (save.active) {
      html += '<div class="mis active"><span class="tag">进行中</span><h2>' + esc(save.active.title) + '</h2><p>' + esc(missionLine()) + '</p><button class="mini alt" id="abandon">放弃任务</button></div>';
    }
    var list = availableMissions(info.st.id);
    if (!list.length) html += '<p class="note">这里暂时没有新任务。</p>';
    list.forEach(function (m, i) {
      html += '<div class="mis' + (m.story ? ' story' : '') + '"><span class="tag' + (m.story ? ' shard' : '') + '">' + (m.story ? '主线' : '支线') + '</span><h2>' + esc(m.title) + '</h2><p>' + esc(m.text) + '</p>' +
        '<div class="mis-foot"><span>奖励 ' + fmt(m.reward) + ' 信用点' + (m.shards ? '，陨石碎片 x' + m.shards : '') + '</span><button class="mini" data-i="' + i + '"' + (save.active ? ' disabled' : '') + '>接受</button></div></div>';
    });
    body.innerHTML = '<div class="mis-list">' + html + '</div>';
    var ab = body.querySelector('#abandon'); if (ab) ab.onclick = function () { save.active = null; writeSave(); renderStation(); toast('任务已放弃'); };
    body.querySelectorAll('button[data-i]').forEach(function (b) { b.onclick = function () { acceptMission(list[+b.dataset.i]); }; });
  }
  function renderYard(body, info) {
    var st = stats(), cur = byId(G.ships, save.ship), html = '<div class="yard">';
    html += '<div class="yard-col"><h2>飞船</h2>';
    G.ships.forEach(function (s) {
      var own = s.id === save.ship, cost = Math.max(0, s.price - Math.round(cur.price * 0.5));
      html += '<div class="shiprow' + (own ? ' own' : '') + '"><span class="ic">' + catIcon(s.id, 120) + '</span><div><b>' + s.name + '</b><small>' + esc(s.desc) + '</small>' +
        '<small>船体 ' + s.hull + '，护盾 ' + s.shield + '，航速 ' + s.speed + '，货舱 ' + s.cargo + '，炮口 ' + s.guns + '，导弹 ' + s.missiles + '</small></div>' +
        (own ? '<span class="tag">当前</span>' : '<button class="mini" data-ship="' + s.id + '">' + (cost ? fmt(cost) + ' 换购' : '免费换回') + '</button>') + '</div>';
    });
    html += '</div><div class="yard-col"><h2>装备与维护</h2>';
    function eqRow(list, curId, key) {
      var ci = list.findIndex(function (x) { return x.id === curId; }), next = list[ci + 1];
      return '<div class="eqrow"><div><b>' + list[ci].name + '</b><small>' + (next ? '下一级：' + next.name : '已满级') + '</small></div>' +
        (next ? '<button class="mini" data-eq="' + key + '" data-id="' + next.id + '">' + fmt(next.price) + ' 升级</button>' : '') + '</div>';
    }
    html += eqRow(G.lasers, save.laser, 'laser') + eqRow(G.shields, save.shieldGen, 'shieldGen');
    var repair = Math.ceil(save.hullDmg * T.repairCostPerHp);
    html += '<div class="eqrow"><div><b>导弹 ' + save.missiles + ' / ' + st.missileCap + '</b><small>每枚 ' + G.missile.price + ' 信用点</small></div><button class="mini" id="buymis">补充 1 枚</button></div>';
    html += '<div class="eqrow"><div><b>船体 ' + Math.round(st.hullMax - save.hullDmg) + ' / ' + st.hullMax + '</b><small>' + (repair ? '修理费 ' + fmt(repair) : '船体完好') + '</small></div>' + (repair ? '<button class="mini" id="repair">修理</button>' : '') + '</div>';
    body.innerHTML = html + '</div></div>';
    body.querySelectorAll('button[data-ship]').forEach(function (b) {
      b.onclick = function () {
        var s = byId(G.ships, b.dataset.ship), cost = Math.max(0, s.price - Math.round(cur.price * 0.5));
        if (save.credits < cost) { toast('信用点不足'); return; }
        var cap = s.cargo + crewFx().cargo; if (cargoUsed() > cap) { toast('新船货舱放不下现有货物，先卖掉一些'); return; }
        save.credits -= cost; save.ship = s.id; save.hullDmg = 0; save.missiles = Math.min(save.missiles, stats().missileCap);
        toast('已换购 ' + s.name); writeSave(); renderStation();
      };
    });
    body.querySelectorAll('button[data-eq]').forEach(function (b) {
      b.onclick = function () {
        var list = b.dataset.eq === 'laser' ? G.lasers : G.shields, it = byId(list, b.dataset.id);
        if (save.credits < it.price) { toast('信用点不足'); return; }
        save.credits -= it.price; save[b.dataset.eq] = it.id; toast('已安装 ' + it.name); writeSave(); renderStation();
      };
    });
    var bm = body.querySelector('#buymis'); if (bm) bm.onclick = function () {
      if (save.missiles >= st.missileCap) { toast('导弹已满'); return; }
      if (save.credits < G.missile.price) { toast('信用点不足'); return; }
      save.credits -= G.missile.price; save.missiles++; writeSave(); renderStation();
    };
    var rp = body.querySelector('#repair'); if (rp) rp.onclick = function () {
      var cost = Math.ceil(save.hullDmg * T.repairCostPerHp), fix = Math.min(save.hullDmg, Math.floor(save.credits / T.repairCostPerHp));
      if (fix <= 0) { toast('信用点不足'); return; }
      save.credits -= Math.ceil(fix * T.repairCostPerHp); save.hullDmg -= fix; writeSave(); renderStation();
    };
  }
  function renderCrew(body) {
    var html = '<div class="crew-grid">';
    G.crew.forEach(function (c) {
      var own = save.crew.indexOf(c.id) >= 0;
      html += '<div class="crewcard' + (own ? '' : ' locked') + '"><span class="ic">' + (own ? catIcon(c.id, 92) : '<i class="q">?</i>') + '</span><div><b>' + (own ? c.name : '未唤醒') + '</b><span>' + (own ? c.role : '星魂') + '</span><small>' + (own ? c.buff : '在召唤台唤醒后加入舰队') + '</small></div></div>';
    });
    html += '</div><div class="summon-bar"><p>消耗 ' + G.summonCost + ' 块陨石碎片，随机唤醒一位尚未加入的星魂少女。当前碎片 ' + save.shards + '。</p><button class="btn primary" id="summon">召唤</button></div>';
    body.innerHTML = html;
    body.querySelector('#summon').onclick = summon;
  }
  function summon() {
    if (save.shards < G.summonCost) { toast('陨石碎片不足，击碎晶脉小行星或击落海贼可以获得'); return; }
    var pool = G.crew.filter(function (c) { return save.crew.indexOf(c.id) < 0; });
    save.shards -= G.summonCost;
    if (!pool.length) { save.credits += 3000; toast('舰员已全部到齐，碎片能量转化为 3,000 信用点'); writeSave(); renderStation(); return; }
    var c = pool[Math.floor(Math.random() * pool.length)];
    save.crew.push(c.id); writeSave();
    var ov = el('div', 'reveal');
    ov.innerHTML = '<div class="reveal-in"><span class="tag shard">召唤成功</span><span class="ic">' + catIcon(c.id, 220) + '</span><h1>' + c.name + '</h1><span class="role">' + c.role + '</span><p>' + c.buff + '</p><button class="btn primary">欢迎加入</button></div>';
    ui.appendChild(ov);
    ov.querySelector('button').onclick = function () { renderStation(); };
  }
  function undock() {
    var info = stationById(save.dockedAt);
    if (W.sys.id !== info.sys.id) loadSystem(info.sys.id);
    var stEnt = W.ents.filter(function (e) { return e.kind === 'station'; })[0];
    var out = norm([0.3, 0.05, 1]);
    W.player.pos = add(stEnt.pos, mul(out, stEnt.radius + 80)); var a = anglesTo(out); W.player.yaw = a[0]; W.player.pitch = 0;
    W.player.speed = 30; W.player.throttle = 0.5; W.player.shield = stats().shieldMax; W.player.hull = stats().hullMax - save.hullDmg;
    if (save.missiles > stats().missileCap) save.missiles = stats().missileCap;
    W.player.model = save.ship; W.player.mesh = E.getMesh(save.ship); W.player.radius = W.player.mesh.radius;
    cam.pos = null; resumeFlight();
  }

  // ------------------------------------------------------------------ 跃迁、星图、暂停、死亡
  function jump(to) {
    var from = W.sys.id, f = document.getElementById('warp');
    mode = 'warp'; f.classList.add('on');
    setTimeout(function () {
      loadSystem(to, from); writeSave();
      f.classList.remove('on'); resumeFlight(); toast('抵达 ' + W.sys.name);
    }, 650);
  }
  function openMap() {
    mode = 'map'; ui.innerHTML = '';
    var p = el('section', 'panel mapview');
    var svg = '<svg viewBox="-0.6 -1.1 3.2 2.2" class="galaxy" aria-label="星图">';
    var links = [['ashfall', 'rubble'], ['rubble', 'redring']];
    links.forEach(function (l) { var a = sysById(l[0]).map, b = sysById(l[1]).map; svg += '<line x1="' + a[0] + '" y1="' + a[1] + '" x2="' + b[0] + '" y2="' + b[1] + '"/>'; });
    G.systems.forEach(function (s) {
      var cur = s.id === W.sys.id, col = s.danger === '高' ? '#E0458C' : s.danger === '中' ? '#F5A524' : '#5CF2DC';
      svg += '<rect x="' + (s.map[0] - 0.09) + '" y="' + (s.map[1] - 0.09) + '" width="0.18" height="0.18" fill="' + col + '"' + (cur ? ' stroke="#EDE6D6" stroke-width="0.03"' : '') + '/>' +
        '<text x="' + s.map[0] + '" y="' + (s.map[1] + 0.3) + '">' + s.name + '</text>' + (cur ? '<text class="here" x="' + s.map[0] + '" y="' + (s.map[1] - 0.17) + '">当前位置</text>' : '');
    });
    svg += '</svg>';
    var navs = W.ents.filter(function (e) { return e.kind === 'station' || e.kind === 'gate' || e.kind === 'base'; });
    var list = navs.map(function (e, i) { return '<button class="navrow" data-i="' + i + '"><b>' + esc(e.name) + '</b><span>' + fmt(dist(e.pos, W.player.pos)) + ' 米</span></button>'; }).join('');
    p.innerHTML = '<div class="map-l"><h2>星系图</h2>' + svg + '<p class="note">' + esc(W.sys.desc) + '</p></div><div class="map-r"><h2>' + esc(W.sys.name) + ' 导航点</h2>' + list +
      '<p class="note">选择导航点后自动驾驶前往。推动摇杆即可接管。</p><p class="mline">' + esc(missionLine()) + '</p><button class="btn" id="mapback">返回飞行</button></div>';
    ui.appendChild(p);
    p.querySelectorAll('.navrow').forEach(function (b) { b.onclick = function () { W.nav = navs[+b.dataset.i]; W.target = W.nav; W.auto = true; resumeFlight(); toast('自动导航：前往 ' + W.nav.name); }; });
    p.querySelector('#mapback').onclick = resumeFlight;
  }
  function openPause() {
    mode = 'pause'; ui.innerHTML = '';
    var p = el('section', 'panel pausebox');
    p.innerHTML = '<h1>暂停</h1><button class="btn primary" id="p-res">继续</button><button class="btn" id="p-title">保存并回到标题</button>' +
      '<p class="note">电脑操作：WASD 或方向键转向，R/F 油门，空格开火，Q 导弹，Shift 加速，T 目标，G 自动导航，E 停靠或跃迁，M 星图。</p>';
    ui.appendChild(p);
    p.querySelector('#p-res').onclick = resumeFlight;
    p.querySelector('#p-title').onclick = function () { writeSave(); showTitle(); };
  }
  function gameOver() {
    mode = 'dead';
    var info = stationById(save.dockedAt);
    save.cargo = {}; save.credits = Math.floor(save.credits * 0.9); save.hullDmg = 0;
    if (save.active && save.active.provide) save.active = null;
    writeSave();
    setTimeout(function () {
      ui.innerHTML = '';
      var p = el('section', 'panel pausebox');
      p.innerHTML = '<h1>飞船被击毁</h1><p>逃生舱把你送回了' + esc(info.st.name) + '。货物全部遗失，保险扣除了 10% 信用点。</p><button class="btn primary" id="respawn">在 ' + esc(info.st.name) + ' 重新出发</button>';
      ui.appendChild(p);
      p.querySelector('#respawn').onclick = function () { loadSystem(info.sys.id); dock(info.st.id); };
    }, 1600);
  }
  function resumeFlight() { mode = 'flight'; buildFlightHUD(); }

  // ------------------------------------------------------------------ 标题与图鉴
  var gallery = { id: CATALOG.items[0].id, cat: CATALOG.items[0].category, yaw: 28, pitch: 14 };
  function showTitle() {
    mode = 'title'; if (!save) save = loadSave() || newSave();
    if (!W.sys || W.sys.id !== 'ashfall') loadSystem('ashfall');
    ui.innerHTML = '';
    var has = !!loadSave();
    var box = el('section', 'title');
    box.innerHTML = '<span class="tag">实验玩法</span><h1>陨星银河</h1><p class="sub">上古陨星天殒坠落八百年后，碎片里沉睡的星魂正在苏醒。驾驶你的飞船，在星系之间跑商、冒险，唤醒她们。</p>';
    var btns = el('div', 'title-btns');
    if (has) { var c = el('button', 'btn primary', '继续航行'); c.onclick = function () { save = loadSave(); startGame(); }; btns.appendChild(c); }
    var n = el('button', 'btn' + (has ? '' : ' primary'), '新的旅程'); n.onclick = function () { save = newSave(); writeSave(); startGame(true); }; btns.appendChild(n);
    var sv = el('button', 'btn sv-entry', '星海突围<small>新玩法：8 分钟割草突围</small>'); sv.onclick = function () { if (window.Survivor) window.Survivor.open(); }; btns.appendChild(sv);
    var g = el('button', 'btn', '资产图鉴'); g.onclick = openGallery; btns.appendChild(g);
    if (window.CosmicHub) { var back = el('button', 'btn primary', '返回宇宙银河玩家'); back.onclick = function () { window.CosmicHub.open(); }; btns.insertBefore(back, btns.firstChild); }
    box.appendChild(btns); ui.appendChild(box);
  }
  function startGame(fresh) {
    loadSystem(save.system);
    var info = stationById(save.dockedAt);
    if (fresh) { dock(info.st.id); toast('欢迎来到灰烬星港。先去任务板接取主线任务。'); }
    else dock(info.st.id);
  }
  function openGallery() {
    mode = 'gallery'; ui.innerHTML = '';
    var side = el('aside', 'panel gallery-list'), cats = el('div', 'cats');
    CATALOG.categories.forEach(function (c) {
      var n = CATALOG.items.filter(function (it) { return it.category === c.id; }).length;
      var b = el('button', 'cat' + (gallery.cat === c.id ? ' on' : ''), c.name + '<small>' + n + '</small>');
      b.onclick = function () { gallery.cat = c.id; gallery.id = CATALOG.items.filter(function (it) { return it.category === c.id; })[0].id; openGallery(); };
      cats.appendChild(b);
    });
    side.appendChild(cats);
    var list = el('div', 'list');
    CATALOG.items.filter(function (it) { return it.category === gallery.cat; }).forEach(function (it) {
      var r = el('button', 'row' + (gallery.id === it.id ? ' on' : ''), '<span class="row-ic">' + iconSVG(it.icon, 64) + '</span><span class="row-t">' + esc(it.name) + '</span>');
      r.onclick = function () { gallery.id = it.id; openGallery(); }; list.appendChild(r);
    });
    side.appendChild(list); ui.appendChild(side);
    var it = byId(CATALOG.items, gallery.id), cat = byId(CATALOG.categories, it.category), info = el('section', 'panel info');
    info.innerHTML = '<span class="tag">' + cat.name + '</span><h1>' + esc(it.name) + '</h1><p class="desc">' + esc(it.desc) + '</p><dl><div><dt>尺寸</dt><dd>' +
      it.size.map(function (v) { return v.toFixed(1); }).join(' x ') + ' 米</dd></div><div><dt>体素</dt><dd>' + fmt(it.voxels) + '</dd></div><div><dt>合并面</dt><dd>' + fmt(MODELS[it.id].quadCount) + '</dd></div></dl>' +
      '<div class="swatches">' + it.palette.map(function (h) { return '<i style="background:' + h + '"></i>'; }).join('') + '</div>';
    ui.appendChild(info);
    var back = el('button', 'btn gal-back', '返回标题'); back.onclick = showTitle; ui.appendChild(back);
  }
  function renderGallery(t) {
    var md = MODELS[gallery.id], sc = md.scale, sx = md.size[0] * sc, sy = md.size[1] * sc, sz = md.size[2] * sc;
    var small = ['crew', 'enemy', 'item'].indexOf(md.category) >= 0, draws = [], base = 0;
    if (small) { var ps = Math.max(0.6, Math.max(sx, sz) * 1.3 / 2.4); draws.push({ mesh: E.getMesh('sys_pedestal'), m: E.trs([0, 0, 0], 0, 0, 0, ps), s: ps }); base = 0.3 * ps; }
    var posY = md.origin[1] === 0 ? base : 0, center = posY + (md.size[1] / 2 - md.origin[1]) * sc;
    draws.push({ mesh: E.getMesh(gallery.id), m: E.trs([0, posY, 0], t * 16, 0, 0, 1), s: 1 });
    var radius = 0.5 * Math.hypot(sx, sy, sz), dd = Math.max(1.6, radius / Math.tan(19 * DEG) * 1.9);
    var cp = Math.cos(gallery.pitch * DEG), eye = [dd * Math.sin(gallery.yaw * DEG) * cp, center + dd * Math.sin(gallery.pitch * DEG), dd * Math.cos(gallery.yaw * DEG) * cp];
    E.render({ env: SC.gallery.env, eye: eye, target: [0, center, 0], fov: fitFov(38, view.w / view.h), aspect: view.w / view.h, near: 0.1, far: 800, draws: draws, stars: null,
      shadow: { range: Math.max(2, radius * 1.6), center: [0, center, 0] } });
  }
  // 图鉴拖动旋转
  (function () {
    var last = null;
    E.canvas.addEventListener('pointerdown', function (e) { if (mode === 'gallery') { last = [e.clientX, e.clientY]; E.canvas.setPointerCapture(e.pointerId); } });
    E.canvas.addEventListener('pointermove', function (e) {
      if (!last || mode !== 'gallery') return;
      var k = 0.125 / Math.max(0.15, view.s); gallery.yaw += (e.clientX - last[0]) * k; gallery.pitch = clamp(gallery.pitch + (e.clientY - last[1]) * k, -20, 75); last = [e.clientX, e.clientY];
    });
    E.canvas.addEventListener('pointerup', function () { last = null; });
  })();

  // ------------------------------------------------------------------ 主循环
  var lastT = performance.now();
  function loop(now) {
    requestAnimationFrame(loop);
    var dt = Math.min(0.05, (now - lastT) / 1000); lastT = now;
    if (mode === 'gallery') { W.t += dt; renderGallery(W.t); drawHud2d(); return; }
    if (mode === 'survivor') { if (window.Survivor) window.Survivor.frame(dt); return; }
    if (mode === 'cosmic-hub') { window.CosmicHub.frame(dt); return; }
    if (mode === 'cosmic-run') { window.CosmicRun.frame(dt); return; }
    if (!W.sys) return;
    if (mode === 'flight') {
      W.t += dt;
      updatePlayer(dt); updatePirates(dt); updateProjectiles(dt); updateCollisions(dt); updateLoot(dt); updateParticles(dt); updateSpawns(dt);
      if (mode === 'flight') { updateCamera(dt); updateFlightHUD(dt); }
      save.played += dt;
    } else if (mode === 'dead' || mode === 'warp') {
      W.t += dt; updateParticles(dt); updateProjectiles(dt);
    } else { W.t += dt * 0.5; }
    if (mode === 'station' || mode === 'title') {
      // 星港 / 标题背景：绕星港缓慢环绕
      var stE = byKind('station'), a = W.t * 4, R = stE.radius * 3.2;
      renderWorld(add(stE.pos, [Math.sin(a * DEG) * R, stE.radius * 0.6, Math.cos(a * DEG) * R]), stE.pos, 55);
    } else if (cam.pos) {
      renderWorld(cam.pos, cam.target, cam.fov);
    }
    drawHud2d();
  }
  setInterval(function () { if (mode === 'flight' && save) writeSave(); }, 15000);
  layout();
  var api = {
    save: function () { if (!save) save = loadSave() || newSave(); return save; }, writeSave: writeSave, toast: toast,
    iconSVG: iconSVG, catIcon: catIcon, resIcon: resIcon, byId: byId, fitFov: fitFov,
    view: function () { return view; }, mode: function () { return mode; }, setMode: function (m) { mode = m; }, showTitle: showTitle
  };
  if (window.CosmicHub) { window.CosmicHub.init(api); window.CosmicRun.init(api); }
  if (window.Survivor) window.Survivor.init({
    save: function () { if (!save) save = loadSave() || newSave(); return save; }, writeSave: writeSave, toast: toast,
    iconSVG: iconSVG, catIcon: catIcon, resIcon: resIcon, byId: byId, fitFov: fitFov,
    view: function () { return view; }, mode: function () { return mode; }, setMode: function (m) { mode = m; }, showTitle: showTitle
  });
  if (window.CosmicHub) window.CosmicHub.open(); else showTitle();
  requestAnimationFrame(loop);
  window.__game = { W: W, get save() { return save; }, set save(v) { save = v; }, stats: stats, dock: dock, undock: undock, jump: jump, loadSystem: loadSystem,
    openMap: openMap, openGallery: openGallery, toast: toast, writeSave: writeSave, refreshStation: function () { if (mode === 'station') renderStation(); }, resumeFlight: resumeFlight, newSave: newSave, startGame: startGame, mode: function () { return mode; }, input: input, keys: keys, cycleTarget: cycleTarget,
    spawnPirate: spawnPirate, interact: interact, step: function (n, dt) { dt = dt || 1 / 30; for (var i = 0; i < n && mode === 'flight'; i++) { W.t += dt; updatePlayer(dt); updatePirates(dt); updateProjectiles(dt); updateCollisions(dt); updateLoot(dt); updateParticles(dt); updateSpawns(dt); } }, summon: summon, setTab: function (t) { stationTab = t; renderStation(); } };
})();
