-- Layout.lua
-- 设计分辨率适配：横屏 1920x1080 为基准。
--   UI 缩放 = min(物理宽/1920, 物理高/1080)，UI 代码里全部使用设计像素。
--   屏幕比 16:9 更宽（19.5:9、20:9）时，逻辑宽度 > 1920，UI 贴边布局，多出的空间留给 3D 场景。
--   屏幕比 16:9 更方（4:3 平板）时，逻辑高度 > 1080，同时放大相机竖直 FOV，保证水平视野不被裁切。
-- 与 preview/src/app.js 中的 layout() / fitFov() 完全一致。

local Layout = {}

Layout.DESIGN_W = 1920
Layout.DESIGN_H = 1080
Layout.DESIGN_ASPECT = Layout.DESIGN_W / Layout.DESIGN_H

function Layout.Compute()
    local w, h = graphics:GetWidth(), graphics:GetHeight()
    if w <= 0 or h <= 0 then
        w, h = Layout.DESIGN_W, Layout.DESIGN_H
    end
    local s = math.min(w / Layout.DESIGN_W, h / Layout.DESIGN_H)
    return {
        physW = w, physH = h,
        scale = s,                 -- 物理像素 / 设计像素
        logicalW = w / s,          -- 设计像素下的可用宽度（>= 1920 或 高度 >= 1080）
        logicalH = h / s,
        aspect = w / h,
        dpr = graphics:GetDPR(),
    }
end

-- 竖直 FOV 适配：宽屏保持设计 FOV，窄屏按 16:9 的水平视野反推
function Layout.FitFov(fov, aspect)
    if aspect >= Layout.DESIGN_ASPECT then
        return fov
    end
    local half = math.rad(fov) * 0.5
    return math.deg(2 * math.atan(math.tan(half) * Layout.DESIGN_ASPECT / aspect))
end

return Layout
