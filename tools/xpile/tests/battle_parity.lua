package.path = "scripts/?.lua;scripts/?/init.lua;" .. package.path
local cfgs = os.getenv("PCFG") or "{}"
local JS = require("jsrt.JS"); local Host = require("jsrt.Host")
local cfg = JS.G.JSON:parse(cfgs)
local mech, ch, N, seed, every = cfg.mech or "mech_azure", cfg.ch or 1, cfg.frames or 600, cfg.seed or 12345, cfg.every or 30
local s = seed
local rc = 0
local H = Host.Load({ rigs = require("voxeldata.Rigs"), store = {}, runModule = os.getenv("RUNMOD") })
local C, run, S = H.C, H.run, H.S
JS.rng = function() rc = rc + 1; s = (s * 1664525 + 1013904223) % 4294967296; return s / 4294967296 end   -- 装载完成后才开始使用确定性随机数（网页版同样是页面启动后才替换）
C.save.mech = mech; C.save.pilot = C:mech(mech).match; C.save.tutorialDone = true; C.save.modEq = JS.newarr(0); C.save.modules = JS.newarr(0)
local cards = { C:makeModule(0, "homing", "fire", 0), C:makeModule(0, "nova", "ice", 0), C:makeModule(1, "orbit", "poison", 0) }
for _, c in ipairs(cards) do C.save.modules:push(c); C.save.modEq:push(c.id) end
H.HOST.window.__tr = JS.newarr(0); C.save.chips = JS.newarr(0); C.save.chipEq = JS.newarr(0); C.save.settings.fx = "high"
-- 测试用：升级弹窗的“点击第一张卡牌”（网页版 debug.step 的做法）
local pendingPick = false
S.openLevelUp = function()
    S.paused = true; local R = S.R; R.pendingLevels = R.pendingLevels - 1; C:sfx("level"); R.rr = R.rr or { free = 1, ad = 0 }
    S.__ids = S:choices(); for i = 0, S.__ids.length - 1 do S:choiceInfo(S.__ids[i]) end; pendingPick = true
end
run:start(ch, cfg.opt and JS.G.JSON:parse(JS.G.JSON:stringify(cfg.opt)) or {})
if cfg.sector and cfg.sector > 0 then run.debug:sector(cfg.sector) end
local D = run.debug
local R = S.R
local S2n = JS.S
local rows = JS.newarr(0)
do local ev = R.event; rows:push(JS.newarr(0):concat(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'init ev=' .. (ev and (ev.type .. ':' .. ev.x:toFixed(2) .. ',' .. ev.z:toFixed(2)) or '-') .. ' gate=' .. R.gate.x:toFixed(2) .. ',' .. R.gate.z:toFixed(2) .. ' decor=' .. R.decor.length .. ' nodes=' .. R.nodes.length .. ' rc=' .. rc .. ' rnd=' .. JS.Math_random():toFixed(6))) end
for i = 0, N - 1 do
    D:move(math.sin(i / 25) * 0.8, 0.6 + 0.4 * math.cos(i / 40))
    if i == 40 or i == 200 or i == 400 then D:cast() end
    if i == 90 or i == 300 then D:dodge() end
    S:step(1 / 30)
    if S.paused and pendingPick then
        pendingPick = false; S:applyChoice(S.__ids[0]); S:afterChoice(); R = S.R; R.gems:forEach(function(_, g) if S:dd(g, S:P()) < 2025 then g.pull = true end end); S.paused = false
    end
    if (i + 1) % every == 0 then
        local function r3(x) return math.floor(x * 1000 + 0.5) / 1000 end
        rows:push(JS.newarr(0):concat(i + 1, r3(R.px), r3(R.py), r3(R.pz), r3(R.hull), R.kills, R.level, math.floor(R.xp * 100 + 0.5) / 100, R.enemies.length, R.shots.length, R.credits, r3(R.camYaw), (' N=' .. R.nums:map(function(_, n) return S2n(n.v) end):join(',') .. ' ') .. ('S' .. R.sched.length .. ' B' .. R.beams.length .. ' cd' .. R.activeCd:toFixed(2) .. ' ') .. R.enemies:map(function(_, e) return e.type .. ':' .. e.hp:toFixed(4) .. '@' .. e.x:toFixed(1) .. ',' .. e.z:toFixed(1) end):join(' ')))
    end
end
rows:push(JS.newarr(0):concat(-1, 0,0,0,0,0,0,0,0,0,0,0, JS.G.JSON:stringify(H.HOST.window.__tr or JS.newarr(0))))
local f = io.open("/tmp/lua_battle.json", "w"); f:write(JS.G.JSON:stringify(rows)); f:close()
print("Lua 版：记录", rows.length)
