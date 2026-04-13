# Phase 9.5 — Hub (4 Tabs)

## Goal
The hub is the persistent home screen between runs. Four tabs: Party (equip critters for next run), Roster (browse all caught critters), Items (manage consumable inventory), Records (codex + achievements + unlocks). All state persists but is loaded from memory here — persistence layer comes in 9.7.

## Verify
- Hub loads correctly after run_over and at game start
- All 4 tabs navigate cleanly with number keys
- Party tab: select critters, equip move discs + hold items
- Roster tab: browse all caught critters, view stats/moves/scars
- Items tab: view inventory sorted by category
- Records tab: codex shows discovered/caught, commits list, unlocks tracker

---

## Files to Create/Modify

```
games/codecritter/
├── ui/hub.lua              -- 4-tab hub scene (master controller)
├── ui/party_select.lua     -- Party + equip sub-panel (used pre-run too)
└── ui/widgets.lua          -- EXTEND: critter_card(), equip_slot(), codex_entry()
```

---

## Hub Layout

```
640×360 total
┌─────────────────────────────────────────────────────────────┐
│  CODECRITTER                    [1]Party [2]Roster [3]Items [4]Records  │  ← 32px header
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    TAB CONTENT                              │  ← 296px
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  [↑↓←→] Navigate  [Z] Select/Equip  [X] Back  [R] Start Run│  ← 32px footer
└─────────────────────────────────────────────────────────────┘
```

---

## `ui/hub.lua`

```lua
-- ui/hub.lua
-- 4-tab hub: Party, Roster, Items, Records

local music = require("audio.music")

local W, H = 640, 360
local HEADER_H = 32
local FOOTER_H = 32
local CONTENT_Y = HEADER_H
local CONTENT_H = H - HEADER_H - FOOTER_H

local TABS = {
    {id="party",   label="Party",   key="1"},
    {id="roster",  label="Roster",  key="2"},
    {id="items",   label="Items",   key="3"},
    {id="records", label="Records", key="4"},
}

-- Sub-tab modules loaded lazily
local tab_modules = {}

local S = {}

function S.load(data)
    data = data or {}
    S.player   = data.player   -- persistent player state (roster, inventory, unlocks, achievements)
    S.tab      = data.tab or "party"
    S.run_result = data.run_result  -- passed in from run_over if applicable

    -- Lazy-load tab modules
    tab_modules.party   = require("ui.hub_party")
    tab_modules.roster  = require("ui.hub_roster")
    tab_modules.items   = require("ui.hub_items")
    tab_modules.records = require("ui.hub_records")

    S._switch_tab(S.tab)
    music.play("hub")
end

function S._switch_tab(id)
    -- Unload current tab
    if S.tab and tab_modules[S.tab] and tab_modules[S.tab].unload then
        tab_modules[S.tab].unload()
    end
    S.tab = id
    -- Load new tab
    local mod = tab_modules[id]
    if mod and mod.load then
        mod.load({player=S.player, run_result=S.run_result})
    end
end

function S.update(dt)
    local mod = tab_modules[S.tab]
    if mod and mod.update then mod.update(dt) end
end

function S.draw()
    engine.graphics.rect(0, 0, W, H, {r=12, g=10, b=22, a=255}, 0)

    -- Header
    engine.graphics.rect(0, 0, W, HEADER_H, {r=24, g=20, b=40, a=255}, 0)
    engine.graphics.text("CODECRITTER", 16, 9, {r=220, g=200, b=255, a=255}, 0)

    -- Tab buttons
    local tx = 220
    for _, tab in ipairs(TABS) do
        local active = tab.id == S.tab
        local bg = active and {r=70, g=55, b=110, a=255} or {r=30, g=25, b=50, a=255}
        engine.graphics.rect(tx, 4, 88, 24, bg, 0)
        local label_col = active and {r=240, g=230, b=255, a=255} or {r=160, g=150, b=180, a=255}
        engine.graphics.text("[" .. tab.key .. "] " .. tab.label, tx + 6, 10, label_col, 0)
        tx = tx + 96
    end

    -- Content area
    local mod = tab_modules[S.tab]
    if mod and mod.draw then
        mod.draw(0, CONTENT_Y, W, CONTENT_H)
    end

    -- Footer
    engine.graphics.rect(0, H - FOOTER_H, W, FOOTER_H, {r=18, g=14, b=32, a=255}, 0)
    local hints = "[↑↓] Navigate  [Z] Select  [X] Back  [R] Start Run"
    engine.graphics.text(hints, 16, H - FOOTER_H + 10, {r=120, g=110, b=140, a=255}, 0)
end

function S.on_key(key)
    -- Tab switch shortcuts
    for _, tab in ipairs(TABS) do
        if key == tab.key then
            S._switch_tab(tab.id)
            return
        end
    end
    -- Start run
    if key == "r" then
        S._start_run()
        return
    end
    -- Delegate to active tab
    local mod = tab_modules[S.tab]
    if mod and mod.on_key then mod.on_key(key) end
end

function S._start_run()
    -- Validate: need at least 1 party critter
    if not S.player or not S.player.party or #S.player.party == 0 then
        -- Flash message — handled in party tab
        return
    end
    music.stop()
    local run = require("dungeon.run").new(S.player)
    engine.scene.switch("party_select", {
        player = S.player,
        on_confirm = function(party, inventory)
            run.party = party
            run.inventory = inventory
            engine.scene.switch("dungeon", {run=run, floor=1})
        end,
    })
end

function S.unload()
    local mod = tab_modules[S.tab]
    if mod and mod.unload then mod.unload() end
end

return S
```

