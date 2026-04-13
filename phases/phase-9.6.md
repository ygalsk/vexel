# Phase 9.6 — Full Game Flow

## Goal
Wire the complete game loop: title screen → starter select (first time) → hub → party select → run → run over → hub. This phase ensures all transitions are connected, first-launch detection works, and `main.lua` registers every scene correctly.

## Verify
- First launch: title → starter select → hub with chosen starter in party
- Subsequent launches: title → hub directly (starter already chosen)
- Hub [R] → party select → run
- Run ends (any outcome) → run over → hub
- No orphaned scene transitions / crashes on any path

---

## Files to Create/Modify

```
games/codecritter/
├── main.lua                    -- Scene registration, first-launch check
├── ui/title_screen.lua         -- Title + new game / continue
├── ui/starter_select.lua       -- Choose 1 of 3 starters (first launch only)
└── ui/party_select.lua         -- Pre-run party picker + pack consumables
```

---

## Game Flow Diagram

```
[first launch]
  title_screen
      └─> starter_select
              └─> hub  (starter placed in party + roster)

[subsequent launches]
  title_screen
      └─> hub

[run start]
  hub [R]
      └─> party_select
              └─> dungeon (floor 1)
                     ├─> battle_screen (→ back to dungeon on resolve)
                     ├─> shop (after boss floors)
                     └─> run_over
                             └─> hub
```

---

## `main.lua`

```lua
-- main.lua — Codecritter entry point

-- Engine resolution
engine.graphics.set_resolution(640, 360)

-- Audio placeholder (graceful if no device)
-- music system handles its own init

-- Load all scene modules and register them
local scenes = {
    title         = require("ui.title_screen"),
    starter_select = require("ui.starter_select"),
    hub           = require("ui.hub"),
    party_select  = require("ui.party_select"),
    dungeon       = require("ui.dungeon_screen"),
    battle        = require("ui.battle_screen"),
    shop          = require("ui.shop_screen"),
    run_over      = require("ui.run_over"),
}

for name, scene in pairs(scenes) do
    engine.scene.register(name, scene)
end

-- Load persistent player state (placeholder until Phase 9.7)
local persistence = require("db.persistence")
local player = persistence.load_player()

-- First launch detection
if player.first_launch then
    engine.scene.switch("title", {player=player, first_launch=true})
else
    engine.scene.switch("title", {player=player, first_launch=false})
end
```

---

## `ui/title_screen.lua`

```lua
-- ui/title_screen.lua
-- Title screen: logo, "New Game" / "Continue", credits line

local music = require("audio.music")

local W, H = 640, 360
local S = {}

-- ASCII-art logo lines (low-budget charm)
local LOGO = {
    "  ___  ___  ___  ___  ___  ___ ___ ___ _____ _____ _____ ___ ",
    " / __/ / _ \\|   \\| __/ __|| _ \\ |_ _|_ _|_   _|_   _| __| _ \\",
    "| (__ | (_) | |) | _| (__ |   / | | | |  | |   | | | _||   /",
    " \\___/ \\___/|___/|___\\___||_|_\\|___|___| |_|   |_| |___|_|_\\",
}

local MENU_ITEMS = {}
local cursor = 1

function S.load(data)
    S.player      = data.player
    S.first_launch = data.first_launch

    MENU_ITEMS = {}
    if S.first_launch then
        table.insert(MENU_ITEMS, {label="New Game", action="new_game"})
    else
        table.insert(MENU_ITEMS, {label="Continue", action="continue"})
        table.insert(MENU_ITEMS, {label="New Run",  action="new_game"})
    end

    cursor = 1
    music.play("title")
end

function S.update(dt) end

function S.draw()
    engine.graphics.rect(0, 0, W, H, {r=8, g=6, b=18, a=255}, 0)

    -- Logo
    local logo_y = 50
    for i, line in ipairs(LOGO) do
        local col = {r=100 + i*20, g=80, b=180 + i*10, a=255}
        engine.graphics.text(line, 20, logo_y + (i-1)*12, col, 0)
    end

    -- Subtitle
    engine.graphics.text("a terminal creature collector", W/2 - 120, logo_y + 56, {r=130, g=120, b=160, a=255}, 0)

    -- Menu
    local menu_y = 210
    for i, item in ipairs(MENU_ITEMS) do
        local selected = (i == cursor)
        local col = selected and {r=240, g=230, b=255, a=255} or {r=140, g=130, b=160, a=255}
        local prefix = selected and ">  " or "   "
        engine.graphics.text(prefix .. item.label, W/2 - 60, menu_y + (i-1)*30, col, 0)
    end

    -- Footer
    engine.graphics.text("v0.1  —  [Z/Enter] Select  [↑↓] Navigate", W/2 - 160, H - 24, {r=80, g=75, b=95, a=255}, 0)
end

function S.on_key(key)
    if key == "up" then
        cursor = math.max(1, cursor - 1)
    elseif key == "down" then
        cursor = math.min(#MENU_ITEMS, cursor + 1)
    elseif key == "z" or key == "return" then
        local action = MENU_ITEMS[cursor].action
        music.stop()
        if action == "new_game" and S.first_launch then
            engine.scene.switch("starter_select", {player=S.player})
        elseif action == "continue" or action == "new_game" then
            engine.scene.switch("hub", {player=S.player})
        end
    end
end

function S.unload() end

return S
```

