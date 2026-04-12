-- Gothic Castle: Terrible Knight vs Fire Skulls
-- Demonstrates all Phase 2 features: load_image, load_spritesheet, draw_sprite
-- with frame/flip/scale, draw_frame, get_frame_count, unload_image, layered compositing

-- Assets
local anims = {}            -- populated in engine.load(): state -> {sheet, speed, frames}
local fire_skull_sheet
local explosion_sheet, electro_sheet
local castle_bg
local skull_frame_count

-- Constants
local RESOLUTION_W = 480
local RESOLUTION_H = 270
local FLOOR_Y = 220
local KNIGHT_W, KNIGHT_H = 128, 96
local SKULL_W, SKULL_H = 96, 112
local SKULL_BASE_Y = 100
local SKULL_BOB_SPEED = 2
local SKULL_BOB_AMPLITUDE = 15
local SKULL_ANIM_SPEED = 0.1

-- Player state
local player = {
    x = 100, y = 220,
    vx = 0, vy = 0,
    frame = 0,
    timer = 0,
    flip = false,
    state = "idle",        -- idle, run, slash, jump, hurt
    state_timer = 0,
    on_ground = true,
    speed = 120,
    jump_force = -280,
    gravity = 600,
}

-- Movement keys held
local keys = { left = false, right = false }

-- Enemies
local skulls = {}
local SKULL_COUNT = 3

-- One-shot effects
local effects = {}

-- FPS tracking
local fps_timer = 0
local fps_frames = 0
local fps_display = 0

-- Advance a looping animation's frame counter
local function advance_frame(entity, dt, speed, total)
    entity.timer = entity.timer + dt
    if entity.timer >= speed then
        entity.timer = entity.timer - speed
        entity.frame = (entity.frame + 1) % total
    end
end

-- Respawn all skulls to starting positions
local function respawn_skulls()
    for i, skull in ipairs(skulls) do
        skull.alive = true
        skull.x = 200 + (i - 1) * 160
        skull.frame = 0
    end
end

function spawn_effect(sheet, x, y, frame_dur)
    table.insert(effects, {
        sheet = sheet,
        x = x, y = y,
        frame = 0,
        timer = 0,
        frame_dur = frame_dur,
        frame_count = engine.graphics.get_frame_count(sheet),
    })
end

function engine.load()
    engine.graphics.set_resolution(RESOLUTION_W, RESOLUTION_H)

    -- Load knight animation sheets into anims table
    local function load_anim(file, speed)
        local sheet = engine.graphics.load_spritesheet(file, KNIGHT_W, KNIGHT_H)
        return { sheet = sheet, speed = speed, frames = engine.graphics.get_frame_count(sheet) }
    end

    anims.idle  = load_anim("assets/knight-idle.png",  0.15)
    anims.run   = load_anim("assets/knight-run.png",   0.07)
    anims.slash = load_anim("assets/knight-slash.png", 0.06)
    anims.jump  = load_anim("assets/knight-jump.png",  0.12)
    anims.hurt  = load_anim("assets/knight-hurt.png",  0.15)

    -- Fire skull: 96x112 frames
    fire_skull_sheet = engine.graphics.load_spritesheet("assets/fire-skull.png", SKULL_W, SKULL_H)
    skull_frame_count = engine.graphics.get_frame_count(fire_skull_sheet)

    -- Effects
    explosion_sheet = engine.graphics.load_spritesheet("assets/explosion.png", 112, 128)
    electro_sheet   = engine.graphics.load_spritesheet("assets/electro-shock.png", 128, 96)

    -- Background (full image, not spritesheet)
    castle_bg = engine.graphics.load_image("assets/castle-background.png")

    -- Spawn fire skulls at different positions
    for i = 1, SKULL_COUNT do
        skulls[i] = {
            x = 150 + (i - 1) * 120,
            y = SKULL_BASE_Y + math.sin(i * 2) * 30,  -- initial spread wider than runtime bob
            frame = 0,
            timer = 0,
            dir = (i % 2 == 0) and 1 or -1,
            speed = 30 + i * 10,
            alive = true,
            bob_offset = i * 1.5,
        }
    end

    -- Draw static background on layer 0 (only once)
    engine.graphics.set_layer(0)
    -- Dark base fill
    engine.graphics.pixel.rect(0, 0, RESOLUTION_W, RESOLUTION_H, 0x0d0d1a)
    -- Draw castle background image (960x304, positioned so lower portion visible)
    engine.graphics.draw_sprite(castle_bg, 0, -60)
    -- Draw stone floor
    for tx = 0, RESOLUTION_W / 16 do
        local shade = ((tx % 2 == 0) and 0x2a2a3e) or 0x222236
        engine.graphics.pixel.rect(tx * 16, FLOOR_Y, 16, RESOLUTION_H - FLOOR_Y, shade)
    end
    -- Floor edge highlight
    engine.graphics.pixel.line(0, FLOOR_Y, RESOLUTION_W, FLOOR_Y, 0x4a4a5e)
