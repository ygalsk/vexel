# Phase 9.4 — Shop + Between Floors

## Goal
After each boss floor (5, 10, 15), the player enters a locked shop room. Full party heal is automatic on entry. Player can buy items, view inventory, and choose to extract or continue. This phase also covers the floor transition moment (stairs → loading animation → new floor).

## Verify
- After beating a boss, stairs lead to shop room
- Full party heal fires automatically
- Shop displays correctly scaled items with floor-biased inventory
- Buy/cancel flow works cleanly
- Extract ends the run with a "voluntary extract" flag
- Continue button starts the next floor

---

## Files to Create/Modify

```
games/codecritter/
├── dungeon/shop.lua           -- Shop inventory generation + buy logic
├── ui/shop_screen.lua         -- Shop scene
└── ui/run_over.lua            -- Run summary (voluntary extract + wipe)
```

---

## `dungeon/shop.lua`

```lua
-- dungeon/shop.lua
-- Shop generation, floor-biased inventory, pricing

local items = require("data.items")
local M = {}

-- Pricing formula: floor_scaled, biome bonus applied to shop_bias
local BASE_PRICES = {
    heal_small = 30,
    heal_large = 70,
    disc_i = 60,
    disc_ii = 100,
    disc_iii = 160,
    hold_item = 120,
    catch_basic = 40,
    catch_stealth = 80,
    catch_null = 140,
}

-- Generate a shop inventory (6 slots)
-- biome_bias: table of {item_category = weight_multiplier}
-- floor: current floor number (1-15)
function M.generate(floor, biome_bias)
    local shop = {
        floor = floor,
        items = {},   -- list of {item_id, price, sold=false}
    }
    biome_bias = biome_bias or {}

    -- Always: 2 healing slots
    table.insert(shop.items, {
        id = "heal_large",
        label = "Full Restore",
        desc = "Restores 100% HP to one critter",
        price = math.floor(BASE_PRICES.heal_large * (1 + floor * 0.05)),
        category = "healing",
        sold = false,
    })
    table.insert(shop.items, {
        id = "heal_small",
        label = "Quick Fix",
        desc = "Restores 40% HP to one critter",
        price = math.floor(BASE_PRICES.heal_small * (1 + floor * 0.05)),
        category = "healing",
        sold = false,
    })

    -- 1 catch tool slot (floor-scaled quality)
    local catch_id = "catch_basic"
    if floor >= 10 then catch_id = "catch_null"
    elseif floor >= 6 then catch_id = "catch_stealth" end
    -- biome bias can upgrade catch tools
    if biome_bias.catch_upgrade and math.random() < 0.4 then
        if catch_id == "catch_basic" then catch_id = "catch_stealth"
        elseif catch_id == "catch_stealth" then catch_id = "catch_null" end
    end
    table.insert(shop.items, {
        id = catch_id,
        label = items.combat[catch_id] and items.combat[catch_id].name or catch_id,
        desc = items.combat[catch_id] and items.combat[catch_id].desc or "",
        price = math.floor(BASE_PRICES[catch_id] * (1 + floor * 0.05)),
        category = "catch",
        sold = false,
    })

    -- 1-2 move disc slots (biome-biased type)
    local disc_tier = floor <= 5 and "disc_i" or (floor <= 10 and "disc_ii" or "disc_iii")
    local disc_types = {"debug", "chaos", "patience", "wisdom", "snark", "vibe", "legacy"}
    -- biome bias: increase probability of biome's native type
    local disc_type = disc_types[math.random(#disc_types)]
    if biome_bias.type and math.random() < 0.5 then
        disc_type = biome_bias.type:lower()
    end
    table.insert(shop.items, {
        id = disc_tier .. "_" .. disc_type,
        label = disc_type:upper() .. " Disc " .. (floor <= 5 and "I" or (floor <= 10 and "II" or "III")),
        desc = "Off-type move. Power " .. (floor <= 5 and "50/95%" or (floor <= 10 and "70/85%" or "90/75%")),
        price = math.floor(BASE_PRICES[disc_tier] * (1 + floor * 0.05)),
        category = "disc",
        sold = false,
    })

    -- 1 hold item slot (rare slot)
    if math.random() < 0.6 then
        local hold_pool = {}
        for id, item in pairs(items.hold) do
            table.insert(hold_pool, {id=id, item=item})
        end
        local pick = hold_pool[math.random(#hold_pool)]
        table.insert(shop.items, {
            id = pick.id,
            label = pick.item.name,
            desc = pick.item.desc,
            price = math.floor(BASE_PRICES.hold_item * (1 + floor * 0.08)),
            category = "hold",
            sold = false,
        })
    end

    return shop
end

-- Attempt purchase; returns true if successful
function M.buy(shop, slot_idx, run)
    local slot = shop.items[slot_idx]
    if not slot or slot.sold then return false, "Already sold" end
    if run.currency < slot.price then return false, "Not enough credits" end
    run.currency = run.currency - slot.price
    slot.sold = true
    run:add_item(slot.id, slot.category)
    return true
end

return M
```

