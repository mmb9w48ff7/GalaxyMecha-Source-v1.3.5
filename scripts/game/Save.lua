-- Save.lua
-- 玩家存档与派生属性（与 HTML 版 game.js 的 save / stats 一致）。
-- 存档写入引擎提供的用户隔离目录：meteor_galaxy_save.json
local G = require("voxeldata.GameData")
local U = require("game.Util")
local cjson = require("cjson")

local S = { data = nil }
local SAVE_FILE = "meteor_galaxy_save.json"

function S.New()
    local st = G.start
    local crew = {}
    for i, c in ipairs(st.crew) do crew[i] = c end
    return { system = st.system, credits = st.credits, shards = st.shards, ship = st.ship, crew = crew, cargo = {},
             laser = st.laser, shieldGen = st.shieldGen, missiles = U.byId(G.ships, st.ship).missiles, hullDmg = 0,
             story = 0, active = nil, dockedAt = "ashfall", kills = 0, played = 0 }
end

function S.Exists()
    return fileSystem:FileExists(SAVE_FILE)
end

function S.Load()
    if not S.Exists() then return nil end
    local file = File(SAVE_FILE, FILE_READ)
    if not file:IsOpen() then return nil end
    local ok, data = pcall(cjson.decode, file:ReadString())
    file:Close()
    if not ok or type(data) ~= "table" then
        print("[Save] 存档解析失败")
        return nil
    end
    data.cargo = data.cargo or {}
    if data.active == cjson.null then data.active = nil end
    return data
end

function S.Write()
    if not S.data then return end
    local file = File(SAVE_FILE, FILE_WRITE)
    if file:IsOpen() then
        local d = S.data
        -- cjson 会把空表编码成 {}，货舱为空时保持对象格式即可
        file:WriteString(cjson.encode(d))
        file:Close()
    end
end

function S.CrewFx()
    local fx = { laserDmg = 0, hull = 0, shieldRegen = 0, freeRepair = 0, mining = 0, cargo = 0, radar = 0, jumpShield = 0, missiles = 0, missileDmg = 0 }
    for _, id in ipairs(S.data.crew) do
        local c = U.byId(G.crew, id)
        if c then for k, v in pairs(c.fx) do fx[k] = fx[k] + v end end
    end
    return fx
end

function S.Stats()
    local d = S.data
    local sh, fx = U.byId(G.ships, d.ship), S.CrewFx()
    local la, sg = U.byId(G.lasers, d.laser), U.byId(G.shields, d.shieldGen)
    local T = G.tuning
    return { ship = sh, hullMax = math.floor(sh.hull * (1 + fx.hull) + 0.5), shieldMax = math.floor(sh.shield * sg.mult + 0.5),
             regen = sg.regen * (1 + fx.shieldRegen), laserDmg = la.dmg * (1 + fx.laserDmg), rof = la.rof, guns = sh.guns,
             cargoCap = sh.cargo + fx.cargo, missileCap = sh.missiles + fx.missiles, missileDmg = G.missile.dmg * (1 + fx.missileDmg),
             radar = T.radarRange * (1 + fx.radar), mining = 1 + fx.mining, speed = sh.speed, turn = sh.turn, fx = fx }
end

function S.CargoUsed()
    local n = 0
    for _, v in pairs(S.data.cargo) do n = n + v end
    return n
end

function S.AddCargo(good, n)
    local c = S.data.cargo
    c[good] = (c[good] or 0) + n
    if c[good] <= 0 then c[good] = nil end
end

function S.SysById(id) return U.byId(G.systems, id) end

function S.StationById(id)
    for _, sys in ipairs(G.systems) do
        local st = U.byId(sys.stations, id)
        if st then return st, sys end
    end
    return nil
end

function S.PriceOf(stId, good, selling)
    local st = S.StationById(stId)
    local g = U.byId(G.goods, good)
    local p = g.base * st.prices[good]
    return math.max(1, math.floor((selling and p * 0.9 or p) + 0.5))
end

return S
