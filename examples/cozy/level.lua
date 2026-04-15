-- Swamp platformer level data
-- 40x6 tiles, 32px each = 1280x192 virtual pixels (fits viewport vertically)

local TILE = 32

-- Tile indices (1-based, tileset is 10 cols x 6 rows)
local E  = 0   -- empty (air)
local TL = 1   -- grass top-left
local TT = 2   -- grass top
local TR = 3   -- grass top-right
local LL = 7   -- ledge left cap
local LM = 8   -- ledge middle
local LR = 9   -- ledge right cap
local GL = 11  -- grass left edge
local DT = 12  -- dirt interior
local GR = 13  -- grass right edge
local BL = 21  -- bottom-left
local BB = 22  -- bottom center
local BR = 23  -- bottom-right
local WS = 20  -- water surface
local WD = 40  -- water deep

local W = 40
local H = 6

-- 6 rows: row 0 sky, row 1 high ledges, row 2 mid ledges, row 3 low ledges, rows 4-5 ground/water
-- Player jumps ~2 tiles high. Max gap jump ~3 tiles wide.
-- stylua: ignore
local tilemap = {
    -- Row 0: sky
    E, E, E, E, E, E, E, E, E, E,  E, E, E, E, E, E, E, E, E, E,
    E, E, E, E, E, E, E, E, E, E,  E, E, E, E, E, E, E, E, E, E,
    -- Row 1: high ledges
    E, E, E, E, E, E, E, E, E, E,  E, E, E, E, E, E,LL,LM,LR, E,
    E, E, E, E, E, E, E, E, E, E,  E, E,LL,LM,LM,LR, E, E, E, E,
    -- Row 2: mid ledges
    E, E, E, E, E, E, E, E, E,LL, LM,LR, E, E, E, E, E, E, E, E,
    E, E, E, E, E, E,LL,LM,LR, E,  E, E, E, E, E, E, E, E, E, E,
    -- Row 3: low ledges
    E, E, E, E, E,LL,LM,LR, E, E,  E, E, E, E,LL,LM,LR, E, E, E,
    E, E,LL,LM,LR, E, E, E, E, E,  E,LL,LM,LR, E, E, E, E, E, E,
    -- Row 4: ground surface
    TL,TT,TT,TR, E, E, E, E, E, E,  E, E,TL,TT,TR, E, E, E, E,TL,
    TT,TR, E, E, E, E, E, E, E, E,  E, E, E, E, E, E, E,TL,TT,TR,
    -- Row 5: underground / water
    BL,BB,BB,BR,WS,WS,WS,WS,WS,WS, WS,WS,BL,BB,BR,WS,WS,WS,WS,BL,
    BB,BR,WS,WS,WS,WS,WS,WS,WS,WS, WS,WS,WS,WS,WS,WS,WS,BL,BB,BR,
}

-- Walls block in all directions (ground tiles)
local WALL = {}
for _, t in ipairs({TL,TT,TR,GL,DT,GR,BL,BB,BR}) do
    WALL[t] = true
end

-- Platforms are one-way: only block when falling onto them from above
local PLATFORM = {}
for _, t in ipairs({LL,LM,LR}) do
    PLATFORM[t] = true
end

local WATER = {}
for _, t in ipairs({WS, WD}) do
    WATER[t] = true
end

local coins = {
    { x =  6 * TILE + 8,  y =  2 * TILE - 12 },  -- above low ledge at col 5-7
    { x = 10 * TILE + 8,  y =  1 * TILE - 12 },  -- above mid ledge at col 9-11
    { x = 15 * TILE + 8,  y =  2 * TILE - 12 },  -- above low ledge at col 14-16
    { x = 17 * TILE + 8,  y =  0 * TILE + 4  },  -- above high ledge at col 16-18
    { x = 23 * TILE + 8,  y =  2 * TILE - 12 },  -- above low ledge at col 22-24
    { x = 27 * TILE + 8,  y =  1 * TILE - 12 },  -- above mid ledge at col 26-28
    { x = 33 * TILE + 8,  y =  0 * TILE + 4  },  -- above high ledge at col 32-35
}

local flag_pos = { x = 38 * TILE - 8, y = 4 * TILE - 48 }
local start_pos = { x = 1 * TILE, y = 3 * TILE }

return {
    tilemap = tilemap,
    w = W,
    h = H,
    tile = TILE,
    wall = WALL,
    platform = PLATFORM,
    water = WATER,
    coins = coins,
    flag_pos = flag_pos,
    start_pos = start_pos,
}
