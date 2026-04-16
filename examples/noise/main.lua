-- Noise demo: side-by-side Lua vs Zig simplex noise.
-- Press TAB to toggle. Watch the FPS.

----------------------------------------------------------------------
-- Pure-Lua simplex2d (same algorithm as noise.zig)
----------------------------------------------------------------------

local F2 = 0.5 * (math.sqrt(3.0) - 1.0)
local G2 = (3.0 - math.sqrt(3.0)) / 6.0
local floor = math.floor

local grad = {
	{ 1, 1 },
	{ -1, 1 },
	{ 1, -1 },
	{ -1, -1 },
	{ 1, 0 },
	{ -1, 0 },
	{ 0, 1 },
	{ 0, -1 },
	{ 1, 1 },
	{ -1, 1 },
	{ 1, -1 },
	{ -1, -1 },
}

local p = {
	151,
	160,
	137,
	91,
	90,
	15,
	131,
	13,
	201,
	95,
	96,
	53,
	194,
	233,
	7,
	225,
	140,
	36,
	103,
	30,
	69,
	142,
	8,
	99,
	37,
	240,
	21,
	10,
	23,
	190,
	6,
	148,
	247,
	120,
	234,
	75,
	0,
	26,
	197,
	62,
	94,
	252,
	219,
	203,
	117,
	35,
	11,
	32,
	57,
	177,
	33,
	88,
	237,
	149,
	56,
	87,
	174,
	20,
	125,
	136,
	171,
	168,
	68,
	175,
	74,
	165,
	71,
	134,
	139,
	48,
	27,
	166,
	77,
	146,
	158,
	231,
	83,
	111,
	229,
	122,
	60,
	211,
	133,
	230,
	220,
	105,
	92,
	41,
	55,
	46,
	245,
	40,
	244,
	102,
	143,
	54,
	65,
	25,
	63,
	161,
	1,
	216,
	80,
	73,
	209,
	76,
	132,
	187,
	208,
	89,
	18,
	169,
	200,
	196,
	135,
	130,
	116,
	188,
	159,
	86,
	164,
	100,
	109,
	198,
	173,
	186,
	3,
	64,
	52,
	217,
	226,
	250,
	124,
	123,
	5,
	202,
	38,
	147,
	118,
	126,
	255,
	82,
	85,
	212,
	207,
	206,
	59,
	227,
	47,
	16,
	58,
	17,
	182,
	189,
	28,
	42,
	223,
	183,
	170,
	213,
	119,
	248,
	152,
	2,
	44,
	154,
	163,
	70,
	221,
	153,
	101,
	155,
	167,
	43,
	172,
	9,
	129,
	22,
	39,
	253,
	19,
	98,
	108,
	110,
	79,
	113,
	224,
	232,
	178,
	185,
	112,
	104,
	218,
	246,
	97,
	228,
	251,
	34,
	242,
	193,
	238,
	210,
	144,
	12,
	191,
	179,
	162,
	241,
	81,
	51,
	145,
	235,
	249,
	14,
	239,
	107,
	49,
	192,
	214,
	31,
	181,
	199,
	106,
	157,
	184,
	84,
	204,
	176,
	115,
	121,
	50,
	45,
	127,
	4,
	150,
	254,
	138,
	236,
	205,
	93,
	222,
	114,
	67,
	29,
	24,
	72,
	243,
	141,
	128,
	195,
	78,
	66,
	215,
	61,
	156,
	180,
}

local perm = {}
for i = 0, 511 do
	perm[i] = p[(i % 256) + 1]
end

