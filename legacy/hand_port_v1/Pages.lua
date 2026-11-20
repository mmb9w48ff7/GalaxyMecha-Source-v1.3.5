-- Pages.lua：机库之外的页面——工坊（卡牌 / 芯片）、驾驶员、召唤、每日、关于与合规
local D = require("cosmic.Data")
local U = require("cosmic.Util")
local S = require("cosmic.Save")
local UI = require("cosmic.UI")
local Meta = require("cosmic.Meta")
local Sdk = require("cosmic.Sdk")
local Pages = {}
local COL, GRADE = UI.COL, UI.GRADE
local TIERC = { { 230, 234, 245 }, { 87, 184, 255 }, { 180, 124, 255 }, { 245, 165, 36 } }
local TIERN = { "白色", "蓝色", "紫色", "金色" }
local ORDER = { S = 0, SS = 1, SSR = 2, SSSR = 3 }
local function header(A, title, tabs)
    local W = UI.lw
    UI.Text(W / 2, 30, title, 60, COL.amber, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    if UI.Button(30, 24, 160, 70, "‹ 返回", { size = 30 }) then A.page = "hub"; S.Write() end
    UI.Text(W - 40, 40, "信用点 " .. math.floor(S.data.credits) .. "　星源 " .. math.floor(S.data.src), 30, COL.bone, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
end
local function adUpgrade(A, item, name)
    local sv = S.data; Meta.DailyReset()
    local left = math.max(0, 5 - (sv.daily.adUp or 0)); local lv = item.lvl or 1
    local label = lv >= D.LV_MAX and "已满级" or ("看广告 升到 Lv " .. (lv + 1) .. "（今日还可 " .. left .. " 次）")
    if UI.Button(0, 0, 0, 0, "", { disabled = true }) then end
    return label, (lv < D.LV_MAX and left > 0 and Sdk.AdAvailable())
end
local function doAdUp(A, item, name)
    Sdk.ShowRewardAd(function(res) if res.success then item.lvl = (item.lvl or 1) + 1; S.data.daily.adUp = (S.data.daily.adUp or 0) + 1; S.Write(); A.Toast(name .. " 升到 Lv " .. item.lvl) else A.Toast("需要完整看完广告才能升级") end end)
end

-- ---------------------------------------------------------------- 工坊
function Pages.Work(A)
    local W, sv = UI.lw, S.data; local wk = A.wk
    header(A, "工坊")
    if UI.Button(240, 100, 260, 60, "技能卡牌", { color = wk.tab == "cards" and { 200, 130, 20 } or COL.hi, size = 28 }) then wk.tab = "cards" end
    if UI.Button(520, 100, 260, 60, "天赋芯片", { color = wk.tab == "chips" and { 200, 130, 20 } or COL.hi, size = 28 }) then wk.tab = "chips" end
    if wk.tab == "cards" then Pages.Cards(A) else Pages.Chips(A) end
end
function Pages.Cards(A)
    local W, sv, wk = UI.lw, S.data, A.wk
    UI.Text(40, 175, "已收集 " .. #sv.modules .. " / " .. Meta.ModTotal() .. " 张卡牌　出击时 3 张装备全部生效", 24, COL.muted)
    for i = 1, 3 do
        local c = sv.modEq[i] and Meta.Card(sv.modEq[i]); local x = 40 + (i - 1) * 370
        if UI.Button(x, 210, 350, 70, c and (c.name .. "  Lv" .. c.lvl) or "空槽位", { size = 24, color = c and { 30, 40, 80 } or COL.panel, border = c and TIERC[c.tier + 1] or nil }) and c then Meta.Equip(c.id) end
    end
    for t = 0, 3 do if UI.Button(40 + t * 215, 300, 205, 56, TIERN[t + 1] .. "  " .. (function() local n = 0; for _, c in ipairs(sv.modules) do if c.tier == t then n = n + 1 end end return n end)(), { size = 24, color = wk.tier == t and TIERC[t + 1] or COL.hi, textColor = wk.tier == t and { 20, 20, 30 } or COL.bone }) then wk.tier = t; wk.v = 0 end end
    -- 形态选择（20 种，5 列 4 行）
    for i, F in ipairs(D.MOD_FORMS) do
        local x, y = 40 + ((i - 1) % 5) * 172, 370 + ((i - 1) // 5) * 62
        local own = 0; for _, c in ipairs(sv.modules) do if c.form == F.k then own = own + 1 end end
        if UI.Button(x, y, 166, 56, F.n .. (own > 0 and ("·" .. own) or ""), { size = 22, color = wk.form == F.k and { 52, 100, 150 } or COL.hi, textColor = own > 0 and COL.bone or COL.muted }) then wk.form = F.k end
    end
    -- 元素 x 变体
    local nv = Meta.VARIANTS[wk.tier + 1]
    for i, E in ipairs(D.ELEMENTS) do
        local y = 640 + (i - 1) * 66; UI.Text(40, y + 14, E.n, 26, COL.muted)
        for v = 0, nv - 1 do
            local card = Meta.MakeCard(wk.tier, wk.form, E.k, v); local own = Meta.Card(card.id); local sel = wk.elem == E.k and wk.v == v
            if UI.Button(130 + v * 330, y, 320, 60, card.name:gsub("^" .. E.n, "") .. (own and ("  Lv" .. own.lvl) or ""), { size = 22, color = own and { 40, 56, 110 } or { 30, 34, 56 }, border = sel and COL.teal or (own and TIERC[wk.tier + 1] or nil), textColor = own and COL.bone or COL.muted }) then wk.elem = E.k; wk.v = v end
        end
    end
    -- 右侧详情
    UI.Panel(W - 700, 170, 660, 880, 235)
    local card = Meta.MakeCard(wk.tier, wk.form, wk.elem, wk.v); local own = Meta.Card(card.id); local F, E = Meta.FORM_BY[wk.form], Meta.ELEM_BY[wk.elem]
    UI.Text(W - 670, 190, card.name, 44, TIERC[wk.tier + 1]); UI.Text(W - 670, 250, TIERN[wk.tier + 1] .. (own and ("　Lv " .. own.lvl) or "　未获得"), 26, own and COL.bone or COL.muted)
    UI.Wrap(W - 670, 300, 600, F.d .. "，伤害 " .. F.dmg .. "，冷却 " .. F.cd .. " 秒，数量 " .. F.count, 24, COL.bone)
    UI.Wrap(W - 670, 380, 600, "元素：" .. E.d, 24, COL.teal)
    local tg = {}; for _, t in ipairs(card.tags) do tg[#tg + 1] = Meta.TAG_BY[t].n end
    UI.Wrap(W - 670, 440, 600, "词条：" .. (#tg > 0 and table.concat(tg, "、") or "无（白色基础卡牌）"), 24, COL.bone)
    local g = Meta.GoldTag(card); if g then UI.Wrap(W - 670, 500, 600, "金色特效：" .. g.d, 24, COL.amber) end
    UI.Wrap(W - 670, 570, 600, "元素反应：" .. (D.REACT_HINT[wk.elem] or ""), 22, COL.muted)
    local fb = F.b or F.k; local ev = D.EVO[fb]; if ev then UI.Wrap(W - 670, 640, 600, "进化「" .. ev.n .. "」：" .. ev.d .. "（卡牌 Lv5 + 对应被动 Lv" .. D.EVO_PASS_LV .. "，局内触发）", 22, COL.muted) end
    if own then
        local eq = false; for _, e in ipairs(sv.modEq) do if e == own.id then eq = true end end
        if UI.Button(W - 670, 740, 290, 70, eq and "卸下" or "装备", { size = 30, color = { 200, 130, 20 } }) then local ok, msg = Meta.Equip(own.id); if ok == nil then A.Toast(msg) end end
        local label, can = adUpgrade(A, own)
        if UI.Button(W - 360, 740, 310, 70, own.lvl >= D.LV_MAX and "已满级" or "看广告 升 1 级", { size = 26, color = { 30, 100, 150 }, disabled = not can }) then doAdUp(A, own, card.name) end
    end
    local cost = Meta.Cost(sv.modBuys or 0)
    if UI.Button(W - 670, 840, 620, 90, "研发技能卡牌", { size = 34, sub = "信用点 " .. cost .. "，随机抽取 " .. Meta.ModTotal() .. " 张之一", color = { 200, 130, 20 } }) then
        local c, err, new = Meta.BuyCard(); if not c then A.Toast(err) else wk.tier, wk.form, wk.elem, wk.v = c.tier, c.form, c.elem, c.v; A.Toast((new and "新卡牌：" or "卡牌升级：") .. c.name .. " Lv" .. c.lvl) end
    end
    UI.Text(W - 670, 950, "品质：白 60% / 蓝 28% / 紫 10% / 金 2%；每 10 次至少蓝色，每 40 次必出金色", 20, COL.muted)
end
function Pages.Chips(A)
    local W, sv, wk = UI.lw, S.data, A.wk
    local slots = Meta.ChipSlots()
    UI.Text(40, 175, "已装备 " .. #sv.chipEq .. " / " .. slots .. "（通关章节解锁更多槽位）　仓库 " .. #sv.chips .. " / " .. D.INV_MAX, 24, COL.muted)
    for i = 1, 6 do local c = sv.chipEq[i] and Meta.Chip(sv.chipEq[i]); local x = 40 + (i - 1) * 190
        if UI.Button(x, 210, 182, 90, c and (c.name:sub(1, 12) .. "\nLv" .. (c.lvl or 1)) or (i > slots and "未解锁" or "空槽"), { size = 20, color = c and { 30, 40, 80 } or COL.panel, border = c and TIERC[c.tier + 1] or nil, disabled = i > slots and not c }) and c then wk.chip = c.id end
    end
    local list = {}; for _, c in ipairs(sv.chips) do list[#list + 1] = c end
    table.sort(list, function(a, b) return a.tier > b.tier or (a.tier == b.tier and (a.lvl or 1) > (b.lvl or 1)) end)
    for i, c in ipairs(list) do local x, y = 40 + ((i - 1) % 6) * 190, 330 + ((i - 1) // 6) * 100
        if y < 1020 then local eq = false; for _, e in ipairs(sv.chipEq) do if e == c.id then eq = true end end
            if UI.Button(x, y, 182, 92, c.series .. "·" .. (c.aff[1] and c.aff[1].k or "") .. "\nLv" .. (c.lvl or 1) .. (eq and " 已装备" or ""), { size = 20, color = wk.chip == c.id and { 52, 100, 150 } or COL.hi, border = TIERC[c.tier + 1] }) then wk.chip = c.id end end
    end
    UI.Panel(W - 700, 170, 660, 880, 235)
    local c = wk.chip and Meta.Chip(wk.chip)
    if c then
        UI.Text(W - 670, 190, c.name, 40, TIERC[c.tier + 1]); UI.Text(W - 670, 250, TIERN[c.tier + 1] .. "　Lv " .. (c.lvl or 1), 26, COL.bone)
        for i, a in ipairs(c.aff) do UI.Text(W - 670, 300 + (i - 1) * 40, "· " .. Meta.AffText(a, c), 26, COL.bone) end
        if c.trait then for _, t in ipairs(D.TRAITS) do if t.k == c.trait then UI.Wrap(W - 670, 440, 600, "金色特性「" .. t.n .. "」：" .. t.d, 24, COL.amber) end end end
        local eq = false; for _, e in ipairs(sv.chipEq) do if e == c.id then eq = true end end
        if UI.Button(W - 670, 540, 290, 70, eq and "卸下" or "装备", { size = 30, color = { 200, 130, 20 } }) then local ok, msg = Meta.EquipChip(c.id); if ok == nil then A.Toast(msg) end end
        local _, can = adUpgrade(A, c)
        if UI.Button(W - 360, 540, 310, 70, (c.lvl or 1) >= D.LV_MAX and "已满级" or "看广告 升 1 级", { size = 26, color = { 30, 100, 150 }, disabled = not can }) then doAdUp(A, c, c.name) end
        if UI.Button(W - 670, 630, 620, 60, "分解  +" .. D.REFUND[c.tier + 1] .. " 信用点", { size = 26 }) then Meta.DissolveChip(c.id); wk.chip = nil end
    else UI.Wrap(W - 670, 220, 600, "点选左侧的芯片查看详情。芯片属性永久生效，装备越多越强；每升 1 级词条 +12%。", 26, COL.muted) end
    local cost = Meta.Cost(sv.chipBuys or 0)
    if UI.Button(W - 670, 840, 620, 90, "研发天赋芯片", { size = 34, sub = "信用点 " .. cost .. "，仓库 " .. #sv.chips .. " / " .. D.INV_MAX, color = { 200, 130, 20 } }) then
        local ch, err = Meta.BuyChip(); if not ch then A.Toast(err) else wk.chip = ch.id; A.Toast("获得 " .. ch.name) end
    end
end

-- ---------------------------------------------------------------- 驾驶员
function Pages.Pilots(A)
    local W, sv = UI.lw, S.data; header(A, "驾驶员")
    local list = {}; for _, c in ipairs(D.CHARS) do list[#list + 1] = c end; table.sort(list, function(a, b) return ORDER[a.grade] > ORDER[b.grade] end)
    for i, c in ipairs(list) do
        local x, y = 40 + ((i - 1) % 3) * 400, 130 + ((i - 1) // 3) * 340; local own = sv.chars[c.id]
        UI.Panel(x, y, 380, 320, own and 225 or 160)
        UI.Text(x + 20, y + 14, c.grade, 36, GRADE[c.grade]); UI.Text(x + 120, y + 10, c.name, 46, own and COL.bone or COL.muted); UI.Text(x + 20, y + 66, c.role .. (own and ("　" .. string.rep("★", own.star)) or "　未获得"), 22, COL.muted)
        UI.Wrap(x + 20, y + 104, 340, "被动：" .. c.passive.name, 22, COL.teal); UI.Wrap(x + 20, y + 150, 340, c.support.name .. "：" .. c.support.desc, 20, COL.muted)
        if own then if UI.Button(x + 20, y + 250, 340, 56, sv.pilot == c.id and "出战中" or "选择出战", { size = 26, color = sv.pilot == c.id and { 200, 130, 20 } or COL.hi }) then sv.pilot = c.id; S.Write() end end
    end
    local p = Meta.CHAR_BY[sv.pilot]; local m = S.Mech(sv.mech)
    UI.Panel(1280, 130, 600, 660, 235); UI.Text(1310, 150, "当前驾驶员  " .. p.name, 36, COL.amber)
    UI.Wrap(1310, 210, 540, "被动：" .. p.passive.name, 26, COL.teal); UI.Wrap(1310, 270, 540, "支援技能「" .. p.support.name .. "」：" .. p.support.desc, 24, COL.bone)
    UI.Wrap(1310, 380, 540, "机甲技能「" .. (p.active and p.active.name or m.active.name) .. "」" , 24, COL.muted)
    UI.Wrap(1310, 480, 540, Meta.Matched() and ("与当前机甲「" .. m.name .. "」匹配：耐久与火力 +20%") or ("当前机甲「" .. m.name .. "」的专属驾驶员是 " .. (Meta.CHAR_BY[m.match] and Meta.CHAR_BY[m.match].name or "?") .. "，搭配时耐久与火力 +20%"), 24, Meta.Matched() and { 100, 230, 130 } or COL.amber)
end

-- ---------------------------------------------------------------- 召唤
function Pages.Summon(A)
    local W, sv = UI.lw, S.data; header(A, "召唤"); A.sm = A.sm or { kind = "mech", res = nil }
    if UI.Button(60, 130, 420, 90, "机甲召唤", { size = 34, color = A.sm.kind == "mech" and { 200, 130, 20 } or COL.hi }) then A.sm.kind = "mech" end
    if UI.Button(500, 130, 420, 90, "驾驶员召唤", { size = 34, color = A.sm.kind == "pilot" and { 200, 130, 20 } or COL.hi }) then A.sm.kind = "pilot" end
    local k = A.sm.kind; local RT = D.SUMMON.rates
    UI.Text(60, 250, string.format("SSSR %.0f%%　SSR %.0f%%　SS %.0f%%　S %.0f%%", RT.SSSR * 100, RT.SSR * 100, RT.SS * 100, RT.S * 100), 28, COL.bone)
    UI.Text(60, 296, "十连必出 SS 以上；" .. D.SUMMON.pitySSR .. " 抽内必出 SSR 以上，" .. D.SUMMON.pitySSSR .. " 抽内必出 SSSR（两个池分开计算）。重复获得会提升星级。", 22, COL.muted)
    UI.Text(60, 336, "保底进度：SSR+ " .. (sv[k .. "Pity"] or 0) .. " / " .. D.SUMMON.pitySSR .. "　SSSR " .. (sv[k .. "Pity3"] or 0) .. " / " .. D.SUMMON.pitySSSR, 24, COL.teal)
    if UI.Button(60, 400, 420, 100, "召唤 1 次", { size = 36, sub = "星源 " .. D.SUMMON.single }) then local r, err = Meta.Pull(k, 1); if r then A.sm.res = r; A.Sfx("win") else A.Toast(err) end end
    if UI.Button(500, 400, 420, 100, "召唤 10 次", { size = 36, sub = "星源 " .. D.SUMMON.ten, color = { 200, 130, 20 } }) then local r, err = Meta.Pull(k, 10); if r then A.sm.res = r; A.Sfx("win") else A.Toast(err) end end
    local pool = k == "mech" and D.MECHS or D.CHARS; local top = {}
    for _, m in ipairs(pool) do if m.grade == "SSSR" or m.grade == "SSR" then top[#top + 1] = m.grade .. " " .. m.name end end
    UI.Text(60, 540, "本池 SSR 以上：" .. table.concat(top, "、"), 24, COL.amber)
    if A.sm.res then for i, r in ipairs(A.sm.res) do local x, y = 60 + ((i - 1) % 5) * 360, 620 + ((i - 1) // 5) * 90
        UI.Panel(x, y, 340, 78, 230); UI.Text(x + 14, y + 8, r.g, 30, GRADE[r.g]); UI.Text(x + 110, y + 10, r.name, 32, COL.bone); UI.Text(x + 110, y + 48, r.new and "新获得！" or "重复：星级提升", 18, r.new and COL.teal or COL.muted) end end
end

-- ---------------------------------------------------------------- 每日
function Pages.Daily(A)
    local W, sv = UI.lw, S.data; header(A, "每日"); Meta.DailyReset()
    local ls = Meta.LoginState()
    UI.Text(40, 120, "7 日登录奖励", 28, COL.teal)
    for i, r in ipairs(Meta.LOGIN) do local x = 40 + (i - 1) * 118; local done = ls.claimed and (i - 1) <= ls.idx or (not ls.claimed and (i - 1) < ls.idx); local cur = not ls.claimed and (i - 1) == ls.idx
        UI.Panel(x, 160, 110, 120, done and 120 or 225); UI.Text(x + 55, 170, "第" .. i .. "天", 20, cur and COL.amber or COL.muted, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        UI.Text(x + 55, 205, r.cr and (r.cr .. "\n信用点") or (r.src .. "\n星源"), 20, COL.bone, NVG_ALIGN_CENTER + NVG_ALIGN_TOP); if r.draw then UI.Text(x + 55, 252, "+抽卡", 18, COL.teal, NVG_ALIGN_CENTER + NVG_ALIGN_TOP) end end
    if UI.Button(40, 295, 400, 60, ls.claimed and "今日已领取" or "领取今日奖励", { size = 26, disabled = ls.claimed, color = { 200, 130, 20 } }) then local t = Meta.LoginClaim(); if t then A.Toast("登录奖励：" .. t); A.Sfx("win") end end
    local dc = Meta.DailyChallenge()
    UI.Panel(40, 380, 840, 330, 230); UI.Text(60, 395, "每日挑战　第 " .. dc.chapter .. " 章　限时 4 分钟", 30, { 255, 138, 58 })
    for i, id in ipairs(dc.mods) do local m = Meta.DcMod(id); UI.Text(60, 445 + (i - 1) * 44, m.n .. "：" .. m.d, 24, COL.bone) end
    UI.Text(60, 545, "今日最高分 " .. dc.state.best .. "　历史最高 " .. (sv.dcBest or 0) .. "　" .. (dc.state.done and "今日奖励已领取" or "首次完成：信用点 +800，星源 +10"), 22, COL.muted)
    if UI.Button(60, 610, 800, 80, "开始挑战", { size = 36, color = { 200, 130, 20 } }) then A.StartDaily(dc) end
    local y = 740; UI.Text(40, y, "每日补给", 28, COL.teal)
    if UI.Button(40, y + 40, 400, 60, sv.daily.supply == 1 and "补给已领取" or ("领取补给 星源 +" .. D.DAILY_SUPPLY), { size = 24, disabled = sv.daily.supply == 1 }) then sv.daily.supply = 1; sv.src = sv.src + D.DAILY_SUPPLY; S.Write(); A.Toast("每日补给：星源 +" .. D.DAILY_SUPPLY) end
    UI.Text(920, 120, "每日任务", 28, COL.teal)
    for i, t in ipairs(D.TASKS) do local yy = 160 + (i - 1) * 64; local v = math.min(t.need, sv.daily[t.key] or 0)
        UI.Text(920, yy + 6, t.name .. "　" .. v .. " / " .. t.need, 24, COL.bone); UI.Text(1500, yy + 8, "星源 +" .. t.reward, 22, COL.teal)
        if UI.Button(1680, yy, 200, 52, sv.daily.claimed[t.id] and "已领取" or "领取", { size = 22, disabled = sv.daily.claimed[t.id] or not Meta.TaskDone(t) }) then Meta.TaskClaim(t) end end
    UI.Text(920, 370, "成就（" .. (function() local n = 0; for _ in pairs(sv.ach) do n = n + 1 end return n end)() .. " / " .. #Meta.ACH .. "）", 28, COL.teal)
    for i, a in ipairs(Meta.ACH) do local yy = 410 + (i - 1) * 46; local ok = a.ok(sv)
        UI.Text(920, yy + 4, a.n .. "　" .. a.d, 20, ok and COL.bone or COL.muted); UI.Text(1560, yy + 4, "星源 +" .. a.src, 20, COL.teal)
        if UI.Button(1700, yy, 180, 40, sv.ach[a.id] and "已领取" or "领取", { size = 20, disabled = sv.ach[a.id] or not ok }) then Meta.AchClaim(a.id) end end
end

-- ---------------------------------------------------------------- 关于与合规
function Pages.About(A)
    local W = UI.lw; header(A, "关于与合规"); local RT = D.SUMMON.rates
    local lines = {
        { "版本", "宇宙银河机甲 v" .. (require("cosmic.Run").VERSION) .. "（UrhoX 版）。存档仅保存在本机用户目录。" },
        { "原创声明", "游戏内全部机甲、角色、敌人、场景模型均为原创体素建模；音效与背景音乐为程序合成的原创音频；界面使用引擎自带字体。与任何现有动漫、游戏、影视作品及其角色、机体、商标无关联。" },
        { "抽取概率公示", string.format("召唤（机甲 / 驾驶员）：SSSR %.0f%%，SSR %.0f%%，SS %.0f%%，S %.0f%%；连续 %d 次未出 SSR 以上时下一次必出 SSR 以上，连续 %d 次未出 SSSR 时下一次必出 SSSR。工坊（技能卡牌 / 天赋芯片）：白色 60%%，蓝色 28%%，紫色 10%%，金色 2%%；每 10 次至少蓝色，每 40 次必出金色；技能卡牌共 %d 张。所有抽取只消耗游戏内货币（信用点 / 星源），本版本无真实货币付费。", RT.SSSR * 100, RT.SSR * 100, RT.SS * 100, RT.S * 100, D.SUMMON.pitySSR, D.SUMMON.pitySSSR, Meta.ModTotal()) },
        { "广告", "“看广告”为可选行为，用于升级卡牌 / 芯片、刷新升级选项、复活或信用点翻倍；不看不影响通关。广告由 TapTap 激励视频提供，只有完整观看才发放奖励。" },
        { "隐私", "本游戏不要求登录，不收集个人信息；存档保存在设备本地。" },
        { "适龄提示", "含卡通风格的科幻战斗（无血腥），建议 12 岁及以上；请合理安排游戏时间。" },
    }
    local y = 130
    for _, l in ipairs(lines) do UI.Text(60, y, l[1], 28, COL.teal); UI.Wrap(60, y + 40, 1780, l[2], 24, COL.bone); y = y + 40 + 32 * (math.floor(#l[2] / 120) + 1) + 24 end
end
return Pages
