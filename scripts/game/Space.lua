-- Space.lua
-- 太空飞行模拟：星系加载、玩家飞行、海贼 AI、激光与导弹、碰撞、采矿、掉落、粒子、追尾相机。
-- 逐函数对应 preview/src/game.js，规则与数值相同（数值来自 voxeldata/GameData.lua）。

local G = require("voxeldata.GameData")
local U = require("game.Util")
local S = require("game.Save")
local VoxelBuilder = require("game.VoxelBuilder")
local Layout = require("game.Layout")

local Space = {}
local T = G.tuning

local scene_, content_, protos_, fxRoot_ = nil, nil, nil, nil
local camNode_, camera_, viewport_, renderPath_ = nil, nil, nil, nil
local zone_, keyNode_, keyLight_, fillNode_, fillLight_ = nil, nil, nil, nil, nil
local starsNode_ = nil
local pools_ = {}

local W = { sys = nil, ents = {}, projs = {}, parts = {}, t = 0, player = nil, target = nil, nav = nil, auto = false, spawnTimer = 0 }
Space.W = W
Space.input = { sx = 0, sy = 0, fire = false, boost = false, throttleDelta = 0 }
Space.cam = { pos = nil, target = { 0, 0, 0 }, fov = 62 }
-- 由 Game 注入：toast(msg)、onHit()、onDead()
Space.events = { toast = function() end, onHit = function() end, onDead = function() end }

local function Toast(msg) Space.events.toast(msg) end

-- ---------------------------------------------------------------- 初始化
function Space.Init()
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    local zn = scene_:CreateChild("Zone")
    zone_ = zn:CreateComponent("Zone")
    zone_.boundingBox = BoundingBox(Vector3(-20000, -20000, -20000), Vector3(20000, 20000, 20000))
    zone_.fogStart = 5000
    zone_.fogEnd = 9000
    keyNode_ = scene_:CreateChild("Key")
    keyLight_ = keyNode_:CreateComponent("Light")
    keyLight_.lightType = LIGHT_DIRECTIONAL
    keyLight_.castShadows = false
    fillNode_ = scene_:CreateChild("Fill")
    fillLight_ = fillNode_:CreateComponent("Light")
    fillLight_.lightType = LIGHT_DIRECTIONAL
    fillLight_.castShadows = false
    camNode_ = scene_:CreateChild("Camera")
    camera_ = camNode_:CreateComponent("Camera")
    camera_.nearClip = 0.5
    camera_.farClip = 9000
    viewport_ = Viewport:new(scene_, camera_)
    renderPath_ = viewport_:GetRenderPath()
    renderPath_:Append(cache:GetResource("XMLFile", "PostProcess/Bloom.xml"))
    renderPath_:Append(cache:GetResource("XMLFile", "PostProcess/FXAA3.xml"))
    protos_ = scene_:CreateChild("Prototypes")
    content_ = scene_:CreateChild("Content")
    fxRoot_ = scene_:CreateChild("Effects")
    print("[Space] Init 完成")
end

function Space.Activate()
    renderer:SetViewport(0, viewport_)
end

function Space.GetCamera() return camera_, camNode_ end

-- 换船后为玩家重新生成网格节点
function Space.ReplacePlayerModel(p)
    p.node = VoxelBuilder.Instance(protos_, content_, p.model)
end

-- ---------------------------------------------------------------- 节点池（激光、导弹、粒子）
local function Acquire(model)
    local pool = pools_[model]
    if not pool then pool = { free = {} }; pools_[model] = pool end
    local node = table.remove(pool.free)
    if not node then
        node = VoxelBuilder.Instance(protos_, fxRoot_, model)
    end
    node:SetEnabled(true)
    return node
end

local function Release(model, node)
    node:SetEnabled(false)
    table.insert(pools_[model].free, node)
end

