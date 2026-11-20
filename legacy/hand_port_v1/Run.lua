-- Run.lua：一局战斗（飞行、机甲、武器、敌人、卡牌技能、升级、首领、氮气、结算）
-- 移植自网页版 cosmic_run.js 的核心逻辑；为适配手机操作，飞行在水平面上进行（敌人在上下 ±6 米范围内）。
local D = require("cosmic.Data")
local U = require("cosmic.Util")
local S = require("cosmic.Save")
local Fx = require("cosmic.Fx")
local Mech = require("cosmic.Mech")
local Snd = require("cosmic.Sound")
local VB = require("game.VoxelBuilder")
local Meta = require("cosmic.Meta")
local Run = { scene = nil, R = nil, banner = nil, DEBUG = false, VERSION = "1.0.0" }
local scene_, camNode_, camera_, zone_, keyNode_, keyLight_, fillNode_, fillLight_, content_, protos_, enemyRoot_, starNode_
local renderPath_
local player_ = nil

-- ---------------------------------------------------------------- 场景
function Run.Init()
    scene_ = Scene(); scene_:CreateComponent("Octree")
    local zn = scene_:CreateChild("Zone"); zone_ = zn:CreateComponent("Zone")
    zone_.boundingBox = BoundingBox(Vector3(-20000, -20000, -20000), Vector3(20000, 20000, 20000)); zone_.fogStart = 5000; zone_.fogEnd = 9000
    keyNode_ = scene_:CreateChild("Key"); keyLight_ = keyNode_:CreateComponent("Light"); keyLight_.lightType = LIGHT_DIRECTIONAL; keyLight_.castShadows = false
    fillNode_ = scene_:CreateChild("Fill"); fillLight_ = fillNode_:CreateComponent("Light"); fillLight_.lightType = LIGHT_DIRECTIONAL; fillLight_.castShadows = false
    camNode_ = scene_:CreateChild("Camera"); camera_ = camNode_:CreateComponent("Camera"); camera_.nearClip = 0.3; camera_.farClip = 9000; camera_.fov = 64
    local vp = Viewport:new(scene_, camera_); renderPath_ = vp:GetRenderPath()
    renderPath_:Append(cache:GetResource("XMLFile", "PostProcess/Bloom.xml")); renderPath_:Append(cache:GetResource("XMLFile", "PostProcess/FXAA3.xml"))
    Run.viewport = vp
    protos_ = scene_:CreateChild("Protos"); content_ = scene_:CreateChild("Content"); enemyRoot_ = scene_:CreateChild("Enemies")
    Fx.Init(scene_); Snd.Init(scene_)
    Run.scene, Run.camera, Run.camNode, Run.content = scene_, camera_, camNode_, content_
end
function Run.Activate() renderer:SetViewport(0, Run.viewport) end
function Run.ApplyEnv(env)
    zone_.ambientColor = Color(env.ambient[1], env.ambient[2], env.ambient[3]); zone_.fogColor = Color(env.bg[1], env.bg[2], env.bg[3])
    keyNode_.direction = Vector3(env.key.dir[1], env.key.dir[2], env.key.dir[3]):Normalized(); keyLight_.color = Color(env.key.color[1], env.key.color[2], env.key.color[3]); keyLight_.brightness = env.key.brightness
    fillNode_.direction = Vector3(env.fill.dir[1], env.fill.dir[2], env.fill.dir[3]):Normalized(); fillLight_.color = Color(env.fill.color[1], env.fill.color[2], env.fill.color[3]); fillLight_.brightness = env.fill.brightness
    renderPath_:SetShaderParameter("BloomThreshold", Variant(0.9)); renderPath_:SetShaderParameter("BloomMix", Variant(Vector2(1.0, 0.4)))