---

## `ui/hub_party.lua`

```lua
-- ui/hub_party.lua
-- Party tab: view party slots, equip move discs and hold items

local widgets = require("ui.widgets")

local M = {}
local player, run_result
local cursor_slot, cursor_equip  -- slot=1-4, equip=nil|"disc"|"hold"
local equip_menu = nil  -- when picking from inventory

function M.load(data)
    player     = data.player
    run_result = data.run_result
    cursor_slot  = 1
    cursor_equip = nil
end

function M.draw(x, y, w, h)
    -- 4 party slots, each ~70px tall, stacked vertically with left panel
    -- Right side: detail panel for selected critter
    local SLOT_H = 60
    local LIST_W = 200
    local DETAIL_X = x + LIST_W + 16
    local DETAIL_W = w - LIST_W - 24

    -- Party slots list
    for i = 1, 4 do
        local critter = player.party[i]
        local sy = y + 8 + (i-1) * (SLOT_H + 6)
        local selected = (i == cursor_slot)

        -- Slot background
        local bg = selected and {r=50, g=42, b=80, a=255} or {r=22, g=18, b=38, a=255}
        engine.graphics.rect(x + 4, sy, LIST_W - 8, SLOT_H, bg, 0)

        if critter then
            widgets.critter_mini(critter, x + 8, sy + 4, selected)
        else
            local label = i <= 3 and "[ Empty ]" or "[ Locked ]"
            local col = {r=70, g=60, b=90, a=255}
            engine.graphics.text(label, x + 50, sy + 22, col, 0)
        end
    end

    -- Detail panel for selected critter
    local selected_critter = player.party[cursor_slot]
    if selected_critter then
        widgets.critter_detail(selected_critter, DETAIL_X, y + 8, DETAIL_W, h - 16)
    else
        widgets.panel(DETAIL_X, y + 8, DETAIL_W, h - 16, 0)
        engine.graphics.text("No critter in this slot.", DETAIL_X + 16, y + 40, {r=100, g=90, b=120, a=255}, 0)
    end

    -- Equip menu overlay
    if equip_menu then
        M._draw_equip_menu(x, y, w, h)
    end
end

function M._draw_equip_menu(x, y, w, h)
    -- Semi-transparent overlay
    engine.graphics.rect(x, y, w, h, {r=0, g=0, b=0, a=160}, 2)  -- layer 2
    widgets.panel(x + 80, y + 40, w - 160, h - 80, 2)
    engine.graphics.text("Select " .. equip_menu.type .. ":", x + 96, y + 52, {r=200, g=190, b=220, a=255}, 2)

    local items = equip_menu.items
    for i, item in ipairs(items) do
        local sel = (i == equip_menu.cursor)
        local iy = y + 68 + (i-1) * 18
        local col = sel and {r=240, g=230, b=255, a=255} or {r=180, g=170, b=200, a=255}
        local prefix = sel and "> " or "  "
        engine.graphics.text(prefix .. item.label, x + 96, iy, col, 2)
    end
    engine.graphics.text("[Z] Equip  [X] Cancel", x + 96, y + h - 60, {r=120, g=110, b=140, a=255}, 2)
end

function M.on_key(key)
    if equip_menu then
        M._equip_menu_key(key)
        return
    end

    if key == "up" then
        cursor_slot = math.max(1, cursor_slot - 1)
    elseif key == "down" then
        cursor_slot = math.min(#player.party, cursor_slot + 1)
    elseif key == "z" then
        -- Open equip options for selected critter
        local critter = player.party[cursor_slot]
        if critter then
            M._open_equip_choice(critter)
        end
    elseif key == "x" then
        cursor_equip = nil
    end
end

function M._open_equip_choice(critter)
    -- Sub-menu: equip move disc, equip hold item, remove disc, remove hold, swap slot
    equip_menu = {
        critter = critter,
        type = "action",
        cursor = 1,
        items = {
            {label="Equip Move Disc",   action="disc"},
            {label="Equip Hold Item",   action="hold"},
            {label="Remove Move Disc",  action="remove_disc"},
            {label="Remove Hold Item",  action="remove_hold"},
        },
    }
end

function M._equip_menu_key(key)
    if key == "up" then
        equip_menu.cursor = math.max(1, equip_menu.cursor - 1)
    elseif key == "down" then
        equip_menu.cursor = math.min(#equip_menu.items, equip_menu.cursor + 1)
    elseif key == "z" then
        local action = equip_menu.items[equip_menu.cursor].action
        local critter = equip_menu.critter
        if action == "disc" then
            -- Open disc picker from inventory
            local discs = {}
            for _, id in ipairs(player.inventory.disc or {}) do
                table.insert(discs, {label=id, id=id})
            end
            if #discs == 0 then
                equip_menu = nil  -- nothing to equip
            else
                equip_menu = {critter=critter, type="disc", cursor=1, items=discs}
            end
        elseif action == "hold" then
            local holds = {}
            for _, id in ipairs(player.inventory.hold or {}) do
                table.insert(holds, {label=id, id=id})
            end
            if #holds == 0 then
                equip_menu = nil
            else
                equip_menu = {critter=critter, type="hold", cursor=1, items=holds}
            end
        elseif action == "remove_disc" then
            if critter.disc then
                table.insert(player.inventory.disc, critter.disc)
                critter.disc = nil
            end
            equip_menu = nil
        elseif action == "remove_hold" then
            if critter.hold_item then
                table.insert(player.inventory.hold, critter.hold_item)
                critter.hold_item = nil
            end
            equip_menu = nil
        else
            -- Actual equip
            local picked = equip_menu.items[equip_menu.cursor]
            if equip_menu.type == "disc" then
                -- Remove from inventory, put old disc back
                if critter.disc then
                    table.insert(player.inventory.disc, critter.disc)
                end
                critter.disc = picked.id
                -- Remove from inventory list
                for i, id in ipairs(player.inventory.disc) do
                    if id == picked.id then
                        table.remove(player.inventory.disc, i)
                        break
                    end
                end
            elseif equip_menu.type == "hold" then
                if critter.hold_item then
                    table.insert(player.inventory.hold, critter.hold_item)
                end
                critter.hold_item = picked.id
                for i, id in ipairs(player.inventory.hold) do
                    if id == picked.id then
                        table.remove(player.inventory.hold, i)
                        break
                    end
                end
            end
            equip_menu = nil
        end
    elseif key == "x" then
        equip_menu = nil
    end
end

function M.unload() end

return M
```

