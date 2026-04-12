-- Pause scene: overlay on top of game
local pause = {}

local blink_timer = 0
local show_prompt = true

function pause.load()
    blink_timer = 0
    show_prompt = true
end

function pause.draw()
    -- Dim overlay
    engine.graphics.set_layer(6)
    engine.graphics.pixel.rect(0, 0, 320, 180, 0x000000)

    -- Pause text
    engine.graphics.set_layer(7)
    engine.graphics.draw_text(7, 4, "PAUSED", 0xFFFFFF)

    if show_prompt then
        engine.graphics.draw_text(3, 7, "ENTER = resume", 0xCCCCCC)
    end
    engine.graphics.draw_text(3, 9, "Q = back to menu", 0x888888)
end

function pause.update(dt)
    blink_timer = blink_timer + dt
    if blink_timer >= 0.5 then
        blink_timer = 0
        show_prompt = not show_prompt
    end
end

function pause.on_key(key, action)
    if action ~= "press" then return end

    if key == "return" then
        engine.scene.pop()
    elseif key == "q" then
        engine.scene.switch("menu", {
            transition = "slide_left",
            duration = 0.3,
        })
    end
end

return pause
