# Phase 9.1 — Data Layer + Battle Engine

## Goal
Port all game data to Lua modules and implement the complete battle logic. No graphics. Testable entirely via print output.

When this phase is complete, `zig build run -- games/codecritter/` prints a simulated battle turn-by-turn showing damage, status effects, XP, and catch results.

---

## Design Context

- Damage: `power × type_eff × (attacker_logic / defender_resolve) × rand(0.85, 1.0)`
- Stat at level N: `base × (1 + N/50)`
- XP per battle: `10 + enemy_level × 3`
- XP to level N: `N² × 10`
- Type chart fix required: CHAOS vs LEGACY cells are wrong in source JSON — fix in `data/types.lua`
- 9 status effects (see DESIGN.md)
- Battle AI: prefer super-effective → else highest power → 20% random
- No status stacking (last applied wins)

---

## Files to Create

### `data/types.lua`
The 7×7 type effectiveness matrix plus type metadata.

```lua
-- Returns multiplier for attacker_type vs defender_type
-- 1.5 = strong, 1.0 = neutral, 0.5 = weak
local M = {}

M.effectiveness = {
  --         DBG  PAT  CHS  WIS  SNA  VIB  LEG
  debug   = {1.0, 1.0, 1.5, 0.5, 1.0, 1.5, 0.5},
  patience= {1.0, 1.0, 0.5, 1.5, 0.5, 1.5, 1.0},
  chaos   = {0.5, 1.5, 1.0, 1.0, 1.5, 1.0, 1.5}, -- CHAOS beats LEGACY (fixed)
  wisdom  = {1.5, 0.5, 1.0, 1.0, 0.5, 1.0, 1.5},
  snark   = {1.0, 1.5, 0.5, 1.5, 1.0, 0.5, 1.0},
  vibe    = {0.5, 0.5, 1.0, 1.0, 1.5, 1.0, 1.5},
  legacy  = {1.5, 1.0, 0.5, 0.5, 1.0, 0.5, 1.0}, -- LEGACY weak to CHAOS (fixed)
}

M.type_order = {"debug","patience","chaos","wisdom","snark","vibe","legacy"}

M.colors = {
  debug   = {r=0,   g=200, b=80},   -- terminal green
  patience= {r=100, g=180, b=255},  -- calm blue
  chaos   = {r=220, g=50,  b=50},   -- error red
  wisdom  = {r=180, g=100, b=220},  -- purple/violet
  snark   = {r=220, g=160, b=0},    -- amber
  vibe    = {r=255, g=150, b=200},  -- pastel pink
  legacy  = {r=140, g=100, b=60},   -- brown/tan
}

M.archetype_names = {
  deployer = "Deployer",
  hotfix   = "Hotfix",
  monolith = "Monolith",
  uptime   = "Uptime",
  regression = "Regression",
  reviewer = "Reviewer",
  zero_day = "Zero Day",
}

function M.get_effectiveness(attacker_type, defender_type)
  local row = M.effectiveness[attacker_type]
  if not row then return 1.0 end
  -- find defender index
  for i, t in ipairs(M.type_order) do
    if t == defender_type then return row[i] end
  end
  return 1.0
end

return M
```

### `data/species.lua`
Convert `~/Documents/codecritters/data/species.json` → Lua table.
Each species entry:
```lua
println = {
  id = "println",
  name = "Println",
  type = "debug",
  archetype = "deployer",
  rarity = "common",
  evolution_from = nil,
  evolution_to = "tracer",
  evolution_level = 12,
  base_hp = 60, base_logic = 75, base_resolve = 55, base_speed = 65,
  move1 = "log_statement",    -- signature, always own type
  move2 = "stack_trace",      -- secondary, learned at evolution or level
  move2_learn_level = 12,
  description = "The humble print debugger. Slow but methodical.",
},
```

