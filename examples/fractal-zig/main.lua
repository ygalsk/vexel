-- Fractal viewer — hybrid Zig+Lua example.
-- Heavy computation in Zig (fractal.render_buffer), UI and controls in Lua.
-- Run with: zig build run-fractal-zig (NOT zig build run -- .)
-- Controls: m = Mandelbrot, j = Julia, r = reset zoom, +/- = zoom speed, q = quit

if not fractal then
    error("This example requires the fractal-zig binary.\n"
       .. "Run: zig build run-fractal-zig\n"
       .. "(The 'fractal' module is compiled from Zig, not available in standalone vexel)")
end

local W, H = 1920, 1080

-- Fractal state
local is_julia = false
local zoom = 1.0
local zoom_speed = 0.3
local center_x, center_y = -0.7435669, 0.1314023  -- classic spiral
local color_offset = 0.0

-- Julia parameter (animated)
local julia_angle = 0.0
local julia_cr, julia_ci = -0.7, 0.27015

local sin, cos = math.sin, math.cos

function engine.load()
    engine.graphics.set_resolution(W, H)
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
end

function engine.draw()
    -- Compute and blit the entire frame in Zig — pixels never touch Lua
    fractal.render_buffer(zoom, center_x, center_y, 32,
        is_julia, color_offset, julia_cr, julia_ci)

    -- HUD overlay
    local mode_label = is_julia and "Julia" or "Mandelbrot"
    engine.graphics.draw_text(1, 0,
        string.format("%s  zoom: %.0fx  [Zig compute]", mode_label, zoom), 0xCCCCCC)
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
