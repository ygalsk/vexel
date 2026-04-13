# Phase 9.9 — Meta Progression

## Goal
Wire all achievement tracking ("Commits"), unlock conditions, and the Records tab into a live system that responds to game events. At this point all other phases are complete — this phase is about making the meta layer feel alive: commits trigger as they happen, unlocks change what the hub shows, and the Records tab is the complete career view.

## Verify
- `feat: add critter` fires on first catch (ever), persists
- `release: v1.0` fires on floor 15 clear
- `feat!: breaking change` fires on first wipe
- Biome select appears in hub after floor 5 clear
- 4th party slot unlocked after catching one of each type
- Secret 4th starter (Heisenbug) appears in starter_select after codex fill
- Records tab: codex shows seen/caught correctly across runs; commits list shows earned vs locked

---

## Architecture

Meta progression is purely reactive. Every event that can trigger a commit or unlock should call `meta.on_event(player, event_name, data)`. The meta module checks conditions and fires `persistence.grant_commit()` / `persistence.check_unlocks()` as needed. The hub re-reads `player.commits` and `player.unlocks` on every load.

---

## Files to Create/Modify

```
games/codecritter/
├── meta.lua                -- Event handler + commit/unlock condition checks (new)
├── ui/hub_records.lua      -- Wire to live player data (already written, verify)
├── ui/hub.lua              -- Show unlock hints when newly unlocked
├── ui/title_screen.lua     -- Heisenbug starter option when secret_starter unlocked
└── ui/party_select.lua     -- 4th slot live when fourth_slot unlocked
```

---

## `meta.lua`

