-- mock_engine_test.lua
-- 开发自检：用桌面 Lua（5.3/5.4）加载整个工程，模拟 UrhoX 的 API，跑通完整游戏流程。
-- 只能发现脚本自身的错误（拼写、nil 访问、调用顺序、逻辑），不能替代真机运行。
-- 用法（工程根目录）：lua tools/mock_engine_test.lua
package.path = "scripts/?.lua;scripts/?/init.lua;" .. package.path
math.randomseed(7)

local calls = { vertices = 0, clones = 0, nvg = 0, writes = 0 }
local function obj(t) return setmetatable(t or {}, { __index = function(_, k) return function() end end }) end

-- 数学
local V3 = {}; V3.__index = V3
function Vector3(x, y, z) assert(x == x and (y or 0) == (y or 0) and (z or 0) == (z or 0), "Vector3 含 NaN"); return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, V3) end
function V3:Normalized() local l = math.sqrt(self.x ^ 2 + self.y ^ 2 + self.z ^ 2); return Vector3(self.x / l, self.y / l, self.z / l) end
function Vector2(x, y) return { x = x, y = y } end
function Color(r, g, b, a) assert(type(r) == "number" and type(g) == "number" and type(b) == "number"); return { r, g, b, a } end
function Quaternion(x, y, z) assert(x == x and y == y and z == z, "NaN 角度"); return { x, y, z } end
function BoundingBox(a, b) return { a, b } end
function CascadeParameters(...) return { ... } end
function BiasParameters(...) return { ... } end
function Variant(v) assert(v ~= nil); return { v = v } end
CULL_NONE, TRIANGLE_LIST, LIGHT_DIRECTIONAL, SHADOWQUALITY_PCF_24BIT, MOUSEB_LEFT = 0, 0, 0, 0, 1
for _, k in ipairs({ "A", "D", "W", "S", "R", "F", "Q", "T", "E", "M", "G", "LEFT", "RIGHT", "UP", "DOWN", "SPACE", "SHIFT", "ESCAPE" }) do _G["KEY_" .. k] = "KEY_" .. k end
NVG_ALIGN_CENTER, NVG_ALIGN_TOP = 2, 8
FILE_READ, FILE_WRITE = 0, 1

-- 节点
local function Component(kind)
    local c = obj({ kind = kind })
    if kind == "CustomGeometry" then
        c.SetNumGeometries = function(self, n) self.n = n end
        c.BeginGeometry = function(self, i) assert(i < self.n, "几何体索引越界") end
        c.DefineVertex = function() calls.vertices = calls.vertices + 1 end
        c.DefineNormal = function(_, n) assert(math.abs(n.x) + math.abs(n.y) + math.abs(n.z) == 1) end
        c.SetMaterial = function(self, i, m) assert(m and i < self.n) end
    elseif kind == "Camera" then
        c.WorldToScreenPoint = function(_, v) assert(v.x); return { x = 0.5, y = 0.5 } end
    end
    return c
