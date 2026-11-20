-- Util.lua
-- 向量与角度工具（向量用 {x, y, z} 普通表，避免每帧创建大量引擎对象）。
-- 角度约定与 UrhoX 的 Quaternion(pitch, yaw, roll) 一致：pitch 为正时机头向下。
local U = {}
U.DEG = math.pi / 180

function U.clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end
function U.lerp(a, b, t) return a + (b - a) * t end
function U.add(a, b) return { a[1] + b[1], a[2] + b[2], a[3] + b[3] } end
function U.sub(a, b) return { a[1] - b[1], a[2] - b[2], a[3] - b[3] } end
function U.mul(a, s) return { a[1] * s, a[2] * s, a[3] * s } end
function U.dot(a, b) return a[1] * b[1] + a[2] * b[2] + a[3] * b[3] end
function U.len(a) return math.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3]) end
function U.dist(a, b) return U.len(U.sub(a, b)) end
function U.norm(a) local l = U.len(a); if l < 1e-6 then l = 1 end return { a[1] / l, a[2] / l, a[3] / l } end
function U.copy(a) return { a[1], a[2], a[3] } end
function U.fwdOf(yaw, pitch)
    local cp = math.cos(pitch * U.DEG)
    return { math.sin(yaw * U.DEG) * cp, -math.sin(pitch * U.DEG), math.cos(yaw * U.DEG) * cp }
end
function U.rightOf(yaw) return { math.cos(yaw * U.DEG), 0, -math.sin(yaw * U.DEG) } end
function U.anglesTo(d)
    local n = U.norm(d)
    return math.deg(math.atan(n[1], n[3])), -math.deg(math.asin(U.clamp(n[2], -1, 1)))
end
function U.wrap180(a) a = (a + 180) % 360; return a - 180 end
function U.rand(a, b) return a + math.random() * (b - a) end
function U.segHit(a, b, c, r)
    local ab, ac = U.sub(b, a), U.sub(c, a)
    local l2 = U.dot(ab, ab)
    local t = l2 > 0 and U.clamp(U.dot(ac, ab) / l2, 0, 1) or 0
    return U.dist(U.add(a, U.mul(ab, t)), c) < r
end
function U.V3(a) return Vector3(a[1], a[2], a[3]) end
-- 千分位格式化
function U.fmt(n)
    local s = tostring(math.floor(n + 0.5))
    local neg = s:sub(1, 1) == "-"
    if neg then s = s:sub(2) end
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if out:sub(1, 1) == "," then out = out:sub(2) end
    return (neg and "-" or "") .. out
end
function U.byId(list, id)
    for _, x in ipairs(list) do if x.id == id then return x end end
    return nil
end
return U
