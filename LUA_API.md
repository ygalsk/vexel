# Vexel Lua API Reference

## Lifecycle Callbacks

```lua
-- main.lua (entry point)
function engine.load()
    -- Called once at startup. Load assets, init state.
end

function engine.update(dt)
    -- Called every frame. dt = seconds since last frame.
end

function engine.draw()
    -- Called every frame after update. All rendering here.
end

function engine.on_key(key, action)
    -- Input callback. action: "press", "release"
end

function engine.on_mouse(x, y, button, action)
    -- Mouse callback. button: "left", "right", "middle", "scroll_up", "scroll_down"
    -- action: "press", "release", "move"
end

function engine.quit()
    -- Called on engine shutdown. Cleanup.
end
```

## Graphics (Phase 0 — Available Now)

```lua
-- Text rendering (cell coordinates)
engine.graphics.draw_text(col, row, text, fg_hex, bg_hex)

-- Rectangle fill (cell coordinates)
engine.graphics.draw_rect(col, row, width, height, color_hex)

-- Clear screen
engine.graphics.clear()

-- Screen dimensions
local cols, rows = engine.graphics.get_size()
local px_w, px_h = engine.graphics.get_pixel_size()
```

Colors are hex integers: `0xFF0000` = red, `0x00FF00` = green, etc.

## Graphics (Phase 1 — Pixel Drawing)

```lua
-- Pixel primitives (virtual pixel coordinates)
engine.graphics.pixel.rect(x, y, w, h, color)      -- filled rect
engine.graphics.pixel.line(x1, y1, x2, y2, color)  -- line
engine.graphics.pixel.circle(cx, cy, r, color)      -- filled circle
engine.graphics.pixel.set(x, y, color)              -- single pixel
engine.graphics.pixel.clear()                       -- clear active layer

-- Bulk pixel write (for full-screen effects, fractals, etc.)
-- pixels is a flat table of w*h hex color integers, row-major order
engine.graphics.pixel.buffer(pixels, x, y, w, h)

-- Resolution
engine.graphics.set_resolution(w, h)               -- set virtual resolution (default 320x180)
local px_w, px_h = engine.graphics.get_resolution()

-- Layers (0-7, drawn bottom to top with alpha blending)
engine.graphics.set_layer(n)  -- subsequent draws go to layer n
engine.graphics.clear_all()   -- clear all layers
```

## Sprites (Phase 2)

```lua
local sprite = engine.graphics.load_image("assets/player.png")
engine.graphics.draw_sprite(sprite, x, y)
engine.graphics.draw_sprite(sprite, x, y, { frame = 2, scale = 2 })

local sheet = engine.graphics.load_spritesheet("assets/chars.png", 16, 16)
engine.graphics.draw_frame(sheet, frame_index, x, y)

engine.graphics.unload_image(sprite)
```

## Retained Sprites (Phase 2)

Retained sprites are persistent objects managed by the engine. Assign properties
declaratively; the engine handles rendering and animation advancement.

```lua
-- Create a retained sprite from an image or spritesheet
local player = engine.sprite(idle_sheet)

-- Set properties (triggers engine-side state update)
player.x = 100
player.y = 200
player.flip_x = true
player.scale = 2
player.layer = 2
player.visible = true
player.frame = 0          -- static frame (clears any active animation)

-- Read properties back
local px = player.x

-- Explicit cleanup (also cleaned up automatically via GC)
player:destroy()
```

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `x` | number | 0 | X position (virtual pixels) |
| `y` | number | 0 | Y position (virtual pixels) |
| `flip_x` | boolean | false | Horizontal flip |
| `flip_y` | boolean | false | Vertical flip |
| `scale` | integer | 1 | Scale factor (1-8) |
| `layer` | integer | 1 | Compositor layer (0-7) |
| `visible` | boolean | true | Whether to render |
| `frame` | integer | 0 | Current frame (setting clears animation) |
| `animation` | table/nil | nil | Animation definition (see below) |
| `on_complete` | function/nil | nil | Called when non-looping animation finishes |

### Animations

Define animations as pure Lua data tables. The engine advances frames automatically.

```lua
-- Animation from a spritesheet (one sheet per animation)
local idle_anim = {
    sheet = idle_sheet,             -- spritesheet (optional, defaults to sprite's base image)
    frames = {0, 1, 2, 3, 4, 5},   -- frame indices (optional, defaults to all frames)
    speed = 0.15,                   -- seconds per frame (default 0.1)
    loop = true,                    -- loop animation (default true)
}

-- Assign animation (engine drives frame advancement)
player.animation = idle_anim

-- One-shot animation with completion callback
local slash_anim = {
    sheet = slash_sheet,
    frames = {0, 1, 2, 3},
    speed = 0.06,
    loop = false,
}
player.animation = slash_anim
player.on_complete = function()
    player.animation = idle_anim   -- chain back to idle
end

-- Clear animation
player.animation = nil
```

Assigning the same animation table again is a no-op (does not restart the animation).
Different animations can reference different spritesheets with different frame sizes.

## Scene Management (Phase 3 — Available Now)

Scenes are Lua tables with optional callbacks. Register them in `engine.load()`,
then use the scene stack to navigate.

