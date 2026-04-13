# Phase 9.8 — Polish Pass

## Goal
Elevate from "functional" to "feels good to play." Juice: HP drain tweens, battle step animations, screen shake, type-colored attack effects, crossfade transitions, and the full-screen moment interruptions (scar, evolution, boss clear, first catch). Also: audio cue polish and input responsiveness tuning.

## Verify
- HP bars animate smoothly (tween, not instant snap)
- Battle has sequenced animations: attack flash → damage text → HP drain
- Screen shake fires on critical hits and knockouts
- Type-colored attack effects play between attacker and target
- Crossfade transition between dungeon and battle
- Full-screen moments fire correctly (scar, evolution, boss clear, run over)

---

## Files to Create/Modify

```
games/codecritter/
├── ui/anim.lua            -- Step sequencer (verify/extend)
├── ui/battle_screen.lua   -- Add animation sequences, shake, effects
├── ui/dungeon_screen.lua  -- Add crossfade transition trigger
├── ui/moments.lua         -- Full-screen interruption scenes (new)
└── ui/widgets.lua         -- Animated HP bar (tween-based)
```

---

## Animation Architecture

### Engine primitives available
- `engine.tween(target_table, fields, duration, easing, on_complete)` — smooth field interpolation
- `engine.timer.after(dt, fn)` — one-shot delay
- `engine.graphics.rect()` — flash overlays (layer 4-7)
- `engine.graphics.draw_sprite()` — immediate-mode sprite draw

### Battle step sequencer (`ui/anim.lua`)
The sequencer queues `{fn, delay}` pairs. Each step fires its callback immediately, then waits `delay` seconds before advancing.

```lua
-- ui/anim.lua
local M = {}

function M.new()
    return {queue={}, t=0, running=false}
end

-- Push a step: fn fires now, delay is wait before next step
function M.push(seq, fn, delay)
    table.insert(seq.queue, {fn=fn, delay=delay or 0})
end

-- Push a tween-backed step: fires tween, delays by tween duration
function M.push_tween(seq, target, fields, duration, easing)
    M.push(seq, function()
        engine.tween(target, fields, duration, easing or "ease_out")
    end, duration)
end

-- Push a blank pause
function M.push_wait(seq, delay)
    M.push(seq, function() end, delay)
end

function M.update(seq, dt)
    if not seq.running or #seq.queue == 0 then return end
    seq.t = seq.t - dt
    if seq.t <= 0 then
        table.remove(seq.queue, 1)
        if #seq.queue > 0 then
            local step = seq.queue[1]
            step.fn()
            seq.t = step.delay
        else
            seq.running = false
            if seq.on_done then seq.on_done() end
        end
    end
end

-- Start the sequence
function M.start(seq, on_done)
    if #seq.queue == 0 then
        if on_done then on_done() end
        return
    end
    seq.on_done = on_done
    seq.running = true
    local step = seq.queue[1]
    step.fn()
    seq.t = step.delay
end

-- Skip to end immediately
function M.skip(seq)
    while #seq.queue > 0 do
        local step = table.remove(seq.queue, 1)
        step.fn()
    end
    seq.running = false
    if seq.on_done then seq.on_done() end
end

return M
```

---

## Animated HP Bar

The HP bar animates via a displayed value that tweens toward the actual value.

```lua
-- In widgets.lua, extend hp_bar():
-- hp_bar(critter, x, y, w, h, layer) where critter has hp, max_hp, _display_hp

function widgets.hp_bar_animated(critter, x, y, w, h, layer)
    -- Initialize display HP if not set
    if not critter._display_hp then
        critter._display_hp = critter.hp
    end

    local pct = critter._display_hp / critter.max_hp
    local bar_w = math.max(0, math.floor(pct * w))

    -- Color: green > 50%, yellow > 25%, red <= 25%
    local col
    if pct > 0.5 then     col = {r=80,  g=200, b=90,  a=255}
    elseif pct > 0.25 then col = {r=220, g=190, b=50,  a=255}
    else                   col = {r=200, g=60,  b=60,  a=255}
    end

    -- Background
    engine.graphics.rect(x, y, w, h, {r=40, g=35, b=55, a=255}, layer)
    -- Filled bar
    if bar_w > 0 then
        engine.graphics.rect(x, y, bar_w, h, col, layer)
    end
    -- HP numbers
    local hp_text = math.ceil(critter._display_hp) .. "/" .. critter.max_hp
    engine.graphics.text(hp_text, x + w + 4, y, {r=190, g=185, b=210, a=255}, layer)
end

-- Trigger HP drain animation
function widgets.animate_hp_drain(critter, new_hp, duration)
    critter._display_hp = critter._display_hp or critter.hp
    engine.tween(critter, {_display_hp = new_hp}, duration or 0.6, "ease_out")
    critter.hp = new_hp
end
```

