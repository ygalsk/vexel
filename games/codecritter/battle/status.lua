local M = {}

-- Status effect definitions.
-- on_turn_start: called before attacker acts (can set skip_turn)
-- on_turn_end:   called at end of turn, returns optional self-damage number
-- on_apply:      called when status is first applied
-- on_expire:     called when duration runs out
M.defs = {
  blocked = {
    duration = 1,
    on_turn_start = function(c) c.skip_turn = true end,
  },
  linted = {
    duration = 2,
    -- enforced in battle/engine.lua: attacker can only use own-type moves
  },
  spaghettified = {
    duration = 2,
    -- stub: no move inflicts this in Phase 9.1
  },
  enlightened = {
    duration = 2,
    -- on_choose_move hook: pick random move (used by AI; not called in Phase 9.1 main loop)
    on_choose_move = function(c, moves_data)
      return moves_data[c.moves[math.random(#c.moves)]]
    end,
  },
  deprecated = {
    duration = 3,
    on_turn_end = function(c)
      c.logic   = math.max(1, math.floor(c.logic   * 0.95))
      c.resolve = math.max(1, math.floor(c.resolve * 0.95))
      c.speed   = math.max(1, math.floor(c.speed   * 0.95))
    end,
  },
  segfaulted = {
    duration = 3,
    -- 25% chance to take 1/8 max HP as self-damage each turn end
    on_turn_end = function(c)
      if math.random(100) <= 25 then
        return math.max(1, math.floor(c.max_hp / 8))
      end
    end,
  },
  tilted = {
    duration = 3,
    -- enforced in battle/engine.lua: -25% accuracy on all moves
  },
  in_the_zone = {
    duration = 3,
    on_apply = function(c)
      c._zone_logic   = c.logic
      c._zone_resolve = c.resolve
      c.logic   = math.floor(c.logic   * 1.30)
      c.resolve = math.floor(c.resolve * 0.80)
    end,
    on_expire = function(c)
      if c._zone_logic   then c.logic   = c._zone_logic   end
      if c._zone_resolve then c.resolve = c._zone_resolve end
      c._zone_logic   = nil
      c._zone_resolve = nil
    end,
  },
  hallucinating = {
    duration = 3,
    -- enforced in battle/engine.lua: 30% chance attacker hits self
  },
}

-- Apply a status to a critter (last-applied wins; no stacking)
function M.apply(critter, effect_id)
  local def = M.defs[effect_id]
  if not def then return end
  -- expire any previous in_the_zone before overwriting
  if critter.status == "in_the_zone" then
    local old = M.defs.in_the_zone
    if old.on_expire then old.on_expire(critter) end
  end
  critter.status       = effect_id
  critter.status_turns = def.duration
  if def.on_apply then def.on_apply(critter) end
end

-- Call at the start of critter's turn (sets skip_turn for blocked, etc.)
function M.apply_turn_start(critter)
  if not critter.status then return end
  local def = M.defs[critter.status]
  if def and def.on_turn_start then def.on_turn_start(critter) end
end

-- Call at end of turn. Returns optional self-damage number (for segfaulted).
function M.tick(critter)
  if not critter.status then return nil end
  local def      = M.defs[critter.status]
  local self_dmg = nil
  if def and def.on_turn_end then
    self_dmg = def.on_turn_end(critter)
  end
  critter.status_turns = critter.status_turns - 1
  if critter.status_turns <= 0 then
    if def and def.on_expire then def.on_expire(critter) end
    critter.status       = nil
    critter.status_turns = 0
  end
  return self_dmg
end

function M.clear(critter)
  if critter.status == "in_the_zone" then
    local def = M.defs.in_the_zone
    if def.on_expire then def.on_expire(critter) end
  end
  critter.status       = nil
  critter.status_turns = 0
end

function M.describe(effect_id)
  local descs = {
    blocked       = "Blocked: skip next turn",
    linted        = "Linted: can only use own-type moves",
    spaghettified = "Spaghettified: moves execute in random order",
    enlightened   = "Enlightened: confused by clarity, uses random moves",
    deprecated    = "Deprecated: -5% to all stats each turn",
    segfaulted    = "Segfaulted: 25% chance to hurt self each turn",
    tilted        = "Tilted: -25% accuracy",
    in_the_zone   = "In The Zone: +30% Logic, -20% Resolve",
    hallucinating = "Hallucinating: 30% chance to hit self",
  }
  return descs[effect_id] or effect_id
end

return M
