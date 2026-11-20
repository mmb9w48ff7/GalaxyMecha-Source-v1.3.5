-- PreviewWorld.lua
-- 资产图鉴的展示场景：转台 + 底座 + 环绕相机。切换模型时清空 Content 节点重建。
-- 场景数据来自 voxeldata/Scenes.lua（与 HTML 预览共用）。

local VoxelBuilder = require("game.VoxelBuilder")
local Anim = require("game.Anim")
local OrbitCamera = require("game.OrbitCamera")

local SCENES = require("voxeldata.Scenes")

local World = {}

local scene_ = nil
local content_ = nil
local zone_ = nil
local keyLight_, fillLight_ = nil, nil
local keyNode_, fillNode_ = nil, nil
local renderPath_ = nil
local viewport_ = nil
local items_ = {}
local starsNode_ = nil
local time_ = 0
local currentId_ = nil

World.camera = nil

local function Col(t)
    return Color(t[1], t[2], t[3])
end

local function Dir(t)
    return Vector3(t[1], t[2], t[3]):Normalized()
end

function World.Init()
    print("[World] Init")
    scene_ = Scene()
    scene_:CreateComponent("Octree")

    local zoneNode = scene_:CreateChild("Zone")
    zone_ = zoneNode:CreateComponent("Zone")
    zone_.boundingBox = BoundingBox(Vector3(-1000, -1000, -1000), Vector3(1000, 1000, 1000))

    keyNode_ = scene_:CreateChild("KeyLight")
    keyLight_ = keyNode_:CreateComponent("Light")
    keyLight_.lightType = LIGHT_DIRECTIONAL
    keyLight_.shadowCascade = CascadeParameters(10.0, 30.0, 70.0, 0.0, 0.8)
    keyLight_.shadowBias = BiasParameters(0.00025, 0.5)

    fillNode_ = scene_:CreateChild("FillLight")
    fillLight_ = fillNode_:CreateComponent("Light")
    fillLight_.lightType = LIGHT_DIRECTIONAL
    fillLight_.castShadows = false

    renderer.shadowMapSize = 2048
    renderer.shadowQuality = SHADOWQUALITY_PCF_24BIT

    World.camera = OrbitCamera.New(scene_)
    viewport_ = Viewport:new(scene_, World.camera.camera)
    renderPath_ = viewport_:GetRenderPath()
    renderPath_:Append(cache:GetResource("XMLFile", "PostProcess/Bloom.xml"))
    renderPath_:Append(cache:GetResource("XMLFile", "PostProcess/FXAA3.xml"))

    content_ = scene_:CreateChild("Content")
    print("[World] Init 完成")
end

local function ApplyEnv(env)
    zone_.ambientColor = Col(env.ambient)
    zone_.fogColor = Col(env.bg)
    zone_.fogStart = env.fog[1]
    zone_.fogEnd = env.fog[2]
    keyNode_.direction = Dir(env.key.dir)
    keyLight_.color = Col(env.key.color)
    keyLight_.brightness = env.key.brightness
    keyLight_.castShadows = env.shadows and true or false
    fillNode_.direction = Dir(env.fill.dir)
    fillLight_.color = Col(env.fill.color)
    fillLight_.brightness = env.fill.brightness
    renderPath_:SetShaderParameter("BloomThreshold", Variant(env.bloom.threshold))
    renderPath_:SetShaderParameter("BloomMix", Variant(Vector2(1.0, env.bloom.mix)))
end

local function ApplyTransform(entry, t)
    local x, y, z, yaw, pitch, roll, s = Anim.Eval(entry.def, t)
    entry.node.position = Vector3(x, y, z)
    entry.node.rotation = Quaternion(pitch, yaw, roll)
    entry.node:SetScale(s)
end

local function Clear()
    content_:RemoveAllChildren()
    items_ = {}
    starsNode_ = nil
    time_ = 0
end

local function Populate(defs, starsDef)
    for i, def in ipairs(defs) do
        local node = VoxelBuilder.Build(content_, def.model, def.model .. "_" .. i)
        local entry = { node = node, def = def }
        items_[#items_ + 1] = entry
        ApplyTransform(entry, 0)
    end
    if starsDef then
        starsNode_ = VoxelBuilder.BuildStars(content_, starsDef)
    end
end

-- 切换到图鉴场景的视口（游戏飞行用 Space 自己的视口）
function World.Activate()
    renderer:SetViewport(0, viewport_)
end

function World.GetSceneDef(id)
    for _, sc in ipairs(SCENES.list) do
        if sc.id == id then return sc end
    end
    return nil
end

-- 图鉴取景：与 app.js 的 galleryLayout 相同
function World.GalleryLayout(id)
    local md = VoxelBuilder.LoadData(id)
    local sc = md.scale
    local sx, sy, sz = md.size[1] * sc, md.size[2] * sc, md.size[3] * sc
    local small = md.category == "crew" or md.category == "enemy" or md.category == "item"
    local defs = {}
    local base = 0
    if small then
        local foot = math.max(sx, sz)
        local ps = math.max(0.6, foot * 1.3 / 2.4)
        defs[#defs + 1] = { model = "sys_pedestal", pos = { 0, 0, 0 }, yaw = 0, scale = ps }
        base = 0.3 * ps
    end
    local posY = (md.origin[2] == 0) and base or 0
    defs[#defs + 1] = { model = id, pos = { 0, posY, 0 }, yaw = 0, scale = 1, anim = { type = "spin", speed = 16 } }
    local center = posY + (md.size[2] / 2 - md.origin[2]) * sc
    local radius = 0.5 * math.sqrt(sx * sx + sy * sy + sz * sz)
    local fov = 38
    local dist = math.max(1.6, radius / math.tan(math.rad(fov) / 2) * 1.9)
    local cam = { target = { 0, center, 0 }, yaw = 28, pitch = 14, dist = dist, fov = fov,
                  minDist = dist * 0.45, maxDist = dist * 2.2, minPitch = -20, maxPitch = 75 }
    return defs, cam
end

function World.ShowGallery(id)
    print("[World] 图鉴: " .. id)
    Clear()
    currentId_ = "gallery"
    ApplyEnv(SCENES.gallery.env)
    local defs, cam = World.GalleryLayout(id)
    Populate(defs, nil)
    World.camera:Configure(cam)
end

function World.ShowScene(id)
    local sc = World.GetSceneDef(id)
    if not sc then
        print("[World] 未找到场景: " .. tostring(id))
        return
    end
    print("[World] 场景: " .. sc.name .. "（" .. #sc.items .. " 个物件）")
    Clear()
    currentId_ = id
    ApplyEnv(sc.env)
    Populate(sc.items, sc.stars)
    World.camera:Configure(sc.camera)
    local st = VoxelBuilder.GetStats()
    print(string.format("[World] 累计生成 %d 个模型，%d 个合并面，%d 个顶点", st.models, st.quads, st.vertices))
end

function World.Update(dt, pointerOverUI)
    time_ = time_ + dt
    for _, entry in ipairs(items_) do
        if entry.def.anim then
            ApplyTransform(entry, time_)
        end
    end
    World.camera:Update(dt, pointerOverUI)
    if starsNode_ then
        -- 星空跟随相机，始终处于无限远处
        starsNode_.position = World.camera.node.position
    end
end

function World.GetCurrentId()
    return currentId_
end

return World
