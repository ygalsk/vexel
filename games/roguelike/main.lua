-- Mini Roguelike — Phase 5 test game
-- Demonstrates: tilemap rendering, scrolling camera, save/load, timers, tweens

local W, H = 320, 180
local TILE = 8
local MAP_W, MAP_H = 60, 40

-- Tile indices (1-based for tilemap, 0 = empty)
local FLOOR = 1
local WALL  = 2
local PLAYER_TILE = 3
local STAIRS = 4

-- Game state
local map = {}
local player = { x = 5, y = 5 }
local camera = { x = 0, y = 0 }
local tileset = nil
local level = 1
local msg = ""
local msg_timer = nil
local blink = true
local blink_timer = nil
local moves = 0

-- Dungeon generation: rooms + corridors
local function generate_map()
    -- Fill with walls
    for i = 1, MAP_W * MAP_H do
        map[i] = WALL
    end

    local rooms = {}
    local function set_tile(x, y, tile)
        if x >= 1 and x <= MAP_W and y >= 1 and y <= MAP_H then
            map[(y - 1) * MAP_W + x] = tile
        end
    end
    local function get_tile(x, y)
        if x >= 1 and x <= MAP_W and y >= 1 and y <= MAP_H then
            return map[(y - 1) * MAP_W + x]
        end
        return WALL
    end

    -- Carve rooms
    for _ = 1, 8 do
        local rw = math.random(4, 10)
        local rh = math.random(4, 8)
        local rx = math.random(2, MAP_W - rw - 1)
        local ry = math.random(2, MAP_H - rh - 1)

        -- Check overlap
        local overlap = false
        for _, r in ipairs(rooms) do
            if rx < r.x + r.w + 1 and rx + rw + 1 > r.x and
               ry < r.y + r.h + 1 and ry + rh + 1 > r.y then
                overlap = true
                break
            end
        end

        if not overlap then
            for dy = 0, rh - 1 do
                for dx = 0, rw - 1 do
                    set_tile(rx + dx, ry + dy, FLOOR)
                end
            end
            table.insert(rooms, { x = rx, y = ry, w = rw, h = rh })
        end
    end

    -- Connect rooms with corridors
    for i = 2, #rooms do
        local a = rooms[i - 1]
        local b = rooms[i]
        local ax = math.floor(a.x + a.w / 2)
        local ay = math.floor(a.y + a.h / 2)
        local bx = math.floor(b.x + b.w / 2)
        local by = math.floor(b.y + b.h / 2)

        -- Horizontal then vertical
        local x = ax
        while x ~= bx do
            set_tile(x, ay, FLOOR)
            x = x + (bx > ax and 1 or -1)
        end
        local y = ay
        while y ~= by do
            set_tile(bx, y, FLOOR)
            y = y + (by > ay and 1 or -1)
        end
    end

    -- Place player in first room
    if #rooms > 0 then
        player.x = math.floor(rooms[1].x + rooms[1].w / 2)
        player.y = math.floor(rooms[1].y + rooms[1].h / 2)
    end

    -- Place stairs in last room
    if #rooms > 1 then
        local last = rooms[#rooms]
        local sx = math.floor(last.x + last.w / 2)
        local sy = math.floor(last.y + last.h / 2)
        set_tile(sx, sy, STAIRS)
    end

    return get_tile
end

local function show_message(text, duration)
    msg = text
    if msg_timer then engine.timer.cancel(msg_timer) end
    msg_timer = engine.timer.after(duration or 2.0, function()
        msg = ""
        msg_timer = nil
    end)
end

local function update_camera_target()
    -- Center camera on player
    local target_x = (player.x - 1) * TILE - W / 2 + TILE / 2
    local target_y = (player.y - 1) * TILE - H / 2 + TILE / 2

    -- Clamp to map bounds
    local max_x = MAP_W * TILE - W
    local max_y = MAP_H * TILE - H
    target_x = math.max(0, math.min(target_x, max_x))
    target_y = math.max(0, math.min(target_y, max_y))

    -- Smooth camera via tween
    engine.tween(camera, { x = target_x, y = target_y }, 0.15, "ease_out")
end

local function try_move(dx, dy)
    local nx, ny = player.x + dx, player.y + dy
    if nx < 1 or nx > MAP_W or ny < 1 or ny > MAP_H then return end

    local idx = (ny - 1) * MAP_W + nx
    local tile = map[idx]

    if tile == WALL then return end

    player.x = nx
    player.y = ny
    moves = moves + 1
    update_camera_target()

    if tile == STAIRS then
        level = level + 1
        show_message("Descending to level " .. level .. "...", 1.5)
        generate_map()
        update_camera_target()
        -- Jump camera immediately for new level
        local target_x = player.x * TILE - W / 2 + TILE / 2
        local target_y = player.y * TILE - H / 2 + TILE / 2
        local max_x = MAP_W * TILE - W
        local max_y = MAP_H * TILE - H
        camera.x = math.max(0, math.min(target_x, max_x))
        camera.y = math.max(0, math.min(target_y, max_y))
    end
end

local function save_game()
    engine.save.set("player_x", tostring(player.x))
    engine.save.set("player_y", tostring(player.y))
    engine.save.set("level", tostring(level))
    engine.save.set("moves", tostring(moves))
    show_message("Game saved!", 1.5)
end

local function load_game()
    local px = engine.save.get("player_x")
    local py = engine.save.get("player_y")
    local lv = engine.save.get("level")
    local mv = engine.save.get("moves")

    if px and py then
        player.x = tonumber(px) or player.x
        player.y = tonumber(py) or player.y
        level = tonumber(lv) or level
        moves = tonumber(mv) or moves

        -- Regenerate map for this level (seeded for consistency)
        math.randomseed(level * 12345)
        generate_map()
        -- Override player position from save
        player.x = tonumber(px) or player.x
        player.y = tonumber(py) or player.y

        update_camera_target()
        camera.x = player.x * TILE - W / 2 + TILE / 2
        camera.y = player.y * TILE - H / 2 + TILE / 2
        show_message("Game loaded! Level " .. level, 1.5)
    else
        show_message("No save found", 1.5)
    end
end

function engine.load()
    engine.graphics.set_resolution(W, H)
    tileset = engine.graphics.load_spritesheet("assets/tileset.png", TILE, TILE)

    math.randomseed(os.time())
    generate_map()

    -- Center camera on player immediately
    camera.x = (player.x - 1) * TILE - W / 2 + TILE / 2
    camera.y = (player.y - 1) * TILE - H / 2 + TILE / 2

    -- Blinking cursor effect
    blink_timer = engine.timer.every(0.5, function()
        blink = not blink
    end)

    show_message("Arrow keys to move. S=save, L=load, Q=quit", 3.0)
end

function engine.update(dt)
    -- Timers and tweens are updated by the engine automatically
end

function engine.draw()
    -- Layer 0: tilemap (floor + walls)
    engine.graphics.draw_tilemap(tileset, map, {
        width = MAP_W,
        cam_x = camera.x,
        cam_y = camera.y,
        layer = 0,
    })

    -- Layer 1: player (drawn as colored rect since player tile is in the tileset)
    engine.graphics.set_layer(1)
    engine.graphics.pixel.clear()

    local px = (player.x - 1) * TILE - math.floor(camera.x)
    local py = (player.y - 1) * TILE - math.floor(camera.y)

    if blink then
        -- Draw player as green @ from tileset
        engine.graphics.draw_sprite(tileset, px, py, { frame = 2 })
    else
        -- Dim version during blink-off
        engine.graphics.pixel.rect(px + 1, py + 1, TILE - 2, TILE - 2, 0x006030)
    end

    -- HUD text overlay (cell-based, renders above pixel layers)
    engine.graphics.draw_text(1, 0,
        string.format("Level:%d  Moves:%d", level, moves), 0xCCCCCC)
    if msg ~= "" then
        engine.graphics.draw_text(1, 1, msg, 0xFFCC44)
    end
end

function engine.on_key(key, action)
    if action ~= "press" then return end

    if key == "up"    then try_move(0, -1)
    elseif key == "down"  then try_move(0, 1)
    elseif key == "left"  then try_move(-1, 0)
    elseif key == "right" then try_move(1, 0)
    elseif key == "s" then save_game()
    elseif key == "l" then load_game()
    elseif key == "q" then engine.quit_game()
    end
end
