# Phase 9.2 — Battle Screen

## Goal
Full interactive battle UI with Pokemon-classic layout. First playable screen. All 4 encounter types supported.

---

## Design Context

**Layout (640×360):**
```
┌─────────────────────────────────────────────────────────────────────┐
│ ENEMY SECTION (top 40%)                                             │
│  [status] [name Lv##] [type badge]  [archetype]    ████░ HP        │
│                               [ENEMY SPRITE  ]                     │
│                               [BOSS: Party ●●○]  ← boss header    │
├─────────────────────────────────────────────────────────────────────┤
│ PLAYER SECTION (mid 35%)                                            │
│                    [PLAYER SPRITE  ]                                │
│  [status] [name Lv##] [type badge] [archetype]     ████░ HP        │
│                                    [BENCH: sprite] ████░ HP        │
├─────────────────────────────────────────────────────────────────────┤
│ ACTION AREA (bottom 25%)                                            │
│  MESSAGE LOG (rolling, 2 lines)                                     │
│  [1] Attack  [2] Catch  [3] Swap  [4] Item  [B] Bench*             │
│  * Bench action only in boss+minion encounters                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Battle state machine:**
```
INTRO → PLAYER_ACTION → PLAYER_MOVE/CATCH/SWAP/ITEM/BENCH → RESOLVE → TICK_STATUS
  → CHECK_END → (NEXT_TURN or VICTORY or DEFEAT or CAUGHT)
  → XP_DISPLAY → EVOLUTION_CHECK → RETURN_TO_CALLER
```

**Full-screen moments triggered here:**
- First catch ever (one-time)
- Evolution (full-screen flash + sprite swap)

**Encounter type headers:**
- Standard: just enemy name/level
- Boss team: `[BOSS] Profiler — Party: ●●○`
- Boss+minion: both enemy sprites visible + bench action row
- Swarm: `[SWARM] 1 of 3`

---

## Files to Create/Modify

### `sprite/registry.lua`
Maps species_id → sprite config. Placeholder: 32×16 2-frame sprites from old project.
```lua
return {
  println = {
    path = "assets/sprites/println.png",
    frame_w = 32, frame_h = 16,
    scale = 2,   -- render at 64×32 in battle
    animations = {
      idle   = { frames = {0,1}, speed = 0.5, loop = true },
      attack = { frames = {0},   speed = 0.0, loop = false },
      hit    = { frames = {1},   speed = 0.0, loop = false },
      faint  = { frames = {1},   speed = 0.0, loop = false },
    }
  },
  -- one entry per species; all default to similar config for placeholders
}
```

### `ui/widgets.lua`
Reusable UI components. All drawn via `engine.graphics.*`.

```lua
local M = {}

-- HP bar: x, y, current, max, width=120
-- Colors: green (>50%), yellow (25–50%), red (<25%)
function M.hp_bar(x, y, hp, max_hp, width)
  width = width or 120
  local pct = hp / math.max(1, max_hp)
  local r, g, b
  if pct > 0.5 then r,g,b = 60,200,60
  elseif pct > 0.25 then r,g,b = 220,200,0
  else r,g,b = 200,50,50 end
  -- Background
  engine.graphics.pixel.rect(x, y, width, 6, 40, 40, 40, 255)
  -- Fill
  engine.graphics.pixel.rect(x, y, math.floor(width * pct), 6, r, g, b, 255)
end

-- Type badge: small colored pill with type name
function M.type_badge(x, y, type_name, types_data)
  local col = types_data.colors[type_name] or {r=128,g=128,b=128}
  engine.graphics.pixel.rect(x, y, 40, 12, col.r, col.g, col.b, 200)
  engine.graphics.text(x+2, y+2, type_name:upper(), col.r, col.g, col.b)
end

-- Archetype badge
function M.archetype_badge(x, y, archetype_name)
  engine.graphics.pixel.rect(x, y, 52, 12, 60, 60, 80, 200)
  engine.graphics.text(x+2, y+2, archetype_name, 200, 200, 220)
end