Include all 61 species. Mark archetype for each based on stat profile:
- High Logic, medium Speed, medium bulk → deployer
- High Speed, medium Logic, low Resolve → hotfix
- High Logic, low Speed → monolith
- High Resolve+HP, low Logic → uptime
- Status-focused moveset → regression
- High Resolve+Speed, very low Logic → reviewer
- Epic with unique mechanic → zero_day

### `data/moves.lua`
Convert `~/Documents/codecritters/data/moves.json` → Lua table.
Each move entry:
```lua
log_statement = {
  id = "log_statement",
  name = "Log Statement",
  type = "debug",
  power = 45,
  accuracy = 100,
  status_effect = nil,      -- or "linted"
  status_chance = 0,        -- 0–100
  description = "A simple diagnostic output.",
},
```

Include all 52 moves plus 21 move discs (named `disc_debug_1`, `disc_debug_2`, `disc_debug_3`, etc.):
```lua
disc_chaos_3 = {
  id = "disc_chaos_3",
  name = "CHAOS Disc III",
  type = "chaos",
  power = 90,
  accuracy = 75,
  status_effect = "segfaulted",
  status_chance = 20,
  description = "Off-type CHAOS coverage. Loadout slot only.",
  is_disc = true,
},
```

### `data/items.lua`
Convert `~/Documents/codecritters/data/items.json` → Lua table.
Add the 13 hold items:
```lua
-- Combat/utility items (original 14)
hotfix = { id="hotfix", name="Hotfix", kind="heal", hp=80, buy=100, sell=50 },
git_revert = { id="git_revert", name="Git Revert", kind="revive", hp_pct=50, buy=300, sell=150 },

-- Hold items (new 13)
config_file = {
  id = "config_file",
  name = "Config File",
  kind = "hold",
  description = "Set one chosen stat to maximum at battle start.",
  effect = "max_chosen_stat",
  buy = 400, sell = 200,
},
fork_bomb = {
  id = "fork_bomb",
  name = "Fork Bomb",
  kind = "hold",
  description = "On faint, deal 30% max HP damage to opponent.",
  effect = "on_faint_damage",
  effect_value = 0.30,
  buy = 350, sell = 175,
},
-- ... etc
```

### `data/biomes.lua`
Convert `~/Documents/codecritters/data/biomes.json` → Lua table.
```lua
pythonic_caves = {
  id = "pythonic_caves",
  name = "Pythonic Caves",
  detect = ".py",
  dominant_types = {"vibe", "wisdom"},
  encounter_table = {
    { species = "copilot",   weight = 30, min_floor = 1 },
    { species = "monad",     weight = 20, min_floor = 1 },
    -- ...
  },
  boss_pool = {
    { species = "burrito",  level_bonus = 3, floor = 5 },
    { species = "hallucination", level_bonus = 5, floor = 10 },
    -- ...
  },
  shop_bias = {"move_disc", "catch_tool"},
},
```

### `battle/status.lua`
Status effect registry and tick logic.
```lua
local M = {}

M.definitions = {
  blocked = {
    duration = 1,
    on_tick = function(critter, battle_state)
      -- skip turn flag set by engine
      critter.skip_turn = true
    end,
  },
  linted = {
    duration = 2,
    -- engine checks this flag when validating move selection
  },
  deprecated = {
    duration = 3,
    on_tick = function(critter)
      -- reduce all stats by 5% per tick
      critter.logic   = math.floor(critter.logic   * 0.95)
      critter.resolve = math.floor(critter.resolve * 0.95)
      critter.speed   = math.floor(critter.speed   * 0.95)
    end,
  },
  -- ... all 9 statuses
}

-- Apply a status to a critter (last applied wins)
function M.apply(critter, status_id)
  local def = M.definitions[status_id]
  if not def then return end
  critter.status = status_id
  critter.status_turns = def.duration
end

-- Tick status at end of turn. Returns true if status expired.
function M.tick(critter)
  if not critter.status then return end
  local def = M.definitions[critter.status]
  if def and def.on_tick then
    def.on_tick(critter)
  end
  critter.status_turns = critter.status_turns - 1
  if critter.status_turns <= 0 then
    critter.status = nil
    critter.status_turns = 0
  end
end

return M
```

