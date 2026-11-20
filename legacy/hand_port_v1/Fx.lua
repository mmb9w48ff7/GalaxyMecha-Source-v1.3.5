-- Fx.lua：特效粒子（体素小方块）。每种颜色一个原型，Clone 复用，限制总数。
local VB = require("game.VoxelBuilder")
local U = require("cosmic.Util")
local Fx = { list = {}, free = {}, root = nil, protos = nil, max = 320, scale = 1 }
local protoByKey_ = {}
local function cubeProto(color)
    local key = string.format("%.2f_%.2f_%.2f", color[1], color[2], color[3])
    local p = protoByKey_[key]
    if p then return p end
    p = Fx.protos:CreateChild("cube_" .. key)
    local g = p:CreateComponent("CustomGeometry")
    g:SetNumGeometries(1); g:BeginGeometry(0, TRIANGLE_LIST)
    local h = 0.5
    local N = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }
    local CORN = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 0 }, { 1, 1 }, { 0, 1 } }
    for f = 0, 5 do
        local axis, sg = f // 2, (f % 2 == 0) and 1 or -1
        for c = 1, 6 do
            local a, b, e = sg * h, CORN[c][1] == 1 and h or -h, CORN[c][2] == 1 and h or -h
            local x, y, z
            if axis == 0 then x, y, z = a, b, e elseif axis == 1 then x, y, z = e, a, b else x, y, z = b, e, a end
            g:DefineVertex(Vector3(x, y, z)); g:DefineNormal(Vector3(N[f + 1][1], N[f + 1][2], N[f + 1][3]))
        end
    end
    g:Commit(); g:SetMaterial(0, VB.GetMaterial(color, 0, 1, 0, true)); g.castShadows = false
    p:SetDeepEnabled(false); protoByKey_[key] = p
    return p
end
-- 返回一个由调用方管理生命周期的方块节点（弹体、导弹、环绕刃）
function Fx.Node(color, sx, sy, sz)
    local n = cubeProto(color):Clone(); n:SetParent(Fx.root); n:SetDeepEnabled(true); n:SetScale(Vector3(sx, sy or sx, sz or sx)); return n
end
function Fx.Init(scene)
    Fx.root = scene:CreateChild("FxRoot"); Fx.protos = scene:CreateChild("FxProtos")
end
function Fx.Reset()
    for _, p in ipairs(Fx.list) do p.node:Remove() end
    Fx.list = {}
end
-- 一个粒子：pos 世界坐标，vel 速度，life 寿命，size 初始边长（米），shrink 是否随寿命缩小
function Fx.Spawn(x, y, z, color, size, life, vx, vy, vz)
    if #Fx.list >= Fx.max then return nil end
    local n = cubeProto(color):Clone(); n:SetParent(Fx.root); n:SetDeepEnabled(true)
    n.position = Vector3(x, y, z); n:SetScale(size)
    local p = { node = n, x = x, y = y, z = z, vx = vx or 0, vy = vy or 0, vz = vz or 0, life = life, max = life, size = size }
    Fx.list[#Fx.list + 1] = p
    return p
end
function Fx.Burst(x, y, z, color, n, speed, life, size, up)
    for _ = 1, n do
        local dx, dy, dz = U.norm(U.rand(-1, 1), U.rand(-1, 1), U.rand(-1, 1)); local s = U.rand(0.4, 1) * speed
        Fx.Spawn(x, y, z, color, size * U.rand(0.7, 1.2), life * U.rand(0.7, 1.2), dx * s, dy * s + (up or 0), dz * s)
    end
end
function Fx.Ring(x, y, z, r, color, n, size, life)
    for i = 1, n do
        local a = i / n * math.pi * 2
        Fx.Spawn(x + math.cos(a) * r, y, z + math.sin(a) * r, color, size, life, 0, 0, 0)
    end
end
function Fx.Line(x0, y0, z0, x1, y1, z1, color, size, life, step)
    local dx, dy, dz = x1 - x0, y1 - y0, z1 - z0; local len = U.len3(dx, dy, dz); local n = math.max(1, math.floor(len / (step or 1.5)))
    for i = 0, n do local t = i / n; Fx.Spawn(x0 + dx * t, y0 + dy * t, z0 + dz * t, color, size, life, 0, 0, 0) end
end
function Fx.Update(dt)
    local L = Fx.list
    for i = #L, 1, -1 do
        local p = L[i]; p.life = p.life - dt
        if p.life <= 0 then p.node:Remove(); L[i] = L[#L]; L[#L] = nil
        else
            p.x, p.y, p.z = p.x + p.vx * dt, p.y + p.vy * dt, p.z + p.vz * dt
            p.node.position = Vector3(p.x, p.y, p.z); p.node:SetScale(math.max(0.02, p.size * (p.life / p.max)))
        end
    end
end
return Fx
