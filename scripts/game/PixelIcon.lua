-- PixelIcon.lua
-- 体素像素图标控件：绘制构建脚本从模型正视图 / 侧视图生成的像素图（Catalog.lua 中的 icon 字段）。
-- 同色像素合并到一条路径里填充，减少 NanoVG 调用。

local UI = require("urhox-libs/UI")

local PixelIcon = UI.Widget:Extend("PixelIcon")

local B36 = "0123456789abcdefghijklmnopqrstuvwxyz"

local function HexToRGB(hex)
    local h = hex:gsub("#", "")
    return tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)
end

-- 预处理：把像素按调色板分组成 { {r,g,b, cells = {i, j, i, j, ...}}, ... }
local function Prepare(icon)
    local groups = {}
    for pi, hex in ipairs(icon.pal) do
        local r, g, b = HexToRGB(hex)
        groups[pi] = { r = r, g = g, b = b, cells = {} }
    end
    local w, h, px = icon.w, icon.h, icon.px
    for j = 0, h - 1 do
        for i = 0, w - 1 do
            local ch = px:sub(j * w + i + 1, j * w + i + 1)
            if ch ~= "." then
                local idx = B36:find(ch, 1, true)
                local cells = groups[idx].cells
                cells[#cells + 1] = i
                cells[#cells + 1] = j
            end
        end
    end
    return groups
end

function PixelIcon:Init(props)
    props = props or {}
    self.icon_ = props.icon
    self.groups_ = props.icon and Prepare(props.icon) or {}
    props.pointerEvents = "none"
    UI.Widget.Init(self, props)
end

function PixelIcon:Render(nvg)
    local icon = self.icon_
    if not icon then return end
    local l = self:GetAbsoluteLayout()
    local cell = math.min(l.w / icon.w, l.h / icon.h)
    local ox = l.x + (l.w - cell * icon.w) * 0.5
    local oy = l.y + (l.h - cell * icon.h) * 0.5
    for _, g in ipairs(self.groups_) do
        if #g.cells > 0 then
            nvgBeginPath(nvg)
            for k = 1, #g.cells, 2 do
                nvgRect(nvg, ox + g.cells[k] * cell, oy + g.cells[k + 1] * cell, cell + 0.5, cell + 0.5)
            end
            nvgFillColor(nvg, nvgRGBA(g.r, g.g, g.b, 255))
            nvgFill(nvg)
        end
    end
end

return PixelIcon