end
local Node
Node = function(name, parent)
    local n = obj({ name = name, children = {}, parent = parent, enabled = true })
    n.CreateChild = function(self, nm) local ch = Node(nm, self); self.children[#self.children + 1] = ch; return ch end
    n.CreateComponent = function(_, kind) return Component(kind) end
    n.RemoveAllChildren = function(self) self.children = {} end
    n.Remove = function(self) self.removed = true end
    n.LookAt = function(_, v) assert(v.x) end
    n.SetScale = function(_, s) assert(type(s) == "number" and s > 0 and s == s, "缩放必须为正数") end
    n.SetEnabled = function(self, e) self.enabled = e end
    n.SetDeepEnabled = function(self, e) self.enabled = e end
    n.Clone = function(self) calls.clones = calls.clones + 1; return Node(self.name .. "_clone", self.parent) end
    n.SetParent = function(self, p) assert(p, "SetParent 需要父节点"); self.parent = p end
    return n
end
function Scene() return Node("Scene") end
Material = { new = function() return obj() end }
cache = obj({ GetResource = function(_, kind, path) assert(type(path) == "string"); return { path = path } end })
Viewport = { new = function() return obj({ GetRenderPath = function() return obj() end }) end }
local activeViewport = nil
renderer = obj({ SetViewport = function(_, i, v) activeViewport = v end })
local W, H = 2532, 1170
graphics = obj({ GetWidth = function() return W end, GetHeight = function() return H end, GetDPR = function() return 3 end })
local keysDown, keysPress = {}, {}
input = obj({ numTouches = 0, mouseMoveX = 0, mouseMoveY = 0, mouseWheelMove = 0,
    GetMouseButtonPress = function() return false end, GetMouseButtonDown = function() return false end,
    GetKeyDown = function(_, k) return keysDown[k] or false end, GetKeyPress = function(_, k) return keysPress[k] or false end })
local handlers = {}
function SubscribeToEvent(name, fn) handlers[name] = function(...) local f = type(fn) == "string" and _G[fn] or fn; return f(...) end end

-- 文件与 JSON 替身
local files = {}
fileSystem = obj({ FileExists = function(_, f) return files[f] ~= nil end })
function File(name, mode)
    return { IsOpen = function() return true end, ReadString = function() return files[name] end,
             WriteString = function(_, s) files[name] = s; calls.writes = calls.writes + 1 end, Close = function() end }
end
local function ser(v)
    if type(v) == "table" then
        local parts = {}
        for k, x in pairs(v) do parts[#parts + 1] = "[" .. (type(k) == "string" and string.format("%q", k) or tostring(k)) .. "]=" .. ser(x) end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif type(v) == "string" then return string.format("%q", v) end
    return tostring(v)
end
package.loaded["cjson"] = { encode = ser, decode = function(s) return load("return " .. s)() end, null = {} }

-- NanoVG
for _, f in ipairs({ "nvgBeginPath", "nvgRect", "nvgFillColor", "nvgFill", "nvgMoveTo", "nvgLineTo", "nvgStroke", "nvgStrokeColor", "nvgStrokeWidth",
    "nvgSave", "nvgRestore", "nvgTranslate", "nvgRotate", "nvgClosePath", "nvgCircle", "nvgFontFace", "nvgFontSize", "nvgTextAlign", "nvgText" }) do
    _G[f] = function(...) calls.nvg = calls.nvg + 1; for _, a in ipairs({ ... }) do if type(a) == "number" then assert(a == a, f .. " 收到 NaN") end end end
end
nvgRGBA = function(r, g, b, a) return { r, g, b, a } end

-- UI 替身
local root = nil
local function Widget(kind, props)
    props = props or {}
    local w = { kind = kind, props = props, visible = true }
    w.SetText = function(self, t) assert(type(t) == "string", "SetText 需要字符串"); self.props.text = t end
    w.SetVisible = function(self, v) self.visible = v end
    w.SetStyle = function(self, st) for k, v in pairs(st) do self.props[k] = v end end
    for i, ch in ipairs(props.children or {}) do assert(type(ch) == "table", kind .. " 的第 " .. i .. " 个子控件不是表") end
    return w
end
local UI = setmetatable({}, { __index = function(_, k) return function(props) return Widget(k, props) end end })
UI.Init = function(cfg) assert(type(cfg.scale) == "function") end
UI.SetRoot = function(r) root = r end
UI.IsPointerOverUI = function() return false end
UI.Layout = function() end
UI.Shutdown = function() end
UI.Theme = { FontFace = function() return "sans" end }
UI.Widget = { Extend = function(_, name)
    local cls = {}; cls.__index = cls
    setmetatable(cls, { __call = function(c, props) local o = setmetatable({ props = props, kind = name }, c); o:Init(props); return o end })
    cls.GetAbsoluteLayout = function(self) return { x = 0, y = 0, w = self.props.width or 1920, h = self.props.height or 1080 } end
    cls.SetVisible = function() end
    return cls end, Init = function(self, props) self.props = props end }
package.loaded["urhox-libs/UI"] = UI

-- 工具：遍历控件树
local function walk(w, fn)
    if type(w) ~= "table" then return end
    fn(w)
    for _, ch in ipairs((w.props and w.props.children) or {}) do walk(ch, fn) end
end
local function findText(text)
    local found = nil
    walk(root, function(w) if not found and w.props and w.props.onClick then
        walk(w, function(x) if x.props and x.props.text == text then found = w end end) end end)
    return found
end
local function click(text)
    local w = findText(text)
    assert(w, "找不到按钮：" .. text)
    w.props.onClick(w, {})
end
local function render()
    walk(root, function(w) if w.Render then w:Render({}) end end)
end
local function frames(n, dt)
    for _ = 1, n do handlers.Update(nil, { TimeStep = { GetFloat = function() return dt or 1 / 30 end } }); keysPress = {} end
end

-- ================================================================ 运行
dofile("scripts/main.lua")
Start()
local Game = require("game.Game")
local Space = require("game.Space")
local S = require("game.Save")
frames(5)
assert(Game.GetMode() == "title")
click("新的旅程"); frames(3)
assert(Game.GetMode() == "station", "新游戏后应停靠在星港")
click("任务板"); click("接受"); assert(S.data.active and S.data.active.id == "story1", "应接受主线 1")
assert((S.data.cargo.parts or 0) == 5, "主线 1 应提供 5 箱零件")
click("交易所"); click("买 5"); print("买入后货舱", S.CargoUsed(), "信用点", S.data.credits)
click("起飞"); frames(10)
assert(Game.GetMode() == "flight")
render()
-- 战斗：在正前方放一艘海贼，持续开火
local W = Space.W
local p = W.player
p.throttle = 0; p.speed = 0
local U = require("game.Util")
local f = U.fwdOf(p.yaw, p.pitch)
local e = Space.SpawnPirate("ship_pirate_interceptor", { 0, 0, 0 })
e.pos = U.add(p.pos, U.mul(f, 150)); e.home = U.copy(e.pos)
W.target = e
Space.input.fire = true
local t = 0
while Space.Alive(e) and t < 900 do
    -- 模拟玩家持续把机头对准目标
    p.yaw, p.pitch = U.anglesTo(U.sub(e.pos, p.pos))
    Space.input.fire = true
    frames(1); t = t + 1
end
Space.input.fire = false
print(string.format("击落用时 %.1f 秒，击落数 %d", t / 30, S.data.kills))
assert(S.data.kills >= 1, "应击落海贼")
render()
-- 导弹、目标切换、自动导航
keysPress[KEY_Q] = true; frames(1); keysPress[KEY_T] = true; frames(1); keysPress[KEY_G] = true; frames(60)
-- 星图与暂停
Game.OpenMap(); render(); click("返回飞行"); frames(2)
Game.OpenPause(); click("继续"); frames(2)
-- 跃迁到碎石带并交付任务
Game.Jump("rubble"); frames(30)
assert(W.sys.id == "rubble", "应跃迁到碎石带")
render()
Game.Dock("rubble"); frames(2)
print("主线进度", S.data.story, "碎片", S.data.shards, "信用点", S.data.credits)
assert(S.data.story == 1, "主线 1 应在晶矿前哨完成")
-- 召唤与船坞
S.data.shards = 20; S.data.credits = 60000
click("舰员召唤"); click("召唤"); click("欢迎加入"); click("召唤"); click("欢迎加入")
print("舰员", table.concat(S.data.crew, ","))
assert(#S.data.crew == 3)
click("船坞"); click("28,000 换购")
assert(S.data.ship == "ship_redhawk", "应换购赤隼号")
click("5,000 升级")
assert(S.data.laser == "laser2")
click("起飞"); frames(10)
assert(W.player.model == "ship_redhawk", "起飞后应换成新船模型")
-- 采矿
local ore = Space.ByKind("ore")
p = W.player; p.throttle = 0; p.speed = 0
ore.pos = U.add(p.pos, U.mul(U.fwdOf(p.yaw, p.pitch), 90)); W.target = nil
t = 0
while Space.Alive(ore) and t < 900 do Space.input.fire = true; frames(1); t = t + 1 end
Space.input.fire = false
local pods = 0
for _, x in ipairs(W.ents) do if x.kind == "loot" then pods = pods + 1; x.pos = U.copy(W.player.pos) end end
frames(5)
print(string.format("采矿用时 %.1f 秒，掉落 %d 个货舱，货舱矿石 %d", t / 30, pods, S.data.cargo.ore or 0))
assert(pods >= 2)
-- 首领战
S.data.story = 2
S.data.active = { id = "story3", kind = "boss", title = "赤髑的巢穴", system = "redring", reward = 10000, shards = 5, story = true, progress = 0, giver = "rubble" }
Game.Jump("redring"); frames(30)
local boss
for _, x in ipairs(W.ents) do if x.boss then boss = x end end
assert(boss, "赤环星系应出现赤髑号")
boss.hull, boss.shield = 1, 0
p = W.player
boss.pos = U.add(p.pos, U.mul(U.fwdOf(p.yaw, p.pitch), 80)); W.target = boss
t = 0
while Space.Alive(boss) and t < 300 do Space.input.fire = true; frames(1); t = t + 1 end
Space.input.fire = false
assert(S.data.active.progress == 1, "击沉赤髑号后任务应达成")
Game.Dock("redring")
print("主线进度", S.data.story)
assert(S.data.story == 3)
-- 被击毁
click("起飞"); frames(5)
W.player.shield = 0; W.player.hull = 1
for _, x in ipairs(W.ents) do if x.kind == "pirate" then x.pos = U.copy(W.player.pos) end end
frames(90)
assert(Game.GetMode() == "dead", "应进入被击毁状态, 当前 " .. Game.GetMode())
click("在 琥珀贸易站 重新出发")
assert(Game.GetMode() == "station")
-- 存档读回
S.Write()
local loaded = S.Load()
assert(loaded.ship == "ship_redhawk" and loaded.story == 3, "存档应能读回")
-- 图鉴
click("起飞"); Game.OpenPause(); click("保存并回到标题"); click("资产图鉴"); frames(10); render()
click("返回标题")
-- 屏幕变化
W, H = 2360, 1640; frames(3)
print(string.format("通过：克隆节点 %d 次，生成顶点 %d 个，NanoVG 调用 %d 次，存档写入 %d 次",
    calls.clones, calls.vertices, calls.nvg, calls.writes))