end
function Run.BuildStars() return Run.buildStars() end
function Run.buildStars() return nil end
local function buildStars()
    if starNode_ then starNode_:Remove() end
    local data, colors = {}, { { 0.92, 0.94, 1.0 }, { 0.6, 0.95, 0.9 }, { 1.0, 0.86, 0.62 } }
    for _ = 1, 420 do
        local x, y, z = U.norm(U.rand(-1, 1), U.rand(-1, 1), U.rand(-1, 1)); local r = 3000
        data[#data + 1] = x * r; data[#data + 1] = y * r; data[#data + 1] = z * r; data[#data + 1] = U.rand(9, 17); data[#data + 1] = math.random(0, 2)
    end
    starNode_ = VB.BuildStars(content_, { data = data, colors = colors })
end

-- ---------------------------------------------------------------- 数据查询
local MECH_BY = {}; for _, m in ipairs(D.MECHS) do MECH_BY[m.id] = m end
local FORM_BY = {}; for _, f in ipairs(D.MOD_FORMS) do FORM_BY[f.k] = f end
local ELEM_BY = {}; for _, e in ipairs(D.ELEMENTS) do ELEM_BY[e.k] = e end
local IMPLEMENTED = { homing = true, orbit = true, nova = true, strike = true, beam = true, fan = true, mine = true, boomerang = true }   -- 本版实现的技能形态（含其派生形态）
Run.IMPLEMENTED = IMPLEMENTED
local UPG = {
    main = { name = "主武器强化", text = "伤害提升，射速加快" }, power = { name = "火控核心", text = "所有伤害 +10%" }, hull = { name = "耐久强化", text = "耐久上限 +20%，立即回复 25%" },
    engine = { name = "引擎超频", text = "移动速度 +8%" }, magnet = { name = "引力收集器", text = "拾取范围扩大" }, cooling = { name = "冷却回路", text = "所有冷却 -7%" }, repair = { name = "自动修复", text = "每秒修复耐久 +0.6" } }
Run.UPG = UPG
local PASSIVES = { "power", "hull", "engine", "magnet", "cooling", "repair" }
local function base(f) return f.b or f.k end

-- ---------------------------------------------------------------- 一局的状态
local NITRO = {
    mech_azure = { name = "氮气冲刺", dist = 16, dur = 0.2, inv = 0.26, cd = 2.4 }, mech_blaze = { name = "氮气冲撞", dist = 20, dur = 0.28, inv = 0.3, cd = 3.0, ram = 60 },
    mech_halo = { name = "氮气漂移", dist = 15, dur = 0.24, inv = 0.3, cd = 2.4, heal = 0.04 }, mech_forge = { name = "氮气加速", dist = 34, dur = 0.9, inv = 0.35, cd = 3.4 },
    mech_frost = { name = "氮气后撤", dist = 17, dur = 0.22, inv = 0.3, cd = 2.6, retreat = true }, mech_starfall = { name = "氮气跃迁", dist = 24, dur = 0.3, inv = 0.36, cd = 3.0 } }
Run.NITRO = NITRO
local function hullMax(R) return math.floor(R.m.hp * R.mMul * (1 + R.st.hp + 0.2 * R.lv.hull) * (R.glass and 0.7 or 1)) end
local function dmgMult(R) return (R.glass and 1.4 or 1) * (1 + R.st.atk + 0.10 * R.lv.power) * R.mMul * ((R.st.traits.berserk and R.hull < hullMax(R) * 0.3) and 1.3 or 1) end
local function cdMult(R) return math.max(0.3, 1 - 0.07 * R.lv.cooling - R.st.cdr) end
local function speed(R) return R.m.spd * 1.1 * (1 + R.st.spd) * (1 + 0.08 * R.lv.engine) * (R.hasMod and R.hasMod.swift and 1.15 or 1) end
Run.hullMax = hullMax


-- ---------------------------------------------------------------- 星域目标（移植自网页版的星域事件，规则略有简化）
local OBJ = { clear = "清剿海盗据点", hunt = "限时猎杀", ambush = "击退伏击", derelict = "搜刮遗弃残骸", ore = "开采富矿带", distress = "营救逃生舱" }
local AFFIX = { { id = "swift", name = "高速敌群", desc = "敌人移速 +25%" }, { id = "fury", name = "狂暴信号", desc = "敌人伤害 +25%，能量 +30%" }, { id = "tide", name = "能量潮汐", desc = "敌人更多，能量 +50%" } }
local function affix(R, id) return (R.affix and R.affix.id == id) or (R.hasMod and R.hasMod[id]) end
local function beacon(R, x, z, color, h)
    local n = Fx.Node(color, 0.9, h or 7, 0.9); n.position = Vector3(x, R.py + (h or 7) / 2 - 2, z); return n
end
local function newObjective(R)
    local k = R.sector
    if k >= 6 or R.endless then R.obj = nil; return end
    R.objUsed = R.objUsed or {}; local pool = {}
    for key in pairs(OBJ) do if not R.objUsed[key] then pool[#pool + 1] = key end end
    if #pool == 0 then R.objUsed = {}; for key in pairs(OBJ) do pool[#pool + 1] = key end end
    table.sort(pool); local typ = k == 1 and "clear" or U.pick(pool); R.objUsed[typ] = true
    local a = U.rand(0, 6.283); local dist = typ == "clear" and 0 or U.rand(60, 90); local o = { type = typ, name = OBJ[typ], x = R.px + math.sin(a) * dist, z = R.pz + math.cos(a) * dist, state = "idle", k0 = R.kills, t = 0 }
    if typ == "clear" then o.need = 12 + 4 * R.chId + 2 * k
    elseif typ == "hunt" then o.need = 20 + 8 * R.chId; o.node = beacon(R, o.x, o.z, { 1.5, 0.6, 0.2 })
    elseif typ == "ambush" then o.wave = 0; o.node = beacon(R, o.x, o.z, { 0.8, 0.5, 1.5 })
    elseif typ == "derelict" then o.node = beacon(R, o.x, o.z, { 0.5, 1.3, 1.2 }); o.hold = 0
    elseif typ == "distress" then o.node = beacon(R, o.x, o.z, { 1.4, 1.4, 0.6 }); o.hold = 0
    elseif typ == "ore" then o.ores = {}; for _ = 1, 4 do local oa = U.rand(0, 6.283); local od = U.rand(45, 80); o.ores[#o.ores + 1] = Run.Spawn(R, "ore", R.px + math.sin(oa) * od, R.py + U.rand(-3, 3), R.pz + math.cos(oa) * od) end end
    R.obj = o; R.objective = o.name
    Run.Banner(R, "星域 " .. k .. " / 6：" .. o.name)
end
local function objDone(R, extra)
    local o = R.obj; if not o then return end
    if o.node then o.node:Remove() end
    R.credits = R.credits + 40 * R.chId; R.src = R.src + 1; Snd.Sfx("win", R.t); R.obj = nil
    R.sector = R.sector + 1; R.secMul = 1 + 0.12 * (R.sector - 1); R.secT = 0
    if R.sector >= 6 then Run.Banner(R, "首领出现：" .. D.ENEMY[R.ch.boss].name); R.bossScale = 1 + 0.12 * (R.danger - 1); Run.Spawn(R, R.ch.boss, R.px, R.py, R.pz + 50); R.phase = "boss"; Snd.Sfx("boss", R.t)
    else R.affix = R.sector >= 2 and U.pick(AFFIX) or nil; Run.Banner(R, (extra or "目标完成") .. (R.affix and ("　词缀：" .. R.affix.name .. "（" .. R.affix.desc .. "）") or "")); newObjective(R) end
end
local function updateObjective(R, dt)
    local o = R.obj; if not o then return end
    local dx, dz = R.px - o.x, R.pz - o.z; local d = math.sqrt(dx * dx + dz * dz)
    if o.type == "clear" then o.got = R.kills - o.k0; if o.got >= o.need then objDone(R) end
    elseif o.type == "hunt" then
        if o.state == "idle" and d < 40 then o.state = "active"; o.t = 40; o.k0 = R.kills; o.sp = 0; Run.Banner(R, "限时猎杀：40 秒内击败 " .. o.need .. " 个敌人！") end
        if o.state == "active" then o.t = o.t - dt; o.sp = o.sp - dt; o.got = R.kills - o.k0
            if o.sp <= 0 then o.sp = 1.6; for _ = 1, 4 + R.chId do local a = U.rand(0, 6.283); Run.Spawn(R, U.pick({ "crawler", "crawler", "grunt" }), R.px + math.sin(a) * 35, R.py, R.pz + math.cos(a) * 35) end end
            if o.got >= o.need then R.credits = R.credits + 100 * R.chId; R.src = R.src + 3; objDone(R, "猎杀成功！") elseif o.t <= 0 then objDone(R, "时间到，猎杀失败") end end
    elseif o.type == "ambush" then
        if o.state == "idle" and d < 34 then o.state = "active"; o.wave = 0 end
        if o.state == "active" then
            local alive = false; for _, e in ipairs(R.enemies) do if e.ambush and e.hp > 0 then alive = true; break end end
            if not alive then
                if o.wave >= 3 then R.credits = R.credits + 130 * R.chId; objDone(R, "伏击瓦解！")
                else o.wave = o.wave + 1; Run.Banner(R, "伏击！第 " .. o.wave .. " / 3 波"); local kinds = o.wave == 1 and { "grunt", "grunt", "inter" } or { "heavy", "grunt", "inter" }
                    for i = 1, (o.wave == 3 and 4 or 7 + R.chId * 2) do local a = U.rand(0, 6.283); local e = Run.Spawn(R, (o.wave == 3 and i == 1) and "brute" or U.pick(kinds), R.px + math.sin(a) * 25, R.py, R.pz + math.cos(a) * 25); if e then e.ambush = true end end end
            end end
    elseif o.type == "derelict" then if d < 12 then o.hold = o.hold + dt; if o.hold >= 4 then R.credits = R.credits + 80 * R.chId; objDone(R, "搜刮完成！") end else o.hold = math.max(0, o.hold - dt) end
    elseif o.type == "distress" then
        if d < 14 then o.hold = o.hold + dt; if o.state == "idle" then o.state = "active"; Run.Banner(R, "守住信标 15 秒！") end
            o.sp = (o.sp or 0) - dt; if o.sp <= 0 then o.sp = 2; for _ = 1, 3 do local a = U.rand(0, 6.283); Run.Spawn(R, U.pick({ "crawler", "grunt", "inter" }), o.x + math.sin(a) * 30, R.py, o.z + math.cos(a) * 30) end end
            if o.hold >= 15 then R.src = R.src + 3; objDone(R, "营救成功！星源 +3") end
        else o.hold = math.max(0, o.hold - dt * 0.5) end
    elseif o.type == "ore" then local left = 0; for _, e in ipairs(o.ores) do if e.hp > 0 then left = left + 1 end end; if left == 0 then R.credits = R.credits + 60 * R.chId; objDone(R, "开采完成！") end end
end
Run.UpdateObjective = updateObjective

function Run.Start(chapterId, opt)
    opt = opt or {}
    local sv = S.data; local ch0 = D.CHAPTERS[chapterId]; local m = MECH_BY[sv.mech]
    local dg = U.clamp(opt.danger or 1, 1, 10)
    local mods = {}; if opt.daily then for _, id in ipairs(opt.mods) do mods[id] = true end end
    local ch = U.copy(ch0); ch.hp = ch0.hp * (1 + 0.12 * (dg - 1)) * (mods.iron and 1.5 or 1); ch.dmg = ch0.dmg * (1 + 0.08 * (dg - 1))
    content_:RemoveAllChildren(); enemyRoot_:RemoveAllChildren(); Fx.Reset(); buildStars(); Run.ApplyEnv(ch.env)
    local R = { ch = ch, chId = chapterId, danger = dg, endless = (opt.endless or opt.daily) and true or false, daily = opt.daily and { mods = opt.mods } or nil, hasMod = mods, glass = mods.glass and true or false,
        m = m, st = Meta.Stats(), pilot = Meta.Pilot(), t = 0, secT = 0, sector = 1, secMul = 1, wave = 1, bossScale = 1 + 0.12 * (dg - 1),
        px = 0, py = 0, pz = 0, yaw = 0, vx = 0, vz = 0, camYaw = 0, camPitch = 14, roll = 0,
        enemies = {}, shots = {}, ebullets = {}, gems = {}, pickups = {}, zones = {}, turrets = {}, missiles = {}, nums = {}, sched = {}, mines = {}, booms = {}, wells = {},
        lv = { main = 1, power = 0, hull = 0, engine = 0, magnet = 0, cooling = 0, repair = 0 }, mods = {}, xp = 0, level = 1, pendingLevels = 0, kills = 0, credits = 0, src = 0, combo = 0, comboT = 0,
        timers = { main = 0.5 }, activeCd = 3, nitroCd = 0, nitroT = 0, dash = nil, iframe = 0, hitstop = 0, rr = { free = 1, ad = 0 }, over = false, won = false, phase = "explore", boss = nil, alt = 0, shake = 0,
        dmgDealt = 0, dmgTaken = 0, lastHeal = -99, target = nil, tgT = 0, bannerT = 0, banner = "", choosing = nil, revived = false, secLen = 40, objective = "" }
    R.mMul = S.MechMul(m.id) * (Meta.Matched() and 1.2 or 1)
    R.hull = hullMax(R)
    if player_ then player_.root:Remove() end
    player_ = Mech.Build(content_, m.id); R.mech = player_
    -- 已装备的卡牌
    for _, id in ipairs(sv.modEq) do
        local c = Meta.Card(id); local F = c and FORM_BY[c.form]
        if F and IMPLEMENTED[base(F)] then R.mods[#R.mods + 1] = { c = c, F = F, base = base(F), tier = c.tier, elem = c.elem, lvl = 1, t = 0.8 + #R.mods * 0.4, orb = {}, evo = false, tags = c.tags } end
    end
    R.supT = R.pilot and R.pilot.support and R.pilot.support.cd or 99
    if R.st.traits.headstart then R.pendingLevels = 1 end
    Run.R = R; Snd.Music("battle")
    if R.daily then R.objective = "每日挑战"; Run.Banner(R, "每日挑战：限时 4 分钟")
    elseif R.endless then R.objective = "无尽模式"; Run.Banner(R, "无尽模式" .. (dg > 1 and ("　危险等级 " .. dg) or ""))
    else newObjective(R) end
    return R
end
function Run.Banner(R, text) R.banner = text; R.bannerT = 2.6 end

-- ---------------------------------------------------------------- 敌人
local function enemyRadius(model, scale) return math.max(1.4, VB.Radius(model) * scale * 0.55) end
function Run.Spawn(R, typ, x, y, z)
    local d = D.ENEMY[typ]; if not d then return nil end
    local node = VB.Instance(protos_, enemyRoot_, d.model); node:SetScale(d.scale)
    local hpMul = d.boss and R.bossScale or (R.ch.hp * R.secMul * (R.endless and 1 or (1 + R.secT / 300)))
    local e = { type = typ, d = d, node = node, x = x, y = y, z = z, hp = d.hp * hpMul, yaw = U.rand(0, 360), r = enemyRadius(d.model, d.scale), contact = 0, fire = U.rand(1, d.shoot and d.shoot.cd or 3),
        dv = { 0, 0, 0 }, kx = 0, kz = 0, slowT = 0, stunT = 0, burn = nil, poison = nil, shock = 0, dmark = 0, lmark = 0, rcd = 0, ph = 1, flash = 0 }
    e.max = e.hp; R.enemies[#R.enemies + 1] = e
    if d.boss then R.boss = e end
    return e
end
local function spawnAround(R, typ)
    local a = U.rand(0, 6.283); local dist = U.rand(42, 64)
    return Run.Spawn(R, typ, R.px + math.sin(a) * dist, R.py + U.rand(-4, 4), R.pz + math.cos(a) * dist)
end
local function roamType(R)
    local m, k, c = {}, R.sector, R.chId
    for _, t in ipairs(R.ch.mix) do m[#m + 1] = t end
    if R.endless then
        local w = R.wave; m = { "crawler", "grunt", "inter", "bomber" }
        if w >= 2 then m[#m + 1] = "splitter"; m[#m + 1] = "guard" end
        if w >= 3 then m[#m + 1] = "sniper" end
        if w >= 4 then m[#m + 1] = "phantom"; m[#m + 1] = "heavy" end
        return U.pick(m)
    end
    if k >= 2 then m[#m + 1] = "bomber" end
    if k >= 3 then m[#m + 1] = "splitter" end
    if c >= 2 or k >= 4 then m[#m + 1] = "guard" end
    if c >= 2 and k >= 2 then m[#m + 1] = "sniper" end
    if c >= 3 then m[#m + 1] = "phantom"; m[#m + 1] = "phantom"; m[#m + 1] = "sniper" end
    return U.pick(m)
end

-- ---------------------------------------------------------------- 伤害与状态
local function num(R, e, v, crit, txt, col) if #R.nums < 60 then R.nums[#R.nums + 1] = { x = e.x, y = e.y + e.r, z = e.z, v = txt or tostring(math.floor(v)), crit = crit, col = col, life = 0.8 } end end
local function hurtPlayer(R, dmg)
    if R.over or (Run.DEBUG and R.god) or R.iframe > 0 or (R.dash and R.dash.inv) then return end
    dmg = dmg * R.ch.dmg * (1 - math.min(0.6, R.st.armor)) * (affix(R, 'fury') and 1.25 or 1)
    R.hull = R.hull - dmg; R.dmgTaken = R.dmgTaken + dmg; R.iframe = 0.4; R.mech.p.hit = 1; R.hitstop = math.max(R.hitstop, 0.05); Snd.Sfx("hurt", R.t); R.shake = math.max(R.shake, 0.3)
end
Run.HurtPlayer = hurtPlayer
local killEnemy
local function hurtEnemy(R, e, dmg, crit, quiet)
    if e.hp <= 0 then return end
    if e.d.guard then
        local fx, fz = math.sin(e.yaw * U.DEG), math.cos(e.yaw * U.DEG); local tx, _, tz = U.norm(R.px - e.x, 0, R.pz - e.z)
        if fx * tx + fz * tz > 0.35 then dmg = dmg * 0.2; crit = false; if not quiet then num(R, e, 0, false, "格挡", { 0.4, 0.95, 0.9 }) end end
    end
    if crit == nil then crit = math.random() < 0.08 + R.st.crit end
    dmg = dmg * (crit and (1.8 + R.st.critDmg) or 1) * dmgMult(R) * ((e.d.elite or e.d.boss) and (1 + R.st.elite) or 1)
    e.hp = e.hp - dmg; R.dmgDealt = R.dmgDealt + dmg; e.flash = 0.06
    if not quiet then num(R, e, dmg, crit) ; Snd.Sfx(crit and "crit" or "hit", R.t) end
    if e.hp <= 0 then killEnemy(R, e) end
end
Run.HurtEnemy = hurtEnemy
local function near(R, x, y, z, r, fn) local r2 = r * r; for _, e in ipairs(R.enemies) do if e.hp > 0 then local dx, dy, dz = e.x - x, e.y - y, e.z - z; if dx * dx + dy * dy + dz * dz <= (r + e.r) ^ 2 then fn(e) end end end end
-- 元素反应
local function react(R, e, elem, dmg)
    if e.rcd > 0 then return end
    local frozen, pois = e.slowT > 0, e.poison and e.poison.t > 0
    local txt, col
    if (elem == "thunder" and frozen) or (elem == "ice" and e.shock > 0) then
        txt = "碎冰"; col = { 0.6, 0.9, 1.4 }; e.slowT = 0; e.shock = 0; near(R, e.x, e.y, e.z, 6, function(o) hurtEnemy(R, o, dmg * 1.2, false, true) end)
    elseif elem == "fire" and pois then txt = "爆燃"; col = { 1.5, 0.6, 0.2 }; e.poison = nil; near(R, e.x, e.y, e.z, 6.5, function(o) hurtEnemy(R, o, dmg * 1.1, false, true) end)
    elseif elem == "fire" and frozen then txt = "融蚀"; col = { 1.4, 0.8, 0.3 }; e.slowT = 0; hurtEnemy(R, e, dmg * 0.9, false, true)
    elseif elem == "thunder" and pois then txt = "麻痹"; col = { 1.4, 1.3, 0.3 }; e.poison = nil; e.stunT = e.d.boss and 0.35 or (e.d.elite and 0.8 or 1.4)
    elseif (elem == "light" and e.dmark > 0) or (elem == "dark" and e.lmark > 0) then txt = "湮灭"; col = { 1.3, 0.5, 1.5 }; e.dmark = 0; e.lmark = 0; hurtEnemy(R, e, dmg * 1.6, true, true) end
    if txt then e.rcd = 0.5; Fx.Burst(e.x, e.y, e.z, col, 10, 9, 0.5, 0.5); Fx.Ring(e.x, e.y, e.z, 5, col, 18, 0.35, 0.35); num(R, e, 0, true, txt, col); Snd.Sfx("crit", R.t) end
end
local hasTag
local function modHit(R, md, e, dmg)
    if e.hp <= 0 then return end
    react(R, e, md.elem, dmg)
    if e.hp <= 0 then return end
    hurtEnemy(R, e, dmg, hasTag(md, "crit") and (math.random() < 0.15 + R.st.crit) or nil)
    if hasTag(md, "slow") then e.slowT = math.max(e.slowT, 2) end
    if hasTag(md, "knock") then local kx, kz = U.norm(e.x - R.px, 0, e.z - R.pz); e.kx, e.kz = e.kx + kx * 14, e.kz + kz * 14 end
    if hasTag(md, "leech") then R.hull = math.min(hullMax(R), R.hull + dmg * 0.02) end
    if hasTag(md, "chain") then near(R, e.x, e.y, e.z, 9, function(o) if o ~= e and not o.chained then o.chained = true; hurtEnemy(R, o, dmg * 0.6, false, true); o.chained = nil end end) end
    if md.elem == "ice" then e.slowT = math.max(e.slowT, 2) elseif md.elem == "fire" then e.burn = { dps = dmg * 0.15, t = 2 } elseif md.elem == "poison" then e.poison = { dps = dmg * 0.12, t = 3 }
    elseif md.elem == "thunder" then e.shock = 2 elseif md.elem == "light" then e.lmark = 2.5 elseif md.elem == "dark" then e.dmark = 2.5 end
end
killEnemy = function(R, e)
    if e.dead then return end
    e.dead = true; R.kills = R.kills + 1; R.combo = R.combo + 1; R.comboT = 3
    local d = e.d; local big = d.elite or d.boss
    Fx.Burst(e.x, e.y, e.z, d.boss and { 1.5, 0.5, 0.3 } or { 1.4, 0.8, 0.3 }, big and 18 or 7, 10, 0.5, 0.5); Snd.Sfx("pop", R.t)
    if d.split then for _ = 1, d.split do Run.Spawn(R, "crawler", e.x + U.rand(-2, 2), e.y, e.z + U.rand(-2, 2)) end end
    R.credits = R.credits + math.floor((d.cr or 1) * (1 + R.st.credit) + 0.5)
    R.gems[#R.gems + 1] = { x = e.x, y = e.y, z = e.z, v = math.max(1, d.xp), node = Fx.Node({ 0.4, 1.0, 0.9 }, 0.45), pull = false }
    if not big and not d.ore and math.random() < math.min(0.05, 0.01 + R.st.luck) and R.t - R.lastHeal > 5 then
        local n = 0; for _, p in ipairs(R.pickups) do n = n + 1 end
        if n < 3 then R.lastHeal = R.t; R.pickups[#R.pickups + 1] = { x = e.x, y = e.y, z = e.z, node = Fx.Node({ 0.4, 1.0, 0.5 }, 0.9) } end
    end
    if big then R.hitstop = math.max(R.hitstop, d.boss and 0.18 or 0.1); R.shake = math.max(R.shake, 0.5) end
    if d.elite and R.hasMod and R.hasMod.elite then R.hull = math.min(hullMax(R), R.hull + hullMax(R) * 0.1) end
    if d.boss then
        if R.endless then R.bossKilled = (R.bossKilled or 0) + 1; R.src = R.src + 3; R.boss = nil; R.phase = "explore"; Run.Banner(R, d.name .. " 被击败！星源 +3")
        else R.won = true; R.src = R.src + 5; Run.Banner(R, d.name .. " 被击败！"); R.sched[#R.sched + 1] = { t = 2.2, fn = function() Run.End(R, true) end } end
    end
end

-- ---------------------------------------------------------------- 弹体
local function newShot(R, x, y, z, dx, dy, dz, spd, dmg, pierce, life, color, size, elongate)
    local n = Fx.Node(color or { 0.4, 1.0, 0.9 }, size or 0.22, size or 0.22, elongate or 1.6)
    local yaw, pitch = U.angOf(dx, dy, dz); n.rotation = Quaternion(pitch, yaw, 0)
    local s = { x = x, y = y, z = z, vx = dx * spd, vy = dy * spd, vz = dz * spd, dmg = dmg, pierce = pierce or 0, life = life or 0.8, hit = {}, node = n }
    R.shots[#R.shots + 1] = s; return s
end
local function toTarget(R, ox, oy, oz, t)
    if not t then return U.norm(math.sin(R.yaw * U.DEG), 0, math.cos(R.yaw * U.DEG)) end
    return U.norm(t.x - ox, t.y - oy, t.z - oz)
end
local function findTarget(R, range)
    local best, bd = nil, range * range
    for _, e in ipairs(R.enemies) do if e.hp > 0 and not e.d.ore then local dx, dy, dz = e.x - R.px, e.y - R.py, e.z - R.pz; local d2 = dx * dx + dy * dy + dz * dz; if d2 < bd then bd, best = d2, e end end end
    -- 富矿：没有敌人，或最近的敌人较远（> 15 米）时，35 米内的矿体也会成为目标
    if not best or bd > 225 then local ob = nil; for _, e in ipairs(R.enemies) do if e.hp > 0 and e.d.ore then local dx, dy, dz = e.x - R.px, e.y - R.py, e.z - R.pz; local d2 = dx * dx + dy * dy + dz * dz; if d2 < 1225 and (not ob or d2 < ob[2]) then ob = { e, d2 } end end end; if ob then return ob[1] end end
    if not best then for _, e in ipairs(R.enemies) do if e.hp > 0 and e.d.ore then local dx, dy, dz = e.x - R.px, e.y - R.py, e.z - R.pz; local d2 = dx * dx + dy * dy + dz * dz; if d2 < bd then bd, best = d2, e end end end end
    return best
end
local function mainStats(R) local l = R.lv.main; return { mul = (1 + 0.2 * math.min(l - 1, 1) + 0.2 * (l >= 4 and 1 or 0) + 0.3 * (l >= 6 and 1 or 0)), rate = (1 + 0.06 * (l >= 2 and 1 or 0) + 0.06 * (l >= 4 and 1 or 0) + 0.1 * (l >= 6 and 1 or 0)) * (1 + R.st.rate), extra = (l >= 3 and 1 or 0) + (l >= 5 and 1 or 0) } end
local function later(R, sec, fn) R.sched[#R.sched + 1] = { t = sec, fn = fn } end
local function glowCol(R) return U.hex(R.mech.fx.glow) end
local function muzzleFlash(R, x, y, z, dx, dy, dz, sz) local g = glowCol(R); Fx.Spawn(x + dx * 0.4, y + dy * 0.4, z + dz * 0.4, { g[1] * 1.3, g[2] * 1.3, g[3] * 1.3 }, 0.5 * sz, 0.09); Fx.Burst(x, y, z, g, 2, 14, 0.2, 0.18 * sz) end

local function fireMain(R, dt)
    R.timers.main = R.timers.main - dt
    if R.timers.main > 0 then return end
    local w = R.m.weapon.type; local st = mainStats(R); local cm = cdMult(R)
    local range = w == "shotgun" and 32 or 42
    local t = findTarget(R, range); R.target = t
    if not t then return end
    local mp = R.mech.p
    if R.m.id ~= "mech_frost" and mp.aimK < 0.55 then R.aimWait = (R.aimWait or 0) + dt; if R.aimWait < 0.6 then R.timers.main = 0.04; return end end
    R.aimWait = 0; Snd.Sfx("shoot", R.t)
    local fxm = R.mech.fx
    if w == "laser" then
        R.timers.main = 0.34 / st.rate * cm; local n = 1 + st.extra
        local function volley()
            local ox, oy, oz = Mech.Muzzle(R.mech, "R", 0); if not ox then return end
            local dx, dy, dz = toTarget(R, ox, oy, oz, t.hp > 0 and t or nil)
            for i = 1, n do
                local off = n > 1 and ((i - 1) / (n - 1) - 0.5) * 0.24 or 0
                newShot(R, ox, oy, oz, dx + off, dy, dz, 80, 3.4 * st.mul, 2, 0.7, { 0.45, 1.0, 0.92 }, 0.2, 1.8)
            end
            muzzleFlash(R, ox, oy, oz, dx, dy, dz, 1); Mech.Kick(R.mech, "R", 1, 0.4 * fxm.kick)
        end
        volley(); later(R, 0.08, volley)
    elseif w == "shotgun" then
        R.timers.main = 0.5 / st.rate * cm; local n = 6 + st.extra * 2
        for bi = 0, 2 do later(R, bi * 0.05, function()
            local ox, oy, oz = Mech.Muzzle(R.mech, "L", bi); if not ox then return end
            local dx, dy, dz = toTarget(R, ox, oy, oz, t.hp > 0 and t or nil); local per = math.ceil(n / 3)
            for q = 1, per do
                local sp = per > 1 and ((q - 1) / (per - 1) - 0.5) * 0.24 or 0
                newShot(R, ox, oy, oz, dx + sp + U.rand(-0.07, 0.07), dy + U.rand(-0.05, 0.05), dz, 72, 13 * st.mul, 1, 0.45, { 1.4, 0.7, 0.3 }, 0.2, 0.6)
            end
            muzzleFlash(R, ox, oy, oz, dx, dy, dz, 1.2); Mech.Kick(R.mech, "L", 0.7, 0.45 * fxm.kick)
        end) end
        R.shake = math.max(R.shake, 0.06)
    elseif w == "heal" then
        R.timers.main = 0.32 / st.rate * cm; local ox, oy, oz = Mech.Muzzle(R.mech, "R", 0); if not ox then return end
        for _ = 1, 1 + st.extra do R.missiles[#R.missiles + 1] = { x = ox, y = oy, z = oz, vx = U.rand(-6, 6), vy = U.rand(-2, 6), vz = U.rand(-6, 6), spd = 28, target = t, dmg = 14 * st.mul, life = 2.5, heal = 0.5, splash = 0, node = Fx.Node({ 0.5, 1.2, 1.1 }, 0.4), col = { 0.5, 1.2, 1.1 } } end
        muzzleFlash(R, ox, oy, oz, 0, 1, 0, 0.9); Mech.Kick(R.mech, "R", 1, 0.2 * fxm.kick)
    elseif w == "twin" then
        R.timers.main = 0.32 / st.rate * cm
        for i = 1, 2 + st.extra do
            local side = ((i + R.alt) % 2 == 1) and "L" or "R"
            local ox, oy, oz = Mech.Muzzle(R.mech, side, 0)
            if ox then local dx, dy, dz = toTarget(R, ox, oy, oz, t); newShot(R, ox, oy, oz, dx, dy, dz, 75, 8.6 * st.mul, 2, 0.7, { 1.5, 1.0, 0.4 }, 0.2, 1.4); muzzleFlash(R, ox, oy, oz, dx, dy, dz, 0.7); Mech.Kick(R.mech, side, 0.8, 0.15 * fxm.kick) end
        end
        R.alt = R.alt + 1
    elseif w == "prism" then
        R.timers.main = 0.34 / st.rate * cm; local n = 3 + st.extra; local ox, oy, oz = Mech.Muzzle(R.mech, "R", 0); if not ox then return end
        local dx, dy, dz = toTarget(R, ox, oy, oz, t)
        for i = 1, n do local off = ((i - 1) / (n - 1) - 0.5) * 0.36; newShot(R, ox, oy, oz, dx + off, dy, dz, 74, 3.9 * st.mul, 2, 0.7, { 0.8, 0.5, 1.5 }, 0.24, 1.6) end
        muzzleFlash(R, ox, oy, oz, dx, dy, dz, 1.2); Mech.Kick(R.mech, "R", 1, 0.4 * fxm.kick)
    elseif w == "lob" then
        R.timers.main = 0.7 / st.rate * cm
        for i = 1, 1 + st.extra do
            local ox, oy, oz = Mech.Muzzle(R.mech, "P", R.alt); R.alt = R.alt + 1; if ox then
                local dx, dy, dz = toTarget(R, ox, oy, oz, t)
                R.missiles[#R.missiles + 1] = { x = ox, y = oy, z = oz, vx = dx * 8 + U.rand(-5, 5), vy = 14, vz = dz * 8 + U.rand(-5, 5), spd = 32, target = t, dmg = 12 * st.mul, splash = 3, life = 3, node = Fx.Node({ 1.4, 0.7, 0.25 }, 0.45, 0.45, 1.0), col = { 1.4, 0.7, 0.25 } }
                Fx.Burst(ox, oy, oz, { 1.4, 0.8, 0.3 }, 3, 7, 0.4, 0.3)
            end
        end
        Mech.Kick(R.mech, nil, 0, 0.8 * fxm.kick); R.shake = math.max(R.shake, 0.05)
    end
end

-- ---------------------------------------------------------------- 卡牌技能
hasTag = function(md, k)
    for _, t in ipairs(md.tags or {}) do if t == k then return true end end
    local g = Meta.GoldTag(md.c); if g and md.tier == 3 and g.tag == k then return true end
    local ev = md.evo and D.EVO[md.base]; if ev then for _, t in ipairs(ev.tags) do if t == k then return true end end end
    return false
end
local function modStat(R, md)
    local F, l = md.F, md.lvl
    local evo = md.evo and D.EVO[md.base] or nil
    local dmg = F.dmg * D.MOD_RARITY_MULT[md.tier + 1] * Meta.CardLvMult(md.c) * (1 + 0.25 * (l - 1)) * (1 + R.st.skill) * (evo and 1.5 or 1) * (md.elem == "dark" and 1.15 or 1)
    return { dmg = dmg, cd = F.cd * (1 - 0.08 * (l - 1)) * cdMult(R) * (R.st.traits.overclock and 0.85 or 1) * (evo and 0.88 or 1), count = F.count + (l >= 3 and 1 or 0) + (l >= 5 and 1 or 0) + (md.tier == 3 and 1 or 0) + (evo and evo.count or 0) + ((hasTag(md, "split") and md.base == "homing") and 1 or 0),
        size = (hasTag(md, "big") and 1.4 or 1) * (evo and evo.size or 1), pierce = hasTag(md, "pierce") and 2 or 0 }
end
Run.ModStat = modStat
local function updateMods(R, dt)
    for _, md in ipairs(R.mods) do
        local st = modStat(R, md); md.t = md.t - dt
        local B = md.base
        if B == "orbit" then
            md.ang = (md.ang or 0) + dt * 2.4; local n = st.count
            for i = 1, n do
                local a = md.ang + i / n * math.pi * 2; local rx, rz = R.px + math.cos(a) * 6.5, R.pz + math.sin(a) * 6.5
                local o = md.orb[i]; if not o then o = { node = Fx.Node({ 1.4, 1.2, 0.5 }, 0.9, 0.35, 1.4), hitT = {} }; md.orb[i] = o end
                o.x, o.y, o.z = rx, R.py + 1.2, rz; o.node.position = Vector3(rx, R.py + 1.2, rz); o.node.rotation = Quaternion(0, -a / U.DEG + 90, 0)
                for _, e in ipairs(R.enemies) do if e.hp > 0 and (o.hitT[e] or 0) <= R.t then local dx, dz = e.x - rx, e.z - rz; if dx * dx + dz * dz < (e.r + 1.2) ^ 2 and math.abs(e.y - R.py) < 6 then o.hitT[e] = R.t + 0.4; modHit(R, md, e, st.dmg) end end end
            end
            for i = n + 1, #md.orb do md.orb[i].node:Remove(); md.orb[i] = nil end
        elseif md.t <= 0 then
            local tgt = findTarget(R, 48)
            if B == "nova" then
                md.t = st.cd; local r = 11 * st.size * (md.evo and 1.4 or 1); near(R, R.px, R.py, R.pz, r, function(e) modHit(R, md, e, st.dmg) end)
                local col = U.hex(ELEM_BY[md.elem] and "#7CD9FF" or "#FFFFFF"); Fx.Ring(R.px, R.py - 2, R.pz, r, { 0.5, 1.0, 1.4 }, 36, 0.4, 0.4)
            elseif tgt then
                md.t = st.cd
                if B == "homing" then
                    for i = 1, st.count do
                        local px, py, pz = Mech.Point(R.mech.shoulderPts[i % 2 + 1])
                        R.missiles[#R.missiles + 1] = { x = px, y = py, z = pz, vx = (i % 2 == 0 and -6 or 6) + U.rand(-3, 3), vy = 14, vz = U.rand(-2, 5), spd = 22, target = tgt, dmg = st.dmg, md = md, splash = md.evo and 3 or 0, life = 3, node = Fx.Node({ 1.2, 1.2, 0.6 }, 0.35, 0.35, 0.9), col = { 1.2, 1.2, 0.6 } }
                    end
                elseif B == "strike" then
                    local picks = {}; for _, e in ipairs(R.enemies) do if e.hp > 0 and not e.d.ore then picks[#picks + 1] = e end end
                    for i = 1, math.min(st.count, #picks) do
                        local e = picks[math.random(1, #picks)]; Fx.Line(e.x, e.y + 30, e.z, e.x, e.y, e.z, { 1.5, 1.4, 0.7 }, 0.5, 0.18, 1.2); Fx.Ring(e.x, e.y, e.z, 3, { 1.5, 1.3, 0.5 }, 12, 0.4, 0.25)
                        modHit(R, md, e, st.dmg); if md.evo then near(R, e.x, e.y, e.z, 7, function(o) if o ~= e then modHit(R, md, o, st.dmg * 0.6) end end) end
                    end
                elseif B == "beam" then
                    local ox, oy, oz = Mech.Muzzle(R.mech, R.mech.fx.fire[1] == "P" and "R" or R.mech.fx.fire[1], 0); if not ox then ox, oy, oz = R.px, R.py + 2, R.pz end
                    for i = 1, st.count do
                        local dx, dy, dz = toTarget(R, ox, oy, oz, tgt); local off = st.count > 1 and ((i - 1) / (st.count - 1) - 0.5) * 0.3 or 0; dx = dx + off; dx, dy, dz = U.norm(dx, dy, dz)
                        Fx.Line(ox, oy, oz, ox + dx * 60, oy + dy * 60, oz + dz * 60, { 0.5, 1.4, 1.3 }, 0.35, 0.2, 1.2)
                        for _, e in ipairs(R.enemies) do if e.hp > 0 then local ex, ey, ez = e.x - ox, e.y - oy, e.z - oz; local tt = ex * dx + ey * dy + ez * dz
                            if tt > 0 and tt < 60 and U.len3(ex - dx * tt, ey - dy * tt, ez - dz * tt) < e.r + 1.6 * st.size then modHit(R, md, e, st.dmg) end end end
                    end
                elseif B == "mine" then
                    for i = 1, st.count do local bx, by, bz = Mech.Point(R.mech.back); R.mines[#R.mines + 1] = { x = bx + U.rand(-1.5, 1.5), y = by, z = bz + U.rand(-1.5, 1.5), life = 14, md = md, dmg = st.dmg, r = 6 * st.size, node = Fx.Node({ 1.5, 0.6, 0.3 }, 0.7, 0.4, 0.7) } end
                elseif B == "boomerang" then
                    for i = 1, st.count do local ox, oy, oz = Mech.Point(R.mech.shoulderPts[i % 2 + 1]); local dx, dy, dz = toTarget(R, ox, oy, oz, tgt); local off = st.count > 1 and ((i - 1) / (st.count - 1) - 0.5) * 0.4 or 0
                        local ndx, ndy, ndz = U.norm(dx + off, dy, dz); R.booms[#R.booms + 1] = { x = ox, y = oy, z = oz, dx = ndx, dy = ndy, dz = ndz, out = true, t = 0, md = md, dmg = st.dmg, hit = {}, node = Fx.Node({ 1.4, 1.2, 0.5 }, 0.9, 0.3, 0.9) } end
                elseif B == "fan" then
                    local ox, oy, oz = Mech.Point(R.mech.shoulderPts[1]); local dx, dy, dz = toTarget(R, ox, oy, oz, tgt)
                    for i = 1, st.count do local off = st.count > 1 and ((i - 1) / (st.count - 1) - 0.5) * 0.7 or 0; local s = newShot(R, ox, oy, oz, dx + off, dy, dz, 60, st.dmg, 1 + st.pierce, 0.9, { 1.2, 0.9, 0.4 }, 0.25, 0.9); s.md = md end
                end
            end
        end
    end
end

-- ---------------------------------------------------------------- 机甲技能与氮气
local function addTurret(R)
    local a = U.rand(0, 6.283)
    R.turrets[#R.turrets + 1] = { x = R.px + math.sin(a) * 7, y = R.py, z = R.pz + math.cos(a) * 7, life = 10, fire = 0.5, node = Fx.Node({ 1.5, 1.1, 0.4 }, 0.9, 1.4, 0.9) }
end
function Run.CastActive(R)
    if R.over or R.activeCd > 0 or R.choosing then return false end
    local id, m = R.m.id, R.m.active; R.activeCd = m.cd * cdMult(R)
    local mm = dmgMult(R) * (1 + R.st.active) * (R.nitroT > 0 and 1.3 or 1)
    if R.nitroT > 0 then R.activeCd = R.activeCd * 0.8; R.nitroT = 0; Run.Banner(R, "氮气强化：技能伤害 +30%，冷却 -20%") end
    Snd.Sfx("skill", R.t)
    local tgt = findTarget(R, 60)
    if id == "mech_azure" then
        Mech.SetCast(R.mech, "beam", 0.6)
        later(R, 0.2, function() local ox, oy, oz = Mech.Muzzle(R.mech, "R", 0); if not ox then return end
            local dx, dy, dz = toTarget(R, ox, oy, oz, tgt and tgt.hp > 0 and tgt or nil); Fx.Line(ox, oy, oz, ox + dx * 90, oy + dy * 90, oz + dz * 90, { 1.5, 1.5, 1.5 }, 0.6, 0.25, 1.2); R.shake = 0.3
            for _, e in ipairs(R.enemies) do if e.hp > 0 then local ex, ey, ez = e.x - ox, e.y - oy, e.z - oz; local tt = ex * dx + ey * dy + ez * dz
                if tt > 0 and tt < 90 and U.len3(ex - dx * tt, ey - dy * tt, ez - dz * tt) < e.r + 3 then hurtEnemy(R, e, 230 * mm / dmgMult(R) * 1.0, false) end end end end)
    elseif id == "mech_blaze" then
        Mech.SetCast(R.mech, "slash", 0.55); local dx, dz = U.norm(math.sin(R.yaw * U.DEG), 0, math.cos(R.yaw * U.DEG))
        R.dash = { t = 0, dur = 0.35, x0 = R.px, z0 = R.pz, x1 = R.px + dx * 32, z1 = R.pz + dz * 32, dmg = 140, hit = {}, inv = true, easeOut = true }
    elseif id == "mech_halo" then
        Mech.SetCast(R.mech, "heal", 0.9)
        later(R, 0.25, function() R.zones[#R.zones + 1] = { x = R.px, y = R.py, z = R.pz, r = 13, life = 6, tick = 0 }; Fx.Ring(R.px, R.py - 2, R.pz, 12, { 0.4, 1.2, 0.7 }, 40, 0.45, 0.6) end)
    elseif id == "mech_forge" then
        Mech.SetCast(R.mech, "deploy", 0.6); later(R, 0.22, function() for _ = 1, 3 do addTurret(R) end end)
    elseif id == "mech_frost" then
        Mech.SetCast(R.mech, "salvo", 0.8); local cx, cy, cz = R.px + math.sin(R.yaw * U.DEG) * 18, R.py, R.pz + math.cos(R.yaw * U.DEG) * 18
        if tgt then cx, cy, cz = tgt.x, tgt.y, tgt.z end
        for j = 1, 16 do
            local tx, tz = cx + U.rand(-11, 11), cz + U.rand(-11, 11); local ox, oy, oz = Mech.Point(R.mech.shoulderPts[j % 2 + 1])
            R.missiles[#R.missiles + 1] = { fall = true, x = ox, y = oy, z = oz, vx = 0, vy = 55, vz = 0, delay = 0.1 + j * 0.03, rise = 0.42, tx = tx, ty = cy, tz = tz, dmg = 15 * mm / dmgMult(R), splash = 5, life = 6, node = Fx.Node({ 1.4, 0.8, 0.3 }, 0.4, 0.4, 1.0), col = { 1.4, 0.8, 0.3 } }
        end
    elseif id == "mech_starfall" then
        Mech.SetCast(R.mech, "meteor", 0.9); local cx, cy, cz = R.px + math.sin(R.yaw * U.DEG) * 18, R.py, R.pz + math.cos(R.yaw * U.DEG) * 18
        if tgt then cx, cy, cz = tgt.x, tgt.y, tgt.z end
        later(R, 0.3, function() R.missiles[#R.missiles + 1] = { fall = true, meteor = true, x = cx, y = cy + 45, z = cz, vx = 0, vy = -60, vz = 0, tx = cx, ty = cy, tz = cz, dmg = 200 * mm / dmgMult(R), splash = 7, life = 8, node = Fx.Node({ 0.9, 0.5, 1.5 }, 1.8), col = { 0.9, 0.5, 1.5 } } end)
    end
    return true
end
function Run.Nitro(R)
    if R.over or R.dash or R.nitroCd > 0 or R.choosing then return false end
    local N = NITRO[R.m.id] or NITRO.mech_azure
    local dx, dz = R.vx, R.vz; if math.abs(dx) + math.abs(dz) < 0.5 then dx, dz = math.sin(R.yaw * U.DEG), math.cos(R.yaw * U.DEG) end; dx, _, dz = U.norm(dx, 0, dz)
    if N.retreat and R.target then dx, _, dz = U.norm(R.px - R.target.x, 0, R.pz - R.target.z) end
    R.dash = { t = 0, dur = N.dur, x0 = R.px, z0 = R.pz, x1 = R.px + dx * N.dist * (1 + R.st.nitroDist), z1 = R.pz + dz * N.dist * (1 + R.st.nitroDist), dmg = (N.ram or 0) * R.mMul, hit = {}, inv = true, invT = N.inv, easeOut = true, nitro = true, dx = dx, dz = dz }
    R.nitroCd = N.cd * (1 - math.min(0.6, R.st.nitro)); R.nitroT = 2.2; Snd.Sfx("nitro", R.t); R.shake = math.max(R.shake, 0.12)
    if N.heal then R.hull = math.min(hullMax(R), R.hull + hullMax(R) * N.heal) end
    if N.retreat then Fx.Ring(R.px, R.py - 2, R.pz, 9, { 0.5, 0.9, 1.5 }, 30, 0.4, 0.4); near(R, R.px, R.py, R.pz, 12, function(e) e.slowT = 2 end) end
    for _, n in ipairs(R.mech.rear) do local x, y, z = Mech.Point(n); local g = glowCol(R); Fx.Burst(x, y, z, { g[1] * 1.4, g[2] * 1.4, g[3] * 1.4 }, 6, 16, 0.5, 0.5) end
    return true
end

-- ================================================================ 第二部分：每帧更新
local function bossPhase(R, e)
    Run.Banner(R, e.d.name .. " 进入第 " .. e.ph .. " 阶段！"); Snd.Sfx("boss", R.t); R.shake = math.max(R.shake, 0.7); e.fire = 1.6; e.laser = nil
    Fx.Ring(e.x, e.y, e.z, e.r * 3, { 1.5, 0.3, 0.35 }, 40, 0.5, 0.6)
    for i = 1, (e.ph == 2 and 6 or 8) do local a = U.rand(0, 6.283); Run.Spawn(R, i % 3 == 0 and "inter" or "crawler", e.x + math.cos(a) * (e.r + 5), e.y, e.z + math.sin(a) * (e.r + 5)) end
end
local function ebullet(R, x, y, z, dx, dy, dz, spd, dmg, kind)
    local size = kind == "snipe" and 0.5 or (kind == "big" and 1.0 or 0.4)
    local n = Fx.Node({ 1.4, 0.25, 0.3 }, size, size, kind == "snipe" and 5 or (kind == "big" and 1.4 or 1.1)); local yaw, pitch = U.angOf(dx, dy, dz); n.rotation = Quaternion(pitch, yaw, 0)
    R.ebullets[#R.ebullets + 1] = { x = x, y = y, z = z, vx = dx * spd, vy = dy * spd, vz = dz * spd, dmg = dmg, life = kind == "big" and 6 or 4, kind = kind, node = n }
end
local function tele(x, y, z, col, size) Fx.Spawn(x, y, z, col, size, 0.06) end
local function updateEnemies(R, dt)
    local E = R.enemies
    for i = #E, 1, -1 do
        local e = E[i]
        if e.hp <= 0 then e.node:Remove(); E[i] = E[#E]; E[#E] = nil; if R.boss == e then R.boss = nil end
        else
            local d = e.d
            e.slowT = math.max(0, e.slowT - dt); e.dmark = math.max(0, e.dmark - dt); e.lmark = math.max(0, e.lmark - dt); e.shock = math.max(0, e.shock - dt); e.rcd = math.max(0, e.rcd - dt); e.flash = math.max(0, e.flash - dt)
            if e.burn then e.burn.t = e.burn.t - dt; e.hp = e.hp - e.burn.dps * dt; if e.burn.t <= 0 then e.burn = nil end end
            if e.poison then e.poison.t = e.poison.t - dt; e.hp = e.hp - e.poison.dps * dt; if e.poison.t <= 0 then e.poison = nil end end
            if e.hp <= 0 then killEnemy(R, e)
            elseif e.stunT > 0 then e.stunT = e.stunT - dt
            else
                local dx, dy, dz = R.px - e.x, R.py - e.y, R.pz - e.z; local dist = U.len3(dx, dy, dz); local nx, ny, nz = dx / math.max(dist, 1e-3), dy / math.max(dist, 1e-3), dz / math.max(dist, 1e-3)
                local mx, my, mz = nx, ny * 0.5, nz
                local pm = e.ph
                if d.boss then local f = e.hp / e.max; local ph0 = f > 0.66 and 1 or (f > 0.33 and 2 or 3); if ph0 > e.ph then e.ph = ph0; pm = ph0; bossPhase(R, e) end end
                if d.keep and dist < d.keep then
                    if not e.orb then e.orb = math.random() < 0.5 and 1 or -1 end
                    local tx, tz = -nz * e.orb, nx * e.orb; mx, my, mz = tx * 0.9 - nx * 0.3, 0, tz * 0.9 - nz * 0.3
                end
                -- 狙击手
                if d.snipe then
                    local SN = d.snipe; e.sncd = (e.sncd or U.rand(1.5, SN.cd)) - dt
                    if not e.sn and e.sncd <= 0 and dist < 75 then e.sn = { t = 0, dx = nx, dy = ny, dz = nz, fired = false }; e.sncd = SN.cd end
                    if e.sn then
                        e.sn.t = e.sn.t + dt; mx, my, mz = 0, 0, 0
                        if e.sn.t < SN.tele * 0.75 then local k = math.min(1, dt * 4); e.sn.dx, e.sn.dy, e.sn.dz = U.norm(U.lerp(e.sn.dx, nx, k), U.lerp(e.sn.dy, ny, k), U.lerp(e.sn.dz, nz, k))
                        elseif e.sn.t >= SN.tele and not e.sn.fired then e.sn.fired = true; Snd.Sfx("boom", R.t); ebullet(R, e.x + e.sn.dx * e.r, e.y + e.sn.dy * e.r, e.z + e.sn.dz * e.r, e.sn.dx, e.sn.dy, e.sn.dz, SN.spd, SN.dmg, "snipe") end
                        if e.sn.t < SN.tele then local len = math.min(30, math.ceil((dist + 8) / 1.5)); for k = 0, len do tele(e.x + e.sn.dx * (e.r + 1 + k * 1.5), e.y + e.sn.dy * (e.r + 1 + k * 1.5), e.z + e.sn.dz * (e.r + 1 + k * 1.5), { 1.2, 0.15, 0.2 }, 0.35) end end
                        if e.sn.t >= SN.tele + 0.3 then e.sn = nil end
                    end
                end
                -- 自爆虫
                if d.bomb then
                    local BB = d.bomb; if not e.fz and dist < BB.trig then e.fz = 0.0001; Snd.Sfx("click", R.t) end
                    if e.fz then
                        e.fz = e.fz + dt; mx, my, mz = 0, 0, 0; Fx.Ring(e.x, e.y - 1, e.z, BB.r, { 1.2, 0.4, 0.15 }, 20, 0.3, 0.06)
                        if e.fz >= BB.fuse then
                            Fx.Ring(e.x, e.y, e.z, BB.r, { 1.5, 0.6, 0.2 }, 30, 0.5, 0.4); Fx.Burst(e.x, e.y, e.z, { 1.5, 0.6, 0.2 }, 14, 12, 0.5, 0.5); Snd.Sfx("boom", R.t); R.shake = math.max(R.shake, 0.2)
                            if U.dist2({ x = R.px, y = R.py, z = R.pz }, e) < (BB.r + 1.5) ^ 2 then hurtPlayer(R, d.dmg * BB.dmg) end
                            e.hp = 0.0001; killEnemy(R, e); e.hp = 0
                        end
                    end
                end
                -- 幽影刺客
                if d.blink and e.hp > 0 then
                    local BL = d.blink; e.bkcd = (e.bkcd or U.rand(2, BL.cd)) - dt
                    if not e.bk and e.bkcd <= 0 and dist > 8 and dist < 60 then e.bk = { t = 0, x = R.px - math.sin(R.yaw * U.DEG) * 11, y = R.py + U.rand(-2, 2), z = R.pz - math.cos(R.yaw * U.DEG) * 11 }; e.bkcd = BL.cd end
                    if e.bk then
                        e.bk.t = e.bk.t + dt; mx, my, mz = 0, 0, 0; Fx.Ring(e.bk.x, e.bk.y - 1, e.bk.z, 4 * (1.2 - 0.5 * e.bk.t / BL.tele), { 0.7, 0.35, 1.4 }, 14, 0.35, 0.06)
                        if e.bk.t >= BL.tele then
                            Fx.Burst(e.x, e.y, e.z, { 0.7, 0.4, 1.4 }, 8, 8, 0.4, 0.4); e.x, e.y, e.z = e.bk.x, e.bk.y, e.bk.z; Fx.Burst(e.x, e.y, e.z, { 0.7, 0.4, 1.4 }, 8, 8, 0.4, 0.4)
                            local bx, by, bz = U.norm(R.px - e.x, R.py - e.y, R.pz - e.z); e.lg = { t = 0, dx = bx, dz = bz }; e.lcool = d.lunge and d.lunge.cd or 5; e.bk = nil
                        end
                    end
                end
                -- 冲撞
                local lunging = false
                if d.lunge and e.hp > 0 then
                    local LG = d.lunge; e.lcool = (e.lcool or U.rand(0.4, 1.4)) - dt
                    if not e.lg and e.lcool <= 0 and dist < LG.range and dist > 2.5 then e.lg = { t = 0, dx = nx, dz = nz }; e.lcool = LG.cd end
                    if e.lg then
                        e.lg.t = e.lg.t + dt
                        if e.lg.t < LG.tele then mx, my, mz = 0, 0, 0; for k = 0, 9 do tele(e.x + e.lg.dx * (e.r + 1 + k * 1.2), e.y, e.z + e.lg.dz * (e.r + 1 + k * 1.2), { 1.2, 0.15, 0.2 }, 0.3) end
                        elseif e.lg.t < LG.tele + LG.dur then mx, my, mz = e.lg.dx, 0, e.lg.dz; lunging = true else e.lg = nil end
                    end
                end
                -- 震地
                if d.slam then
                    local SL = d.slam; e.scd = (e.scd or SL.cd * 0.6) - dt
                    if not e.sl and e.scd <= 0 and dist < SL.r * 1.9 then e.sl = { t = 0 }; e.scd = SL.cd * ((d.boss and pm >= 3) and 0.7 or 1) end
                    if e.sl then
                        e.sl.t = e.sl.t + dt; Fx.Ring(e.x, e.y - e.r * 0.5, e.z, SL.r, { 1.2, 0.35, 0.15 }, 36, 0.35, 0.06); Fx.Ring(e.x, e.y - e.r * 0.5, e.z, SL.r * e.sl.t / SL.tele, { 1.5, 0.6, 0.2 }, 20, 0.45, 0.06)
                        if e.sl.t >= SL.tele then
                            e.sl = nil; R.shake = math.max(R.shake, 0.5); Snd.Sfx("boom", R.t); Fx.Ring(e.x, e.y - e.r * 0.5, e.z, SL.r, { 1.5, 0.6, 0.2 }, 44, 0.6, 0.5); Fx.Burst(e.x, e.y, e.z, { 1.4, 0.6, 0.25 }, 16, 12, 0.6, 0.6, 3)
                            if U.dist2({ x = R.px, y = R.py, z = R.pz }, e) < (SL.r + 1.5) ^ 2 then hurtPlayer(R, d.dmg * SL.dmg) end
                            if SL.ring then local nn = 14 + 4 * (pm - 1); for k = 1, nn do local a = k / nn * 6.283; ebullet(R, e.x, e.y, e.z, math.cos(a), 0, math.sin(a), 13, d.dmg * 0.5, "ring") end end
                        end
                    end
                end
                -- 首领激光
                if d.laser and pm >= d.laser.from and dist < 75 then
                    e.lcd = (e.lcd or d.laser.every * 0.55) - dt
                    if not e.laser and e.lcd <= 0 then e.lcd = d.laser.every * (pm >= 3 and 0.7 or 1); e.laser = { t = 0, charge = 1.2, fire = 0.45, dx = nx, dy = ny, dz = nz, hit = false }; Snd.Sfx("boss", R.t) end
                end
                if e.laser then
                    local L = e.laser; L.t = L.t + dt
                    if L.t < L.charge * 0.7 then local k = math.min(1, dt * 3); L.dx, L.dy, L.dz = U.norm(U.lerp(L.dx, nx, k), U.lerp(L.dy, ny, k), U.lerp(L.dz, nz, k)) end
                    local ox, oy, oz = e.x + L.dx * e.r, e.y + L.dy * e.r, e.z + L.dz * e.r
                    local firing = L.t >= L.charge
                    for k = 0, 44 do tele(ox + L.dx * k * 2, oy + L.dy * k * 2, oz + L.dz * k * 2, firing and { 1.6, 1.5, 1.5 } or { 1.2, 0.12, 0.18 }, firing and 0.8 or 0.3) end
                    if firing and not L.hit then
                        L.hit = true; R.shake = math.max(R.shake, 0.3)
                        local wx, wy, wz = R.px - ox, R.py - oy, R.pz - oz; local tt = wx * L.dx + wy * L.dy + wz * L.dz
                        if tt > 0 and tt < 95 and U.len3(wx - L.dx * tt, wy - L.dy * tt, wz - L.dz * tt) < 2.8 then hurtPlayer(R, d.dmg * 1.5) end
                    end
                    if L.t >= L.charge + L.fire then e.laser = nil end
                end
                -- 召唤
                if d.summon then e.sumT = (e.sumT or d.summon) - dt; if e.sumT <= 0 then e.sumT = d.summon * ({ 1, 0.8, 0.6 })[pm]; for _ = 1, 3 do local a = U.rand(0, 6.283); Run.Spawn(R, "crawler", e.x + math.cos(a) * (e.r + 4), e.y, e.z + math.sin(a) * (e.r + 4)) end end end
                -- 射击
                if d.shoot and dist < 60 then
                    local sh = d.shoot; e.fire = e.fire - dt
                    if e.fire <= 0 then
                        e.fire = sh.cd * (d.boss and ({ 1, 0.82, 0.66 })[pm] or 1); e.cnt = (e.cnt or 0) + 1
                        local sp = sh.spd * (d.boss and (1 + 0.08 * (pm - 1)) or 1); local ox, oy, oz = e.x + nx * e.r * 0.9, e.y + ny * e.r * 0.9, e.z + nz * e.r * 0.9
                        if sh.ring then
                            local rn = sh.ring + (d.boss and 4 * (pm - 1) or 0); for k = 1, rn do local a = k / rn * 6.283 + R.t; ebullet(R, e.x, e.y, e.z, math.cos(a), 0, math.sin(a), sp, sh.dmg, "ring") end
                        else
                            if sh.burst then e.bq = sh.burst - 1; e.bt = 0.13 end
                            local nn = sh.n + (d.boss and 2 * (pm - 1) or 0)
                            if sh.big and e.cnt % 2 == 0 then nn = 0; ebullet(R, ox, oy, oz, nx, ny, nz, sp * 0.55, sh.dmg * 2.4, "big") end
                            for k = 1, nn do
                                local off = nn > 1 and math.tan(((k - 1) / (nn - 1) - 0.5) * (sh.spread + (d.boss and 12 * (pm - 1) or 0)) * U.DEG) or 0
                                local ax, ay, az = U.norm(nx - nz * off, ny, nz + nx * off); ebullet(R, ox, oy, oz, ax, ay, az, sp, sh.dmg, "shot")
                            end
                        end
                        Fx.Burst(ox, oy, oz, { 1.4, 0.3, 0.3 }, 2, 6, 0.2, 0.25)
                    end
                    if e.bq and e.bq > 0 then e.bt = e.bt - dt; if e.bt <= 0 then e.bq = e.bq - 1; e.bt = 0.13; ebullet(R, e.x + nx * e.r, e.y + ny * e.r, e.z + nz * e.r, nx, ny, nz, sh.spd, sh.dmg, "shot") end end
                end
                -- 移动 + 分离
                local spd = (lunging and d.lunge.dash or d.spd) * (e.slowT > 0 and 0.45 or 1) * (affix(R, "swift") and 1.25 or 1)
                local ml = U.len3(mx, my, mz); if ml > 1e-3 then mx, my, mz = mx / ml, my / ml, mz / ml end
                local k = 1 - math.exp(-dt * 9); if not lunging then e.dv[1], e.dv[2], e.dv[3] = U.lerp(e.dv[1], mx, k), U.lerp(e.dv[2], my, k), U.lerp(e.dv[3], mz, k) else e.dv[1], e.dv[2], e.dv[3] = mx, my, mz end
                e.x, e.y, e.z = e.x + (e.dv[1] * spd + e.kx) * dt, e.y + e.dv[2] * spd * dt, e.z + (e.dv[3] * spd + e.kz) * dt
                e.kx, e.kz = e.kx * math.exp(-dt * 6), e.kz * math.exp(-dt * 6)
                if #E < 90 then
                    for j = i + 1, #E do local o = E[j]; local sx, sz = e.x - o.x, e.z - o.z; local md = e.r + o.r
                        if sx * sx + sz * sz < md * md and sx * sx + sz * sz > 1e-4 then local sdist = math.sqrt(sx * sx + sz * sz); local push = math.min(0.5, dt * 14) * (md - sdist) * 0.5; e.x, e.z = e.x + sx / sdist * push, e.z + sz / sdist * push; o.x, o.z = o.x - sx / sdist * push, o.z - sz / sdist * push end end
                end
                -- 接触伤害
                e.contact = e.contact - dt
                if dist < e.r + 2.3 and e.contact <= 0 and not d.bomb then hurtPlayer(R, d.dmg * (lunging and 1.6 or 1)); e.contact = 0.8 end
                -- 朝向
                local ty = U.angOf(e.dv[1], 0, e.dv[3]); if ml < 1e-3 then ty = U.angOf(nx, 0, nz) end
                e.yaw = e.yaw + U.wrap(ty - e.yaw) * (d.guard and (1 - math.exp(-dt * 2.2)) or (1 - math.exp(-dt * 10)))
                e.node.position = Vector3(e.x, e.y - (d.ship and 0 or e.r * 0.6), e.z); e.node.rotation = Quaternion(0, e.yaw, 0)
                if dist > 130 and not d.boss then local a = U.rand(0, 6.283); e.x, e.y, e.z = R.px + math.sin(a) * 55, R.py + U.rand(-4, 4), R.pz + math.cos(a) * 55 end
            end
        end
    end
end
local function updateProjectiles(R, dt)
    local S_ = R.shots
    for i = #S_, 1, -1 do
        local s = S_[i]; s.life = s.life - dt; s.x, s.y, s.z = s.x + s.vx * dt, s.y + s.vy * dt, s.z + s.vz * dt; local dead = s.life <= 0
        if not dead then
            for _, e in ipairs(R.enemies) do
                if e.hp > 0 and not s.hit[e] then local dx, dy, dz = e.x - s.x, e.y - s.y, e.z - s.z
                    if dx * dx + dy * dy + dz * dz < (e.r + 0.8) ^ 2 then
                        s.hit[e] = true; if s.md then modHit(R, s.md, e, s.dmg) else hurtEnemy(R, e, s.dmg) end
                        if s.kb then e.kx, e.kz = e.kx + s.vx * 0.05, e.kz + s.vz * 0.05 end
                        if s.pierce <= 0 then dead = true; break else s.pierce = s.pierce - 1 end
                    end end
            end
        end
        if dead then s.node:Remove(); S_[i] = S_[#S_]; S_[#S_] = nil else s.node.position = Vector3(s.x, s.y, s.z) end
    end
    local B = R.ebullets
    for i = #B, 1, -1 do
        local b = B[i]; b.life = b.life - dt; b.x, b.y, b.z = b.x + b.vx * dt, b.y + b.vy * dt, b.z + b.vz * dt
        local rad = b.kind == "big" and 3.3 or 2.3; local dead = b.life <= 0
        if not dead and U.dist2({ x = R.px, y = R.py, z = R.pz }, b) < rad * rad then hurtPlayer(R, b.dmg); dead = true end
        if dead then b.node:Remove(); B[i] = B[#B]; B[#B] = nil else b.node.position = Vector3(b.x, b.y, b.z); if math.random() < 0.4 then Fx.Spawn(b.x, b.y, b.z, { 1.2, 0.2, 0.25 }, 0.3, 0.2) end end
    end
    local M = R.missiles
    for i = #M, 1, -1 do
        local m = M[i]; m.life = m.life - dt; local dead = m.life <= 0; local explode = false
        if m.fall then
            if m.delay and m.delay > 0 then m.delay = m.delay - dt; m.life = m.life + dt; m.node:SetEnabled(false)
            elseif m.rise and m.rise > 0 then m.node:SetEnabled(true); m.rise = m.rise - dt; m.y = m.y + m.vy * dt; if m.rise <= 0 then m.rise = nil; m.x, m.y, m.z = m.tx, m.ty + 30, m.tz; m.vy = -60 end
            else m.node:SetEnabled(true); m.y = m.y + m.vy * dt; if m.y <= m.ty + 0.5 then explode = true end end
            if m.node.enabled ~= false then Fx.Spawn(m.x, m.y + 1, m.z, m.meteor and { 0.9, 0.5, 1.5 } or { 1.4, 0.7, 0.25 }, m.meteor and 1.2 or 0.5, 0.3) end
        else
            local t = m.target; if t and t.hp > 0 then local dx, dy, dz = U.norm(t.x - m.x, t.y - m.y, t.z - m.z); local vl = U.len3(m.vx, m.vy, m.vz); local k = math.min(1, dt * 5)
                local vx, vy, vz = U.norm(U.lerp(m.vx / math.max(vl, 1e-3), dx, k), U.lerp(m.vy / math.max(vl, 1e-3), dy, k), U.lerp(m.vz / math.max(vl, 1e-3), dz, k)); m.vx, m.vy, m.vz = vx * m.spd, vy * m.spd, vz * m.spd
                if (t.x - m.x) ^ 2 + (t.y - m.y) ^ 2 + (t.z - m.z) ^ 2 < (t.r + 1) ^ 2 then explode = true end
            else m.target = findTarget(R, 40); if not m.target then m.vx, m.vy, m.vz = m.vx * 0.99, m.vy * 0.99, m.vz * 0.99 end end
            m.x, m.y, m.z = m.x + m.vx * dt, m.y + m.vy * dt, m.z + m.vz * dt
            if math.random() < 0.6 then Fx.Spawn(m.x, m.y, m.z, m.col or { 1.4, 0.7, 0.25 }, 0.4, 0.3) end
        end
        if explode then
            if (m.splash or 0) > 0 then Fx.Ring(m.x, m.y, m.z, m.splash, m.col or { 1.4, 0.7, 0.25 }, 20, 0.4, 0.3); Fx.Burst(m.x, m.y, m.z, { 1.5, 0.8, 0.3 }, 8, 10, 0.5, 0.6); if m.meteor then R.shake = 0.7; Snd.Sfx("boom", R.t) end
                near(R, m.x, m.y, m.z, m.splash, function(e) if m.md then modHit(R, m.md, e, m.dmg) else hurtEnemy(R, e, m.dmg) end end)
            elseif m.target and m.target.hp > 0 then if m.md then modHit(R, m.md, m.target, m.dmg) else hurtEnemy(R, m.target, m.dmg) end end
            if m.heal then R.hull = math.min(hullMax(R), R.hull + m.heal) end
            dead = true
        end
        if dead then m.node:Remove(); M[i] = M[#M]; M[#M] = nil else m.node.position = Vector3(m.x, m.y, m.z) end
    end
end
-- 升级选项
function Run.XpNeed(l) return math.floor(5 + l * 4 + l * l * 0.35) end
local function evoReady(R, md) local ev = D.EVO[md.base]; return ev and not md.evo and md.lvl >= 5 and R.lv[ev.pass] >= D.EVO_PASS_LV end
function Run.Choices(R)
    local pool, out = {}, {}
    for i, md in ipairs(R.mods) do if evoReady(R, md) and #out < 3 then out[#out + 1] = "evo" .. i end end
    if R.lv.main < 6 then pool[#pool + 1] = { id = "main", w = 1.6 } end
    for i, md in ipairs(R.mods) do if md.lvl < 5 then pool[#pool + 1] = { id = "mod" .. i, w = 1.5 } end end
    local owned = 0; for _, k in ipairs(PASSIVES) do if R.lv[k] > 0 then owned = owned + 1 end end
    for _, k in ipairs(PASSIVES) do if R.lv[k] < 5 and (R.lv[k] > 0 or owned < 4) then pool[#pool + 1] = { id = k, w = 1.0 } end end
    while #out < 3 and #pool > 0 do
        local tot = 0; for _, p in ipairs(pool) do tot = tot + p.w end
        local r, idx = math.random() * tot, 1; for k, p in ipairs(pool) do if r <= p.w then idx = k; break end r = r - p.w; idx = k end
        out[#out + 1] = table.remove(pool, idx).id
    end
    if #out == 0 then out[1] = "heal" end
    return out
end
function Run.ChoiceInfo(R, id)
    if id:sub(1, 3) == "evo" then local md = R.mods[tonumber(id:sub(4))]; local ev = D.EVO[md.base]; local a, b = modStat(R, md), modStat(R, setmetatable({ evo = true }, { __index = md }))
        return { name = md.F.n .. " · " .. ev.n, tag = "★ 进化", text = ev.d .. "。伤害 " .. math.floor(a.dmg) .. " → " .. math.floor(b.dmg) .. "，数量 " .. a.count .. " → " .. b.count, evo = true } end
    if id:sub(1, 3) == "mod" then local md = R.mods[tonumber(id:sub(4))]; local a, b = modStat(R, md), modStat(R, setmetatable({ lvl = md.lvl + 1 }, { __index = md }))
        local t = "伤害 " .. math.floor(a.dmg) .. " → " .. math.floor(b.dmg) .. "，冷却 " .. string.format("%.1f", a.cd) .. "s → " .. string.format("%.1f", b.cd) .. "s"; if a.count ~= b.count then t = t .. "，数量 " .. a.count .. " → " .. b.count end
        local el = ELEM_BY[md.elem]; local rh = D.REACT_HINT[md.elem]; if rh then t = t .. "。元素反应：" .. rh end
        return { name = (el and el.n or "") .. md.F.n, tag = "技能卡牌 Lv" .. (md.lvl + 1), text = t } end
    if id == "heal" then return { name = "紧急维修", tag = "回复", text = "立即回复 40% 耐久" } end
    local u = UPG[id]; return { name = u.name, tag = "强化 Lv" .. (R.lv[id] + 1), text = u.text }
end
function Run.ApplyChoice(R, id)
    if id:sub(1, 3) == "evo" then local md = R.mods[tonumber(id:sub(4))]; md.evo = true; Run.Banner(R, "进化！" .. md.F.n .. " · " .. D.EVO[md.base].n); Snd.Sfx("win", R.t); R.shake = math.max(R.shake, 0.4); Fx.Ring(R.px, R.py - 2, R.pz, 12, { 1.5, 1.2, 0.4 }, 40, 0.5, 0.6)
    elseif id:sub(1, 3) == "mod" then local md = R.mods[tonumber(id:sub(4))]; md.lvl = md.lvl + 1
    elseif id == "heal" then R.hull = math.min(hullMax(R), R.hull + hullMax(R) * 0.4)
    else R.lv[id] = R.lv[id] + 1; if id == "hull" then R.hull = math.min(hullMax(R), R.hull + hullMax(R) * 0.25) end end
    for _, md in ipairs(R.mods) do if evoReady(R, md) and not md.hint then md.hint = true; Run.Banner(R, md.F.n .. " 可以进化了！下次升级必出进化选项") end end
    R.choosing = nil
end
function Run.Reroll(R, viaAd) R.rr = R.rr or { free = 1, ad = 0 }; if viaAd then R.rr.ad = R.rr.ad + 1 else R.rr.free = R.rr.free - 1 end; R.choosing = Run.Choices(R); Snd.Sfx("click", R.t) end
function Run.Skip(R) R.hull = math.min(hullMax(R), R.hull + hullMax(R) * 0.3); R.choosing = nil end

-- 结算
function Run.End(R, win)
    if R.over and not win then return end
    R.over = true; R.won = win
    local sv = S.data; local dgm = 1 + 0.15 * (R.danger - 1)
    local credits = math.floor((R.credits + R.kills * 3 + (win and not R.endless and 800 * R.chId or 0) + (R.endless and R.wave * 60 or 0)) * dgm)
    local src = R.src + (R.endless and math.floor(R.wave / 3) or (win and (R.danger - 1) or 0))
    if not win and not R.endless then credits = math.floor(credits * 0.7) end
    local first = win and not R.endless and not sv.cleared[tostring(R.chId)]
    if first then src = src + (R.ch.first or 30) end
    local unlock = false
    if win and not R.endless then sv.cleared[tostring(R.chId)] = true; sv.chapter = math.max(sv.chapter, math.min(#D.CHAPTERS, R.chId + 1)); if R.danger >= sv.dangerMax and sv.dangerMax < 10 then sv.dangerMax = sv.dangerMax + 1; unlock = true end; sv.bossKills = sv.bossKills + 1 end
    if R.endless and not R.daily then sv.endlessBest = math.max(sv.endlessBest, R.wave) end
    local dcScore, dcFirst = nil, false
    if R.daily then
        dcScore = R.kills * 10 + (R.wave - 1) * 100 + (R.bossKilled or 0) * 300 + (win and 500 or 0)
        local dc = Meta.DailyChallenge().state; dcFirst = not dc.done; dc.done = true; dc.runs = dc.runs + 1; dc.best = math.max(dc.best, dcScore); sv.dcBest = math.max(sv.dcBest or 0, dcScore)
        if dcFirst then credits = credits + 800; src = src + 10 + (dcScore >= 1500 and 5 or 0) end
        if R.hasMod and R.hasMod.iron then credits = math.floor(credits * 1.2) end
    end
    credits = math.floor(credits * (1 + R.st.credit * 0.5))
    Meta.DailyReset(); sv.daily.runs = (sv.daily.runs or 0) + 1; sv.daily.kills = (sv.daily.kills or 0) + R.kills
    sv.credits = sv.credits + credits; sv.src = sv.src + src; sv.runs = sv.runs + 1; sv.kills = sv.kills + R.kills; S.Write()
    R.result = { win = win, credits = credits, src = src, kills = R.kills, level = R.level, wave = R.wave, first = first, unlock = unlock, time = R.t, dcScore = dcScore, dcFirst = dcFirst }
    Snd.Sfx(win and "win" or "hurt", R.t); Snd.Music("hub")
end
function Run.Revive(R) R.over = false; R.won = false; R.result = nil; R.revived = true; R.hull = hullMax(R) * 0.5; R.iframe = 2; R.ebullets = {}; Snd.Music("battle") end


-- ---------------------------------------------------------------- 驾驶员支援技能
local function strongest(R, range)
    local best, bh = nil, -1; for _, e in ipairs(R.enemies) do if e.hp > 0 and not e.d.ore and (e.x - R.px) ^ 2 + (e.z - R.pz) ^ 2 < range * range and e.hp > bh then best, bh = e, e.hp end end return best
end
local function rawHit(R, e, dmg) hurtEnemy(R, e, dmg * (1 + R.st.sup) / dmgMult(R), false) end
local function updateSupport(R, dt)
    local p = R.pilot; if not p or not p.support then return end
    R.supT = R.supT - dt; if R.supT > 0 then return end
    local id = p.id; R.supT = p.support.cd * cdMult(R)
    if id == "char_xingli" then
        local e = strongest(R, 70); if not e then R.supT = 0.5; return end
        local ox, oy, oz = Mech.Muzzle(R.mech, R.mech.fx.fire[1] == "P" and "R" or R.mech.fx.fire[1], 0); ox = ox or R.px; oy = oy or R.py; oz = oz or R.pz
        Fx.Line(ox, oy, oz, e.x, e.y, e.z, { 0.5, 1.4, 1.3 }, 0.3, 0.2, 1.2); rawHit(R, e, 55)
    elseif id == "char_chiyan" then
        local dx, dz = math.sin(R.yaw * U.DEG), math.cos(R.yaw * U.DEG); Fx.Line(R.px, R.py, R.pz, R.px + dx * 32, R.py, R.pz + dz * 32, { 1.5, 0.7, 0.25 }, 0.6, 0.35, 1.2)
        for _, e in ipairs(R.enemies) do if e.hp > 0 then local ex, ez = e.x - R.px, e.z - R.pz; local t = ex * dx + ez * dz; if t > 0 and t < 32 and math.abs(ex * dz - ez * dx) < e.r + 2.5 then rawHit(R, e, 70) end end end
    elseif id == "char_yuexi" then
        R.hull = math.min(hullMax(R), R.hull + 15); Fx.Ring(R.px, R.py - 2, R.pz, 12, { 0.4, 1.2, 0.7 }, 32, 0.4, 0.4); near(R, R.px, R.py, R.pz, 12, function(e) rawHit(R, e, 15) end)
    elseif id == "char_hupo" then addTurret(R); R.turrets[#R.turrets].life = 8
    elseif id == "char_shuangling" then
        local t = findTarget(R, 60); local cx, cy, cz = R.px + math.sin(R.yaw * U.DEG) * 18, R.py, R.pz + math.cos(R.yaw * U.DEG) * 18; if t then cx, cy, cz = t.x, t.y, t.z end
        for j = 1, 7 do local tx, tz = cx + U.rand(-10, 10), cz + U.rand(-10, 10); R.missiles[#R.missiles + 1] = { fall = true, x = tx, y = cy + 30 + j * 2, z = tz, vx = 0, vy = -60, vz = 0, tx = tx, ty = cy, tz = tz, dmg = 12 * (1 + R.st.sup), splash = 5 * (1 + R.st.blast), life = 5, node = Fx.Node({ 1.4, 0.8, 0.3 }, 0.4, 0.4, 1.0), col = { 1.4, 0.8, 0.3 } } end
    elseif id == "char_yeyuan" then
        local best, bn = nil, 0; for _, e in ipairs(R.enemies) do if e.hp > 0 and not e.d.ore then local n = 0; for _, o in ipairs(R.enemies) do if (o.x - e.x) ^ 2 + (o.z - e.z) ^ 2 < 144 then n = n + 1 end end; if n > bn then best, bn = e, n end end end
        if best then R.wells[#R.wells + 1] = { x = best.x, y = best.y, z = best.z, life = 3 }; Fx.Ring(best.x, best.y, best.z, 8, { 0.8, 0.4, 1.4 }, 24, 0.4, 0.5) end
    end
end
local function updateExtras(R, dt)
    for i = #R.mines, 1, -1 do local m = R.mines[i]; m.life = m.life - dt; m.node.position = Vector3(m.x, m.y, m.z); local boom = m.life <= 0
        if not boom then for _, e in ipairs(R.enemies) do if e.hp > 0 and (e.x - m.x) ^ 2 + (e.y - m.y) ^ 2 + (e.z - m.z) ^ 2 < (e.r + 3.5) ^ 2 then boom = true; break end end end
        if boom then if m.life > 0 or true then Fx.Ring(m.x, m.y, m.z, m.r, { 1.5, 0.6, 0.3 }, 24, 0.4, 0.3); Fx.Burst(m.x, m.y, m.z, { 1.5, 0.7, 0.3 }, 8, 10, 0.4, 0.5); near(R, m.x, m.y, m.z, m.r, function(e) modHit(R, m.md, e, m.dmg) end) end; m.node:Remove(); table.remove(R.mines, i) end end
    for i = #R.booms, 1, -1 do local b = R.booms[i]; b.t = b.t + dt
        if b.out then b.x, b.y, b.z = b.x + b.dx * 38 * dt, b.y + b.dy * 38 * dt, b.z + b.dz * 38 * dt; if b.t > 0.55 then b.out = false; b.hit = {} end
        else local dx, dy, dz = U.norm(R.px - b.x, R.py - b.y, R.pz - b.z); b.x, b.y, b.z = b.x + dx * 46 * dt, b.y + dy * 46 * dt, b.z + dz * 46 * dt end
        for _, e in ipairs(R.enemies) do if e.hp > 0 and not b.hit[e] and (e.x - b.x) ^ 2 + (e.y - b.y) ^ 2 + (e.z - b.z) ^ 2 < (e.r + 1.4) ^ 2 then b.hit[e] = true; modHit(R, b.md, e, b.dmg) end end
        b.node.position = Vector3(b.x, b.y, b.z); b.node.rotation = Quaternion(0, b.t * 900, 0)
        if (not b.out and (b.x - R.px) ^ 2 + (b.z - R.pz) ^ 2 < 9) or b.t > 3 then b.node:Remove(); table.remove(R.booms, i) end end
    for i = #R.wells, 1, -1 do local w = R.wells[i]; w.life = w.life - dt
        for _, e in ipairs(R.enemies) do if e.hp > 0 and not e.d.boss then local dx, dz = w.x - e.x, w.z - e.z; local d2 = dx * dx + dz * dz; if d2 < 225 and d2 > 1 then local d = math.sqrt(d2); e.kx, e.kz = e.kx + dx / d * 30 * dt, e.kz + dz / d * 30 * dt; hurtEnemy(R, e, 16 * dt * (1 + R.st.sup) / dmgMult(R), false, true) end end end
        if w.life <= 0 then table.remove(R.wells, i) end end
end

-- ================================================================ 主更新
-- inp: { jx, jy（-1..1，屏幕方向）, camdx（相机转动度数）, nitro, skill（本帧是否按下） }
function Run.Update(R, dt, inp)
    if not R then return end
    if R.over then Fx.Update(dt); return end
    if R.choosing then return end
    if R.hitstop > 0 then R.hitstop = R.hitstop - dt; dt = dt * 0.1 end
    R.t = R.t + dt; R.secT = R.secT + dt
    for i = #R.sched, 1, -1 do local s = R.sched[i]; s.t = s.t - dt; if s.t <= 0 then table.remove(R.sched, i); s.fn() end end
    R.camYaw = R.camYaw + (inp.camdx or 0)
    R.iframe = math.max(0, R.iframe - dt); R.activeCd = math.max(0, R.activeCd - dt); R.nitroCd = math.max(0, R.nitroCd - dt); R.nitroT = math.max(0, R.nitroT - dt); R.comboT = R.comboT - dt; if R.comboT <= 0 then R.combo = 0 end
    R.bannerT = math.max(0, R.bannerT - dt); R.shake = math.max(0, R.shake - dt * 1.6)
    if inp.nitro then Run.Nitro(R) end
    if inp.skill then Run.CastActive(R) end
    local sp = speed(R)
    -- 移动
    local cyaw = R.camYaw * U.DEG; local fx, fz, rx, rz = math.sin(cyaw), math.cos(cyaw), math.cos(cyaw), -math.sin(cyaw)
    local tvx, tvz = (fx * (inp.jy or 0) + rx * (inp.jx or 0)) * sp, (fz * (inp.jy or 0) + rz * (inp.jx or 0)) * sp
    local d = R.dash
    if d then
        d.t = d.t + dt; local k = math.min(1, d.t / d.dur); if d.easeOut then k = 1 - (1 - k) * (1 - k) end; if d.invT then d.inv = d.t < d.invT end
        R.px, R.pz = U.lerp(d.x0, d.x1, k), U.lerp(d.z0, d.z1, k)
        if d.dmg > 0 then near(R, R.px, R.py, R.pz, 4, function(e) if not d.hit[e] then d.hit[e] = true; hurtEnemy(R, e, d.dmg / dmgMult(R)); e.kx, e.kz = e.kx + (e.x - R.px) * 6, e.kz + (e.z - R.pz) * 6 end end) end
        local g = glowCol(R); Fx.Burst(R.px, R.py, R.pz, { g[1] * 1.4, g[2] * 1.4, g[3] * 1.4 }, 3, 5, 0.5, 0.7)
        if d.t >= d.dur then R.dash = nil; R.iframe = 0.1 end
        R.vx, R.vz = (d.x1 - d.x0) / d.dur * 0.3, (d.z1 - d.z0) / d.dur * 0.3
    else
        local kk = math.min(1, dt * 6); R.vx, R.vz = U.lerp(R.vx, tvx, kk), U.lerp(R.vz, tvz, kk); R.px, R.pz = R.px + R.vx * dt, R.pz + R.vz * dt
    end
    local vl = math.sqrt(R.vx * R.vx + R.vz * R.vz)
    -- 目标与朝向
    R.tgT = R.tgT - dt; if R.tgT <= 0 or (R.tg and R.tg.hp <= 0) then R.tgT = 0.2; R.tg = findTarget(R, 48) end
    local tg = R.tg and R.tg.hp > 0 and R.tg or nil
    local ty = vl > 1.5 and (U.angOf(R.vx, 0, R.vz)) or R.camYaw
    if R.dash and R.dash.dx then ty = U.angOf(R.dash.dx, 0, R.dash.dz) end
    local yawL, dwn = 0, 0
    if tg then local gy, gp = U.angOf(tg.x - R.px, tg.y - R.py, tg.z - R.pz); local dl = U.wrap(gy - ty); if math.abs(dl) > 40 then ty = ty + dl - (dl > 0 and 40 or -40) end; yawL = U.wrap(gy - R.yaw); dwn = gp - R.mech.p.lean end
    R.yaw = R.yaw + U.clamp(U.wrap(ty - R.yaw), -400 * dt, 400 * dt)
    -- 姿态
    local fxs, fzs = math.sin(R.yaw * U.DEG), math.cos(R.yaw * U.DEG); local vf, vs = R.vx * fxs + R.vz * fzs, R.vx * fzs - R.vz * fxs
    local af = (vf - (R.vfPrev or 0)) / math.max(dt, 0.001) / 70; R.vfPrev = vf
    Mech.Update(R.mech, { fk = vf / sp, sk = vs / sp, uk = 0, af = af, dashing = R.dash ~= nil, tg = tg ~= nil, yawL = yawL, dwn = dwn, t = R.t }, dt)
    local P = R.mech.p
    R.mech.root.position = Vector3(R.px, R.py - 2.4 + math.sin(R.t * 3) * 0.12, R.pz); R.mech.root.rotation = Quaternion(P.lean, R.yaw, P.bank)
    -- 尾焰
    local thr = P.thrR; for _, n in ipairs(R.mech.rear) do if math.random() < 0.35 + thr * 0.5 then local x, y, z = Mech.Point(n); local g = glowCol(R); local bx, bz = -fxs, -fzs; Fx.Spawn(x, y, z, { g[1] * 1.3, g[2] * 1.3, g[3] * 1.3 }, 0.5 + thr * 0.4, 0.3 + 0.2 * thr, bx * (5 + 6 * thr) - R.vx * 0.15, U.rand(-1, 1), bz * (5 + 6 * thr) - R.vz * 0.15) end end
    -- 战斗
    fireMain(R, dt); updateMods(R, dt)
    updateEnemies(R, dt); updateProjectiles(R, dt)
    -- 回复 / 区域 / 炮台 / 拾取
    local regen = 0.6 * R.lv.repair + R.st.regen + ((R.pilot and R.pilot.passive and R.pilot.passive.fx and R.pilot.passive.fx.regen) and hullMax(R) * R.pilot.passive.fx.regen or 0)
    if regen > 0 then R.hull = math.min(hullMax(R), R.hull + regen * dt) end
    for i = #R.zones, 1, -1 do local z = R.zones[i]; z.life = z.life - dt; z.tick = z.tick - dt
        if (R.px - z.x) ^ 2 + (R.pz - z.z) ^ 2 < z.r * z.r then R.hull = math.min(hullMax(R), R.hull + hullMax(R) * 0.08 * dt) end
        if z.tick <= 0 then z.tick = 0.5; Fx.Ring(z.x, z.y - 2, z.z, z.r, { 0.4, 1.2, 0.7 }, 28, 0.3, 0.5) end
        if z.life <= 0 then table.remove(R.zones, i) end end
    for i = #R.turrets, 1, -1 do local t = R.turrets[i]; t.life = t.life - dt; t.fire = t.fire - dt; t.node.position = Vector3(t.x, t.y - 1, t.z)
        if t.fire <= 0 then local e = nil; local bd = 34 * 34; for _, en in ipairs(R.enemies) do if en.hp > 0 then local d2 = (en.x - t.x) ^ 2 + (en.y - t.y) ^ 2 + (en.z - t.z) ^ 2; if d2 < bd then bd, e = d2, en end end end
            if e then t.fire = 0.4; local dx, dy, dz = U.norm(e.x - t.x, e.y - t.y, e.z - t.z); newShot(R, t.x, t.y + 1, t.z, dx, dy, dz, 60, 3.5 * (1 + R.st.summon), 1, 0.8, { 1.5, 1.0, 0.4 }, 0.22, 1.2) else t.fire = 0.2 end end
        if t.life <= 0 then t.node:Remove(); table.remove(R.turrets, i) end end
    local magnet = (18 + 5 * R.lv.magnet) * (1 + R.st.pickup)                  -- 击杀点离机甲较远（射程 42），宝石在一定范围内会被吸过来，并缓慢向机甲漂移
    for i = #R.gems, 1, -1 do local g = R.gems[i]; local dx, dy, dz = R.px - g.x, R.py - g.y, R.pz - g.z; local dist = U.len3(dx, dy, dz)
        if dist < magnet then g.pull = true end
        if g.pull then local s = math.min(1, dt * 7); g.x, g.y, g.z = g.x + dx * s, g.y + dy * s, g.z + dz * s
        elseif dist < 70 then local s = math.min(1, dt * 6 / math.max(dist, 1)); g.x, g.y, g.z = g.x + dx * s, g.y + dy * s, g.z + dz * s end
        g.node.position = Vector3(g.x, g.y, g.z)
        if dist < 1.8 then R.xp = R.xp + g.v * (1 + R.st.xp) * (affix(R, 'fury') and 1.3 or (affix(R, 'tide') and 1.5 or 1)); Snd.Sfx("pick", R.t); g.node:Remove(); table.remove(R.gems, i)
            while R.xp >= Run.XpNeed(R.level) do R.xp = R.xp - Run.XpNeed(R.level); R.level = R.level + 1; R.pendingLevels = R.pendingLevels + 1 end end end
    for i = #R.pickups, 1, -1 do local p = R.pickups[i]; p.node.position = Vector3(p.x, p.y, p.z); if U.dist2({ x = R.px, y = R.py, z = R.pz }, p) < 9 then R.hull = math.min(hullMax(R), R.hull + hullMax(R) * 0.25); p.node:Remove(); table.remove(R.pickups, i); Snd.Sfx("pick", R.t) end end
    for i = #R.nums, 1, -1 do local n = R.nums[i]; n.life = n.life - dt; n.y = n.y + dt * 3; if n.life <= 0 then table.remove(R.nums, i) end end
    -- 目标 / 刷怪 / 首领 / 每日挑战
    updateObjective(R, dt); updateSupport(R, dt); updateExtras(R, dt)
    local cap = math.floor((34 + 10 * R.sector + 8 * R.chId) * (1 + 0.05 * (R.danger - 1)) * (affix(R, "tide") and 1.3 or 1))
    local rate = (R.phase == "boss" and 0.35 or (0.9 + 0.22 * R.sector + R.secT / 120)) * (1 + 0.06 * (R.danger - 1)) * (affix(R, "tide") and 1.25 or 1)
    if R.endless then
        local w = 1 + math.floor(R.t / 45)
        if w > R.wave then R.wave = w; R.secMul = 1 + 0.12 * (w - 1); Run.Banner(R, (R.daily and "每日挑战" or "无尽模式") .. "：第 " .. w .. " 波"); Snd.Sfx("gate", R.t)
            if w % 5 == 0 and not R.boss then R.bossScale = (1 + 0.12 * (R.danger - 1)) * (1 + 0.3 * (w / 5 - 1)); Run.Spawn(R, R.ch.boss, R.px, R.py, R.pz + 50); R.phase = "boss"; Run.Banner(R, "第 " .. w .. " 波首领：" .. D.ENEMY[R.ch.boss].name) end end
        cap = math.min(150, math.floor((38 + 6 * R.wave) * (affix(R, "tide") and 1.3 or 1))); rate = (1.1 + 0.18 * R.wave) * (affix(R, "tide") and 1.25 or 1)
        if R.hasMod and R.hasMod.elite and math.floor(R.t / 40) > (R.eliteN or 0) then R.eliteN = math.floor(R.t / 40); Run.Spawn(R, "brute", R.px, R.py, R.pz + 45); Run.Banner(R, "精英出现！") end
        if R.daily and R.t >= D.DC_TIME then Run.End(R, true) end
    end
    R.spawnAcc = (R.spawnAcc or 0) + rate * dt
    while R.spawnAcc >= 1 do R.spawnAcc = R.spawnAcc - 1; if #R.enemies < cap then spawnAround(R, roamType(R)) end end
    if R.hull <= 0 then
        if R.st.traits.revive and not R.reviveUsed then R.reviveUsed = true; R.hull = hullMax(R) * 0.4; R.iframe = 2; Run.Banner(R, "星魂庇护：自动复活") else Run.End(R, false) end
    end
    if R.pendingLevels > 0 and not R.over then R.pendingLevels = R.pendingLevels - 1; R.choosing = Run.Choices(R); Snd.Sfx("level", R.t) end
    Fx.Update(dt)
end
function Run.UpdateCamera(R, dt)
    local dist, h = 15, 5
    local eyeYaw = R.camYaw; local fx, fy, fz = U.fwdOf(eyeYaw, R.camPitch)
    R.cx = R.cx and U.lerp(R.cx, R.px, 1 - math.exp(-dt * 8)) or R.px; R.cz = R.cz and U.lerp(R.cz, R.pz, 1 - math.exp(-dt * 8)) or R.pz
    local sx, sy = U.rand(-1, 1) * R.shake * 0.5, U.rand(-1, 1) * R.shake * 0.5
    camNode_.position = Vector3(R.cx - fx * dist + sx, R.py + h - fy * dist * 0.35 + sy, R.cz - fz * dist)
    camNode_:LookAt(Vector3(R.px + fx * 8, R.py + 1.5, R.pz + fz * 8))
end
function Run.Clear() if Run.R then Run.R = nil end content_:RemoveAllChildren(); enemyRoot_:RemoveAllChildren(); Fx.Reset(); player_ = nil end
Run.buildStars = buildStars; Run.MECH_BY = MECH_BY; Run.FORM_BY = FORM_BY; Run.ELEM_BY = ELEM_BY; Run.PASSIVES = PASSIVES
Run.Affix = affix; Run.OBJ = OBJ; Run.NewObjective = newObjective; Run.ObjDone = objDone
function Run.Content() return content_ end
function Run.Protos() return protos_ end
return Run
