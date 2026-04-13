-- Battle screen scene. Receives data from engine.scene.push("battle", data).
-- data = {
--   party = { critter1, critter2, ... },
--   enemy = critter,
--   encounter_type = "wild"|"boss_team"|"boss_minion"|"swarm",
--   boss_team = { critter1, critter2, ... },  -- for boss_team
--   minion = critter,                          -- for boss_minion
--   swarm = { critter1, critter2, ... },       -- for swarm
--   biome = biome_id,
--   floor = floor_num,
--   gold = number,                             -- optional, dungeon gold
--   inventory = { item1, item2, ... },         -- optional
-- }

local widgets    = require("ui.widgets")
local anim       = require("ui.anim")
local music      = require("audio.music")
local battle   = require("battle.engine")
local ai       = require("battle.ai")
local status   = require("battle.status")
local stat     = require("critter.stats")
local types    = require("data.types")
local moves    = require("data.moves")
local items    = require("data.items")
local species  = require("data.species")

local scene = {}

-- Battle state
local state
local seq           -- animation sequencer

-- Virtual resolution
local W, H = 640, 360

-- Cell-based layout (populated in scene.load)
local L = {}

-----------------------------------------------------------------------
-- Animation templates — picked by frame count at load time
-----------------------------------------------------------------------

local ANIM_TEMPLATES = {
  [11] = { -- base forms
    idle   = { frames = {0,1,2,3},   speed = 0.4,  },
    attack = { frames = {4,5,6},     speed = 0.12, },
    hit    = { frames = {7,8},       speed = 0.15, },
    faint  = { frames = {9,10},      speed = 0.3,  },
  },
  [12] = { -- mid evolutions
    idle   = { frames = {0,1,2,3,4},  speed = 0.4,  },
    attack = { frames = {5,6,7},      speed = 0.12, },
    hit    = { frames = {8,9},        speed = 0.15, },
    faint  = { frames = {10,11},      speed = 0.3,  },
  },
  [14] = { -- final forms
    idle   = { frames = {0,1,2,3,4,5}, speed = 0.4,  },
    attack = { frames = {6,7,8},       speed = 0.12, },
    hit    = { frames = {9,10},        speed = 0.15, },
    faint  = { frames = {11,12,13},    speed = 0.3,  },
  },
}
local PLACEHOLDER_TEMPLATE = {
  idle   = { frames = {0,1}, speed = 0.5,  },
  attack = { frames = {0},   speed = 0.1,  },
  hit    = { frames = {1},   speed = 0.1,  },
  faint  = { frames = {1},   speed = 0.1,  },
}

local function get_template(sheet)
  return ANIM_TEMPLATES[engine.graphics.get_frame_count(sheet)] or PLACEHOLDER_TEMPLATE
end

-----------------------------------------------------------------------
-- ECS sprite management
-----------------------------------------------------------------------

-- Per-critter sprite state: { entity, sheet, template }
local player_sprite = nil
local enemy_sprite  = nil
local minion_sprite = nil

local function spawn_critter_sprite(species_id, x, y, flip_x)
  local path = "assets/sprites/" .. species_id .. ".png"
  local ok, sheet = pcall(engine.graphics.load_spritesheet, path, 32, 32)
  if not ok then return nil end
  local tmpl = get_template(sheet)
  local e = engine.world.spawn()
  engine.world.set(e, "position", { x = x, y = y })
  engine.world.set(e, "sprite", { image = sheet, layer = 1, scale = 2, flip_x = flip_x or false })
  engine.world.set(e, "animation", { frames = tmpl.idle.frames, speed = tmpl.idle.speed, loop = true })
  return { entity = e, sheet = sheet, template = tmpl }
end

local function despawn_critter_sprite(cs)
  if not cs then return end
  if cs.entity and engine.world.is_alive(cs.entity) then
    engine.world.despawn(cs.entity)
  end
  if cs.sheet then pcall(engine.graphics.unload_image, cs.sheet) end
end

