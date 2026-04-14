-- Fractal viewer demo — Mandelbrot & Julia sets
-- Exercises the bulk pixel.buffer() API with full-screen per-pixel rendering.
-- Controls: m = Mandelbrot, j = Julia, r = reset zoom, +/- = zoom speed, q = quit

local W, H = 1920, 1080
local pixels = {}
local MAX_ITER = 32

-- Localize math functions — avoids global table lookup in hot loops
local sin, cos, floor = math.sin, math.cos, math.floor

-- Fractal state
local is_julia = false
local zoom = 1.0
local zoom_speed = 0.3
local center_x, center_y = -0.7435669, 0.1314023  -- classic spiral
local color_offset = 0.0

-- Julia parameter (animated)
local julia_angle = 0.0
local julia_cr, julia_ci = -0.7, 0.27015

function engine.load()
    engine.graphics.set_resolution(W, H)
    -- Pre-fill pixel table
    for i = 1, W * H do
        pixels[i] = 0
    end
end

function engine.update(dt)
    -- Animate zoom (exponential)
    zoom = zoom * (1.0 + zoom_speed * dt)

    -- Animate color cycling
    color_offset = color_offset + dt * 0.1

    -- In Julia mode, slowly rotate the c parameter
    if is_julia then
        julia_angle = julia_angle + dt * 0.15
        julia_cr = 0.7885 * cos(julia_angle)
        julia_ci = 0.7885 * sin(julia_angle)
    end

    -- Compute fractal (moved from draw so profiling separates compute from upload)
    local scale = 3.5 / (zoom * W)
    local half_W = W * 0.5
    local half_H = H * 0.5
    local aspect_scale = scale * (W / H)
    local max_iter = MAX_ITER
    local co = color_offset

    local function make_color(iter)
        if iter >= max_iter then return 0 end
        local t = iter / max_iter + co
        local r = floor(127.5 * (1 + sin(6.2832 * t)))
        local g = floor(127.5 * (1 + sin(6.2832 * t + 2.094)))
        local b = floor(127.5 * (1 + sin(6.2832 * t + 4.189)))
        return r * 65536 + g * 256 + b
    end

    if is_julia then
        local cr, ci = julia_cr, julia_ci
        local sx = scale * 2.5
        local sy = sx * (W / H)
        for py = 0, H - 1 do
            local row_offset = py * W
            local y0 = (py - half_H) * sy
            for px = 0, W - 1 do
                local zr = (px - half_W) * sx
                local zi = y0
                local iter = 0
                while iter < max_iter do
                    local zr2 = zr * zr
                    local zi2 = zi * zi
                    if zr2 + zi2 > 4.0 then break end
                    zi = 2 * zr * zi + ci
                    zr = zr2 - zi2 + cr
                    iter = iter + 1
                end
                pixels[row_offset + px + 1] = make_color(iter)
            end
        end
    else
        local cr_base = center_x
        local ci_base = center_y
        for py = 0, H - 1 do
            local row_offset = py * W
            local ci0 = ci_base + (py - half_H) * aspect_scale
            for px = 0, W - 1 do
                local cr = cr_base + (px - half_W) * scale
                local zr, zi = 0.0, 0.0
                local iter = 0
                while iter < max_iter do
                    local zr2 = zr * zr
                    local zi2 = zi * zi
                    if zr2 + zi2 > 4.0 then break end
                    zi = 2 * zr * zi + ci0
                    zr = zr2 - zi2 + cr
                    iter = iter + 1
                end
                pixels[row_offset + px + 1] = make_color(iter)
            end
        end
    end
end

function engine.draw()
    -- Blit the whole framebuffer in one call
    engine.graphics.set_layer(0)
    engine.graphics.pixel.buffer(pixels, 0, 0, W, H)

    -- HUD overlay
    local mode_label = is_julia and "Julia" or "Mandelbrot"
    engine.graphics.draw_text(1, 0,
        string.format("%s  zoom: %.0fx", mode_label, zoom), 0xCCCCCC)
    engine.graphics.draw_text(1, 1, "[m]andelbrot  [j]ulia  [r]eset  +/-  [q]uit", 0x666666)
end

function engine.on_key(key, action)
    if action ~= "press" then return end
    if key == "q" then engine.quit()
    elseif key == "m" then
        is_julia = false
        zoom = 1.0
        center_x, center_y = -0.7435669, 0.1314023
    elseif key == "j" then
        is_julia = true
        zoom = 1.0
    elseif key == "r" then
        zoom = 1.0
    elseif key == "equal" or key == "kp_add" then
        zoom_speed = math.min(zoom_speed + 0.1, 2.0)
    elseif key == "minus" or key == "kp_subtract" then
        zoom_speed = math.max(zoom_speed - 0.1, 0.05)
    end
end