end

function engine.update(dt)
    -- FPS counter
    fps_frames = fps_frames + 1
    fps_timer = fps_timer + dt
    if fps_timer >= 0.5 then
        fps_display = math.floor(fps_frames / fps_timer + 0.5)
        fps_frames = 0
        fps_timer = 0
    end

    -- Player state machine
    update_player(dt)

    -- Skull enemies
    for _, skull in ipairs(skulls) do
        if skull.alive then
            update_skull(skull, dt)
        end
    end

    -- One-shot effects (remove when animation completes)
    for i = #effects, 1, -1 do
        local fx = effects[i]
        fx.timer = fx.timer + dt
        if fx.timer >= fx.frame_dur then
            fx.timer = fx.timer - fx.frame_dur
            fx.frame = fx.frame + 1
            if fx.frame >= fx.frame_count then
                table.remove(effects, i)
            end
        end
    end
end

function update_player(dt)
    local anim = anims[player.state]

    -- State transitions
    if player.state == "slash" then
        player.state_timer = player.state_timer + dt
        if player.state_timer >= anims.slash.speed * anims.slash.frames then
            player.state = "idle"
            player.state_timer = 0
            player.frame = 0
        end
    elseif player.state == "hurt" then
        player.state_timer = player.state_timer + dt
        if player.state_timer >= 0.4 then
            player.state = "idle"
            player.state_timer = 0
            player.frame = 0
        end
    end

    -- Horizontal movement (only if not in slash/hurt)
    if player.state ~= "slash" and player.state ~= "hurt" then
        if keys.left then
            player.vx = -player.speed
            player.flip = true
            if player.on_ground and player.state ~= "jump" then
                player.state = "run"
            end
        elseif keys.right then
            player.vx = player.speed
            player.flip = false
            if player.on_ground and player.state ~= "jump" then
                player.state = "run"
            end
        else
            player.vx = 0
            if player.on_ground and player.state ~= "jump" then
                player.state = "idle"
            end
        end
    else
        player.vx = 0
    end

    -- Gravity
    if not player.on_ground then
        player.vy = player.vy + player.gravity * dt
    end

    -- Apply velocity
    player.x = player.x + player.vx * dt
    player.y = player.y + player.vy * dt

    -- Floor collision
    if player.y >= FLOOR_Y - KNIGHT_H then
        player.y = FLOOR_Y - KNIGHT_H
        player.vy = 0
        if not player.on_ground then
            player.on_ground = true
            if player.state == "jump" then
                player.state = "idle"
                player.frame = 0
            end
        end
    else
        player.on_ground = false
    end

    -- Clamp to screen
    player.x = math.max(-32, math.min(RESOLUTION_W - 96, player.x))

    -- Animate
    anim = anims[player.state]
    advance_frame(player, dt, anim.speed, anim.frames)

    -- Check slash collision with skulls
    if player.state == "slash" and player.frame == 2 then
        local attack_x = player.flip and (player.x - 40) or (player.x + 80)
        for _, skull in ipairs(skulls) do
            if skull.alive then
                local dx = math.abs((skull.x + SKULL_W / 2) - attack_x)
                local dy = math.abs((skull.y + SKULL_H / 2) - (player.y + KNIGHT_H / 2))
                if dx < 60 and dy < 60 then
                    skull.alive = false
                    spawn_effect(explosion_sheet, skull.x - 20, skull.y - 30, 0.08)
                    spawn_effect(electro_sheet, attack_x - 64, player.y - 20, 0.06)
                end
            end
        end
    end