local function play_critter_anim(cs, anim_name, on_done)
  if not cs or not cs.entity then return end
  local a = cs.template[anim_name]
  if not a then return end
  local is_idle = (anim_name == "idle")
  engine.world.set(cs.entity, "animation", {
    frames = a.frames, speed = a.speed, loop = is_idle,
    on_complete = is_idle and nil or (on_done or function()
      play_critter_anim(cs, "idle")
    end),
  })
end

local function add_msg(text, color)
  table.insert(state.messages, { text = text, color = color or 0xDCDCDC })
end

local function active_player()
  return state.party[state.active_idx]
end

local function get_enemy()
  return state.enemy
end

local function find_next_alive(party, skip_idx)
  for i, c in ipairs(party) do
    if i ~= skip_idx and c.hp > 0 then return i end
  end
  return nil
end


-----------------------------------------------------------------------
-- Menu actions
-----------------------------------------------------------------------

local menu_labels        = { "Attack", "Catch", "Swap", "Item" }
local menu_labels_minion = { "Attack", "Catch", "Swap", "Item", "Bench" }
local menu_keys          = { "moves", "catch", "swap", "items" }

local function enter_submenu(sub)
  state.sub_menu = sub
  state.sub_cursor = 1
  state.phase = "sub_menu"
end

local function exit_submenu()
  state.sub_menu = nil
  state.phase = "player_action"
end

-----------------------------------------------------------------------
-- Turn resolution
-----------------------------------------------------------------------

local function push_attack_steps(s, attacker, move_id, defender, attacker_name, defender_name, is_player)
  local m = type(move_id) == "string" and moves[move_id] or move_id
  if not m then
    anim.push(s, function() add_msg(attacker_name .. " has no move!") end, 0.6)
    return
  end

  -- Apply turn start (blocked check) — skip if already fainted
  anim.push(s, function()
    if attacker.hp <= 0 or defender.hp <= 0 then return end
    status.apply_turn_start(attacker)
  end, 0.0)

  -- Trigger attacker's attack animation
  anim.push(s, function()
    if attacker.hp <= 0 or defender.hp <= 0 then return end
    play_critter_anim(is_player and player_sprite or enemy_sprite, "attack")
  end, 0.4)

  anim.push(s, function()
    if attacker.hp <= 0 or defender.hp <= 0 then return end
    local result = battle.process_attack(attacker, m, defender, moves)

    if result.blocked_by_status then
      add_msg(attacker_name .. " is blocked!")
      return
    end
    if result.linted_blocked then
      add_msg(attacker_name .. " can't use " .. m.name .. " (linted!)")
      return
    end
    if result.missed then
      add_msg(attacker_name .. " used " .. m.name .. " — missed!")
      return
    end

    -- Hit
    local target = result.self_targeted and attacker or defender
    local target_name = result.self_targeted and attacker_name or defender_name
    target.hp = math.max(0, target.hp - result.damage)

    -- Trigger hit animation
    play_critter_anim(is_player and enemy_sprite or player_sprite, "hit")
    if result.self_targeted then
      add_msg(attacker_name .. " used " .. m.name .. " — hit self! " .. result.damage .. " dmg")
    else
      local label = battle.eff_label(result.eff or 1.0)
      add_msg(attacker_name .. " used " .. m.name .. " — " .. result.damage .. " dmg" .. label)
    end

    if result.status_applied then
      add_msg(target_name .. " is now " .. result.status_applied .. "!")
    end
  end, 0.8)
end

local function push_status_tick_steps(s)
  anim.push(s, function()
    local p = active_player()
    local e = get_enemy()
    local p_dmg = status.tick(p)
    if p_dmg then
      p.hp = math.max(0, p.hp - p_dmg)
      add_msg(p.name .. " takes " .. p_dmg .. " status damage!")
    end
    local e_dmg = status.tick(e)
    if e_dmg then
      e.hp = math.max(0, e.hp - e_dmg)
      add_msg(e.name .. " takes " .. e_dmg .. " status damage!")
    end
  end, 0.5)
end

