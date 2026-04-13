-- Menu scene: title screen with background
local menu = {}

local sky, mountains
local blink_timer = 0
local show_prompt = true

function menu.load()
    sky = engine.graphics.load_image("assets/sky.png")
    mountains = engine.graphics.load_image("assets/mountains.png")
    blink_timer = 0
    show_prompt = true
end

function menu.update(dt)
    blink_timer = blink_timer + dt
    if blink_timer >= 0.6 then
        blink_timer = 0
        show_prompt = not show_prompt
    end
end

function menu.draw()
    -- Background layers
    engine.graphics.set_layer(0)
    engine.graphics.draw_sprite(sky, 0, 0)
    engine.graphics.set_layer(1)
    engine.graphics.draw_sprite(mountains, 0, 0)

    -- Title text
    engine.graphics.set_layer(7)
    local title = "SCENE DEMO"
    engine.graphics.draw_text(5, 3, title, 0xFFD700)

    local subtitle = "Phase 3: Input & Scenes"
    engine.graphics.draw_text(3, 5, subtitle, 0xAAAAAA)

    if show_prompt then
        engine.graphics.draw_text(3, 8, "Press ENTER to play", 0xFFFFFF)
    end

    engine.graphics.draw_text(3, 10, "Press Q to quit", 0x888888)
end

function menu.on_key(key, action)
    if action ~= "press" then return end

    if key == "return" then
        engine.scene.switch("game", {
            transition = "fade",
            duration = 0.5,
        })
    elseif key == "q" then
        engine.quit_game()
    end
end

function menu.unload()
    if sky then engine.graphics.unload_image(sky) end
    if mountains then engine.graphics.unload_image(mountains) end
    sky = nil
    mountains = nil
end

return menu
