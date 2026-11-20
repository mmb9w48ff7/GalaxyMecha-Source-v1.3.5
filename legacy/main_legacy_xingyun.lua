-- main.lua
-- 陨星银河：体素风太空冒险（玩法参考《浴火银河 2》）
-- 入口：初始化图鉴场景、太空场景与 UI，进入标题画面。
--
-- 目录：
--   game/Layout.lua        设计分辨率 1920x1080 适配
--   game/Util.lua          向量与角度工具
--   game/Save.lua          存档与派生属性（舰员加成、货舱、价格）
--   game/VoxelBuilder.lua  体素数据 -> CustomGeometry（原型 + Clone 复用）
--   game/Space.lua         飞行模拟：星系、玩家、海贼 AI、武器、采矿、掉落、粒子、相机
--   game/Hud.lua           飞行 HUD：摇杆、油门、按钮、准星、目标框、雷达
--   game/Game.lua          流程：标题、星港（交易 / 任务 / 船坞 / 召唤）、星图、暂停、图鉴
--   game/Theme.lua         体素风 UI 配色与控件
--   game/PixelIcon.lua     像素图标控件
--   game/PreviewWorld.lua  资产图鉴展示场景（含 Anim / OrbitCamera）
--   voxeldata/             由 tools/build_voxels.py 生成的模型、图鉴、玩法数据

local UI = require("urhox-libs/UI")
local Layout = require("game.Layout")
local World = require("game.PreviewWorld")
local Space = require("game.Space")
local Game = require("game.Game")

local lastW_, lastH_ = 0, 0

function Start()
    print("=== 陨星银河 Start ===")
    local L = Layout.Compute()
    print(string.format("屏幕 %dx%d，DPR %.2f，UI 缩放 %.3f，逻辑尺寸 %.0fx%.0f",
        L.physW, L.physH, L.dpr, L.scale, L.logicalW, L.logicalH))
    math.randomseed(os.time())

    World.Init()
    Space.Init()

    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf", bold = "Fonts/MiSans-Bold.ttf" } },
        },
        -- 设计分辨率 1920x1080：1 个 UI 基准像素 = 1 个设计像素
        scale = function()
            return Layout.Compute().scale
        end,
    })

    Game.Init()
    SubscribeToEvent("Update", "HandleUpdate")
    print("=== Start 完成 ===")
end

function Stop()
    UI.Shutdown()
end

function HandleUpdate(eventType, eventData)
    local dt = math.min(eventData["TimeStep"]:GetFloat(), 0.05)
    local w, h = graphics:GetWidth(), graphics:GetHeight()
    if w ~= lastW_ or h ~= lastH_ then
        if lastW_ ~= 0 then
            print(string.format("[main] 屏幕尺寸变化 %dx%d", w, h))
            UI.Layout()
        end
        lastW_, lastH_ = w, h
    end
    Game.Update(dt, UI.IsPointerOverUI())
end
