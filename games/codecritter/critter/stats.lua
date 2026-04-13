local M = {}

-- Stat at level N: floor(base × (1 + level/50))
function M.stat_at_level(base, level)
  return math.floor(base * (1 + level / 50))
end

-- Create a live critter instance from species data at a given level
function M.make_instance(species_id, level, species_data)
  local s = species_data[species_id]
  if not s then error("Unknown species: " .. tostring(species_id)) end
  local moveset = {}
  if s.move1 then table.insert(moveset, s.move1) end
  if s.move2 then table.insert(moveset, s.move2) end
  local c = {
    species_id   = species_id,
    name         = s.name,
    critter_type = s.critter_type,
    rarity       = s.rarity,
    archetype    = s.archetype,
    level        = level,
    xp           = 0,
    max_hp       = M.stat_at_level(s.base_hp,      level),
    logic        = M.stat_at_level(s.base_logic,    level),
    resolve      = M.stat_at_level(s.base_resolve,  level),
    speed        = M.stat_at_level(s.base_speed,    level),
    moves        = moveset,
    status       = nil,
    status_turns = 0,
    skip_turn    = false,
    held_item    = nil,
    scars        = {},
  }
  c.hp = c.max_hp
  return c
end

-- Recalculate stats at current level (called after level-up)
function M.recalc_stats(critter, species_data)
  local s = species_data[critter.species_id]
  critter.max_hp  = M.stat_at_level(s.base_hp,      critter.level)
  critter.logic   = M.stat_at_level(s.base_logic,    critter.level)
  critter.resolve = M.stat_at_level(s.base_resolve,  critter.level)
  critter.speed   = M.stat_at_level(s.base_speed,    critter.level)
  -- re-apply scars
  for _, scar in ipairs(critter.scars) do
    critter[scar.stat] = math.max(1, critter[scar.stat] - 1)
  end
end

-- Apply a permanent scar (-1 to a random stat)
function M.apply_scar(critter)
  local pool = {"logic", "resolve", "speed"}
  local stat = pool[math.random(#pool)]
  table.insert(critter.scars, {stat = stat})
  critter[stat] = math.max(1, critter[stat] - 1)
  return stat
end

function M.heal(critter, amount)
  critter.hp = math.min(critter.max_hp, critter.hp + amount)
end

return M
