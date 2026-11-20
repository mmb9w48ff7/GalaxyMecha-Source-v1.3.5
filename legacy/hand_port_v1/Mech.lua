-- Mech.lua：机甲分件节点树 + 姿态动画（移植自网页版 poseStep / poseBuild）
-- 所有部件与整机共用同一原点（机甲脚底中心）；每个关节是一个 pivot 节点，部件几何偏移 -pivot，因此旋转 pivot 即绕关节转动。
local VB = require("game.VoxelBuilder")
local Rigs = require("voxeldata.Rigs")
local U = require("cosmic.Util")
local Mech = {}
local SCALE = 1.35
local FX = {   -- 手臂角色与枪口：与网页版 MECHFX 一致
    mech_azure = { fire = { "R" }, aim = { R = "gun", L = "guard" }, glow = "#9DF7EC", kick = 0.5 },
    mech_blaze = { fire = { "L" }, aim = { L = "gun", R = "axe" }, glow = "#FF8A3A", kick = 1.0 },
    mech_halo = { fire = { "R" }, aim = { R = "staff", L = "free" }, glow = "#C9B8FF", kick = 0.3 },
    mech_forge = { fire = { "R", "L" }, aim = { L = "gun", R = "gun" }, glow = "#FFB347", kick = 0.5 },
    mech_frost = { fire = { "P" }, aim = { R = "gun", L = "free" }, glow = "#9DD8FF", kick = 0.8 },
    mech_starfall = { fire = { "R" }, aim = { R = "spear", L = "free" }, glow = "#E0A0FF", kick = 0.5 },
}
Mech.FX = FX
local function V(t) return Vector3(t[1], t[2], t[3]) end
local function sub(a, b) return { a[1] - b[1], a[2] - b[2], a[3] - b[3] } end
local function neg(a) return Vector3(-a[1], -a[2], -a[3]) end
-- 在 parent 下创建关节 pivot（位置 = 关节 - 父关节），并在其下放置几何（偏移 -关节）
local function joint(parent, name, at, parentAt, partId)
    local p = parent:CreateChild(name); p.position = V(sub(at, parentAt))
    local geo = nil
    if partId then geo = VB.Build(p, partId, name .. "_geo"); geo.position = neg(at) end
    return p, geo
end
local function marker(parent, name, at, parentAt)
    local n = parent:CreateChild(name); n.position = V(sub(at, parentAt)); return n
