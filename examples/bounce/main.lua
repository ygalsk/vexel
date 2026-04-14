-- Bouncing ball demo — Phase 1 test game
-- Exercises pixel drawing, layers, and cell-based text overlay.

local W, H = 1920, 1080
local ball_x, ball_y = 960.0, 540.0
local ball_dx, ball_dy = 720.0, 510.0
local ball_r = 64   -- collision radius; matches sprite half-size (128px / 2)
local SPRITE_HALF = 64
local frame = 0
local ball_sheet   -- kept at module scope to prevent GC while entity holds the handle
local ball_entity

function engine.load()
    engine.graphics.set_resolution(W, H)
    ball_sheet = engine.graphics.load_spritesheet("assets/ball.png", 128, 128)
    ball_entity = engine.world.spawn()
    engine.world.set(ball_entity, "position", { x = ball_x - SPRITE_HALF, y = ball_y - SPRITE_HALF })
    engine.world.set(ball_entity, "sprite", { image = ball_sheet, layer = 2 })
end

function engine.update(dt)
    frame = frame + 1

    ball_x = ball_x + ball_dx * dt
    ball_y = ball_y + ball_dy * dt

    -- Bounce off walls
    if ball_x - ball_r < 0 then
        ball_x = ball_r
        ball_dx = -ball_dx
    elseif ball_x + ball_r > W then
        ball_x = W - ball_r
        ball_dx = -ball_dx
    end

    if ball_y - ball_r < 0 then
        ball_y = ball_r
        ball_dy = -ball_dy
    elseif ball_y + ball_r > H then
        ball_y = H - ball_r
        ball_dy = -ball_dy
    end

    engine.world.set(ball_entity, "position", { x = ball_x - SPRITE_HALF, y = ball_y - SPRITE_HALF })
end

function engine.draw()
    -- Layer 0: dark background
    engine.graphics.set_layer(0)
    engine.graphics.pixel.clear()
    engine.graphics.pixel.rect(0, 0, W, H, 0x0f0f23)

    -- Layer 1: decorative crossed lines
    engine.graphics.set_layer(1)
    engine.graphics.pixel.clear()
    engine.graphics.pixel.line(0, 0, W, H, 0x222244)
    engine.graphics.pixel.line(W, 0, 0, H, 0x222244)
    -- Border
    engine.graphics.pixel.rect(0, 0, W, 1, 0x444488)
    engine.graphics.pixel.rect(0, H - 1, W, 1, 0x444488)
    engine.graphics.pixel.rect(0, 0, 1, H, 0x444488)
    engine.graphics.pixel.rect(W - 1, 0, 1, H, 0x444488)

    -- Cell-based text overlay (renders above pixel layers)
    engine.graphics.draw_text(1, 0, string.format("Bounce Demo  frame:%d", frame), 0xCCCCCC)
    engine.graphics.draw_text(1, 1, string.format("pos: %.1f, %.1f", ball_x, ball_y), 0x888888)
    engine.graphics.draw_text(1, 2, "Press 'q' to quit", 0x666666)
end

function engine.on_key(key, action)
    if action == "press" and key == "q" then
        engine.quit()
    end
end
