package.path = "scripts/?.lua;scripts/?/init.lua;" .. package.path
local JS = require("jsrt.JS")
local store = {}
local HOST = {
    window = {}, document = {}, localStorage = { getItem = function(_, k) return store[k] end, setItem = function(_, k, v) store[k] = v end, removeItem = function(_, k) store[k] = nil end },
}
local M = require("jsrt.CosmicData")(HOST)
local C = M.C
local res = {}
local cards = JS.newarr(0)
C.MOD_FORMS:forEach(function(_, f) C.ELEMENTS:forEach(function(_, e)
    for t = 0, 3 do for v = 0, C.VARIANTS[t] - 1 do
        local m = C:makeModule(t, f.k, e.k, v)
        cards:push(JS.newarr(0):concat(m.id, m.name, (m.tags or JS.newarr(0)):join("|"), m.tier, m.v))
    end end
end) end)
res.cards = cards
C:load()
local dc = C:dailyChallenge(); res.dc = { day = dc.day, chapter = dc.chapter, mods = dc.mods, danger = dc.danger }
res.costs = JS.newarr(0); for _, n in ipairs({ 0, 1, 5, 20, 60, 100 }) do res.costs:push(JS.newarr(0):concat(C:CHIP_COST(n), C:MOD_COST(n))) end
res.lv = JS.newarr(0); for _, l in ipairs({ 1, 2, 3, 5 }) do res.lv:push(C:modLvMult({ lvl = l })) end
C.save.chips = JS.G.JSON:parse('[{"id":"a","tier":3,"lvl":3,"aff":[{"k":"atk","v":8},{"k":"regen","v":0.5},{"k":"crit","v":4}],"trait":"revive"},{"id":"b","tier":1,"lvl":1,"aff":[{"k":"hp","v":7},{"k":"luck","v":1.2}]}]')
C.save.chipEq = JS.G.JSON:parse('["a","b"]'); C.save.pilot = "char_chiyan"
local cs = C:chipStats(); local keys = {}
for k in pairs(cs) do if k ~= "traits" then keys[#keys + 1] = k end end; table.sort(keys)
res.chip = JS.newarr(0); for _, k in ipairs(keys) do res.chip:push(k .. "=" .. JS.S(math.floor(cs[k] * 1e6 + 0.5) / 1e6)) end
local tk = {}; for k in pairs(cs.traits or {}) do tk[#tk + 1] = k end; table.sort(tk); res.traits = JS.newarr(0); for _, k in ipairs(tk) do res.traits:push(k) end
local f = io.open("/tmp/lua_data.json", "w"); f:write(JS.G.JSON:stringify(res)); f:close()
print("Lua 版：卡牌", res.cards.length)
