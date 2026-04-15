-- SDF raymarching demo: side-by-side Lua vs Zig.
-- Press TAB to toggle. Watch the FPS.

local floor = math.floor
local sqrt = math.sqrt
local cos = math.cos
local sin = math.sin
local max = math.max
local min = math.min

----------------------------------------------------------------------
-- Pure-Lua raymarcher (same algorithm as sdf.zig)
----------------------------------------------------------------------

local MAX_STEPS = 64
local MAX_DIST = 50.0
local SURF_DIST = 0.001

local function clamp01(x)
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

local function normalize(x, y, z)
    local len = sqrt(x * x + y * y + z * z)
    if len < 1e-10 then return 0, 1, 0 end
    return x / len, y / len, z / len
end

local function dot(ax, ay, az, bx, by, bz)
    return ax * bx + ay * by + az * bz
end

local function sd_sphere(px, py, pz, r)
    return sqrt(px * px + py * py + pz * pz) - r
end

local function sd_torus(px, py, pz, r1, r2)
    local q0 = sqrt(px * px + pz * pz) - r1
    return sqrt(q0 * q0 + py * py) - r2
end

local function sd_plane(py)
    return py + 1.0
end

local function lua_scene(px, py, pz, time)
    local c = cos(time)
    local s = sin(time)
    local tx = px * c - pz * s
    local tz = px * s + pz * c
    local torus = sd_torus(tx, py, tz, 0.8, 0.25)

    local sx = px - 1.5
    local sy = py - sin(time * 1.3) * 0.3
    local sphere = sd_sphere(sx, sy, pz, 0.5)

    local plane = sd_plane(py)

    return min(min(torus, sphere), plane)
end

local function lua_march(rox, roy, roz, rdx, rdy, rdz, time)
    local t = 0
    for _ = 1, MAX_STEPS do
        local px = rox + rdx * t
        local py = roy + rdy * t
        local pz = roz + rdz * t
        local d = lua_scene(px, py, pz, time)
        t = t + d
        if d < SURF_DIST or t > MAX_DIST then break end
    end
    return t
end

local function lua_normal(px, py, pz, time)
    local e = 0.001
    local d = lua_scene(px, py, pz, time)
    return normalize(
        lua_scene(px + e, py, pz, time) - d,
        lua_scene(px, py + e, pz, time) - d,
        lua_scene(px, py, pz + e, time) - d
    )
end

local function lua_render_pixel(px, py, w, h, time)
    local aspect = w / h
    local u = (2.0 * px / w - 1.0) * aspect
    local v = 1.0 - 2.0 * py / h

    local rox, roy, roz = 0, 0.5, -3.5
    local rdx, rdy, rdz = normalize(u, v, 1.5)

    local t = lua_march(rox, roy, roz, rdx, rdy, rdz, time)

    if t >= MAX_DIST then
        local sky = 0.3 + 0.4 * clamp01(v + 0.5)
        local ri = floor(clamp01(sky * 0.3) * 255)
        local gi = floor(clamp01(sky * 0.4) * 255)
        local bi = floor(clamp01(sky * 0.7) * 255)
        return ri * 65536 + gi * 256 + bi
    end

    local hx = rox + rdx * t
    local hy = roy + rdy * t
    local hz = roz + rdz * t
    local nx, ny, nz = lua_normal(hx, hy, hz, time)

    local lx, ly, lz = normalize(-0.5, 0.8, -0.6)
    local diff = clamp01(dot(nx, ny, nz, lx, ly, lz))

    -- Shadow
    local sox = hx + nx * 0.02
    local soy = hy + ny * 0.02
    local soz = hz + nz * 0.02
    local shadow_t = lua_march(sox, soy, soz, lx, ly, lz, time)
    local shadow = shadow_t < MAX_DIST and 0.3 or 1.0

    -- Specular
    local dn = 2.0 * dot(rdx, rdy, rdz, nx, ny, nz)
    local rx = rdx - dn * nx
    local ry = rdy - dn * ny
    local rz = rdz - dn * nz
    local spec = clamp01(dot(rx, ry, rz, lx, ly, lz)) ^ 16

    -- Material: classify by nearest SDF (avoids threshold artifacts at silhouettes)
    local c_time = cos(time)
    local s_time = sin(time)
    local torus_d = sd_torus(
        hx * c_time - hz * s_time, hy, hx * s_time + hz * c_time,
        0.8, 0.25
    )
    local sphere_d = sd_sphere(hx - 1.5, hy - sin(time * 1.3) * 0.3, hz, 0.5)
    local plane_d = sd_plane(hy)

    local br, bg, bb
    if torus_d < sphere_d and torus_d < plane_d then
        br, bg, bb = 0.9, 0.3, 0.1
    elseif sphere_d < plane_d then
        br, bg, bb = 0.2, 0.5, 0.9
    else
        local check = ((floor(hx) + floor(hz)) % 2 == 0) and 0.5 or 0.3
        -- handle negative floor
        if ((floor(hx) + floor(hz)) % 2) < 0 then
            check = ((floor(hx) + floor(hz)) % 2 + 2 == 0) and 0.5 or 0.3
        end
        br, bg, bb = check, check, check
    end

    local ambient = 0.15
    local light = ambient + diff * shadow * 0.85
    local ri = floor(clamp01(br * light + spec * shadow * 0.4) * 255)
    local gi = floor(clamp01(bg * light + spec * shadow * 0.3) * 255)
    local bi = floor(clamp01(bb * light + spec * shadow * 0.2) * 255)
    return ri * 65536 + gi * 256 + bi
end

----------------------------------------------------------------------
-- Demo
----------------------------------------------------------------------

local W, H = 512, 288
local time = 0
local use_zig = true
local pixels = {}

-- FPS tracking
local frame_count = 0
local fps_timer = 0
local fps = 0

function engine.load()
    engine.graphics.set_resolution(W, H)
    for i = 1, W * H do
        pixels[i] = 0
    end
end

function engine.update(dt)
    time = time + dt

    -- FPS counter
    frame_count = frame_count + 1
    fps_timer = fps_timer + dt
    if fps_timer >= 0.5 then
        fps = frame_count / fps_timer
        frame_count = 0
        fps_timer = 0
    end

    if not use_zig then
        local idx = 1
        for y = 0, H - 1 do
            for x = 0, W - 1 do
                pixels[idx] = lua_render_pixel(x, y, W, H, time)
                idx = idx + 1
            end
        end
    end
end

function engine.draw()
    engine.graphics.set_layer(0)
    if use_zig then
        engine.graphics.pixel.shade("sdf", time)
    else
        engine.graphics.pixel.buffer(pixels, 0, 0, W, H)
    end

    local mode = use_zig and "ZIG" or "LUA"
    local label = string.format(
        "MODE: %s  |  FPS: %.1f  |  %dx%d = %d px/frame  |  SDF raymarching",
        mode, fps, W, H, W * H
    )
    engine.graphics.draw_text(1, 0, label, 0xFFFFFF, 0x000000)
    engine.graphics.draw_text(1, 1, "TAB: toggle  |  ESC: quit", 0xAAAAAA, 0x000000)
end

function engine.on_key(key, action)
    if action ~= "press" then return end
    if key == "tab" then
        use_zig = not use_zig
    elseif key == "escape" then
        engine.quit()
    end
end
