# Vexel Engine — Lua API Reference

Terminal graphics runtime: Zig 0.15.2 + Lua 5.4, Kitty graphics protocol, 60fps.

## Architecture

```
Lua code -> Renderer API -> 8-layer compositor -> Kitty protocol -> terminal
```

- Virtual resolution: 320x180 default (configurable via `set_resolution`)
- 8 compositor layers (0-7), alpha blended bottom-to-top; text renders on top of all pixel layers
- Dirty-rect tracking; synchronized output (Mode 2026)
- Main loop: `engine.load() -> [poll input -> engine.update(dt) -> engine.draw() -> composite -> flush]`

```bash
zig build run -- examples/bounce/    # project dir must contain main.lua
```

## Lifecycle Callbacks

```lua
function engine.load()                          -- once at startup
function engine.update(dt)                      -- every frame, dt in seconds
function engine.draw()                          -- every frame after update
function engine.on_key(key, action)             -- action: "press"/"release"
function engine.on_mouse(x, y, button, action)  -- button: left/right/middle/scroll_up/scroll_down
function engine.quit()                          -- on shutdown
engine.quit()                                   -- call to exit
```

## Graphics — Text + Primitives

```lua
engine.graphics.draw_text(col, row, text, fg_hex, bg_hex)  -- cell coords
engine.graphics.set_resolution(w, h)
local w, h = engine.graphics.get_resolution()
local cols, rows = engine.graphics.get_size()               -- terminal cell grid
local px_w, px_h = engine.graphics.get_pixel_size()

engine.graphics.set_layer(n)                     -- 0-7, subsequent pixel draws go here
engine.graphics.pixel.rect(x, y, w, h, color)   -- virtual pixel coords
engine.graphics.pixel.line(x1, y1, x2, y2, color)
engine.graphics.pixel.circle(cx, cy, r, color)
engine.graphics.pixel.set(x, y, color)
engine.graphics.pixel.clear()                    -- clears current layer
engine.graphics.pixel.buffer(pixels, x, y, w, h) -- flat table, row-major
engine.graphics.clear()                          -- clears text
engine.graphics.clear_all()                      -- clears all layers + text
```

## Graphics — Images (Immediate Mode)

Use for one-off draws, effects, or when you need full manual control each frame.

```lua
local img = engine.graphics.load_image("assets/player.png")
engine.graphics.draw_sprite(img, x, y)
engine.graphics.draw_sprite(img, x, y, { frame = 2, scale = 2, flip_x = true })
engine.graphics.unload_image(img)

local sheet = engine.graphics.load_spritesheet("assets/chars.png", tile_w, tile_h)
engine.graphics.draw_frame(sheet, frame_index, x, y)
local count = engine.graphics.get_frame_count(sheet)
```

## Graphics — ECS Sprites (Retained Mode)

**Use for objects that persist across frames** (characters, projectiles, pickups, widgets).
The engine auto-advances animations and auto-renders sprites by layer each frame.
You do NOT call draw_sprite in draw() for ECS sprites — the engine handles it.

```lua
-- Create a sprite entity
local e = engine.world.spawn()
engine.world.set(e, "position", { x = 100, y = 50 })
engine.world.set(e, "sprite", {
    image = sheet,        -- spritesheet handle (required)
    layer = 2,            -- compositor layer 0-7 (default 1)
    scale = 2,            -- pixel scale (default 1)
    flip_x = false,       -- (default false)
    flip_y = false,       -- (default false)
})

-- Add animation (engine advances frames automatically each update)
engine.world.set(e, "animation", {
    frames = {0, 1, 2, 3},   -- frame indices into spritesheet
    speed = 0.15,             -- seconds per frame (default 0.1)
    loop = true,              -- (default true)
    sheet = alt_sheet,        -- optional: override sprite's image during this animation
    on_complete = function()  -- fires once when loop=false animation ends
        -- chain to next animation here
    end,
})

-- Move the sprite (just update position)
local pos = engine.world.get(e, "position")
engine.world.set(e, "position", { x = pos.x + 10, y = pos.y })

-- Remove animation (sprite stays on current frame)
engine.world.remove(e, "animation")

-- Destroy
engine.world.despawn(e)
```

### Animation State Machine Pattern

Chain animations via on_complete. This replaces manual frame tracking.

```lua
local ANIMS = {
    idle   = { frames = {0,1,2,3}, speed = 0.4,  loop = true },
    attack = { frames = {4,5,6},   speed = 0.12, loop = false },
    hit    = { frames = {7,8},     speed = 0.15, loop = false },
    faint  = { frames = {9,10},    speed = 0.3,  loop = false },
}

local function play_anim(entity, name)
    local a = ANIMS[name]
    engine.world.set(entity, "animation", {
        frames = a.frames, speed = a.speed, loop = a.loop,
        on_complete = function()
            if name ~= "faint" then play_anim(entity, "idle") end
        end,
    })
end

-- Usage: play_anim(player_entity, "attack")
-- Automatically chains: attack -> idle
```

### When to use ECS sprites vs immediate draw_sprite

