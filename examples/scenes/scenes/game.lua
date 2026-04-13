-- Game scene: dragon flying with keyboard control using input state queries
local game = {}

local dragon_sheet
local dragon_frames = 0
local anim_timer = 0
local anim_frame = 0
local ANIM_SPEED = 0.08

local dragon = { x = 100, y = 60 }
local SPEED = 120
local sky

function game.load()
    sky = engine.graphics.load_image("assets/sky.png")
    dragon_sheet = engine.graphics.load_spritesheet("assets/dragon-fly.png", 192, 176)
    dragon_frames = engine.graphics.get_frame_count(dragon_sheet)
    dragon.x = 100
    dragon.y = 60
    anim_timer = 0
    anim_frame = 0
end

function game.update(dt)
    -- Continuous input via state queries (no on_key needed for movement)
    local dx, dy = 0, 0
    if engine.input.is_key_down("left")  or engine.input.is_key_down("a") then dx = -1 end
    if engine.input.is_key_down("right") or engine.input.is_key_down("d") then dx = 1  end
    if engine.input.is_key_down("up")    or engine.input.is_key_down("w") then dy = -1 end
    if engine.input.is_key_down("down")  or engine.input.is_key_down("s") then dy = 1  end

    dragon.x = dragon.x + dx * SPEED * dt
    dragon.y = dragon.y + dy * SPEED * dt

    -- Clamp to screen
    dragon.x = math.max(-40, math.min(dragon.x, 280))
    dragon.y = math.max(-20, math.min(dragon.y, 140))

    -- Animation
    anim_timer = anim_timer + dt
    if anim_timer >= ANIM_SPEED then
        anim_timer = anim_timer - ANIM_SPEED
        anim_frame = (anim_frame + 1) % dragon_frames
    end
end

function game.draw()
    -- Background
    engine.graphics.set_layer(0)
    engine.graphics.draw_sprite(sky, 0, 0)

    -- Dragon
    engine.graphics.set_layer(3)
    engine.graphics.draw_sprite(dragon_sheet, math.floor(dragon.x), math.floor(dragon.y), {
        frame = anim_frame,
    })

    -- HUD
    engine.graphics.set_layer(7)
    engine.graphics.draw_text(1, 0, "Arrow keys / WASD to fly", 0xCCCCCC)
    engine.graphics.draw_text(1, 1, "ESC = pause", 0x888888)
end

function game.on_key(key, action)
    if action ~= "press" then return end

    if key == "escape" then
        engine.scene.push("pause")
    end
end

function game.pause()
    -- Called when pause scene is pushed on top
end

function game.resume()
    -- Called when returning from pause
end

function game.unload()
    if sky then engine.graphics.unload_image(sky) end
    if dragon_sheet then engine.graphics.unload_image(dragon_sheet) end
    sky = nil
    dragon_sheet = nil
end

return game
