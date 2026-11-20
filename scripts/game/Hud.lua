-- Hud.lua
-- 飞行 HUD：状态条、任务行、目标信息、油门滑条、虚拟摇杆、动作按钮、
-- 以及 NanoVG 叠加层（准星、目标框、屏幕外箭头、雷达）。布局与 HTML 版相同（1920x1080 设计像素）。

local UI = require("urhox-libs/UI")
local G = require("voxeldata.GameData")
local U = require("game.Util")
local S = require("game.Save")
local Space = require("game.Space")
local Theme = require("game.Theme")
local PixelIcon = require("game.PixelIcon")
local SCENES = require("voxeldata.Scenes")

local C, PAD = Theme.C, Theme.PAD
local Hud = {}
local refs_ = {}
local actions_ = {}
local tick_ = 0

-- ---------------------------------------------------------------- 叠加层：准星 / 目标框 / 箭头
local Overlay = UI.Widget:Extend("FlightOverlay")
function Overlay:Init(props) props.pointerEvents = "none"; UI.Widget.Init(self, props) end
function Overlay:Render(nvg)
    local W = Space.W
    local p = W.player
    if not p or not Space.cam.pos then return end
    local camera = Space.GetCamera()
    local l = self:GetAbsoluteLayout()
    local eye, ct = Space.cam.pos, Space.cam.target
    local cf = U.norm(U.sub(ct, eye))
    local st = S.Stats()
    local function Project(pos)
        if U.dot(U.sub(pos, eye), cf) <= 0.5 then return nil end
        local v = camera:WorldToScreenPoint(U.V3(pos))
        return l.x + v.x * l.w, l.y + v.y * l.h, U.dist(pos, eye)
    end
    -- 准星
    local ax, ay = Project(U.add(p.pos, U.mul(U.fwdOf(p.yaw, p.pitch), 300)))
    if ax then
        nvgBeginPath(nvg)
        local a = 22
        nvgMoveTo(nvg, ax - a, ay); nvgLineTo(nvg, ax - a / 3, ay); nvgMoveTo(nvg, ax + a / 3, ay); nvgLineTo(nvg, ax + a, ay)
        nvgMoveTo(nvg, ax, ay - a); nvgLineTo(nvg, ax, ay - a / 3); nvgMoveTo(nvg, ax, ay + a / 3); nvgLineTo(nvg, ax, ay + a)
        nvgStrokeColor(nvg, nvgRGBA(237, 230, 214, 220)); nvgStrokeWidth(nvg, 3); nvgStroke(nvg)
    end
    nvgFontFace(nvg, UI.Theme.FontFace("sans", "bold"))
    nvgFontSize(nvg, 22)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    for _, e in ipairs(W.ents) do
        local nav = e.kind == "station" or e.kind == "gate" or e.kind == "base"
        local enemy, loot = e.kind == "pirate", e.kind == "loot"
        local d = U.dist(e.pos, p.pos)
        if (nav or enemy or loot) and not ((enemy or loot) and d > st.radar) then
            local isT = e == W.target
            local col = enemy and C.danger or (loot and C.teal or (isT and C.amber or { 237, 230, 214, 190 }))
            local sx, sy, sd = Project(e.pos)
            if not sx or sx < l.x or sx > l.x + l.w or sy < l.y or sy > l.y + l.h then
                if isT then
                    -- 屏幕外目标：边缘箭头
                    local rel = U.sub(e.pos, p.pos)
                    local r = U.rightOf(p.yaw)
                    local up = { math.sin(p.yaw * U.DEG) * math.sin(p.pitch * U.DEG), math.cos(p.pitch * U.DEG), math.cos(p.yaw * U.DEG) * math.sin(p.pitch * U.DEG) }
                    local ang = math.atan(-U.dot(rel, up), U.dot(rel, r))
                    local R = math.min(l.w, l.h) * 0.38
                    local ex, ey = l.x + l.w / 2 + math.cos(ang) * R, l.y + l.h / 2 + math.sin(ang) * R
                    nvgSave(nvg); nvgTranslate(nvg, ex, ey); nvgRotate(nvg, ang)
                    nvgBeginPath(nvg); nvgMoveTo(nvg, 22, 0); nvgLineTo(nvg, -12, -14); nvgLineTo(nvg, -12, 14); nvgClosePath(nvg)
                    nvgFillColor(nvg, nvgRGBA(col[1], col[2], col[3], 255)); nvgFill(nvg); nvgRestore(nvg)
                end
            elseif loot then
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, sx, sy - 11); nvgLineTo(nvg, sx + 11, sy); nvgLineTo(nvg, sx, sy + 11); nvgLineTo(nvg, sx - 11, sy); nvgClosePath(nvg)
                nvgStrokeColor(nvg, nvgRGBA(col[1], col[2], col[3], 255)); nvgStrokeWidth(nvg, 3); nvgStroke(nvg)
            else
                local size = U.clamp(e.radius * 900 / math.max(1, sd) * 1.2, 16, 140)
                local k = size * 0.35
                nvgBeginPath(nvg)
                for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
                    local x, y = sx + q[1] * size, sy + q[2] * size
                    nvgMoveTo(nvg, x, y - q[2] * k); nvgLineTo(nvg, x, y); nvgLineTo(nvg, x - q[1] * k, y)
                end
                nvgStrokeColor(nvg, nvgRGBA(col[1], col[2], col[3], 255)); nvgStrokeWidth(nvg, isT and 4 or 3); nvgStroke(nvg)
                if nav or isT then
                    nvgFillColor(nvg, nvgRGBA(col[1], col[2], col[3], 255))
                    nvgText(nvg, sx, sy + size + 8, (e.name or "") .. "  " .. U.fmt(d) .. " 米")
                end
                if isT and enemy then
                    local lx, ly = Project(U.add(e.pos, U.mul(e.vel, d / G.tuning.laserSpeed)))
                    if lx then
                        nvgBeginPath(nvg); nvgCircle(nvg, lx, ly, 10)
                        nvgStrokeColor(nvg, nvgRGBA(col[1], col[2], col[3], 255)); nvgStroke(nvg)
                    end
                end
            end
        end
    end