end
function Mech.Build(parent, id)
    local rig = Rigs[id]
    local m = { id = id, rig = rig, fx = FX[id] or FX.mech_azure, muz = { L = {}, R = {}, P = {} }, rear = {}, vern = {}, sh = {}, el = {}, hip = {}, knee = {} }
    local root = parent:CreateChild("Mech_" .. id); root:SetScale(SCALE); m.root = root
    local origin = { 0, 0, 0 }
    m.torso = joint(root, "torso", rig.waist, origin); VB.Build(m.torso, id .. "__body", "body").position = neg(rig.waist)
    m.neck = joint(m.torso, "neck", rig.neck, rig.waist, id .. "__head")
    for _, S in ipairs({ "L", "R" }) do
        m.sh[S] = joint(m.torso, "sh" .. S, rig["shoulder" .. S], rig.waist, id .. "__uarm" .. S)
        m.el[S] = joint(m.sh[S], "el" .. S, rig["elbow" .. S], rig["shoulder" .. S], id .. "__arm" .. S)
        m.hip[S] = joint(root, "hip" .. S, rig["hip" .. S], origin, id .. "__thigh" .. S)
        m.knee[S] = joint(m.hip[S], "knee" .. S, rig["knee" .. S], rig["hip" .. S], id .. "__shin" .. S)
        if rig["muzzle" .. S] then for i, q in ipairs(rig["muzzle" .. S]) do m.muz[S][i] = marker(m.el[S], "muz" .. S .. i, q, rig["elbow" .. S]) end end
        m.rear[#m.rear + 1] = marker(m.torso, "rear" .. S, rig["rear" .. S], rig.waist)
        m.vern[#m.vern + 1] = marker(m.torso, "vern" .. S, rig["vern" .. S], rig.waist)
    end
    if rig.muzzleP then for i, q in ipairs(rig.muzzleP) do m.muz.P[i] = marker(m.torso, "muzP" .. i, q, rig.waist) end end
    m.shoulderPts = { marker(m.torso, "shpL", { rig.shoulderL[1], rig.shoulderL[2] + 0.6, rig.shoulderL[3] }, rig.waist), marker(m.torso, "shpR", { rig.shoulderR[1], rig.shoulderR[2] + 0.6, rig.shoulderR[3] }, rig.waist) }
    m.back = marker(m.torso, "back", { (rig.rearL[1] + rig.rearR[1]) / 2, rig.rearL[2], rig.rearL[3] - 0.1 }, rig.waist)
    m.crane = rig.craneL and marker(m.torso, "crane", rig.craneL, rig.waist) or m.shoulderPts[1]
    m.axe = rig.axeEdge and marker(m.el.R, "axe", rig.axeEdge, rig.elbowR) or nil
    -- 姿态状态
    m.p = { lean = 0, bank = 0, thrR = 0.25, twist = 0, tP = 0, hY = 0, hP = 0, aimK = 0, hit = 0, recB = 0, rec = { L = 0, R = 0 }, cast = nil,
            arm = { L = { p = 0, e = 0, y = 0, r = 0 }, R = { p = 0, e = 0, y = 0, r = 0 } }, th = { L = { p = 0, r = 0 }, R = { p = 0, r = 0 } }, kn = { L = 0, R = 0 }, af = 0, vf = 0 }
    return m
end
function Mech.Muzzle(m, side, i)
    local n = m.muz[side] and m.muz[side][(i or 0) % math.max(1, #m.muz[side]) + 1]
    if not n then return nil end
    local w = n.worldPosition; return w.x, w.y, w.z
end
function Mech.Point(n) local w = n.worldPosition; return w.x, w.y, w.z end
function Mech.Kick(m, side, amt, body)
    if side then m.p.rec[side] = math.max(m.p.rec[side], amt) end
    m.p.recB = math.min(2, m.p.recB + (body or 0))
end
function Mech.SetCast(m, kind, dur) m.p.cast = { kind = kind, t = 0, dur = dur } end
local function ease(c, g, k, dt) return c + (g - c) * (1 - math.exp(-k * dt)) end
-- s：{ fk 前进速度占比, sk 横移占比, uk 升降占比, af 加速度, dashing, tg 是否有目标, yawL 目标相对机头偏航, dwn 目标俯角, t 时间 }
function Mech.Update(m, s, dt)
    local P, fxm, t, c = m.p, m.fx, s.t, m.p.cast
    local fk, sk, uk = U.clamp(s.fk, -0.6, 1.5), U.clamp(s.sk, -1, 1), U.clamp(s.uk, -1, 1)
    local legK = U.clamp(fk, 0, 1.2)
    local dashing = s.dashing and true or false
    P.aimK = ease(P.aimK, s.tg and (math.abs(s.yawL) > 95 and 0 or 1) or 0, 9, dt)
    P.af = ease(P.af, U.clamp(s.af or 0, -1.5, 1.5), 12, dt)
    local leanG = fk * 17 + (dashing and 20 or 0) + U.clamp(P.af, 0, 1.5) * 5
    P.lean = ease(P.lean, U.clamp(leanG, -10, 40), 7, dt)
    P.bank = ease(P.bank, -sk * 9, 6, dt)
    P.thrR = ease(P.thrR, 0.2 + 0.7 * U.clamp(fk, 0, 1.2) + 0.5 * U.clamp(P.af, 0, 1.5) + (dashing and 1.6 or 0), 12, dt)
    -- 腿
    local ph = { math.sin(t * 2.1), math.sin(t * 2.1 + 1.6) }
    local down = math.max(0, -uk)
    for i, S in ipairs({ "L", "R" }) do
        local tp = 6 + 18 * legK + (dashing and 16 or 0) + ph[i] * (3 + 4 * legK) - down * 10
        local kn = 10 + 24 * legK + (dashing and 4 or 0) + 14 * math.max(0, uk) + ph[3 - i] * (3 + 5 * legK) - down * 10
        local rl = (S == "L" and 3 or -3) - sk * 14
        P.th[S].p = ease(P.th[S].p, tp, 9, dt); P.th[S].r = ease(P.th[S].r, rl, 9, dt); P.kn[S] = ease(P.kn[S], math.max(2, kn), 9, dt)
    end
    -- 躯干 / 头
    local cw = c and U.clamp(math.sin(U.clamp(c.t / c.dur, 0, 1) * math.pi) * 1.6, 0, 1) or 0
    local ck = c and U.clamp(c.t / c.dur, 0, 1) or 0
    local twG = s.tg and U.clamp(s.yawL * 0.5, -26, 26) * P.aimK or 0
    local tPG = -P.recB * 4 + (s.tg and U.clamp(s.dwn * 0.12, -6, 8) * P.aimK or 0) + math.sin(t * 1.7) * 0.8
    if c then
        if c.kind == "slash" then twG = ck < 0.25 and -30 * (ck / 0.25) or ck < 0.6 and U.lerp(-30, 32, (ck - 0.25) / 0.35) or U.lerp(32, 0, (ck - 0.6) / 0.4)
        elseif c.kind == "salvo" or c.kind == "meteor" then tPG = tPG - 10 * cw
        elseif c.kind == "deploy" then tPG = tPG + 8 * cw
        elseif c.kind == "beam" then tPG = tPG - 5 * cw end
    end
    P.twist = ease(P.twist, twG, 9, dt); P.tP = ease(P.tP, tPG, 12, dt)
    P.hY = ease(P.hY, s.tg and U.clamp(s.yawL - P.twist, -34, 34) * 0.75 * P.aimK or 0, 10, dt)
    P.hP = ease(P.hP, (s.tg and U.clamp(s.dwn - P.tP, -20, 24) * 0.5 * P.aimK or 0) - P.hit * 16, 12, dt)
    -- 手臂（大臂 + 小臂）
    local ay, dd = U.clamp(s.yawL - P.twist, -22, 22), U.clamp(s.dwn - P.tP, -42, 42)
    for _, S in ipairs({ "L", "R" }) do
        local role = fxm.aim[S] or "free"; local side = S == "L" and 1 or -1
        local sway = math.sin(t * 1.8 + (S == "L" and 0 or 2)) * 3
        local g = { p = 0, y = 0, r = side * 6 }
        local trail = 0
        if role == "gun" then g.p = U.lerp(-12 + sway + 14 * legK, dd, P.aimK); g.y = P.aimK * ay * 0.95; g.r = side * (4 + 6 * (1 - P.aimK))
        elseif role == "staff" or role == "spear" then g.p = U.lerp(4 + sway * 0.5 + 10 * legK, dd + 90, P.aimK); g.y = P.aimK * ay
        elseif role == "axe" then g.p = -4 + sway + 26 * legK; g.r = side * 8
        elseif role == "guard" then g.p = U.lerp(-22 + sway + 18 * legK, -42, P.aimK); g.y = P.aimK * 8
        else g.p = -6 + sway + 30 * legK; g.r = side * (7 + 6 * legK) end
        if dashing then g.p = (role == "staff" or role == "spear") and 40 or 60; g.y = 0 end
        if c then
            local cp = nil
            if c.kind == "slash" then
                if S == "R" then cp = ck < 0.25 and U.lerp(g.p, -70, ck / 0.25) or ck < 0.6 and U.lerp(-70, 120, 1 - (1 - (ck - 0.25) / 0.35) ^ 3) or U.lerp(120, g.p, (ck - 0.6) / 0.4); cw = 1 else cp = 40 end
            elseif c.kind == "heal" then cp = S == "R" and (role == "staff" and 50 or -50) or -75
            elseif c.kind == "deploy" then cp = -75
            elseif c.kind == "salvo" then cp = -130
            elseif c.kind == "meteor" then cp = S == "R" and 20 or -140
            elseif c.kind == "beam" and S == "R" and (role == "gun" or role == "staff" or role == "spear") then cp = role == "gun" and dd or dd + 90 end
            if cp then g.p = U.lerp(g.p, cp, cw) end
        end
        g.p = g.p - P.hit * 30
        local tot, aimW = g.p, P.aimK * (1 - cw) * (dashing and 0 or 1)
        local pu
        if role == "gun" then pu = U.lerp(tot * 0.6, U.clamp(-26 + 0.5 * dd, -70, 10), aimW) elseif role == "staff" or role == "spear" then pu = tot * 0.35 else pu = tot * 0.6 end
        local pe = U.clamp(tot - pu + ((role == "gun" and aimW > 0.3) and 8 or 12), -20, 125)
        local a = P.arm[S]; a.p = ease(a.p, pu, 13, dt); a.e = ease(a.e, pe, 15, dt); a.y = ease(a.y, g.y, 12, dt); a.r = ease(a.r, g.r, 10, dt)
    end
    if c then c.t = c.t + dt; if c.t >= c.dur then P.cast = nil end end
    P.hit = math.max(0, P.hit - dt * 4)
    P.rec.L = math.max(0, P.rec.L - dt * 9); P.rec.R = math.max(0, P.rec.R - dt * 9); P.recB = math.max(0, P.recB - dt * 7)
    -- 写回节点旋转
    m.torso.rotation = Quaternion(P.tP, P.twist, 0)
    m.neck.rotation = Quaternion(P.hP, P.hY, 0)
    for _, S in ipairs({ "L", "R" }) do
        local a, role, rec = P.arm[S], fxm.aim[S], P.rec[S]
        m.sh[S].rotation = Quaternion(a.p + rec * 3, a.y, a.r)
        local pk = role == "gun" and -10 * rec or 0
        m.el[S].rotation = Quaternion(a.e + pk, 0, 0)
        m.hip[S].rotation = Quaternion(P.th[S].p, 0, P.th[S].r)
        m.knee[S].rotation = Quaternion(P.kn[S], 0, 0)
    end
end
return Mech
