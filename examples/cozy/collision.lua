local TILE = 32

local M = {}

function M.overlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

function M.tile_at(map, map_w, px, py)
    local col = math.floor(px / TILE)
    local row = math.floor(py / TILE)
    local map_h = #map / map_w
    if col < 0 or col >= map_w or row < 0 or row >= map_h then return -1 end
    return map[row * map_w + col + 1]
end

-- Check if a pixel is on a "wall" tile (blocks in all directions)
local function is_wall(map, map_w, wall, px, py)
    local t = M.tile_at(map, map_w, px, py)
    return t == -1 or wall[t] == true
end

-- Check if a pixel is on any solid tile (wall OR platform)
function M.is_solid(map, map_w, wall, platform, px, py)
    local t = M.tile_at(map, map_w, px, py)
    return t == -1 or wall[t] == true or platform[t] == true
end

function M.is_water(map, map_w, water, px, py)
    local t = M.tile_at(map, map_w, px, py)
    return water[t] == true
end

-- Horizontal movement only collides with walls (not one-way platforms)
function M.move_x(map, map_w, wall, x, y, vx, dt, hb)
    local nx = x + vx * dt
    local left   = nx + hb.ox
    local right  = nx + hb.ox + hb.w - 1
    local top    = y + hb.oy
    local bottom = y + hb.oy + hb.h - 1

    if vx > 0 then
        if is_wall(map, map_w, wall, right, top) or
           is_wall(map, map_w, wall, right, bottom) then
            local col = math.floor(right / TILE)
            nx = col * TILE - hb.ox - hb.w
            return nx, true
        end
    elseif vx < 0 then
        if is_wall(map, map_w, wall, left, top) or
           is_wall(map, map_w, wall, left, bottom) then
            local col = math.floor(left / TILE)
            nx = (col + 1) * TILE - hb.ox
            return nx, true
        end
    end
    return nx, false
end

-- Vertical movement: falling hits walls + platforms; jumping up hits only walls
function M.move_y(map, map_w, wall, platform, x, y, vy, dt, hb)
    local ny = y + vy * dt
    local left   = x + hb.ox
    local right  = x + hb.ox + hb.w - 1
    local top    = ny + hb.oy
    local bottom = ny + hb.oy + hb.h - 1

    if vy > 0 then
        -- Falling: check against walls AND platforms
        if M.is_solid(map, map_w, wall, platform, left, bottom) or
           M.is_solid(map, map_w, wall, platform, right, bottom) then
            local row = math.floor(bottom / TILE)
            ny = row * TILE - hb.oy - hb.h
            return ny, true, false
        end
    elseif vy < 0 then
        -- Jumping: only walls block (can jump through platforms)
        if is_wall(map, map_w, wall, left, top) or
           is_wall(map, map_w, wall, right, top) then
            local row = math.floor(top / TILE)
            ny = (row + 1) * TILE - hb.oy
            return ny, false, true
        end
    end
    return ny, false, false
end

return M
