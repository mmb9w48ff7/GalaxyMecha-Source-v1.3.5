-- Theme.lua
-- 体素风 UI 配色与通用控件（与 HTML 版 CSS 变量一致）。
local UI = require("urhox-libs/UI")

local Theme = {}
Theme.PAD = 36
Theme.C = {
    panel = { 24, 30, 66, 230 }, hi = { 52, 64, 122, 255 }, lo = { 9, 12, 34, 255 }, rowBg = { 9, 12, 34, 150 },
    amber = { 245, 165, 36, 255 }, amberHi = { 255, 210, 122, 255 }, amberLo = { 168, 106, 6, 255 },
    ink = { 42, 26, 0, 255 }, teal = { 92, 242, 220, 255 }, tealInk = { 6, 42, 39, 255 },
    danger = { 224, 69, 140, 255 }, bone = { 237, 230, 214, 255 }, muted = { 163, 171, 207, 255 },
    text2 = { 210, 214, 234, 255 }, hp = { 124, 242, 154, 255 }, white = { 255, 255, 255, 255 },
    shade = { 5, 6, 15, 210 },
}
local C = Theme.C

function Theme.Text(text, size, color, bold, extra)
    local props = { text = text, fontSize = size, fontColor = color or C.bone, fontFamily = "sans", fontWeight = bold and "bold" or "normal" }
    if extra then for k, v in pairs(extra) do props[k] = v end end
    return UI.Label(props)
end

function Theme.VoxPanel(props)
    props.backgroundColor = props.backgroundColor or C.panel
    props.borderTopWidth = 5; props.borderTopColor = C.hi
    props.borderLeftWidth = 5; props.borderLeftColor = C.hi
    props.borderRightWidth = 5; props.borderRightColor = C.lo
    props.borderBottomWidth = 7; props.borderBottomColor = C.lo
    props.borderRadius = props.borderRadius or 4
    return UI.Panel(props)
end

function Theme.Tag(text, bg, fg)
    return UI.Panel { alignSelf = "flex-start", paddingHorizontal = 14, paddingVertical = 2, backgroundColor = bg or C.hi,
        children = { Theme.Text(text, 24, fg or C.bone, true) } }
end

-- opts: text, note, primary, alt, fontSize, style, onClick, disabled
function Theme.Button(opts)
    local primary = opts.primary
    local fg = primary and C.ink or C.bone
    local children = { Theme.Text(opts.text, opts.fontSize or 34, fg, true) }
    if opts.note then children[#children + 1] = Theme.Text(opts.note, 22, fg, false) end
    local props = {
        justifyContent = "center", alignItems = "center", paddingHorizontal = 30,
        backgroundColor = opts.bg or (primary and C.amber or C.hi),
        borderTopWidth = 5, borderTopColor = primary and C.amberHi or { 80, 92, 150, 255 },
        borderBottomWidth = 8, borderBottomColor = primary and C.amberLo or C.lo,
        opacity = opts.disabled and 0.4 or 1,
        children = children,
        onClick = (not opts.disabled) and opts.onClick or nil,
    }
    for k, v in pairs(opts.style or {}) do props[k] = v end
    return UI.Panel(props)
end

function Theme.Mini(text, onClick, alt, disabled)
    return Theme.Button({ text = text, fontSize = 26, primary = not alt, disabled = disabled, onClick = onClick,
        style = { minHeight = 64, paddingHorizontal = 20 } })
end

function Theme.Bar(value, color, height)
    return UI.Panel { width = "100%", height = height or 16, backgroundColor = C.lo, marginTop = 6,
        children = { UI.Panel { width = string.format("%d%%", math.floor(math.max(0, math.min(1, value)) * 100 + 0.5)), height = "100%", backgroundColor = color } } }
end

return Theme
