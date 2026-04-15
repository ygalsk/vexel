local collision = require("collision")

local M = {}
local entity
local wx, wy = 0, 0  -- world position
local vx, vy = 0, 0
local on_ground = false
local facing_right = true
local was_walk = false

local GRAVITY    = 600
local JUMP_VEL   = -260
local MOVE_SPEED = 100
local MAX_FALL   = 400
local HITBOX     = { ox = 8, oy = 4, w = 16, h = 28 }

local WALK_FRAMES = { 4, 5, 6, 7 }
local IDLE_FRAME  = { 4 }

function M.create(shared)
    entity = engine.world.spawn()
    engine.world.set(entity, "position", { x = 0, y = 0 })
    engine.world.set(entity, "sprite", {
        image = shared.sheet_guy, layer = 3, scale = 1,
    })
    engine.world.set(entity, "animation", {
        frames = IDLE_FRAME, speed = 0.3, loop = true,
    })
    wx, wy = 0, 0
    vx, vy = 0, 0
    on_ground = false
    facing_right = true
    was_walk = false
end

function M.get_world_pos() return wx, wy end
function M.get_hitbox() return HITBOX end

function M.update(dt, level, shared, cam_x)
    -- Input
    local dx = 0
    if engine.input.is_key_down("left")  then dx = dx - 1 end
    if engine.input.is_key_down("right") then dx = dx + 1 end
    vx = dx * MOVE_SPEED

    if on_ground and (engine.input.is_key_down("space") or engine.input.is_key_down("up")) then
        vy = JUMP_VEL
        on_ground = false
    end

    -- Gravity
    vy = math.min(vy + GRAVITY * dt, MAX_FALL)

    -- Move (in world coords)
    local nx, ny, landed, bonked
    nx = collision.move_x(level.tilemap, level.w, level.wall, wx, wy, vx, dt, HITBOX)
    ny, landed, bonked = collision.move_y(level.tilemap, level.w, level.wall, level.platform, nx, wy, vy, dt, HITBOX)

    if landed then vy = 0; on_ground = true end
    if bonked then vy = 0 end

    if not landed and vy >= 0 then
        local left  = nx + HITBOX.ox
        local right = nx + HITBOX.ox + HITBOX.w - 1
        local below = ny + HITBOX.oy + HITBOX.h
        on_ground = collision.is_solid(level.tilemap, level.w, level.wall, level.platform, left, below) or
                    collision.is_solid(level.tilemap, level.w, level.wall, level.platform, right, below)
    end

    wx, wy = nx, ny

    -- Water death / fall off bottom
    local cx = wx + HITBOX.ox + HITBOX.w / 2
    local cy = wy + HITBOX.oy + HITBOX.h / 2
    if collision.is_water(level.tilemap, level.w, level.water, cx, cy) or
       wy > level.h * level.tile + 64 then
        wx, wy = level.start_pos.x, level.start_pos.y
        vy = 0
        on_ground = false
    end

    -- Set ECS position to screen coords
    engine.world.set(entity, "position", { x = wx - cam_x, y = wy })

    -- Animation
    local moving = dx ~= 0
    local new_right = facing_right
    if dx > 0 then new_right = true elseif dx < 0 then new_right = false end

    local want_walk = moving and on_ground
    if new_right ~= facing_right or want_walk ~= was_walk then
        facing_right = new_right
        was_walk = want_walk
        local frames = want_walk and WALK_FRAMES or IDLE_FRAME
        local speed = want_walk and 0.12 or 0.3
        engine.world.set(entity, "animation", {
            frames = frames, speed = speed, loop = true,
        })
        engine.world.set(entity, "sprite", {
            image = shared.sheet_guy, layer = 3, scale = 1,
            flip_x = not facing_right,
        })
    end
end

return M
