local M = {}

M.ORDER = {"debug","patience","chaos","wisdom","snark","vibe","legacy"}

-- [attacker][defender index] — columns follow ORDER above
-- Derived from DESIGN.md type chart (strong=1.5, neutral=1.0, weak=0.5)
M.CHART = {
  --         DBG  PAT  CHS  WIS  SNA  VIB  LEG
  debug    = {1.0, 1.0, 1.5, 0.5, 1.0, 1.5, 0.5},
  patience = {1.0, 1.0, 1.5, 1.5, 0.5, 0.5, 1.0},
  chaos    = {0.5, 1.5, 1.0, 0.5, 1.5, 1.0, 1.5},
  wisdom   = {1.5, 1.5, 1.0, 1.0, 0.5, 1.0, 0.5},
  snark    = {1.0, 1.5, 0.5, 1.5, 1.0, 0.5, 1.0},
  vibe     = {0.5, 0.5, 1.0, 1.0, 1.5, 1.0, 1.5},
  legacy   = {1.5, 1.0, 0.5, 1.5, 1.0, 0.5, 1.0},
}

local _idx = {}
for i, t in ipairs(M.ORDER) do _idx[t] = i end

function M.effectiveness(atk_type, def_type)
  local row = M.CHART[atk_type]
  local j   = _idx[def_type]
  return (row and j) and row[j] or 1.0
end

return M