end

-- ---------------------------------------------------------------- 雷达
local Radar = UI.Widget:Extend("Radar")
function Radar:Init(props) props.pointerEvents = "none"; UI.Widget.Init(self, props) end
function Radar:Render(nvg)
    local W = Space.W
    local p = W.player
    if not p then return end
    local l = self:GetAbsoluteLayout()
    local R, cx, cy = l.w / 2, l.x + l.w / 2, l.y + l.h / 2
    local st = S.Stats()
    nvgBeginPath(nvg); nvgCircle(nvg, cx, cy, R)
    nvgFillColor(nvg, nvgRGBA(9, 12, 34, 185)); nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(92, 242, 220, 130)); nvgStrokeWidth(nvg, 2); nvgStroke(nvg)
    nvgBeginPath(nvg); nvgCircle(nvg, cx, cy, R * 0.5); nvgStroke(nvg)
    nvgBeginPath(nvg); nvgMoveTo(nvg, cx, cy - 9); nvgLineTo(nvg, cx + 7, cy + 7); nvgLineTo(nvg, cx - 7, cy + 7); nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(245, 165, 36, 255)); nvgFill(nvg)
    local rr = U.rightOf(p.yaw)
    local ff = { math.sin(p.yaw * U.DEG), 0, math.cos(p.yaw * U.DEG) }
    local colors = { pirate = C.danger, loot = C.teal, station = C.amber, gate = { 157, 247, 236, 255 }, base = { 255, 77, 106, 255 } }
    for _, e in ipairs(W.ents) do
        local col = colors[e.kind]
        if col then
            local rel = U.sub(e.pos, p.pos)
            local x, z = U.dot(rel, rr) / st.radar, U.dot(rel, ff) / st.radar
            local len = math.sqrt(x * x + z * z)
            local show = true
            if len > 1 then
                if e.kind == "pirate" or e.kind == "loot" then show = false else x, z = x / len, z / len end
            end
            if show then
                local sz = (e.kind == "station" or e.kind == "gate" or e.kind == "base") and 7 or 4.5
                nvgBeginPath(nvg); nvgRect(nvg, cx + x * R - sz / 2, cy - z * R - sz / 2, sz, sz)
                nvgFillColor(nvg, nvgRGBA(col[1], col[2], col[3], 255)); nvgFill(nvg)
            end
        end
    end
end

