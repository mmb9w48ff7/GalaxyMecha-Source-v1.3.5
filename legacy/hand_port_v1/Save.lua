-- Save.lua：存档（JSON，写入引擎提供的项目 + 用户隔离目录）
local D = require("cosmic.Data")
local cjson = require("cjson")
local S = { data = nil }
local FILE = "cosmic_mecha_save.json"
local function newSave()
    return { version = 2, credits = 600, src = 30, mech = "mech_azure", mechs = { mech_azure = { lv = 1, star = 1 } }, pilot = "char_xingli", chars = { char_xingli = { star = 1 } },
        chapter = 1, cleared = {}, dangerMax = 1, danger = 1, endlessBest = 0, runs = 0, kills = 0, bossKills = 0, music = true, sound = true,
        modules = {}, modEq = {}, chips = {}, chipEq = {}, modBuys = 0, chipBuys = 0, ach = {}, dcBest = 0, dc = nil, login = { last = "", n = 0 },
        daily = { day = "", ads = 0, supply = 0, runs = 0, kills = 0, pulls = 0, claimed = {}, adUp = 0 }, tutorialDone = false }
end
function S.Load()
    local ok, data = false, nil
    if fileSystem and fileSystem:FileExists(FILE) then
        local f = File(FILE, FILE_READ)
        if f:IsOpen() then ok, data = pcall(cjson.decode, f:ReadString()); f:Close() end
    end
    if not ok or type(data) ~= "table" then data = newSave() end
    local base = newSave(); for k, v in pairs(base) do if data[k] == nil then data[k] = v end end
    for _, k in ipairs({ "daily", "login" }) do if type(data[k]) ~= "table" then data[k] = base[k] else for kk, vv in pairs(base[k]) do if data[k][kk] == nil then data[k][kk] = vv end end end end
    for _, k in ipairs({ "mechs", "chars", "cleared", "ach" }) do if type(data[k]) ~= "table" then data[k] = base[k] or {} end end
    if not data.mechs[data.mech] then data.mech = "mech_azure" end
    if not data.chars[data.pilot] then data.pilot = "char_xingli" end
    -- 老存档 / 新存档：没有卡牌时送两张起步卡牌并自动装备
    if #data.modules == 0 then
        local M = require("cosmic.Meta")
        local a, b = M.MakeCard(0, "homing", "light", 0), M.MakeCard(0, "nova", "ice", 0); data.modules = { a, b }; data.modEq = { a.id, b.id }
    end
    S.data = data; return data
end
function S.Write()
    if not S.data then return end
    local f = File(FILE, FILE_WRITE)
    if f:IsOpen() then f:WriteString(cjson.encode(S.data)); f:Close() end
end
function S.Mech(id) for _, m in ipairs(D.MECHS) do if m.id == id then return m end end end
function S.MechMul(id)                                  -- 机甲倍率：等级 x 星级 x 等阶倍率 x 驾驶员匹配
    local m, o = S.Mech(id), S.data.mechs[id]
    if not o then return 1 end
    return (1 + 0.08 * (o.lv - 1)) * (1 + 0.12 * (o.star - 1)) * D.GRADE[m.grade].mul
end
function S.Power()
    local m = S.Mech(S.data.mech); return math.floor((m.hp + m.fire * 18) * S.MechMul(m.id))
end
return S
