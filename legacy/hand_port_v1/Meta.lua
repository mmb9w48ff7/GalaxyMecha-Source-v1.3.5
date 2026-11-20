-- Meta.lua：战斗之外的成长系统（卡牌收集 / 芯片 / 驾驶员 / 召唤 / 登录 / 成就 / 每日挑战），移植自网页版 cosmic_data.js
local D = require("cosmic.Data")
local U = require("cosmic.Util")
local S = require("cosmic.Save")
local M = {}
local FORM_BY, ELEM_BY, TAG_BY = {}, {}, {}
for _, f in ipairs(D.MOD_FORMS) do FORM_BY[f.k] = f end
for _, e in ipairs(D.ELEMENTS) do ELEM_BY[e.k] = e end
for _, t in ipairs(D.MOD_TAGS) do TAG_BY[t.k] = t end
M.FORM_BY, M.ELEM_BY, M.TAG_BY = FORM_BY, ELEM_BY, TAG_BY
local CHAR_BY = {}; for _, c in ipairs(D.CHARS) do CHAR_BY[c.id] = c end
M.CHAR_BY = CHAR_BY
local VARIANTS = { 1, 3, 3, 2 }; M.VARIANTS = VARIANTS
function M.Today() return os.date("%Y-%m-%d") end
function M.Yesterday() return os.date("%Y-%m-%d", os.time() - 86400) end
function M.ModTotal() return #D.MOD_FORMS * #D.ELEMENTS * 9 end
function M.Cost(n) return math.min(2500, 400 + n * 60) end

