local modes = {
    { name = "maze",    feed = 0.055, kill = 0.062 },
    { name = "coral",   feed = 0.029, kill = 0.057 },
    { name = "waves",   feed = 0.014, kill = 0.054 },
    { name = "mitosis", feed = 0.039, kill = 0.058 },
}

local mode = 1
local mouse_px, mouse_py = -1, -1
local mouse_down = false
local reset_flag = false
local w, h = 320, 180

function engine.load()
    engine.graphics.set_resolution(w, h)
end

function engine.draw()
    local m = modes[mode]
    engine.graphics.set_layer(0)
    engine.graphics.pixel.shade("rd", m.feed, m.kill,
        mouse_px, mouse_py,
        mouse_down and 1 or 0,
        reset_flag and 1 or 0)
    reset_flag = false

    -- HUD
    local label = "[1]maze [2]coral [3]waves [4]mitosis  [r]reset  [esc]quit"
    local mode_label = "mode: " .. modes[mode].name
    engine.graphics.draw_text(4, 2, label, 0x888888)
    engine.graphics.draw_text(4, 12, mode_label, 0xFFFFFF)
end

function engine.on_key(key, action)
    if action ~= "press" then return end
    if key == "1" then mode = 1
    elseif key == "2" then mode = 2
    elseif key == "3" then mode = 3
    elseif key == "4" then mode = 4
    elseif key == "r" then reset_flag = true
    elseif key == "escape" then engine.quit()
    end
end

function engine.on_mouse(x, y, button, action)
    mouse_px = x
    mouse_py = y
    if button == "left" then
        if action == "press" then mouse_down = true
        elseif action == "release" then mouse_down = false
        end
    end
end