local function begin_victory_sequence()
  seq = anim.new()
  local winner = active_player()
  local enemy_lvl = state.enemy.level

  anim.push(seq, function()
    add_msg(state.enemy.name .. " fainted!", 0xFF6644)
    play_critter_anim(enemy_sprite, "faint", function() end) -- stay on last frame
  end, 1.0)

  anim.push(seq, function()
    local xp_gain, leveled = battle.award_xp(winner, enemy_lvl, species)
    add_msg(winner.name .. " gained " .. xp_gain .. " XP!", 0x44FF44)
    if leveled then
      add_msg(winner.name .. " reached Level " .. winner.level .. "!", 0xFFFF44)
    end
    if winner.evolved then
      local new_sp = species[winner.species_id]
      if new_sp then
        add_msg(winner.name .. " evolved into " .. new_sp.name .. "!", 0xFF88FF)
        winner.name = new_sp.name
        winner.critter_type = new_sp.critter_type
        -- Reload sprite for evolved form
        despawn_critter_sprite(player_sprite)
        player_sprite = spawn_critter_sprite(winner.species_id, L.player_sprite_x, L.player_sprite_y, false)
      end
      winner.evolved = nil
    end
  end, 1.5)

  anim.push(seq, function()
    music.stop()
    state.phase = "end"
    state.result = "victory"
  end, 0.0)
end

local function begin_defeat_sequence()
  seq = anim.new()
  anim.push(seq, function()
    add_msg(active_player().name .. " fainted!", 0xFF4444)
    play_critter_anim(player_sprite, "faint", function() end) -- stay on last frame
  end, 1.0)
  anim.push(seq, function()
    add_msg("You blacked out...", 0xFF4444)
    music.stop()
    state.phase = "end"
    state.result = "defeat"
  end, 1.5)
end