-- ---------------------------------------------------------------- 摇杆
local Joystick = UI.Widget:Extend("Joystick")
function Joystick:Init(props)
    self.active_, self.cx_, self.cy_, self.dx_, self.dy_ = false, 0, 0, 0, 0
    local me = self
    props.onPointerDown = function(event) me.active_ = true; me.cx_, me.cy_ = event.x, event.y; me.dx_, me.dy_ = 0, 0 end
    props.onPointerMove = function(event)
        if not me.active_ then return end
        local dx, dy = event.x - me.cx_, event.y - me.cy_
        local len, R = math.sqrt(dx * dx + dy * dy), 130
        if len > R then dx, dy = dx / len * R, dy / len * R end
        me.dx_, me.dy_ = dx, dy
        Space.input.sx, Space.input.sy = dx / R, -dy / R
    end
    props.onPointerUp = function() me:Release() end
    UI.Widget.Init(self, props)
end
function Joystick:Release()
    self.active_ = false; self.dx_, self.dy_ = 0, 0
    Space.input.sx, Space.input.sy = 0, 0
end
function Joystick:Render(nvg)
    local l = self:GetAbsoluteLayout()
    local cx, cy = l.x + 230, l.y + 380
    if self.active_ then cx, cy = self.cx_, self.cy_ end
    nvgBeginPath(nvg); nvgRect(nvg, cx - 130, cy - 130, 260, 260)
    nvgFillColor(nvg, nvgRGBA(9, 12, 34, 115)); nvgFill(nvg)
    local sc = self.active_ and C.teal or { 163, 171, 207, 115 }
    nvgStrokeColor(nvg, nvgRGBA(sc[1], sc[2], sc[3], sc[4] or 255)); nvgStrokeWidth(nvg, 6); nvgStroke(nvg)
    nvgBeginPath(nvg); nvgRect(nvg, cx + self.dx_ - 60, cy + self.dy_ - 60, 120, 120)
    nvgFillColor(nvg, nvgRGBA(237, 230, 214, 140)); nvgFill(nvg)
end

-- ---------------------------------------------------------------- 油门
local Throttle = UI.Widget:Extend("Throttle")
function Throttle:Init(props)
    local me = self
    local function Set(event)
        local l = me:GetAbsoluteLayout()
        if Space.W.player then Space.W.player.throttle = U.clamp(1 - (event.y - l.y) / l.h, 0, 1) end
    end
    props.onPointerDown = function(event) me.drag_ = true; Set(event) end
    props.onPointerMove = function(event) if me.drag_ then Set(event) end end
    props.onPointerUp = function() me.drag_ = false end
    UI.Widget.Init(self, props)
end
function Throttle:Render(nvg)
    local l = self:GetAbsoluteLayout()
    local v = Space.W.player and Space.W.player.throttle or 0
    nvgBeginPath(nvg); nvgRect(nvg, l.x, l.y, l.w, l.h)
    nvgFillColor(nvg, nvgRGBA(9, 12, 34, 190)); nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(52, 64, 122, 255)); nvgStrokeWidth(nvg, 4); nvgStroke(nvg)
    local h = (l.h - 16) * v
    nvgBeginPath(nvg); nvgRect(nvg, l.x + 8, l.y + l.h - 8 - h, l.w - 16, h)
    nvgFillColor(nvg, nvgRGBA(245, 165, 36, 205)); nvgFill(nvg)
    nvgBeginPath(nvg); nvgRect(nvg, l.x - 14, l.y + l.h - 8 - h - 18, l.w + 28, 36)
    nvgFillColor(nvg, nvgRGBA(237, 230, 214, 255)); nvgFill(nvg)
end

-- ---------------------------------------------------------------- 组装
local function HoldButton(label, style, onDown, onUp)
    local props = {
        position = "absolute", justifyContent = "center", alignItems = "center",
        backgroundColor = style.bg or { 24, 30, 66, 217 },
        borderTopWidth = 5, borderTopColor = style.hi or C.hi, borderBottomWidth = 8, borderBottomColor = style.lo or C.lo,
        children = { Theme.Text(label, style.fontSize or 30, style.fg or C.bone, true) },
        onPointerDown = function() onDown() end,
        onPointerUp = function() if onUp then onUp() end end,
    }
    for _, k in ipairs({ "right", "bottom", "width", "height" }) do props[k] = style[k] end
    return UI.Panel(props)
