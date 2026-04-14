-- Fractal viewer demo — Mandelbrot & Julia sets
-- Exercises the bulk pixel.buffer() API with full-screen per-pixel rendering.
-- Controls: m = Mandelbrot, j = Julia, r = reset zoom, +/- = zoom speed, q = quit

local W, H = 1920, 1080
local pixels = {}
local MAX_ITER = 32

-- Fractal state
local mode = "mandelbrot"  -- "mandelbrot" or "julia"
local zoom = 1.0
local zoom_speed = 0.3
local center_x, center_y = -0.7435669, 0.1314023  -- classic spiral
local color_offset = 0.0

-- Julia parameter (animated)
local julia_angle = 0.0
local julia_cr, julia_ci = -0.7, 0.27015

-- Color palette: smooth sine-wave RGB
local function make_color(iter, max_iter)
    if iter >= max_iter then return 0x000000 end
    local t = iter / max_iter
    t = t + color_offset
    local r = math.floor(127.5 * (1 + math.sin(6.2832 * t + 0.0)))
    local g = math.floor(127.5 * (1 + math.sin(6.2832 * t + 2.094)))
    local b = math.floor(127.5 * (1 + math.sin(6.2832 * t + 4.189)))
    return r * 65536 + g * 256 + b
end

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
    if mode == "julia" then
        julia_angle = julia_angle + dt * 0.15
        julia_cr = 0.7885 * math.cos(julia_angle)
        julia_ci = 0.7885 * math.sin(julia_angle)
    end
end

function engine.draw()
    -- Compute fractal
    local scale = 3.5 / (zoom * W)
    local aspect = H / W

    for py = 0, H - 1 do
        local row_offset = py * W
        for px = 0, W - 1 do
            local x0, y0

            if mode == "mandelbrot" then
                x0 = center_x + (px - W * 0.5) * scale
                y0 = center_y + (py - H * 0.5) * scale * (W / H)
            else
                x0 = (px - W * 0.5) * scale * 2.5
                y0 = (py - H * 0.5) * scale * 2.5 * (W / H)
            end

            local zr, zi = x0, y0
            local cr, ci
            if mode == "mandelbrot" then
                cr, ci = x0, y0
                zr, zi = 0, 0
            else
                cr, ci = julia_cr, julia_ci
            end

            local iter = 0
            while iter < MAX_ITER do
                local zr2 = zr * zr
                local zi2 = zi * zi
                if zr2 + zi2 > 4.0 then break end
                zi = 2 * zr * zi + ci
                zr = zr2 - zi2 + cr
                iter = iter + 1
            end

            pixels[row_offset + px + 1] = make_color(iter, MAX_ITER)
        end
    end

    -- Blit the whole framebuffer in one call
    engine.graphics.set_layer(0)
    engine.graphics.pixel.buffer(pixels, 0, 0, W, H)

    -- HUD overlay
    local mode_label = mode == "mandelbrot" and "Mandelbrot" or "Julia"
    engine.graphics.draw_text(1, 0,
        string.format("%s  zoom: %.0fx", mode_label, zoom), 0xCCCCCC)
    engine.graphics.draw_text(1, 1, "[m]andelbrot  [j]ulia  [r]eset  +/-  [q]uit", 0x666666)
end

function engine.on_key(key, action)
    if action ~= "press" then return end
    if key == "q" then engine.quit()
    elseif key == "m" then
        mode = "mandelbrot"
        zoom = 1.0
        center_x, center_y = -0.7435669, 0.1314023
    elseif key == "j" then
        mode = "julia"
        zoom = 1.0
    elseif key == "r" then
        zoom = 1.0
    elseif key == "equal" or key == "kp_add" then
        zoom_speed = math.min(zoom_speed + 0.1, 2.0)
    elseif key == "minus" or key == "kp_subtract" then
        zoom_speed = math.max(zoom_speed - 0.1, 0.05)
    end
end
