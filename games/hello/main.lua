-- Hello World — vexel test game
-- Prints text, responds to keyboard input

local message = "Hello, Vexel!"
local sub_message = "Press arrow keys to move. Press 'q' or Ctrl+C to quit."
local x = 10
local y = 5
local color = 0x00FF88
local frame = 0

function engine.load()
    -- called once at startup
end

function engine.update(dt)
    frame = frame + 1
end

function engine.draw()
    local cols, rows = engine.graphics.get_size()

    -- Draw a colored rectangle behind the text
    engine.graphics.draw_rect(x - 1, y - 1, #message + 2, 3, 0x222244)

    -- Draw the main message
    engine.graphics.draw_text(x, y, message, color, 0x222244)

    -- Draw instructions
    engine.graphics.draw_text(2, rows - 2, sub_message, 0x888888)

    -- Draw position info
    local pos = string.format("pos: %d, %d  frame: %d", x, y, frame)
    engine.graphics.draw_text(2, rows - 1, pos, 0x666666)
end

function engine.on_key(key, action)
    if action ~= "press" then return end

    if key == "left" then
        x = x - 1
    elseif key == "right" then
        x = x + 1
    elseif key == "up" then
        y = y - 1
    elseif key == "down" then
        y = y + 1
    elseif key == "q" then
        engine.quit_game()
    end

    -- Keep in bounds
    local cols, rows = engine.graphics.get_size()
    if x < 0 then x = 0 end
    if y < 0 then y = 0 end
    if x > cols - #message then x = cols - #message end
    if y > rows - 1 then y = rows - 1 end
end

function engine.quit()
    -- cleanup
end