---

## Screen Shake

```lua
-- In ui/battle_screen.lua and ui/dungeon_screen.lua

-- Shake state
local shake = {x=0, y=0, t=0, intensity=0}

local function trigger_shake(intensity, duration)
    shake.intensity = intensity
    shake.t = duration or 0.3
end

local function update_shake(dt)
    if shake.t > 0 then
        shake.t = shake.t - dt
        local s = shake.intensity * (shake.t / 0.3)
        shake.x = (math.random() * 2 - 1) * s
        shake.y = (math.random() * 2 - 1) * s
    else
        shake.x = 0
        shake.y = 0
    end
end

-- Apply shake offset to all draw calls by setting a global offset
-- In draw(), before all graphics calls:
-- engine.graphics.set_offset(math.floor(shake.x), math.floor(shake.y))
-- After all draws:
-- engine.graphics.set_offset(0, 0)
-- NOTE: if engine doesn't have set_offset, simulate by adding shake.x/y to all positions manually.
-- For Phase 9.8, wrap a draw_offset helper:
local function ox(base) return base + math.floor(shake.x) end
local function oy(base) return base + math.floor(shake.y) end
```

---

## Type Attack Effects

Each type has a characteristic visual effect. Drawn on layer 4 (above UI) during the attack animation step.

```lua
-- In ui/battle_screen.lua

local TYPE_EFFECTS = {
    DEBUG   = {color={r=80,  g=180, b=255, a=200}, shape="rect"},
    CHAOS   = {color={r=200, g=60,  b=200, a=200}, shape="circle"},
    PATIENCE= {color={r=100, g=220, b=140, a=200}, shape="line"},
    WISDOM  = {color={r=220, g=190, b=60,  a=200}, shape="circle"},
    SNARK   = {color={r=255, g=120, b=60,  a=200}, shape="line"},
    VIBE    = {color={r=60,  g=220, b=220, a=200}, shape="rect"},
    LEGACY  = {color={r=160, g=140, b=200, a=200}, shape="rect"},
}

-- Effect state
local effect = {active=false, t=0, duration=0.4, type=nil, x=0, y=0}

local function trigger_effect(move_type, target_x, target_y)
    effect.active   = true
    effect.t        = effect.duration
    effect.type     = move_type
    effect.x        = target_x
    effect.y        = target_y
end

local function draw_effect()
    if not effect.active or effect.t <= 0 then return end
    local pct  = effect.t / effect.duration
    local data = TYPE_EFFECTS[effect.type] or TYPE_EFFECTS.DEBUG
    local col  = {r=data.color.r, g=data.color.g, b=data.color.b, a=math.floor(data.color.a * pct)}
    local size = math.floor(30 * pct)

    if data.shape == "rect" then
        engine.graphics.rect(effect.x - size, effect.y - size, size*2, size*2, col, 4)
    elseif data.shape == "circle" then
        engine.graphics.circle(effect.x, effect.y, size, col, 4)
    elseif data.shape == "line" then
        -- Cross pattern
        engine.graphics.line(effect.x - size, effect.y, effect.x + size, effect.y, col, 4)
        engine.graphics.line(effect.x, effect.y - size, effect.x, effect.y + size, col, 4)
    end
end

local function update_effect(dt)
    if effect.active then
        effect.t = effect.t - dt
        if effect.t <= 0 then effect.active = false end
    end
end
```

---

## Complete Battle Animation Sequence

The battle step sequencer queues these steps for a player attack:

