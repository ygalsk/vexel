local types = require("data.types")
local M = {}

-- Wild critter AI: prefer super-effective → else highest power → 20% random
-- Returns a move table (not an id)
function M.choose_move(critter, target, moves_data)
  -- 20% random regardless of matchup
  if math.random(100) <= 20 then
    local idx = math.random(#critter.moves)
    return moves_data[critter.moves[idx]]
  end

  -- enlightened: random move selection
  if critter.status == "enlightened" then
    local idx = math.random(#critter.moves)
    return moves_data[critter.moves[idx]]
  end

  -- Score each move: power × effectiveness × (accuracy/100)
  local best, best_score = nil, -1
  for _, mid in ipairs(critter.moves) do
    local m = moves_data[mid]
    if m and m.power > 0 then
      local eff   = types.effectiveness(m.move_type, target.critter_type)
      local score = m.power * eff * (m.accuracy / 100)
      if score > best_score then
        best_score = score
        best       = m
      end
    end
  end

  return best or moves_data[critter.moves[1]]
end

return M