local function check_end_conditions()
  local player = active_player()
  local enemy = get_enemy()

  if enemy.hp <= 0 then
    -- Boss team: next boss critter
    if state.encounter_type == "boss_team" then
      state.boss_idx = state.boss_idx + 1
      if state.boss_idx <= #state.boss_team then
        seq = anim.new()
        anim.push(seq, function()
          add_msg(state.enemy.name .. " fainted!", 0xFF6644)
        end, 0.8)
        anim.push(seq, function()
          state.enemy = state.boss_team[state.boss_idx]
          despawn_critter_sprite(enemy_sprite)
          enemy_sprite = spawn_critter_sprite(state.enemy.species_id, L.enemy_sprite_x, L.enemy_sprite_y, true)
          add_msg(state.enemy.name .. " enters the battle!")
        end, 0.8)
        anim.push(seq, function()
          state.phase = "player_action"
        end, 0.0)
        return
      end
    end
    -- Swarm: next critter
    if state.encounter_type == "swarm" then
      state.swarm_idx = state.swarm_idx + 1
      if state.swarm_idx <= #state.swarm then
        seq = anim.new()
        anim.push(seq, function()
          add_msg(state.enemy.name .. " fainted!", 0xFF6644)
        end, 0.8)
        anim.push(seq, function()
          state.enemy = state.swarm[state.swarm_idx]
          despawn_critter_sprite(enemy_sprite)
          enemy_sprite = spawn_critter_sprite(state.enemy.species_id, L.enemy_sprite_x, L.enemy_sprite_y, true)
          add_msg(string.format("[SWARM] %d of %d — %s appeared!",
            state.swarm_idx, #state.swarm, state.enemy.name))
        end, 0.8)
        anim.push(seq, function()
          state.phase = "player_action"
        end, 0.0)
        return
      end
    end
    begin_victory_sequence()
    return
  end

  if player.hp <= 0 then
    local next_idx = find_next_alive(state.party, state.active_idx)
    if next_idx then
      seq = anim.new()
      anim.push(seq, function()
        add_msg(player.name .. " fainted!", 0xFF4444)
      end, 0.8)
      anim.push(seq, function()
        state.active_idx = next_idx
        local new_p = active_player()
        despawn_critter_sprite(player_sprite)
        player_sprite = spawn_critter_sprite(new_p.species_id, L.player_sprite_x, L.player_sprite_y, false)
        add_msg("Go, " .. new_p.name .. "!")
      end, 0.8)
      anim.push(seq, function()
        state.phase = "player_action"
      end, 0.0)
      return
    end
    begin_defeat_sequence()
    return
  end

  state.phase = "player_action"
end

local function resolve_turn(player_move_id)
  state.phase = "resolving"
  seq = anim.new()

  local player = active_player()
  local enemy = get_enemy()
  local enemy_move = ai.choose_move(enemy, player, moves)

  local player_first = player.speed >= enemy.speed

  if player_first then
    push_attack_steps(seq, player, player_move_id, enemy, player.name, enemy.name, true)
    push_attack_steps(seq, enemy, enemy_move, player, enemy.name, player.name, false)
  else
    push_attack_steps(seq, enemy, enemy_move, player, enemy.name, player.name, false)
    push_attack_steps(seq, player, player_move_id, enemy, player.name, enemy.name, true)
  end

  push_status_tick_steps(seq)

  anim.push(seq, function()
    check_end_conditions()
  end, 0.0)
end

-----------------------------------------------------------------------
-- Input handlers
-----------------------------------------------------------------------

local function handle_action_input(key)
  local max_items = (state.encounter_type == "boss_minion") and 5 or 4
  if key == "up" then
    state.menu_cursor = ((state.menu_cursor - 2) % max_items) + 1
  elseif key == "down" then
    state.menu_cursor = (state.menu_cursor % max_items) + 1
  elseif key == "1" then enter_submenu("moves")
  elseif key == "2" then enter_submenu("catch")
  elseif key == "3" then enter_submenu("swap")
  elseif key == "4" then enter_submenu("items")
  elseif key == "5" and state.encounter_type == "boss_minion" then
    enter_submenu("bench")
  elseif key == "return" or key == "space" then
    local keys = {"moves", "catch", "swap", "items", "bench"}
    enter_submenu(keys[state.menu_cursor])
  end
end

local function handle_submenu_input(key)
  if key == "escape" or key == "b" then
    exit_submenu()
    return
  end

  if state.sub_menu == "moves" then
    local p = active_player()
    local count = #p.moves
    if key == "up" then
      state.sub_cursor = ((state.sub_cursor - 2) % count) + 1
    elseif key == "down" then
      state.sub_cursor = (state.sub_cursor % count) + 1
    elseif key == "return" or key == "space" then
      local move_id = p.moves[state.sub_cursor]
      exit_submenu()
      resolve_turn(move_id)
    else
      -- number shortcut
      local n = tonumber(key)
      if n and n >= 1 and n <= count then
        local move_id = p.moves[n]
        exit_submenu()
        resolve_turn(move_id)
      end
    end

  elseif state.sub_menu == "catch" then
    local inv = state.inventory
    local catch_tools = {}
    for _, item in ipairs(inv) do
      if items.is_catch_tool(item.id) then
        table.insert(catch_tools, item)
      end
    end
    local count = #catch_tools
    if count == 0 then
      add_msg("No catch tools!")
      exit_submenu()
      return
    end
    if key == "up" then
      state.sub_cursor = ((state.sub_cursor - 2) % count) + 1
    elseif key == "down" then
      state.sub_cursor = (state.sub_cursor % count) + 1
    elseif key == "return" or key == "space" then
      local tool = catch_tools[state.sub_cursor]
      exit_submenu()
      -- Catch attempt uses the player's turn
      state.phase = "resolving"
      seq = anim.new()
      anim.push(seq, function()
        local success, chance = battle.try_catch(tool, state.enemy, species)
        if success then
          add_msg(string.format("Used %s (%.0f%%) — Caught %s!", tool.name, chance, state.enemy.name), 0x44FF44)
          state.caught_critter = state.enemy
          music.stop()
          state.phase = "end"
          state.result = "caught"
        else
          add_msg(string.format("Used %s (%.0f%%) — Failed!", tool.name, chance), 0xFF8844)
          -- Remove used tool from inventory
          for i, it in ipairs(state.inventory) do
            if it == tool then table.remove(state.inventory, i); break end
          end
        end
      end, 0.8)
      -- If catch failed, enemy still attacks
      anim.push(seq, function()
        if state.phase == "end" then return end
        local enemy = get_enemy()
        local player = active_player()
        local enemy_move = ai.choose_move(enemy, player, moves)
        local result = battle.process_attack(enemy, enemy_move, player, moves)
        if result.blocked_by_status then
          add_msg(enemy.name .. " is blocked!")
        elseif result.missed then
          add_msg(enemy.name .. " used " .. (enemy_move.name or "?") .. " — missed!")
        elseif not result.linted_blocked then
          local target = result.self_targeted and enemy or player
          target.hp = math.max(0, target.hp - result.damage)
          local label = battle.eff_label(result.eff or 1.0)
          add_msg(enemy.name .. " used " .. (enemy_move.name or "?") .. " — " .. result.damage .. " dmg" .. label)
        end
      end, 0.8)
      anim.push(seq, function()
        if state.phase ~= "end" then
          check_end_conditions()
        end
      end, 0.0)
    end

  elseif state.sub_menu == "swap" then
    local count = #state.party
    if key == "up" then
      state.sub_cursor = ((state.sub_cursor - 2) % count) + 1
    elseif key == "down" then
      state.sub_cursor = (state.sub_cursor % count) + 1
    elseif key == "return" or key == "space" then
      local idx = state.sub_cursor
      if idx == state.active_idx then
        add_msg("Already active!")
      elseif state.party[idx].hp <= 0 then
        add_msg("Can't send out a fainted critter!")
      else
        exit_submenu()
        state.phase = "resolving"
        seq = anim.new()
        anim.push(seq, function()
          state.active_idx = idx
          local p = active_player()
          despawn_critter_sprite(player_sprite)
          player_sprite = spawn_critter_sprite(p.species_id, L.player_sprite_x, L.player_sprite_y, false)
          add_msg("Go, " .. p.name .. "!")
        end, 0.8)
        -- Enemy attacks after swap
        anim.push(seq, function()
          local enemy = get_enemy()
          local player = active_player()
          local enemy_move = ai.choose_move(enemy, player, moves)
          push_attack_steps(seq, enemy, enemy_move, player, enemy.name, player.name, false)
        end, 0.0)
        push_status_tick_steps(seq)
        anim.push(seq, function()
          check_end_conditions()
        end, 0.0)
      end
    end

  elseif state.sub_menu == "items" then
    local healing = {}
    for _, item in ipairs(state.inventory) do
      if item.kind == "healing" or item.kind == "revive" then
        table.insert(healing, item)
      end
    end
    local count = #healing
    if count == 0 then
      add_msg("No usable items!")
      exit_submenu()
      return
    end
    if key == "up" then
      state.sub_cursor = ((state.sub_cursor - 2) % count) + 1
    elseif key == "down" then
      state.sub_cursor = (state.sub_cursor % count) + 1
    elseif key == "return" or key == "space" then
      local item = healing[state.sub_cursor]
      exit_submenu()
      state.phase = "resolving"
      seq = anim.new()
      anim.push(seq, function()
        if item.kind == "healing" then
          local before = active_player().hp
          stat.heal(active_player(), item.heal_amount or 30)
          local healed = active_player().hp - before
          add_msg("Used " .. item.name .. " — healed " .. healed .. " HP!", 0x44FF44)
        elseif item.kind == "revive" then
          -- Find first fainted party member
          for _, c in ipairs(state.party) do
            if c.hp <= 0 then
              c.hp = math.floor(c.max_hp * 0.5)
              add_msg("Used " .. item.name .. " — " .. c.name .. " revived!", 0x44FF44)
              break
            end
          end
        end
        -- Remove used item
        for i, it in ipairs(state.inventory) do
          if it == item then table.remove(state.inventory, i); break end
        end
      end, 0.8)
      -- Enemy attacks after item use
      anim.push(seq, function()
        local enemy = get_enemy()
        local player = active_player()
        local enemy_move = ai.choose_move(enemy, player, moves)
        push_attack_steps(seq, enemy, enemy_move, player, enemy.name, player.name, false)
      end, 0.0)
      push_status_tick_steps(seq)
      anim.push(seq, function()
        check_end_conditions()
      end, 0.0)
    end

  elseif state.sub_menu == "bench" then
    -- Boss+minion bench actions (stub for now)
    add_msg("Bench actions not yet implemented.")
    exit_submenu()
  end
end

-----------------------------------------------------------------------
-- Scene callbacks
-----------------------------------------------------------------------

function scene.load(data)
  widgets.init()

  -- Compute cell-based layout from actual terminal dimensions
  local cols = widgets.cols()
  local rows = widgets.rows()

  -- Vertical zones (cell rows): enemy | player | msg (2) | menu (rest)
  local enemy_h = math.floor(rows * 0.40)
  local player_h = math.floor(rows * 0.35)
  local msg_row = enemy_h + player_h
  local menu_row = msg_row + 2
  local panel_w = math.min(28, math.floor(cols * 0.38))

  L = {
    cols = cols, rows = rows, panel_w = panel_w,
    -- Zone row boundaries
    enemy_h = enemy_h,
    player_start = enemy_h,
    player_h = player_h,
    msg_row = msg_row,
    menu_row = menu_row,
    -- Enemy panel: top-left of enemy zone
    ep_col = 1, ep_row = 1,
    -- Player panel: bottom-right of player zone
    pp_col = cols - panel_w - 1,
    pp_row = enemy_h + player_h - 4,
    -- Sprite positions (virtual pixels)
    enemy_sprite_x = math.floor(W * 0.65),
    enemy_sprite_y = widgets.row_px(math.floor(enemy_h * 0.3)),
    player_sprite_x = math.floor(W * 0.18),
    player_sprite_y = widgets.row_px(enemy_h + math.floor(player_h * 0.3)),
    minion_sprite_x = math.floor(W * 0.65) - 80,
    minion_sprite_y = widgets.row_px(math.floor(enemy_h * 0.3)) + 20,
  }

  state = {
    phase          = "intro",
    encounter_type = data.encounter_type or "wild",
    party          = data.party,
    active_idx     = 1,
    enemy          = data.enemy,
    boss_team      = data.boss_team or {},
    boss_idx       = 1,
    minion         = data.minion,
    swarm          = data.swarm or {},
    swarm_idx      = 1,
    messages       = {},
    menu_cursor    = 1,
    sub_menu       = nil,
    sub_cursor     = 1,
    result         = nil,
    caught_critter = nil,
    inventory      = data.inventory or {},
    floor          = data.floor or 1,
    gold           = data.gold or 0,
    end_timer      = 0,
  }

  -- For boss_team, enemy is first in team
  if state.encounter_type == "boss_team" and #state.boss_team > 0 then
    state.enemy = state.boss_team[1]
  end
  -- For swarm, enemy is first in swarm
  if state.encounter_type == "swarm" and #state.swarm > 0 then
    state.enemy = state.swarm[1]
  end

  -- Clean up any stale sprites from a prior load
  despawn_critter_sprite(player_sprite)
  despawn_critter_sprite(enemy_sprite)
  despawn_critter_sprite(minion_sprite)

  -- Spawn ECS sprites for active critters
  player_sprite = spawn_critter_sprite(active_player().species_id, L.player_sprite_x, L.player_sprite_y, false)
  enemy_sprite = spawn_critter_sprite(state.enemy.species_id, L.enemy_sprite_x, L.enemy_sprite_y, true)
  if state.minion then
    minion_sprite = spawn_critter_sprite(state.minion.species_id, L.minion_sprite_x, L.minion_sprite_y, true)
  end

  -- Play battle music
  if state.encounter_type == "boss_team" or state.encounter_type == "boss_minion" then
    music.play("battle_boss")
  else
    music.play("battle_wild")
  end

  -- Intro sequence
  seq = anim.new()
  local intro_msg
  if state.encounter_type == "wild" then
    intro_msg = "A wild " .. state.enemy.name .. " appeared!"
  elseif state.encounter_type == "boss_team" then
    intro_msg = "[BOSS] " .. state.enemy.name .. " challenges you!"
  elseif state.encounter_type == "boss_minion" then
    intro_msg = "[BOSS] " .. state.enemy.name .. " and " .. (state.minion and state.minion.name or "???") .. " appeared!"
  elseif state.encounter_type == "swarm" then
    intro_msg = "[SWARM] 1 of " .. #state.swarm .. " — " .. state.enemy.name .. " appeared!"
  end
  anim.push(seq, function() add_msg(intro_msg) end, 1.2)
  anim.push(seq, function()
    add_msg("Go, " .. active_player().name .. "!")
  end, 0.8)
  anim.push(seq, function()
    state.phase = "player_action"
  end, 0.0)
end

function scene.update(dt)
  -- Update sequencer
  if seq then anim.update(seq, dt) end

  -- End state: auto-pop after delay
  if state.phase == "end" then
    state.end_timer = state.end_timer + dt
    if state.end_timer >= 3.0 then
      engine.scene.pop({
        result = state.result,
        party  = state.party,
        caught = state.caught_critter,
      })
    end
  end
end

function scene.draw()
  local p = active_player()
  local e = get_enemy()
  local is_boss = state.encounter_type == "boss_team" or state.encounter_type == "boss_minion"

  -- Clear all pixel layers
  for layer = 0, 7 do
    engine.graphics.set_layer(layer)
    engine.graphics.pixel.clear()
  end

  ---------------------------------------------------------------
  -- Layer 0: zone backgrounds (pixel.rect)
  ---------------------------------------------------------------
  engine.graphics.set_layer(0)
  local divider_y = widgets.row_px(L.player_start)
  local action_y = widgets.row_px(L.msg_row)
  engine.graphics.pixel.rect(0, 0, W, divider_y, 0x1A1A2E)
  engine.graphics.pixel.rect(0, divider_y, W, action_y - divider_y, 0x141428)
  engine.graphics.pixel.rect(0, action_y, W, H - action_y, 0x0E0E1E)
  engine.graphics.pixel.rect(0, divider_y, W, 1, 0x333355)
  engine.graphics.pixel.rect(0, action_y, W, 1, 0x333355)

  -- Layer 1: critter sprites rendered automatically by ECS
  -- Fallback colored rectangles if sprite failed to load
  if not player_sprite then
    engine.graphics.set_layer(1)
    engine.graphics.pixel.rect(L.player_sprite_x, L.player_sprite_y, 64, 64,
      widgets.type_colors[p.critter_type] or 0x808080)
  end
  if not enemy_sprite then
    engine.graphics.set_layer(1)
    engine.graphics.pixel.rect(L.enemy_sprite_x, L.enemy_sprite_y, 64, 64,
      widgets.type_colors[e.critter_type] or 0x808080)
  end

  ---------------------------------------------------------------
  -- Layer 3: UI panels + text (pixel.rect for panels, draw_text for text)
  ---------------------------------------------------------------
  engine.graphics.set_layer(3)

  -- Boss/swarm header
  local ep_row = L.ep_row
  if is_boss then
    local boss_str = "[BOSS]"
    if state.encounter_type == "boss_team" then
      boss_str = boss_str .. "  "
      for i = 1, #state.boss_team do
        if i < state.boss_idx then boss_str = boss_str .. "x"
        elseif i == state.boss_idx then boss_str = boss_str .. "#"
        else boss_str = boss_str .. "o" end
      end
    end
    widgets.text(L.ep_col, 0, boss_str, 0xFF6644)
    ep_row = L.ep_row + 1
  elseif state.encounter_type == "swarm" then
    widgets.text(L.ep_col, 0,
      string.format("[SWARM] %d of %d", state.swarm_idx, #state.swarm), 0xFFAA44)
    ep_row = L.ep_row + 1
  end

  -- Info panels
  widgets.info_panel(L.ep_col, ep_row, L.panel_w, e, species[e.species_id], is_boss)
  widgets.info_panel(L.pp_col, L.pp_row, L.panel_w, p, species[p.species_id], false)

  -- Message panel
  widgets.message_panel(L.msg_row, state.messages,
    string.format("Floor %d/15  %dg", state.floor, state.gold))

  ---------------------------------------------------------------
  -- Menu area
  ---------------------------------------------------------------
  local labels = (state.encounter_type == "boss_minion") and menu_labels_minion or menu_labels

  if state.phase == "player_action" then
    widgets.menu_bar(L.menu_row, labels, state.menu_cursor)

  elseif state.phase == "sub_menu" then
    if state.sub_menu == "moves" then
      local mitems = {}
      for _, mid in ipairs(p.moves) do
        local m = moves[mid]
        if m then
          local eff = types.effectiveness(m.move_type, e.critter_type)
          local det = string.format("P:%d A:%d%%", m.power, m.accuracy)
          if eff >= 1.5 then det = det .. " SE" end
          if eff <= 0.5 then det = det .. " NVE" end
          table.insert(mitems, {
            name = m.name, detail = det,
            type_color = widgets.type_colors[m.move_type],
          })
        end
      end
      widgets.move_menu(L.menu_row, mitems, state.sub_cursor)

    elseif state.sub_menu == "catch" then
      local litems = {}
      for _, item in ipairs(state.inventory) do
        if items.is_catch_tool(item.id) then
          local hp_ratio = e.hp / math.max(1, e.max_hp)
          local s = species[e.species_id]
          local rp = ({common=0,uncommon=10,rare=20,epic=35,legendary=50})[s.rarity] or 0
          local ch = math.max(5, math.min(100, item.base_catch_rate - hp_ratio*30 - rp))
          table.insert(litems, { text = item.name, detail = string.format("%.0f%%", ch) })
        end
      end
      if #litems == 0 then litems = {{ text = "No catch tools!", color = 0xFF4444 }} end
      widgets.submenu_list(L.menu_row, litems, state.sub_cursor)

    elseif state.sub_menu == "swap" then
      local litems = {}
      for i, c in ipairs(state.party) do
        local col = nil
        if i == state.active_idx then col = 0x4488DD
        elseif c.hp <= 0 then col = 0x444444 end
        table.insert(litems, {
          text = c.name .. "  Lv" .. c.level,
          detail = c.hp .. "/" .. c.max_hp .. " HP",
          color = col,
        })
      end
      widgets.submenu_list(L.menu_row, litems, state.sub_cursor)

    elseif state.sub_menu == "items" then
      local litems = {}
      for _, item in ipairs(state.inventory) do
        if item.kind == "healing" or item.kind == "revive" then
          local det = item.heal_amount and ("+" .. item.heal_amount .. " HP") or ""
          table.insert(litems, { text = item.name, detail = det })
        end
      end
      if #litems == 0 then litems = {{ text = "No usable items!", color = 0xFF4444 }} end
      widgets.submenu_list(L.menu_row, litems, state.sub_cursor)

    elseif state.sub_menu == "bench" then
      widgets.submenu_list(L.menu_row,
        {{ text = "Not yet implemented.", color = 0x888888 }}, 1)
    end

  else
    -- Intro/resolving/end: empty menu area
    widgets.fill_cells(0, L.menu_row, L.cols, L.rows - L.menu_row, 0x0E0E1E)
  end

  ---------------------------------------------------------------
  -- End overlay
  ---------------------------------------------------------------
  if state.phase == "end" then
    local mr, mc = math.floor(L.rows / 2), math.floor(L.cols / 2)
    if state.result == "victory" then
      widgets.text(mc - 5, mr, "VICTORY!", 0x44FF44)
    elseif state.result == "defeat" then
      widgets.text(mc - 4, mr, "DEFEAT", 0xFF4444)
    elseif state.result == "caught" then
      widgets.text(mc - 4, mr, "CAUGHT!", 0x44DDFF)
    end
    widgets.text(mc - 7, mr + 1, "Returning...", 0x888888)
  end
end

function scene.on_key(key, action)
  if action ~= "press" then return end

  -- Enter/Space advances sequencer
  if (key == "return" or key == "space") and seq and not seq.done then
    anim.skip(seq)
    return
  end

  -- End state: any key to exit early
  if state.phase == "end" then
    state.end_timer = 999
    return
  end

  if state.phase == "player_action" then
    handle_action_input(key)
  elseif state.phase == "sub_menu" then
    handle_submenu_input(key)
  elseif key == "escape" then
    if #state.messages == 0 or state.messages[#state.messages].text ~= "No retreat!" then
      add_msg("No retreat!", 0xFF4444)
    end
  end
end

function scene.unload()
  music.stop()
  despawn_critter_sprite(player_sprite)
  despawn_critter_sprite(enemy_sprite)
  despawn_critter_sprite(minion_sprite)
  player_sprite = nil
  enemy_sprite = nil
  minion_sprite = nil
end

return scene
