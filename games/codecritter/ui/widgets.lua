-- Reusable UI widgets for battle screen.
-- pixel.rect for all graphical elements, draw_text for all text.
-- Layout computed from cell grid to guarantee alignment.

local M = {}

local cell_w, cell_h = 8, 18
local total_cols, total_rows = 80, 20
local virt_w, virt_h = 640, 360

function M.init()
  virt_w, virt_h = engine.graphics.get_resolution()
  total_cols, total_rows = engine.graphics.get_size()
  if total_cols > 0 then cell_w = virt_w / total_cols end
  if total_rows > 0 then cell_h = virt_h / total_rows end
end

function M.cols() return total_cols end
function M.rows() return total_rows end

-- Convert between coordinate systems
function M.col_px(c) return math.floor(c * cell_w) end
function M.row_px(r) return math.floor(r * cell_h) end
function M.px_col(x) return math.floor(x / cell_w) end
function M.px_row(y) return math.floor(y / cell_h) end
function M.cell_h() return cell_h end
function M.virt_w() return virt_w end

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

local status_labels = {
  blocked = "BLK", deprecated = "DEP", segfaulted = "SEG",
  linted = "LNT", tilted = "TLT", in_the_zone = "ZON",
  spaghettified = "SPA", enlightened = "ENL", hallucinating = "HAL",
}
local status_colors = {
  blocked = 0x6464DC, deprecated = 0x8C6440, segfaulted = 0xDC3232,
  linted = 0x00C850, tilted = 0xDCA000, in_the_zone = 0xFF96C8,
  spaghettified = 0xB464DC, enlightened = 0xC8C83C, hallucinating = 0xC864B4,
}

-----------------------------------------------------------------------
-- Drawing helpers (all pixel.rect + draw_text, no draw_rect)
-----------------------------------------------------------------------

-- Fill a cell-aligned region with pixel.rect
function M.fill_cells(col, row, w_cells, h_cells, color)
  engine.graphics.pixel.rect(M.col_px(col), M.row_px(row),
    M.col_px(w_cells), M.row_px(h_cells), color)
end

-- Text at cell position
function M.text(col, row, str, fg, bg)
  engine.graphics.draw_text(col, row, str, fg or 0xDCDCDC, bg)
end

-----------------------------------------------------------------------
-- Info panel widget
-----------------------------------------------------------------------