---

## `ui/hub_roster.lua`

```lua
-- ui/hub_roster.lua
-- Roster tab: all caught critters, view stats/moves/scars

local widgets = require("ui.widgets")

local M = {}
local player
local cursor, scroll
local view_mode  -- nil | "detail"

function M.load(data)
    player    = data.player
    cursor    = 1
    scroll    = 0
    view_mode = nil
end

local VISIBLE_ROWS = 9
local ROW_H = 28

function M.draw(x, y, w, h)
    local LIST_W = 220
    local DETAIL_X = x + LIST_W + 12
    local DETAIL_W = w - LIST_W - 20

    local roster = player.roster or {}
    local visible_start = scroll + 1

    -- Roster list
    for i = 1, VISIBLE_ROWS do
        local idx = visible_start + i - 1
        if idx > #roster then break end
        local critter = roster[idx]
        local sy = y + 4 + (i-1) * ROW_H
        local selected = (idx == cursor)

        local bg = selected and {r=48, g=40, b=78, a=255} or {r=20, g=16, b=34, a=255}
        engine.graphics.rect(x + 4, sy, LIST_W - 8, ROW_H - 2, bg, 0)

        -- Type badge + name + level
        widgets.type_badge_small(critter.type, x + 8, sy + 5)
        local name_col = critter.hp <= 0 and {r=120, g=80, b=80, a=255} or {r=220, g=210, b=240, a=255}
        engine.graphics.text(critter.name .. " Lv" .. critter.level, x + 32, sy + 7, name_col, 0)

        -- Cooldown indicator
        if (critter.cooldown_runs or 0) > 0 then
            engine.graphics.text("zzz", x + LIST_W - 30, sy + 7, {r=180, g=120, b=80, a=255}, 0)
        end
    end

    -- Scroll indicators
    if scroll > 0 then
        engine.graphics.text("▲", x + LIST_W/2 - 4, y + 2, {r=160, g=150, b=180, a=255}, 0)
    end
    if scroll + VISIBLE_ROWS < #roster then
        engine.graphics.text("▼", x + LIST_W/2 - 4, y + h - 16, {r=160, g=150, b=180, a=255}, 0)
    end

    -- Detail panel
    local critter = roster[cursor]
    if critter then
        widgets.critter_detail(critter, DETAIL_X, y + 4, DETAIL_W, h - 8)
    end
end

function M.on_key(key)
    local roster = player.roster or {}
    if key == "up" then
        cursor = math.max(1, cursor - 1)
        if cursor < scroll + 1 then scroll = cursor - 1 end
    elseif key == "down" then
        cursor = math.min(#roster, cursor + 1)
        if cursor > scroll + VISIBLE_ROWS then scroll = cursor - VISIBLE_ROWS end
    end
end

function M.unload() end

return M
```