```lua
-- meta.lua
-- Reactive meta progression: commit grants and unlock checks.
-- Call meta.on_event(player, "event_name", data) from anywhere in the game.

local persistence = require("db.persistence")
local M = {}

-- ---------------------------------------------------------------------------
-- Commit condition checks
-- These are checked reactively on relevant events.
-- ---------------------------------------------------------------------------

-- Commit conditions: {id, check_fn(player, event, data) → bool}
local COMMIT_CHECKS = {
    {
        id    = "first_catch",
        event = "catch",
        check = function(player, data)
            return true  -- any catch on a player with no prior catches
        end,
        once  = true,
    },
    {
        id    = "edge_case",
        event = "battle_win",
        check = function(player, data)
            return data.active_hp_pct and data.active_hp_pct < 0.1
        end,
    },
    {
        id    = "hotfix_prod",
        event = "battle_win",
        check = function(player, data)
            return data.had_faint  -- a critter fainted during this battle
        end,
    },
    {
        id    = "release_v1",
        event = "floor_clear",
        check = function(player, data)
            return data.floor == 15
        end,
    },
    {
        id    = "breaking",
        event = "run_wipe",
        check = function(player, data)
            return true
        end,
        once  = true,
    },
    {
        id    = "add_comments",
        event = "codex_update",
        check = function(player, data)
            -- All species caught
            local species_data = require("data.species")
            local caught = 0
            for _, entry in pairs(player.codex) do
                if entry.caught then caught = caught + 1 end
            end
            return caught >= #species_data
        end,
    },
    {
        id    = "pipeline",
        event = "run_complete",
        check = function(player, data)
            return data.total_faints == 0
        end,
    },
    {
        id    = "revert",
        event = "catch",
        check = function(player, data)
            return data.rarity == "legendary"
        end,
    },
    {
        id    = "perf",
        event = "battle_win",
        check = function(player, data)
            return data.damage_taken == 0
        end,
    },
    {
        id    = "test_coverage",
        event = "run_complete",
        check = function(player, data)
            return data.catch_types_used and
                data.catch_types_used.basic and
                data.catch_types_used.stealth and
                data.catch_types_used.null_ptr
        end,
    },
    {
        id    = "chore",
        event = "catch",
        check = function(player, data)
            -- Check if player now has all 3 in a complete evolution line
            if not data.species_id then return false end
            local species_data = require("data.species")
            -- Find evolution line
            local function find_line(sp)
                -- Walk to root of evolution chain
                local line = {sp.id}
                local current = sp
                while current.evolution do
                    for _, other in ipairs(species_data) do
                        if other.id == current.evolution then
                            table.insert(line, other.id)
                            current = other
                            break
                        end
                    end
                    break  -- simple 2-stage for now
                end
                return line
            end
            for _, sp in ipairs(species_data) do
                if sp.id == data.species_id then
                    local line = find_line(sp)
                    if #line >= 3 then
                        local all_caught = true
                        for _, sid in ipairs(line) do
                            if not (player.codex[sid] and player.codex[sid].caught) then
                                all_caught = false
                                break
                            end
                        end
                        return all_caught
                    end
                end
            end
            return false
        end,
    },
    {
        id    = "refactor",
        event = "evolution",
        check = function(player, data)
            return true
        end,
        once  = true,
    },
    {
        id    = "merge_conflict",
        event = "party_change",
        check = function(player, data)
            local scar_count = 0
            for _, critter in ipairs(player.party or {}) do
                if critter.scars and #critter.scars > 0 then
                    scar_count = scar_count + 1
                end
            end
            return scar_count >= 2
        end,
    },
}

-- ---------------------------------------------------------------------------
-- Main event handler
-- ---------------------------------------------------------------------------

-- Event names:
--   "catch"         data: {critter, rarity, species_id}
--   "battle_win"    data: {active_hp_pct, had_faint, damage_taken}
--   "run_wipe"      data: {}
--   "run_complete"  data: {total_faints, catch_types_used}
--   "floor_clear"   data: {floor}
--   "evolution"     data: {critter, from_name, to_name}
--   "codex_update"  data: {}
--   "party_change"  data: {}

function M.on_event(player, event_name, data)
    data = data or {}
    local newly_earned = {}

    for _, check in ipairs(COMMIT_CHECKS) do
        if check.event == event_name then
            -- Skip if already earned and marked once
            local already = player.commits[check.id]
            if not already or not check.once then
                if not already and check.check(player, data) then
                    local granted = persistence.grant_commit(player, check.id)
                    if granted then
                        table.insert(newly_earned, check.id)
                    end
                end
            end
        end
    end

    -- Check unlocks after every event
    persistence.check_unlocks(player)

    return newly_earned  -- caller can show notification if any
end

-- ---------------------------------------------------------------------------
-- Commit notification helper
-- ---------------------------------------------------------------------------

-- Returns display label for a commit id
local COMMIT_LABELS = {
    first_catch   = 'feat: add critter',
    edge_case     = 'fix: handle edge case',
    hotfix_prod   = 'hotfix: prod is down',
    release_v1    = 'release: v1.0',
    breaking      = 'feat!: breaking change',
    add_comments  = 'docs: add comments',
    pipeline      = 'ci: pipeline passes',
    revert        = 'revert: this was a mistake',
    perf          = 'perf: reduce allocations',
    test_coverage = 'test: add coverage',
    chore         = 'chore: clean up globals',
    refactor      = 'refactor: extract method',
    merge_conflict= 'merge conflict resolved',
}

function M.label(commit_id)
    return COMMIT_LABELS[commit_id] or commit_id
end

return M
```

---

## Event Call Sites

### In `battle/engine.lua` — after battle resolves:
```lua
-- After a successful catch:
local newly_earned = meta.on_event(player, "catch", {
    critter    = caught_critter,
    rarity     = caught_critter.rarity,
    species_id = caught_critter.species_id,
})
-- Update codex seen/caught:
player.codex[caught_critter.species_id] = {seen=true, caught=true}
meta.on_event(player, "codex_update", {})
-- Show commit notification if any earned
for _, commit_id in ipairs(newly_earned) do
    -- Queue in battle log or show as toast
    battle.log("Commit: " .. meta.label(commit_id))
end
```