### `battle/ai.lua`
Wild critter AI — type-aware move selection.
```lua
local types = require("data.types")
local M = {}

function M.choose_move(critter, target, moves_data)
  -- 20% random
  if math.random() < 0.20 then
    return moves_data[critter.moves[math.random(#critter.moves)]]
  end

  -- Find super-effective moves
  local best_move, best_score = nil, -1
  for _, move_id in ipairs(critter.moves) do
    local move = moves_data[move_id]
    if move and move.power > 0 then
      local eff = types.get_effectiveness(move.type, target.type)
      local score = move.power * eff * (move.accuracy / 100)
      if score > best_score then
        best_score = score
        best_move = move
      end
    end
  end

  return best_move or moves_data[critter.moves[1]]
end

return M
```

### `critter/stats.lua`
Stat calculation, XP, leveling, evolution logic.
```lua
local M = {}

-- Calculate stat at given level
function M.calc_stat(base, level)
  return math.floor(base * (1 + level / 50))
end

-- Apply level stats to a live critter table
function M.apply_level_stats(critter, species_data)
  local s = species_data[critter.species_id]
  critter.max_hp   = M.calc_stat(s.base_hp,      critter.level)
  critter.logic    = M.calc_stat(s.base_logic,    critter.level)
  critter.resolve  = M.calc_stat(s.base_resolve,  critter.level)
  critter.speed    = M.calc_stat(s.base_speed,    critter.level)
  -- Apply scars (permanent -1 per scar per stat)
  for _, scar in ipairs(critter.scars or {}) do
    critter[scar.stat] = critter[scar.stat] - 1
  end
end

-- XP needed to reach a level
function M.xp_for_level(level)
  return level * level * 10
end

-- XP awarded for defeating an enemy
function M.xp_reward(enemy_level)
  return 10 + enemy_level * 3
end

-- Add XP to critter, return true if leveled up
function M.add_xp(critter, amount, species_data)
  critter.xp = (critter.xp or 0) + amount
  local leveled = false
  while critter.xp >= M.xp_for_level(critter.level + 1) do
    critter.level = critter.level + 1
    leveled = true
    -- Check evolution
    local s = species_data[critter.species_id]
    if s.evolution_to and critter.level >= s.evolution_level then
      critter.species_id = s.evolution_to
      critter.evolved = true
    end
  end
  M.apply_level_stats(critter, species_data)
  return leveled
end

-- Apply a scar (called when critter faints)
function M.apply_scar(critter)
  local stats = {"logic", "resolve", "speed"}
  local stat = stats[math.random(#stats)]
  critter.scars = critter.scars or {}
  table.insert(critter.scars, {stat = stat})
  critter[stat] = critter[stat] - 1  -- immediate penalty
  return stat
end

return M
```

