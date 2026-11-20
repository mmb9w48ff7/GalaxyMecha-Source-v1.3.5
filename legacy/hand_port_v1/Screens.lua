-- Screens.lua：各界面绘制（机库 / 战斗 HUD / 升级选卡 / 结算），点击回调由 App 提供。
local D = require("cosmic.Data")
local U = require("cosmic.Util")
local S = require("cosmic.Save")
local UI = require("cosmic.UI")
local Sdk = require("cosmic.Sdk")
local Run = require("cosmic.Run")
local Screens = {}
local COL, GRADE = UI.COL, UI.GRADE
local function gcol(g) return GRADE[g] or COL.bone end

-- ---------------------------------------------------------------- 机库
function Screens.Hub(A)
    local sv, m = S.data, S.Mech(S.data.mech)
    local W = UI.lw
    UI.Text(W / 2, 28, "宇宙银河机甲", 76, COL.amber, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    UI.Text(W / 2, 112, "VOXEL MECHA", 24, COL.teal, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    UI.Text(W - 40, 36, "信用点 " .. math.floor(sv.credits) .. "　星源 " .. math.floor(sv.src), 34, COL.bone, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    -- 左：机甲信息
    UI.Panel(40, 150, 560, 700)
    local g = m.grade; UI.Text(70, 170, g, 44, gcol(g)); UI.Text(190, 170, m.name, 56, COL.bone); UI.Text(70, 240, m.type .. "　Lv " .. sv.mechs[m.id].lv .. "　" .. string.rep("★", sv.mechs[m.id].star), 28, COL.muted)
    local mul = S.MechMul(m.id)
    local stats = { { "耐久", m.hp * mul, 400, { 100, 230, 130 } }, { "火力", m.fire * 20 * mul, 300, COL.amber }, { "机动", m.spd * 5, 120, COL.teal } }
    for i, s in ipairs(stats) do local y = 300 + (i - 1) * 56; UI.Text(70, y, s[1], 30, COL.muted); UI.Bar(170, y + 8, 300, 22, s[2] / s[3], s[4]); UI.Text(490, y, tostring(math.floor(s[2])), 30, COL.bone) end
    UI.Text(70, 480, "主武器　" .. m.weapon.name, 30, COL.teal); UI.Wrap(70, 520, 500, m.weapon.desc, 24, COL.muted)
    UI.Text(70, 600, "机甲技能　" .. m.active.name .. "（冷却 " .. m.active.cd .. " 秒）", 30, COL.amber); UI.Wrap(70, 640, 500, m.active.desc, 24, COL.muted)
    if UI.Button(60, 760, 250, 70, "‹ 上一台", { size = 30 }) then A.CycleMech(-1) end
    if UI.Button(330, 760, 250, 70, "下一台 ›", { size = 30 }) then A.CycleMech(1) end
    -- 右：章节 / 危险 / 出击
    local ch = D.CHAPTERS[A.chapterSel]; local locked = A.chapterSel > sv.chapter
    UI.Panel(W - 620, 150, 580, 700)
    UI.Text(W - 330, 170, "第 " .. ch.id .. " 章", 30, COL.muted, NVG_ALIGN_CENTER + NVG_ALIGN_TOP); UI.Text(W - 330, 210, ch.name, 52, COL.amber, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    UI.Wrap(W - 590, 290, 520, ch.desc, 26, COL.bone)
    local power = S.Power(); local okp = power >= ch.rec
    UI.Text(W - 590, 400, "推荐战力 " .. ch.rec, 28, COL.muted); UI.Text(W - 60, 400, "你的战力 " .. power, 28, okp and { 100, 230, 130 } or COL.amber, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    UI.Text(W - 590, 440, "首领：" .. ch.bossName, 28, COL.bone)
    if UI.Button(W - 600, 490, 80, 70, "‹", { size = 40 }) then A.chapterSel = math.max(1, A.chapterSel - 1) end
    if UI.Button(W - 100, 490, 80, 70, "›", { size = 40 }) then A.chapterSel = math.min(#D.CHAPTERS, A.chapterSel + 1) end
    UI.Text(W - 330, 505, locked and "通关上一章解锁" or ("章节 " .. ch.id .. " / " .. #D.CHAPTERS), 30, locked and COL.danger or COL.bone, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    if UI.Button(W - 600, 580, 80, 70, "‹", { size = 40 }) then A.dangerSel = math.max(1, A.dangerSel - 1) end
    if UI.Button(W - 100, 580, 80, 70, "›", { size = 40 }) then A.dangerSel = math.min(sv.dangerMax, A.dangerSel + 1) end
    UI.Text(W - 330, 588, "危险等级 " .. A.dangerSel, 34, { 255, 138, 58 }, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    UI.Text(W - 330, 628, "敌人血量 +" .. 12 * (A.dangerSel - 1) .. "%　伤害 +" .. 8 * (A.dangerSel - 1) .. "%　奖励 +" .. 15 * (A.dangerSel - 1) .. "%", 20, COL.muted, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    if UI.Button(W - 600, 680, 560, 90, "出 击", { size = 52, color = { 200, 130, 20 }, disabled = locked }) then A.StartRun(false) end
    if UI.Button(W - 600, 780, 560, 60, "无尽模式（最高第 " .. sv.endlessBest .. " 波）", { size = 28, color = { 60, 38, 100 }, disabled = not sv.cleared["1"] }) then A.StartRun(true) end
    -- 底部导航
    local Meta = require("cosmic.Meta")
    local dot = function(n) return n and "  ●" or "" end
    local items = { { "工坊", "work" }, { "驾驶员", "pilots" }, { "召唤", "summon" }, { "每日" .. dot(Meta.AchReady() > 0 or not Meta.LoginState().claimed or not Meta.DailyChallenge().state.done), "daily" } }
    for i, it in ipairs(items) do if UI.Button(W / 2 - 780 + (i - 1) * 320, 900, 300, 80, it[1], { size = 32 }) then A.page = it[2] end end
    if UI.Button(W / 2 + 500, 900, 280, 80, "设置", { size = 32 }) then A.settings = not A.settings end
    if A.settings then
        UI.Panel(W / 2 - 360, 300, 720, 420, 245); UI.Text(W / 2, 320, "设置", 44, COL.amber, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        if UI.Button(W / 2 - 320, 400, 640, 70, "音效：" .. (sv.sound and "开" or "关")) then sv.sound = not sv.sound; A.ApplySound() end
        if UI.Button(W / 2 - 320, 490, 640, 70, "背景音乐：" .. (sv.music and "开" or "关")) then sv.music = not sv.music; A.ApplySound() end
        if UI.Button(W / 2 - 320, 580, 310, 60, "关于与合规", { size = 26 }) then A.settings = false; A.page = "about" end
        if UI.Button(W / 2 + 10, 580, 310, 60, "关闭", { size = 28 }) then A.settings = false; S.Write() end
    end
    if A.msg and A.msgT > 0 then UI.Text(W / 2, 850, A.msg, 34, COL.teal, NVG_ALIGN_CENTER + NVG_ALIGN_TOP) end
    if not sv.tutorialDone then
        nvgBeginPath(UI.vg); nvgRect(UI.vg, 0, 0, W, 1080); nvgFillColor(UI.vg, nvgRGBA(0, 0, 10, 200)); nvgFill(UI.vg)
        UI.Panel(W / 2 - 620, 200, 1240, 640, 250); UI.Text(W / 2, 225, "欢迎，舰长！", 64, COL.amber, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        local tips = { "按住左半屏拖动：移动机甲（电脑：WASD / 方向键）", "右半屏拖动：转动镜头", "机甲会自动瞄准并开火，右下大按钮放机甲技能（电脑：E）", "左侧小按钮是氮气推进：冲刺并短暂无敌，随后放技能有加成（电脑：空格）",
            "击败敌人掉落能量，升级时三选一：技能卡牌升到 5 级并凑齐对应被动可以“进化”", "去【工坊】抽取并装备技能卡牌，去【召唤】获得新机甲，每天记得领【每日】奖励" }
        for i, t in ipairs(tips) do UI.Text(W / 2 - 560, 320 + (i - 1) * 68, "· " .. t, 28, COL.bone) end
        if UI.Button(W / 2 - 200, 740, 400, 72, "开始游戏", { size = 36, color = { 200, 130, 20 } }) then sv.tutorialDone = true; S.Write() end
    end
end

-- ---------------------------------------------------------------- 战斗 HUD
local function project(R, x, y, z)
    local v = Run.camera:WorldToScreenPoint(Vector3(x, y, z)); return v.x * UI.lw, v.y * 1080
end
function Screens.Hud(R, A)
    local W = UI.lw; local exit = Sdk.ExitRect(); local rightPad = (exit and exit.right > 0.8) and 170 or 40
    -- 耐久 / 等级
    local hm = Run.hullMax(R)
    UI.Bar(40, 36, 520, 30, R.hull / hm, R.hull / hm > 0.3 and { 100, 230, 130 } or COL.danger); UI.Text(50, 38, "耐久 " .. math.max(0, math.floor(R.hull)) .. " / " .. hm, 24, COL.bone)
    UI.Text(40, 76, "信用点 " .. R.credits .. "　击破 " .. R.kills .. (R.combo > 4 and ("　" .. R.combo .. " 连击") or ""), 26, COL.bone)
    UI.Bar(0, 0, W, 14, R.xp / Run.XpNeed(R.level), COL.teal); UI.Text(W - 20, 18, "Lv " .. R.level, 26, COL.bone, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    -- 顶部提示
    local head = R.daily and ("每日挑战　第 " .. R.wave .. " 波　剩余 " .. U.fmtTime(D.DC_TIME - R.t)) or R.endless and ("无尽模式　第 " .. R.wave .. " 波　" .. U.fmtTime(R.t)) or ("星域 " .. R.sector .. " / 6　" .. (R.phase == "boss" and "击败首领" or U.fmtTime(R.t)))
    UI.Text(W / 2, 28, head .. (R.danger > 1 and ("　危险 " .. R.danger) or ""), 30, COL.amber, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    local o = R.obj
    if o then
        local txt = o.name
        if o.type == "clear" then txt = txt .. "　" .. (o.got or 0) .. " / " .. o.need elseif o.type == "hunt" and o.state == "active" then txt = txt .. "　" .. (o.got or 0) .. " / " .. o.need .. "　" .. math.ceil(o.t) .. " 秒"
        elseif o.type == "ambush" and o.state == "active" then txt = txt .. "　第 " .. o.wave .. " / 3 波" elseif (o.type == "derelict" or o.type == "distress") and o.hold and o.hold > 0 then txt = txt .. "　" .. string.format("%.0f", o.hold) .. " 秒" end
        UI.Text(W / 2, 62, txt .. (R.affix and ("　[" .. R.affix.name .. "]") or ""), 24, COL.teal, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        if o.node or o.ores then local tx, tz = o.x, o.z; if o.ores then for _, e in ipairs(o.ores) do if e.hp > 0 then tx, tz = e.x, e.z; break end end end
            local sx, sy = project(R, tx, R.py, tz); local d = math.floor(math.sqrt((tx - R.px) ^ 2 + (tz - R.pz) ^ 2))
            if sx > 40 and sx < W - 40 and sy > 40 and sy < 1040 then UI.Text(sx, sy - 30, "▼ " .. o.name .. " " .. d .. "米", 24, COL.teal, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            else UI.Text(U.clamp(sx, 60, W - 60), U.clamp(sy, 120, 1000), "◀▶ " .. d .. "米", 24, COL.teal, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE) end end
    end
    if R.bannerT > 0 then UI.Text(W / 2, 220, R.banner, 56, COL.amber, NVG_ALIGN_CENTER + NVG_ALIGN_TOP, math.min(255, math.floor(R.bannerT * 400))) end
    if R.boss and R.boss.hp > 0 then local b = R.boss; UI.Text(W / 2, 80, b.d.name, 28, COL.danger, NVG_ALIGN_CENTER + NVG_ALIGN_TOP); UI.Bar(W / 2 - 300, 118, 600, 20, b.hp / b.max, COL.danger) end
    -- 已装备卡牌
    for i, md in ipairs(R.mods) do UI.Text(40, 120 + (i - 1) * 34, (md.evo and "★ " or "") .. (Run.ELEM_BY[md.elem] and Run.ELEM_BY[md.elem].n or "") .. md.F.n .. " Lv" .. md.lvl, 22, md.evo and COL.amber or COL.muted) end
    -- 目标框与伤害数字
    if R.tg and R.tg.hp > 0 then local x, y = project(R, R.tg.x, R.tg.y, R.tg.z); UI.Text(x, y - 40, "◇", 34, COL.danger, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE) end
    for _, n in ipairs(R.nums) do local x, y = project(R, n.x, n.y, n.z); local c = n.col and { math.min(255, n.col[1] * 180), math.min(255, n.col[2] * 180), math.min(255, n.col[3] * 180) } or (n.crit and COL.amber or COL.bone)
        UI.Text(x, y, n.v, n.crit and 36 or 26, c, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE, math.min(255, math.floor(n.life * 400))) end
    -- 摇杆
    if UI.stick then nvgBeginPath(UI.vg); nvgCircle(UI.vg, UI.stick.cx, UI.stick.cy, 110); nvgStrokeColor(UI.vg, nvgRGBA(92, 242, 220, 120)); nvgStrokeWidth(UI.vg, 4); nvgStroke(UI.vg)
        nvgBeginPath(UI.vg); nvgCircle(UI.vg, UI.stick.x, UI.stick.y, 46); nvgFillColor(UI.vg, nvgRGBA(92, 242, 220, 160)); nvgFill(UI.vg)
    else UI.Text(200, 880, "按住左半屏拖动移动", 24, COL.muted, NVG_ALIGN_CENTER + NVG_ALIGN_TOP, 160) end
    -- 技能 / 氮气按钮
    local N = Run.NITRO[R.m.id] or Run.NITRO.mech_azure
    local sx, sy = W - rightPad - 240, 800
    local ready = R.activeCd <= 0
    if UI.Button(sx, sy, 230, 230, ready and R.m.active.name or string.format("%.0f", R.activeCd), { size = 30, color = ready and { 200, 130, 20 } or COL.hi, border = R.nitroT > 0 and COL.teal or nil, textColor = COL.bone }) then A.cast = true end
    if UI.Button(sx - 190, sy + 70, 170, 160, R.nitroCd <= 0 and N.name or string.format("%.0f", R.nitroCd), { size = 26, color = R.nitroCd <= 0 and { 30, 100, 150 } or COL.hi }) then A.nitro = true end
    if UI.Button(W - 150 - (exit and 160 or 0), 90, 110, 60, "暂停", { size = 24 }) then A.paused = true end
end

-- ---------------------------------------------------------------- 升级选卡
function Screens.LevelUp(R, A)
    local W = UI.lw
    nvgBeginPath(UI.vg); nvgRect(UI.vg, 0, 0, W, 1080); nvgFillColor(UI.vg, nvgRGBA(0, 0, 10, 170)); nvgFill(UI.vg)
    UI.Text(W / 2, 90, "升级！", 90, COL.amber, NVG_ALIGN_CENTER + NVG_ALIGN_TOP); UI.Text(W / 2, 200, "选择一项强化", 34, COL.bone, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    local ids = R.choosing; local cw, gap = 520, 40; local x0 = (W - (#ids * cw + (#ids - 1) * gap)) / 2
    for i, id in ipairs(ids) do
        local info = Run.ChoiceInfo(R, id); local x, y = x0 + (i - 1) * (cw + gap), 280
        UI.Panel(x, y, cw, 520, 235); if info.evo then nvgBeginPath(UI.vg); nvgRect(UI.vg, x, y, cw, 520); nvgStrokeColor(UI.vg, nvgRGBA(245, 165, 36, 255)); nvgStrokeWidth(UI.vg, 6); nvgStroke(UI.vg) end
        UI.Text(x + cw / 2, y + 24, info.tag, 28, info.evo and COL.amber or COL.teal, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        UI.Text(x + cw / 2, y + 90, info.name, 44, COL.bone, NVG_ALIGN_CENTER + NVG_ALIGN_TOP); UI.Wrap(x + 30, y + 190, cw - 60, info.text, 26, COL.muted)
        if UI.Button(x + 40, y + 440, cw - 80, 60, "选择", { size = 30, color = info.evo and { 200, 130, 20 } or COL.hi }) then Run.ApplyChoice(R, id) end
    end
    local free = R.rr.free > 0; local left = math.max(0, 2 - R.rr.ad)
    local label = free and "刷新选项（免费 1 次）" or (left > 0 and ("看广告 刷新选项（还可 " .. left .. " 次）") or "刷新次数已用完")
    if UI.Button(W / 2 - 440, 850, 430, 80, label, { size = 26, disabled = (not free) and (left <= 0 or not Sdk.AdAvailable()), color = free and COL.hi or { 30, 100, 150 } }) then
        if free then Run.Reroll(R, false) else Sdk.ShowRewardAd(function(res) if res.success then Run.Reroll(R, true) else A.Toast("需要完整看完广告才能刷新") end end) end
    end
    if UI.Button(W / 2 + 10, 850, 430, 80, "跳过，回复 30% 耐久", { size = 26 }) then Run.Skip(R) end
end

-- ---------------------------------------------------------------- 结算
function Screens.Result(R, A)
    local W, r = UI.lw, R.result
    nvgBeginPath(UI.vg); nvgRect(UI.vg, 0, 0, W, 1080); nvgFillColor(UI.vg, nvgRGBA(0, 0, 10, 190)); nvgFill(UI.vg)
    UI.Panel(W / 2 - 520, 200, 1040, 640, 245)
    UI.Text(W / 2, 230, R.endless and "无尽模式结束" or (r.win and "远征成功" or "远征失败"), 80, r.win and COL.amber or COL.danger, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    local rows = { { "到达", R.endless and ("第 " .. r.wave .. " 波") or (r.win and "通关" or (R.sector .. " / 6")) }, { "用时", U.fmtTime(r.time) }, { "击破", tostring(r.kills) }, { "信用点", "+" .. r.credits }, { "星源", "+" .. r.src }, { "本局等级", "Lv " .. r.level } }
    for i, row in ipairs(rows) do local x = W / 2 - 440 + ((i - 1) % 3) * 300; local y = 350 + ((i - 1) // 3) * 130; UI.Text(x, y, row[1], 26, COL.muted); UI.Text(x, y + 40, row[2], 50, COL.bone) end
    if r.dcScore then UI.Text(W / 2, 560, "每日挑战得分 " .. r.dcScore .. (r.dcFirst and "　首次完成奖励已发放" or ""), 34, { 255, 138, 58 }, NVG_ALIGN_CENTER + NVG_ALIGN_TOP) end
    if r.first then UI.Text(W / 2, 620, "首次通关奖励已发放，下一章已解锁", 28, COL.teal, NVG_ALIGN_CENTER + NVG_ALIGN_TOP) end
    if r.unlock then UI.Text(W / 2, 660, "危险等级 " .. S.data.dangerMax .. " 已解锁", 28, COL.amber, NVG_ALIGN_CENTER + NVG_ALIGN_TOP) end
    local y = 730
    if not r.win and not R.revived and Sdk.AdAvailable() then if UI.Button(W / 2 - 500, y, 330, 80, "看广告 复活", { size = 28, color = { 30, 100, 150 } }) then Sdk.ShowRewardAd(function(res) if res.success then Run.Revive(R) else A.Toast("需要完整看完广告才能复活") end end) end end
    if r.credits > 0 and not R.doubled and Sdk.AdAvailable() then if UI.Button(W / 2 - 160, y, 330, 80, "看广告 信用点翻倍", { size = 26, color = { 30, 100, 150 } }) then Sdk.ShowRewardAd(function(res) if res.success then R.doubled = true; S.data.credits = S.data.credits + r.credits; S.Write() else A.Toast("需要完整看完广告才能领取") end end) end end
    if UI.Button(W / 2 + 190, y, 310, 80, "返回机库", { size = 30, color = { 200, 130, 20 } }) then A.ToHub() end
end
function Screens.Pause(R, A)
    local W = UI.lw
    nvgBeginPath(UI.vg); nvgRect(UI.vg, 0, 0, W, 1080); nvgFillColor(UI.vg, nvgRGBA(0, 0, 10, 170)); nvgFill(UI.vg)
    UI.Text(W / 2, 260, "暂停", 80, COL.amber, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    if UI.Button(W / 2 - 260, 420, 520, 90, "继续", { size = 40, color = { 200, 130, 20 } }) then A.paused = false end
    if UI.Button(W / 2 - 260, 540, 520, 90, "撤退（结算）", { size = 34 }) then A.paused = false; Run.End(R, false) end
end
return Screens
