-- Platformer scene: collect coins, reach the flag
local collision = require("collision")
local player = require("player")
local level = require("level")

local M = {}

function M.new(shared)
    local scene = {}
    local coins = {}       -- { entity, wx, wy }
    local flag = nil        -- { entity, wx, wy }
    local collected = 0
    local total = #level.coins
    local cam_x = 0
    local won = false

    local function update_cam()
        local px = player.get_world_pos()
        local target = px - 160 + 16
        cam_x = math.max(0, math.min(target, level.w * level.tile - 320))
    end

    function scene.load()
        collected = 0
        won = false
        cam_x = 0

        -- Spawn coins
        for _, cp in ipairs(level.coins) do
            local e = engine.world.spawn()
            engine.world.set(e, "position", { x = 0, y = 0 })
            engine.world.set(e, "sprite", { image = shared.sheet_coin, layer = 3, scale = 2 })
            engine.world.set(e, "animation", {
                frames = { 0, 1, 2, 3 }, speed = 0.15, loop = true,
            })
            coins[#coins + 1] = { entity = e, wx = cp.x, wy = cp.y }
        end

        -- Spawn flag
        local fe = engine.world.spawn()
        engine.world.set(fe, "position", { x = 0, y = 0 })
        engine.world.set(fe, "sprite", { image = shared.sheet_flag, layer = 3, scale = 1 })
        engine.world.set(fe, "animation", {
            frames = { 0, 1, 2, 3 }, speed = 0.2, loop = true,
        })
        flag = { entity = fe, wx = level.flag_pos.x, wy = level.flag_pos.y }

        -- Music started in main.lua
    end

    function scene.update(dt)
        if won then return end

        update_cam()
        player.update(dt, level, shared, cam_x)
        update_cam()  -- re-center after player moved

        local px, py = player.get_world_pos()
        local phb = player.get_hitbox()
        local pax, pay = px + phb.ox, py + phb.oy

        -- Update coin screen positions + check collection
        local i = 1
        while i <= #coins do
            local c = coins[i]
            if engine.world.is_alive(c.entity) then
                engine.world.set(c.entity, "position", {
                    x = c.wx - cam_x, y = c.wy,
                })
                if collision.overlap(pax, pay, phb.w, phb.h, c.wx, c.wy, 20, 20) then
                    -- Tween up and despawn
                    local pos = engine.world.get(c.entity, "position")
                    engine.tween(pos, { y = pos.y - 20 }, 0.3, "ease_out")
                    engine.world.set(c.entity, "position", pos)
                    local ent = c.entity
                    engine.timer.after(0.3, function()
                        if engine.world.is_alive(ent) then engine.world.despawn(ent) end
                    end)
                    table.remove(coins, i)
                    collected = collected + 1
                else
                    i = i + 1
                end
            else
                table.remove(coins, i)
            end
        end

        -- Update flag screen position + check win
        if flag and engine.world.is_alive(flag.entity) then
            engine.world.set(flag.entity, "position", {
                x = flag.wx - cam_x, y = flag.wy,
            })
            if collected >= total then
                if collision.overlap(pax, pay, phb.w, phb.h,
                                     flag.wx, flag.wy, 48, 48) then
                    won = true
                end
            end
        end
    end

    local BG_SPEEDS = { 0.0, 0.1, 0.2, 0.4, 0.6 }

    function scene.draw()
        -- Parallax backgrounds (576x324 images, viewport 320x192)
        engine.graphics.set_layer(0)
        engine.graphics.pixel.clear()
        for i = 1, 3 do
            local offset = math.floor(cam_x * BG_SPEEDS[i])
            engine.graphics.draw_sprite(shared.bg[i], -offset, -66)
        end
        engine.graphics.set_layer(1)
        engine.graphics.pixel.clear()
        for i = 4, 5 do
            local offset = math.floor(cam_x * BG_SPEEDS[i])
            engine.graphics.draw_sprite(shared.bg[i], -offset, -66)
        end

        -- Tilemap on layer 2
        engine.graphics.set_layer(2)
        engine.graphics.pixel.clear()
        engine.graphics.draw_tilemap(shared.tiles_swamp, level.tilemap, {
            width = level.w, layer = 2, cam_x = cam_x, cam_y = 0,
        })

        -- HUD
        local coin_text = "Coins: " .. collected .. " / " .. total
        engine.graphics.draw_text(0, 0, coin_text, 0xFFDD44, 0x1a1a2e)
        if won then
            engine.graphics.draw_text(3, 2, "You Win!", 0x44FF44)
        elseif collected >= total then
            engine.graphics.draw_text(0, 1, "Reach the flag!", 0x88AAFF)
        end
    end

    function scene.unload()
        for _, c in ipairs(coins) do
            if engine.world.is_alive(c.entity) then engine.world.despawn(c.entity) end
        end
        coins = {}
        if flag and engine.world.is_alive(flag.entity) then
            engine.world.despawn(flag.entity)
        end
        flag = nil
    end

    function scene.on_key(key, action)
        if action == "press" and (key == "q" or key == "escape") then
            engine.quit()
        end
    end

    return scene
end

return M