| Use case | API |
|----------|-----|
| Characters, enemies, projectiles, pickups | ECS sprites (auto-animated, auto-rendered) |
| UI elements (HP bars, menus, backgrounds) | `pixel.rect` + `draw_text` (manual in draw()) |
| Particle effects, one-frame flashes | Immediate `draw_sprite` |
| Tilemaps | `draw_tilemap` (see below) |

## Graphics — Tilemap

```lua
engine.graphics.draw_tilemap(tileset, map, {
    width = 40,       -- map width in tiles (required)
    cam_x = 120.5,    -- camera X (sub-pixel scrolling)
    cam_y = 80.0,     -- camera Y
    layer = 0,        -- compositor layer
})
-- map: flat 1D array, row-major, 1-based tile indices (0 = empty)
-- height derived from #map / width; only visible tiles rendered
```

## Scenes

```lua
-- Scene table contract (all callbacks optional)
local scene = {}
function scene.load(data) end       -- entered via push/switch
function scene.update(dt) end
function scene.draw() end
function scene.on_key(key, action) end
function scene.on_mouse(x, y, button, action) end
function scene.unload() end         -- leaving scene
function scene.pause() end          -- another scene pushed on top
function scene.resume(data) end     -- returning from pop
return scene

-- Navigation
engine.scene.register("menu", require("scenes.menu"))
engine.scene.push("game", optional_data)
engine.scene.pop(optional_data)
engine.scene.switch("menu")
engine.scene.switch("menu", {
    transition = "fade",  -- "fade"/"slide_left"/"slide_right"/"wipe"
    duration = 0.5,
    data = optional_data,
})
```

## Input

```lua
engine.input.is_key_down("left")
local x, y, buttons = engine.input.get_mouse()  -- buttons = {left, right, middle}
local gp = engine.input.get_gamepad()            -- {up,down,left,right,a,b,start,select}
-- Gamepad mapping: arrows/WASD -> dpad, z -> a, x -> b, return -> start, escape -> select
```

**Key names:** a-z, 0-9, up/down/left/right, escape, return, tab, backspace, delete, space, page_up/page_down, home/end, f1-f12

## Audio

```lua
local music = engine.audio.load("assets/theme.wav", { stream = true })
local sfx = engine.audio.load("assets/hit.wav")
music:play({ loop = true, volume = 0.7, pan = 0.0 })
sfx:play(); sfx:stop(); sfx:pause(); sfx:resume()
sfx:set_volume(0.5); sfx:set_pan(-0.5)
music:fade_in(2000); music:fade_out(1000)   -- milliseconds
engine.audio.set_master_volume(0.8)
engine.audio.stop_all()
```

Formats: WAV, OGG, MP3. Gracefully disabled if no audio device.

## Timers + Tweens

```lua
local h = engine.timer.after(2.0, function() end)
local h = engine.timer.every(0.5, function() end)
engine.timer.cancel(h)

engine.tween(target, { x = 100, y = 50 }, 0.3)
engine.tween(target, { x = 100 }, 1.0, "ease_in_out", function() end)
-- Easing: "linear", "ease_in", "ease_out", "ease_in_out"
```

## Persistence

```lua
-- Key-value (auto-creates save.db in project dir)
engine.save.set("high_score", "9001")
local score = engine.save.get("high_score")  -- string or nil
engine.save.set("key", nil)                  -- delete

-- Raw SQLite
local db = engine.db.open("data.db")
db:exec("CREATE TABLE IF NOT EXISTS t (id INTEGER, data TEXT)")
db:exec("INSERT INTO t VALUES (?, ?)", 1, "hello")
local rows = db:query("SELECT * FROM t WHERE id = ?", 1)
db:close()
```

## ECS

```lua
local e = engine.world.spawn()
engine.world.set(e, "position", { x = 100, y = 50 })
engine.world.set(e, "velocity", { vx = 10, vy = 0 })
engine.world.set(e, "sprite", { image = h, layer = 1, scale = 1, flip_x = false })
engine.world.set(e, "animation", { frames = {0,1,2,3}, speed = 0.1, loop = true })
engine.world.set(e, "collider", { w = 16, h = 16, solid = true })
engine.world.set(e, "tag", { player = true, enemy = false })

local pos = engine.world.get(e, "position")
engine.world.remove(e, "velocity")
local alive = engine.world.is_alive(e)
local n = engine.world.count("position")
engine.world.despawn(e)

for entity, pos, vel in engine.world.each("position", "velocity") do end
```

**Built-in systems (run automatically each frame):**
- Movement: position += velocity * dt
- Animation: frame advancement, on_complete callbacks
- Sprite rendering: collect visible sprites, sort by layer, draw

## Known Limitations

- `visible` on SpriteComp exists in Zig but is NOT settable/gettable from Lua (workaround: despawn or move off-screen)
- `frame` is NOT returned by `world.get(e, "sprite")` (managed automatically by animation system)
- Max 32 frames per animation
- `on_complete` fires once then clears — setting a new animation resets it
- Setting animation auto-sets sprite.frame to frames[1]; removing animation leaves sprite on last frame
