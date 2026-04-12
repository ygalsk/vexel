-- Scene Demo: Menu -> Game -> Pause
-- Demonstrates Phase 3: scene stack, transitions, input state queries

function engine.load()
    engine.graphics.set_resolution(320, 180)

    engine.scene.register("menu",  require("scenes.menu"))
    engine.scene.register("game",  require("scenes.game"))
    engine.scene.register("pause", require("scenes.pause"))

    engine.scene.push("menu")
end
