-- Compositor upload benchmark: small animated rect + static background
-- Most frames should be partial (P) — only the moving rect is dirty.
local W, H = 1920, 1080
engine.debug = true

local t = 0
local BOX = 200  -- size of the animated rect

function engine.load()
    engine.graphics.set_resolution(W, H)
    -- Static dark background on layer 0
    engine.graphics.set_layer(0)
    engine.graphics.pixel.rect(0, 0, W, H, 0x111111)
end

function engine.update(dt)
    t = t + dt
end

function engine.draw()
    -- Animated rect on layer 1: moves in a circle, changes color
    local cx = W / 2 + math.floor(math.sin(t * 0.7) * (W / 2 - BOX))
    local cy = H / 2 + math.floor(math.cos(t * 0.5) * (H / 2 - BOX))
    local r = math.floor((math.sin(t) * 0.5 + 0.5) * 255)
    local g = math.floor((math.cos(t * 1.3) * 0.5 + 0.5) * 255)
    engine.graphics.set_layer(1)
    engine.graphics.pixel.clear()
    engine.graphics.pixel.rect(cx, cy, BOX, BOX, r * 0x10000 + g * 0x100)
end

function engine.on_key(key, action)
    if key == "escape" and action == "press" then engine.quit() end
end
