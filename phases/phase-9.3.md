# Phase 9.3 — Dungeon Exploration

## Goal
Procedurally generated dungeon floors with free-movement top-down navigation, visible patrolling enemies, fog of war, and battle triggers. Encounter → battle → dungeon flow complete.

---

## Design Context

**View**: Free-move top-down, Zelda/Undertale feel.
**Canvas**: 640×320px dungeon viewport (40×20 tiles at 16×16px) + 40px HUD strip at bottom.
**Player avatar**: Active critter sprite walks the dungeon. Party order changes who you see.
**Enemy behavior**: Calm patrol until player enters 3-tile detection radius (~48px), then chase. Contact at ~8px triggers battle.
**Fog of war**: Per-room reveal. Adjacent rooms visible as dim silhouette through doorways.
**Optional clearing**: Rooms do not need to be cleared. Stairs only unblock after boss dies.

**Floor layout:**
```
Start room → 2-3 enemy rooms → optional chest room → boss room
```
Boss floors (5, 10, 15): add locked shop room after boss.

**Chest room rewards**: 60% item, 30% currency 50-150g, 10% peaceful catchable critter.

**HUD strip (640×40px):**
```
[Active ████░] [Bench1 ████░] [Bench2 ████░]   Floor 5/15   💰 340g
```

**Layer usage:**
- 0: dungeon tilemap (walls, floors, doors)
- 1: entities (player sprite, enemy sprites, chests, stairs)
- 2: fog of war overlay (dark rects, dim silhouettes)
- 3: HUD strip, minimap overlay

---

## Files to Create

### `dungeon/floor_gen.lua`
Procedural floor generation. Returns a floor data structure.