end

-- actions：{ missile, target, auto, interact, map, pause }
function Hud.Build(actions)
    actions_ = actions
    refs_ = {}
    local function StatRow(label, color)
        local fill = UI.Panel { width = "0%", height = "100%", backgroundColor = color }
        local row = UI.Panel { flexDirection = "row", alignItems = "center", gap = 14, marginBottom = 8, children = {
            Theme.Text(label, 24, C.muted, false, { width = 72 }),
            UI.Panel { flexGrow = 1, height = 22, backgroundColor = C.lo, children = { fill } },
        } }
        return row, fill
    end
    local shRow, shFill = StatRow("护盾", { 87, 184, 255, 255 })
    local hpRow, hpFill = StatRow("船体", C.hp)
    local boRow, boFill = StatRow("加速", C.amber)
    refs_.sh, refs_.hp, refs_.bo = shFill, hpFill, boFill
    refs_.spd = Theme.Text("", 26, C.bone)
    refs_.cr = Theme.Text("", 36, C.bone, true)
    refs_.sd = Theme.Text("", 36, C.teal, true)
    local status = Theme.VoxPanel {
        position = "absolute", left = PAD, top = 28, width = 500, paddingHorizontal = 24, paddingTop = 18, paddingBottom = 20,
        children = { shRow, hpRow, boRow, UI.Panel { flexDirection = "row", alignItems = "center", gap = 18, marginTop = 6, children = {
            refs_.spd, PixelIcon { icon = SCENES.resIcons.credit, width = 34, height = 34 }, refs_.cr,
            PixelIcon { icon = SCENES.resIcons.shard, width = 34, height = 34 }, refs_.sd } } },
    }
    refs_.sys = Theme.Text("", 46, C.amber, true, { textAlign = "center" })
    refs_.mis = Theme.Text("", 26, C.bone, false, { textAlign = "center", whiteSpace = "normal" })
    local obj = UI.Panel { position = "absolute", left = 0, right = 0, top = 26, alignItems = "center", pointerEvents = "none",
        children = { UI.Panel { width = 760, alignItems = "center", children = { refs_.sys, refs_.mis } } } }
    refs_.tName = Theme.Text("", 30, C.bone, true)
    refs_.tDist = Theme.Text("", 24, C.muted)
    refs_.tSh = UI.Panel { width = "0%", height = "100%", backgroundColor = { 87, 184, 255, 255 } }
    refs_.tHp = UI.Panel { width = "0%", height = "100%", backgroundColor = C.danger }
    refs_.tBars = UI.Panel { width = "100%", children = {
        UI.Panel { width = "100%", height = 16, marginTop = 6, backgroundColor = C.lo, children = { refs_.tSh } },
        UI.Panel { width = "100%", height = 16, marginTop = 6, backgroundColor = C.lo, children = { refs_.tHp } } } }
    refs_.target = Theme.VoxPanel { width = 460, alignItems = "center", paddingHorizontal = 22, paddingTop = 12, paddingBottom = 16, pointerEvents = "none",
        children = { refs_.tName, refs_.tDist, refs_.tBars } }
    local targetWrap = UI.Panel { position = "absolute", left = 0, right = 0, top = 150, alignItems = "center", pointerEvents = "none", children = { refs_.target } }
    local menu = UI.Panel { position = "absolute", right = PAD + 300, top = 28, flexDirection = "row", gap = 12, children = {
        Theme.Button({ text = "地图", fontSize = 28, style = { minHeight = 88, paddingHorizontal = 26 }, onClick = actions.map }),
        Theme.Button({ text = "暂停", fontSize = 28, style = { minHeight = 88, paddingHorizontal = 26 }, onClick = actions.pause }),
    } }
    local radar = Radar { position = "absolute", right = PAD + 20, top = 36, width = 240, height = 240 }
    local throttle = UI.Panel { position = "absolute", left = PAD, top = 330, bottom = 120, width = 104, alignItems = "center", gap = 10, children = {
        Theme.Text("油门", 24, C.muted), Throttle { width = 60, flexGrow = 1 } } }
    refs_.joy = Joystick { position = "absolute", left = 170, bottom = 0, width = 760, height = 640 }
    refs_.missileLabel = "导弹"
    local pad = UI.Panel { position = "absolute", right = PAD, bottom = 40, width = 560, height = 470, children = {
        HoldButton("开火", { right = 0, bottom = 0, width = 250, height = 250, fontSize = 42, bg = C.danger, hi = { 255, 140, 190, 255 }, lo = { 142, 31, 85, 255 }, fg = C.white },
            function() Space.input.fire = true end, function() Space.input.fire = false end),
        HoldButton("导弹", { right = 270, bottom = 0, width = 150, height = 150 }, actions.missile),
        HoldButton("加速", { right = 0, bottom = 270, width = 150, height = 150 }, function() Space.input.boost = true end, function() Space.input.boost = false end),
        HoldButton("目标", { right = 270, bottom = 170, width = 150, height = 110 }, actions.target),
        HoldButton("导航", { right = 170, bottom = 300, width = 150, height = 110 }, actions.auto),
    } }
    refs_.missiles = Theme.Text("", 30, C.teal, true)
    local misCount = UI.Panel { position = "absolute", right = PAD + 270, bottom = 40 + 18, width = 150, alignItems = "center", pointerEvents = "none", children = { refs_.missiles } }
    refs_.actText = Theme.Text("", 34, C.ink, true)
    refs_.act = UI.Panel { minWidth = 520, minHeight = 104, paddingHorizontal = 44, justifyContent = "center", alignItems = "center",
        backgroundColor = C.amber, borderTopWidth = 5, borderTopColor = C.amberHi, borderBottomWidth = 8, borderBottomColor = C.amberLo,
        children = { refs_.actText }, onClick = actions.interact }
    local actWrap = UI.Panel { position = "absolute", left = 0, right = 0, bottom = 150, alignItems = "center", pointerEvents = "box-none", children = { refs_.act } }
    local safe = UI.SafeAreaView { width = "100%", height = "100%", children = { UI.Panel { width = "100%", height = "100%", children = {
        refs_.joy, status, obj, targetWrap, menu, radar, throttle, pad, misCount, actWrap } } } }
    return UI.Panel { width = "100%", height = "100%", children = {
        Overlay { position = "absolute", left = 0, top = 0, right = 0, bottom = 0 }, safe } }
