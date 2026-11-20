-- mock_cosmic_test.lua：用桌面 Lua 5.4 模拟 UrhoX 接口，跑通“宇宙银河机甲”完整流程（机库 -> 6 台机甲战斗 -> 升级 -> 首领 -> 结算 -> 无尽）。
-- 只能发现脚本自身的错误（拼写、nil 访问、调用顺序、逻辑），不能替代 UrhoX 真机运行。
-- 用法（工程根目录）：lua tools/mock_cosmic_test.lua
package.path = "scripts/?.lua;scripts/?/init.lua;" .. package.path
math.randomseed(11)
local calls = { vertices = 0, clones = 0, nvg = 0, nodes = 0, removed = 0 }
local function obj(t) return setmetatable(t or {}, { __index = function(_, k) return function() end end }) end
-- 数学
local V3 = {}; V3.__index = V3
function Vector3(x, y, z) assert(x == x and (y or 0) == (y or 0) and (z or 0) == (z or 0), "Vector3 含 NaN"); return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, V3) end
function V3:Normalized() local l = math.sqrt(self.x ^ 2 + self.y ^ 2 + self.z ^ 2); return Vector3(self.x / l, self.y / l, self.z / l) end
function Vector2(x, y) return { x = x, y = y } end
function Color(r, g, b, a) assert(type(r) == "number" and type(g) == "number" and type(b) == "number"); return { r, g, b, a } end
function Quaternion(x, y, z) assert(x == x and y == y and z == z, "Quaternion 含 NaN"); return { x = x, y = y, z = z } end
function BoundingBox(a, b) return { a, b } end
function Variant(v) assert(v ~= nil); return { v = v } end
CULL_NONE, TRIANGLE_LIST, LIGHT_DIRECTIONAL, MOUSEB_LEFT, SOUND_EFFECT, SOUND_MUSIC, REMOVE_COMPONENT, FILE_READ, FILE_WRITE = 0, 0, 0, 1, 0, 1, 0, 0, 1
for _, k in ipairs({ "A", "D", "W", "S", "E", "LEFT", "RIGHT", "UP", "DOWN", "SPACE", "SHIFT" }) do _G["KEY_" .. k] = "KEY_" .. k end
NVG_ALIGN_LEFT, NVG_ALIGN_CENTER, NVG_ALIGN_RIGHT, NVG_ALIGN_TOP, NVG_ALIGN_MIDDLE = 1, 2, 4, 8, 16
-- 节点
local Node
Node = function(name, parent)
    calls.nodes = calls.nodes + 1
    local n = { name = name, children = {}, parent = parent, enabled = true, position = Vector3(0, 0, 0), rotation = Quaternion(0, 0, 0), scale = Vector3(1, 1, 1) }
    setmetatable(n, { __index = function(t, k)
        if k == "worldPosition" then local x, y, z = 0, 0, 0; local c = t; while c do x, y, z = x + c.position.x, y + c.position.y, z + c.position.z; c = rawget(c, "parent") end; return Vector3(x, y, z) end
        return function() end end })
    n.CreateChild = function(self, nm) local ch = Node(nm, self); self.children[#self.children + 1] = ch; return ch end
    n.CreateComponent = function(self, kind)
        local c = obj({ kind = kind })
        if kind == "CustomGeometry" then c.SetNumGeometries = function(s, k) s.n = k end; c.BeginGeometry = function(s, i) assert(i < s.n) end; c.DefineVertex = function() calls.vertices = calls.vertices + 1 end
        elseif kind == "Camera" then c.WorldToScreenPoint = function(_, v) assert(v.x == v.x); return { x = 0.5, y = 0.5 } end end
        return c
    end
    n.RemoveAllChildren = function(self) self.children = {} end
    n.Remove = function(self) calls.removed = calls.removed + 1; self.removed = true; if self.parent then for i, c in ipairs(self.parent.children) do if c == self then table.remove(self.parent.children, i); break end end end end
    n.SetScale = function(self, s) if type(s) == "number" then assert(s > 0 and s == s, "缩放必须为正数") else assert(s.x == s.x) end self.scale = s end
    n.SetEnabled = function(self, e) self.enabled = e end
    n.SetDeepEnabled = function(self, e) self.enabled = e end
    n.Clone = function(self) calls.clones = calls.clones + 1; return Node(self.name .. "_c", self.parent) end
    n.SetParent = function(self, p) assert(p, "SetParent 需要父节点"); self.parent = p; p.children[#p.children + 1] = self end
    n.LookAt = function(self, v) assert(v.x == v.x) end
    return n
end
function Scene() return Node("Scene") end
Material = { new = function() return obj() end }
cache = obj({ GetResource = function(_, kind, path) assert(type(path) == "string"); return obj({ path = path }) end })
Viewport = { new = function() return obj({ GetRenderPath = function() return obj() end }) end }
renderer = obj(); graphics = { GetWidth = function() return 1920 end, GetHeight = function() return 1080 end }
-- 输入
local mouse = { down = false, x = 0, y = 0 }; local keys = {}
input = { GetNumTouches = function() return 0 end, GetMouseButtonDown = function() return mouse.down end, mousePosition = setmetatable({}, { __index = function(_, k) return k == "x" and mouse.x or mouse.y end }),
    GetKeyDown = function(_, k) return keys[k] == true end, GetKeyPress = function(_, k) local v = keys["P" .. k]; keys["P" .. k] = nil; return v == true end }
-- 存档（内存）
local files = {}
function File(name, mode) local f = { name = name, mode = mode, open = true }; function f:IsOpen() return true end
    function f:WriteString(s) files[name] = s end; function f:ReadString() return files[name] end; function f:Close() end; return f end
fileSystem = { FileExists = function(_, n) return files[n] ~= nil end }
package.preload["cjson"] = function()
    local function ser(v) local t = type(v); if t == "table" then local parts = {}; for k, x in pairs(v) do parts[#parts + 1] = "[" .. string.format("%q", tostring(k)) .. "]=" .. ser(x) end return "{" .. table.concat(parts, ",") .. "}" elseif t == "string" then return string.format("%q", v) else return tostring(v) end end
    return { encode = function(v) return ser(v) end, decode = function(s) local f = assert(load("return " .. s)); local r = f(); return r end, null = {} }
end
-- NanoVG / 事件 / 音频
function nvgCreate() return {} end
function nvgCreateFont() return 1 end
function nvgRGBA(r, g, b, a) return { r, g, b, a } end
for _, fn in ipairs({ "nvgBeginFrame", "nvgEndFrame", "nvgSave", "nvgRestore", "nvgScale", "nvgBeginPath", "nvgRect", "nvgRoundedRect", "nvgCircle", "nvgFillColor", "nvgFill", "nvgStrokeColor", "nvgStrokeWidth", "nvgStroke", "nvgFontFace", "nvgFontSize", "nvgTextAlign", "nvgText", "nvgTextBox", "nvgMoveTo", "nvgLineTo" }) do
    _G[fn] = function() calls.nvg = calls.nvg + 1 end
end
local handlers = {}
function SubscribeToEvent(name, fn) handlers[name] = fn end
sdk = nil

-- ---------------------------------------------------------------- 测试
local Data = require("cosmic.Data")
require("cosmic.Run").DEBUG = true
D_TIME = require("cosmic.Data").DC_TIME - 0.5; local S = require("cosmic.Save"); local Run = require("cosmic.Run"); local App = require("cosmic.App"); local Screens = require("cosmic.Screens"); local UI = require("cosmic.UI")
local function ok(cond, msg) if not cond then error("断言失败：" .. msg, 2) end end
local function frame(dt) App.Update(dt or 1 / 30); App.Render() end
local function skipTutorial() end
local function tap(x, y) mouse.down, mouse.x, mouse.y = true, x, y; frame(); mouse.down = false; frame() end

local function section(name) print("\n[测试] " .. name) end
section("启动与机库")
require("main"); Start()
ok(App.state == "hub", "应进入机库"); for _ = 1, 20 do frame() end
ok(S.data.tutorialDone == false, "首次应显示新手引导"); tap(1920 / 2, 776); ok(S.data.tutorialDone == true, "点击开始游戏后引导关闭")
tap(1920 - 320, 725)                       -- 点击“出击”
for _ = 1, 3 do frame() end
ok(App.state == "run" and Run.R, "点击出击后应进入战斗")
print("  已进入战斗，章节", Run.R.chId, "机甲", Run.R.m.id)

local function simulate(R, seconds, opts)
    opts = opts or {}; local frames = math.floor(seconds * 30); local casts, nitros, levels = 0, 0, 0
    for i = 1, frames do
        if not opts.still then keys.KEY_W = true; keys.KEY_D = (i // 60) % 2 == 0 end
        if i % 90 == 20 then App.cast = true; casts = casts + 1 end
        if i % 150 == 60 then App.nitro = true; nitros = casts + 1 end
        frame()
        if R.choosing then levels = levels + 1; Run.ApplyChoice(R, R.choosing[1]) end
        if R.over then break end
    end
    keys.KEY_W, keys.KEY_D = nil, nil
    return casts, nitros, levels
end
section("六台机甲战斗（各 25 秒，含技能 / 氮气 / 升级）")
for _, m in ipairs(Data.MECHS) do
    S.data.mech = m.id; S.data.mechs[m.id] = S.data.mechs[m.id] or { lv = 1, star = 1 }
    App.pending = function() App.state = "run"; Run.Start(1, { danger = 1 }); App.inp = { jx = 0, jy = 0, camdx = 0 } end; frame()
    local R = Run.R; R.god = true; local c, n, l = simulate(R, 25)
    print(string.format("  %-16s 击破 %3d 等级 %2d 敌人 %2d 弹体 %2d 技能 %d 升级选择 %d 耐久 %d", m.id, R.kills, R.level, #R.enemies, #R.shots, c, l, math.floor(R.hull)))
    ok(R.kills >= 0, "击破数"); if R.over then print("   （本局提前结束）") end
end
section("新敌人 / 元素反应 / 首领")
S.data.mech = "mech_forge"; App.pending = function() App.state = "run"; Run.Start(3, { danger = 2 }); App.inp = { jx = 0, jy = 0, camdx = 0 } end; frame()
local R = Run.R; R.god = true
for _, t in ipairs({ "sniper", "guard", "splitter", "bomber", "phantom", "brute", "heavy", "inter" }) do local e = Run.Spawn(R, t, 8, 0, 20); ok(e, "生成 " .. t) end
simulate(R, 12)
local md = R.mods[1]; local e = Run.Spawn(R, "grunt", 0, 0, 10); e.slowT = 3; md.elem = "thunder"
local hp0 = e.hp; Run.HurtEnemy(R, e, 1); ok(e.hp < hp0, "受击扣血")
R.sector = 5; R.objUsed = {}; Run.NewObjective(R); Run.ObjDone(R); frame(); ok(R.phase == "boss" and R.boss, "应刷出首领"); local boss = R.boss; print("  首领：", boss.d.name)
for ph = 1, 3 do boss.hp = boss.max * ({ 0.6, 0.3, 0.001 })[ph]; R.px, R.pz = boss.x, boss.z - 25; simulate(R, 3, { still = true }) end
if boss.hp > 0 then Run.HurtEnemy(R, boss, 1e9, false, true) end; simulate(R, 10, { still = true }); ok(R.over, "首领被击败后应结算"); ok(R.result and R.result.win, "应为胜利")
print("  结算：信用点", R.result.credits, "星源", R.result.src, "解锁危险等级", S.data.dangerMax, "章节", S.data.chapter)
for _ = 1, 4 do frame() end
section("结算界面点击返回机库")
tap(1920 / 2 + 345, 730 + 40); for _ = 1, 3 do frame() end; ok(App.state == "hub", "应回到机库")
section("无尽模式 + 危险等级")
S.data.cleared["1"] = true; S.data.dangerMax = 3; App.dangerSel = 3; App.chapterSel = 1; App.StartRun(true); for _ = 1, 3 do frame() end
R = Run.R; ok(R.endless and R.danger == 3, "无尽 + 危险等级"); R.god = true
R.t = 220; simulate(R, 8); print("  波次", R.wave, "Boss", R.boss and R.boss.d.name or "无")
if R.choosing then Run.ApplyChoice(R, R.choosing[1]) end; R.god = false; R.hull = -50; frame(); ok(R.over and R.result, "无尽死亡应结算"); print("  无尽最高波数", S.data.endlessBest)
section("升级 / 暂停 / 结算界面绘制")
App.pending = function() App.state = "run"; Run.Start(1, {}) end; frame(); R = Run.R; R.god = true
R.choosing = Run.Choices(R); frame(); for _, id in ipairs(R.choosing) do local info = Run.ChoiceInfo(R, id); ok(info.name and info.text, "选项信息") end
Run.Reroll(R, false); frame(); Run.Skip(R); frame()
App.paused = true; frame(); App.paused = false

section("完整版：卡牌 / 芯片 / 驾驶员 / 召唤 / 每日 / 页面")
local Meta = require("cosmic.Meta"); local Pages = require("cosmic.Pages")
S.data.credits = 2000000; S.data.src = 5000
local gotGold, news = 0, 0
for _ = 1, 160 do local c, err, new = Meta.BuyCard(); ok(c, "抽卡：" .. tostring(err)); if new then news = news + 1 end; if c.tier == 3 then gotGold = gotGold + 1 end end
print("  抽卡 160 次：新卡牌", news, "金色", gotGold, "收集", #S.data.modules, "/", Meta.ModTotal())
for _ = 1, 12 do local ch = Meta.BuyChip(); ok(ch, "芯片") end
for i = 1, 3 do Meta.EquipChip(S.data.chips[i].id) end
local st = Meta.Stats(); print("  芯片属性：火力", string.format("%.2f", st.atk), "耐久", string.format("%.2f", st.hp), "暴击", string.format("%.2f", st.crit))
local mc = Meta.MakeCard(0, "mine", "fire", 0); local bc = Meta.MakeCard(0, "boomerang", "thunder", 0); local sc = Meta.MakeCard(1, "strike", "dark", 1)
for _, c in ipairs({ mc, bc, sc }) do if not Meta.Card(c.id) then S.data.modules[#S.data.modules + 1] = c end end
S.data.modEq = { mc.id, bc.id, sc.id }
print("  登录奖励：", Meta.LoginClaim()); ok(Meta.LoginState().claimed, "登录已领")
S.data.runs = 3; print("  可领成就", Meta.AchReady()); for _, a in ipairs(Meta.ACH) do Meta.AchClaim(a.id) end
local res = Meta.Pull("pilot", 10); ok(res and #res == 10, "驾驶员十连"); res = Meta.Pull("mech", 10); ok(res, "机甲十连")
local dc = Meta.DailyChallenge(); print("  每日挑战：第", dc.chapter, "章", dc.mods[1], dc.mods[2]); ok(#dc.mods == 2, "每日词缀")
for _, pg in ipairs({ "work", "pilots", "summon", "daily", "about" }) do
    App.state = "hub"; App.page = pg; App.wk.tab = "cards"; frame(); frame(); if pg == "work" then App.wk.tab = "chips"; App.wk.chip = S.data.chips[1].id; frame(); frame(); App.wk.tab = "cards" end
end
App.page = "hub"
section("驾驶员支援技能（6 位，各 20 秒）")
for _, c in ipairs(Data.CHARS) do
    S.data.pilot = c.id; S.data.chars[c.id] = S.data.chars[c.id] or { star = 1 }
    App.pending = function() App.state = "run"; Run.Start(2, {}); App.inp = { jx = 0, jy = 0, camdx = 0 } end; frame()
    local R = Run.R; R.god = true; R.supT = 0.1; simulate(R, 20, { still = true }); print(string.format("  %-16s 击破 %3d 卡牌 %d 张", c.id, R.kills, #R.mods))
end
section("星域目标（6 种）+ 词缀 + 新卡牌形态")
for _, typ in ipairs({ "clear", "hunt", "ambush", "derelict", "ore", "distress" }) do
    App.pending = function() App.state = "run"; Run.Start(1, {}); App.inp = { jx = 0, jy = 0, camdx = 0 } end; frame()
    local R = Run.R; R.god = true; R.sector = 2; R.objUsed = {}; for k in pairs(Run.OBJ) do if k ~= typ then R.objUsed[k] = true end end; Run.NewObjective(R); ok(R.obj and R.obj.type == typ, "目标 " .. typ)
    R.affix = { id = "swift", name = "高速敌群", desc = "" }
    local o = R.obj; if typ ~= "clear" and typ ~= "ore" then R.px, R.pz = o.x, o.z end
    local t0 = R.sector; for i = 1, 30 * 70 do R.god = true; if typ == "ore" or typ == "clear" or typ == "hunt" then for _, e in ipairs(R.enemies) do e.hp = 0.001 end end; if typ == "ambush" then for _, e in ipairs(R.enemies) do if e.ambush then e.hp = 0.001 end end end
        if typ == "derelict" or typ == "distress" or typ == "hunt" or typ == "ambush" then R.px, R.pz = o.x, o.z end
        if typ == "ore" then for _, e in ipairs(o.ores) do if e.hp > 0 then Run.HurtEnemy(R, e, 1e6, false, true) end end end
        frame(); if R.choosing then Run.ApplyChoice(R, R.choosing[1]) end; if R.sector > t0 then break end end
    print(string.format("  %-9s 完成：%s（星域 %d -> %d）", typ, tostring(R.sector > t0), t0, R.sector)); ok(R.sector > t0, "目标 " .. typ .. " 应能完成")
end
S.data.modEq = { Meta.MakeCard(0, "homing", "light", 0).id }
section("每日挑战整局（快进）")
local d = Meta.DailyChallenge(); App.StartDaily(d); for _ = 1, 3 do frame() end; local R = Run.R; ok(R.daily and R.endless, "每日挑战模式"); R.god = true; simulate(R, 20); R.t = D_TIME or 239.5
R.t = 239.99; frame(); frame(); ok(R.over and R.result and R.result.dcScore, "每日挑战到时应结算"); print("  得分", R.result.dcScore, "首次", R.result.dcFirst)

section("召唤保底")
S.data.src = 5000; S.data.mechPity, S.data.mechPity3 = 49, 119; local pr = Meta.Pull("mech", 1); ok(pr[1].g == "SSSR" and S.data.mechPity3 == 0, "120 抽保底 SSSR")
S.data.pilotPity, S.data.pilotPity3 = 49, 0; pr = Meta.Pull("pilot", 1); ok(pr[1].g == "SSR" or pr[1].g == "SSSR", "50 抽保底 SSR 以上")
local own = 0; for _ in pairs(S.data.mechs) do own = own + 1 end; print("  已拥有机甲", own)
print(string.format("\n通过：克隆节点 %d 次，生成顶点 %d 个，NanoVG 调用 %d 次，节点创建 %d / 移除 %d", calls.clones, calls.vertices, calls.nvg, calls.nodes, calls.removed))
print("OK")