```lua
local M = {}

-- Tile IDs (match dungeon-tileset.png strip layout)
M.TILE = {
  WALL       = 0,
  FLOOR      = 1,
  DOOR_H     = 2,
  DOOR_V     = 3,
  STAIRS     = 4,
  CHEST      = 5,
}

-- Room structure
-- { x, y, w, h, type, enemies, chest, cleared, revealed }
-- types: "start" | "enemy" | "chest" | "boss" | "shop"

function M.generate(floor_num, biome, encounter_pool)
  local floor = {
    width = 40, height = 20,
    tiles = {},
    rooms = {},
    enemies = {},   -- { species_id, level, x, y, state, patrol_path }
    chests = {},    -- { x, y, item_id, currency, critter_id, opened }
    stairs = nil,   -- { x, y, locked=true/false }
    fog = {},       -- [y][x] = "hidden"|"silhouette"|"revealed"
  }

  -- Initialize all tiles as walls
  for y = 1, floor.height do
    floor.tiles[y] = {}
    floor.fog[y] = {}
    for x = 1, floor.width do
      floor.tiles[y][x] = M.TILE.WALL
      floor.fog[y][x] = "hidden"
    end
  end

  -- Generate rooms
  local room_count = math.random(4, 6)
  local rooms = M._place_rooms(floor, room_count)
  floor.rooms = rooms

  -- Carve corridors between rooms
  M._carve_corridors(floor, rooms)

  -- Assign room types
  rooms[1].type = "start"
  rooms[#rooms].type = "boss"

  local chest_room_idx = nil
  if #rooms >= 4 and math.random() < 0.5 then
    -- One of the middle rooms becomes a chest room
    local mid = math.random(2, #rooms - 1)
    rooms[mid].type = "chest"
    chest_room_idx = mid
  end

  for i = 2, #rooms do
    if rooms[i].type == nil then
      rooms[i].type = "enemy"
    end
  end

  -- Populate enemies in enemy rooms
  local enemy_level = 3 + floor_num * 2 + math.random(-1, 1)
  enemy_level = math.min(50, math.max(1, enemy_level))

  for _, room in ipairs(rooms) do
    if room.type == "enemy" then
      local count = math.random(2, 3)
      for _ = 1, count do
        local species_id = M._pick_encounter(encounter_pool, floor_num)
        local ex = room.x + math.random(1, room.w - 2)
        local ey = room.y + math.random(1, room.h - 2)
        table.insert(floor.enemies, {
          species_id = species_id,
          level = enemy_level,
          x = ex * 16, y = ey * 16,  -- pixel coords
          tx = ex, ty = ey,           -- tile coords
          home_room = room,
          state = "patrol",           -- "patrol" | "chase" | "defeated"
          patrol_timer = 0,
          patrol_dx = (math.random(2)==1) and 1 or -1,
          patrol_dy = 0,
          defeated = false,
        })
      end
    elseif room.type == "boss" then
      local boss_spec = M._pick_boss(biome, floor_num)
      table.insert(floor.enemies, {
        species_id = boss_spec.species,
        level = enemy_level + (boss_spec.level_bonus or 3),
        x = (room.x + room.w//2) * 16,
        y = (room.y + room.h//2) * 16,
        tx = room.x + room.w//2,
        ty = room.y + room.h//2,
        home_room = room,
        state = "patrol",
        is_boss = true,
        defeated = false,
      })
    end
  end

  -- Chest room contents
  if chest_room_idx then
    local room = rooms[chest_room_idx]
    local cx = room.x + room.w//2
    local cy = room.y + room.h//2
    local roll = math.random(100)
    local chest = { tx = cx, ty = cy, x = cx*16, y = cy*16, opened = false }
    if roll <= 60 then
      chest.kind = "item"
      chest.item_id = M._pick_chest_item(floor_num)
    elseif roll <= 90 then
      chest.kind = "currency"
      chest.amount = math.random(50, 150)
    else
      chest.kind = "critter"
      chest.species_id = M._pick_rare_critter(encounter_pool, floor_num)
    end
    table.insert(floor.chests, chest)
    floor.tiles[cy][cx] = M.TILE.CHEST
  end

  -- Stairs in boss room (locked until boss defeated)
  local boss_room = rooms[#rooms]
  local sx = boss_room.x + boss_room.w//2 + 2
  local sy = boss_room.y + boss_room.h//2
  floor.stairs = { tx=sx, ty=sy, x=sx*16, y=sy*16, locked=true }

  -- Reveal start room immediately
  M.reveal_room(floor, rooms[1])

  return floor
end

-- Reveal all tiles in a room and silhouette adjacent rooms
function M.reveal_room(floor, room)
  for y = room.y, room.y + room.h - 1 do
    for x = room.x, room.x + room.w - 1 do
      if y >= 1 and y <= floor.height and x >= 1 and x <= floor.width then
        floor.fog[y][x] = "revealed"
      end
    end
  end
  room.revealed = true
  -- Mark adjacent corridor tiles
  -- (corridors between rooms are revealed when the room connecting them is revealed)
end

-- Internal helpers (placement, carving, encounter picking)
function M._place_rooms(floor, count) -- ... end
function M._carve_corridors(floor, rooms) -- ... end
function M._pick_encounter(pool, floor_num) -- weighted random from pool end
function M._pick_boss(biome, floor_num) -- from biome.boss_pool end
function M._pick_chest_item(floor_num) -- scaling item quality end
function M._pick_rare_critter(pool, floor_num) -- uncommon+ from pool end

return M
```

### `dungeon/run.lua`
Active run state. Passed to and from scenes via `engine.scene.push`.

