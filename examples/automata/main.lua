local speed = 1.0
local reset_flag = false

function engine.load()
    engine.graphics.set_resolution(320, 180)
end

function engine.draw()
    engine.graphics.set_layer(0)
    engine.graphics.pixel.shade("automata",
        1 / 60.0,    -- dt (fixed)
        speed,
        reset_flag and 1 or 0)
    reset_flag = false

    engine.graphics.draw_text(1, 1, "  [</>]speed  [spc]new seed  [esc]quit", "777777", "000000")
    engine.graphics.draw_text(1, 2, "3d cellular automata  speed:" .. string.format("%.1f", speed), "ffffff", "000000")
end

function engine.on_key(key, action)
    if action ~= "press" then return end
    if key == "right" then speed = math.min(5.0, speed + 0.5)
    elseif key == "left" then speed = math.max(0.1, speed - 0.5)
    elseif key == "space" then reset_flag = true
    elseif key == "escape" then engine.quit()
    end
end
