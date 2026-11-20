-- App.lua：应用流程（机库 <-> 战斗）、事件与输入衔接
local D = require("cosmic.Data")
local U = require("cosmic.Util")
local S = require("cosmic.Save")
local Snd = require("cosmic.Sound")
local Run = require("cosmic.Run")
local Mech = require("cosmic.Mech")
local UI = require("cosmic.UI")
local Screens = require("cosmic.Screens")
local Pages = require("cosmic.Pages")
local Meta = require("cosmic.Meta")
local App = { page = "hub", wk = { tab = "cards", tier = 0, form = "homing", elem = "light", v = 0 }, state = "hub", chapterSel = 1, dangerSel = 1, settings = false, msg = nil, msgT = 0, paused = false, pending = nil, t = 0 }
local vg_, hubMech_
local ORDER = { S = 0, SS = 1, SSR = 2, SSSR = 3 }

function App.Toast(msg) App.msg = msg; App.msgT = 2.5 end
function App.ApplySound() Snd.enabled = S.data.sound; Snd.music = S.data.music; Snd.Music(App.state == "run" and "battle" or "hub"); S.Write() end
local function owned()
    local list = {}; for _, m in ipairs(D.MECHS) do if S.data.mechs[m.id] then list[#list + 1] = m end end
    table.sort(list, function(a, b) return ORDER[a.grade] > ORDER[b.grade] end); return list
end
local function buildHubMech()
    if hubMech_ then hubMech_.root:Remove(); hubMech_ = nil end
    hubMech_ = Mech.Build(Run.Content(), S.data.mech)
end
function App.EnterHub()
    App.state = "hub"; App.page = "hub"; App.paused = false; Run.Clear(); Run.ApplyEnv(D.CHAPTERS[1].env); Run.buildStars(); buildHubMech()
    Snd.Music("hub")
end
function App.CycleMech(dir)
    local list = owned(); local idx = 1; for i, m in ipairs(list) do if m.id == S.data.mech then idx = i end end
    idx = ((idx - 1 + dir) % #list) + 1; S.data.mech = list[idx].id; S.Write(); App.pending = buildHubMech
end
function App.Sfx(name) Snd.Sfx(name, App.t) end
function App.StartRun(endless)
    local sv = S.data; local ch = endless and (App.chapterSel <= sv.chapter and App.chapterSel or 1) or App.chapterSel
    App.pending = function()
        if hubMech_ then hubMech_.root:Remove(); hubMech_ = nil end
        App.state = "run"; App.paused = false; Run.Start(ch, { danger = App.dangerSel, endless = endless }); App.inp = { jx = 0, jy = 0, camdx = 0 }
    end
end
function App.StartDaily(dc)
    App.pending = function()
        if hubMech_ then hubMech_.root:Remove(); hubMech_ = nil end
        App.state = "run"; App.paused = false; App.page = "hub"; Run.Start(dc.chapter, { daily = true, mods = dc.mods, danger = dc.danger }); App.inp = { jx = 0, jy = 0, camdx = 0 }
    end
end
function App.ToHub() App.pending = App.EnterHub end

function App.Start()
    print("=== 宇宙银河机甲 Start ===")
    math.randomseed(os.time()); S.Load(); Meta.DailyReset()
    Run.Init(); Run.Activate()
    vg_ = nvgCreate(1); UI.Init(vg_)
    Snd.enabled, Snd.music = S.data.sound, S.data.music
    App.chapterSel = math.min(S.data.chapter, #D.CHAPTERS); App.dangerSel = math.min(S.data.danger or 1, S.data.dangerMax)
    App.EnterHub()
    SubscribeToEvent("Update", "HandleUpdate"); SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
end
function App.Stop() S.Write() end
-- 脚本运行时出错：保存存档，回到机库；连续出错不再重复处理
function App.OnError(err)
    App.errN = (App.errN or 0) + 1
    if App.errN == 1 or App.errN % 120 == 0 then pcall(S.Write); if App.state == "run" then App.pending = App.EnterHub; App.Toast("出现异常，已返回机库") end end
end

function App.Update(dt)
    dt = math.min(dt, 0.05); App.t = App.t + dt
    Snd.Tick()
    if App.msgT > 0 then App.msgT = App.msgT - dt end
    if App.pending then local f = App.pending; App.pending = nil; f() end
    if App.state == "hub" then
        if hubMech_ then
            hubMech_.root.rotation = Quaternion(0, App.t * 28, 0); hubMech_.root.position = Vector3(0, 0, 0)
            Mech.Update(hubMech_, { fk = 0, sk = 0, uk = 0, af = 0, dashing = false, tg = false, yawL = 0, dwn = 0, t = App.t }, dt)
        end
        Run.camNode.position = Vector3(-2.2, 3.6, -11.5); Run.camNode:LookAt(Vector3(-2.2 + 0.0, 2.6, 0))
    else
        local R = Run.R; if not R then return end
        if App.paused then return end
        local inp = App.inp or { jx = 0, jy = 0, camdx = 0 }
        if App.cast then inp.skill = true; App.cast = false end
        if App.nitro then inp.nitro = true; App.nitro = false end
        Run.Update(R, dt, inp); Run.UpdateCamera(R, dt)
        App.inp = { jx = inp.jx, jy = inp.jy, camdx = 0 }
    end
end

function App.Render()
    local w, h = graphics:GetWidth(), graphics:GetHeight()
    UI.BeginFrame(w, h)
    nvgBeginFrame(vg_, w, h, 1.0); UI.Frame()
    if App.state == "hub" then
        if App.page == "work" then Pages.Work(App) elseif App.page == "pilots" then Pages.Pilots(App) elseif App.page == "summon" then Pages.Summon(App)
        elseif App.page == "daily" then Pages.Daily(App) elseif App.page == "about" then Pages.About(App) else Screens.Hub(App) end
        if App.msg and App.msgT > 0 and App.page ~= "hub" then UI.Text(UI.lw / 2, 1010, App.msg, 34, UI.COL.teal, NVG_ALIGN_CENTER + NVG_ALIGN_TOP) end
    else
        local R = Run.R
        if R then
            if R.over and R.result then Screens.Result(R, App)
            elseif R.choosing then Screens.LevelUp(R, App)
            elseif App.paused then Screens.Pause(R, App)
            else Screens.Hud(R, App); App.inp = UI.RunInput() end
        end
    end
    UI.EndFrame(); nvgEndFrame(vg_)
end
return App
