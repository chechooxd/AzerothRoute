-- AzerothRoute: draws the skins' art. The Marble skin's (Theme/SkinMarble.lua): a 512x512 warm white marble that
-- tiles, soft beige veins with fine grey cores and thin gold threads, as an uncompressed 32-bit TGA.
--   luajit tools/fork/make_skin_art.lua [OUTDIR]   (default tools/fork/assets/AzerothRoute/Media/UI)
-- Prints the texture's mean brightness, the GRAIN Theme/SkinMarble.lua lifts its colours by.
-- Original AzerothRoute art (GPL-3.0-only).

local bit = require("bit")
local OUT = arg[1] or "tools/fork/assets/AzerothRoute/Media/UI"
local N = 512
local floor, abs, sin, pi, min = math.floor, math.abs, math.sin, math.pi, math.min

-- Value noise on a lattice that wraps every `period` cells, so the picture tiles.
local function hash(x, y, seed)
	local h = bit.bxor(x * 73856093, y * 19349663, seed * 83492791)
	h = bit.bxor(h, bit.rshift(h, 13))
	h = bit.tobit(h * 1274126177)
	h = bit.bxor(h, bit.rshift(h, 16))
	return bit.band(h, 0xffff) / 65535
end
local function smooth(t) return t * t * (3 - 2 * t) end
local function noise(u, v, period, seed)
	local x, y = u * period, v * period
	local ix, iy = floor(x), floor(y)
	local fx, fy = smooth(x - ix), smooth(y - iy)
	local x0, y0, x1, y1 = ix % period, iy % period, (ix + 1) % period, (iy + 1) % period
	local a, b = hash(x0, y0, seed), hash(x1, y0, seed)
	local c, d = hash(x0, y1, seed), hash(x1, y1, seed)
	local top, bottom = a + (b - a) * fx, c + (d - c) * fx
	return top + (bottom - top) * fy
end
local function fbm(u, v, period, seed, octaves)
	local sum, amp, total = 0, 1, 0
	for o = 0, octaves - 1 do
		sum = sum + noise(u, v, period * 2 ^ o, seed + o * 7) * amp
		total = total + amp
		amp = amp * 0.5
	end
	return sum / total
end
local function mix(a, b, t) return a + (b - a) * t end

-- A vein: a band of the stone (integer turns across the tile keep it tiling), bent by the noise.
local function vein(u, v, du, dv, warp, period, seed)
	local w = fbm(u, v, period, seed, 6)
	return 1 - abs(sin(pi * (u * du + v * dv) + warp * w))
end

local pixels, total = {}, 0
for y = 0, N - 1 do
	for x = 0, N - 1 do
		local u, v = x / N, y / N
		local cloud = fbm(u, v, 2, 11, 5)
		-- Broad soft beige veins with a fine grey core.
		local a = vein(u, v, 1, 2, 11, 3, 23)
		local soft, core = a ^ 7, a ^ 60
		-- A second, fainter family across them.
		local b2 = vein(u, v, 2, -1, 9, 3, 41)
		local faint = b2 ^ 40 * 0.6
		-- Thin gold threads where a third band peaks, in patches.
		local g = vein(u, v, 3, 1, 13, 4, 57)
		local gold = g ^ 120 * (fbm(u, v, 2, 71, 3) > 0.45 and 1 or 0.2)
		local r, gg, bb = 245 - 9 * cloud, 241 - 10 * cloud, 234 - 12 * cloud
		r, gg, bb = mix(r, 214, 0.5 * soft), mix(gg, 202, 0.5 * soft), mix(bb, 186, 0.5 * soft)
		local grey = min(1, core * 0.8 + faint)
		r, gg, bb = mix(r, 150, 0.6 * grey), mix(gg, 146, 0.6 * grey), mix(bb, 142, 0.6 * grey)
		gold = min(1, gold)
		r, gg, bb = mix(r, 200, 0.85 * gold), mix(gg, 158, 0.85 * gold), mix(bb, 80, 0.85 * gold)
		local i = (y * N + x) * 4
		pixels[i + 1], pixels[i + 2], pixels[i + 3], pixels[i + 4] = floor(bb + 0.5), floor(gg + 0.5), floor(r + 0.5), 255
		total = total + (0.2126 * r + 0.7152 * gg + 0.0722 * bb) / 255
	end
end

local function u16(n) return string.char(n % 256, floor(n / 256)) end
local header = string.char(0, 0, 2) .. string.rep("\0", 5) .. u16(0) .. u16(0) .. u16(N) .. u16(N) .. string.char(32, 40)
local chars = {}
for i = 1, #pixels do chars[i] = string.char(pixels[i]) end
local f = assert(io.open(OUT .. "/marble.tga", "wb"))
f:write(header, table.concat(chars))
f:close()
print(string.format("marble.tga: mean brightness %.3f", total / (N * N)))

-- The Terminal skin's scanlines (Theme/SkinTerminal.lua): a 64x64 tile, one dark line every 3 rows
-- over clear, laid over its grounds like a CRT's.
do
	local S = 64
	local px = {}
	for y = 0, S - 1 do
		local a = (y % 3 == 0) and 110 or 0
		for _ = 0, S - 1 do px[#px + 1] = string.char(0, 0, 0, a) end
	end
	local out = assert(io.open(OUT .. "/scanlines.tga", "wb"))
	out:write(string.char(0, 0, 2) .. string.rep("\0", 5) .. u16(0) .. u16(0) .. u16(S) .. u16(S) .. string.char(32, 40), table.concat(px))
	out:close()
	print("scanlines.tga: written")
end