```lua
-- Define a scene (typically in a separate file, loaded via require)
local menu = {}
function menu.load(data)   end  -- called on push/switch (data is optional)
function menu.update(dt)   end  -- called every frame (active scene only)
function menu.draw()       end  -- called every frame (active scene only)
function menu.on_key(key, action)              end
function menu.on_mouse(x, y, button, action)   end
function menu.unload()     end  -- called on pop/switch away
function menu.pause()      end  -- called when another scene is pushed on top
function menu.resume(data) end  -- called when returning from a pushed scene
return menu

-- In main.lua:
function engine.load()
    engine.scene.register("menu", require("scenes.menu"))
    engine.scene.register("game", require("scenes.game"))
    engine.scene.push("menu")
end

-- Navigation
engine.scene.push("game", optional_data)   -- push new scene, pause current
engine.scene.pop(optional_data)            -- return to previous scene
engine.scene.switch("menu")                -- replace current scene (instant)
engine.scene.switch("menu", {              -- replace with transition
    transition = "fade",                   -- "fade", "slide_left", "slide_right", "wipe"
    duration = 0.5,                        -- seconds
    data = optional_data,                  -- passed to new scene's load()
})
```

Games that never call `engine.scene.register` work unchanged (legacy mode).

## Input (Phase 3 — Available Now)

```lua
-- Key state queries (continuous input, no event callbacks needed)
engine.input.is_key_down("left")   -- true/false
engine.input.is_key_down("a")      -- works with any key name from on_key

-- Mouse state
local x, y, buttons = engine.input.get_mouse()
-- buttons = { left = bool, right = bool, middle = bool }

-- Gamepad abstraction (mapped from keyboard)
local gp = engine.input.get_gamepad()
-- gp = { up, down, left, right, a, b, start, select }
-- Mapping: arrows/WASD → dpad, z → a, x → b, return → start, escape → select
```

## Audio (Phase 4 — Available Now)

```lua
-- Load sounds (paths relative to game directory)
local music = engine.audio.load("assets/theme.wav", { stream = true })  -- streaming for large files
local sfx = engine.audio.load("assets/hit.wav")                         -- preloaded for low latency

-- Playback
music:play({ loop = true, volume = 0.7, pan = 0.0 })  -- all opts are optional
sfx:play()                                              -- play with defaults
sfx:stop()
sfx:pause()
sfx:resume()

-- Volume and panning
sfx:set_volume(0.5)       -- 0.0 to 1.0+
sfx:set_pan(-0.5)         -- -1.0 (left) to 1.0 (right), 0.0 = center

-- Fade effects
music:fade_in(2000)        -- fade in over 2 seconds
music:fade_out(1000)       -- fade out over 1 second

-- Master volume (affects all sounds)
engine.audio.set_master_volume(0.8)

-- Stop everything
engine.audio.stop_all()
```

Sound handles are automatically cleaned up by Lua's garbage collector.
If no audio device is available (SSH, containers), audio is silently disabled.

## Timers & Tweens (Phase 5 — Available Now)

```lua
-- One-shot timer: fires callback after delay
local handle = engine.timer.after(2.0, function()
    show_title()
end)

-- Repeating timer: fires every interval
local blinker = engine.timer.every(0.5, function()
    cursor_visible = not cursor_visible
end)

-- Cancel a timer
engine.timer.cancel(handle)

-- Tween: smoothly interpolate table fields over time
-- Reads current values as start, interpolates to target values
engine.tween(camera, { x = 100, y = 50 }, 0.3)                -- linear (default)
engine.tween(camera, { x = 100, y = 50 }, 0.3, "ease_out")    -- with easing
engine.tween(sprite, { x = 200 }, 1.0, "ease_in_out", function()
    print("tween done!")  -- optional on_complete callback
end)

-- Easing functions: "linear", "ease_in", "ease_out", "ease_in_out" (all quadratic)
```

Timers and tweens are ticked automatically by the engine each frame.
Timer/tween handles are integers (not userdata).

## Persistence (Phase 5 — Available Now)

### Simple Key-Value (engine.save)

Auto-creates `save.db` in the game directory on first use.

```lua
-- Save values (strings, numbers, booleans — stored as strings)
engine.save.set("high_score", "9001")
engine.save.set("player_name", "Ada")

-- Load values (returns string or nil)
local score = engine.save.get("high_score")   -- "9001" or nil
local name = engine.save.get("player_name")   -- "Ada" or nil

-- Delete by setting nil or empty string
engine.save.set("temp_data", nil)
```

### Raw SQLite (engine.db)

For games that need full relational storage.

```lua
-- Open database (path relative to game directory)
local db = engine.db.open("data.db")

-- Execute statements with bind parameters
db:exec("CREATE TABLE IF NOT EXISTS saves (slot INTEGER, data TEXT)")
db:exec("INSERT INTO saves VALUES (?, ?)", 1, "hello world")

-- Query — returns array of row tables
local rows = db:query("SELECT * FROM saves WHERE slot = ?", 1)
for i, row in ipairs(rows) do
    print(row.slot, row.data)  -- columns accessed by name
end

-- Close (also called automatically on GC)
db:close()
```

Bind parameters support: integers, floats, strings, and nil (SQL NULL).

## Tilemap (Phase 5 — Available Now)

Draw tile-based maps using a sprite sheet as tileset. The engine handles
viewport culling and scrolling.

```lua
-- Load a sprite sheet as tileset (same as load_spritesheet)
local tileset = engine.graphics.load_spritesheet("assets/tiles.png", 8, 8)

-- Build map data: flat 1D array of tile indices (row-major, 1-based; 0 = empty)
local map = {}
for i = 1, 40 * 30 do
    map[i] = math.random(1, 4)  -- random tiles
end

-- Draw tilemap with scrolling camera
engine.graphics.draw_tilemap(tileset, map, {
    width = 40,        -- map width in tiles (required)
    cam_x = 120.5,     -- camera X offset in pixels (sub-pixel for smooth scrolling)
    cam_y = 80.0,      -- camera Y offset in pixels
    layer = 0,         -- compositor layer (0-7)
})
```

Map height is derived from `#map / width`. Only visible tiles are rendered.

## Engine Control

```lua
engine.quit_game()  -- signals the engine to exit
```