-- ---------------------------------------------------------------- 技能卡牌（形态 x 元素 x 品质 x 变体）
function M.MakeCard(tier, form, elem, v)
    local F = FORM_BY[form]; local E = ELEM_BY[elem]
    local rnd = U.seeded(form .. elem .. "p" .. tier); local pool = {}; for _, t in ipairs(D.MOD_TAGS) do pool[#pool + 1] = t end
    for k = #pool, 2, -1 do local j = math.floor(rnd() * k) + 1; pool[k], pool[j] = pool[j], pool[k] end
    local n = ({ 0, 1, 2, 2 })[tier + 1]; local tags, tn = {}, {}
    for k = 0, n - 1 do local tg = pool[((v * n + k) % #pool) + 1]; tags[#tags + 1] = tg.k; tn[#tn + 1] = tg.n end
    local c = { id = form .. ":" .. elem .. ":" .. tier .. ":" .. v, form = form, elem = elem, tier = tier, v = v, lvl = 1, tags = tags }
    c.name = E.n .. F.n .. (#tn > 0 and ("·" .. table.concat(tn)) or "")
    return c
end
function M.Card(id) for _, c in ipairs(S.data.modules) do if c.id == id then return c end end end
function M.CardOwned(form, elem, tier, v) return M.Card(form .. ":" .. elem .. ":" .. tier .. ":" .. v) end
function M.CardLvMult(c) return 1 + 0.12 * ((c.lvl or 1) - 1) end
local function rollTier(sv, key)
    sv[key] = (sv[key] or 0) + 1
    if sv[key] % 40 == 0 then return 3 end
    local r = math.random() * 100; local t = r < 60 and 0 or (r < 88 and 1 or (r < 98 and 2 or 3))
    if sv[key] % 10 == 0 and t == 0 then t = 1 end
    return t
end
function M.BuyCard()
    local sv = S.data; local cost = M.Cost(sv.modBuys or 0)
    if sv.credits < cost then return nil, "信用点不足" end
    sv.credits = sv.credits - cost; sv.modBuys = (sv.modBuys or 0) + 1
    local tier = rollTier(sv, "pityMod"); local F = U.pick(D.MOD_FORMS); local E = U.pick(D.ELEMENTS); local v = math.random(0, VARIANTS[tier + 1] - 1)
    local c = M.MakeCard(tier, F.k, E.k, v); local own = M.Card(c.id)
    if not own then sv.modules[#sv.modules + 1] = c; S.Write(); return c, nil, true end
    if (own.lvl or 1) < D.LV_MAX then own.lvl = (own.lvl or 1) + 1 else sv.credits = sv.credits + D.REFUND[own.tier + 1] end
    S.Write(); return own, nil, false
end
function M.Equip(id)
    local sv = S.data; for i, e in ipairs(sv.modEq) do if e == id then table.remove(sv.modEq, i); S.Write(); return false end end
    if #sv.modEq >= 3 then return nil, "槽位已满，先卸下一个" end
    sv.modEq[#sv.modEq + 1] = id; S.Write(); return true
end
function M.GoldTag(c) if c.tier ~= 3 then return nil end local F = FORM_BY[c.form]; return D.GOLD_FX[F.b or c.form] end

-- ---------------------------------------------------------------- 天赋芯片
function M.MakeChip(tier)
    local R = D.RARITY[tier + 1]; local pool = {}; for _, s in ipairs(D.CHIP_STATS) do pool[#pool + 1] = s end
    local ser = U.pick(D.CHIP_SERIES); local aff = {}
    for i = 1, R.affixes do
        local pl = pool
        if i == 1 then pl = {}; for _, s in ipairs(pool) do for _, b in ipairs(ser.b) do if b == s.k then pl[#pl + 1] = s end end end end
        local st = U.pick(pl); for k, s in ipairs(pool) do if s == st then table.remove(pool, k); break end end
        local v = U.rand(st.r[1], st.r[2]) * R.mult; aff[#aff + 1] = { k = st.k, v = st.abs and math.floor(v * 10 + 0.5) / 10 or math.floor(v + 0.5) }
    end
    local main; for _, s in ipairs(D.CHIP_STATS) do if s.k == aff[1].k then main = s end end
    local chip = { id = tostring(os.time()) .. "_" .. math.random(1, 999999), tier = tier, lvl = 1, series = ser.n, name = ser.n .. "·" .. main.p .. "芯片", aff = aff }
    if tier == 3 then chip.trait = U.pick(D.TRAITS).k end
    return chip
end
function M.BuyChip()
    local sv = S.data; local cost = M.Cost(sv.chipBuys or 0)
    if #sv.chips >= D.INV_MAX then return nil, "芯片仓库已满，先分解一些" end
    if sv.credits < cost then return nil, "信用点不足" end
    sv.credits = sv.credits - cost; sv.chipBuys = (sv.chipBuys or 0) + 1
    local c = M.MakeChip(rollTier(sv, "pityChip")); sv.chips[#sv.chips + 1] = c; S.Write(); return c
end
function M.ChipSlots() local n = 0; for _ in pairs(S.data.cleared) do n = n + 1 end; return math.min(6, 3 + n) end
function M.ChipLvMult(c) return 1 + 0.12 * ((c.lvl or 1) - 1) end
function M.Chip(id) for _, c in ipairs(S.data.chips) do if c.id == id then return c end end end
function M.EquipChip(id)
    local sv = S.data; for i, e in ipairs(sv.chipEq) do if e == id then table.remove(sv.chipEq, i); S.Write(); return false end end
    if #sv.chipEq >= M.ChipSlots() then return nil, "槽位已满，先卸下一个" end
    sv.chipEq[#sv.chipEq + 1] = id; S.Write(); return true
end
function M.DissolveChip(id)
    local sv = S.data; for i, c in ipairs(sv.chips) do if c.id == id then table.remove(sv.chips, i); sv.credits = sv.credits + D.REFUND[c.tier + 1]; break end end
    for i, e in ipairs(sv.chipEq) do if e == id then table.remove(sv.chipEq, i) end end; S.Write()
end
function M.AffText(a, c) local st; for _, s in ipairs(D.CHIP_STATS) do if s.k == a.k then st = s end end; local v = math.floor(a.v * M.ChipLvMult(c) * 10 + 0.5) / 10; return st.n .. " +" .. v .. (st.abs and "" or "%") end
-- 已装备芯片 + 驾驶员被动的属性汇总（百分比转小数，regen 为绝对值）
function M.Stats()
    local out = { traits = {} }; for _, s in ipairs(D.CHIP_STATS) do out[s.k] = 0 end
    for _, id in ipairs(S.data.chipEq) do local c = M.Chip(id)
        if c then local lm = M.ChipLvMult(c); for _, a in ipairs(c.aff) do local st; for _, s in ipairs(D.CHIP_STATS) do if s.k == a.k then st = s end end; out[a.k] = out[a.k] + (st.abs and a.v or a.v / 100) * lm end; if c.trait then out.traits[c.trait] = true end end end
    local ch = CHAR_BY[S.data.pilot]
    if ch and ch.passive and ch.passive.fx then for k, v in pairs(ch.passive.fx) do
        if k == "hull" then out.hp = out.hp + v elseif k == "dodge" then out.nitro = out.nitro + v elseif k == "loot" then out.credit = out.credit + v elseif k == "turret" then out.summon = out.summon + v elseif out[k] ~= nil then out[k] = out[k] + v end end end
    return out
end

-- ---------------------------------------------------------------- 驾驶员 / 召唤
function M.Pilot() return CHAR_BY[S.data.pilot] end
function M.Matched() local m = S.Mech(S.data.mech); return m and m.match == S.data.pilot end
local function pullGrade(sv, kind)
    local RT = D.SUMMON.rates; local pk, pk3 = kind .. "Pity", kind .. "Pity3"; sv[pk] = (sv[pk] or 0) + 1; sv[pk3] = (sv[pk3] or 0) + 1
    local r = math.random(); local g = r < RT.SSSR and "SSSR" or (r < RT.SSSR + RT.SSR and "SSR" or (r < RT.SSSR + RT.SSR + RT.SS and "SS" or "S"))
    if sv[pk3] >= D.SUMMON.pitySSSR then g = "SSSR" elseif sv[pk] >= D.SUMMON.pitySSR and (g == "S" or g == "SS") then g = "SSR" end
    if g == "SSSR" then sv[pk], sv[pk3] = 0, 0 elseif g == "SSR" then sv[pk] = 0 end
    return g
end
-- kind = "mech" | "pilot"；返回结果文本表
function M.Pull(kind, n)
    local sv = S.data; local cost = n == 10 and D.SUMMON.ten or D.SUMMON.single
    if sv.src < cost then return nil, "星源不足（需要 " .. cost .. "）" end
    sv.src = sv.src - cost; local res = {}
    for i = 1, n do
        local g = pullGrade(sv, kind); if n == 10 and i == 10 and (g == "S") then g = "SS" end
        local list = kind == "mech" and D.MECHS or D.CHARS; local pool = {}; for _, m in ipairs(list) do if m.grade == g then pool[#pool + 1] = m end end
        local m = U.pick(pool); local store = kind == "mech" and sv.mechs or sv.chars; local o = store[m.id]
        if o then o.star = math.min(5, o.star + 1); res[#res + 1] = { g = g, name = m.name, new = false } else store[m.id] = kind == "mech" and { lv = 1, star = 1 } or { star = 1 }; res[#res + 1] = { g = g, name = m.name, new = true } end
    end
    sv.daily.pulls = (sv.daily.pulls or 0) + n; S.Write(); return res
end

-- ---------------------------------------------------------------- 每日：登录 / 任务 / 成就 / 每日挑战
M.LOGIN = D.LOGIN_REWARDS
function M.DailyReset()
    local sv, t = S.data, M.Today()
    if sv.daily.day ~= t then sv.daily = { day = t, ads = 0, supply = 0, runs = 0, kills = 0, pulls = 0, claimed = {}, adUp = 0 } end
end
function M.LoginState()
    local l = S.data.login
    if l.last == M.Today() then return { claimed = true, idx = (l.n + 6) % 7 } end
    return { claimed = false, idx = (l.last == M.Yesterday()) and (l.n % 7) or 0 }
end
function M.LoginClaim()
    local st = M.LoginState(); if st.claimed then return nil end
    local rw, sv, txt = M.LOGIN[st.idx + 1], S.data, {}
    if rw.cr then sv.credits = sv.credits + rw.cr; txt[#txt + 1] = "信用点 +" .. rw.cr end
    if rw.src then sv.src = sv.src + rw.src; txt[#txt + 1] = "星源 +" .. rw.src end
    if rw.draw then sv.credits = sv.credits + M.Cost(sv.modBuys or 0); local c = M.BuyCard(); if c then txt[#txt + 1] = "免费抽到卡牌：" .. c.name end end
    sv.login.last = M.Today(); sv.login.n = st.idx + 1; S.Write(); return table.concat(txt, "，")
end
M.ACH = {
    { id = "a_run1", n = "首次出击", d = "完成 1 次远征", src = 5, ok = function(s) return s.runs >= 1 end },
    { id = "a_run10", n = "老练舰长", d = "完成 10 次远征", src = 10, ok = function(s) return s.runs >= 10 end },
    { id = "a_ch1", n = "灰烬终结者", d = "通关第 1 章", src = 15, ok = function(s) return s.cleared["1"] end },
    { id = "a_ch2", n = "碎石征服者", d = "通关第 2 章", src = 20, ok = function(s) return s.cleared["2"] end },
    { id = "a_ch3", n = "赤环破局者", d = "通关第 3 章", src = 30, ok = function(s) return s.cleared["3"] end },
    { id = "a_card10", n = "卡牌新手", d = "收集 10 张技能卡牌", src = 10, ok = function(s) return #s.modules >= 10 end },
    { id = "a_card30", n = "卡牌收藏家", d = "收集 30 张技能卡牌", src = 15, ok = function(s) return #s.modules >= 30 end },
    { id = "a_gold", n = "金光闪闪", d = "获得 1 张金色卡牌", src = 20, ok = function(s) for _, c in ipairs(s.modules) do if c.tier == 3 then return true end end end },
    { id = "a_chip5", n = "芯片工程师", d = "拥有 5 枚天赋芯片", src = 10, ok = function(s) return #s.chips >= 5 end },
    { id = "a_kill1k", n = "千杀", d = "累计击破 1000 个敌人", src = 15, ok = function(s) return s.kills >= 1000 end },
    { id = "a_boss3", n = "首领猎手", d = "累计击败 3 个首领", src = 20, ok = function(s) return s.bossKills >= 3 end },
    { id = "a_end10", n = "无尽远征", d = "无尽模式到达第 10 波", src = 20, ok = function(s) return s.endlessBest >= 10 end },
    { id = "a_dg5", n = "险中求胜", d = "解锁危险等级 5", src = 25, ok = function(s) return s.dangerMax >= 5 end },
    { id = "a_dc1", n = "每日挑战者", d = "完成 1 次每日挑战", src = 10, ok = function(s) return (s.dcBest or 0) > 0 end },
}
function M.AchClaim(id) for _, a in ipairs(M.ACH) do if a.id == id and not S.data.ach[id] and a.ok(S.data) then S.data.ach[id] = true; S.data.src = S.data.src + a.src; S.Write(); return true end end end
function M.AchReady() local n = 0; for _, a in ipairs(M.ACH) do if a.ok(S.data) and not S.data.ach[a.id] then n = n + 1 end end return n end
function M.TaskDone(t) return (S.data.daily[t.key] or 0) >= t.need end
function M.TaskClaim(t) local sv = S.data; if M.TaskDone(t) and not sv.daily.claimed[t.id] then sv.daily.claimed[t.id] = true; sv.src = sv.src + t.reward; S.Write(); return true end end
function M.DailyChallenge()
    local key = M.Today(); local rnd = U.seeded("dc" .. key); local pool = {}; for _, m in ipairs(D.DC_MODS) do pool[#pool + 1] = m end
    local mods = {}; for _ = 1, 2 do mods[#mods + 1] = table.remove(pool, math.floor(rnd() * #pool) + 1).id end
    local ch = 1 + math.floor(rnd() * math.max(1, math.min(#D.CHAPTERS, S.data.chapter)))
    local dc = S.data.dc; if not dc or dc.day ~= key then dc = { day = key, best = 0, done = false, runs = 0 }; S.data.dc = dc end
    return { day = key, chapter = ch, mods = mods, danger = 2, state = dc }
end
function M.DcMod(id) for _, m in ipairs(D.DC_MODS) do if m.id == id then return m end end end
return M
