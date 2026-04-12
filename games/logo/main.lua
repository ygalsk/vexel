-- VEXEL logo animation demo
-- Cycles through animation phases: scan lines, glow pulse, pixel dissolve, color wave.
-- Controls: q = quit, space = skip to next phase

local W, H = 1920, 1080

-- Block-letter pixel font for "VEXEL" (each letter is 7 wide x 9 tall)
-- 1 = filled pixel, 0 = empty
local font = {
    V = {
        "1.....1",
        "1.....1",
        "1.....1",
        ".1...1.",
        ".1...1.",
        "..1.1..",
        "..1.1..",
        "...1...",
        "...1...",
    },
    E = {
        "1111111",
        "1......",
        "1......",
        "1......",
        "111111.",
        "1......",
        "1......",
        "1......",
        "1111111",
    },
    X = {
        "1.....1",
        ".1...1.",
        "..1.1..",
        "...1...",
        "...1...",
        "...1...",
        "..1.1..",
        ".1...1.",
        "1.....1",
    },
    L = {
        "1......",
        "1......",
        "1......",
        "1......",
        "1......",
        "1......",
        "1......",
        "1......",
        "1111111",
    },
}

-- Parse font into block-level coordinates (one entry per font cell, not per sub-pixel)
local letter_order = {"V", "E", "X", "E", "L"}
local SCALE = 16
local LETTER_W = 7 * SCALE
local LETTER_H = 9 * SCALE
local GAP = 2 * SCALE
local total_w = #letter_order * LETTER_W + (#letter_order - 1) * GAP
local start_x = math.floor((W - total_w) / 2)
local start_y = math.floor((H - LETTER_H) / 2)

-- One entry per font cell (~125 blocks total instead of ~32K pixels)
local blocks = {}
local letter_centers = {}

for li, ch in ipairs(letter_order) do
    local lx = start_x + (li - 1) * (LETTER_W + GAP)
    letter_centers[li] = lx + LETTER_W / 2
    local rows = font[ch]
    for row_i, row_str in ipairs(rows) do
        for col_i = 1, #row_str do
            if row_str:sub(col_i, col_i) == "1" then
                local bx = lx + (col_i - 1) * SCALE
                local by = start_y + (row_i - 1) * SCALE
                table.insert(blocks, {
                    x = bx, y = by,
                    letter = li,
                    nx = (bx - start_x) / total_w,
                })
            end
        end
    end
end

-- Animation state
local phases = {"scanline", "glow", "dissolve", "wave"}
local phase_idx = 1
local phase_time = 0
local PHASE_DURATION = 5.0

-- Dissolve particles (one per block)
local particles = nil

local function init_particles()
    particles = {}
    for i, b in ipairs(blocks) do
        local angle = math.random() * 6.2832
        local dist = 80 + math.random() * 200
        particles[i] = {
            x = b.x, y = b.y,
            home_x = b.x, home_y = b.y,
            target_x = b.x + math.cos(angle) * dist,
            target_y = b.y + math.sin(angle) * dist,
            speed = 0.5 + math.random() * 1.5,
        }
    end
end

-- Base color for letters
local BASE_COLOR = 0x44BBFF

local function hsv_to_rgb(h, s, v)
    h = h % 1.0
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then return v, t, p
    elseif i == 1 then return q, v, p
    elseif i == 2 then return p, v, t
    elseif i == 3 then return p, q, v
    elseif i == 4 then return t, p, v
    else return v, p, q end
end

local function rgb_hex(r, g, b)
    return math.floor(r * 255) * 65536 + math.floor(g * 255) * 256 + math.floor(b * 255)
end

function engine.load()
    engine.graphics.set_resolution(W, H)
    math.randomseed(os.time())
end

