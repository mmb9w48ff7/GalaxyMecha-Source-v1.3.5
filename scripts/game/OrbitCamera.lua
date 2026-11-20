-- OrbitCamera.lua
-- 预览用环绕相机：拖动旋转、滚轮 / 双指缩放。
-- 相机位置 = target + dist * (sin(yaw)cos(pitch), sin(pitch), cos(yaw)cos(pitch))
-- yaw = 0 时相机位于目标 +Z 方向，正对模型正面（模型统一面朝 +Z）。
-- 拖动灵敏度按 UI 缩放归一化：同样的设计像素位移得到同样的旋转角（与 HTML 预览一致）。

local Layout = require("game.Layout")

local OrbitCamera = {}
OrbitCamera.__index = OrbitCamera

local DEG_PER_DESIGN_PX = 0.125

function OrbitCamera.New(scene)
    local self = setmetatable({}, OrbitCamera)
    self.node = scene:CreateChild("PreviewCamera")
    self.camera = self.node:CreateComponent("Camera")
    self.camera.nearClip = 0.1
    self.camera.farClip = 800.0
    self.cfg = nil
    self.home = nil
    self.dragging = false
    self.touches = {}
    self.pinchDist = nil
    self.pinchStart = nil
    return self
end

function OrbitCamera:Configure(cfg)
    local function copy(c)
        return {
            target = { c.target[1], c.target[2], c.target[3] },
            yaw = c.yaw, pitch = c.pitch, dist = c.dist, fov = c.fov,
            minDist = c.minDist, maxDist = c.maxDist, minPitch = c.minPitch, maxPitch = c.maxPitch,
        }
    end
    self.cfg = copy(cfg)
    self.home = copy(cfg)
    self.dragging = false
    self.touches = {}
    self.pinchDist = nil
    self:Apply()
end

function OrbitCamera:Reset()
    if self.home then
        self:Configure(self.home)
    end
end

function OrbitCamera:Clamp()
    local c = self.cfg
    c.pitch = math.max(c.minPitch, math.min(c.maxPitch, c.pitch))
    c.dist = math.max(c.minDist, math.min(c.maxDist, c.dist))
end

function OrbitCamera:GetEye()
    local c = self.cfg
    local cp = math.cos(math.rad(c.pitch))
    return Vector3(
        c.target[1] + c.dist * math.sin(math.rad(c.yaw)) * cp,
        c.target[2] + c.dist * math.sin(math.rad(c.pitch)),
        c.target[3] + c.dist * math.cos(math.rad(c.yaw)) * cp)
end

function OrbitCamera:Apply()
    local c = self.cfg
    if not c then return end
    local L = Layout.Compute()
    self.camera.fov = Layout.FitFov(c.fov, L.aspect)
    self.node.position = self:GetEye()
    self.node:LookAt(Vector3(c.target[1], c.target[2], c.target[3]))
end

function OrbitCamera:Rotate(dxPhys, dyPhys, uiScale)
    local k = DEG_PER_DESIGN_PX / math.max(0.15, uiScale)
    self.cfg.yaw = self.cfg.yaw + dxPhys * k
    self.cfg.pitch = self.cfg.pitch + dyPhys * k
    self:Clamp()
end

-- pointerOverUI：由 UI 库判断指针是否落在面板上，落在面板上时不旋转相机
function OrbitCamera:Update(dt, pointerOverUI)
    if not self.cfg then return end
    local uiScale = Layout.Compute().scale
    local n = input.numTouches
    if n > 0 then
        -- 触摸：单指旋转，双指缩放（有触摸时忽略模拟鼠标事件，避免重复旋转）
        local seen = {}
        local pts = {}
        for i = 0, n - 1 do
            local tch = input:GetTouch(i)
            local id = tch.touchID
            local x, y = tch.position.x, tch.position.y
            seen[id] = true
            pts[#pts + 1] = { x, y }
            local prev = self.touches[id]
            if prev == nil then
                self.touches[id] = { x = x, y = y, active = not pointerOverUI }
            else
                if n == 1 and prev.active then
                    self:Rotate(x - prev.x, y - prev.y, uiScale)
                end
                prev.x, prev.y = x, y
            end
        end
        for id in pairs(self.touches) do
            if not seen[id] then self.touches[id] = nil end
        end
        if n >= 2 then
            local d = math.sqrt((pts[1][1] - pts[2][1]) ^ 2 + (pts[1][2] - pts[2][2]) ^ 2)
            if not self.pinchDist then
                self.pinchDist, self.pinchStart = d, self.cfg.dist
            else
                self.cfg.dist = self.pinchStart * self.pinchDist / math.max(10, d)
                self:Clamp()
            end
        else
            self.pinchDist = nil
        end
    else
        self.touches = {}
        self.pinchDist = nil
        if input:GetMouseButtonPress(MOUSEB_LEFT) then
            self.dragging = not pointerOverUI
        end
        if not input:GetMouseButtonDown(MOUSEB_LEFT) then
            self.dragging = false
        end
        if self.dragging then
            self:Rotate(input.mouseMoveX, input.mouseMoveY, uiScale)
        end
        local wheel = input.mouseWheelMove
        if wheel ~= 0 and not pointerOverUI then
            self.cfg.dist = self.cfg.dist * (1 - (wheel > 0 and 1 or -1) * 0.08)
            self:Clamp()
        end
        if input:GetKeyPress(KEY_R) then
            self:Reset()
        end
    end
    self:Apply()
end

return OrbitCamera
