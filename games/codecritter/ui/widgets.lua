-- Reusable UI widgets for battle screen and future screens.
-- All pixel drawing via engine.graphics.pixel.*, text via engine.graphics.draw_text().

local M = {}

local cell_w, cell_h = 8, 18  -- defaults, recalculated in init()

function M.init()
  local px_w, px_h = engine.graphics.get_pixel_size()
  local cols, rows = engine.graphics.get_size()
  if cols > 0 then cell_w = px_w / cols end
  if rows > 0 then cell_h = px_h / rows end
end

local function px_to_col(x) return math.floor(x / cell_w) end
local function px_to_row(y) return math.floor(y / cell_h) end

-- First cell row whose top edge is at or inside a panel starting at pixel y
local function first_row_in(y) return math.ceil(y / cell_h) end

-- Type colors
M.type_colors = {
  debug    = 0x4488DD,
  chaos    = 0xDD4444,
  patience = 0x44AAAA,
  wisdom   = 0xAAAA44,
  snark    = 0xAA44AA,
  vibe     = 0xDD8844,
  legacy   = 0x888844,
}

-- HP bar: green (>50%), yellow (25-50%), red (<25%)
function M.hp_bar(x, y, hp, max_hp, width)
  width = width or 120
  local pct = hp / math.max(1, max_hp)
  local color
  if pct > 0.5 then color = 0x3CC83C
  elseif pct > 0.25 then color = 0xDCC800
  else color = 0xC83232 end
  engine.graphics.pixel.rect(x, y, width, 6, 0x282828)
  local fill = math.floor(width * pct)
  if fill > 0 then
    engine.graphics.pixel.rect(x, y, fill, 6, color)
  end
end

-- Type badge: colored pill with type name
function M.type_badge(x, y, type_name)
  local col = M.type_colors[type_name] or 0x808080
  engine.graphics.pixel.rect(x, y, 48, 12, col)
  engine.graphics.draw_text(px_to_col(x + 2), px_to_row(y + 1), type_name:upper(), 0x000000)
end

-- Archetype badge
function M.archetype_badge(x, y, archetype_name)
  engine.graphics.pixel.rect(x, y, 56, 12, 0x3C3C50)
  engine.graphics.draw_text(px_to_col(x + 2), px_to_row(y + 1), archetype_name, 0xC8C8DC)
end

-- Panel border
function M.panel(x, y, w, h)
  engine.graphics.pixel.rect(x, y, w, h, 0x14141E)
  engine.graphics.pixel.rect(x, y, w, 1, 0x505064)
  engine.graphics.pixel.rect(x, y + h - 1, w, 1, 0x505064)
  engine.graphics.pixel.rect(x, y, 1, h, 0x505064)
  engine.graphics.pixel.rect(x + w - 1, y, 1, h, 0x505064)
end

-- Message log: draws last 2 messages
function M.message_log(x, y, w, messages)
  M.panel(x, y, w, 40)
  local start = math.max(1, #messages - 1)
  for i = start, math.min(start + 1, #messages) do
    local msg = messages[i]
    local row_offset = i - start
    engine.graphics.draw_text(
      px_to_col(x + 6),
      px_to_row(y + 6 + row_offset * 18),
      msg.text,
      msg.color or 0xDCDCDC
    )
  end
end

-- Status icon: abbreviated label
function M.status_icon(x, y, status_name)
  if not status_name then return end
  local labels = {
    blocked = "BLK", deprecated = "DEP", segfaulted = "SEG",
    linted = "LNT", tilted = "TLT", in_the_zone = "ZON",
    spaghettified = "SPA", enlightened = "ENL", hallucinating = "HAL",
  }
  local colors = {
    blocked = 0x6464DC, deprecated = 0x8C6440, segfaulted = 0xDC3232,
    linted = 0x00C850, tilted = 0xDCA000, in_the_zone = 0xFF96C8,
    spaghettified = 0xB464DC, enlightened = 0xC8C83C, hallucinating = 0xC864B4,
  }
  local label = labels[status_name] or "???"
  local col = colors[status_name] or 0x969696
  engine.graphics.pixel.rect(x, y, 28, 10, col)
  engine.graphics.draw_text(px_to_col(x + 2), px_to_row(y), label, 0x000000)
end

-- Draw text at pixel position (convenience wrapper)
function M.text(x, y, str, color)
  engine.graphics.draw_text(px_to_col(x), px_to_row(y), str, color or 0xDCDCDC)
end

-- Draw text inside a panel: row 0 = first cell row inside the panel, row 1 = next, etc.
function M.panel_text(panel_x, panel_y, row_offset, str, color)
  local col = px_to_col(panel_x + 10)
  local row = first_row_in(panel_y) + row_offset
  engine.graphics.draw_text(col, row, str, color or 0xDCDCDC)
end

-- Pixel Y of a row inside a panel (for aligning pixel elements like badges/bars)
function M.panel_row_y(panel_y, row_offset)
  return (first_row_in(panel_y) + row_offset) * cell_h
end

return M