---

## `ui/starter_select.lua`

```lua
-- ui/starter_select.lua
-- First-launch only: choose 1 of 3 starters. Rich info panel. No going back.

local species_data  = require("data.species")
local critter_stats = require("critter.stats")
local widgets       = require("ui.widgets")
local music         = require("audio.music")
local persistence   = require("db.persistence")

local W, H = 640, 360

-- Starter species IDs
local STARTER_IDS = {"println", "goto", "glitch"}

local STARTER_FLAVOR = {
    println = {
        tagline = "Reliable. Methodical. Always delivers.",
        style   = "Precision striker. Apply Linted to force opponents into mono-typing.",
        hint    = "Good for players who want consistent, readable strategies.",
    },
    goto = {
        tagline = "Immovable. Patient. Outlasts everything.",
        style   = "Indestructible wall. Apply Deprecated to drain stats over time.",
        hint    = "Always moves last. Wins by surviving.",
    },
    glitch = {
        tagline = "Fast. Reckless. Breaks the rules.",
        style   = "Glass cannon speedster. Apply Segfaulted for 25% self-damage/turn.",
        hint    = "Almost always moves first. One bad matchup ends it.",
    },
}

local S = {}

function S.load(data)
    S.player  = data.player
    S.cursor  = 1
    S.chosen  = false

    -- Build starter critter previews
    S.starters = {}
    for _, id in ipairs(STARTER_IDS) do
        for _, sp in ipairs(species_data) do
            if sp.id == id then
                local critter = critter_stats.new_critter(sp, 5)
                S.starters[#S.starters+1] = critter
                break
            end
        end
    end
end

function S.update(dt) end

function S.draw()
    engine.graphics.rect(0, 0, W, H, {r=10, g=8, b=20, a=255}, 0)

    -- Title
    engine.graphics.text("Choose your starter", W/2 - 80, 16, {r=200, g=190, b=230, a=255}, 0)
    engine.graphics.text("This choice is permanent.", W/2 - 90, 30, {r=130, g=120, b=150, a=255}, 0)

    -- 3 selection cards, horizontal layout
    local CARD_W = 180
    local CARD_H = 240
    local CARD_Y = 56
    local total_w = CARD_W * 3 + 16 * 2
    local start_x = math.floor((W - total_w) / 2)

    for i, critter in ipairs(S.starters) do
        local cx = start_x + (i-1) * (CARD_W + 16)
        local selected = (i == S.cursor)

        -- Card background
        local bg = selected and {r=45, g=38, b=75, a=255} or {r=20, g=16, b=36, a=255}
        engine.graphics.rect(cx, CARD_Y, CARD_W, CARD_H, bg, 0)

        -- Border highlight if selected
        if selected then
            engine.graphics.rect(cx, CARD_Y, CARD_W, 2, {r=150, g=120, b=220, a=255}, 0)
        end

        -- Sprite placeholder (32×32 box)
        engine.graphics.rect(cx + CARD_W/2 - 16, CARD_Y + 8, 32, 32, {r=60, g=50, b=90, a=255}, 0)
        engine.graphics.text("?", cx + CARD_W/2 - 4, CARD_Y + 20, {r=140, g=130, b=160, a=255}, 0)

        -- Name + type
        engine.graphics.text(critter.name, cx + 8, CARD_Y + 48, {r=220, g=215, b=240, a=255}, 0)
        widgets.type_badge(critter.type, cx + 8, CARD_Y + 64)
        widgets.archetype_badge(critter.archetype, cx + 8, CARD_Y + 82)

        -- Stats
        local stat_y = CARD_Y + 102
        for _, stat in ipairs({"logic", "resolve", "speed"}) do
            engine.graphics.text(stat:upper() .. ": " .. critter.stats[stat], cx + 8, stat_y, {r=170, g=165, b=190, a=255}, 0)
            stat_y = stat_y + 14
        end

        -- Flavor
        local flavor = STARTER_FLAVOR[critter.species_id] or {}
        if flavor.tagline then
            engine.graphics.text(flavor.tagline, cx + 6, CARD_Y + 152, {r=150, g=145, b=170, a=255}, 0)
        end
    end

    -- Bottom detail for selected
    local sel = S.starters[S.cursor]
    local flavor = sel and STARTER_FLAVOR[sel.species_id] or {}
    if flavor.style then
        engine.graphics.text(flavor.style, 20, CARD_Y + CARD_H + 16, {r=180, g=175, b=200, a=255}, 0)
    end
    if flavor.hint then
        engine.graphics.text(flavor.hint, 20, CARD_Y + CARD_H + 32, {r=130, g=125, b=150, a=255}, 0)
    end

    -- Confirm prompt
    if not S.chosen then
        engine.graphics.text("[←→] Browse  [Z/Enter] Choose  (no going back)", 20, H - 24, {r=120, g=115, b=140, a=255}, 0)
    else
        engine.graphics.text("Chosen! Starting your journey...", W/2 - 120, H - 24, {r=130, g=220, b=150, a=255}, 0)
    end
end

function S.on_key(key)
    if S.chosen then return end
    if key == "left" then
        S.cursor = math.max(1, S.cursor - 1)
    elseif key == "right" then
        S.cursor = math.min(#S.starters, S.cursor + 1)
    elseif key == "z" or key == "return" then
        S._confirm()
    end
end

function S._confirm()
    S.chosen = true
    local starter = S.starters[S.cursor]

    -- Add to player roster and party
    S.player.roster = S.player.roster or {}
    S.player.party  = {}
    table.insert(S.player.roster, starter)
    table.insert(S.player.party, starter)
    S.player.first_launch = false

    -- Persist
    persistence.save_player(S.player)

    -- Brief delay then hub
    engine.timer.after(0.8, function()
        engine.scene.switch("hub", {player=S.player})
    end)
end

function S.unload() end

return S
```

