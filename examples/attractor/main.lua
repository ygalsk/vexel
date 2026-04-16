-- Strange attractor particle demo
-- Particles follow chaotic ODEs; accumulation + fade reveals the fractal shape.

local W, H = 320, 180
local N = 4000

-- Attractor definitions: step(x,y,z,dt) -> nx,ny,nz
-- center: world coords to subtract before projecting (cx,cy,cz)
-- scale: pixels per world unit
local ATTRACTORS = {
    {
        name = "lorenz",
        step = function(x, y, z, dt)
            local dx = 10 * (y - x)
            local dy = x * (28 - z) - y
            local dz = x * y - (8/3) * z
            return x + dx*dt, y + dy*dt, z + dz*dt
        end,
        -- Lorenz lives in x∈[-20,20], z∈[2,48]; center at (0,0,25)
        -- Rotate in x-z plane, project x→screen_x, z→screen_y
        cx = 0, cy = 0, cz = 25,
        scale = 3.0,
        sim_dt = 0.008,
    },
    {
        name = "thomas",
        step = function(x, y, z, dt)
            local b = 0.208186
            return x + (-b*x + math.sin(y))*dt,
                   y + (-b*y + math.sin(z))*dt,
                   z + (-b*z + math.sin(x))*dt
        end,
        cx = 0, cy = 0, cz = 0,
        scale = 18.0,
        sim_dt = 0.04,
    },
    {
        name = "dadras",
        step = function(x, y, z, dt)
            -- a=3 b=2.7 c=1.7 d=2 e=9
            return x + (y - 3*x + 2.7*y*z)*dt,
                   y + (1.7*y - x*z + z)*dt,
                   z + (2*x*y - 9*z)*dt
        end,
        cx = 0, cy = 0, cz = 4,
        scale = 12.0,
        sim_dt = 0.008,
    },
}

local idx = 1
local px, py, pz = {}, {}, {}
local acc = {}   -- brightness accumulation [1..W*H]
local pixels = {}

-- Precomputed colormap: index 0..255 -> packed RGB
-- dark navy -> electric blue -> cyan -> white
local CMAP = {}
do
    for i = 0, 255 do
        local t = i / 255.0
        local r = math.min(255, math.floor(math.max(0, t - 0.65) / 0.35 * 220))
        local g = math.min(255, math.floor(math.max(0, t - 0.3) / 0.7 * 255))
        local b = math.min(255, math.floor(t * 255))
        CMAP[i] = r * 0x10000 + g * 0x100 + b
    end
end

local yaw = 0
local rot_speed = 0.5

local function warmup(attr)
    local x, y, z = 0.1, 0.1, 0.1
    for _ = 1, 800 do
        x, y, z = attr.step(x, y, z, attr.sim_dt)
    end
    return x, y, z
end

local function initParticles()
    local attr = ATTRACTORS[idx]
    local wx, wy, wz = warmup(attr)
    for i = 1, N do
        px[i] = wx + (math.random() - 0.5) * 0.02
        py[i] = wy + (math.random() - 0.5) * 0.02
        pz[i] = wz + (math.random() - 0.5) * 0.02
    end
    for i = 1, W * H do
        acc[i] = 0.0
        pixels[i] = 0
    end
end

function engine.load()
    engine.graphics.set_resolution(W, H)
    math.randomseed(12345)
    initParticles()
end

function engine.update(dt)
    local attr = ATTRACTORS[idx]
    yaw = yaw + rot_speed * dt

    local sdt = attr.sim_dt
    local step = attr.step

    -- Run 5 simulation steps
    for _ = 1, 5 do
        for i = 1, N do
            px[i], py[i], pz[i] = step(px[i], py[i], pz[i], sdt)
        end
    end

    -- Fade accumulation
    local fade = 1.0 - 8.0 * dt   -- ~0.867 at 60fps (8% fade per second * 1/60)
    if fade < 0.85 then fade = 0.85 end
    for i = 1, W * H do
        acc[i] = acc[i] * fade
    end

    -- Project and accumulate
    local cy_angle = math.cos(yaw)
    local sy_angle = math.sin(yaw)
    local scale = attr.scale
    local ocx, ocy, ocz = attr.cx, attr.cy, attr.cz
    local hw = W / 2
    local hh = H / 2
    _ = ocy  -- unused (y is depth axis)

    for i = 1, N do
        -- Translate to center the attractor
        local x = px[i] - ocx
        local z = pz[i] - ocz
        -- Rotate in x-z plane (Y-axis yaw)
        local rx = x * cy_angle - z * sy_angle
        local rz = x * sy_angle + z * cy_angle
        -- Project: rx -> screen_x, rz -> screen_y (z is "up" for most attractors)
        local depth = 1.0 + (py[i] - ocy) * 0.015
        local sx = math.floor(hw + rx * scale / depth + 0.5)
        local sy = math.floor(hh - rz * scale / depth + 0.5)
        if sx >= 1 and sx <= W and sy >= 1 and sy <= H then
            local ai = (sy - 1) * W + sx
            acc[ai] = math.min(1.0, acc[ai] + 0.08)
        end
    end
end

function engine.draw()
    engine.graphics.set_layer(0)

    -- Colorize accumulation buffer
    for i = 1, W * H do
        local v = acc[i]
        if v < 0.004 then
            pixels[i] = 0
        else
            pixels[i] = CMAP[math.min(255, math.floor(v * 255))]
        end
    end

    engine.graphics.pixel.buffer(pixels, 0, 0, W, H)

    local label = "  [1]lorenz  [2]thomas  [3]dadras  [</>]rotation  [spc]scatter  [esc]quit"
    engine.graphics.draw_text(4, 2, label, 0x777777)
    engine.graphics.draw_text(4, 12, "attractor: " .. ATTRACTORS[idx].name, 0xFFFFFF)
end

function engine.on_key(key, action)
    if action ~= "press" then return end
    if key == "1" then idx = 1; initParticles()
    elseif key == "2" then idx = 2; initParticles()
    elseif key == "3" then idx = 3; initParticles()
    elseif key == "right" then rot_speed = rot_speed + 0.3
    elseif key == "left" then rot_speed = rot_speed - 0.3
    elseif key == "space" then
        local attr = ATTRACTORS[idx]
        for i = 1, N do
            px[i] = px[i] + (math.random() - 0.5) * 3
            py[i] = py[i] + (math.random() - 0.5) * 3
            pz[i] = pz[i] + (math.random() - 0.5) * 3
        end
        _ = attr
    elseif key == "escape" then engine.quit()
    end
end