function engine.update(dt)
    phase_time = phase_time + dt

    if phase_time >= PHASE_DURATION then
        phase_time = phase_time - PHASE_DURATION
        phase_idx = (phase_idx % #phases) + 1
        particles = nil
    end

    local phase = phases[phase_idx]

    if phase == "dissolve" then
        if not particles then init_particles() end
        local t = phase_time / PHASE_DURATION
        for _, p in ipairs(particles) do
            if t < 0.5 then
                local prog = math.min(t * 2, 1.0) * p.speed
                p.x = p.home_x + (p.target_x - p.home_x) * prog
                p.y = p.home_y + (p.target_y - p.home_y) * prog
            else
                local prog = math.min((t - 0.5) * 2, 1.0) * p.speed
                prog = math.min(prog, 1.0)
                p.x = p.target_x + (p.home_x - p.target_x) * prog
                p.y = p.target_y + (p.home_y - p.target_y) * prog
            end
        end
    end
end

function engine.draw()
    -- Layer 0: dark background
    engine.graphics.set_layer(0)
    engine.graphics.pixel.clear()
    engine.graphics.pixel.rect(0, 0, W, H, 0x0a0a1a)

    local phase = phases[phase_idx]
    local t = phase_time / PHASE_DURATION
    local S = SCALE

    if phase == "scanline" then
        -- Letters reveal top-to-bottom with scan line
        local scan_y = start_y + math.floor(t * LETTER_H * 1.3)

        -- Glow line
        engine.graphics.set_layer(1)
        engine.graphics.pixel.clear()
        if scan_y >= start_y and scan_y < start_y + LETTER_H then
            engine.graphics.pixel.rect(start_x - 20, scan_y - 1, total_w + 40, 3, 0x88DDFF)
            engine.graphics.pixel.rect(start_x - 10, scan_y - 3, total_w + 20, 2, 0x224466)
            engine.graphics.pixel.rect(start_x - 10, scan_y + 2, total_w + 20, 2, 0x224466)
        end

        -- Draw revealed blocks
        engine.graphics.set_layer(2)
        engine.graphics.pixel.clear()
        for _, b in ipairs(blocks) do
            if b.y + S <= scan_y then
                engine.graphics.pixel.rect(b.x, b.y, S, S, BASE_COLOR)
            elseif b.y <= scan_y then
                -- Block partially revealed — bright flash
                local visible_h = scan_y - b.y
                engine.graphics.pixel.rect(b.x, b.y, S, visible_h, 0x88DDFF)
            end
        end

    elseif phase == "glow" then
        -- Pulsing glow behind each letter
        engine.graphics.set_layer(1)
        engine.graphics.pixel.clear()
        local pulse = 0.5 + 0.5 * math.sin(phase_time * 3.0)
        local glow_r = math.floor((12 + pulse * 25) * (SCALE / 4))
        for li, cx in ipairs(letter_centers) do
            local cy = start_y + LETTER_H / 2
            local letter_pulse = 0.5 + 0.5 * math.sin(phase_time * 3.0 - li * 0.8)
            local r = math.floor(glow_r * letter_pulse)
            if r > 4 then
                engine.graphics.pixel.circle(cx, cy, r, 0x112244)
                if r > 12 then
                    engine.graphics.pixel.circle(cx, cy, math.floor(r * 0.6), 0x1a3366)
                end
            end
        end

        -- Draw letter blocks with brightness modulation
        engine.graphics.set_layer(2)
        engine.graphics.pixel.clear()
        for _, b in ipairs(blocks) do
            local letter_pulse = 0.7 + 0.3 * math.sin(phase_time * 3.0 - b.letter * 0.8)
            local r = math.min(255, math.floor(0x44 * letter_pulse))
            local g = math.min(255, math.floor(0xBB * letter_pulse))
            local bv = math.min(255, math.floor(0xFF * letter_pulse))
            engine.graphics.pixel.rect(b.x, b.y, S, S, r * 65536 + g * 256 + bv)
        end

    elseif phase == "dissolve" then
        -- Blocks scatter and reform
        engine.graphics.set_layer(1)
        engine.graphics.pixel.clear()
        engine.graphics.set_layer(2)
        engine.graphics.pixel.clear()

        if particles then
            for _, p in ipairs(particles) do
                local px = math.floor(p.x + 0.5)
                local py = math.floor(p.y + 0.5)
                if px >= -S and px < W and py >= -S and py < H then
                    engine.graphics.pixel.rect(px, py, S, S, BASE_COLOR)
                end
            end
        end

    elseif phase == "wave" then
        -- Rainbow color wave sweeping across letters
        engine.graphics.set_layer(1)
        engine.graphics.pixel.clear()
        engine.graphics.set_layer(2)
        engine.graphics.pixel.clear()

        for _, b in ipairs(blocks) do
            local hue = b.nx + phase_time * 0.4
            local r, g, bv = hsv_to_rgb(hue, 0.7, 1.0)
            engine.graphics.pixel.rect(b.x, b.y, S, S, rgb_hex(r, g, bv))
        end
    end

    -- Phase indicator
    local phase_name = phase:sub(1,1):upper() .. phase:sub(2)
    engine.graphics.draw_text(1, 0,
        string.format("VEXEL  [%s]  %.1fs", phase_name, PHASE_DURATION - phase_time),
        0xCCCCCC)
    engine.graphics.draw_text(1, 1, "[space] next  [q] quit", 0x666666)
end

function engine.on_key(key, action)
    if action ~= "press" then return end
    if key == "q" then
        engine.quit_game()
    elseif key == "space" then
        phase_time = PHASE_DURATION  -- trigger next phase
        particles = nil
    end
end