---

## `ui/party_select.lua`

```lua
-- ui/party_select.lua
-- Pre-run configuration: pick party order, pack consumables for the run

local widgets = require("ui.widgets")
local W, H = 640, 360

local S = {}

function S.load(data)
    S.player     = data.player
    S.on_confirm = data.on_confirm

    -- Build party selection state
    -- roster minus critters on cooldown
    S.available = {}
    for _, critter in ipairs(S.player.roster or {}) do
        if (critter.cooldown_runs or 0) <= 0 then
            table.insert(S.available, critter)
        end
    end

    S.selected_party = {}  -- ordered list (up to 3, or 4 if unlocked)
    S.max_party = S.player.unlocks and S.player.unlocks.fourth_slot and 4 or 3

    S.panel    = "roster"   -- "roster" | "inventory"
    S.cursor   = 1

    -- Pack consumable inventory for the run (copy from player inventory)
    S.run_inventory = {
        healing = {},
        catch   = {},
        disc    = {},
        hold    = {},
    }
    -- Pre-populate with 2 quick heals if available
    local heals_packed = 0
    for _, id in ipairs(S.player.inventory.healing or {}) do
        if heals_packed < 2 then
            table.insert(S.run_inventory.healing, id)
            heals_packed = heals_packed + 1
        end
    end
end

function S.draw()
    engine.graphics.rect(0, 0, W, H, {r=10, g=8, b=20, a=255}, 0)

    -- Title
    engine.graphics.rect(0, 0, W, 28, {r=22, g=18, b=38, a=255}, 0)
    engine.graphics.text("Prepare your party", 16, 8, {r=200, g=190, b=230, a=255}, 0)
    engine.graphics.text("Max " .. S.max_party .. " critters per run", W - 180, 8, {r=130, g=125, b=155, a=255}, 0)

    -- Left: available roster
    local LIST_W = 240
    engine.graphics.text("Roster (select to add)", 8, 36, {r=160, g=155, b=185, a=255}, 0)
    for i, critter in ipairs(S.available) do
        local sy = 54 + (i-1) * 32
        local in_party = S._in_party(critter)
        local selected = (S.panel == "roster" and i == S.cursor)
        local bg = selected and {r=48, g=40, b=78, a=255}
            or (in_party and {r=28, g=40, b=32, a=255} or {r=20, g=16, b=34, a=255})
        engine.graphics.rect(4, sy, LIST_W - 8, 30, bg, 0)
        local name_col = in_party and {r=100, g=200, b=130, a=255} or {r=210, g=205, b=230, a=255}
        engine.graphics.text((in_party and "✓ " or "  ") .. critter.name .. " Lv" .. critter.level, 10, sy + 8, name_col, 0)
    end

    -- Right: selected party (ordered)
    local px = LIST_W + 16
    engine.graphics.text("Party order:", px, 36, {r=160, g=155, b=185, a=255}, 0)
    for i = 1, S.max_party do
        local py = 54 + (i-1) * 44
        local critter = S.selected_party[i]
        local bg = {r=18, g=15, b=30, a=255}
        engine.graphics.rect(px, py, W - px - 12, 40, bg, 0)
        engine.graphics.text("[" .. i .. "]", px + 6, py + 12, {r=130, g=125, b=150, a=255}, 0)
        if critter then
            widgets.critter_mini(critter, px + 28, py + 6, false)
        else
            engine.graphics.text("--- Empty ---", px + 50, py + 12, {r=70, g=65, b=85, a=255}, 0)
        end
    end

    -- Controls
    engine.graphics.rect(0, H - 30, W, 30, {r=16, g=12, b=28, a=255}, 0)
    local can_start = #S.selected_party > 0
    local hint_col = can_start and {r=120, g=210, b=145, a=255} or {r=100, g=95, b=115, a=255}
    engine.graphics.text("[Z] Add/Remove  [X] Cancel  [Enter] Start Run", 16, H - 22, {r=130, g=120, b=150, a=255}, 0)
    if can_start then
        engine.graphics.text("[Enter] Start Run", W - 160, H - 22, hint_col, 0)
    end
end

function S._in_party(critter)
    for _, c in ipairs(S.selected_party) do
        if c == critter then return true end
    end
    return false
end

function S.on_key(key)
    if key == "up" then
        S.cursor = math.max(1, S.cursor - 1)
    elseif key == "down" then
        S.cursor = math.min(#S.available, S.cursor + 1)
    elseif key == "z" then
        local critter = S.available[S.cursor]
        if critter then
            if S._in_party(critter) then
                -- Remove from party
                for i, c in ipairs(S.selected_party) do
                    if c == critter then
                        table.remove(S.selected_party, i)
                        break
                    end
                end
            else
                -- Add to party if room
                if #S.selected_party < S.max_party then
                    table.insert(S.selected_party, critter)
                end
            end
        end
    elseif key == "x" then
        engine.scene.pop()
    elseif key == "return" then
        if #S.selected_party > 0 then
            S._confirm()
        end
    end
end

function S._confirm()
    -- Restore HP for all selected party members (they start with current HP — no auto-heal before run)
    S.on_confirm(S.selected_party, S.run_inventory)
end

function S.unload() end

return S
```