### In `ui/battle_screen.lua` — on battle win:
```lua
local newly_earned = meta.on_event(player, "battle_win", {
    active_hp_pct = active.hp / active.max_hp,
    had_faint     = S.had_faint,
    damage_taken  = S.damage_taken,
})
```

### In `ui/run_over.lua` — on run end:
```lua
if S.outcome == "wipe" then
    meta.on_event(player, "run_wipe", {})
elseif S.outcome == "victory" then
    meta.on_event(player, "run_complete", {
        total_faints    = S.run.total_faints,
        catch_types_used = S.run.catch_types_used,
    })
end
meta.on_event(player, "floor_clear", {floor = S.stats.floors})
```

### In `critter/stats.lua` — on evolution:
```lua
local newly_earned = meta.on_event(player, "evolution", {
    critter   = critter,
    from_name = old_name,
    to_name   = critter.name,
    old_stats = old_stats,
})
```

### In `ui/hub.lua` — on party change:
```lua
meta.on_event(player, "party_change", {})
```

---

## Heisenbug as Secret Starter

In `ui/starter_select.lua`, conditionally add Heisenbug to the starter list:

```lua
function S.load(data)
    S.player = data.player
    local secret_unlocked = S.player.unlocks and S.player.unlocks.secret_starter

    -- Base starters
    STARTER_IDS = {"println", "goto", "glitch"}
    if secret_unlocked then
        table.insert(STARTER_IDS, "heisenbug")
    end
    -- ... rest of load ...
end
```

Add Heisenbug flavor text:
```lua
STARTER_FLAVOR.heisenbug = {
    tagline = "Exists until you observe it.",
    style   = "Zero Day Wild Card. Breaks all normal mechanics. Extreme one stat.",
    hint    = "Hidden from codex until caught. This is the real game.",
}
```

---

## 4th Party Slot Live Update

In `ui/party_select.lua`:
```lua
S.max_party = (S.player.unlocks and S.player.unlocks.fourth_slot) and 4 or 3
```

In `ui/hub_party.lua`, the 4th slot draws locked if not unlocked:
```lua
for i = 1, 4 do
    local critter = player.party[i]
    local locked = (i == 4 and not (player.unlocks and player.unlocks.fourth_slot))
    -- ... draw slot ...
    if locked then
        -- Draw lock icon
        engine.graphics.text("[Catch all 7 types to unlock]", x + 10, sy + 18, {r=90, g=85, b=110, a=255}, 0)
    end
end
```

---

## Unlock Notification Toast

When `meta.on_event()` detects a new unlock, the hub should show a brief toast. Implement via a shared notification queue:

```lua
-- In ui/hub.lua:
local notify = require("ui.notify")

function S.update(dt)
    notify.update(dt)
    -- ...
end

function S.draw()
    -- ...
    notify.draw()  -- drawn on top of everything
end

-- After meta.on_event returns, if unlocks changed:
-- notify.show("Unlocked: Biome Selection!")
```

```lua
-- ui/notify.lua — simple toast notification queue
local M = {}
local queue = {}

function M.show(text, duration)
    table.insert(queue, {text=text, t=duration or 3.0, y=0})
end

function M.update(dt)
    for i = #queue, 1, -1 do
        queue[i].t = queue[i].t - dt
        if queue[i].t <= 0 then table.remove(queue, i) end
    end
end

function M.draw()
    local W = 640
    for i, note in ipairs(queue) do
        local alpha = math.min(255, math.floor(note.t * 255))
        local ny = 8 + (i-1) * 22
        engine.graphics.rect(W - 300, ny, 290, 18, {r=30, g=60, b=40, a=alpha}, 5)
        engine.graphics.text(note.text, W - 294, ny + 3, {r=130, g=220, b=150, a=alpha}, 5)
    end
end

return M
```

---

## Biome Selection (Post Floor-5 Unlock)

In `ui/party_select.lua` or in `ui/hub.lua`, when starting a run:

