-- AzerothRoute: gathering routes. For Herbalism or Mining, a closed loop through every spot where the
-- herbs or ore veins that still teach the character's skill can spawn, in the zone with most of them
-- (Core/GatherData.lua's spots, Gather.Spots), and the arrow held on each spot in turn (Nav.Hold, so
-- the guide's steps do not take it away), moving on when the character comes within REACH yards.
-- A spot is where a node CAN spawn, never a promise one is up. Original AzerothRoute code (GPL-3.0-only).
--
--   Routes.KindsFor(line, rank) -> { kind ids }            kinds of line needing rank-SPAN+1..rank (pure but for data)
--   Routes.Candidates(line, rank, level) -> { { map, kinds, count, minLevel } }   most spots first
--   Routes.Order(points) -> ordered, length                closed loop by nearest neighbour, then 2-opt (pure)
--   Routes.Build(map, kinds, line) -> route | nil           { map, f, line, kinds, points = { { x, y, k, wx, wy } }, length }
--   Routes.Advance(route, i, wx, wy) -> index               the next spot once within REACH of spot i (pure)
--   Routes.Start(route[, i]), Routes.Skip(), Routes.Stop(), Routes.Active(), Routes.Index()
--   message ROUTE_CHANGED(route | nil, index)

local ADDON, ns = ...
local L = ns.L
local Compat = ns.Compat
local sqrt, floor, huge = math.sqrt, math.floor, math.huge

local R = {}
ns.Routes = R

R.SPAN = 100       -- a node keeps teaching the skill up to 100 points past what it needs
R.REACH = 25       -- yards: close enough to see a node at its spot, the next spot is held
R.MIN_SPOTS = 8    -- a zone with fewer spots of the kinds makes no route
R.LEVEL_SLACK = 5  -- zones up to this many levels above the character
R.MAX_ZONES = 3    -- routes offered per skill
R.LINES = { 182, 186 } -- Herbalism, Mining
local TICK = 0.5

if GetLocale and (GetLocale() == "esMX" or GetLocale() == "esES") then
	L["Route: %s (%d of %d)"] = "Ruta: %s (%d de %d)"
end

---------------------------------------------------------------------------
-- Building (pure but for the gather data)
---------------------------------------------------------------------------

function R.KindsFor(line, rank)
	local G, out = ns.Gather, {}
	if not (G and rank and rank > 0) then return out end
	local k = 1
	while G.Kind(k) do
		local kind = G.Kind(k)
		if kind.line == line and kind.skill <= rank and kind.skill > rank - R.SPAN then out[#out + 1] = k end
		k = k + 1
	end
	return out
end

function R.Candidates(line, rank, level)
	local G, out = ns.Gather, {}
	local kinds = R.KindsFor(line, rank)
	if not (G and G.Maps and #kinds > 0) then return out end
	local want = {}
	for _, k in ipairs(kinds) do want[k] = true end
	local Maps = ns.Maps
	for _, map in ipairs(G.Maps()) do
		local lo = Maps and Maps.GetZoneLevels and Maps.GetZoneLevels(map)
		local spots = G.Spots(map)
		-- Only a zone whose spots the client can place in the world makes a route (R.Build).
		local placeable = spots[1] and Compat.MapToWorld(map, spots[1].x, spots[1].y, spots[1].f) ~= nil
		if placeable and not (lo and level and lo > level + R.LEVEL_SLACK) then
			local count, here, seen = 0, {}, {}
			for _, s in ipairs(spots) do
				if want[s.k] then
					count = count + 1
					if not seen[s.k] then seen[s.k] = true here[#here + 1] = s.k end
				end
			end
			if count >= R.MIN_SPOTS then
				table.sort(here)
				out[#out + 1] = { map = map, kinds = here, count = count, minLevel = lo }
			end
		end
	end
	table.sort(out, function(a, b)
		if a.count ~= b.count then return a.count > b.count end
		return a.map < b.map
	end)
	while #out > R.MAX_ZONES do table.remove(out) end
	return out
end

local function dist(a, b) return sqrt((a.wx - b.wx) ^ 2 + (a.wy - b.wy) ^ 2) end

local function tourLength(t)
	local len = 0
	for i = 1, #t do len = len + dist(t[i], t[i % #t + 1]) end
	return len
end

-- A closed loop through every point: nearest neighbour from the first, then 2-opt until no swap of two
-- edges shortens it (or the passes run out).
function R.Order(points)
	local n = #points
	if n == 0 then return {}, 0 end
	local left = {}
	for i = 2, n do left[#left + 1] = points[i] end
	local t = { points[1] }
	while #left > 0 do
		local last, bi, bd = t[#t], 1, huge
		for i, p in ipairs(left) do
			local d = dist(last, p)
			if d < bd then bi, bd = i, d end
		end
		t[#t + 1] = table.remove(left, bi)
	end
	if n >= 4 then
		for _ = 1, 50 do
			local better = false
			for i = 1, n - 2 do
				for j = i + 2, n do
					local a, b, c, d = t[i], t[i + 1], t[j], t[j % n + 1]
					if a ~= d and dist(a, c) + dist(b, d) < dist(a, b) + dist(c, d) - 1e-9 then
						-- Reverse t[i+1..j].
						local lo, hi = i + 1, j
						while lo < hi do t[lo], t[hi] = t[hi], t[lo] lo, hi = lo + 1, hi - 1 end
						better = true
					end
				end
			end
			if not better then break end
		end
	end
	return t, tourLength(t)
end

function R.Build(map, kinds, line)
	local G = ns.Gather
	if not (G and G.Spots) then return nil end
	local want = {}
	for _, k in ipairs(kinds or {}) do want[k] = true end
	local pts, frame = {}, nil
	for _, s in ipairs(G.Spots(map)) do
		if want[s.k] then
			local _, wx, wy = Compat.MapToWorld(map, s.x, s.y, s.f)
			if wx and wy then
				frame = s.f
				pts[#pts + 1] = { x = s.x, y = s.y, k = s.k, wx = wx, wy = wy }
			end
		end
	end
	if #pts == 0 then return nil end
	local ordered, length = R.Order(pts)
	return { map = map, f = frame, line = line, kinds = kinds, points = ordered, length = length }
end

function R.Advance(route, i, wx, wy)
	local p = route and route.points[i]
	if not (p and wx and wy) then return i end
	if sqrt((p.wx - wx) ^ 2 + (p.wy - wy) ^ 2) <= R.REACH then return i % #route.points + 1 end
	return i
end

-- The spot of the route nearest to the character (the first when the position is unknown).
function R.Nearest(route)
	local _, wx, wy = Compat.GetPlayerWorldPosition()
	if not (route and wx and wy) then return 1 end
	local bi, bd = 1, huge
	for i, p in ipairs(route.points) do
		local d = (p.wx - wx) ^ 2 + (p.wy - wy) ^ 2
		if d < bd then bi, bd = i, d end
	end
	return bi
end

---------------------------------------------------------------------------
-- Following
---------------------------------------------------------------------------

local active, index, ticker

local function kindName(k)
	local G = ns.Gather
	local kind = G and G.Kind(k)
	return kind and kind.name or "?"
end

local function hold()
	local p = active and active.points[index]
	if not p then return end
	local Nav = ns.Nav
	if Nav and Nav.Hold then
		Nav.Hold(active.map, p.x, p.y, string.format(L["Route: %s (%d of %d)"], kindName(p.k), index, #active.points), active.f)
	end
	ns.Fire("ROUTE_CHANGED", active, index)
end

local function tick()
	if not active then return end
	local _, wx, wy = Compat.GetPlayerWorldPosition()
	local nxt = R.Advance(active, index, wx, wy)
	if nxt ~= index then
		index = nxt
		hold()
	end
end

function R.Start(route, i)
	if not route then return end
	R.Stop(true)
	active = route
	index = i or R.Nearest(route)
	hold()
	if ns.NewTicker then ticker = ns.NewTicker(TICK, tick) end
end

function R.Skip()
	if not active then return end
	index = index % #active.points + 1
	hold()
end

function R.Stop(quiet)
	if ticker and ticker.Cancel then ticker:Cancel() end
	ticker = nil
	if active then
		active, index = nil, nil
		local Nav = ns.Nav
		if Nav and Nav.Unhold then Nav.Unhold() end
		if not quiet then ns.Fire("ROUTE_CHANGED", nil, nil) end
	end
end

function R.Active() return active end
function R.Index() return index end
