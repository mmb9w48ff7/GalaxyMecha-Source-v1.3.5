-- Game.lua
-- 游戏流程控制：标题、飞行、星港（交易所 / 任务板 / 船坞 / 舰员召唤）、星图、暂停、被击毁、图鉴。
-- 逻辑与 HTML 版 game.js 一致。

local UI = require("urhox-libs/UI")
local G = require("voxeldata.GameData")
local CATALOG = require("voxeldata.Catalog")
local U = require("game.Util")
local S = require("game.Save")
local Space = require("game.Space")
local Hud = require("game.Hud")
local Theme = require("game.Theme")
local PixelIcon = require("game.PixelIcon")
local World = require("game.PreviewWorld")
local SCENES = require("voxeldata.Scenes")

local C, PAD = Theme.C, Theme.PAD
local Game = {}
local mode_ = "title"
local stationTab_ = "trade"
local sideMissions_ = {}
local toastBox_, toastLabel_, toastTime_ = nil, nil, 0
local hitTime_ = 0
local deadTimer_ = 0
local warpTimer_, warpTo_, warpFrom_ = 0, nil, nil
local autosave_ = 15
local gallery_ = { id = CATALOG.items[1].id, cat = CATALOG.items[1].category }

local function CatIcon(id, w, h)
    local it = U.byId(CATALOG.items, id)
    if not it then return UI.Panel { width = w, height = h } end
    return PixelIcon { icon = it.icon, width = w, height = h }
end

-- ---------------------------------------------------------------- 根节点与提示
local function SetRoot(content)
    toastLabel_ = Theme.Text("", 28, C.bone, false, { whiteSpace = "normal", textAlign = "center" })
    toastBox_ = UI.Panel { maxWidth = 1200, paddingHorizontal = 28, paddingVertical = 12, backgroundColor = { 9, 12, 34, 225 },
        borderLeftWidth = 6, borderLeftColor = C.teal, pointerEvents = "none", children = { toastLabel_ } }
    toastBox_:SetVisible(toastTime_ > 0)
    local root = UI.Panel { width = "100%", height = "100%", children = {
        content,
        UI.Panel { position = "absolute", left = 0, right = 0, top = 235, alignItems = "center", pointerEvents = "none", children = { toastBox_ } },
    } }
    UI.SetRoot(root, true)
end

function Game.Toast(msg)
    print("[提示] " .. msg)
    toastTime_ = 2.6
    if toastLabel_ then toastLabel_:SetText(msg); toastBox_:SetVisible(true) end
end

local function Safe(children)
    return UI.SafeAreaView { width = "100%", height = "100%", children = { UI.Panel { width = "100%", height = "100%", children = children } } }
end

-- ---------------------------------------------------------------- 任务
local function MissionLine()
    local m = S.data.active
    if not m then
        if S.data.story < #G.story then
            local sm = G.story[S.data.story + 1]
            return "主线：前往 " .. S.StationById(sm.giver).name .. " 接取「" .. sm.title .. "」"
        end
        return "自由航行：跑商、采矿、清剿海贼"
    end
    if m.kind == "deliver" then
        local st, sys = S.StationById(m.target)
        return m.title .. "：把 " .. m.count .. " 箱" .. U.byId(G.goods, m.good).name .. "送到 " .. st.name .. "（" .. sys.name .. "）"
    elseif m.kind == "bounty" then
        return m.title .. "：在" .. S.SysById(m.system).name .. "击落海贼 " .. math.min(m.progress or 0, m.count) .. " / " .. m.count
    elseif m.kind == "mining" then
        return m.title .. "：带 " .. m.count .. " 箱矿石回 " .. S.StationById(m.giver).name .. "（货舱 " .. (S.data.cargo.ore or 0) .. "）"
    elseif m.kind == "boss" then
        return m.title .. "：" .. ((m.progress or 0) > 0 and "回到星港交付" or "前往赤环星系，击沉赤髑号")
    end
    return ""
end
Game.MissionLine = MissionLine

local function CompleteMission(m)
    S.data.credits = S.data.credits + m.reward
    S.data.shards = S.data.shards + (m.shards or 0)
    Game.Toast("任务完成：" .. m.title .. "，获得 " .. U.fmt(m.reward) .. " 信用点" .. ((m.shards or 0) > 0 and ("、陨石碎片 x" .. m.shards) or ""))
    if m.story then S.data.story = S.data.story + 1 end
    S.data.active = nil
end

local function CheckMissionOnDock(stId)
    local m = S.data.active
    if not m then return end
    local cargo = S.data.cargo
    if m.kind == "deliver" and m.target == stId and (cargo[m.good] or 0) >= m.count then
        S.AddCargo(m.good, -m.count); CompleteMission(m)
    elseif m.kind == "mining" and m.giver == stId and (cargo.ore or 0) >= m.count then
        S.AddCargo("ore", -m.count); CompleteMission(m)
    elseif (m.kind == "bounty" and (m.progress or 0) >= m.count) or (m.kind == "boss" and (m.progress or 0) > 0) then
        CompleteMission(m)
    end