-- Draws a critter info panel. col/row are cell coordinates.
-- 3 cell rows tall:
--   Row 0: Name  Lv##           HP/MAX
--   Row 1: [TYPE]  ARCHETYPE     [STATUS]
--   Row 2: ████████░░░░░░░░░ (HP bar)
function M.info_panel(col, row, panel_w, critter, sp_entry, is_boss)
  -- Panel background (pixel.rect for consistent rendering)
  local px = M.col_px(col)
  local py = M.row_px(row)
  local pw = M.col_px(panel_w)
  local ph = M.row_px(3)
  engine.graphics.pixel.rect(px, py, pw, ph, 0x14141E)
  -- Borders
  engine.graphics.pixel.rect(px, py, pw, 1, 0x505064)
  engine.graphics.pixel.rect(px, py + ph - 1, pw, 1, 0x505064)
  engine.graphics.pixel.rect(px, py, 1, ph, 0x505064)
  engine.graphics.pixel.rect(px + pw - 1, py, 1, ph, 0x505064)

  -- Row 0: name + level (left), HP fraction (right)
  local hp_str = critter.hp .. "/" .. critter.max_hp
  M.text(col + 1, row, critter.name .. "  Lv" .. critter.level, 0xDCDCDC)
  M.text(col + panel_w - #hp_str - 1, row, hp_str, 0xAAAAAA)

  -- Row 1: type badge + archetype (left), status icon (right)
  local type_name = critter.critter_type or "debug"
  local type_col = M.type_colors[type_name] or 0x808080
  M.text(col + 1, row + 1, type_name:upper(), 0x000000, type_col)

  local arch_start = col + 1 + #type_name + 1
  if is_boss and sp_entry then
    M.text(arch_start, row + 1, "BOSS - " .. (sp_entry.archetype or ""):upper(), 0xFF6644)
  elseif sp_entry then
    M.text(arch_start, row + 1, (sp_entry.archetype or ""):upper(), 0x666688)
  end

  if critter.status then
    local slabel = status_labels[critter.status] or "???"
    local scol = status_colors[critter.status] or 0x969696
    M.text(col + panel_w - #slabel - 1, row + 1, slabel, 0x000000, scol)
  end

  -- Row 2: HP bar (pixel.rect for smooth fill, vertically centered in the cell)
  local bar_x = M.col_px(col + 1)
  local bar_y = M.row_px(row + 2) + math.floor(cell_h * 0.25)
  local bar_w = M.col_px(panel_w - 2)
  local bar_h = math.max(3, math.floor(cell_h * 0.5))
  local pct = critter.hp / math.max(1, critter.max_hp)
  local bar_color
  if pct > 0.5 then bar_color = 0x3CC83C
  elseif pct > 0.25 then bar_color = 0xDCC800
  else bar_color = 0xC83232 end

  engine.graphics.pixel.rect(bar_x, bar_y, bar_w, bar_h, 0x282828)
  local fill = math.floor(bar_w * pct)
  if fill > 0 then
    engine.graphics.pixel.rect(bar_x, bar_y, fill, bar_h, bar_color)
  end
end

-----------------------------------------------------------------------
-- Message panel
-----------------------------------------------------------------------

function M.message_panel(row, messages, floor_str)
  M.fill_cells(0, row, total_cols, 2, 0x14141E)
  -- Bottom border
  engine.graphics.pixel.rect(0, M.row_px(row + 2) - 1, virt_w, 1, 0x505064)

  local start = math.max(1, #messages - 1)
  for i = start, math.min(start + 1, #messages) do
    local msg = messages[i]
    M.text(1, row + (i - start), msg.text, msg.color or 0xDCDCDC)
  end

  if floor_str then
    M.text(total_cols - #floor_str - 1, row + 1, floor_str, 0x666688)
  end
end

-----------------------------------------------------------------------
-- Menu widgets
-----------------------------------------------------------------------

function M.menu_bar(row, labels, cursor)
  local menu_h = total_rows - row
  M.fill_cells(0, row, total_cols, menu_h, 0x14141E)
  engine.graphics.pixel.rect(0, M.row_px(row), virt_w, 1, 0x505064)

  local item_w = math.floor(total_cols / #labels)
  local text_row = row + math.max(0, math.floor(menu_h / 2))

  for i, label in ipairs(labels) do
    local x = (i - 1) * item_w
    if i == cursor then
      M.fill_cells(x, row, item_w, menu_h, 0x334466)
    end
    local color = (i == cursor) and 0xFFFFFF or 0x888888
    M.text(x + 2, text_row, i .. "  " .. label, color)
  end
end

function M.submenu_list(row, items, cursor, back_label)
  local menu_h = total_rows - row
  M.fill_cells(0, row, total_cols, menu_h, 0x14141E)
  engine.graphics.pixel.rect(0, M.row_px(row), virt_w, 1, 0x505064)

  local max_vis = math.max(1, menu_h - 1)
  local vis_start = math.max(1, cursor - math.floor(max_vis / 2))
  vis_start = math.min(vis_start, math.max(1, #items - max_vis + 1))
  local vis_end = math.min(#items, vis_start + max_vis - 1)

  for vi = vis_start, vis_end do
    local slot = vi - vis_start
    local item = items[vi]
    local color = (vi == cursor) and 0xFFFFFF or 0x888888
    if item.color then color = item.color end
    if vi == cursor then
      M.fill_cells(0, row + slot, total_cols, 1, 0x1E2A3E)
    end
    if item.type_color then
      M.text(2, row + slot, "\u{25CF}", item.type_color)
      M.text(4, row + slot, item.text, color)
    else
      M.text(2, row + slot, item.text, color)
    end
    if item.detail then
      M.text(total_cols - #item.detail - 2, row + slot, item.detail,
        (vi == cursor) and 0xCCCCCC or 0x555566)
    end
  end

  if vis_start > 1 then M.text(total_cols - 3, row, "^", 0x555566) end
  if vis_end < #items then M.text(total_cols - 3, row + max_vis - 1, "v", 0x555566) end
  M.text(1, row + menu_h - 1, back_label or "[B] Back", 0x555566)
end

function M.move_menu(row, move_items, cursor, back_label)
  local menu_h = total_rows - row
  M.fill_cells(0, row, total_cols, menu_h, 0x14141E)
  engine.graphics.pixel.rect(0, M.row_px(row), virt_w, 1, 0x505064)

  local count = #move_items
  local item_w = math.floor(total_cols / math.max(1, count))

  for i, m in ipairs(move_items) do
    local x = (i - 1) * item_w
    if i == cursor then
      M.fill_cells(x, row, item_w, menu_h - 1, 0x1E2A3E)
    end
    local color = (i == cursor) and 0xFFFFFF or 0x888888
    if m.type_color then
      M.text(x + 1, row, "\u{25CF}", m.type_color)
      M.text(x + 3, row, m.name, color)
    else
      M.text(x + 1, row, m.name, color)
    end
    if m.detail then
      M.text(x + 1, row + 1, m.detail, (i == cursor) and 0xCCCCCC or 0x555566)
    end
  end

  M.text(1, row + menu_h - 1, back_label or "[B] Back", 0x555566)
end

return M