```lua
local M = {}

function M.new(party, biome_id, biomes_data)
  return {
    party       = party,          -- array of critter tables
    biome_id    = biome_id,
    floor       = 1,
    max_floor   = 15,
    currency    = 0,
    inventory   = {},             -- { item_id = count }
    catches     = {},             -- critters caught this run
    floor_data  = nil,            -- current floor (from floor_gen)
    run_state   = "active",       -- "active"|"extracted"|"wiped"
    scars_this_run = {},
  }
end

-- Add currency
function M.add_currency(run, amount)
  run.currency = run.currency + amount
end

-- Add item to inventory
function M.add_item(run, item_id, count)
  count = count or 1
  run.inventory[item_id] = (run.inventory[item_id] or 0) + count
end

-- Use item (returns false if not available)
function M.use_item(run, item_id)
  if not run.inventory[item_id] or run.inventory[item_id] <= 0 then return false end
  run.inventory[item_id] = run.inventory[item_id] - 1
  return true
end

-- Record a catch
function M.record_catch(run, critter)
  table.insert(run.catches, critter)
end

-- Check if entire party is fainted
function M.is_wiped(run)
  for _, c in ipairs(run.party) do
    if c.hp > 0 then return false end
  end
  return true
end

-- Get active (first non-fainted) party member
function M.get_active(run)
  for _, c in ipairs(run.party) do
    if c.hp > 0 then return c end
  end
  return nil
end

return M
```

### `ui/dungeon_screen.lua`
The dungeon exploration scene. Free-movement, rendering, enemy AI, battle trigger.