---

## `ui/shop_screen.lua`

```lua
-- ui/shop_screen.lua
-- Post-boss shop scene: auto-heal, buy items, extract or continue

local shop_gen = require("dungeon.shop")
local widgets  = require("ui.widgets")
local music    = require("audio.music")

local W, H = 640, 360
local PANEL_X, PANEL_Y = 80, 40
local PANEL_W, PANEL_H = 480, 280

local S = {}

-- Entry point: called with {run=run_state, floor=N, biome=biome_data, on_continue=fn, on_extract=fn}
function S.load(data)
    S.run    = data.run
    S.floor  = data.floor
    S.biome  = data.biome
    S.on_continue = data.on_continue
    S.on_extract  = data.on_extract

    -- Auto-heal entire party on shop entry
    for _, critter in ipairs(S.run.party) do
        critter.hp = critter.max_hp
    end
    S.healed = true  -- show "Party fully healed!" toast

    -- Generate shop inventory
    S.shop = shop_gen.generate(S.floor, S.biome and S.biome.shop_bias or {})

    S.cursor    = 1       -- selected shop slot
    S.feedback  = nil     -- buy result message
    S.feedback_t = 0
    S.tab       = "shop"  -- "shop" | "inventory"

    music.play("shop")
end

function S.update(dt)
    if S.feedback_t > 0 then
        S.feedback_t = S.feedback_t - dt
        if S.feedback_t <= 0 then S.feedback = nil end
    end
end

function S.draw()
    -- Background
    engine.graphics.rect(0, 0, W, H, {r=15, g=12, b=28, a=255}, 0)

    -- Title bar
    engine.graphics.rect(0, 0, W, 32, {r=30, g=24, b=50, a=255}, 0)
    engine.graphics.text("SHOP  —  Floor " .. S.floor .. "/15", 20, 8, {r=200, g=170, b=255, a=255}, 0)

    -- Currency
    local gold_str = string.format("Credits: %dg", S.run.currency)
    engine.graphics.text(gold_str, W - 160, 8, {r=255, g=220, b=80, a=255}, 0)

    -- Heal toast
    if S.healed then
        engine.graphics.text("Party fully restored!", W/2 - 80, 36, {r=100, g=255, b=140, a=255}, 0)
    end

    -- Tab bar
    local tabs = {"SHOP", "INVENTORY"}
    local tab_x = PANEL_X
    for i, label in ipairs(tabs) do
        local active = (i == 1 and S.tab == "shop") or (i == 2 and S.tab == "inventory")
        local bg = active and {r=60, g=50, b=90, a=255} or {r=30, g=25, b=50, a=255}
        engine.graphics.rect(tab_x, 48, 100, 20, bg, 0)
        engine.graphics.text(label, tab_x + 10, 52, {r=200, g=190, b=220, a=255}, 0)
        tab_x = tab_x + 110
    end

    -- Main panel
    widgets.panel(PANEL_X, 70, PANEL_W, PANEL_H, 0)

    if S.tab == "shop" then
        S._draw_shop()
    else
        S._draw_inventory()
    end

    -- Bottom bar: controls
    engine.graphics.rect(0, H - 30, W, 30, {r=20, g=16, b=36, a=255}, 0)
    engine.graphics.text(
        "[↑↓] Select  [Z/Enter] Buy  [TAB] Inventory  [X] Extract  [C] Continue",
        20, H - 22, {r=140, g=130, b=160, a=255}, 0
    )

    -- Feedback toast
    if S.feedback then
        local col = S.feedback.ok and {r=100, g=255, b=140, a=255} or {r=255, g=100, b=100, a=255}
        engine.graphics.text(S.feedback.msg, PANEL_X + 10, PANEL_Y + PANEL_H + 10, col, 0)
    end
end

function S._draw_shop()
    local items = S.shop.items
    for i, slot in ipairs(items) do
        local y = 76 + (i - 1) * 42
        local selected = (i == S.cursor)
        local sold = slot.sold
        local can_afford = S.run.currency >= slot.price

        -- Row highlight
        if selected then
            engine.graphics.rect(PANEL_X + 2, y, PANEL_W - 4, 40, {r=50, g=42, b=80, a=255}, 0)
        end

        -- Item label
        local label_col = sold and {r=80, g=70, b=90, a=255} or {r=220, g=210, b=240, a=255}
        engine.graphics.text((sold and "[SOLD] " or "") .. slot.label, PANEL_X + 12, y + 6, label_col, 0)

        -- Description
        local desc_col = {r=140, g=130, b=155, a=255}
        engine.graphics.text(slot.desc, PANEL_X + 12, y + 22, desc_col, 0)

        -- Price
        local price_col = sold and {r=80, g=70, b=90, a=255}
            or (can_afford and {r=255, g=220, b=80, a=255} or {r=180, g=80, b=80, a=255})
        engine.graphics.text(string.format("%dg", slot.price), PANEL_X + PANEL_W - 70, y + 14, price_col, 0)
    end
end

function S._draw_inventory()
    -- Simple categorized list of current run inventory
    local inv = S.run.inventory
    local y = 76
    local categories = {
        {key="healing", label="Healing"},
        {key="catch",   label="Catch Tools"},
        {key="disc",    label="Move Discs"},
        {key="hold",    label="Hold Items"},
    }
    for _, cat in ipairs(categories) do
        local items_in_cat = inv[cat.key] or {}
        if #items_in_cat > 0 then
            engine.graphics.text(cat.label .. ":", PANEL_X + 12, y, {r=180, g=160, b=220, a=255}, 0)
            y = y + 16
            for _, item_id in ipairs(items_in_cat) do
                engine.graphics.text("  " .. item_id, PANEL_X + 12, y, {r=200, g=195, b=215, a=255}, 0)
                y = y + 14
            end
            y = y + 6
        end
    end
    if y == 76 then
        engine.graphics.text("Inventory empty.", PANEL_X + 12, y, {r=120, g=110, b=130, a=255}, 0)
    end
end

function S.on_key(key)
    if key == "up" then
        S.cursor = math.max(1, S.cursor - 1)
    elseif key == "down" then
        S.cursor = math.min(#S.shop.items, S.cursor + 1)
    elseif key == "tab" then
        S.tab = S.tab == "shop" and "inventory" or "shop"
    elseif key == "z" or key == "return" then
        if S.tab == "shop" then
            local ok, msg = shop_gen.buy(S.shop, S.cursor, S.run)
            S.feedback = {ok=ok, msg = ok and ("Bought: " .. S.shop.items[S.cursor].label) or msg}
            S.feedback_t = 2.0
        end
    elseif key == "x" then
        -- Extract — end run voluntarily
        S._extract()
    elseif key == "c" then
        -- Continue to next floor
        S._continue()
    end
end

function S._extract()
    music.stop()
    S.run.extracted = true
    engine.scene.switch("run_over", {run = S.run})
end

function S._continue()
    music.stop()
    S.on_continue(S.run)
end

function S.unload() end

return S
```