```lua
-- In battle_screen.lua, _execute_player_move(move):

local function _execute_player_move(move)
    local seq = anim.new()
    local result = battle_engine.process_attack(S.state, S.state.player_active, S.state.enemy_active, move)

    -- Step 1: Flash attacker sprite
    anim.push(seq, function()
        S.attacker_flash = 1.0  -- white overlay alpha, drawn on top of sprite
    end, 0.1)

    -- Step 2: Clear flash, trigger type effect on enemy
    anim.push(seq, function()
        S.attacker_flash = 0
        trigger_effect(move.type, S.enemy_sprite_x + 16, S.enemy_sprite_y + 16)
    end, 0.25)

    -- Step 3: Show damage number + apply HP drain tween
    anim.push(seq, function()
        if result.damage > 0 then
            S.damage_text = {
                value = tostring(result.damage),
                x = S.enemy_sprite_x,
                y = S.enemy_sprite_y,
                t = 1.0,
            }
            widgets.animate_hp_drain(S.state.enemy_active, result.new_hp, 0.6)
            if result.crit then trigger_shake(4, 0.25) end
            if result.ko then trigger_shake(6, 0.4) end
        end
        -- Append battle log message
        S._log(result.message)
    end, 0.7)

    -- Step 4: Check catch result if applicable
    if result.caught then
        anim.push(seq, function()
            S._trigger_catch_moment(result.caught_critter)
        end, 0)
    end

    -- Step 5: Continue to enemy turn
    anim.push(seq, function()
        if not result.ko and not result.caught then
            S._enemy_turn()
        else
            S._check_battle_end(result)
        end
    end, 0)

    anim.start(seq)
end
```

---

## Crossfade Transition (Dungeon → Battle)

Use engine's built-in fade transition:

```lua
-- In dungeon_screen.lua, _trigger_battle():
local function _trigger_battle(enemy)
    engine.scene.switch("battle", {
        run        = S.run,
        enemy      = enemy,
        transition = {type="fade", duration=0.3},
        on_return  = function(result) S._post_battle(result) end,
    })
end
```

The scene manager handles the crossfade automatically when `transition` is passed. Battle returns to dungeon via `engine.scene.pop()`.

---

## `ui/moments.lua` — Full-Screen Interruptions