```lua
function S._start_run()
    -- If biome selection unlocked, push biome_select scene first
    if S.player.unlocks and S.player.unlocks.biome_select then
        engine.scene.push("biome_select", {
            player = S.player,
            on_select = function(biome_id)
                -- Continue to party_select with biome
                engine.scene.switch("party_select", {
                    player  = S.player,
                    biome   = biome_id,
                    on_confirm = function(party, inv)
                        local run = require("dungeon.run").new(S.player)
                        run.party = party
                        run.inventory = inv
                        run.biome = biome_id
                        engine.scene.switch("dungeon", {run=run, floor=1})
                    end,
                })
            end,
        })
    else
        -- Default biome selection (random or floor-auto)
        engine.scene.switch("party_select", { ... })
    end
end
```

Biome select scene is a simple list with biome names and descriptions. Implementation mirrors hub_items.lua structure.

---

## Records Tab Final Wiring

`ui/hub_records.lua` is already written in Phase 9.5 with codex/commits/unlocks tabs. For Phase 9.9, verify live data flows correctly:

- `player.codex` updated on every `catch` and `battle` (enemy seen)
- `player.commits` updated by `meta.on_event()`
- `player.unlocks` updated by `persistence.check_unlocks()`
- All persisted via `persistence.save_player()` in run_over

Update `hub_records.lua` to show the commit count:
```lua
-- In sub-tab header:
local earned = 0
for _ in pairs(player.commits) do earned = earned + 1 end
engine.graphics.text("COMMITS (" .. earned .. "/" .. #ALL_COMMITS .. ")", ...)
```

---

## Lifetime Stats in Records

Add a lifetime stats section to hub_records (below the UNLOCKS sub-tab, or as a 4th sub-tab):

```lua
-- Sub-tab 4: STATS
SUB_TABS = {"CODEX", "COMMITS", "UNLOCKS", "STATS"}

function M._draw_stats(x, y, w, h)
    local lt = player.lifetime or {}
    local lines = {
        "Total Runs:       " .. (lt.runs     or 0),
        "Floors Reached:   " .. (lt.floors   or 0),
        "Critters Caught:  " .. (lt.catches  or 0),
        "Total Faints:     " .. (lt.faints   or 0),
        "Credits Earned:   " .. (lt.currency or 0) .. "g",
    }
    for i, line in ipairs(lines) do
        engine.graphics.text(line, x + 16, y + 12 + (i-1) * 24, {r=190, g=185, b=210, a=255}, 0)
    end
end
```

---

## Checklist

- [ ] `meta.lua` — all 13 commit conditions, `on_event()`, `label()`
- [ ] `ui/notify.lua` — toast notification queue for commit/unlock events
- [ ] Wire `meta.on_event("catch", ...)` in battle engine on catch
- [ ] Wire `meta.on_event("battle_win", ...)` in battle_screen on win
- [ ] Wire `meta.on_event("run_wipe"/"run_complete", ...)` in run_over
- [ ] Wire `meta.on_event("evolution", ...)` in critter/stats.lua
- [ ] Wire `meta.on_event("floor_clear", ...)` in run_over
- [ ] Wire `meta.on_event("party_change", ...)` in hub on party update
- [ ] Heisenbug 4th starter: appears in starter_select when `secret_starter` unlocked
- [ ] 4th party slot: live in hub_party.lua and party_select.lua
- [ ] Biome selection: `biome_select` scene, routed from hub when `biome_select` unlocked
- [ ] `hub_records.lua` updated: earned commit count, lifetime stats tab
- [ ] Test: earn `feat: add critter` on first catch → appears in Records → persists across restart
- [ ] Test: `release: v1.0` fires on floor 15 clear → toast shows
- [ ] Test: `feat!: breaking change` fires on first wipe → persists
- [ ] Test: clear floor 5 → biome selection available next run
- [ ] Test: catch all 7 types → 4th slot unlocked → hub_party shows 4th slot active
- [ ] Test: fill codex → Heisenbug appears in starter_select on new game
- [ ] Test: Records tab codex shows accurately after multi-run session