end

function update_skull(skull, dt)
    -- Float back and forth
    skull.x = skull.x + skull.dir * skull.speed * dt
    if skull.x > RESOLUTION_W - 100 then
        skull.dir = -1
    elseif skull.x < 4 then
        skull.dir = 1
    end

    -- Bobbing motion
    skull.bob_offset = skull.bob_offset + dt * SKULL_BOB_SPEED
    skull.y = SKULL_BASE_Y + math.sin(skull.bob_offset) * SKULL_BOB_AMPLITUDE

    -- Animate
    advance_frame(skull, dt, SKULL_ANIM_SPEED, skull_frame_count)
end

function engine.draw()
    -- Layer 0: background (drawn once in load, never cleared)

    -- Layer 1: enemies
    engine.graphics.set_layer(1)
    engine.graphics.pixel.clear()
    for _, skull in ipairs(skulls) do
        if skull.alive then
            engine.graphics.draw_sprite(fire_skull_sheet,
                math.floor(skull.x), math.floor(skull.y), {
                frame = skull.frame,
                flip_x = (skull.dir < 0),
            })
        end
    end

    -- Layer 2: player
    engine.graphics.set_layer(2)
    engine.graphics.pixel.clear()
    engine.graphics.draw_sprite(anims[player.state].sheet,
        math.floor(player.x), math.floor(player.y), {
        frame = player.frame,
        flip_x = player.flip,
    })

    -- Layer 3: effects overlay
    engine.graphics.set_layer(3)
    engine.graphics.pixel.clear()
    for _, fx in ipairs(effects) do
        engine.graphics.draw_sprite(fx.sheet,
            math.floor(fx.x), math.floor(fx.y), {
            frame = fx.frame,
        })
    end

    -- Text HUD (drawn on vaxis text layer, above pixel graphics)
    engine.graphics.draw_text(1, 0, "Gothic Castle - Arrows, Space, Up, Q", 0xcccccc)
    engine.graphics.draw_text(1, 1, "FPS: " .. fps_display, 0x00ff00)

    -- Show alive skull count
    local alive = 0
    for _, skull in ipairs(skulls) do
        if skull.alive then alive = alive + 1 end
    end
    if alive == 0 then
        engine.graphics.draw_text(1, 2, "All skulls defeated! Press R to respawn", 0xffcc00)
    end
end

function engine.on_key(key, action)
    local pressed = (action == "press")

    if key == "q" and pressed then
        engine.quit_game()
        return
    end

    if key == "left" then keys.left = pressed end
    if key == "right" then keys.right = pressed end

    if pressed then
        if key == "up" and player.on_ground and player.state ~= "slash" then
            player.state = "jump"
            player.vy = player.jump_force
            player.on_ground = false
            player.frame = 0
            player.timer = 0
        end

        if key == "space" and player.on_ground and player.state ~= "slash" then
            player.state = "slash"
            player.state_timer = 0
            player.frame = 0
            player.timer = 0
        end

        if key == "r" then
            respawn_skulls()
        end
    end
end

function engine.quit()
    for _, anim in pairs(anims) do
        engine.graphics.unload_image(anim.sheet)
    end
    engine.graphics.unload_image(fire_skull_sheet)
    engine.graphics.unload_image(explosion_sheet)
    engine.graphics.unload_image(electro_sheet)
    engine.graphics.unload_image(castle_bg)
end
