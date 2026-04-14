-- Boids flocking demo — mouse attraction
-- Up/Down to add/remove boids, q to quit

local W, H = 1280, 720
local COUNT = 100

-- SoA layout
local bx, by = {}, {}
local vx, vy = {}, {}

-- Tuning
local MAX_SPEED = 60
local PERCEPTION = 25
local PERCEPTION_SQ = PERCEPTION * PERCEPTION
local SEP_WEIGHT = 1.5
local ALI_WEIGHT = 1.0
local COH_WEIGHT = 1.0
local MOUSE_WEIGHT = 0.4

-- Spatial hash
local CELL = PERCEPTION -- cell size = perception radius
local GRID_COLS = math.ceil(W / CELL)
local GRID_ROWS = math.ceil(H / CELL)
local grid = {} -- keyed by cell index, value = {count, i1, i2, ...}

-- FPS tracking
local frame_count = 0
local fps_timer = 0
local fps = 0

-- Localize
local sqrt = math.sqrt
local floor, format = math.floor, string.format

local function spawn_boid()
	local n = #bx + 1
	bx[n] = math.random() * W
	by[n] = math.random() * H
	vx[n] = (math.random() * 2 - 1) * MAX_SPEED * 0.5
	vy[n] = (math.random() * 2 - 1) * MAX_SPEED * 0.5
end

local function remove_boid()
	local n = #bx
	if n <= 1 then
		return
	end
	bx[n] = nil
	by[n] = nil
	vx[n] = nil
	vy[n] = nil
end

local function grid_key(col, row)
	return row * GRID_COLS + col
end

local function build_grid(n)
	-- Clear by replacing with fresh table (faster than nilling keys)
	grid = {}
	for i = 1, n do
		local col = floor(bx[i] / CELL)
		local row = floor(by[i] / CELL)
		if col >= GRID_COLS then col = GRID_COLS - 1 end
		if row >= GRID_ROWS then row = GRID_ROWS - 1 end
		local key = grid_key(col, row)
		local cell = grid[key]
		if cell then
			local c = cell[1] + 1
			cell[1] = c
			cell[c + 1] = i
		else
			grid[key] = { 1, i }
		end
	end
end

function engine.load()
	engine.graphics.set_resolution(W, H)
	for _ = 1, COUNT do
		spawn_boid()
	end
end

