-- Platformer: Character with idle/walk animations
-- Demonstrates spritesheet loading with different frame sizes

-- Constants
local RESOLUTION_W = 480
local RESOLUTION_H = 270
local FLOOR_Y = 230
local GRAVITY = 600
local MOVE_SPEED = 100
local JUMP_FORCE = -280

-- Assets
local idle_sheet, walk_sheet

-- Frame sizes per animation
local IDLE_W, IDLE_H = 46, 55
local WALK_W, WALK_H = 45, 58

-- Player state
local player = {
    x = 200,
    y = 0,
    vx = 0,
    vy = 0,
    state = "idle",
    frame = 0,
    timer = 0,
    flip = false,
    on_ground = false,
}

-- Animation config
local anims = {
    idle = { frames = 10, speed = 0.12, w = IDLE_W, h = IDLE_H },
    walk = { frames = 24, speed = 0.05, w = WALK_W, h = WALK_H },
}

local keys = { left = false, right = false }

-- FPS tracking
local fps_timer = 0
local fps_frames = 0
local fps_display = 0

function engine.load()
    engine.graphics.set_resolution(RESOLUTION_W, RESOLUTION_H)

    idle_sheet = engine.graphics.load_spritesheet("assets/idle.png", IDLE_W, IDLE_H)
    walk_sheet = engine.graphics.load_spritesheet("assets/walk.png", WALK_W, WALK_H)

    -- Draw background on layer 0 (persists)
    engine.graphics.set_layer(0)

    -- Sky gradient
    local sky_colors = { 0x87CEEB, 0x7EC8E3, 0x6BBCD8, 0x5BB0CD, 0x4BA4C2 }
    local band_h = FLOOR_Y / #sky_colors
    for i, color in ipairs(sky_colors) do
        engine.graphics.pixel.rect(0, (i - 1) * band_h, RESOLUTION_W, band_h, color)
    end

    -- Ground
    engine.graphics.pixel.rect(0, FLOOR_Y, RESOLUTION_W, RESOLUTION_H - FLOOR_Y, 0x4a7c3f)
    -- Darker ground layer
    engine.graphics.pixel.rect(0, FLOOR_Y + 8, RESOLUTION_W, RESOLUTION_H - FLOOR_Y - 8, 0x3d6b34)
    -- Ground edge
    engine.graphics.pixel.line(0, FLOOR_Y, RESOLUTION_W, FLOOR_Y, 0x5a9c4f)
    -- Dirt stripe
    engine.graphics.pixel.rect(0, FLOOR_Y + 3, RESOLUTION_W, 2, 0x8B7355)

    -- Simple clouds
    engine.graphics.pixel.circle(80, 40, 18, 0xffffff)
    engine.graphics.pixel.circle(100, 35, 22, 0xffffff)
    engine.graphics.pixel.circle(120, 42, 16, 0xffffff)

    engine.graphics.pixel.circle(320, 55, 14, 0xf0f0f0)
    engine.graphics.pixel.circle(340, 50, 18, 0xf0f0f0)
    engine.graphics.pixel.circle(355, 56, 12, 0xf0f0f0)
end

function engine.update(dt)
    -- FPS
    fps_frames = fps_frames + 1
    fps_timer = fps_timer + dt
    if fps_timer >= 0.5 then
        fps_display = math.floor(fps_frames / fps_timer + 0.5)
        fps_frames = 0
        fps_timer = 0
    end

    -- Movement
    if keys.left then
        player.vx = -MOVE_SPEED
        player.flip = true
        if player.on_ground then player.state = "walk" end
    elseif keys.right then
        player.vx = MOVE_SPEED
        player.flip = false
        if player.on_ground then player.state = "walk" end
    else
        player.vx = 0
        if player.on_ground then player.state = "idle" end
    end

    -- Gravity
    if not player.on_ground then
        player.vy = player.vy + GRAVITY * dt
    end

    -- Apply velocity
    player.x = player.x + player.vx * dt
    player.y = player.y + player.vy * dt

    -- Floor collision
    local anim = anims[player.state]
    if player.y >= FLOOR_Y - anim.h then
        player.y = FLOOR_Y - anim.h
        player.vy = 0
        if not player.on_ground then
            player.on_ground = true
        end
    else
        player.on_ground = false
    end

    -- Clamp to screen
    player.x = math.max(0, math.min(RESOLUTION_W - anim.w, player.x))

    -- Animate
    player.timer = player.timer + dt
    if player.timer >= anim.speed then
        player.timer = player.timer - anim.speed
        player.frame = (player.frame + 1) % anim.frames
    end
end

function engine.draw()
    -- Layer 0: background (drawn once in load)

    -- Layer 1: player
    engine.graphics.set_layer(1)
    engine.graphics.pixel.clear()

    local anim = anims[player.state]
    local sheet = (player.state == "walk") and walk_sheet or idle_sheet

    local draw_x = player.x

    engine.graphics.draw_sprite(sheet,
        math.floor(draw_x), math.floor(player.y), {
        frame = player.frame,
        flip_x = player.flip,
    })

    -- HUD
    engine.graphics.draw_text(1, 0, "Platformer - Arrows, Up to jump, Q to quit", 0x333333)
    engine.graphics.draw_text(1, 1, "FPS: " .. fps_display, 0x006600)
end

function engine.on_key(key, action)
    local pressed = (action == "press")

    if key == "q" and pressed then
        engine.quit_game()
        return
    end

    if key == "left" then keys.left = pressed end
    if key == "right" then keys.right = pressed end

    if key == "up" and pressed and player.on_ground then
        player.vy = JUMP_FORCE
        player.on_ground = false
    end
end

function engine.quit()
    engine.graphics.unload_image(idle_sheet)
    engine.graphics.unload_image(walk_sheet)
end
