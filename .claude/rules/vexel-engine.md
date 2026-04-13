# Vexel Engine — Quick Reference

Terminal game engine: Zig 0.15.2 + Lua 5.4, Kitty graphics protocol, 60fps.

## Architecture

```
Lua game code → Renderer API → 8-layer compositor → Kitty protocol → terminal
```

- Virtual resolution: 320×180 default (configurable)
- 8 compositor layers (0-7), alpha blended bottom-to-top
- Text rendered on top of all pixel layers
- Dirty-rect tracking (only changed regions re-rendered)
- Synchronized output (Mode 2026)

## Main Loop

```
engine.load() → [loop: poll input → engine.update(dt) → engine.draw() → composite → flush] → engine.quit()
```

## Running Games

```bash
zig build run -- games/mygame/    # game dir must contain main.lua
```

## Lua API

### Lifecycle Callbacks (define in main.lua or scene)

```lua
function engine.load()                          -- once at startup
function engine.update(dt)                      -- every frame, dt = seconds
function engine.draw()                          -- every frame after update
function engine.on_key(key, action)             -- action: "press"/"release"
function engine.on_mouse(x, y, button, action)  -- button: left/right/middle/scroll_up/scroll_down
function engine.quit()                          -- on shutdown
engine.quit_game()                              -- call to exit
```

### Graphics — Text & Rects

```lua
engine.graphics.draw_text(col, row, text, fg_hex, bg_hex)
engine.graphics.draw_rect(col, row, w, h, color_hex)
engine.graphics.clear()
local cols, rows = engine.graphics.get_size()
local px_w, px_h = engine.graphics.get_pixel_size()
```

### Graphics — Pixels

```lua
engine.graphics.set_resolution(w, h)
local w, h = engine.graphics.get_resolution()
engine.graphics.set_layer(n)                     -- 0-7, subsequent draws go here
engine.graphics.pixel.rect(x, y, w, h, color)
engine.graphics.pixel.line(x1, y1, x2, y2, color)
engine.graphics.pixel.circle(cx, cy, r, color)
engine.graphics.pixel.set(x, y, color)
engine.graphics.pixel.clear()
engine.graphics.pixel.buffer(pixels, x, y, w, h) -- flat table, row-major
engine.graphics.clear_all()
```

### Graphics — Images & Sprites

```lua
local img = engine.graphics.load_image("assets/player.png")
engine.graphics.draw_sprite(img, x, y)
engine.graphics.draw_sprite(img, x, y, { frame = 2, scale = 2 })
engine.graphics.unload_image(img)

local sheet = engine.graphics.load_spritesheet("assets/chars.png", tile_w, tile_h)
engine.graphics.draw_frame(sheet, frame_index, x, y)
local count = engine.graphics.get_frame_count(sheet)
```

### Graphics — Retained Sprites

```lua
local player = engine.sprite(sheet)
player.x = 100; player.y = 200
player.flip_x = true; player.flip_y = false
player.scale = 2; player.layer = 2
player.visible = true; player.frame = 0

player.animation = {
    sheet = idle_sheet,              -- optional, defaults to sprite's base
    frames = {0, 1, 2, 3, 4, 5},    -- optional: all frames
    speed = 0.15,                    -- seconds per frame (default 0.1)
    loop = true,                     -- default true
}
player.on_complete = function() player.animation = idle_anim end
player:destroy()
```

### Graphics — Tilemap

```lua
engine.graphics.draw_tilemap(tileset, map, {
    width = 40,       -- map width in tiles (required)
    cam_x = 120.5,    -- camera X (sub-pixel scrolling)
    cam_y = 80.0,     -- camera Y
    layer = 0,        -- compositor layer
})
-- map: flat 1D array, row-major, 1-based tile indices (0 = empty)
-- height derived from #map / width
```

### Scenes

```lua
-- Define a scene (separate file, return table)
local scene = {}
function scene.load(data) end
function scene.update(dt) end
function scene.draw() end
function scene.on_key(key, action) end
function scene.on_mouse(x, y, button, action) end
function scene.unload() end
function scene.pause() end       -- when another scene pushed on top
function scene.resume(data) end  -- when returning (pop)
return scene

-- Register & navigate
engine.scene.register("menu", require("scenes.menu"))
engine.scene.push("game", optional_data)
engine.scene.pop(optional_data)               -- resume previous scene
engine.scene.switch("menu")                   -- replace current
engine.scene.switch("menu", {
    transition = "fade",  -- "fade"/"slide_left"/"slide_right"/"wipe"
    duration = 0.5,
    data = optional_data,
})
```

