local types  = require("data.types")
local status = require("battle.status")

local M = {}

-- damage = floor(power × type_eff × (logic/resolve) × rand(0.85,1.0)), min 1
function M.calc_damage(attacker, move, defender)
  if move.power == 0 then return 0, 1.0 end
  local eff      = types.effectiveness(move.move_type, defender.critter_type)
  local ratio    = attacker.logic / math.max(1, defender.resolve)
  local variance = 0.85 + math.random() * 0.15
  return math.max(1, math.floor(move.power * eff * ratio * variance)), eff
end

function M.eff_label(eff)
  if eff >= 1.5 then return " [SUPER EFFECTIVE]"
  elseif eff <= 0.5 then return " [NOT VERY EFFECTIVE]"
  else return "" end
end

-- Process one attack. Returns:
-- {damage, eff, status_applied, missed, blocked_by_status, linted_blocked, self_targeted}
function M.process_attack(attacker, move_or_id, defender, moves_data)
  local m = type(move_or_id) == "string" and moves_data[move_or_id] or move_or_id
  if not m then
    return {damage = 0, missed = true}
  end

  -- blocked: attacker skips turn
  if attacker.skip_turn then
    attacker.skip_turn = false
    return {damage = 0, blocked_by_status = true}
  end

  -- linted: only own-type moves allowed
  if attacker.status == "linted" and m.move_type ~= attacker.critter_type then
    return {damage = 0, linted_blocked = true}
  end

  -- accuracy check (tilted: -25%)
  local acc = m.accuracy * (attacker.status == "tilted" and 0.75 or 1.0)
  if math.random(100) > math.floor(acc) then
    return {damage = 0, missed = true}
  end

  -- hallucinating: 30% chance to target self
  local actual_target = defender
  if attacker.status == "hallucinating" and math.random(100) <= 30 then
    actual_target = attacker
  end

  local dmg, eff = M.calc_damage(attacker, m, actual_target)
  local status_applied = nil
  if m.status_effect and (m.status_chance or 0) > 0 then
    if math.random(100) <= m.status_chance and not actual_target.status then
      status.apply(actual_target, m.status_effect)
      status_applied = m.status_effect
    end
  end

  return {
    damage         = dmg,
    eff            = eff,
    status_applied = status_applied,
    self_targeted  = (actual_target == attacker),
  }
end

-- Catch attempt. Returns: success (bool), effective_chance (number)
-- catch_chance = base_rate - (hp_ratio × 30) - rarity_penalty, clamped 5–100
local RARITY_PENALTY = {common = 0, uncommon = 10, rare = 20, epic = 35, legendary = 50}

function M.try_catch(tool, critter, species_data)
  local s          = species_data[critter.species_id]
  local hp_ratio   = critter.hp / math.max(1, critter.max_hp)
  local hp_penalty = hp_ratio * 30
  local chance     = tool.base_catch_rate - hp_penalty - (RARITY_PENALTY[s.rarity] or 0)
  chance           = math.max(5, math.min(100, chance))
  local roll       = math.random(100)
  return roll <= math.floor(chance), chance
end

-- Award XP to a critter after battle. Returns xp_gained, leveled_up (bool).
-- XP earned: 10 + enemy_level × 3
-- XP to reach level N: N² × 10
function M.award_xp(critter, enemy_level, species_data)
  local xp_gain = 10 + enemy_level * 3
  critter.xp    = (critter.xp or 0) + xp_gain
  local leveled = false
  while critter.xp >= (critter.level + 1) ^ 2 * 10 do
    critter.level = critter.level + 1
    leveled       = true
    -- check evolution
    local s = species_data[critter.species_id]
    if s.evolves_to and critter.level >= (s.evolution_level or 999) then
      critter.species_id = s.evolves_to
      critter.evolved    = true
    end
  end
  if leveled then
    -- recalc stats at new level
    local stat = require("critter.stats")
    stat.recalc_stats(critter, species_data)
  end
  return xp_gain, leveled
end

return M
