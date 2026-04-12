-- ECS Demo — vexel Phase 7 test game
-- Demonstrates: spawn, position, velocity, sprites, animation, despawn
-- Arrow keys to move the knight. Space to spawn fire skulls. Q to quit.

local knight = nil
local knight_sheet = nil
local skull_img = nil
local speed = 120

function engine.load()
    engine.graphics.set_resolution(320, 180)

    -- Load assets
    knight_sheet = engine.graphics.load_spritesheet("assets/knight-idle.png", 120, 80)
    skull_img = engine.graphics.load_image("assets/fire-skull.png")

    -- Spawn the player as an ECS entity
    knight = engine.world.spawn()
    engine.world.set(knight, "position", { x = 100, y = 60 })
    engine.world.set(knight, "velocity", { vx = 0, vy = 0 })
    engine.world.set(knight, "sprite", { image = knight_sheet, layer = 1, scale = 1 })
    engine.world.set(knight, "animation", {
        frames = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9},
        speed = 0.1,
        loop = true,
    })
    engine.world.set(knight, "tag", { player = true })
end

function engine.update(dt)
    -- Despawn skulls that leave the screen
    for entity, pos in engine.world.each("position", "tag") do
        if pos.x > 340 or pos.x < -40 or pos.y > 200 or pos.y < -40 then
            if not engine.world.get(entity, "tag").player then
                engine.world.despawn(entity)
            end
        end
    end
end

function engine.draw()
    engine.graphics.clear_all()

    -- HUD
    local count = engine.world.count()
    engine.graphics.draw_text(1, 0, "ECS Demo: " .. count .. " entities", 0x00FF88)
    engine.graphics.draw_text(1, 1, "Arrows=move  Space=spawn skulls  Q=quit", 0x888888)
end

function engine.on_key(key, action)
    if action == "release" then
        if key == "left" or key == "right" then
            engine.world.set(knight, "velocity", { vx = 0, vy = engine.world.get(knight, "velocity").vy })
        elseif key == "up" or key == "down" then
            engine.world.set(knight, "velocity", { vx = engine.world.get(knight, "velocity").vx, vy = 0 })
        end
        return
    end

    if action ~= "press" then return end

    if key == "q" then
        engine.quit_game()
    elseif key == "left" then
        engine.world.set(knight, "velocity", { vx = -speed, vy = 0 })
    elseif key == "right" then
        engine.world.set(knight, "velocity", { vx = speed, vy = 0 })
    elseif key == "up" then
        engine.world.set(knight, "velocity", { vx = 0, vy = -speed })
    elseif key == "down" then
        engine.world.set(knight, "velocity", { vx = 0, vy = speed })
    elseif key == "space" then
        -- Spawn a fire skull at the knight's position
        local kpos = engine.world.get(knight, "position")
        local skull = engine.world.spawn()
        engine.world.set(skull, "position", { x = kpos.x, y = kpos.y })
        engine.world.set(skull, "velocity", { vx = math.random(-100, 100), vy = math.random(-100, 100) })
        engine.world.set(skull, "sprite", { image = skull_img, layer = 2 })
        engine.world.set(skull, "tag", { enemy = true })
    end
end

function engine.quit()
end