-- Panel border (Pixel UI Pack style)
function M.panel(x, y, w, h)
  engine.graphics.pixel.rect(x, y, w, h, 20, 20, 30, 220)
  engine.graphics.pixel.rect(x, y, w, 1, 80, 80, 100, 255)
  engine.graphics.pixel.rect(x, y+h-1, w, 1, 80, 80, 100, 255)
  engine.graphics.pixel.rect(x, y, 1, h, 80, 80, 100, 255)
  engine.graphics.pixel.rect(x+w-1, y, 1, h, 80, 80, 100, 255)
end

-- Message log: draws 2 most recent messages
function M.message_log(x, y, w, messages)
  M.panel(x, y, w, 24)
  local start = math.max(1, #messages - 1)
  for i = start, #messages do
    local msg = messages[i]
    engine.graphics.text(x+4, y + (i-start)*11 + 4,
      msg.text, msg.r or 220, msg.g or 220, msg.b or 220)
  end
end

-- Status icon: small indicator
function M.status_icon(x, y, status_name)
  if not status_name then return end
  local labels = {
    blocked="BLK", deprecated="DEP", segfaulted="SEG", linted="LNT",
    tilted="TLT", in_the_zone="ZONE", spaghettified="SPA",
    enlightened="ENL", hallucinating="HAL",
  }
  local colors = {
    blocked={100,100,220}, deprecated={140,100,60}, segfaulted={220,50,50},
    linted={0,200,80}, tilted={220,160,0}, in_the_zone={255,150,200},
    spaghettified={180,100,220}, enlightened={200,200,60}, hallucinating={200,100,180},
  }
  local label = labels[status_name] or "???"
  local c = colors[status_name] or {150,150,150}
  engine.graphics.pixel.rect(x, y, 24, 10, c[1], c[2], c[3], 200)
  engine.graphics.text(x+2, y+1, label, 0, 0, 0)
end

return M
```

### `ui/anim.lua`
Battle step sequencer. A queue of `{fn, delay}` pairs that plays through automatically.
```lua
local M = {}

function M.new()
  return { queue = {}, timer = 0, done = false }
end

-- Add a step: fn() runs immediately, then waits `delay` seconds
function M.push(seq, fn, delay)
  table.insert(seq.queue, { fn = fn, delay = delay or 0 })
end

-- Call in update(dt). Returns true when all steps complete.
function M.update(seq, dt)
  if seq.done then return true end
  if #seq.queue == 0 then seq.done = true; return true end

  local step = seq.queue[1]
  if not step.started then
    step.fn()
    step.started = true
  end
  seq.timer = seq.timer + dt
  if seq.timer >= step.delay then
    seq.timer = 0
    table.remove(seq.queue, 1)
  end
  return false
end

-- Skip remaining delays (Enter to advance)
function M.skip(seq)
  seq.timer = 999
end

return M
```

### `ui/battle_screen.lua`
The main battle scene. Receives `data` from `engine.scene.push("battle", data)`.

```lua
-- data = {
--   party = { critter1, critter2, critter3 },  -- player party
--   enemy = critter,                            -- or
--   encounter_type = "wild"|"boss_team"|"boss_minion"|"swarm",
--   boss_team = { critter1, critter2, critter3 },  -- for boss_team
--   minion = critter,                              -- for boss_minion
--   swarm = { critter1, critter2, critter3 },      -- for swarm
--   biome = biome_id,
--   floor = floor_num,
-- }

local widgets = require("ui.widgets")
local anim    = require("ui.anim")
local battle  = require("battle.engine")
local ai      = require("battle.ai")
local status  = require("battle.status")
local stat    = require("critter.stats")
local types   = require("data.types")
local moves   = require("data.moves")
local items   = require("data.items")
local registry = require("sprite.registry")

local scene = {}
local state  -- battle state table
local seq    -- animation sequencer

-- Sprite animation state per critter
local function new_sprite_state(species_id, facing)
  return {
    species_id = species_id,
    facing = facing or "right",
    anim = "idle",
    frame = 0,
    timer = 0,
  }
end

function scene.load(data)
  -- Initialize battle state from incoming data
  state = {
    phase = "intro",    -- intro, player_action, sub_menu, resolving, end
    encounter_type = data.encounter_type or "wild",
    party = data.party,
    active_idx = 1,     -- which party member is active
    enemy = data.enemy,
    boss_team = data.boss_team or {},
    boss_idx = 1,
    minion = data.minion,
    swarm = data.swarm or {},
    swarm_idx = 1,
    messages = {},
    menu_cursor = 1,    -- 1=Attack, 2=Catch, 3=Swap, 4=Item, 5=Bench
    sub_menu = nil,     -- "moves"|"catch"|"swap"|"items"|"bench"
    sub_cursor = 1,
    result = nil,       -- "victory"|"defeat"|"caught"|"extracted"
    pending_xp = 0,
    floor = data.floor or 1,
  }

  -- Load sprites
  state.player_sprite = new_sprite_state(data.party[1].species_id, "right")
  state.enemy_sprite  = new_sprite_state(data.enemy.species_id, "left")

  -- Load battle music
  engine.audio.play_music("battle_wild")  -- handled by music.lua

  seq = anim.new()
  -- Intro sequence
  anim.push(seq, function()
    M.add_msg("A wild " .. data.enemy.name .. " appeared!")
  end, 1.0)
  anim.push(seq, function()
    state.phase = "player_action"
  end, 0.0)
end

local function M_add_msg(text, r, g, b)  -- forward declared
  table.insert(state.messages, { text=text, r=r, g=g, b=b })
end

-- ... (full implementation follows patterns from battle engine)
-- Key methods:
-- scene.update(dt)    -- drives sequencer, handles input in player_action phase
-- scene.draw()        -- renders all layers
-- scene.on_key(key)   -- routes input to current phase handler

-- Input handler for player_action phase
local function handle_player_action_input(key)
  if key == "1" or key == "return" then
    if state.menu_cursor == 1 then  -- Attack
      state.sub_menu = "moves"
      state.sub_cursor = 1
      state.phase = "sub_menu"
    elseif state.menu_cursor == 2 then  -- Catch
      state.sub_menu = "catch"
      state.sub_cursor = 1
      state.phase = "sub_menu"
    -- ... etc
    end
  elseif key == "up" or key == "down" then
    -- navigate menu_cursor
  end
end

-- On move selected: build resolution sequence
local function resolve_turn(player_move)
  state.phase = "resolving"
  seq = anim.new()

  local player = state.party[state.active_idx]
  local enemy  = state.enemy

  -- Speed check: who goes first?
  local player_first = player.speed >= enemy.speed

  local function do_player_attack()
    local result = battle.process_attack(player, player_move, enemy, moves)
    if result.missed then
      anim.push(seq, function() M_add_msg(player.name .. " missed!") end, 0.8)
    else
      anim.push(seq, function()
        enemy.hp = math.max(0, enemy.hp - result.damage)
        M_add_msg(string.format("%s → %d dmg %s", player_move.name, result.damage, result.label))
        -- Trigger hit animation
        state.enemy_sprite.anim = "hit"
      end, 0.3)
      if result.status_applied then
        anim.push(seq, function()
          M_add_msg(enemy.name .. " is " .. result.status_applied .. "!")
        end, 0.5)
      end
    end
  end

  -- ... enemy AI, turn resolution, faint checks, XP, etc.

  -- After all steps: check if battle is over
  anim.push(seq, function()
    if enemy.hp <= 0 then
      M_add_msg(enemy.name .. " fainted!")
      state.pending_xp = stat.xp_reward(enemy.level)
      state.phase = "end"
      state.result = "victory"
    else
      state.phase = "player_action"
    end
  end, 0.5)
end

function scene.update(dt)
  -- Update sprite animations
  -- Update sequencer
  if seq then anim.update(seq, dt) end
  -- Update sprite frame timers
end

function scene.draw()
  engine.graphics.set_layer(0)
  -- Battle background (biome-specific)

  engine.graphics.set_layer(1)
  -- Enemy sprite (top-right area)
  -- Player sprite (bottom-left area)
  -- Minion sprite (if boss_minion encounter, top-left area)

  engine.graphics.set_layer(3)
  -- Enemy HP bar, name, type badge, status icon
  -- Player HP bar, name, type badge, status icon
  -- Bench critter mini-display (if applicable)
  -- Boss team indicator (●●○)
  -- Swarm indicator
  -- Message log (bottom)
  -- Action menu (if player_action phase)
  -- Sub-menu (if sub_menu phase)
end

function scene.on_key(key)
  if key == "escape" then
    -- No escape from battle — show brief message
    M_add_msg("There's no running from this!")
    return
  end
  if seq and not seq.done then
    anim.skip(seq)
    return
  end
  if state.phase == "player_action" then
    handle_player_action_input(key)
  elseif state.phase == "sub_menu" then
    -- handle sub-menu navigation
  end
end

return scene
```

### `audio/music.lua`
Maps context string → WAV file path. Called by scenes.

```lua
local M = {}
local base = "assets/music/"

M.tracks = {
  title       = base .. "Cheerful Title Screen.wav",
  hub         = base .. "Life is full of Joy.wav",
  dungeon     = base .. "Space Horror InGame Music (Exploration).wav",
  dungeon_deep= base .. "Space Horror InGame Music (Tense).wav",
  battle_wild = base .. "16-Bit Beat Em All.wav",
  battle_boss = base .. "Chaotic Boss.wav",
  shop        = base .. "The Chillout Factory.wav",
  victory     = base .. "Unsettling victory.wav",
  wipe        = base .. "Shadows.wav",
}

local current = nil

function M.play(context)
  local path = M.tracks[context]
  if not path or context == current then return end
  if current then engine.audio.stop_music() end
  engine.audio.play_music(path, { loop = true, volume = 0.7 })
  current = context
end

function M.stop()
  engine.audio.stop_music()
  current = nil
end

return M
```

---

## Asset Setup Tasks

- [ ] Copy placeholder sprites: `cp ~/Documents/codecritters/assets/sprites/*.png games/codecritter/assets/sprites/`
- [ ] Copy battle effects: `cp "~/Documents/vexel/assets/Legacy Collection/Assets/Explosions and Magic/Grotto-escape-2-FX/spritesheets/"*.png games/codecritter/assets/effects/`
- [ ] Copy dungeon tileset: `cp "~/Documents/vexel/assets/Legacy Collection/Assets/TinyRPG/Environments/single-dungeon-crawler/PNG/dungeon-tileset.png" games/codecritter/assets/tiles/`
- [ ] Symlink or copy music tracks: verify `games/codecritter/assets/music/` contains the 9 mapped WAV files
- [ ] Verify Pixel UI Pack at `~/Documents/vexel/assets/All.png` and plan extract approach for HP bars/panels

---

## Task Checklist

- [ ] `sprite/registry.lua` — all 61 species mapped (copy same config for all placeholders)
- [ ] `ui/widgets.lua` — hp_bar, type_badge, archetype_badge, panel, message_log, status_icon
- [ ] `ui/anim.lua` — step sequencer (push, update, skip)
- [ ] `audio/music.lua` — context map, play, stop
- [ ] `ui/battle_screen.lua`:
  - [ ] Load function (all 4 encounter types)
  - [ ] Sprite rendering with idle animation
  - [ ] HP bars (static for now — tween in 9.8)
  - [ ] Status icons
  - [ ] Message log (rolling, color-coded)
  - [ ] Action menu: Attack / Catch / Swap / Item
  - [ ] Bench action row (boss+minion only)
  - [ ] Move sub-menu with type/power/effectiveness preview
  - [ ] Catch sub-menu with success % shown
  - [ ] Party swap sub-menu with HP display
  - [ ] Item use with target selection
  - [ ] Turn resolution with step-through (Enter advances)
  - [ ] Boss team indicator (Party: ●●○) and next-critter logic
  - [ ] Swarm indicator and sequential fight logic
  - [ ] Victory state: XP gain display
  - [ ] Defeat state
  - [ ] Caught state
  - [ ] Evolution interrupt (full-screen flash + sprite swap)
  - [ ] First-catch-ever interrupt (one-time)
- [ ] `main.lua` updated: register "battle" scene, auto-start test battle
- [ ] Battle music plays on enter, stops on exit

## Verification

`zig build run -- games/codecritter/` shows a battle screen. Player can:
- See enemy and player sprites with idle animations
- Navigate the action menu with arrow keys
- Select Attack → pick a move → watch damage resolve with effectiveness label
- See HP drain (instant for now)
- Watch enemy AI respond
- Win (victory → XP display) or lose (defeat screen)
- Press Enter to advance through messages