local function lua_simplex2d(xin, yin)
	local s = (xin + yin) * F2
	local i = floor(xin + s)
	local j = floor(yin + s)

	local t = (i + j) * G2
	local x0 = xin - (i - t)
	local y0 = yin - (j - t)

	local i1, j1
	if x0 > y0 then
		i1, j1 = 1, 0
	else
		i1, j1 = 0, 1
	end

	local x1 = x0 - i1 + G2
	local y1 = y0 - j1 + G2
	local x2 = x0 - 1.0 + 2.0 * G2
	local y2 = y0 - 1.0 + 2.0 * G2

	local ii = i % 256
	local jj = j % 256
	-- handle negative mod
	if ii < 0 then
		ii = ii + 256
	end
	if jj < 0 then
		jj = jj + 256
	end

	local n = 0

	local d = 0.5 - x0 * x0 - y0 * y0
	if d > 0 then
		d = d * d
		local gi = perm[ii + perm[jj]] % 12 + 1
		n = n + d * d * (grad[gi][1] * x0 + grad[gi][2] * y0)
	end

	d = 0.5 - x1 * x1 - y1 * y1
	if d > 0 then
		d = d * d
		local gi = perm[ii + i1 + perm[jj + j1]] % 12 + 1
		n = n + d * d * (grad[gi][1] * x1 + grad[gi][2] * y1)
	end

	d = 0.5 - x2 * x2 - y2 * y2
	if d > 0 then
		d = d * d
		local gi = perm[ii + 1 + perm[jj + 1]] % 12 + 1
		n = n + d * d * (grad[gi][1] * x2 + grad[gi][2] * y2)
	end

	return 70.0 * n
end

----------------------------------------------------------------------
-- Demo
----------------------------------------------------------------------

local W, H = 320, 180
local time = 0
local use_zig = true
local pixels = {}

engine.debug = true

-- Color: map noise [-1,1] -> RGB via hue rotation
local function noise_to_color(val, hue_shift)
	local t = (val + 1) * 0.5 -- [0, 1]
	-- HSV with varying hue, high saturation, value from noise
	local h = (t * 0.6 + hue_shift) % 1.0
	local s = 0.8
	local v = 0.3 + t * 0.7

	local i = floor(h * 6)
	local f = h * 6 - i
	local pp = v * (1 - s)
	local q = v * (1 - f * s)
	local u = v * (1 - (1 - f) * s)

	local r, g, b
	local m = i % 6
	if m == 0 then
		r, g, b = v, u, pp
	elseif m == 1 then
		r, g, b = q, v, pp
	elseif m == 2 then
		r, g, b = pp, v, u
	elseif m == 3 then
		r, g, b = pp, q, v
	elseif m == 4 then
		r, g, b = u, pp, v
	else
		r, g, b = v, pp, q
	end

	return floor(r * 255) * 65536 + floor(g * 255) * 256 + floor(b * 255)
end

function engine.load()
	engine.graphics.set_resolution(W, H)
	for i = 1, W * H do
		pixels[i] = 0
	end
end

function engine.update(dt)
	time = time + dt

	-- Pick noise function
	local noisefn
	if use_zig then
		noisefn = noise.simplex2d
	else
		noisefn = lua_simplex2d
	end

	-- Fill pixel buffer with animated noise
	local scale = 0.02
	local hue_shift = time * 0.05
	local t_offset = time * 0.3

	local idx = 1
	for y = 0, H - 1 do
		for x = 0, W - 1 do
			local val = noisefn(x * scale + t_offset, y * scale + t_offset * 0.7)
			pixels[idx] = noise_to_color(val, hue_shift)
			idx = idx + 1
		end
	end
end

function engine.draw()
	engine.graphics.set_layer(0)
	engine.graphics.pixel.buffer(pixels, 0, 0, W, H)

	local mode = use_zig and "ZIG" or "LUA"
	local label = string.format("MODE: %s  |  %dx%d = %d calls/frame", mode, W, H, W * H)
	engine.graphics.draw_text(4, 2, label, 0xFFFFFF)
	engine.graphics.draw_text(4, 12, "TAB: toggle  |  ESC: quit", 0xAAAAAA)
end

function engine.on_key(key, action)
	if action ~= "press" then
		return
	end
	if key == "tab" then
		use_zig = not use_zig
	elseif key == "escape" then
		engine.quit()
	end
end
