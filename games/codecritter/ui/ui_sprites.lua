-- UI sprite asset loader for battle screen and future screens.
-- Loads sprites from assets/ui/ (extracted from Pixel UI pack 3).

local M = {}
local handles = {}

function M.load()
  -- HP bars: 6 fill states each (frame 0 = full, frame 5 = empty)
  -- 42x11 per frame, use scale=2 for 84x22 display
  handles.hp_bar_red    = engine.graphics.load_spritesheet("assets/ui/hp_bar_red.png", 42, 11)
  handles.hp_bar_yellow = engine.graphics.load_spritesheet("assets/ui/hp_bar_yellow.png", 42, 11)
  handles.hp_bar_blue   = engine.graphics.load_spritesheet("assets/ui/hp_bar_blue.png", 42, 11)

  -- Segmented bars: 6 fill states, 27x8 per frame
  handles.hp_bar_green  = engine.graphics.load_spritesheet("assets/ui/hp_bar_green.png", 27, 8)
  handles.hp_bar_orange = engine.graphics.load_spritesheet("assets/ui/hp_bar_orange.png", 27, 8)

  -- Dark button: single image, 48x26
  handles.btn_dark  = engine.graphics.load_image("assets/ui/btn_dark.png")
  handles.btn_dark2 = engine.graphics.load_image("assets/ui/btn_dark2.png")

  -- Badges
  handles.badge_boss = engine.graphics.load_image("assets/ui/badge_boss.png")
  handles.badge_blue = engine.graphics.load_image("assets/ui/badge_blue.png")

  -- Stars: individual images, 14x16 each
  -- 0=gray, 1=gray-half, 2=gold-half, 3=gold
  handles.star_0 = engine.graphics.load_image("assets/ui/star_0.png")
  handles.star_1 = engine.graphics.load_image("assets/ui/star_1.png")
  handles.star_2 = engine.graphics.load_image("assets/ui/star_2.png")
  handles.star_3 = engine.graphics.load_image("assets/ui/star_3.png")
end

function M.get(name)
  return handles[name]
end

function M.unload()
  for _, h in pairs(handles) do
    pcall(engine.graphics.unload_image, h)
  end
  handles = {}
end

return M