### Input

```lua
engine.input.is_key_down("left")               -- continuous polling
local x, y, buttons = engine.input.get_mouse() -- buttons = {left, right, middle}
local gp = engine.input.get_gamepad()           -- {up,down,left,right,a,b,start,select}
-- Gamepad mapping: arrows/WASD → dpad, z → a, x → b, return → start, escape → select
```

**Key names:** a-z, 0-9, up/down/left/right, escape, return, tab, backspace, delete, space, page_up/page_down, home/end, f1-f12

### Audio

```lua
local music = engine.audio.load("assets/theme.wav", { stream = true })
local sfx = engine.audio.load("assets/hit.wav")
music:play({ loop = true, volume = 0.7, pan = 0.0 })
sfx:play(); sfx:stop(); sfx:pause(); sfx:resume()
sfx:set_volume(0.5); sfx:set_pan(-0.5)
music:fade_in(2000); music:fade_out(1000)       -- milliseconds
engine.audio.set_master_volume(0.8)
engine.audio.stop_all()
```

Formats: WAV, OGG, MP3. Gracefully disabled if no audio device.

### Timers & Tweens

```lua
local h = engine.timer.after(2.0, function() end)     -- one-shot
local h = engine.timer.every(0.5, function() end)     -- repeating
engine.timer.cancel(h)

engine.tween(target, { x = 100, y = 50 }, 0.3)                    -- linear
engine.tween(target, { x = 100 }, 1.0, "ease_in_out", function()  -- with easing + callback
    print("done")
end)
-- Easing: "linear", "ease_in", "ease_out", "ease_in_out"
```

### Persistence

```lua
-- Simple key-value (auto-creates save.db in game dir)
engine.save.set("high_score", "9001")
local score = engine.save.get("high_score")  -- string or nil
engine.save.set("key", nil)                  -- delete

-- Raw SQLite
local db = engine.db.open("data.db")
db:exec("CREATE TABLE IF NOT EXISTS t (id INTEGER, data TEXT)")
db:exec("INSERT INTO t VALUES (?, ?)", 1, "hello")
local rows = db:query("SELECT * FROM t WHERE id = ?", 1)
-- rows[i].column_name for access
db:close()
```

### ECS

```lua
local e = engine.world.spawn()
engine.world.set(e, "position", { x = 100, y = 50 })
engine.world.set(e, "velocity", { vx = 10, vy = 0 })
engine.world.set(e, "sprite", { image_handle = h, layer = 1, frame = 0, flip_x = false, scale = 1, visible = true })
engine.world.set(e, "animation", { frames = {0,1,2,3}, frame_count = 4, speed = 0.1, loop = true })
engine.world.set(e, "collider", { w = 16, h = 16, solid = true })
engine.world.set(e, "tag", { player = true, enemy = false })

local pos = engine.world.get(e, "position")
engine.world.remove(e, "velocity")
local alive = engine.world.is_alive(e)
local n = engine.world.count("position")
engine.world.despawn(e)

for entity, pos, vel in engine.world.each("position", "velocity") do
    -- iterate entities with both components
end
```

**Built-in systems (automatic):** movement (pos += vel * dt), animation frame advancement, sprite rendering by layer.

## Source Structure

```
src/main.zig                     -- entry point, main loop
src/engine/{input,scene,timer}.zig
src/graphics/{renderer,kitty,compositing,image,sprite_placer,tilemap}.zig
src/ecs/{entity,component_store,world}.zig
src/scripting/{lua_engine,lua_api,lua_ecs}.zig
src/audio/audio.zig
src/persistence/db.zig
```

## Minimal Game Template

```lua
function engine.load()
    engine.graphics.set_resolution(320, 180)
end

function engine.update(dt)
end

function engine.draw()
    engine.graphics.clear()
    engine.graphics.draw_text(1, 1, "Hello!", 0xFFFFFF)
end

function engine.on_key(key, action)
    if action == "press" and key == "q" then engine.quit_game() end
end
```