```lua
-- ui/moments.lua
-- Full-screen pause moments: scar, evolution, boss clear, first catch

local M = {}

-- All moments are modal overlays drawn on top of whatever scene is active.
-- They don't push a new scene — they draw on layer 6-7 and block input.

local current = nil

-- Show a moment. on_dismiss called when player presses Z.
function M.show(kind, data, on_dismiss)
    current = {
        kind       = kind,
        data       = data,
        on_dismiss = on_dismiss,
        t          = 0,
        ready      = false,  -- Z blocks until t > 0.8
    }
end

function M.active()
    return current ~= nil
end

function M.update(dt)
    if not current then return end
    current.t = current.t + dt
    if current.t > 0.8 then current.ready = true end
end

function M.draw()
    if not current then return end
    local W, H = 640, 360
    local alpha = math.min(200, math.floor(current.t * 400))

    -- Dim backdrop
    engine.graphics.rect(0, 0, W, H, {r=0, g=0, b=0, a=alpha}, 6)

    local kind = current.kind
    if kind == "scar" then
        M._draw_scar(current.data)
    elseif kind == "evolution" then
        M._draw_evolution(current.data)
    elseif kind == "first_catch" then
        M._draw_first_catch(current.data)
    elseif kind == "boss_clear" then
        M._draw_boss_clear(current.data)
    elseif kind == "run_complete" then
        M._draw_run_complete(current.data)
    end

    if current.ready then
        engine.graphics.text("[Z] Continue", W/2 - 50, H - 40, {r=180, g=175, b=200, a=255}, 7)
    end
end

function M.on_key(key)
    if not current then return false end
    if current.ready and (key == "z" or key == "return") then
        local cb = current.on_dismiss
        current = nil
        if cb then cb() end
        return true
    end
    return true  -- always consume input while moment is active
end

-- Individual moment draw functions

function M._draw_scar(data)
    -- data: {critter, scar}
    local W, H = 640, 360
    engine.graphics.text("SCAR RECEIVED", W/2 - 70, 80, {r=200, g=60, b=60, a=255}, 7)
    engine.graphics.text(data.critter.name .. " took lasting damage.", W/2 - 120, 110, {r=200, g=190, b=210, a=255}, 7)
    engine.graphics.text(
        data.scar.stat:upper() .. " permanently -" .. data.scar.amount,
        W/2 - 100, 140, {r=180, g=80, b=80, a=255}, 7
    )
    -- Critter sprite (placeholder box)
    engine.graphics.rect(W/2 - 32, 170, 64, 64, {r=80, g=40, b=40, a=255}, 7)
    engine.graphics.text("A reminder of this fight.", W/2 - 110, 250, {r=140, g=130, b=155, a=255}, 7)
end

function M._draw_evolution(data)
    -- data: {from_name, to_name, critter}
    local W, H = 640, 360
    engine.graphics.text("EVOLUTION!", W/2 - 48, 60, {r=255, g=220, b=80, a=255}, 7)
    engine.graphics.text(data.from_name .. "  →  " .. data.to_name, W/2 - 80, 90, {r=220, g=210, b=240, a=255}, 7)
    -- Flash effect (simple: alternate bg color)
    local flash = math.sin(engine.time() * 8) > 0
    if flash then
        engine.graphics.rect(0, 0, W, H, {r=255, g=240, b=100, a=30}, 7)
    end
    -- Sprite boxes: before → after
    engine.graphics.rect(W/2 - 90, 120, 64, 64, {r=60, g=55, b=80, a=255}, 7)
    engine.graphics.text("→", W/2 - 10, 148, {r=200, g=200, b=200, a=255}, 7)
    engine.graphics.rect(W/2 + 26, 120, 64, 64, {r=80, g=70, b=120, a=255}, 7)
    -- Stat comparison
    local stats = {"logic", "resolve", "speed"}
    local sy = 200
    for _, stat in ipairs(stats) do
        local old_val = data.old_stats and data.old_stats[stat] or 0
        local new_val = data.critter.stats[stat]
        local diff = new_val - old_val
        local col = diff > 0 and {r=100, g=220, b=130, a=255} or {r=200, g=190, b=210, a=255}
        engine.graphics.text(
            stat:upper() .. ": " .. old_val .. " → " .. new_val .. (diff > 0 and "  +" .. diff or ""),
            W/2 - 80, sy, col, 7
        )
        sy = sy + 20
    end
end

function M._draw_first_catch(data)
    local W, H = 640, 360
    engine.graphics.text("FIRST CATCH!", W/2 - 56, 70, {r=100, g=200, b=255, a=255}, 7)
    engine.graphics.text(data.critter.name .. " joined your roster.", W/2 - 120, 100, {r=200, g=195, b=220, a=255}, 7)
    engine.graphics.rect(W/2 - 32, 130, 64, 64, {r=50, g=70, b=100, a=255}, 7)
    engine.graphics.text("Catch tools can be found in chests and shops.", W/2 - 180, 210, {r=140, g=135, b=160, a=255}, 7)
    engine.graphics.text("Your codex has been updated.", W/2 - 110, 228, {r=140, g=135, b=160, a=255}, 7)
end

function M._draw_boss_clear(data)
    local W, H = 640, 360
    local col = {r=255, g=200, b=60, a=255}
    engine.graphics.text("BOSS DEFEATED", W/2 - 72, 70, col, 7)
    if data.flavor then
        engine.graphics.text(data.flavor, W/2 - 160, 110, {r=200, g=190, b=215, a=255}, 7)
    end
    engine.graphics.text("Shop is now open.", W/2 - 70, 160, {r=130, g=200, b=150, a=255}, 7)
    engine.graphics.text("Your party has been fully healed.", W/2 - 120, 178, {r=130, g=200, b=150, a=255}, 7)
end

function M._draw_run_complete(data)
    local W, H = 640, 360
    engine.graphics.text("RUN COMPLETE", W/2 - 72, 60, {r=255, g=220, b=80, a=255}, 7)
    engine.graphics.text("Floor 15 cleared.", W/2 - 60, 90, {r=200, g=195, b=220, a=255}, 7)
    if data and data.floors then
        engine.graphics.text("Floors: " .. data.floors, W/2 - 40, 120, {r=180, g=175, b=200, a=255}, 7)
    end
    if data and data.catches then
        engine.graphics.text("Caught: " .. data.catches, W/2 - 40, 138, {r=180, g=175, b=200, a=255}, 7)
    end
end

return M
```

---

## Integration: moments.lua in battle_screen.lua