```lua
local floor_gen = require("dungeon.floor_gen")
local run_mod   = require("dungeon.run")
local widgets   = require("ui.widgets")
local registry  = require("sprite.registry")
local music     = require("audio.music")
local species   = require("data.species")
local biomes    = require("data.biomes")

local scene = {}
local run_state
local floor
local player

-- Pixel movement state
local px, py           -- player pixel position
local PLAYER_SPEED = 96  -- px/sec
local keys_held = {}

-- Camera offset (center player on screen)
local cam_x, cam_y

-- Sprite animation state for player and each enemy
local player_sprite_state
local enemy_sprite_states = {}

-- Pending battle data (set when encounter triggers)
local pending_battle = nil

function scene.load(data)
  run_state = data.run
  local biome = biomes[run_state.biome_id] or biomes.generic_dungeon
  local pool = biome.encounter_table

  floor = floor_gen.generate(run_state.floor, biome, pool)
  run_state.floor_data = floor

  -- Place player in start room center
  local start = floor.rooms[1]
  px = (start.x + start.w//2) * 16
  py = (start.y + start.h//2) * 16

  -- Init enemy sprite states
  enemy_sprite_states = {}
  for i, enemy in ipairs(floor.enemies) do
    enemy_sprite_states[i] = {
      frame = 0, timer = 0, anim = "idle",
    }
  end

  -- Update camera
  cam_x = px - 320
  cam_y = py - 160

  music.play(run_state.floor <= 10 and "dungeon" or "dungeon_deep")

  player_sprite_state = { frame = 0, timer = 0, anim = "idle" }
end

function scene.update(dt)
  if pending_battle then return end  -- waiting for battle to resolve

  -- Player movement
  local dx, dy = 0, 0
  if keys_held["right"] or keys_held["l"] then dx = 1 end
  if keys_held["left"]  or keys_held["h"] then dx = -1 end
  if keys_held["down"]  or keys_held["j"] then dy = 1 end
  if keys_held["up"]    or keys_held["k"] then dy = -1 end

  if dx ~= 0 or dy ~= 0 then
    local nx = px + dx * PLAYER_SPEED * dt
    local ny = py + dy * PLAYER_SPEED * dt

    -- Collision check against wall tiles
    if not scene._is_wall(nx, py) then px = nx end
    if not scene._is_wall(px, ny) then py = ny end

    -- Update sprite animation
    player_sprite_state.anim = "idle"  -- will be "walk" when we have walk frames
  end

  -- Camera follows player (smooth)
  local target_cx = px - 320
  local target_cy = py - 160
  cam_x = cam_x + (target_cx - cam_x) * math.min(1, dt * 8)
  cam_y = cam_y + (target_cy - cam_y) * math.min(1, dt * 8)

  -- Clamp camera to floor bounds
  cam_x = math.max(0, math.min(floor.width*16 - 640, cam_x))
  cam_y = math.max(0, math.min(floor.height*16 - 320, cam_y))

  -- Check room entry for fog update
  local ptx = math.floor(px / 16) + 1
  local pty = math.floor(py / 16) + 1
  for _, room in ipairs(floor.rooms) do
    if not room.revealed and
       ptx >= room.x and ptx < room.x + room.w and
       pty >= room.y and pty < room.y + room.h then
      floor_gen.reveal_room(floor, room)
    end
  end

  -- Update enemy AI
  for i, enemy in ipairs(floor.enemies) do
    if not enemy.defeated then
      scene._update_enemy(enemy, enemy_sprite_states[i], dt)
    end
  end

  -- Check chest interaction (Z key handled in on_key)
  -- Check stairs interaction (Z key handled in on_key)
end

function scene._is_wall(x, y)
  -- Check all 4 corners of player hitbox (8×8 centered)
  local hw = 6
  local corners = {
    {x - hw, y - hw}, {x + hw, y - hw},
    {x - hw, y + hw}, {x + hw, y + hw},
  }
  for _, c in ipairs(corners) do
    local tx = math.floor(c[1] / 16) + 1
    local ty = math.floor(c[2] / 16) + 1
    if tx < 1 or tx > floor.width or ty < 1 or ty > floor.height then
      return true
    end
    local tile = floor.tiles[ty] and floor.tiles[ty][tx]
    if tile == floor_gen.TILE.WALL then return true end
  end
  return false
end

function scene._update_enemy(enemy, sprite_state, dt)
  local ex, ey = enemy.x, enemy.y
  local dist = math.sqrt((px-ex)^2 + (py-ey)^2)

  -- State transitions
  if enemy.state == "patrol" and dist < 48 then
    enemy.state = "chase"
  elseif enemy.state == "chase" and dist > 80 then
    enemy.state = "patrol"
  end

  if enemy.state == "patrol" then
    -- Simple back-and-forth patrol
    enemy.patrol_timer = enemy.patrol_timer + dt
    if enemy.patrol_timer > 1.5 then
      enemy.patrol_dx = -enemy.patrol_dx
      enemy.patrol_timer = 0
    end
    local nx = ex + enemy.patrol_dx * 48 * dt
    local ny = ey
    if not scene._is_wall(nx, ny) then
      enemy.x = nx
    else
      enemy.patrol_dx = -enemy.patrol_dx
    end

  elseif enemy.state == "chase" then
    local speed = 72  -- slightly slower than player
    local ddx = px - ex
    local ddy = py - ey
    local len = math.max(1, math.sqrt(ddx*ddx + ddy*ddy))
    local nx = ex + (ddx/len) * speed * dt
    local ny = ey + (ddy/len) * speed * dt
    if not scene._is_wall(nx, ey) then enemy.x = nx end
    if not scene._is_wall(ex, ny) then enemy.y = ny end
  end

  -- Battle trigger: contact
  if dist < 8 and not enemy.defeated then
    scene._trigger_battle(enemy)
  end
end

function scene._trigger_battle(enemy)
  enemy.defeated = true  -- prevent double-trigger

  local active = run_mod.get_active(run_state)
  local battle_data = {
    party = run_state.party,
    enemy = scene._make_live_critter(enemy.species_id, enemy.level),
    encounter_type = enemy.is_boss and "boss_team" or "wild",
    floor = run_state.floor,
    run = run_state,
  }

  -- Boss: build team from biome boss pool
  if enemy.is_boss then
    local biome = biomes[run_state.biome_id] or biomes.generic_dungeon
    local boss_entry = scene._get_boss_entry(biome, run_state.floor)
    if boss_entry and #boss_entry > 1 then
      battle_data.boss_team = {}
      for _, entry in ipairs(boss_entry) do
        table.insert(battle_data.boss_team,
          scene._make_live_critter(entry.species, enemy.level + (entry.level_bonus or 0)))
      end
      battle_data.enemy = battle_data.boss_team[1]
    end
    -- Some bosses have a minion
    if boss_entry and boss_entry.minion then
      battle_data.encounter_type = "boss_minion"
      battle_data.minion = scene._make_live_critter(boss_entry.minion, enemy.level - 2)
    end
  end

  pending_battle = battle_data
  engine.scene.push("battle", battle_data)
end

function scene._make_live_critter(species_id, level)
  local s = require("data.species")[species_id]
  local stat = require("critter.stats")
  local c = {
    species_id = species_id,
    name = s.name,
    type = s.type,
    archetype = s.archetype,
    level = level,
    xp = 0, scars = {},
    moves = {s.move1, s.move2},
    status = nil, status_turns = 0,
    hold_item = nil,
  }
  stat.apply_level_stats(c, require("data.species"))
  c.hp = c.max_hp
  return c
end

-- Called when battle scene pops back
function scene.resume(result)
  pending_battle = nil

  if result then
    -- Apply XP to party
    for _, c in ipairs(run_state.party) do
      if c.hp > 0 then
        require("critter.stats").add_xp(c, result.xp_reward or 0, require("data.species"))
      end
    end

    -- Add currency
    run_mod.add_currency(run_state, result.currency or 0)

    -- Record catches
    for _, caught in ipairs(result.catches or {}) do
      run_mod.record_catch(run_state, caught)
    end

    -- Apply scars to fainted party members (done in battle engine, reflected in critter table)

    -- Check wipe
    if run_mod.is_wiped(run_state) then
      engine.scene.switch("run_over", { run = run_state, outcome = "wipe" })
      return
    end

    -- Check if boss was beaten — unlock stairs
    if result.was_boss then
      floor.stairs.locked = false
      -- Boss floor: go to shop
      if run_state.floor % 5 == 0 then
        engine.scene.push("shop", { run = run_state })
        return
      end
    end
  end
end

function scene.draw()
  local cx, cy = math.floor(cam_x), math.floor(cam_y)

  engine.graphics.set_layer(0)
  -- Draw visible tiles (only within viewport + 1 tile margin)
  local tile_x0 = math.max(1, math.floor(cx/16))
  local tile_y0 = math.max(1, math.floor(cy/16))
  local tile_x1 = math.min(floor.width,  tile_x0 + 42)
  local tile_y1 = math.min(floor.height, tile_y0 + 22)

  for ty = tile_y0, tile_y1 do
    for tx = tile_x0, tile_x1 do
      local fog_state = floor.fog[ty] and floor.fog[ty][tx] or "hidden"
      if fog_state ~= "hidden" then
        local tile = floor.tiles[ty][tx]
        local sx = (tx-1)*16 - cx
        local sy = (ty-1)*16 - cy
        -- draw tile from tileset spritesheet
        engine.graphics.draw_sprite(
          tileset_sheet,
          sx, sy,
          { frame = tile, scale = 1 }
        )
      end
    end
  end

  engine.graphics.set_layer(1)
  -- Draw chests
  for _, chest in ipairs(floor.chests) do
    if not chest.opened then
      local sx = chest.x - cx
      local sy = chest.y - cy
      -- draw chest sprite
    end
  end

  -- Draw stairs (if unlocked)
  if floor.stairs and not floor.stairs.locked then
    local sx = floor.stairs.x - cx
    local sy = floor.stairs.y - cy
    -- draw stairs sprite
  end

  -- Draw enemies
  for i, enemy in ipairs(floor.enemies) do
    if not enemy.defeated then
      local sx = enemy.x - cx - 16
      local sy = enemy.y - cy - 16
      local fog_state = floor.fog[math.floor(enemy.y/16)+1]
        and floor.fog[math.floor(enemy.y/16)+1][math.floor(enemy.x/16)+1]
      if fog_state == "revealed" then
        local reg = registry[enemy.species_id] or registry.default
        engine.graphics.draw_sprite(reg.path, sx, sy, {
          frame = enemy_sprite_states[i].frame,
          frame_w = reg.frame_w, frame_h = reg.frame_h,
          scale = reg.scale or 1,
        })
      end
    end
  end

  -- Draw player
  local player_screen_x = px - cx - 16
  local player_screen_y = py - cy - 16
  local active = run_mod.get_active(run_state)
  if active then
    local reg = registry[active.species_id] or registry.default
    engine.graphics.draw_sprite(reg.path, player_screen_x, player_screen_y, {
      frame = player_sprite_state.frame,
      frame_w = reg.frame_w, frame_h = reg.frame_h,
      scale = reg.scale or 1,
    })
  end

  engine.graphics.set_layer(2)
  -- Fog of war: dark overlay with per-tile transparency
  for ty = tile_y0, tile_y1 do
    for tx = tile_x0, tile_x1 do
      local fog_state = floor.fog[ty] and floor.fog[ty][tx] or "hidden"
      local sx = (tx-1)*16 - cx
      local sy = (ty-1)*16 - cy
      if fog_state == "hidden" then
        engine.graphics.pixel.rect(sx, sy, 16, 16, 0, 0, 0, 255)
      elseif fog_state == "silhouette" then
        engine.graphics.pixel.rect(sx, sy, 16, 16, 0, 0, 0, 140)
      end
    end
  end

  engine.graphics.set_layer(3)
  -- HUD strip (y=320 to 360)
  engine.graphics.pixel.rect(0, 320, 640, 40, 15, 15, 20, 240)
  local x = 4
  for i, c in ipairs(run_state.party) do
    widgets.hp_bar(x, 326, c.hp, c.max_hp, 80)
    engine.graphics.text(x, 335, c.name:sub(1,8), 200, 200, 200)
    x = x + 92
  end
  engine.graphics.text(400, 326, string.format("Floor %d/15", run_state.floor), 200, 200, 150)
  engine.graphics.text(500, 326, string.format("💰 %dg", run_state.currency), 200, 180, 50)

  -- Minimap (top-right 64×48)
  scene._draw_minimap(576, 4)
end

function scene._draw_minimap(mx, my)
  engine.graphics.pixel.rect(mx-2, my-2, 68, 52, 0, 0, 0, 180)
  for _, room in ipairs(floor.rooms) do
    if room.revealed then
      local rx = mx + math.floor(room.x * 64 / floor.width)
      local ry = my + math.floor(room.y * 48 / floor.height)
      local rw = math.max(2, math.floor(room.w * 64 / floor.width))
      local rh = math.max(2, math.floor(room.h * 48 / floor.height))
      local r, g, b = 80, 80, 100
      if room.type == "boss" then r,g,b = 180,50,50 end
      if room.type == "chest" then r,g,b = 180,160,50 end
      engine.graphics.pixel.rect(rx, ry, rw, rh, r, g, b, 255)
    end
  end
  -- Player dot
  local pdx = mx + math.floor(px * 64 / (floor.width*16))
  local pdy = my + math.floor(py * 48 / (floor.height*16))
  engine.graphics.pixel.rect(pdx-1, pdy-1, 3, 3, 255, 255, 100, 255)
end

function scene.on_key(key, is_press)
  if is_press then
    keys_held[key] = true
    -- Interact with chest or stairs
    if key == "z" or key == "return" then
      scene._try_interact()
    end
  else
    keys_held[key] = false
  end
end

function scene._try_interact()
  -- Check for stairs
  if floor.stairs and not floor.stairs.locked then
    local dist = math.sqrt((px-floor.stairs.x)^2 + (py-floor.stairs.y)^2)
    if dist < 20 then
      scene._advance_floor()
      return
    end
  end

  -- Check for chests
  for _, chest in ipairs(floor.chests) do
    if not chest.opened then
      local dist = math.sqrt((px-chest.x)^2 + (py-chest.y)^2)
      if dist < 20 then
        scene._open_chest(chest)
        return
      end
    end
  end
end

function scene._open_chest(chest)
  chest.opened = true
  if chest.kind == "currency" then
    run_mod.add_currency(run_state, chest.amount)
  elseif chest.kind == "item" then
    run_mod.add_item(run_state, chest.item_id)
  elseif chest.kind == "critter" then
    -- Trigger a peaceful critter encounter (different from battle trigger)
    local critter = scene._make_live_critter(chest.species_id, run_state.floor * 2 + 3)
    engine.scene.push("battle", {
      party = run_state.party,
      enemy = critter,
      encounter_type = "wild",
      peaceful_start = true,  -- battle starts with catch menu pre-selected
      run = run_state,
      floor = run_state.floor,
    })
  end
end

function scene._advance_floor()
  run_state.floor = run_state.floor + 1
  if run_state.floor > run_state.max_floor then
    -- Completed the run!
    engine.scene.switch("run_over", { run = run_state, outcome = "victory" })
    return
  end
  -- Regenerate floor and reload scene
  engine.scene.switch("dungeon", { run = run_state })
end

return scene
```