end

local function SetPct(w, v) w:SetStyle({ width = string.format("%d%%", math.floor(U.clamp(v, 0, 1) * 100 + 0.5)) }) end

function Hud.Update(dt, missionLine)
    local W = Space.W
    local p = W.player
    if not p or not refs_.sh then return end
    local st = S.Stats()
    -- 指针全部抬起时的兜底释放（防止抬起事件落在按钮外导致持续开火）
    if input.numTouches == 0 and not input:GetMouseButtonDown(MOUSEB_LEFT) then
        Space.input.fire, Space.input.boost = false, false
        if refs_.joy.active_ then refs_.joy:Release() end
    end
    tick_ = tick_ - dt
    if tick_ > 0 then return end
    tick_ = 0.12
    SetPct(refs_.sh, p.shield / st.shieldMax); SetPct(refs_.hp, p.hull / st.hullMax); SetPct(refs_.bo, p.boost / 100)
    refs_.spd:SetText("航速 " .. math.floor(p.speed + 0.5) .. " 米/秒")
    refs_.cr:SetText(U.fmt(S.data.credits))
    refs_.sd:SetText(tostring(S.data.shards))
    refs_.missiles:SetText(tostring(S.data.missiles))
    refs_.sys:SetText(W.sys.name)
    refs_.mis:SetText(missionLine)
    local t = W.target
    if t and not Space.Alive(t) then W.target = nil; t = nil end
    refs_.target:SetVisible(t ~= nil)
    if t then
        refs_.tName:SetText(t.name or "")
        refs_.tDist:SetText(U.fmt(U.dist(t.pos, p.pos)) .. " 米")
        refs_.tBars:SetVisible(t.kind == "pirate")
        if t.kind == "pirate" then SetPct(refs_.tSh, t.shield / t.def.shield); SetPct(refs_.tHp, t.hull / t.def.hull) end
    end
    local it = Space.Interactable()
    refs_.act:SetVisible(it ~= nil)
    if it then
        refs_.actText:SetText(it.kind == "station" and ("停靠 " .. it.name) or ("跃迁 " .. S.SysById(it.to).name))
    end
end

return Hud