---

## `ui/hub_items.lua`

```lua
-- ui/hub_items.lua
-- Items tab: inventory by category

local M = {}
local player, cursor, selected_cat

local CATEGORIES = {
    {key="healing", label="Healing Items"},
    {key="catch",   label="Catch Tools"},
    {key="disc",    label="Move Discs"},
    {key="hold",    label="Hold Items"},
}

function M.load(data)
    player       = data.player
    cursor       = 1
    selected_cat = 1
end

function M.draw(x, y, w, h)
    local CAT_W = 160
    local ITEM_X = x + CAT_W + 12
    local ITEM_W = w - CAT_W - 20

    -- Category list on left
    for i, cat in ipairs(CATEGORIES) do
        local sy = y + 8 + (i-1) * 36
        local selected = (i == selected_cat)
        local bg = selected and {r=50, g=42, b=80, a=255} or {r=20, g=16, b=34, a=255}
        engine.graphics.rect(x + 4, sy, CAT_W - 8, 32, bg, 0)
        local items_in_cat = player.inventory[cat.key] or {}
        local col = selected and {r=220, g=210, b=240, a=255} or {r=150, g=140, b=170, a=255}
        engine.graphics.text(cat.label, x + 10, sy + 8, col, 0)
        engine.graphics.text("x" .. #items_in_cat, x + CAT_W - 24, sy + 8, col, 0)
    end

    -- Item list on right
    local cat = CATEGORIES[selected_cat]
    local items = player.inventory[cat.key] or {}
    if #items == 0 then
        engine.graphics.text("None in inventory.", ITEM_X, y + 16, {r=100, g=90, b=120, a=255}, 0)
    else
        for i, item_id in ipairs(items) do
            local iy = y + 8 + (i-1) * 20
            local col = (i == cursor) and {r=240, g=230, b=255, a=255} or {r=190, g=180, b=210, a=255}
            engine.graphics.text((i == cursor and "> " or "  ") .. item_id, ITEM_X, iy, col, 0)
        end
    end
end

function M.on_key(key)
    if key == "left" or key == "right" then
        if key == "left" then selected_cat = math.max(1, selected_cat - 1)
        else selected_cat = math.min(#CATEGORIES, selected_cat + 1) end
        cursor = 1
    elseif key == "up" then
        cursor = math.max(1, cursor - 1)
    elseif key == "down" then
        local items = player.inventory[CATEGORIES[selected_cat].key] or {}
        cursor = math.min(#items, cursor + 1)
    end
end

function M.unload() end

return M
```