end

local missionSeq_ = 0
local function GenSide(stId)
    local _, hereSys = S.StationById(stId)
    local others = {}
    for _, s in ipairs(G.systems) do for _, x in ipairs(s.stations) do if x.id ~= stId then others[#others + 1] = x end end end
    local tgt = others[math.random(#others)]
    local good = G.goods[math.random(4)]
    missionSeq_ = missionSeq_ + 1
    local out = {}
    out[1] = { id = "side-d-" .. missionSeq_, kind = "deliver", title = "加急货运", giver = stId, good = good.id, count = math.random(4, 8), target = tgt.id,
               provide = true, reward = 900 + math.random(0, 5) * 150, shards = 0,
               text = "商会需要把一批" .. good.name .. "送到 " .. tgt.name .. "，货物由我们提供。" }
    local bsys = hereSys.pirates.max > 0 and hereSys or S.SysById("rubble")
    out[2] = { id = "side-b-" .. missionSeq_, kind = "bounty", title = "清剿海贼", giver = stId, system = bsys.id, count = math.random(2, 4),
               reward = 1200 + math.random(0, 4) * 200, shards = math.random() < 0.4 and 1 or 0,
               text = "在" .. bsys.name .. "击落海贼船，回到这里领取赏金。" }
    out[3] = { id = "side-m-" .. missionSeq_, kind = "mining", title = "矿石订单", giver = stId, count = math.random(6, 12),
               reward = 700 + math.random(0, 5) * 120, shards = math.random() < 0.3 and 1 or 0,
               text = "工坊急需矿石。去小行星带击碎富矿小行星，带矿石回来。" }
    return out
end

local function AvailableMissions(stId)
    local list = {}
    if S.data.story < #G.story and G.story[S.data.story + 1].giver == stId then
        local m = {}
        for k, v in pairs(G.story[S.data.story + 1]) do m[k] = v end
        m.story = true
        list[#list + 1] = m
    end
    for _, m in ipairs(sideMissions_[stId] or {}) do list[#list + 1] = m end
    return list
end

local RenderStation

local function AcceptMission(m)
    if S.data.active then Game.Toast("先完成或放弃当前任务"); return end
    if m.provide then
        local room = S.Stats().cargoCap - S.CargoUsed()
        if room < m.count then Game.Toast("货舱空间不足，需要 " .. m.count .. " 格"); return end
        S.AddCargo(m.good, m.count)
    end
    local copy = {}
    for k, v in pairs(m) do copy[k] = v end
    copy.progress = 0
    S.data.active = copy
    if not m.story then
        local keep = {}
        for _, x in ipairs(sideMissions_[m.giver] or {}) do if x.id ~= m.id then keep[#keep + 1] = x end end
        sideMissions_[m.giver] = keep
    end
    Game.Toast("已接受任务：" .. m.title)
    S.Write(); RenderStation()
end

-- ---------------------------------------------------------------- 飞行
local function ResumeFlight()
    mode_ = "flight"
    Space.Activate()
    SetRoot(Hud.Build({
        missile = Space.FireMissile, target = Space.CycleTarget, auto = Space.ToggleAuto,
        interact = function() Game.Interact() end, map = function() Game.OpenMap() end, pause = function() Game.OpenPause() end,
    }))
end
Game.ResumeFlight = ResumeFlight

function Game.Interact()
    local e = Space.Interactable()
    if not e then return end
    if e.kind == "station" then Game.Dock(e.st.id) else Game.Jump(e.to) end
end

function Game.Jump(to)
    mode_ = "warp"
    warpTimer_, warpTo_, warpFrom_ = 0.65, to, Space.W.sys.id
    SetRoot(UI.Panel { width = "100%", height = "100%", backgroundColor = { 232, 255, 251, 235 } })
end

-- ---------------------------------------------------------------- 星港
function Game.Dock(stId)
    S.data.dockedAt = stId
    Space.W.auto = false
    local st = S.Stats()
    if st.fx.freeRepair > 0 then S.data.hullDmg = 0 end
    if Space.W.player then Space.W.player.hull = st.hullMax - S.data.hullDmg end
    CheckMissionOnDock(stId)
    if not sideMissions_[stId] then sideMissions_[stId] = GenSide(stId) end
    S.Write()
    mode_ = "station"; stationTab_ = "trade"
    Space.Activate()
    RenderStation()
end

local function Undock()
    local st, sys = S.StationById(S.data.dockedAt)
    if Space.W.sys.id ~= sys.id then Space.LoadSystem(sys.id) end
    local stEnt = Space.ByKind("station")
    local out = U.norm({ 0.3, 0.05, 1 })
    local p = Space.W.player
    p.pos = U.add(stEnt.pos, U.mul(out, stEnt.radius + 80))
    p.yaw = U.anglesTo(out); p.pitch = 0
    p.speed, p.throttle = 30, 0.5
    local stt = S.Stats()
    p.shield, p.hull = stt.shieldMax, stt.hullMax - S.data.hullDmg
    if S.data.missiles > stt.missileCap then S.data.missiles = stt.missileCap end
    if p.model ~= S.data.ship then
        -- 换船后重新生成玩家网格
        local VoxelBuilder = require("game.VoxelBuilder")
        local pos = p.pos
        p.node:Remove()
        p.model = S.data.ship
        Space.ReplacePlayerModel(p)
        p.pos = pos
        p.radius = VoxelBuilder.Radius(p.model)
    end
    Space.cam.pos = nil
    ResumeFlight()
end

local function ResChip(iconId, text, color)
    return UI.Panel { flexDirection = "row", alignItems = "center", gap = 10, paddingVertical = 10, paddingLeft = 14, paddingRight = 22,
        backgroundColor = C.panel, borderTopWidth = 4, borderTopColor = C.hi, borderBottomWidth = 6, borderBottomColor = C.lo,
        children = { PixelIcon { icon = SCENES.resIcons[iconId], width = 40, height = 40 }, Theme.Text(text, 40, color or C.bone, true) } }
end

local function TradeBody(stId)
    local st = S.Stats()
    local rows = { UI.Panel { flexDirection = "row", paddingHorizontal = 12, children = {
        Theme.Text("商品", 24, C.muted, false, { flexGrow = 1 }), Theme.Text("买入价", 24, C.muted, false, { width = 130 }),
        Theme.Text("卖出价", 24, C.muted, false, { width = 130 }), Theme.Text("货舱", 24, C.muted, false, { width = 100 }),
        UI.Panel { width = 520 } } } }
    for _, g in ipairs(G.goods) do
        local bp, sp = S.PriceOf(stId, g.id, false), S.PriceOf(stId, g.id, true)
        local have = S.data.cargo[g.id] or 0
        local stObj = S.StationById(stId)
        local mult = stObj.prices[g.id]
        local nameRow = { Theme.Text(g.name, 32, C.bone, true) }
        if mult <= 0.75 then nameRow[2] = Theme.Tag("低价", C.hp, { 11, 42, 20, 255 }) elseif mult >= 1.3 then nameRow[2] = Theme.Tag("高价", C.amber, C.ink) end
        local function Buy(n)
            return function()
                n = math.min(n, st.cargoCap - S.CargoUsed(), math.floor(S.data.credits / bp))
                if n <= 0 then Game.Toast((st.cargoCap - S.CargoUsed() <= 0) and "货舱已满" or "信用点不足"); return end
                S.data.credits = S.data.credits - bp * n; S.AddCargo(g.id, n); S.Write(); RenderStation()
            end
        end
        local function Sell(n)
            return function()
                n = math.min(n, S.data.cargo[g.id] or 0)
                if n <= 0 then return end
                local m = S.data.active
                if m and m.kind == "deliver" and m.good == g.id and ((S.data.cargo[g.id] or 0) - n) < m.count then Game.Toast("这批货是任务货物，不能卖"); return end
                S.data.credits = S.data.credits + sp * n; S.AddCargo(g.id, -n); S.Write(); RenderStation()
            end
        end
        rows[#rows + 1] = UI.Panel { flexDirection = "row", alignItems = "center", paddingHorizontal = 12, paddingVertical = 14,
            borderTopWidth = 3, borderTopColor = { 52, 64, 122, 150 }, children = {
                UI.Panel { flexGrow = 1, flexShrink = 1, children = {
                    UI.Panel { flexDirection = "row", alignItems = "center", gap = 10, children = nameRow },
                    Theme.Text(g.desc, 22, C.muted, false, { whiteSpace = "normal" }) } },
                Theme.Text(tostring(bp), 30, C.bone, false, { width = 130 }),
                Theme.Text(tostring(sp), 30, C.bone, false, { width = 130 }),
                Theme.Text(tostring(have), 30, C.bone, false, { width = 100 }),
                UI.Panel { width = 520, flexDirection = "row", gap = 8, justifyContent = "flex-end", children = {
                    Theme.Mini("买 1", Buy(1)), Theme.Mini("买 5", Buy(5)), Theme.Mini("卖 1", Sell(1), true), Theme.Mini("全卖", Sell(99), true) } },
            } }
    end
    rows[#rows + 1] = Theme.Text("同一商品在不同星港价格不同。低价买入、高价卖出就是跑商的全部秘诀。", 26, C.muted, false, { marginTop = 18, whiteSpace = "normal" })
    return rows
end

local function MissionsBody(stId)
    local out = {}
    if S.data.active then
        out[#out + 1] = UI.Panel { backgroundColor = C.rowBg, paddingHorizontal = 26, paddingVertical = 20, borderLeftWidth = 6, borderLeftColor = C.amber, gap = 8, children = {
            Theme.Tag("进行中"), Theme.Text(S.data.active.title, 38, C.bone, true), Theme.Text(MissionLine(), 28, C.text2, false, { whiteSpace = "normal" }),
            UI.Panel { flexDirection = "row", children = { Theme.Mini("放弃任务", function() S.data.active = nil; S.Write(); RenderStation(); Game.Toast("任务已放弃") end, true) } } } }
    end
    local list = AvailableMissions(stId)
    if #list == 0 then out[#out + 1] = Theme.Text("这里暂时没有新任务。", 26, C.muted) end
    for _, m in ipairs(list) do
        out[#out + 1] = UI.Panel { backgroundColor = C.rowBg, paddingHorizontal = 26, paddingVertical = 20, borderLeftWidth = 6,
            borderLeftColor = m.story and C.teal or C.hi, gap = 8, children = {
                Theme.Tag(m.story and "主线" or "支线", m.story and C.teal or C.hi, m.story and C.tealInk or C.bone),
                Theme.Text(m.title, 38, C.bone, true), Theme.Text(m.text, 28, C.text2, false, { whiteSpace = "normal" }),
                UI.Panel { flexDirection = "row", justifyContent = "space-between", alignItems = "center", children = {
                    Theme.Text("奖励 " .. U.fmt(m.reward) .. " 信用点" .. (((m.shards or 0) > 0) and ("，陨石碎片 x" .. m.shards) or ""), 26, C.amber),
                    Theme.Mini("接受", function() AcceptMission(m) end, false, S.data.active ~= nil) } } } }
    end
    return out
end

local function YardBody()
    local st = S.Stats()
    local cur = U.byId(G.ships, S.data.ship)
    local ships = { Theme.Text("飞船", 34, C.amber, true, { marginBottom = 14 }) }
    for _, s in ipairs(G.ships) do
        local own = s.id == S.data.ship
        local cost = math.max(0, s.price - math.floor(cur.price * 0.5 + 0.5))
        local right
        if own then right = Theme.Tag("当前") else
            right = Theme.Mini(cost > 0 and (U.fmt(cost) .. " 换购") or "免费换回", function()
                if S.data.credits < cost then Game.Toast("信用点不足"); return end
                local fx = S.CrewFx()
                if S.CargoUsed() > s.cargo + fx.cargo then Game.Toast("新船货舱放不下现有货物，先卖掉一些"); return end
                S.data.credits = S.data.credits - cost; S.data.ship = s.id; S.data.hullDmg = 0
                S.data.missiles = math.min(S.data.missiles, S.Stats().missileCap)
                Game.Toast("已换购 " .. s.name); S.Write(); RenderStation()
            end)
        end
        ships[#ships + 1] = UI.Panel { flexDirection = "row", alignItems = "center", gap = 20, paddingHorizontal = 18, paddingVertical = 16, marginBottom = 12,
            backgroundColor = C.rowBg, borderLeftWidth = own and 6 or 0, borderLeftColor = C.amber, children = {
                CatIcon(s.id, 120, 80),
                UI.Panel { flexGrow = 1, flexShrink = 1, children = {
                    Theme.Text(s.name, 32, C.bone, true), Theme.Text(s.desc, 22, C.muted, false, { whiteSpace = "normal" }),
                    Theme.Text(string.format("船体 %d，护盾 %d，航速 %d，货舱 %d，炮口 %d，导弹 %d", s.hull, s.shield, s.speed, s.cargo, s.guns, s.missiles), 22, C.muted, false, { whiteSpace = "normal" }) } },
                right } }
    end
    local function EqRow(list, curId, key)
        local ci = 1
        for i, x in ipairs(list) do if x.id == curId then ci = i end end
        local nextIt = list[ci + 1]
        local kids = { UI.Panel { flexGrow = 1, flexShrink = 1, children = {
            Theme.Text(list[ci].name, 32, C.bone, true), Theme.Text(nextIt and ("下一级：" .. nextIt.name) or "已满级", 22, C.muted) } } }
        if nextIt then
            kids[2] = Theme.Mini(U.fmt(nextIt.price) .. " 升级", function()
                if S.data.credits < nextIt.price then Game.Toast("信用点不足"); return end
                S.data.credits = S.data.credits - nextIt.price; S.data[key] = nextIt.id
                Game.Toast("已安装 " .. nextIt.name); S.Write(); RenderStation()
            end)
        end
        return UI.Panel { flexDirection = "row", alignItems = "center", gap = 20, paddingHorizontal = 18, paddingVertical = 16, marginBottom = 12, backgroundColor = C.rowBg, children = kids }
    end
    local repair = math.ceil(S.data.hullDmg * G.tuning.repairCostPerHp)
    local eq = { Theme.Text("装备与维护", 34, C.amber, true, { marginBottom = 14 }), EqRow(G.lasers, S.data.laser, "laser"), EqRow(G.shields, S.data.shieldGen, "shieldGen"),
        UI.Panel { flexDirection = "row", alignItems = "center", gap = 20, paddingHorizontal = 18, paddingVertical = 16, marginBottom = 12, backgroundColor = C.rowBg, children = {
            UI.Panel { flexGrow = 1, children = { Theme.Text("导弹 " .. S.data.missiles .. " / " .. st.missileCap, 32, C.bone, true), Theme.Text("每枚 " .. G.missile.price .. " 信用点", 22, C.muted) } },
            Theme.Mini("补充 1 枚", function()
                if S.data.missiles >= st.missileCap then Game.Toast("导弹已满"); return end
                if S.data.credits < G.missile.price then Game.Toast("信用点不足"); return end
                S.data.credits = S.data.credits - G.missile.price; S.data.missiles = S.data.missiles + 1; S.Write(); RenderStation()
            end) } },
        UI.Panel { flexDirection = "row", alignItems = "center", gap = 20, paddingHorizontal = 18, paddingVertical = 16, backgroundColor = C.rowBg, children = {
            UI.Panel { flexGrow = 1, children = { Theme.Text(string.format("船体 %d / %d", math.floor(st.hullMax - S.data.hullDmg + 0.5), st.hullMax), 32, C.bone, true),
                Theme.Text(repair > 0 and ("修理费 " .. U.fmt(repair)) or "船体完好", 22, C.muted) } },
            repair > 0 and Theme.Mini("修理", function()
                local fix = math.min(S.data.hullDmg, math.floor(S.data.credits / G.tuning.repairCostPerHp))
                if fix <= 0 then Game.Toast("信用点不足"); return end
                S.data.credits = S.data.credits - math.ceil(fix * G.tuning.repairCostPerHp); S.data.hullDmg = S.data.hullDmg - fix; S.Write(); RenderStation()
            end) or UI.Panel {} } },
    }
    return { UI.Panel { flexDirection = "row", gap = 34, children = {
        UI.Panel { flexGrow = 1.3, flexBasis = 0, children = ships }, UI.Panel { flexGrow = 1, flexBasis = 0, children = eq } } } }
end

local function Summon()
    if S.data.shards < G.summonCost then Game.Toast("陨石碎片不足，击碎晶脉小行星或击落海贼可以获得"); return end
    local pool = {}
    for _, c in ipairs(G.crew) do
        local own = false
        for _, id in ipairs(S.data.crew) do if id == c.id then own = true end end
        if not own then pool[#pool + 1] = c end
    end
    S.data.shards = S.data.shards - G.summonCost
    if #pool == 0 then
        S.data.credits = S.data.credits + 3000
        Game.Toast("舰员已全部到齐，碎片能量转化为 3,000 信用点"); S.Write(); RenderStation(); return
    end
    local c = pool[math.random(#pool)]
    table.insert(S.data.crew, c.id); S.Write()
    SetRoot(UI.Panel { width = "100%", height = "100%", backgroundColor = C.shade, justifyContent = "center", alignItems = "center", gap = 14, children = {
        Theme.Tag("召唤成功", C.teal, C.tealInk), CatIcon(c.id, 220, 440),
        Theme.Text(c.name, 120, C.bone, true), Theme.Text(c.role, 34, C.teal), Theme.Text(c.buff, 32, C.bone, false, { marginBottom = 20 }),
        Theme.Button({ text = "欢迎加入", primary = true, style = { minHeight = 104, minWidth = 360 }, onClick = function() RenderStation() end }),
    } })
end

local function CrewBody()
    local cards = {}
    for _, c in ipairs(G.crew) do
        local own = false
        for _, id in ipairs(S.data.crew) do if id == c.id then own = true end end
        cards[#cards + 1] = UI.Panel { width = "32%", minHeight = 210, flexDirection = "row", alignItems = "center", gap = 16, padding = 16,
            backgroundColor = C.rowBg, opacity = own and 1 or 0.55, children = {
                own and CatIcon(c.id, 100, 200) or UI.Panel { width = 100, alignItems = "center", children = { Theme.Text("?", 90, C.muted, true) } },
                UI.Panel { flexGrow = 1, flexShrink = 1, children = {
                    Theme.Text(own and c.name or "未唤醒", 36, C.bone, true), Theme.Text(own and c.role or "星魂", 26, C.teal),
                    Theme.Text(own and c.buff or "在召唤台唤醒后加入舰队", 24, C.text2, false, { whiteSpace = "normal", marginTop = 6 }) } } } }
    end
    return {
        UI.Panel { flexDirection = "row", flexWrap = "wrap", gap = 16, children = cards },
        UI.Panel { flexDirection = "row", alignItems = "center", justifyContent = "space-between", gap = 30, marginTop = 24, children = {
            Theme.Text("消耗 " .. G.summonCost .. " 块陨石碎片，随机唤醒一位尚未加入的星魂少女。当前碎片 " .. S.data.shards .. "。", 28, C.text2, false, { flexShrink = 1, whiteSpace = "normal" }),
            Theme.Button({ text = "召唤", primary = true, onClick = Summon, style = { minHeight = 104, minWidth = 300 } }) } },
    }
end

RenderStation = function()
    local st, sys = S.StationById(S.data.dockedAt)
    local stats = S.Stats()
    local head = UI.Panel { position = "absolute", left = PAD, right = PAD, top = 26, flexDirection = "row", justifyContent = "space-between", alignItems = "center", children = {
        UI.Panel { children = { Theme.Text(st.name, 76, C.amber, true), Theme.Text(sys.name .. "，危险度 " .. sys.danger, 26, C.muted) } },
        UI.Panel { flexDirection = "row", gap = 14, children = {
            ResChip("credit", U.fmt(S.data.credits)), ResChip("shard", tostring(S.data.shards), C.teal),
            ResChip("supply", S.CargoUsed() .. " / " .. stats.cargoCap) } } } }
    local tabs = {}
    for _, t in ipairs({ { "trade", "交易所" }, { "missions", "任务板" }, { "yard", "船坞" }, { "crew", "舰员召唤" } }) do
        local on = stationTab_ == t[1]
        tabs[#tabs + 1] = UI.Panel { minHeight = 104, paddingHorizontal = 30, justifyContent = "center",
            backgroundColor = on and C.teal or C.panel, borderTopWidth = 4, borderTopColor = on and { 184, 255, 244, 255 } or C.hi,
            borderBottomWidth = 6, borderBottomColor = on and { 46, 159, 166, 255 } or C.lo,
            children = { Theme.Text(t[2], 34, on and C.tealInk or C.muted, true) },
            onClick = function() stationTab_ = t[1]; RenderStation() end }
    end
    tabs[#tabs + 1] = UI.Panel { flexGrow = 1 }
    tabs[#tabs + 1] = Theme.Button({ text = "起飞", primary = true, onClick = Undock, style = { minHeight = 104 } })
    local nav = UI.Panel { position = "absolute", left = PAD, top = 160, bottom = 40, width = 300, gap = 12, children = tabs }
    local body
    if stationTab_ == "trade" then body = TradeBody(st.id)
    elseif stationTab_ == "missions" then body = MissionsBody(st.id)
    elseif stationTab_ == "yard" then body = YardBody()
    else body = CrewBody() end
    local panel = Theme.VoxPanel { position = "absolute", left = PAD + 330, right = PAD, top = 160, bottom = 40, padding = 28, children = {
        UI.ScrollView { width = "100%", flexGrow = 1, flexBasis = 0, scrollY = true, scrollX = false, showScrollbar = true,
            children = { UI.Panel { width = "100%", gap = 18, children = body } } } } }
    SetRoot(Safe({ head, nav, panel }))
end

-- ---------------------------------------------------------------- 星图、暂停、被击毁
function Game.OpenMap()
    mode_ = "map"
    local W = Space.W
    local nodes = {}
    -- 星系示意：三个方块按 map 坐标排布
    for _, s in ipairs(G.systems) do
        local col = s.danger == "高" and C.danger or (s.danger == "中" and C.amber or C.teal)
        local cur = s.id == W.sys.id
        nodes[#nodes + 1] = UI.Panel { position = "absolute", left = string.format("%d%%", math.floor(10 + s.map[1] * 35)),
            top = string.format("%d%%", math.floor(42 + s.map[2] * 40)), alignItems = "center", width = 220, marginLeft = -110, children = {
                Theme.Text(cur and "当前位置" or " ", 22, C.amber),
                UI.Panel { width = 56, height = 56, backgroundColor = col, borderWidth = cur and 6 or 0, borderColor = C.bone },
                Theme.Text(s.name, 30, C.bone, true) } }
    end
    local navs = {}
    for _, e in ipairs(W.ents) do
        if e.kind == "station" or e.kind == "gate" or e.kind == "base" then
            local target = e
            navs[#navs + 1] = UI.Panel { flexDirection = "row", justifyContent = "space-between", alignItems = "center", minHeight = 96, paddingHorizontal = 26,
                backgroundColor = C.rowBg, borderLeftWidth = 6, borderLeftColor = C.hi, children = {
                    Theme.Text(e.name, 30, C.bone, true), Theme.Text(U.fmt(U.dist(e.pos, W.player.pos)) .. " 米", 26, C.muted) },
                onClick = function() Space.NavTo(target); ResumeFlight() end }
        end
    end
    local right = { Theme.Text(W.sys.name .. " 导航点", 40, C.amber, true, { marginBottom = 4 }) }
    for _, n in ipairs(navs) do right[#right + 1] = n end
    right[#right + 1] = Theme.Text("选择导航点后自动驾驶前往。推动摇杆即可接管。", 26, C.muted, false, { whiteSpace = "normal" })
    right[#right + 1] = Theme.Text(MissionLine(), 28, C.amber, false, { whiteSpace = "normal" })
    right[#right + 1] = Theme.Button({ text = "返回飞行", onClick = ResumeFlight, style = { minHeight = 96 } })
    local panel = Theme.VoxPanel { position = "absolute", left = PAD, right = PAD, top = 40, bottom = 40, flexDirection = "row", gap = 40, paddingHorizontal = 40, paddingVertical = 30, children = {
        UI.Panel { flexGrow = 1.4, flexBasis = 0, children = {
            Theme.Text("星系图", 40, C.amber, true, { marginBottom = 16 }),
            UI.Panel { width = "100%", height = 560, backgroundColor = C.rowBg, children = nodes },
            Theme.Text(W.sys.desc, 26, C.muted, false, { whiteSpace = "normal", marginTop = 18 }) } },
        UI.Panel { flexGrow = 1, flexBasis = 0, gap = 12, children = right } } }
    SetRoot(Safe({ panel }))
end

local function ShowTitle()
    mode_ = "title"
    if not S.data then S.data = S.Load() or S.New() end
    if not Space.W.sys or Space.W.sys.id ~= "ashfall" then Space.LoadSystem("ashfall") end
    Space.Activate()
    local has = S.Exists()
    local btns = {}
    if has then btns[#btns + 1] = Theme.Button({ text = "继续航行", primary = true, style = { minHeight = 104, minWidth = 300 }, onClick = function() S.data = S.Load() or S.New(); Game.StartGame(false) end }) end
    btns[#btns + 1] = Theme.Button({ text = "新的旅程", primary = not has, style = { minHeight = 104, minWidth = 300 }, onClick = function() S.data = S.New(); S.Write(); Game.StartGame(true) end })
    btns[#btns + 1] = Theme.Button({ text = "资产图鉴", style = { minHeight = 104, minWidth = 300 }, onClick = function() Game.OpenGallery() end })
    SetRoot(Safe({ UI.Panel { position = "absolute", left = 120, top = 0, bottom = 0, width = 860, justifyContent = "center", children = {
        Theme.Text("陨星银河", 190, C.amber, true, { letterSpacing = 10 }),
        Theme.Text("上古陨星天殒坠落八百年后，碎片里沉睡的星魂正在苏醒。驾驶你的飞船，在星系之间跑商、冒险，唤醒她们。", 34, C.bone, false, { whiteSpace = "normal", lineHeight = 1.6, marginTop = 24, marginBottom = 48 }),
        UI.Panel { flexDirection = "row", flexWrap = "wrap", gap = 20, children = btns } } } }))
end
Game.ShowTitle = ShowTitle

function Game.OpenPause()
    mode_ = "pause"
    SetRoot(Safe({ UI.Panel { position = "absolute", left = 0, right = 0, top = 0, bottom = 0, justifyContent = "center", alignItems = "center", children = {
        Theme.VoxPanel { width = 900, paddingHorizontal = 50, paddingVertical = 40, gap = 20, children = {
            Theme.Text("暂停", 80, C.amber, true),
            Theme.Button({ text = "继续", primary = true, onClick = ResumeFlight, style = { minHeight = 104 } }),
            Theme.Button({ text = "保存并回到标题", onClick = function() S.Write(); ShowTitle() end, style = { minHeight = 104 } }),
            Theme.Text("电脑操作：WASD 或方向键转向，R/F 油门，空格开火，Q 导弹，Shift 加速，T 目标，G 自动导航，E 停靠或跃迁，M 星图。", 26, C.muted, false, { whiteSpace = "normal" }) } } } } }))
end

local function OnDead()
    mode_ = "dead"
    deadTimer_ = 1.6
    local d = S.data
    d.cargo = {}; d.credits = math.floor(d.credits * 0.9); d.hullDmg = 0
    if d.active and d.active.provide then d.active = nil end
    S.Write()
end

local function ShowDeadPanel()
    local st, sys = S.StationById(S.data.dockedAt)
    SetRoot(Safe({ UI.Panel { position = "absolute", left = 0, right = 0, top = 0, bottom = 0, justifyContent = "center", alignItems = "center", children = {
        Theme.VoxPanel { width = 900, paddingHorizontal = 50, paddingVertical = 40, gap = 20, children = {
            Theme.Text("飞船被击毁", 80, C.amber, true),
            Theme.Text("逃生舱把你送回了" .. st.name .. "。货物全部遗失，保险扣除了 10% 信用点。", 30, C.text2, false, { whiteSpace = "normal" }),
            Theme.Button({ text = "在 " .. st.name .. " 重新出发", primary = true, style = { minHeight = 104 },
                onClick = function() Space.LoadSystem(sys.id); Game.Dock(st.id) end }) } } } } }))
end

function Game.StartGame(fresh)
    Space.LoadSystem(S.data.system)
    Game.Dock(S.data.dockedAt)
    if fresh then Game.Toast("欢迎来到灰烬星港。先去任务板接取主线任务。") end
end

-- ---------------------------------------------------------------- 图鉴（复用 PreviewWorld 的展示场景）
function Game.OpenGallery()
    mode_ = "gallery"
    World.Activate()
    World.ShowGallery(gallery_.id)
    local cats = {}
    for _, c in ipairs(CATALOG.categories) do
        local on = gallery_.cat == c.id
        cats[#cats + 1] = UI.Panel { minHeight = 76, paddingHorizontal = 20, justifyContent = "center", backgroundColor = on and C.teal or C.lo,
            children = { Theme.Text(c.name, 28, on and C.tealInk or C.muted, true) },
            onClick = function()
                gallery_.cat = c.id
                for _, it in ipairs(CATALOG.items) do if it.category == c.id then gallery_.id = it.id; break end end
                Game.OpenGallery()
            end }
    end
    local rows = {}
    for _, it in ipairs(CATALOG.items) do
        if it.category == gallery_.cat then
            local on = gallery_.id == it.id
            rows[#rows + 1] = UI.Panel { flexDirection = "row", alignItems = "center", gap = 20, minHeight = 104, paddingHorizontal = 16, paddingVertical = 10,
                backgroundColor = on and C.hi or C.rowBg, borderLeftWidth = on and 8 or 0, borderLeftColor = C.amber,
                children = { PixelIcon { icon = it.icon, width = 76, height = 84 }, Theme.Text(it.name, 30, C.bone, true) },
                onClick = function() gallery_.id = it.id; Game.OpenGallery() end }
        end
    end
    local it = U.byId(CATALOG.items, gallery_.id)
    local side = Theme.VoxPanel { position = "absolute", left = PAD, top = 40, bottom = 40, width = 540, padding = 18, children = {
        UI.Panel { flexDirection = "row", flexWrap = "wrap", gap = 10, marginBottom = 14, children = cats },
        UI.ScrollView { width = "100%", flexGrow = 1, flexBasis = 0, scrollY = true, scrollX = false, children = { UI.Panel { width = "100%", gap = 8, children = rows } } } } }
    local info = Theme.VoxPanel { position = "absolute", right = PAD, bottom = 40, width = 660, paddingHorizontal = 36, paddingVertical = 30, children = {
        Theme.Text(it.name, 72, C.bone, true), Theme.Text(it.desc, 28, C.text2, false, { whiteSpace = "normal", marginTop = 10 }),
        Theme.Text(string.format("尺寸 %.1f x %.1f x %.1f 米，体素 %d", it.size[1], it.size[2], it.size[3], it.voxels), 26, C.muted, false, { marginTop = 16 }) } }
    local back = Theme.Button({ text = "返回标题", onClick = function() ShowTitle() end, style = { position = "absolute", right = PAD, top = 28, minHeight = 96 } })
    SetRoot(Safe({ side, info, back }))
end

-- ---------------------------------------------------------------- 主循环
function Game.Init()
    Space.events.toast = Game.Toast
    Space.events.onHit = function() hitTime_ = 0.12 end
    Space.events.onDead = OnDead
    ShowTitle()
end

function Game.HandleKeys()
    if mode_ == "flight" then
        if input:GetKeyPress(KEY_Q) then Space.FireMissile() end
        if input:GetKeyPress(KEY_T) then Space.CycleTarget() end
        if input:GetKeyPress(KEY_E) then Game.Interact() end
        if input:GetKeyPress(KEY_M) then Game.OpenMap() end
        if input:GetKeyPress(KEY_G) then Space.ToggleAuto() end
        if input:GetKeyPress(KEY_ESCAPE) then Game.OpenPause() end
    elseif (mode_ == "map" or mode_ == "pause") and input:GetKeyPress(KEY_ESCAPE) then
        ResumeFlight()
    end
end

function Game.Update(dt, pointerOverUI)
    if toastTime_ > 0 then
        toastTime_ = toastTime_ - dt
        if toastTime_ <= 0 and toastBox_ then toastBox_:SetVisible(false) end
    end
    if mode_ == "gallery" then
        World.Update(dt, pointerOverUI)
        return
    end
    Game.HandleKeys()
    Space.Update(dt, mode_ == "flight")
    if mode_ == "flight" then
        Space.FollowCamera()
        Hud.Update(dt, MissionLine())
        S.data.played = (S.data.played or 0) + dt
        autosave_ = autosave_ - dt
        if autosave_ <= 0 then autosave_ = 15; S.Write() end
    elseif mode_ == "station" or mode_ == "title" then
        Space.OrbitStationCamera()
    elseif mode_ == "dead" then
        Space.FollowCamera()
        deadTimer_ = deadTimer_ - dt
        if deadTimer_ <= 0 and deadTimer_ > -1 then deadTimer_ = -2; ShowDeadPanel() end
    elseif mode_ == "warp" then
        warpTimer_ = warpTimer_ - dt
        if warpTimer_ <= 0 then
            Space.LoadSystem(warpTo_, warpFrom_); S.Write()
            ResumeFlight(); Game.Toast("抵达 " .. Space.W.sys.name)
        end
    else
        Space.FollowCamera()
    end
end

function Game.GetMode() return mode_ end

return Game