### `battle/engine.lua`
Core battle logic — damage, turns, catch, hold item effects.
```lua
local types   = require("data.types")
local status  = require("battle.status")
local stats   = require("critter.stats")

local M = {}

-- Calculate damage dealt by an attack
function M.calc_damage(attacker, move, defender)
  if move.power == 0 then return 0 end
  local eff      = types.get_effectiveness(move.type, defender.type)
  local ratio    = attacker.logic / math.max(1, defender.resolve)
  local variance = 0.85 + math.random() * 0.15
  return math.max(1, math.floor(move.power * eff * ratio * variance))
end

-- Effectiveness label for UI
function M.effectiveness_label(eff)
  if eff >= 1.5 then return "▲ super effective" end
  if eff <= 0.5 then return "▼ not very effective" end
  return ""
end

-- Attempt to catch a critter
-- Returns: "success", "fail", or "fail_hurt" (Try-Catch failure)
function M.attempt_catch(tool, critter, species_data)
  local s = species_data[critter.species_id]
  local rarity_penalties = {common=0, uncommon=10, rare=20, epic=35, legendary=50}
  local hp_penalty = (critter.hp / critter.max_hp) * 30
  local chance = tool.base_rate
    + (tool.type_bonus and tool.type_bonus(critter.type) or 0)
    - hp_penalty
    - (rarity_penalties[s.rarity] or 0)
  chance = math.max(5, math.min(100, chance))

  local roll = math.random(100)
  if roll <= chance then
    return "success"
  elseif tool.id == "try_catch" then
    return "fail_hurt"  -- enemy gets free attack
  else
    return "fail"
  end
end

-- Process one attack action
-- Returns: { damage, effective, status_applied, label }
function M.process_attack(attacker, move, defender, moves_data)
  local m = type(move) == "string" and moves_data[move] or move

  -- Check Linted (can only use own-type moves)
  if attacker.status == "linted" and m.type ~= attacker.type then
    return { damage=0, blocked=true, label="Linted — can't use off-type moves!" }
  end

  -- Accuracy check
  local acc_mod = attacker.status == "tilted" and 0.75 or 1.0
  if math.random(100) > math.floor(m.accuracy * acc_mod) then
    return { damage=0, missed=true, label=attacker.name .. " missed!" }
  end

  -- Damage
  local dmg = M.calc_damage(attacker, m, defender)
  local eff = types.get_effectiveness(m.type, defender.type)

  -- Status effect
  local status_applied = nil
  if m.status_effect and math.random(100) <= m.status_chance then
    if not defender.status then  -- no stacking
      status.apply(defender, m.status_effect)
      status_applied = m.status_effect
    end
  end

  return {
    damage = dmg,
    eff = eff,
    status_applied = status_applied,
    label = M.effectiveness_label(eff),
  }
end

-- Apply hold item effects at battle start
function M.apply_hold_item_start(critter, hold_items_data)
  if not critter.hold_item then return end
  local item = hold_items_data[critter.hold_item]
  if not item then return end

  if item.effect == "in_the_zone_start" then
    status.apply(critter, "in_the_zone")
  elseif item.effect == "reveal_first_move" then
    critter.first_move_guaranteed_hit = true
  elseif item.effect == "syntax_error" then
    -- handled by engine when enemy takes first action
    critter.syntax_error_active = true
  end
end

-- Apply hold item effects on faint
-- Returns: damage to deal to opponent, or nil
function M.apply_hold_item_faint(critter, hold_items_data)
  if not critter.hold_item then return nil end
  local item = hold_items_data[critter.hold_item]
  if item and item.effect == "on_faint_damage" then
    return math.floor(critter.max_hp * (item.effect_value or 0.30))
  end
  return nil
end

return M
```

### `main.lua` (Phase 9.1 version)
Loads all data, runs a simulated battle via print output. No graphics.

