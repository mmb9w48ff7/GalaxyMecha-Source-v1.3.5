-- Anim.lua
-- 场景摆放的程序化动画。公式与 preview/src/app.js 中 evalAnim 一一对应，
-- 保证 HTML 预览与引擎内看到的动作一致。
-- 返回：x, y, z, yaw, pitch, roll, scale（角度为度）

local Anim = {}

local TAU = math.pi * 2

local function PingPong(x)
    local f = x % 2
    if f < 1 then
        return f, 1
    end
    return 2 - f, -1
end

function Anim.Eval(item, t)
    local p = item.pos
    local x, y, z = p[1], p[2], p[3]
    local yaw, pitch, roll, s = item.yaw or 0, 0, 0, item.scale or 1
    local a = item.anim
    if not a then
        return x, y, z, yaw, pitch, roll, s
    end
    local ph = a.phase or 0
    local kind = a.type
    if kind == "bob" then
        y = y + a.amp * math.sin(t * a.speed * TAU + ph)
    elseif kind == "spin" then
        yaw = yaw + a.speed * t
        if a.amp then
            y = y + (a.lift or 0) + a.amp * math.sin(t * 1.3 + ph)
        end
    elseif kind == "idle" then
        y = y + a.amp * math.abs(math.sin(t * a.speed * TAU + ph))
        yaw = yaw + a.sway * math.sin(t * a.speed * math.pi + ph)
    elseif kind == "sway" then
        yaw = yaw + a.amp * math.sin(t * a.speed * TAU + ph)
    elseif kind == "pulse" then
        s = s * (1 + a.amp * math.sin(t * a.speed * TAU + ph))
    elseif kind == "hover" then
        y = y + a.amp * math.sin(t * a.speed * TAU)
        roll = a.roll * math.sin(t * a.speed * math.pi + 1)
    elseif kind == "chase" then
        x = x + a.ax * math.sin(t * a.speed * TAU)
        z = z + a.az * math.sin(t * a.speed * TAU * 0.7 + 1)
        roll = -a.roll * math.cos(t * a.speed * TAU)
    elseif kind == "drift" then
        local span = a.max - a.min
        local zz = z + a.vel * t
        z = a.min + ((zz - a.min) % span)
        yaw = yaw + a.spin * t
        pitch = a.tumble * t
    elseif kind == "walk" then
        local k, dir = PingPong(t * a.speed + ph)
        local to = a.to
        local dx, dz = (to[1] - p[1]) * dir, (to[3] - p[3]) * dir
        x = p[1] + (to[1] - p[1]) * k
        y = p[2] + (to[2] - p[2]) * k
        z = p[3] + (to[3] - p[3]) * k
        yaw = math.deg(math.atan(dx, dz))
        y = y + 0.05 * math.abs(math.sin(t * 9 + ph))
    end
    return x, y, z, yaw, pitch, roll, s
end

return Anim