---

## `db/persistence.lua` (stub for Phase 9.6)

```lua
-- db/persistence.lua
-- Stub until Phase 9.7. Returns a blank player state on first launch.

local M = {}

-- Default blank player state
local function default_player()
    return {
        first_launch = true,
        roster       = {},
        party        = {},
        inventory    = {
            healing = {},
            catch   = {"catch_basic", "catch_basic", "catch_basic"},
            disc    = {},
            hold    = {},
        },
        codex     = {},
        commits   = {},
        unlocks   = {},
        lifetime  = {
            runs        = 0,
            floors      = 0,
            catches     = 0,
            faints      = 0,
            currency    = 0,
        },
    }
end

function M.load_player()
    -- Phase 9.7: load from SQLite
    -- For now: return default player (no persistence yet)
    return default_player()
end

function M.save_player(player)
    -- Phase 9.7: persist to SQLite
    -- No-op for now
end

return M
```

---

## Scene Registration in `main.lua`

All scenes registered by name string, so `engine.scene.switch("hub", {...})` works from any file without circular requires. The `main.lua` above is the canonical registration point.

---

## Checklist

- [ ] `main.lua` — register all scenes, first-launch check, load player state
- [ ] `ui/title_screen.lua` — title, menu (New Game / Continue), route to starter_select or hub
- [ ] `ui/starter_select.lua` — 3-card layout, type+archetype info, confirm with brief delay
- [ ] `ui/party_select.lua` — available roster, ordered party slots, confirm to start run
- [ ] `db/persistence.lua` stub — `load_player()` returns default, `save_player()` is no-op
- [ ] Wire starter → hub: after selection, `player.first_launch = false`, push starter to party+roster
- [ ] Wire hub → party_select → dungeon via `on_confirm` callback
- [ ] Wire run_over → hub with `run_result` passed in
- [ ] Test: full first-launch flow: title → starter select → hub
- [ ] Test: return flow: run_over → hub (roster shows caught critters)
- [ ] Test: critters on cooldown do NOT appear in party_select available list
- [ ] Test: 4th party slot locked by default, visible but unselectable
