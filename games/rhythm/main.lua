-- Rhythm Game — vexel audio test game (Phase 4)
-- Demonstrates: music streaming, SFX playback, volume control, panning, fade

local music = nil
local sfx_hit = nil
local sfx_miss = nil

local volume = 0.7
local pan = 0.0
local music_playing = false

-- Note lanes: D, F, J, K
local lanes = {"d", "f", "j", "k"}
local lane_labels = {"D", "F", "J", "K"}
local lane_colors = {0xFF4444, 0x44FF44, 0x4488FF, 0xFFFF44}
local lane_flash = {0, 0, 0, 0}

-- Notes falling down
local notes = {}
local scroll_speed = 80
local spawn_timer = 0
local spawn_interval = 0.6
local score = 0
local combo = 0
local hit_zone_y = 150

function engine.load()
    engine.graphics.set_resolution(320, 180)

    -- Load music (streaming for large files)
    music = engine.audio.load("../../assets/music/16-Bit Beat Em All _Clement Panchout.wav", {stream = true})
    -- Load SFX (preloaded for low latency) — reuse short segments of music as SFX stand-ins
    sfx_hit = engine.audio.load("../../assets/music/Clement Panchout _ Jelly Blob _ 2017.wav")
    sfx_miss = engine.audio.load("../../assets/music/Clement Panchout _ Dark _ 2004.wav")

    -- Start background music
    music:play({loop = true, volume = volume})
    music_playing = true
end

function engine.update(dt)
    -- Spawn notes
    spawn_timer = spawn_timer + dt
    if spawn_timer >= spawn_interval then
        spawn_timer = spawn_timer - spawn_interval
        local lane = math.random(1, #lanes)
        table.insert(notes, {lane = lane, y = 0})
    end

    -- Move notes down
    for i = #notes, 1, -1 do
        notes[i].y = notes[i].y + scroll_speed * dt
        -- Remove notes that fall past the screen
        if notes[i].y > 180 then
            combo = 0
            table.remove(notes, i)
        end
    end

    -- Decay lane flash
    for i = 1, #lanes do
        if lane_flash[i] > 0 then
            lane_flash[i] = lane_flash[i] - dt * 4
            if lane_flash[i] < 0 then lane_flash[i] = 0 end
        end
    end
end

function engine.draw()
    local w, h = engine.graphics.get_pixel_size()

    -- Draw lane backgrounds
    local lane_width = 30
    local start_x = 100
    for i = 1, #lanes do
        local lx = start_x + (i - 1) * (lane_width + 4)
        local brightness = math.floor(lane_flash[i] * 80)
        local bg = brightness * 0x010101
        engine.graphics.pixel.rect(lx, 0, lane_width, 180, bg + 0x111111)
    end

    -- Draw hit zone
    for i = 1, #lanes do
        local lx = start_x + (i - 1) * (lane_width + 4)
        engine.graphics.pixel.rect(lx, hit_zone_y - 2, lane_width, 4, 0x666666)
    end

    -- Draw notes
    for _, note in ipairs(notes) do
        local lx = start_x + (note.lane - 1) * (lane_width + 4)
        local ny = math.floor(note.y)
        engine.graphics.pixel.rect(lx + 2, ny, lane_width - 4, 8, lane_colors[note.lane])
    end

    -- Draw lane labels
    for i = 1, #lanes do
        local col = math.floor((start_x + (i - 1) * (lane_width + 4)) / 8) + 1
        local row = 22
        engine.graphics.draw_text(col, row, lane_labels[i], lane_colors[i])
    end

    -- HUD
    engine.graphics.draw_text(1, 1, string.format("Score: %d", score), 0xFFFFFF)
    engine.graphics.draw_text(1, 2, string.format("Combo: %d", combo), 0xFFFF88)
    engine.graphics.draw_text(1, 4, string.format("Vol: %.0f%%", volume * 100), 0xAAAAAA)
    engine.graphics.draw_text(1, 5, string.format("Pan: %.1f", pan), 0xAAAAAA)

    -- Controls
    engine.graphics.draw_text(1, 20, "[D/F/J/K] Hit", 0x888888)
    engine.graphics.draw_text(1, 21, "[Up/Down] Volume", 0x888888)
    engine.graphics.draw_text(1, 22, "[Left/Right] Pan", 0x888888)
end

function engine.on_key(key, action)
    if action ~= "press" then return end

    -- Lane hits
    for i, lane_key in ipairs(lanes) do
        if key == lane_key then
            lane_flash[i] = 1.0
            local hit = false
            for j = #notes, 1, -1 do
                if notes[j].lane == i and math.abs(notes[j].y - hit_zone_y) < 15 then
                    -- Hit!
                    table.remove(notes, j)
                    combo = combo + 1
                    score = score + 10 * combo
                    -- Play hit SFX with panning based on lane position
                    local sfx_pan = -0.6 + (i - 1) * 0.4
                    sfx_hit:stop()
                    sfx_hit:set_pan(sfx_pan)
                    sfx_hit:set_volume(0.3)
                    sfx_hit:play()
                    hit = true
                    break
                end
            end
            if not hit then
                combo = 0
                sfx_miss:stop()
                sfx_miss:set_volume(0.15)
                sfx_miss:play()
            end
            return
        end
    end

    -- Volume control
    if key == "up" then
        volume = math.min(1.0, volume + 0.1)
        engine.audio.set_master_volume(volume)
    elseif key == "down" then
        volume = math.max(0.0, volume - 0.1)
        engine.audio.set_master_volume(volume)
    -- Pan control
    elseif key == "left" then
        pan = math.max(-1.0, pan - 0.2)
        music:set_pan(pan)
    elseif key == "right" then
        pan = math.min(1.0, pan + 0.2)
        music:set_pan(pan)
    -- Space: pause/resume music
    elseif key == "space" then
        if music_playing then
            music:pause()
            music_playing = false
        else
            music:resume()
            music_playing = true
        end
    elseif key == "q" then
        engine.quit_game()
    end
end

function engine.quit()
    engine.audio.stop_all()
end