---

## Task Checklist

- [ ] `dungeon/floor_gen.lua`:
  - [ ] Room placement (non-overlapping, within 40×20 bounds)
  - [ ] Corridor carving between rooms
  - [ ] Room type assignment (start, enemy×2-3, chest×0-1, boss)
  - [ ] Enemy spawning per enemy room (level = 3 + floor×2 ±1)
  - [ ] Boss enemy spawning with biome boss pool
  - [ ] Chest room content generation (60/30/10% split)
  - [ ] Stairs placement in boss room (locked=true initially)
  - [ ] Fog state initialization
  - [ ] `reveal_room()` — mark tiles as revealed, adjacent as silhouette
- [ ] `dungeon/run.lua`:
  - [ ] `new()` — run state constructor
  - [ ] `add_currency`, `add_item`, `use_item`
  - [ ] `record_catch`, `is_wiped`, `get_active`
- [ ] `ui/dungeon_screen.lua`:
  - [ ] `load()` — floor generation, player placement, sprite init
  - [ ] `update()` — movement, collision, camera, fog, enemy AI, battle trigger
  - [ ] `_is_wall()` — AABB corner collision check
  - [ ] `_update_enemy()` — patrol, detect, chase, contact trigger
  - [ ] `_trigger_battle()` — build battle_data, push battle scene
  - [ ] `resume()` — handle battle result (XP, currency, catches, wipe check, stairs unlock, shop transition)
  - [ ] `draw()` — tiles (layer 0), entities (layer 1), fog (layer 2), HUD+minimap (layer 3)
  - [ ] `_draw_minimap()` — 64×48 room map overlay
  - [ ] `on_key()` — movement keys held, Z interact
  - [ ] `_open_chest()` — apply rewards, peaceful critter push
  - [ ] `_advance_floor()` — increment floor, switch or end run
  - [ ] Load dungeon tileset spritesheet
  - [ ] Dungeon music plays, changes to tense on floor 11+
- [ ] `main.lua` updated: register "dungeon" scene, start with a test run
- [ ] Wire dungeon → battle → dungeon flow (scene push/pop)

## Verification

`zig build run -- games/codecritter/` shows the dungeon screen:
- Rooms visible with fog of war revealing on entry
- Active critter sprite walks freely with AABB collision
- Enemies patrol rooms, chase when player approaches
- Contact with enemy transitions to battle screen
- Return from battle: XP applied, currency shown in HUD
- Reach stairs (after defeating boss): advance to next floor