---

## `ui/hub_records.lua`

```lua
-- ui/hub_records.lua
-- Records tab: codex (species discovered/caught), commits (achievements), unlocks

local species_data = require("data.species")
local M = {}
local player, sub_tab, cursor

local SUB_TABS = {"CODEX", "COMMITS", "UNLOCKS"}

function M.load(data)
    player  = data.player
    sub_tab = 1
    cursor  = 1
end

function M.draw(x, y, w, h)
    -- Sub-tab bar
    local tx = x + 8
    for i, label in ipairs(SUB_TABS) do
        local active = (i == sub_tab)
        local bg = active and {r=60, g=50, b=90, a=255} or {r=25, g=20, b=42, a=255}
        engine.graphics.rect(tx, y + 4, 90, 20, bg, 0)
        local col = active and {r=230, g=220, b=255, a=255} or {r=140, g=130, b=160, a=255}
        engine.graphics.text(label, tx + 10, y + 9, col, 0)
        tx = tx + 98
    end

    local cy = y + 30
    if sub_tab == 1 then
        M._draw_codex(x, cy, w, h - 30)
    elseif sub_tab == 2 then
        M._draw_commits(x, cy, w, h - 30)
    elseif sub_tab == 3 then
        M._draw_unlocks(x, cy, w, h - 30)
    end
end

function M._draw_codex(x, y, w, h)
    -- Grid: species entries, 3 columns
    -- Each entry: small type badge + name + caught indicator
    local COL_W = math.floor(w / 3)
    local ROW_H = 22
    local per_col = math.floor(h / ROW_H)

    local codex = player.codex or {}  -- {species_id = {seen=bool, caught=bool}}

    for i, sp in ipairs(species_data) do
        local col_idx = math.floor((i-1) / per_col)
        local row_idx = (i-1) % per_col
        local ex = x + 8 + col_idx * COL_W
        local ey = y + 4 + row_idx * ROW_H
        local entry = codex[sp.id] or {}

        if entry.caught then
            engine.graphics.text("● " .. sp.name, ex, ey, {r=180, g=240, b=180, a=255}, 0)
        elseif entry.seen then
            engine.graphics.text("○ " .. sp.name, ex, ey, {r=160, g=150, b=190, a=255}, 0)
        else
            engine.graphics.text("? " .. string.rep("?", #sp.name), ex, ey, {r=70, g=65, b=85, a=255}, 0)
        end
    end

    -- Summary
    local caught_count = 0
    local seen_count   = 0
    for _, entry in pairs(codex) do
        if entry.caught then caught_count = caught_count + 1
        elseif entry.seen then seen_count = seen_count + 1 end
    end
    local summary = string.format("Caught: %d / %d   Seen: %d", caught_count, #species_data, seen_count)
    engine.graphics.text(summary, x + 8, y + h - 20, {r=160, g=150, b=190, a=255}, 0)
end

-- Git-format commit achievements
local ALL_COMMITS = {
    {id="first_catch",  label='feat: add critter',            desc="First catch"},
    {id="edge_case",    label='fix: handle edge case',         desc="Win battle at <10% HP"},
    {id="hotfix_prod",  label='hotfix: prod is down',          desc="Win after first critter faints"},
    {id="release_v1",   label='release: v1.0',                 desc="Clear floor 15"},
    {id="breaking",     label='feat!: breaking change',        desc="First wipe"},
    {id="add_comments", label='docs: add comments',            desc="Fill the codex"},
    {id="pipeline",     label='ci: pipeline passes',           desc="Clear floor 15 with no faints"},
    {id="revert",       label='revert: this was a mistake',    desc="Catch a Legendary"},
    {id="perf",         label='perf: reduce allocations',      desc="Win battle without taking damage"},
    {id="test_coverage",label='test: add coverage',            desc="Use all 3 catch tool types in one run"},
    {id="chore",        label='chore: clean up globals',       desc="Catch all of a 3-stage evolution line"},
    {id="refactor",     label='refactor: extract method',      desc="Evolve a critter for the first time"},
    {id="merge_conflict",label='merge conflict resolved',       desc="Have 2 critters with scars in same party"},
}

function M._draw_commits(x, y, w, h)
    local commits = player.commits or {}
    for i, commit in ipairs(ALL_COMMITS) do
        local cy = y + 4 + (i-1) * 20
        local done = commits[commit.id]
        local label_col = done and {r=100, g=200, b=130, a=255} or {r=90, g=85, b=105, a=255}
        local prefix = done and "✓ " or "  "
        engine.graphics.text(prefix .. commit.label, x + 8, cy, label_col, 0)
        engine.graphics.text(commit.desc, x + 340, cy, {r=120, g=115, b=135, a=255}, 0)
    end
end

local ALL_UNLOCKS = {
    {id="biome_select",  label="Biome Selection",   condition="Clear floor 5"},
    {id="hard_mode",     label="Hard Mode",          condition="Clear floor 10"},
    {id="depth_mode",    label="Depth Mode (16+)",   condition="Clear floor 15"},
    {id="fourth_slot",   label="4th Party Slot",     condition="Catch one of each starter type"},
    {id="secret_starter",label="Secret Starter",     condition="Fill the codex"},
    {id="root_encounter",label="Root (Legendary)",   condition="Catch all LEGACY species"},
    {id="zero_day",      label="Zero Day (Legendary)",condition="Clear floor 15 with zero catches"},
    {id="linus",         label="Linus (Legendary)",  condition="Fill codex completely"},
}

function M._draw_unlocks(x, y, w, h)
    local unlocks = player.unlocks or {}
    for i, unlock in ipairs(ALL_UNLOCKS) do
        local uy = y + 8 + (i-1) * 28
        local done = unlocks[unlock.id]
        local bg = done and {r=30, g=50, b=35, a=255} or {r=22, g=18, b=36, a=255}
        engine.graphics.rect(x + 8, uy, w - 16, 24, bg, 0)
        local col = done and {r=120, g=220, b=150, a=255} or {r=150, g=140, b=170, a=255}
        engine.graphics.text((done and "[UNLOCKED] " or "[LOCKED]   ") .. unlock.label, x + 14, uy + 5, col, 0)
        engine.graphics.text(unlock.condition, x + 340, uy + 5, {r=110, g=105, b=125, a=255}, 0)
    end
end

function M.on_key(key)
    if key == "left" then
        sub_tab = math.max(1, sub_tab - 1)
    elseif key == "right" then
        sub_tab = math.min(#SUB_TABS, sub_tab + 1)
    end
end

function M.unload() end

return M
```