---

## `ui/run_over.lua`

```lua
-- ui/run_over.lua
-- Run summary screen: voluntary extract, wipe, or floor-15 victory

local widgets = require("ui.widgets")
local music   = require("audio.music")

local W, H = 640, 360
local S = {}

function S.load(data)
    S.run = data.run

    -- Determine outcome
    if S.run.extracted then
        S.outcome = "extract"
        S.title   = "Run Over — Extracted"
        S.color   = {r=180, g=160, b=255, a=255}
        music.play("defeat")  -- bittersweet
    elseif S.run.floor > 15 then
        S.outcome = "victory"
        S.title   = "Run Complete!"
        S.color   = {r=255, g=220, b=80, a=255}
        music.play("victory")
    else
        S.outcome = "wipe"
        S.title   = "Wiped Out"
        S.color   = {r=255, g=80, b=80, a=255}
        music.play("defeat")
    end

    -- Build stat summary
    S.stats = {
        floors    = math.min(S.run.floor - 1, 15),
        catches   = #S.run.caught,
        currency  = S.run.currency,
        scars     = S._count_scars(S.run),
        faints    = S.run.total_faints or 0,
    }

    -- Apply post-run effects: cooldowns for fainted critters
    S._apply_post_run(S.run)

    S.anim_t = 0
    S.ready  = false
end

function S._count_scars(run)
    local n = 0
    for _, critter in ipairs(run.party) do
        n = n + #(critter.scars or {})
    end
    return n
end

function S._apply_post_run(run)
    -- Critters that fainted get a 1-run cooldown
    for _, critter in ipairs(run.party) do
        if critter.hp <= 0 then
            critter.cooldown_runs = (critter.cooldown_runs or 0) + 1
        end
    end
end

function S.update(dt)
    S.anim_t = S.anim_t + dt
    if S.anim_t > 1.5 then S.ready = true end
end

function S.draw()
    engine.graphics.rect(0, 0, W, H, {r=10, g=8, b=20, a=255}, 0)

    -- Outcome title (slides in)
    local title_y = math.max(20, 80 - S.anim_t * 60)
    engine.graphics.text(S.title, W/2 - #S.title * 4, title_y, S.color, 0)

    -- Stat panel
    local py = 90
    widgets.panel(120, py, 400, 180, 0)

    local stats_lines = {
        string.format("Floors Reached:   %d / 15",   S.stats.floors),
        string.format("Critters Caught:  %d",         S.stats.catches),
        string.format("Credits Earned:   %dg",        S.stats.currency),
        string.format("Total Faints:     %d",         S.stats.faints),
        string.format("Scars Applied:    %d",         S.stats.scars),
    }
    for i, line in ipairs(stats_lines) do
        engine.graphics.text(line, 136, py + 14 + (i-1)*26, {r=200, g=195, b=215, a=255}, 0)
    end

    -- Wipe: list critters that now have cooldown
    if S.outcome == "wipe" then
        local cy = py + 190
        engine.graphics.text("Critters on cooldown (unavailable next run):", 120, cy, {r=200, g=100, b=100, a=255}, 0)
        cy = cy + 16
        for _, critter in ipairs(S.run.party) do
            if critter.hp <= 0 then
                engine.graphics.text("  " .. critter.name, 120, cy, {r=170, g=80, b=80, a=255}, 0)
                cy = cy + 14
            end
        end
    end

    -- New scars
    if S.stats.scars > 0 then
        local sy = S.outcome == "wipe" and 310 or py + 200
        engine.graphics.text("New scars recorded. Check Roster for stat losses.", 120, sy, {r=180, g=130, b=80, a=255}, 0)
    end

    -- Continue prompt
    if S.ready then
        engine.graphics.text("[Z/Enter] Return to Hub", W/2 - 90, H - 36, {r=160, g=150, b=200, a=255}, 0)
    end
end

function S.on_key(key)
    if not S.ready then return end
    if key == "z" or key == "return" then
        music.stop()
        engine.scene.switch("hub", {run_result = S.run})
    end
end

function S.unload() end

return S
```