```lua
-- Disable graphics for data-only test
engine.set_resolution(640, 360)

local types   = require("data.types")
local species = require("data.species")
local moves   = require("data.moves")
local items   = require("data.items")
local biomes  = require("data.biomes")
local battle  = require("battle.engine")
local ai      = require("battle.ai")
local stat    = require("critter.stats")
local status  = require("battle.status")

-- Build two test critters
local function make_critter(species_id, level)
  local s = species[species_id]
  local c = {
    species_id = species_id,
    name = s.name,
    type = s.type,
    level = level,
    xp = 0,
    hp = 0, max_hp = 0,
    logic = 0, resolve = 0, speed = 0,
    moves = {s.move1, s.move2},
    status = nil,
    status_turns = 0,
    scars = {},
    hold_item = nil,
  }
  stat.apply_level_stats(c, species)
  c.hp = c.max_hp
  return c
end

local player = make_critter("println", 5)
local enemy  = make_critter("segfault", 5)

print(string.format("=== TEST BATTLE: %s (Lv%d) vs %s (Lv%d) ===",
  player.name, player.level, enemy.name, enemy.level))
print(string.format("%s: HP %d, Logic %d, Resolve %d, Speed %d",
  player.name, player.max_hp, player.logic, player.resolve, player.speed))
print(string.format("%s: HP %d, Logic %d, Resolve %d, Speed %d",
  enemy.name, enemy.max_hp, enemy.logic, enemy.resolve, enemy.speed))
print("")

local turn = 1
while player.hp > 0 and enemy.hp > 0 and turn <= 20 do
  print(string.format("--- Turn %d ---", turn))

  -- Player action: use first move
  local pmove = moves[player.moves[1]]
  local presult = battle.process_attack(player, pmove, enemy, moves)
  enemy.hp = math.max(0, enemy.hp - presult.damage)
  print(string.format("  %s uses %s → %d damage %s",
    player.name, pmove.name, presult.damage, presult.label))
  if presult.status_applied then
    print(string.format("  %s is now %s!", enemy.name, presult.status_applied))
  end

  if enemy.hp <= 0 then
    print(string.format("  %s fainted!", enemy.name))
    break
  end

  -- Enemy AI action
  local emove = ai.choose_move(enemy, player, moves)
  local eresult = battle.process_attack(enemy, emove, player, moves)
  player.hp = math.max(0, player.hp - eresult.damage)
  print(string.format("  %s uses %s → %d damage %s",
    enemy.name, emove.name, eresult.damage, eresult.label))

  -- Tick statuses
  status.tick(player)
  status.tick(enemy)

  print(string.format("  HP: %s %d/%d | %s %d/%d",
    player.name, player.hp, player.max_hp,
    enemy.name, enemy.hp, enemy.max_hp))

  turn = turn + 1
end

-- XP reward
if enemy.hp <= 0 then
  local xp = stat.xp_reward(enemy.level)
  print(string.format("\n%s defeated! +%d XP", enemy.name, xp))
  local leveled = stat.add_xp(player, xp, species)
  if leveled then
    print(string.format("%s leveled up to %d!", player.name, player.level))
  end
end

print("\nBattle test complete.")
engine.quit()
```

---

## Task Checklist

- [ ] Read `~/Documents/codecritters/data/species.json` and convert to `data/species.lua`
- [ ] Read `~/Documents/codecritters/data/moves.json` and convert to `data/moves.lua`
  - [ ] Add 21 move discs (`disc_{type}_{1,2,3}` for all 7 types)
- [ ] Read `~/Documents/codecritters/data/items.json` and convert to `data/items.lua`
  - [ ] Add 13 hold items
- [ ] Read `~/Documents/codecritters/data/biomes.json` and convert to `data/biomes.lua`
- [ ] Write `data/types.lua` with corrected CHAOS/LEGACY cells
- [ ] Write `battle/status.lua` — all 9 status effects
- [ ] Write `battle/ai.lua` — type-aware AI
- [ ] Write `battle/engine.lua` — damage, catch, hold item triggers
- [ ] Write `critter/stats.lua` — stat calc, XP, scars
- [ ] Assign archetype field to all 61 species based on stat profile
- [ ] Write `main.lua` — test battle simulation
- [ ] `zig build run -- games/codecritter/` prints at least 3 turns of battle

## Verification

```
=== TEST BATTLE: Println (Lv5) vs Segfault (Lv5) ===
Println: HP 66, Logic 82, Resolve 60, Speed 71
Segfault: HP 55, Logic 77, Resolve 44, Speed 88

--- Turn 1 ---
  Println uses Log Statement → 84 damage ▲ super effective
  Segfault fainted!

Segfault defeated! +25 XP
Battle test complete.
```