---

## `ui/widgets.lua` — New Functions to Add

```lua
-- Add to existing widgets.lua:

-- Compact critter row for party/roster list
function widgets.critter_mini(critter, x, y, selected)
    local name_col = selected and {r=240, g=230, b=255, a=255} or {r=200, g=195, b=220, a=255}
    widgets.type_badge_small(critter.type, x, y + 4)
    engine.graphics.text(critter.name, x + 26, y + 2, name_col, 0)
    engine.graphics.text("Lv" .. critter.level, x + 26, y + 16, {r=150, g=145, b=170, a=255}, 0)
    -- HP bar (mini, 60px wide)
    widgets.hp_bar(critter.hp, critter.max_hp, x + 100, y + 18, 60, 6, 0)
end

-- Full critter detail panel
function widgets.critter_detail(critter, x, y, w, h)
    widgets.panel(x, y, w, h, 0)
    local px, py = x + 10, y + 10

    -- Name + type + archetype
    engine.graphics.text(critter.name .. "  Lv" .. critter.level, px, py, {r=230, g=220, b=250, a=255}, 0)
    widgets.type_badge(critter.type, px, py + 18)
    widgets.archetype_badge(critter.archetype, px + 70, py + 18)
    py = py + 42

    -- HP bar
    engine.graphics.text("HP", px, py, {r=180, g=175, b=195, a=255}, 0)
    widgets.hp_bar(critter.hp, critter.max_hp, px + 24, py + 2, w - 44, 10, 0)
    engine.graphics.text(critter.hp .. "/" .. critter.max_hp, px + 24, py + 14, {r=160, g=155, b=175, a=255}, 0)
    py = py + 30

    -- Stats
    local stat_names = {"logic", "resolve", "speed"}
    for _, stat in ipairs(stat_names) do
        local val = critter.stats[stat]
        engine.graphics.text(stat:upper() .. ": " .. val, px, py, {r=180, g=175, b=200, a=255}, 0)
        py = py + 16
    end
    py = py + 4

    -- Moves
    engine.graphics.text("Moves:", px, py, {r=160, g=155, b=180, a=255}, 0)
    py = py + 16
    for i, move in ipairs(critter.moves or {}) do
        engine.graphics.text("  " .. move.name, px, py, {r=200, g=195, b=218, a=255}, 0)
        py = py + 14
    end
    py = py + 4

    -- Equipped items
    if critter.disc then
        engine.graphics.text("Disc: " .. critter.disc, px, py, {r=130, g=180, b=230, a=255}, 0)
        py = py + 14
    end
    if critter.hold_item then
        engine.graphics.text("Hold: " .. critter.hold_item, px, py, {r=200, g=160, b=100, a=255}, 0)
        py = py + 14
    end

    -- Scars
    if critter.scars and #critter.scars > 0 then
        py = py + 4
        engine.graphics.text("Scars:", px, py, {r=180, g=80, b=80, a=255}, 0)
        py = py + 16
        for _, scar in ipairs(critter.scars) do
            engine.graphics.text("  -" .. scar.stat .. " " .. scar.amount, px, py, {r=160, g=70, b=70, a=255}, 0)
            py = py + 14
        end
    end

    -- Cooldown
    if (critter.cooldown_runs or 0) > 0 then
        engine.graphics.text("On cooldown: unavailable this run", px, py + 4, {r=180, g=120, b=60, a=255}, 0)
    end
end

-- Small type badge (inline, 20px wide)
function widgets.type_badge_small(type_name, x, y)
    local type_data = require("data.types")
    local col = type_data.colors[type_name:upper()] or {r=100, g=100, b=120, a=255}
    engine.graphics.rect(x, y, 20, 14, col, 0)
    engine.graphics.text(type_name:sub(1,2):upper(), x + 2, y + 2, {r=240, g=235, b=250, a=255}, 0)
end
```

---

## Checklist

- [ ] `ui/hub.lua` — master controller, tab switching, start run button
- [ ] `ui/hub_party.lua` — party slots, equip disc/hold item sub-menu
- [ ] `ui/hub_roster.lua` — roster list + critter detail panel
- [ ] `ui/hub_items.lua` — inventory by category
- [ ] `ui/hub_records.lua` — codex (seen/caught grid), commits list, unlocks list
- [ ] Extend `ui/widgets.lua` — `critter_mini()`, `critter_detail()`, `type_badge_small()`
- [ ] Register `hub` scene in `main.lua`
- [ ] Test: navigate all 4 tabs, check correct data displayed
- [ ] Test: equip/unequip disc and hold item, verify inventory updates
- [ ] Test: roster shows caught critters with scars/cooldowns
- [ ] Test: codex shows seen/caught/unknown correctly
- [ ] Test: commits list shows earned achievements
