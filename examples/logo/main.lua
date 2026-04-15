-- VEXEL logo SDF shader demo
-- 5 phases: SDF reveal, neon glow, plasma, chromatic aberration, CRT glitch
-- Controls: space = next phase, q/escape = quit

local W, H = 1080, 720

local phase_names = { "SDF Reveal", "Neon Glow", "Plasma", "Chromatic", "CRT Glitch" }
local NUM_PHASES = #phase_names
local PHASE_DURATION = 5.0

local time = 0
local phase_idx = 0
local phase_time = 0

engine.debug = true

function engine.load()
    engine.graphics.set_resolution(W, H)
end

function engine.update(dt)
    time = time + dt
    phase_time = phase_time + dt

    if phase_time >= PHASE_DURATION then
        phase_time = phase_time - PHASE_DURATION
        phase_idx = (phase_idx + 1) % NUM_PHASES
    end

end

function engine.draw()
    local progress = phase_time / PHASE_DURATION

    engine.graphics.set_layer(0)
    engine.graphics.pixel.shade("logo", time, phase_idx, progress)

    local remaining = PHASE_DURATION - phase_time
    local label = string.format(
        "VEXEL  [%s]  %.1fs  |  %dx%d",
        phase_names[phase_idx + 1], remaining, W, H
    )
    engine.graphics.draw_text(1, 0, label, 0xCCCCCC)
    engine.graphics.draw_text(1, 1, "[space] next  [q] quit", 0x666666)
end

function engine.on_key(key, action)
    if action ~= "press" then return end
    if key == "q" or key == "escape" then
        engine.quit()
    elseif key == "space" then
        phase_time = PHASE_DURATION
    end
end
