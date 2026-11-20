-- mock_xp_test.lua：用桌面 Lua 模拟 UrhoX 接口，跑通“网页版转换内核”完整流程：机库 -> 出击 -> 战斗（含升级 / 技能 / 氮气）-> 结算 -> 各页面。
package.path = "scripts/?.lua;scripts/?/init.lua;" .. package.path
math.randomseed(5)
local calls = { nodes = 0, nvg = 0, clones = 0 }
local function obj(t) return setmetatable(t or {}, { __index = function(_, k) return function() end end }) end
local V3 = {}; V3.__index = V3
function Vector3(x, y, z) assert(x == x and y == y and z == z, "Vector3 含 NaN"); return setmetatable({ x = x, y = y, z = z }, V3) end
function V3:Normalized() local l = math.sqrt(self.x ^ 2 + self.y ^ 2 + self.z ^ 2); return Vector3(self.x / l, self.y / l, self.z / l) end
function Vector2(x, y) return { x = x, y = y } end
function Color(r, g, b, a) assert(r == r and g == g and b == b, "Color 含 NaN"); return { r, g, b, a } end
function Quaternion(w, x, y, z) assert(w == w and x == x and y == y and z == z, "Quaternion 含 NaN"); return { w = w, x = x, y = y, z = z } end
function BoundingBox(a, b) return { a, b } end
function Variant(v) assert(v ~= nil); return { v = v } end
CULL_NONE, TRIANGLE_LIST, LIGHT_DIRECTIONAL, MOUSEB_LEFT, SOUND_EFFECT, SOUND_MUSIC, REMOVE_COMPONENT, FILE_READ, FILE_WRITE = 0, 0, 0, 1, 0, 1, 0, 0, 1
for _, k in ipairs({ "A", "D", "W", "S", "E", "R", "F", "LEFT", "RIGHT", "UP", "DOWN", "SPACE", "SHIFT", "ESCAPE" }) do _G["KEY_" .. k] = "KEY_" .. k end
NVG_ALIGN_LEFT, NVG_ALIGN_CENTER, NVG_ALIGN_RIGHT, NVG_ALIGN_TOP, NVG_ALIGN_MIDDLE, NVG_ALIGN_BASELINE, NVG_CW = 1, 2, 4, 8, 16, 64, 2
local Node
Node = function(name, parent)
    calls.nodes = calls.nodes + 1
    local n = { name = name, children = {}, parent = parent, enabled = true, position = Vector3(0, 0, 0), rotation = Quaternion(1, 0, 0, 0) }
    setmetatable(n, { __index = function(t, k) if k == "worldPosition" then return Vector3(0, 0, 0) end return function() end end })
    n.CreateChild = function(self, nm) local ch = Node(nm, self); self.children[#self.children + 1] = ch; return ch end
    n.CreateComponent = function(self, kind) local c = obj({ kind = kind })
        if kind == "CustomGeometry" then c.SetNumGeometries = function(s, k) s.n = k end; c.BeginGeometry = function(s, i) assert(i < s.n) end; c.DefineVertex = function(_, v) assert(v.x == v.x and v.y == v.y and v.z == v.z, "顶点 NaN") end end
        return c end
    n.Remove = function(self) self.removed = true end
    n.SetScale = function(self, s) if type(s) == "number" then assert(s == s and s > 0, "缩放必须为正数：" .. tostring(s)) end self.scale = s end
    n.SetEnabled = function(self, e) self.enabled = e end; n.SetDeepEnabled = function(self, e) self.enabled = e end
    n.Clone = function(self) calls.clones = calls.clones + 1; return Node(self.name .. "_c", self.parent) end
    n.SetParent = function(self, p) self.parent = p end
    n.LookAt = function(self, v) assert(v.x == v.x and v.y == v.y and v.z == v.z, "LookAt NaN") end
    return n
end
function Scene() return Node("Scene") end
Material = { new = function() return obj() end }
cache = obj({ GetResource = function(_, kind, path) assert(type(path) == "string"); return obj({ path = path }) end })
Viewport = { new = function() return obj({ GetRenderPath = function() return obj() end }) end }
renderer = obj(); local W, Hh = tonumber(os.getenv("SHOT_W") or 1920), tonumber(os.getenv("SHOT_H") or 1080)
graphics = { GetWidth = function() return W end, GetHeight = function() return Hh end }
local mouse = { down = false, x = 0, y = 0 }; local keys = {}
input = { mouseMoveWheel = 0, GetNumTouches = function() return 0 end, GetMouseButtonDown = function() return mouse.down end, mousePosition = setmetatable({}, { __index = function(_, k) return k == "x" and mouse.x or mouse.y end }),
    GetKeyDown = function(_, k) return keys[k] == true end, GetKeyPress = function(_, k) local v = keys["P" .. k]; keys["P" .. k] = nil; return v == true end }
local files = {}
function File(name, mode) local f = {}; function f:IsOpen() return true end; function f:WriteString(s) files[name] = s end; function f:ReadString() return files[name] end; function f:Close() end; return f end
fileSystem = { FileExists = function(_, n) return files[n] ~= nil end }
function nvgRadialGradient() return {} end
function nvgCreate() return {} end
function nvgCreateFont() return 1 end
function nvgRGBA(r, g, b, a) return { r, g, b, a } end
for _, fn in ipairs({ "nvgBeginFrame", "nvgEndFrame", "nvgSave", "nvgRestore", "nvgScale", "nvgTranslate", "nvgRotate", "nvgBeginPath", "nvgRect", "nvgRoundedRect", "nvgCircle", "nvgArc", "nvgFillColor", "nvgFill", "nvgStrokeColor", "nvgStrokeWidth", "nvgStroke", "nvgFontFace", "nvgFontSize", "nvgTextAlign", "nvgText", "nvgTextBox", "nvgMoveTo", "nvgLineTo", "nvgClosePath", "nvgTextLineHeight", "nvgScissor", "nvgResetScissor", "nvgFontBlur", "nvgTextLetterSpacing", "nvgFillPaint" }) do _G[fn] = function() calls.nvg = calls.nvg + 1 end end
local handlers = {}; function SubscribeToEvent(name, fn) handlers[name] = fn end
sdk = nil
local App = require("cosmic.GameApp"); local JS = require("jsrt.JS")
local function frame(dt) App.Update(dt or 1 / 30); App.Render() end
local function tap(x, y) mouse.down, mouse.x, mouse.y = true, x, y; frame(); mouse.down = false; frame() end
local function ok(c, m) if not c then error("断言失败：" .. m, 2) end end
local function section(n) print("\n[测试] " .. n) end
section("启动与机库"); require("main"); Start()
local H = require("jsrt.Host")  -- 仅为类型检查
for _ = 1, 10 do frame() end
for _, tab in ipairs({ "home", "hangar", "pilots", "work", "summon", "daily" }) do
    local Hub = require("cosmic.Hub"); Hub.tab = tab; Hub.wsub = "mods"; frame(); frame(); if tab == "work" then Hub.wsub = "chips"; frame(); frame() end
end
require("cosmic.Hub").tab = "home"
local GameUI = require("cosmic.GameUI"); local Hub = require("cosmic.Hub")
local Hh, S, C = App.Get()
local function simulate(frames, opts)
    opts = opts or {}; local levels = 0
    for i = 1, frames do
        if S.R then
            if not opts.still then S.joy.dx = math.sin(i / 25) * 0.8; S.joy.dy = 0.6 + 0.4 * math.cos(i / 40) end
            if i % 120 == 30 then S:castActive() end; if i % 170 == 90 then S:dodge() end
        end
        frame()
        local u = GameUI.state
        if u.levelup then levels = levels + 1; S:applyChoice(u.levelup.ids[0]); GameUI.finishLevel() end
        if u.shop then u.shop = nil; S.paused = false end
        if u.revive then u.revive = nil; S:endRun(false) end
        if S.R and S.R.ended and not opts.keepEnd then break end
    end
    return levels
end
section("工坊 / 召唤 / 每日 操作")
C.save.credits = 9000000; C.save.src = 5000
Hub.tab = "work"; Hub.wsub = "mods"; frame()
for _ = 1, 40 do local r = C:buyModule(); ok(not r.err, "抽卡") end
for _ = 1, 8 do local r = C:buyChip(); ok(not r.err, "芯片") end
print("  卡牌", C.save.modules.length, "芯片", C.save.chips.length)
local r1 = C:pull("mech", false); ok(r1.id, "召唤"); local r2 = C:pull("pilot", false); ok(r2.id, "召唤驾驶员")
ok(C:loginClaim() ~= nil, "登录奖励"); local dc = C:dailyChallenge(); ok(dc.mods.length == 2, "每日词缀")
for _, tab in ipairs({ "home", "hangar", "pilots", "work", "summon", "daily" }) do Hub.tab = tab; Hub.wsub = "mods"; frame(); frame(); if tab == "work" then Hub.wsub = "chips"; Hub.wsel = C.save.chips[0].id; frame(); frame() end end
Hub.results = { kind = "card", item = C.save.modules[0], name = C.save.modules[0].name, tier = C.save.modules[0].tier }; frame(); Hub.results = nil
Hub.results = { kind = "chip", item = C.save.chips[0], name = C.save.chips[0].name, tier = C.save.chips[0].tier }; frame(); Hub.results = nil
Hub.modal = "settings"; frame(); Hub.modal = "about"; frame(); Hub.modal = "getsrc"; frame(); Hub.modal = "rates"; frame(); Hub.modal = nil
Hub.tab = "home"
C.save.settings.lvMode = "now"
section("六台机甲 x 战斗（各 20 秒）")
for _, m in ipairs({ "mech_azure", "mech_blaze", "mech_halo", "mech_forge", "mech_frost", "mech_starfall" }) do
    if not C.save.mechs[m] then C.save.mechs[m] = { lv = 1, star = 1 } end
    C.save.mech = m; C.save.pilot = C:mech(m).match; if not C.save.chars[C.save.pilot] then C.save.chars[C.save.pilot] = { star = 1 } end
    Hub.onStart(1, { danger = 1 }); for _ = 1, 3 do frame() end
    ok(Hh.A:mode() == "cosmic-run" and S.R, "进入战斗")
    local lv = simulate(600); print(string.format("  %-14s 击破 %3d 等级 %2d 敌人 %2d 弹体 %2d 升级选择 %d", m, S.R.kills, S.R.level, S.R.enemies.length, S.R.shots.length, lv))
    S.R = nil; Hh.A:setMode("cosmic-hub"); GameUI.Reset(); S.paused = false
end
section("首领战 + 结算界面 + 返回机库")
C.save.mech = "mech_forge"; C.save.pilot = "char_hupo"; C.save.chars.char_hupo = C.save.chars.char_hupo or { star = 1 }
Hub.onStart(3, { danger = 2 }); for _ = 1, 3 do frame() end; Hh.run.debug:sector(6)
simulate(120, { still = true }); local R = S.R; local boss = R.boss; ok(boss, "应有首领"); print("  首领：", boss.d.name)
boss.hp = 1; simulate(60, { still = true }); S:hurtEnemy(boss, 1e9, 0, 0, 0, true)
for _ = 1, 160 do frame() end
R = S.R; ok(R and R.ended and R.result, "首领击败后应出现结算"); print("  结算：信用点", R.result.credits, "星源", R.result.src, "胜利", R.result.win)
for _ = 1, 5 do frame() end
do local UIm = require("cosmic.UI"); tap((UIm.ox + 1257) * UIm.s, (UIm.oy + 872) * UIm.s) end; for _ = 1, 4 do frame() end
ok(Hh.A:mode() == "cosmic-hub", "点击返回机库后应回到机库")
section("无尽模式 / 每日挑战 / 暂停 / 复活")
C.save.cleared[1] = true; Hub.onStart(1, { danger = 3, endless = true }); for _ = 1, 3 do frame() end; simulate(300)
S:openPause(); frame(); GameUI.state.pause = nil; S.paused = false
S.R.hull = -10; for _ = 1, 3 do frame() end
Hub.onStart(dc.chapter, { daily = true, mods = dc.mods, danger = dc.danger }); for _ = 1, 3 do frame() end; ok(S.R.daily, "每日挑战"); simulate(200)
S.R.t = 239.99; S.R.secT = 240; for _ = 1, 6 do frame() end; ok(S.R.ended, "每日挑战到时应结算"); print("  每日得分", S.R.result and S.R.result.dcScore)
section("升级选卡模式：稍后 / 自动 / 弹窗内稍后")
C.save.chips = JS.newarr(0); C.save.chipEq = JS.newarr(0)
local function freshRun() S.R = nil; Hh.A:setMode("cosmic-hub"); GameUI.Reset(); S.paused = false; Hub.onStart(1, { danger = 1 }); for _ = 1, 3 do frame() end end
freshRun(); C.save.settings.lvMode = "later"
S:gainXp(80)       -- 确定性地制造待选升级，避免依赖战斗里的随机掉落
local modals = 0; for i = 1, 500 do S.joy.dx = math.sin(i / 25) * 0.8; S.joy.dy = 0.7; frame(); if GameUI.state.levelup then modals = modals + 1; GameUI.state.levelup = nil; S.paused = false end
    if GameUI.state.shop then GameUI.state.shop = nil; S.paused = false end       -- 战斗里随机出现的商人事件会暂停游戏，测试里直接离开
    if GameUI.state.revive then GameUI.state.revive = nil; S.paused = false; S.R.hull = S:hullMax() end end
ok(modals == 0, "稍后模式下不应自动弹出选卡"); ok(S.R.pendingLevels > 0, "稍后模式应累积待选升级"); print("  稍后模式：500 帧无弹窗，待选升级", S.R.pendingLevels, "战斗未暂停:", not S.paused)
S.R.hull = S:hullMax(); S.paused = false; GameUI.state.shop = nil; GameUI.state.pause = nil
local n0 = S.R.pendingLevels; GameUI.OpenPendingLevel(); frame(); frame(); ok(GameUI.state.levelup, "点待升级按钮后应弹出选卡"); ok(S.R.pendingLevels == n0 - 1, "弹出时扣 1 次待选")
GameUI.DeferLevel(); frame(); ok(not GameUI.state.levelup and S.R.pendingLevels == n0 and not S.paused, "稍后选择应放回待选并继续战斗")
GameUI.OpenPendingLevel(); frame(); frame(); S:applyChoice(GameUI.state.levelup.ids[0]); GameUI.finishLevel(); frame(); ok(S.R.pendingLevels == n0 - 1, "选择后待选减 1")
freshRun(); C.save.settings.lvMode = "auto"; local lv0 = 1
S:gainXp(80)
for i = 1, 500 do S.joy.dx = math.sin(i / 25) * 0.8; S.joy.dy = 0.7; frame(); ok(not GameUI.state.levelup, "自动模式不应弹窗"); if GameUI.state.shop then GameUI.state.shop = nil; S.paused = false end; if GameUI.state.revive then GameUI.state.revive = nil; S.paused = false; S.R.hull = S:hullMax() end end
ok(S.R.level > 1 and S.R.pendingLevels == 0, "自动模式应自动消化升级"); print("  自动模式：等级", S.R.level, "待选", S.R.pendingLevels)
C.save.settings.lvMode = "later"; S.R = nil; Hh.A:setMode("cosmic-hub"); GameUI.Reset(); S.paused = false
section("兑换码 / 开发者模式（需要 tools/gen_codes.py 生成的测试码）")
local TC = os.getenv("TEST_CREDITS")
if TC then
    local Rd = require("cosmic.Redeem"); local DevUI = require("cosmic.DevUI"); local UIm = require("cosmic.UI")
    S.R = nil; Hh.A:setMode("cosmic-hub"); GameUI.Reset(); S.paused = false
    C.save.did = os.getenv("TEST_DID"); C.save.devCode = nil; C.save.redeemed = nil; Rd.Dev.on = false; Rd.lockUntil = 0; Rd.fails = 0
    local c0, s0 = C.save.credits, C.save.src
    local ok1, m1 = Rd.Redeem(C, TC); ok(ok1 and C.save.credits == c0 + 5000, "信用点兑换码应加 5000：" .. tostring(m1)); print("  信用点码：", m1)
    local ok2, m2 = Rd.Redeem(C, TC); ok(not ok2, "同一个码不能重复兑换"); print("  重复兑换：", m2)
    local ok3 = Rd.Redeem(C, os.getenv("TEST_SRC")); ok(ok3 and C.save.src == s0 + 100, "星源兑换码应加 100")
    local ok4, m4 = Rd.Redeem(C, os.getenv("TEST_EXPIRED")); ok(not ok4, "过期码应失败"); print("  过期码：", m4)
    local ok5, m5 = Rd.Redeem(C, os.getenv("TEST_DEV")); ok(not ok5, "开发者码不能当兑换码用"); print("  开发者码走兑换：", m5)
    for i = 1, 5 do Rd.Redeem(C, "AAAAAA-AAAAAA-AAAAAA-AAAAAA") end
    local ok6, m6 = Rd.Redeem(C, os.getenv("TEST_CREDITS2")); ok(not ok6, "连续错误后应被锁定"); print("  锁定：", m6); Rd.lockUntil = 0
    ok(not Rd.Dev.on, "未解锁时开发者模式必须关闭")
    local okd, md = Rd.Dev.Unlock(C, os.getenv("TEST_DEV_OTHER")); ok(not okd, "别的设备的开发者码必须无效"); print("  别的设备的开发者码：", md); Rd.lockUntil = 0
    local okd2, md2 = Rd.Dev.Unlock(C, os.getenv("TEST_DEV")); ok(okd2 and Rd.Dev.on, "本设备的开发者码应能解锁"); print("  开发者码：", md2)
    Rd.Dev.on = false; ok(Rd.Dev.Check(C), "重新启动后应仍保持解锁"); C.save.devCode = os.getenv("TEST_DEV_OTHER"); ok(not Rd.Dev.Check(C), "篡改存档里的码必须失效"); C.save.devCode = os.getenv("TEST_DEV"); Rd.Dev.Check(C)
    -- 界面：兑换码页（键盘输入 + 点确认）、开发者面板全部动作、战斗面板
    local Hub2 = require("cosmic.Hub"); Hub2.tab = "home"; Hub2.modal = "redeem"; DevUI.kp = nil; frame(); frame()
    DevUI.kp.text = os.getenv("TEST_CREDITS3"):gsub("-", ""); local cc = C.save.credits
    tap((UIm.ox + 1248) * UIm.s, (UIm.oy + 742) * UIm.s); frame(); ok(C.save.credits == cc + 5000, "在兑换码页点确认应兑换成功"); Hub2.modal = nil
    Hub2.modal = "dev"; frame(); frame()
    for i, act in ipairs(DevUI.ACTIONS) do local okp, e = pcall(act[2]); ok(okp, "开发者动作失败：" .. act[1] .. " " .. tostring(e)) end
    C:write(); Hub2.modal = "devlock"; DevUI.kp = nil; frame(); Hub2.modal = nil
    Hub2.onStart(1, { danger = 1 }); for _ = 1, 3 do frame() end; DevUI.open = true; DevUI.stats = true
    local function btn(i) local col, row = (i - 1) % 2, (i - 1) // 2; return UIm.lw - 380 + 12 + col * 172 + 82, 280 + 12 + row * 62 + 27 end
    local function tapEdge(x, y) tap((x) * UIm.s, (UIm.oy + y) * UIm.s) end
    frame(); frame(); tapEdge(btn(1)); frame(); ok(S.R.god, "无敌按钮应生效"); tapEdge(btn(2)); frame(); ok(S.R.devOne, "秒杀按钮应生效")
    tapEdge(btn(5)); frame(); frame(); tapEdge(btn(9)); frame(); frame(); ok(S.R.sector == 2, "下一星域按钮应生效"); tapEdge(btn(4)); frame(); tapEdge(btn(3)); frame()
    DevUI.speed = 4; for _ = 1, 30 do frame() end; DevUI.speed = 0.5; for _ = 1, 10 do frame() end; DevUI.speed = 1
    tapEdge(btn(13)); for _ = 1, 4 do frame() end; ok(S.R == nil or S.R.ended, "胜利结算按钮应结算")
    S.R = nil; Hh.A:setMode("cosmic-hub"); GameUI.Reset(); S.paused = false; DevUI.open = false; Rd.Dev.Lock(C)
    print("  兑换码与开发者模式测试通过")
else print("  （未提供测试码，跳过；在工程里运行 tools/run_xp_test.py 会自动生成）") end
section("召唤动画（10 连）")
S.R = nil; Hh.A:setMode("cosmic-hub"); GameUI.Reset(); S.paused = false
local Hub2 = require("cosmic.Hub"); C.save.src = 5000; Hub2.tab = "summon"; Hub2.banner = "mech"
local res = {}; for i = 1, 10 do res[#res + 1] = C:pull("mech", i == 10) end; Hub2.StartSummon(res)
local ph = {}; for i = 1, 600 do frame(); local sa = Hub2.sa; if not sa then break end; if #ph == 0 or ph[#ph] ~= sa.phase then ph[#ph + 1] = sa.phase end
    if sa.phase == "cards" and sa.t > 3 then if #sa.show > 0 then sa.phase = "show"; sa.t = 0; sa.si = 1 else Hub2.FinishSummon() end end
    if sa.phase == "show" and sa.t > 0.5 then if sa.si < #sa.show then sa.si = sa.si + 1; sa.t = 0 else Hub2.FinishSummon() end end end
print("  阶段：", table.concat(ph, " -> ")); ok(Hub2.sa == nil, "召唤动画应能结束")
Hub2.tab = "home"
print(string.format("\n通过：节点创建 %d，克隆 %d，NanoVG 调用 %d", calls.nodes, calls.clones, calls.nvg))
print("OK")
