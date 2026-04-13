-- Music manager. Maps context strings to WAV files, lazy-loads handles.

local M = {}
local base = "assets/music/"

M.tracks = {
  title        = base .. "2014 07_ Clement Panchout_ Partycles OST_ Cheerful Title Screen.wav",
  hub          = base .. "2016_ Clement Panchout_ Life is full of Joy.wav",
  dungeon      = base .. "Space Horror InGame Music (Exploration) _Clement Panchout.wav",
  dungeon_deep = base .. "Space Horror InGame Music (Tense) _Clement Panchout.wav",
  battle_wild  = base .. "16-Bit Beat Em All _Clement Panchout.wav",
  battle_boss  = base .. "Clement Panchout _ MW FUP _ Chaotic Boss.wav",
  shop         = base .. "2014 07_ Clement Panchout_ Partycles OST_ The Chillout Factory.wav",
  victory      = base .. "Clement Panchout _ Unsettling victory _ 2019.wav",
  wipe         = base .. "Clement Panchout_ Shadows.wav",
}

local handles = {}
local current = nil

function M.play(context)
  local path = M.tracks[context]
  if not path or context == current then return end
  if current and handles[current] then
    handles[current]:stop()
  end
  if not handles[context] then
    local ok, h = pcall(engine.audio.load, path, { stream = true })
    if not ok then return end
    handles[context] = h
  end
  handles[context]:play({ loop = true, volume = 0.7 })
  current = context
end

function M.stop()
  if current and handles[current] then
    handles[current]:stop()
    current = nil
  end
end

return M
