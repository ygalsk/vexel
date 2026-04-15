-- Swamp Platformer: collect coins, reach the flag
-- Exercises: tilemaps, ECS sprites, platformer physics, parallax scrolling, audio.

local game = require("game")
local player = require("player")

local shared = {}

function engine.load()
    engine.graphics.set_resolution(320, 192)

    shared.tiles_swamp = engine.graphics.load_spritesheet("assets/swamp.png", 32, 32)
    shared.sheet_guy   = engine.graphics.load_spritesheet("assets/guy.png", 32, 32)
    shared.sheet_coin  = engine.graphics.load_spritesheet("assets/coin.png", 10, 10)
    shared.sheet_flag  = engine.graphics.load_spritesheet("assets/flag.png", 48, 48)

    shared.bg = {}
    for i = 1, 5 do
        shared.bg[i] = engine.graphics.load_image("assets/bg" .. i .. ".png")
    end

    local ok, music = pcall(engine.audio.load, "assets/village.wav", { stream = true })
    if ok and music then
        shared.music = music
        shared.music:play({ loop = true, volume = 0.3 })
    end

    player.create(shared)

    engine.scene.register("game", game.new(shared))
    engine.scene.push("game")
end