---

## Wiring into Dungeon Flow

In `ui/dungeon_screen.lua`, the `_advance_floor()` function:
```lua
function S._advance_floor()
    local next_floor = S.run.floor + 1
    S.run.floor = next_floor

    if next_floor > 15 then
        -- Victory condition
        engine.scene.switch("run_over", {run = S.run})
        return
    end

    local is_boss_floor = (next_floor % 5 == 1) and (next_floor > 1)
    -- i.e., floors 6, 11, 16... are post-boss transition floors
    -- actually: boss is ON floor 5/10/15; shop is AFTER defeating that boss
    -- So check: did we just clear a boss floor?
    local just_cleared_boss = (S.run.floor - 1) % 5 == 0 and (S.run.floor - 1) > 0

    if just_cleared_boss then
        engine.scene.switch("shop", {
            run         = S.run,
            floor       = S.run.floor - 1,
            biome       = S.biome,
            on_continue = function(run)
                engine.scene.switch("dungeon", {run=run, floor=next_floor})
            end,
            on_extract  = function(run)
                engine.scene.switch("run_over", {run=run})
            end,
        })
    else
        engine.scene.switch("dungeon", {run = S.run, floor = next_floor})
    end
end
```

---

## Checklist

- [ ] `dungeon/shop.lua` — inventory generation, buy logic
- [ ] `ui/shop_screen.lua` — full scene with tab switching, feedback toasts
- [ ] `ui/run_over.lua` — outcome detection, stat summary, cooldown application
- [ ] Wire `_advance_floor()` in dungeon_screen to route through shop on boss floors
- [ ] Register `shop` and `run_over` scenes in `main.lua`
- [ ] Test: beat boss → shop appears → buy item → continue → next floor loads
- [ ] Test: extract button → run_over with "Extracted" outcome
- [ ] Test: full party wipe → run_over with "Wiped Out" + cooldown list
- [ ] Test: floor 15 clear → run_over with "Run Complete!" + victory music
