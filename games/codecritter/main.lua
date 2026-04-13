-- Phase 9.2: Battle screen integration test

local stat    = require("critter.stats")
local species = require("data.species")
local items   = require("data.items")

function engine.load()
  engine.graphics.set_resolution(640, 360)
  math.randomseed(os.time())

  -- Register scenes
  engine.scene.register("battle", require("ui.battle_screen"))

  -- Build test party and enemy
  local party = {
    stat.make_instance("println",  10, species),
    stat.make_instance("glitch",   8,  species),
  }
  local enemy = stat.make_instance("semaphore", 10, species)

  -- Give player some items
  local inventory = {
    items["print_statement"],
    items["small_patch"],
  }

  -- Start battle
  engine.scene.push("battle", {
    party          = party,
    enemy          = enemy,
    encounter_type = "wild",
    inventory      = inventory,
    biome          = "generic_dungeon",
    floor          = 1,
  })
end