Moments are drawn in `draw()` after all other layers, and consume input in `on_key()`:

```lua
-- In battle_screen.lua:
local moments = require("ui.moments")

function S.draw()
    -- ... all normal draw code ...
    moments.draw()  -- always last
end

function S.on_key(key)
    -- Moments consume all input when active
    if moments.on_key(key) and moments.active() then return end
    -- ... normal key handling ...
end

function S.update(dt)
    -- ...
    moments.update(dt)
    -- ...
end

-- Trigger scar moment after a knockout:
-- moments.show("scar", {critter=critter, scar=scar}, function()
--     S._continue_after_scar()
-- end)
```

---

## Floating Damage Numbers

```lua
-- In battle_screen.lua, draw():

-- S.damage_texts = list of {value, x, y, t, col}
-- Each ticks down on t; draw while t > 0

local function update_damage_texts(dt)
    for i = #S.damage_texts, 1, -1 do
        local d = S.damage_texts[i]
        d.t = d.t - dt
        d.y = d.y - 20 * dt  -- float upward
        if d.t <= 0 then table.remove(S.damage_texts, i) end
    end
end

local function draw_damage_texts()
    for _, d in ipairs(S.damage_texts or {}) do
        local alpha = math.floor(d.t * 255)
        local col = d.col or {r=255, g=80, b=80, a=alpha}
        col.a = alpha
        engine.graphics.text(d.value, d.x, math.floor(d.y), col, 4)
    end
end

-- On damage:
table.insert(S.damage_texts, {
    value = tostring(damage),
    x     = enemy_sprite_x + 8,
    y     = enemy_sprite_y - 8,
    t     = 0.9,
    col   = {r=255, g=100, b=100, a=255},
})
-- On heal:
table.insert(S.damage_texts, {
    value = "+" .. tostring(heal),
    x     = player_sprite_x + 8,
    y     = player_sprite_y - 8,
    t     = 0.9,
    col   = {r=100, g=220, b=130, a=255},
})
```

---

## Audio Cue Polish

```lua
-- audio/sfx.lua — short SFX events (separate from music.lua)
local M = {}

local sounds = {}

local SFX_MAP = {
    hit         = "assets/sfx/hit.wav",
    hit_super   = "assets/sfx/hit_super.wav",
    hit_weak    = "assets/sfx/hit_weak.wav",
    miss        = "assets/sfx/miss.wav",
    catch       = "assets/sfx/catch.wav",
    evolve      = "assets/sfx/evolve.wav",
    faint       = "assets/sfx/faint.wav",
    menu_move   = "assets/sfx/menu_move.wav",
    menu_select = "assets/sfx/menu_select.wav",
    stairs      = "assets/sfx/stairs.wav",
    chest       = "assets/sfx/chest.wav",
}

function M.play(id)
    local path = SFX_MAP[id]
    if not path then return end
    -- Play one-shot, no handle needed
    engine.audio.play(path, {volume=0.7})
end

return M
```

---

## Checklist

- [ ] `ui/anim.lua` — `push_tween()`, `push_wait()` helpers added
- [ ] `ui/widgets.lua` — `hp_bar_animated()` with `_display_hp` tween field
- [ ] `ui/battle_screen.lua` — full attack sequence: flash → effect → damage text → HP drain
- [ ] Screen shake: `trigger_shake()`, `update_shake()`, offset applied in draw
- [ ] Type effects: `trigger_effect()`, `draw_effect()`, all 7 types defined
- [ ] Floating damage numbers: spawn on damage/heal, float upward, fade out
- [ ] `ui/moments.lua` — 5 moment types: scar, evolution, first_catch, boss_clear, run_complete
- [ ] Moments wired into battle_screen.lua (draw last, on_key gates first)
- [ ] Crossfade transition: `{type="fade", duration=0.3}` passed to scene.switch for battle entry
- [ ] `audio/sfx.lua` — one-shot SFX for hit/miss/catch/faint/evolve/menu
- [ ] SFX calls added: hit on damage, menu_move on cursor change, catch on successful catch
- [ ] Test: HP bar drains smoothly over 0.6s (not instant)
- [ ] Test: critical hit triggers screen shake
- [ ] Test: scar moment fires and blocks input until dismissed
- [ ] Test: evolution moment shows sprite transition + stat comparison