function engine.update(dt)
	-- FPS
	frame_count = frame_count + 1
	fps_timer = fps_timer + dt
	if fps_timer >= 0.5 then
		fps = floor(frame_count / fps_timer + 0.5)
		frame_count = 0
		fps_timer = 0
	end

	local n = #bx
	if n == 0 then
		return
	end

	build_grid(n)

	-- Mouse: get_mouse() returns cell coords, convert to virtual pixels
	local mcol, mrow = engine.input.get_mouse()
	local cols, rows = engine.graphics.get_size()
	local mx = mcol * W / cols
	local my = mrow * H / rows

	for i = 1, n do
		local px, py = bx[i], by[i]
		local sep_x, sep_y = 0, 0
		local ali_x, ali_y = 0, 0
		local coh_x, coh_y = 0, 0
		local neighbors = 0

		-- Query 9 neighboring cells
		local ci = floor(px / CELL)
		local ri = floor(py / CELL)
		if ci >= GRID_COLS then ci = GRID_COLS - 1 end
		if ri >= GRID_ROWS then ri = GRID_ROWS - 1 end

		for dc = -1, 1 do
			local nc = ci + dc
			if nc >= 0 and nc < GRID_COLS then
				for dr = -1, 1 do
					local nr = ri + dr
					if nr >= 0 and nr < GRID_ROWS then
						local cell = grid[grid_key(nc, nr)]
						if cell then
							local count = cell[1]
							for k = 2, count + 1 do
								local j = cell[k]
								if j ~= i then
									local dx = bx[j] - px
									local dy = by[j] - py
									local d2 = dx * dx + dy * dy
									if d2 < PERCEPTION_SQ and d2 > 0 then
										local d = sqrt(d2)
										sep_x = sep_x - dx / d
										sep_y = sep_y - dy / d
										ali_x = ali_x + vx[j]
										ali_y = ali_y + vy[j]
										coh_x = coh_x + bx[j]
										coh_y = coh_y + by[j]
										neighbors = neighbors + 1
									end
								end
							end
						end
					end
				end
			end
		end

		local ax, ay = 0, 0

		-- Separation
		ax = ax + sep_x * SEP_WEIGHT
		ay = ay + sep_y * SEP_WEIGHT

		if neighbors > 0 then
			-- Alignment: steer toward average velocity
			ali_x = ali_x / neighbors - vx[i]
			ali_y = ali_y / neighbors - vy[i]
			ax = ax + ali_x * ALI_WEIGHT
			ay = ay + ali_y * ALI_WEIGHT

			-- Cohesion: steer toward average position
			coh_x = coh_x / neighbors - px
			coh_y = coh_y / neighbors - py
			ax = ax + coh_x * COH_WEIGHT
			ay = ay + coh_y * COH_WEIGHT
		end

		-- Mouse attraction
		local mdx = mx - px
		local mdy = my - py
		ax = ax + mdx * MOUSE_WEIGHT
		ay = ay + mdy * MOUSE_WEIGHT

		-- Integrate
		vx[i] = vx[i] + ax * dt
		vy[i] = vy[i] + ay * dt

		-- Clamp speed
		local spd = sqrt(vx[i] * vx[i] + vy[i] * vy[i])
		if spd > MAX_SPEED then
			vx[i] = vx[i] / spd * MAX_SPEED
			vy[i] = vy[i] / spd * MAX_SPEED
		end

		-- Move
		bx[i] = (bx[i] + vx[i] * dt) % W
		by[i] = (by[i] + vy[i] * dt) % H
	end
end

function engine.draw()
	engine.graphics.set_layer(0)
	engine.graphics.pixel.clear()
	engine.graphics.pixel.rect(0, 0, W, H, 0x0a0a1a)

	local n = #bx
	for i = 1, n do
		local px, py = bx[i], by[i]

		-- Triangle from normalized velocity (no trig)
		local uvx, uvy = vx[i], vy[i]
		local spd = sqrt(uvx * uvx + uvy * uvy)
		if spd > 0 then
			uvx = uvx / spd
			uvy = uvy / spd
		else
			uvx, uvy = 1, 0
		end

		-- Nose: 4px ahead, wings: 2px back at ~±130°
		local nx = px + 4 * uvx
		local ny = py + 4 * uvy
		-- Perpendicular: (-uvy, uvx)
		local lx = px - 2 * uvx - 1.5 * uvy
		local ly = py - 2 * uvy + 1.5 * uvx
		local rx = px - 2 * uvx + 1.5 * uvy
		local ry = py - 2 * uvy - 1.5 * uvx

		local color = 0x44aaff
		engine.graphics.pixel.line(floor(nx), floor(ny), floor(lx), floor(ly), color)
		engine.graphics.pixel.line(floor(lx), floor(ly), floor(rx), floor(ry), color)
		engine.graphics.pixel.line(floor(rx), floor(ry), floor(nx), floor(ny), color)
	end

	-- HUD
	engine.graphics.draw_text(1, 0, format("boids: %d  fps: %d", n, fps), 0xcccccc)
	engine.graphics.draw_text(1, 1, "up/down: count  q: quit", 0x666666)
end

function engine.on_key(key, action)
	if action ~= "press" then
		return
	end
	if key == "q" or key == "escape" then
		engine.quit()
	elseif key == "up" then
		for _ = 1, 10 do
			spawn_boid()
		end
	elseif key == "down" then
		for _ = 1, 10 do
			remove_boid()
		end
	end
end