-- ---------------------------------------------------------------- 实体
local nextId_ = 1
local function Ent(o)
    o.id = nextId_; nextId_ = nextId_ + 1
    o.scale = o.scale or 1
    o.yaw, o.pitch, o.roll = o.yaw or 0, o.pitch or 0, o.roll or 0
    o.radius = VoxelBuilder.Radius(o.model) * o.scale
    o.node = VoxelBuilder.Instance(protos_, content_, o.model)
    o.vel = o.vel or { 0, 0, 0 }
    W.ents[#W.ents + 1] = o
    return o
end

local function RemoveEnt(e)
    for i, x in ipairs(W.ents) do
        if x == e then table.remove(W.ents, i); break end
    end
    if e.node then e.node:Remove(); e.node = nil end
    if W.target == e then W.target = nil end
    if W.nav == e then W.nav = nil; W.auto = false end
end

local function Alive(e)
    for _, x in ipairs(W.ents) do if x == e then return true end end
    return false
end
Space.Alive = Alive

function Space.ByKind(k)
    for _, e in ipairs(W.ents) do if e.kind == k then return e end end
    return nil
end

local function ApplyEnv(env)
    zone_.ambientColor = Color(env.ambient[1], env.ambient[2], env.ambient[3])
    zone_.fogColor = Color(env.bg[1], env.bg[2], env.bg[3])
    keyNode_.direction = Vector3(env.key.dir[1], env.key.dir[2], env.key.dir[3]):Normalized()
    keyLight_.color = Color(env.key.color[1], env.key.color[2], env.key.color[3])
    keyLight_.brightness = env.key.brightness
    fillNode_.direction = Vector3(env.fill.dir[1], env.fill.dir[2], env.fill.dir[3]):Normalized()
    fillLight_.color = Color(env.fill.color[1], env.fill.color[2], env.fill.color[3])
    fillLight_.brightness = env.fill.brightness
    renderPath_:SetShaderParameter("BloomThreshold", Variant(env.bloom.threshold))
    renderPath_:SetShaderParameter("BloomMix", Variant(Vector2(1.0, env.bloom.mix)))
end

function Space.SpawnPirate(ptype, pos, boss)
    local pd = W.sys.pirates
    ptype = ptype or pd.types[math.random(#pd.types)]
    local base = pos or pd.spawns[math.random(#pd.spawns)]
    local d = U.byId(G.enemies, ptype)
    local p = U.add(base, { U.rand(-150, 150), U.rand(-60, 60), U.rand(-150, 150) })
    return Ent({ kind = "pirate", model = ptype, def = d, pos = p, yaw = U.rand(0, 360), speed = d.speed * 0.6,
                 hull = d.hull, shield = d.shield, shieldCd = 0, fireCd = U.rand(0.5, 2), state = "patrol",
                 home = U.copy(p), wp = U.copy(p), timer = 0, boss = boss and true or false, name = d.name })
end

function Space.LoadSystem(id, arrive)
    local sys = S.SysById(id)
    print("[Space] 载入星系 " .. sys.name)
    content_:RemoveAllChildren()
    for _, pr in ipairs(W.projs) do Release(pr.model, pr.node) end
    for _, pa in ipairs(W.parts) do Release(pa.model, pa.node) end
    W.sys, W.ents, W.projs, W.parts = sys, {}, {}, {}
    W.target, W.nav, W.auto, W.spawnTimer = nil, nil, false, 3
    ApplyEnv(sys.env)
    starsNode_ = VoxelBuilder.BuildStars(content_, sys.stars)
    for _, d in ipairs(sys.decor) do Ent({ kind = "decor", model = d.model, pos = U.copy(d.pos), yaw = d.yaw, scale = d.scale, spin = d.spin }) end
    for _, s in ipairs(sys.stations) do Ent({ kind = "station", model = s.model, pos = U.copy(s.pos), scale = s.scale, spin = 3, name = s.name, st = s }) end
    for _, g in ipairs(sys.gates) do Ent({ kind = "gate", model = "space_jumpgate", pos = U.copy(g.pos), yaw = g.yaw, scale = 2.5, name = g.name, to = g.to }) end
    if sys.base then Ent({ kind = "base", model = sys.base.model, pos = U.copy(sys.base.pos), scale = sys.base.scale, name = sys.base.name, spin = 1 }) end
    for _, a in ipairs(sys.asteroids) do
        local crystal = a.model == "space_asteroid_b"
        Ent({ kind = crystal and "crystal" or "rock", model = a.model, pos = U.copy(a.pos), yaw = a.yaw, pitch = a.pitch,
              scale = a.scale, spin = a.spin, hp = crystal and 150 or 0 })
    end
    for _, a in ipairs(sys.ore) do
        Ent({ kind = "ore", model = a.model, pos = U.copy(a.pos), yaw = a.yaw, pitch = a.pitch, scale = a.scale, spin = a.spin, hp = 70 })
    end
    for _, d in ipairs(sys.derelicts) do Ent({ kind = "rock", model = d.model, pos = U.copy(d.pos), yaw = d.yaw, scale = d.scale, spin = 0.5 }) end
    -- 玩家
    local st = S.Stats()
    local spawnPos, spawnYaw = U.copy(sys.spawn.pos), sys.spawn.yaw
    if arrive then
        for _, g in ipairs(sys.gates) do
            if g.to == arrive then
                spawnPos = U.add(g.pos, U.mul(U.fwdOf(g.yaw, 0), 160)); spawnYaw = g.yaw
            end
        end
    end
    local p = Ent({ kind = "player", model = S.data.ship, pos = spawnPos, yaw = spawnYaw, speed = 0, throttle = 0.4,
                    hull = st.hullMax - S.data.hullDmg, shield = st.shieldMax, shieldCd = 0, fireCd = 0, missileCd = 0, boost = 100, bumpCd = 0 })
    if arrive and st.fx.jumpShield == 0 then p.shield = math.min(p.shield, st.shieldMax * 0.5) end
    W.player = p
    if sys.boss and S.data.story == 2 then Space.SpawnPirate(sys.boss.type, sys.boss.pos, true) end
    for _ = 1, math.min(2, sys.pirates.max) do Space.SpawnPirate(nil) end
    Space.cam.pos = nil
    S.data.system = id
    local st2 = VoxelBuilder.GetStats()
    print(string.format("[Space] %d 个实体，累计网格 %d 个模型 / %d 个顶点", #W.ents, st2.models, st2.vertices))
end

-- ---------------------------------------------------------------- 飞行
local function SteerToward(o, dir, turn, dt)
    local ty, tp = U.anglesTo(dir)
    local dy, dp = U.wrap180(ty - o.yaw), tp - o.pitch
    local m = turn * dt
    o.yaw = o.yaw + U.clamp(dy, -m, m)
    o.pitch = U.clamp(o.pitch + U.clamp(dp, -m, m), -80, 80)
    return dy, dp
end

local function KeyDown(k) return input:GetKeyDown(k) end

local function UpdatePlayer(dt)
    local p, st, inp = W.player, S.Stats(), Space.input
    local sx, sy = inp.sx, inp.sy
    if KeyDown(KEY_A) or KeyDown(KEY_LEFT) then sx = -1 end
    if KeyDown(KEY_D) or KeyDown(KEY_RIGHT) then sx = 1 end
    if KeyDown(KEY_W) or KeyDown(KEY_UP) then sy = 1 end
    if KeyDown(KEY_S) or KeyDown(KEY_DOWN) then sy = -1 end
    if KeyDown(KEY_R) then p.throttle = U.clamp(p.throttle + dt * 0.8, 0, 1) end
    if KeyDown(KEY_F) then p.throttle = U.clamp(p.throttle - dt * 0.8, 0, 1) end
    local manual = math.abs(sx) > 0.15 or math.abs(sy) > 0.15
    if manual and W.auto then W.auto = false; Toast("自动导航已关闭") end
    local rollTarget = 0
    if W.auto and W.nav then
        local d = U.dist(p.pos, W.nav.pos)
        local reach = W.nav.kind == "gate" and T.gateRange * 0.6 or W.nav.radius + T.dockRange * 0.6
        local dy = SteerToward(p, U.sub(W.nav.pos, p.pos), st.turn, dt)
        rollTarget = U.clamp(-dy, -30, 30)
        p.throttle = (d < reach) and 0 or (d < reach + 400 and 0.35 or 1)
        if d < reach then W.auto = false; Toast("已抵达 " .. W.nav.name) end
    else
        p.yaw = p.yaw + sx * st.turn * dt
        p.pitch = U.clamp(p.pitch - sy * st.turn * 0.8 * dt, -80, 80)
        rollTarget = -sx * 35
    end
    p.roll = U.lerp(p.roll, rollTarget, 1 - math.exp(-dt * 5))
    local boosting = (inp.boost or KeyDown(KEY_SHIFT)) and p.boost > 0
    p.boost = U.clamp(p.boost + (boosting and -T.boostDrain or T.boostRegen) * dt, 0, 100)
    local targetSpeed = p.throttle * st.speed * (boosting and T.boostMult or 1)
    p.speed = U.lerp(p.speed, targetSpeed, 1 - math.exp(-dt * 1.6))
    p.boosting = boosting
    p.vel = U.mul(U.fwdOf(p.yaw, p.pitch), p.speed)
    p.pos = U.add(p.pos, U.mul(p.vel, dt))
    p.fireCd = p.fireCd - dt
    p.missileCd = p.missileCd - dt
    if (inp.fire or KeyDown(KEY_SPACE)) and p.fireCd <= 0 then
        Space.FireLaser(st); p.fireCd = 1 / st.rof
    end
    p.shieldCd = p.shieldCd - dt
    if p.shieldCd <= 0 then p.shield = math.min(st.shieldMax, p.shield + st.regen * dt) end
end

local function AimDir(p)
    local f, t = U.fwdOf(p.yaw, p.pitch), W.target
    if t and t.kind == "pirate" and Alive(t) then
        local d = U.dist(p.pos, t.pos)
        if d < T.aimAssistRange then
            local lead = U.add(t.pos, U.mul(t.vel, d / T.laserSpeed))
            local dir = U.norm(U.sub(lead, p.pos))
            if U.dot(dir, f) > math.cos(T.aimAssistDeg * U.DEG) then return dir end
        end
    end
    return f
end

local function AddProj(pr)
    pr.node = Acquire(pr.model)
    W.projs[#W.projs + 1] = pr
end

function Space.FireLaser(st)
    local p = W.player
    local dir, right, f = AimDir(p), U.rightOf(p.yaw), U.fwdOf(p.yaw, p.pitch)
    for g = 1, st.guns do
        local side = st.guns == 1 and 0 or (g == 1 and -1 or 1)
        local origin = U.add(U.add(p.pos, U.mul(f, p.radius * 0.9)), U.mul(right, side * p.radius * 0.6))
        AddProj({ model = "fx_laser_player", pos = origin, vel = U.add(U.mul(dir, T.laserSpeed), p.vel), life = T.laserLife, dmg = st.laserDmg, owner = "player" })
    end
end

local function NearestEnemy(range)
    local best, bd = nil, range
    for _, e in ipairs(W.ents) do
        if e.kind == "pirate" then
            local d = U.dist(e.pos, W.player.pos)
            if d < bd then bd = d; best = e end
        end
    end
    return best
end

function Space.FireMissile()
    local p, st = W.player, S.Stats()
    if S.data.missiles <= 0 then Toast("导弹已用完，到星港船坞补充"); return end
    if p.missileCd > 0 then return end
    local t = (W.target and W.target.kind == "pirate") and W.target or NearestEnemy(1200)
    S.data.missiles = S.data.missiles - 1
    p.missileCd = 0.6
    AddProj({ model = "fx_missile", missile = true, pos = U.add(p.pos, U.mul(U.fwdOf(p.yaw, p.pitch), p.radius)), yaw = p.yaw, pitch = p.pitch,
              speed = G.missile.speed, life = 6, dmg = st.missileDmg, owner = "player", target = t, vel = { 0, 0, 0 } })
end

function Space.CycleTarget()
    local p, st = W.player, S.Stats()
    local list = {}
    for _, e in ipairs(W.ents) do
        if e.kind == "pirate" and U.dist(e.pos, p.pos) < st.radar then list[#list + 1] = e end
    end
    table.sort(list, function(a, b) return U.dist(a.pos, p.pos) < U.dist(b.pos, p.pos) end)
    for _, e in ipairs(W.ents) do
        if e.kind == "station" or e.kind == "gate" or e.kind == "base" then list[#list + 1] = e end
    end
    if #list == 0 then return end
    local idx = 0
    for i, e in ipairs(list) do if e == W.target then idx = i end end
    W.target = list[idx % #list + 1]
    if W.target.kind ~= "pirate" then W.nav = W.target end
end

function Space.ToggleAuto()
    if not W.nav then
        W.nav = (W.target and W.target.kind ~= "pirate") and W.target or Space.ByKind("station")
    end
    W.auto = (not W.auto) and W.nav ~= nil
    Toast(W.auto and ("自动导航：前往 " .. W.nav.name) or "自动导航已关闭")
end

function Space.NavTo(e)
    W.nav = e; W.target = e; W.auto = true
    Toast("自动导航：前往 " .. e.name)
end

-- ---------------------------------------------------------------- 海贼 AI
local function UpdatePirates(dt)
    local p = W.player
    for _, e in ipairs(W.ents) do
        if e.kind == "pirate" then
            local d = e.def
            local toP = U.sub(p.pos, e.pos)
            local dp = U.len(toP)
            e.timer = e.timer - dt; e.fireCd = e.fireCd - dt; e.shieldCd = e.shieldCd - dt
            if e.shieldCd <= 0 then e.shield = math.min(d.shield, e.shield + d.shield * 0.08 * dt) end
            local aggro = e.boss and 1500 or 1100
            if e.state == "patrol" and (dp < aggro or e.hurt) then e.state = "attack" end
            local dir, spd = nil, d.speed
            if e.state == "patrol" then
                if U.dist(e.pos, e.wp) < 60 or e.timer <= 0 then
                    e.wp = U.add(e.home, { U.rand(-400, 400), U.rand(-120, 120), U.rand(-400, 400) }); e.timer = 12
                end
                dir = U.sub(e.wp, e.pos); spd = d.speed * 0.5
            elseif e.state == "evade" then
                dir = e.evadeDir
                if e.timer <= 0 then e.state = "attack" end
            else
                local lead = U.add(p.pos, U.mul(p.vel, dp / T.enemyLaserSpeed))
                dir = U.sub(lead, e.pos)
                if dp < (e.boss and 260 or 110) then
                    e.state = "evade"; e.timer = U.rand(1.5, 2.6)
                    e.evadeDir = U.norm(U.add(U.norm(U.sub(e.pos, p.pos)), { U.rand(-1, 1), U.rand(-0.6, 0.6), U.rand(-1, 1) }))
                end
                if dp > 2600 then e.state = "patrol" end
            end
            local dy = SteerToward(e, dir, d.turn, dt)
            e.roll = U.lerp(e.roll, U.clamp(-dy, -40, 40), 1 - math.exp(-dt * 4))
            e.speed = U.lerp(e.speed, spd, 1 - math.exp(-dt))
            e.vel = U.mul(U.fwdOf(e.yaw, e.pitch), e.speed)
            e.pos = U.add(e.pos, U.mul(e.vel, dt))
            if e.state == "attack" and dp < d.range and e.fireCd <= 0 then
                local aim = U.norm(U.sub(U.add(p.pos, U.mul(p.vel, dp / T.enemyLaserSpeed)), e.pos))
                local cone = e.boss and 0.6 or math.cos(10 * U.DEG)
                if U.dot(aim, U.fwdOf(e.yaw, e.pitch)) > cone then
                    local spread = { U.rand(-0.03, 0.03), U.rand(-0.03, 0.03), U.rand(-0.03, 0.03) }
                    AddProj({ model = "fx_laser_enemy", pos = U.add(e.pos, U.mul(aim, e.radius)), vel = U.mul(U.norm(U.add(aim, spread)), T.enemyLaserSpeed),
                              life = 2.2, dmg = d.dmg, owner = "enemy" })
                    e.fireCd = 1 / d.rof * U.rand(0.8, 1.3)
                end
            end
        end
    end
end

-- ---------------------------------------------------------------- 伤害、掉落、粒子
local function Spark(at, model, n, spd, life)
    for _ = 1, n do
        if #W.parts >= 300 then return end
        W.parts[#W.parts + 1] = { model = model, node = Acquire(model), pos = U.copy(at),
                                  vel = { U.rand(-1, 1) * spd, U.rand(-1, 1) * spd, U.rand(-1, 1) * spd },
                                  life = life * U.rand(0.6, 1.2), max = life, size = U.rand(1.5, 3) }
    end
end

local function Explode(at, radius)
    local k = U.clamp(radius / 3, 1, 6)
    Spark(at, "fx_spark", math.floor(30 * k), 25 * k, 1.1)
    Spark(at, "fx_debris", math.floor(20 * k), 18 * k, 2.2)
    Spark(at, "fx_spark_teal", math.floor(8 * k), 12 * k, 0.8)
end

local function DropLoot(at, contents)
    Ent({ kind = "loot", model = "prop_loot_pod", pos = U.add(at, { U.rand(-8, 8), U.rand(-8, 8), U.rand(-8, 8) }), yaw = U.rand(0, 360),
          scale = 2.2, spin = 60, vel = { U.rand(-6, 6), U.rand(-6, 6), U.rand(-6, 6) }, contents = contents, life = 90, name = "漂浮货舱" })
end

local Destroy
local function Damage(e, amount, at)
    if e.kind == "pirate" or e.kind == "player" then
        e.shieldCd = T.shieldDelay
        local s = math.min(e.shield, amount)
        e.shield = e.shield - s
        e.hull = e.hull - (amount - s)
        if s > 0 then Spark(at, "fx_shield", 3, 10, 0.3) end
        if e.kind == "pirate" then e.hurt = true end
        if e.kind == "player" then
            S.data.hullDmg = math.max(0, S.Stats().hullMax - e.hull)
            Space.events.onHit()
        end
        if e.hull <= 0 then Destroy(e) end
    elseif e.kind == "ore" or e.kind == "crystal" then
        e.hp = e.hp - amount
        if e.hp <= 0 then Destroy(e) end
    end
end

Destroy = function(e)
    Explode(e.pos, e.radius)
    RemoveEnt(e)
    if e.kind == "player" then Space.events.onDead(); return end
    if e.kind == "pirate" then
        S.data.credits = S.data.credits + e.def.bounty
        S.data.kills = S.data.kills + 1
        Toast("击落 " .. e.name .. "，赏金 " .. U.fmt(e.def.bounty))
        local m = S.data.active
        if m and m.kind == "bounty" and m.system == W.sys.id then
            m.progress = (m.progress or 0) + 1
            if m.progress >= m.count then
                local st = S.StationById(m.giver)
                Toast("任务目标完成：回到 " .. st.name .. " 交付")
            end
        end
        if e.boss then
            if m and m.kind == "boss" then m.progress = 1; Toast("赤髑号已被击沉！回到星港交付任务") end
            DropLoot(e.pos, { shards = 3 }); DropLoot(e.pos, { credits = 2000 })
        end
        local roll = math.random()
        if roll < 0.25 then DropLoot(e.pos, { shards = 1 })
        elseif roll < 0.7 then DropLoot(e.pos, { good = G.goods[math.random(#G.goods)].id, n = math.random(1, 3) })
        else DropLoot(e.pos, { credits = math.random(100, 400) }) end
    elseif e.kind == "ore" then
        for _ = 1, math.random(2, 3) do DropLoot(e.pos, { good = "ore", n = math.floor(2 * S.Stats().mining + 0.5) }) end
    elseif e.kind == "crystal" then
        if math.random() < 0.45 then DropLoot(e.pos, { shards = 1 }) end
        DropLoot(e.pos, { good = "ore", n = 2 })
    end
end

local PLAYER_HITS = { pirate = true, ore = true, crystal = true, rock = true, station = true, base = true }

local function UpdateProjectiles(dt)
    local keep = {}
    for _, pr in ipairs(W.projs) do
        pr.life = pr.life - dt
        if pr.missile then
            if pr.target and Alive(pr.target) then SteerToward(pr, U.sub(pr.target.pos, pr.pos), G.missile.turn, dt) end
            pr.vel = U.mul(U.fwdOf(pr.yaw, pr.pitch), pr.speed)
            if math.random() < 0.6 then Spark(pr.pos, "fx_spark", 1, 6, 0.4) end
        end
        local a, b = pr.pos, U.add(pr.pos, U.mul(pr.vel, dt))
        local hit = nil
        for _, e in ipairs(W.ents) do
            if pr.owner == "player" and PLAYER_HITS[e.kind] then
                if U.segHit(a, b, e.pos, e.radius * (e.kind == "pirate" and 1.1 or 0.85)) then hit = e; break end
            elseif pr.owner == "enemy" and (e.kind == "player" or e.kind == "rock") then
                if U.segHit(a, b, e.pos, e.radius * (e.kind == "player" and 1.2 or 0.85)) then hit = e; break end
            end
        end
        pr.pos = b
        if hit then
            Damage(hit, pr.dmg, pr.pos)
            Spark(pr.pos, pr.owner == "player" and "fx_spark_teal" or "fx_spark", pr.missile and 18 or 4, pr.missile and 30 or 15, 0.5)
            Release(pr.model, pr.node)
        elseif pr.life > 0 then
            keep[#keep + 1] = pr
        else
            Release(pr.model, pr.node)
        end
    end
    W.projs = keep
end

local function UpdateLoot(dt)
    local p, st = W.player, S.Stats()
    for i = #W.ents, 1, -1 do
        local e = W.ents[i]
        if e and e.kind == "loot" then
            e.life = e.life - dt
            local d = U.dist(e.pos, p.pos)
            if d < T.magnetRange then e.vel = U.mul(U.norm(U.sub(p.pos, e.pos)), 40 + (T.magnetRange - d)) end
            e.pos = U.add(e.pos, U.mul(e.vel, dt))
            e.vel = U.mul(e.vel, 0.98)
            local taken = false
            if d < T.pickupRange + p.radius then
                local c, msg = e.contents, nil
                if c.shards then
                    S.data.shards = S.data.shards + c.shards; msg = "获得陨石碎片 x" .. c.shards
                elseif c.credits then
                    S.data.credits = S.data.credits + c.credits; msg = "获得信用点 " .. U.fmt(c.credits)
                else
                    local room = st.cargoCap - S.CargoUsed()
                    if room <= 0 then
                        if not e.warned then Toast("货舱已满"); e.warned = true end
                    else
                        local n = math.min(room, c.n)
                        S.AddCargo(c.good, n)
                        msg = "获得" .. U.byId(G.goods, c.good).name .. " x" .. n
                    end
                end
                if msg then Toast(msg); RemoveEnt(e); taken = true end
            end
            if not taken and e.life <= 0 then RemoveEnt(e) end
        end
    end
end

local function UpdateCollisions(dt)
    local p = W.player
    for _, e in ipairs(W.ents) do
        if e ~= p and e.kind ~= "loot" and e.kind ~= "decor" and e.kind ~= "gate" then
            local d = U.dist(e.pos, p.pos)
            local r = e.radius * (e.kind == "pirate" and 1 or 0.8) + p.radius * 0.7
            if d < r and d > 0.001 then
                p.pos = U.add(e.pos, U.mul(U.norm(U.sub(p.pos, e.pos)), r))
                if p.speed > 25 and p.bumpCd <= 0 then Damage(p, p.speed * 0.25, p.pos); p.bumpCd = 0.8 end
                p.speed = p.speed * 0.4
            end
        end
    end
    if p.bumpCd > 0 then p.bumpCd = p.bumpCd - dt end
end

local function UpdateParticles(dt)
    local keep = {}
    for _, pa in ipairs(W.parts) do
        pa.life = pa.life - dt
        pa.pos = U.add(pa.pos, U.mul(pa.vel, dt))
        pa.vel = U.mul(pa.vel, 0.97)
        if pa.life > 0 then keep[#keep + 1] = pa else Release(pa.model, pa.node) end
    end
    W.parts = keep
end

local function UpdateSpawns(dt)
    local n = 0
    for _, e in ipairs(W.ents) do if e.kind == "pirate" and not e.boss then n = n + 1 end end
    if n < W.sys.pirates.max then
        W.spawnTimer = W.spawnTimer - dt
        if W.spawnTimer <= 0 then Space.SpawnPirate(nil); W.spawnTimer = T.respawnDelay * U.rand(0.6, 1.4) end
    end
end

function Space.Interactable()
    local p, best = W.player, nil
    for _, e in ipairs(W.ents) do
        if e.kind == "station" and U.dist(e.pos, p.pos) < e.radius + T.dockRange then best = e end
        if e.kind == "gate" and U.dist(e.pos, p.pos) < T.gateRange + e.radius * 0.4 then best = e end
    end
    return best
end

-- ---------------------------------------------------------------- 相机与节点同步
local function UpdateCamera(dt)
    local p, c = W.player, Space.cam
    local f = U.fwdOf(p.yaw, p.pitch)
    local D, H = p.radius * 2.4 + 5, p.radius * 0.75 + 1.2
    local desired = U.add(U.add(p.pos, U.mul(f, -D)), { 0, H, 0 })
    if c.pos then c.pos = U.add(c.pos, U.mul(U.sub(desired, c.pos), 1 - math.exp(-dt * 7))) else c.pos = desired end
    c.target = U.add(p.pos, U.mul(f, 24))
    c.fov = U.lerp(c.fov, p.boosting and 72 or 62, 1 - math.exp(-dt * 3))
end

function Space.ApplyCamera(eye, target, fov)
    camNode_.position = U.V3(eye)
    camNode_:LookAt(U.V3(target))
    camera_.fov = Layout.FitFov(fov, Layout.Compute().aspect)
    if starsNode_ then starsNode_.position = U.V3(eye) end
end

local function SyncNodes()
    local t = W.t
    for _, e in ipairs(W.ents) do
        if e.node then
            e.node.position = U.V3(e.pos)
            local yaw = e.yaw
            if e.kind ~= "pirate" and e.kind ~= "player" then yaw = yaw + (e.spin or 0) * t end
            e.node.rotation = Quaternion(e.pitch or 0, yaw, e.roll or 0)
            e.node:SetScale(e.scale)
        end
    end
    for _, pr in ipairs(W.projs) do
        local y, pt
        if pr.missile then y, pt = pr.yaw, pr.pitch else y, pt = U.anglesTo(pr.vel) end
        pr.node.position = U.V3(pr.pos)
        pr.node.rotation = Quaternion(pt, y, 0)
        pr.node:SetScale(pr.missile and 3 or 3.2)
    end
    for _, pa in ipairs(W.parts) do
        local s = pa.size * U.clamp(pa.life / pa.max, 0.15, 1) * 2
        pa.node.position = U.V3(pa.pos)
        pa.node.rotation = Quaternion(pa.life * 140, pa.life * 200, 0)
        pa.node:SetScale(s)
    end
end

-- 每帧：mode = "flight" 时运行模拟；其它模式只推进时间与粒子
function Space.Update(dt, simulate)
    if not W.sys then return end
    if simulate then
        W.t = W.t + dt
        UpdatePlayer(dt); UpdatePirates(dt); UpdateProjectiles(dt); UpdateCollisions(dt)
        UpdateLoot(dt); UpdateParticles(dt); UpdateSpawns(dt)
        if W.player and Alive(W.player) then UpdateCamera(dt) end
    else
        W.t = W.t + dt * 0.5
        UpdateParticles(dt)
    end
    SyncNodes()
end

function Space.FollowCamera()
    local c = Space.cam
    if c.pos then Space.ApplyCamera(c.pos, c.target, c.fov) end
end

-- 星港 / 标题背景：绕星港缓慢环绕
function Space.OrbitStationCamera()
    local st = Space.ByKind("station")
    if not st then return end
    local a, R = W.t * 4, st.radius * 3.2
    Space.ApplyCamera(U.add(st.pos, { math.sin(a * U.DEG) * R, st.radius * 0.6, math.cos(a * U.DEG) * R }), st.pos, 55)
end

return Space
