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
local NVG = {}; local function ser(v) if type(v) == "table" then local o = {}; for i = 1, 4 do o[i] = v[i] end return o end return v end
local function rec(name) _G[name] = function(...) local a = { ... }; local o = { name }; for i = 2, select("#", ...) do o[#o + 1] = ser(a[i]) end NVG[#NVG + 1] = o end end
function nvgRadialGradient() return {} end
function nvgCreate() return {} end
function nvgCreateFont() return 1 end
function nvgRGBA(r, g, b, a) return { r, g, b, a } end
for _, fn in ipairs({ "nvgSave", "nvgRestore", "nvgScale", "nvgTranslate", "nvgRotate", "nvgBeginPath", "nvgRect", "nvgRoundedRect", "nvgCircle", "nvgArc", "nvgFillColor", "nvgFill", "nvgStrokeColor", "nvgStrokeWidth", "nvgStroke", "nvgFontFace", "nvgFontSize", "nvgTextAlign", "nvgText", "nvgTextBox", "nvgMoveTo", "nvgLineTo", "nvgClosePath", "nvgTextLineHeight", "nvgScissor", "nvgResetScissor", "nvgFontBlur", "nvgTextLetterSpacing", "nvgFillPaint" }) do rec(fn) end
function nvgBeginFrame() NVG = {}; NVG_CUR = NVG end
function nvgEndFrame() end
local function jstr(s) return '"' .. s:gsub('[%c"\\]', function(c) local m = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }; return m[c] or "" end) .. '"' end
function DUMP(path) local f = io.open(path, "w"); local parts = {}
    for _, c in ipairs(NVG) do local t = {}; for i, v in ipairs(c) do if type(v) == "table" then t[i] = "[" .. table.concat(v, ",") .. "]" elseif type(v) == "string" then t[i] = jstr(v) else t[i] = tostring(v) end end parts[#parts + 1] = "[" .. table.concat(t, ",") .. "]" end
    f:write("[" .. table.concat(parts, ",\n") .. "]"); f:close() end
local handlers = {}; function SubscribeToEvent(name, fn) handlers[name] = fn end
sdk = nil
