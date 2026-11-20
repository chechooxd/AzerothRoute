-- AzerothRoute: multi-leg journey planner (walk, known flight paths, boats, zeppelins, tram).
-- Plans the fastest way to the arrow's destination with Dijkstra over: the player, the target,
-- the hearthstone landing (when the stone is in the bags; its cooldown counts as waiting),
-- the flight masters the character knows (TravelData snapped to the database) and transport docks.
-- Times are estimates: walking at the player's average speed (at least run speed), flying at a
-- fixed effective speed, and each transport at its listed crossing time.

local AR = _G.AzerothRoute
local Journey = {
    RUN_SPEED = 7,            -- yd/s on foot
    FLY_SPEED = 24,           -- yd/s effective over the ground (taxi routes bend)
    FLY_OVERHEAD = 15,        -- s to mount up and land
    SNAP_YARDS = 250,         -- a database flight master this close replaces the table position
    REPLAN_SECONDS = 5,
    MIN_SAVING = 0.8,         -- a multi-leg plan must take under 80% of walking straight there
    plan = nil,
    nodes = nil,
}
AR.Journey = Journey

local function L(key, fallback)
    if AR.L then
        local v = AR.L:Get(key)
        if v and v ~= key then return v end
    end
    return fallback or key
end

function Journey:Reset()
    self.plan, self.nodes, self.planKey, self.planTime = nil, nil, nil, nil
end

local function playerSide()
    local f = _G.UnitFactionGroup and _G.UnitFactionGroup("player")
    return (f == "Alliance" and "A") or (f == "Horde" and "H") or nil
end

local function sideOk(side)
    local me = playerSide()
    return side == "B" or not me or side == me
end

local function world(map, x, y)
    if not AR.Coords or not map then return nil end
    return AR.Coords:ToWorldYards(map, x, y)
end

-- Flight nodes and docks usable by this character, with world positions (rebuilt per plan).
function Journey:BuildNodes()
    local nodes = {}
    local TT, TD = AR.TaxiTracker, AR.TravelData
    local masters = {}
    for _, ref in ipairs((AR.Nearby and AR.Nearby:GetIndex().f) or {}) do
        local u = AR.DB:GetUnit(ref.id)
        if u and u.map > 0 then
            local c, wx, wy = world(u.map, u.x / 100, u.y / 100)
            if c then masters[#masters + 1] = { u = u, c = c, wx = wx, wy = wy } end
        end
    end
    for _, n in ipairs((TD and TD.TAXI_NODES) or {}) do
        if sideOk(n.side) and TT and TT:KnowsTaxi(n.name) then
            local map, x, y = n.map, n.x / 100, n.y / 100
            local c, wx, wy = world(map, x, y)
            if c then
                local best, bestD
                for _, m in ipairs(masters) do
                    if m.c == c and (n.side == "B" or m.u.side == n.side or m.u.side == "B") then
                        local d = math.sqrt((m.wx - wx) ^ 2 + (m.wy - wy) ^ 2)
                        if d <= self.SNAP_YARDS and (not bestD or d < bestD) then best, bestD = m, d end
                    end
                end
                if best then
                    map, x, y, wx, wy = best.u.map, best.u.x / 100, best.u.y / 100, best.wx, best.wy
                end
                nodes[#nodes + 1] = { kind = "taxi", name = n.name, map = map, x = x, y = y, c = c, wx = wx, wy = wy }
            end
        end
    end
    for _, t in ipairs((TD and TD.TRANSPORTS) or {}) do
        if sideOk(t.side) then
            local ends = {}
            for _, dock in ipairs({ t.a, t.b }) do
                local c, wx, wy = world(dock.map, dock.x / 100, dock.y / 100)
                if c then
                    local node = { kind = "dock", name = dock.name, map = dock.map, x = dock.x / 100, y = dock.y / 100,
                        c = c, wx = wx, wy = wy, transport = t }
                    nodes[#nodes + 1] = node
                    ends[#ends + 1] = node
                end
            end
            if #ends == 2 then ends[1].pair, ends[2].pair = ends[2], ends[1] end
        end
    end
    return nodes
end

Journey.HEARTHSTONE_ITEM = 6948
Journey.HEARTH_CAST = 10 -- s of casting

-- Seconds until the hearthstone can be used (0 when ready), or nil without one in the bags.
function Journey:HearthWait()
    local count = (AR.Compat and AR.Compat:GetItemCount(self.HEARTHSTONE_ITEM, false)) or 0
    if count <= 0 then return nil end
    local getCD = (_G.C_Container and _G.C_Container.GetItemCooldown) or _G.GetItemCooldown
    if not getCD then return 0 end
    local start, duration = getCD(self.HEARTHSTONE_ITEM)
    if not start or start == 0 or not duration then return 0 end
    local now = (_G.GetTime and _G.GetTime()) or 0
    return math.max(0, start + duration - now)
end

-- Hearth landing node with its world position, or nil (no stone, no known bind location).
function Journey:HearthNode()
    local wait = self:HearthWait()
    if not wait or not AR.TaxiTracker or not AR.TaxiTracker.GetHearthLocation then return nil end
    local loc = AR.TaxiTracker:GetHearthLocation()
    if not loc then return nil end
    local c, wx, wy = world(loc.map, loc.x, loc.y)
    if not c then return nil end
    local name = (AR.TaxiTracker.GetLocalizedNodeName and AR.TaxiTracker:GetLocalizedNodeName(loc.name)) or loc.name
    return { kind = "hearth", name = name, map = loc.map, x = loc.x, y = loc.y, c = c, wx = wx, wy = wy,
        cost = wait + self.HEARTH_CAST }
end

function Journey:WalkSpeed()
    local P = AR.Pointer
    local samples = P and P.speedSamples or {}
    if #samples > 0 then
        local sum = 0
        for _, s in ipairs(samples) do sum = sum + s end
        return math.max(self.RUN_SPEED, sum / #samples)
    end
    return self.RUN_SPEED
end

local function dist(a, b)
    if a.c ~= b.c then return nil end
    return math.sqrt((a.wx - b.wx) ^ 2 + (a.wy - b.wy) ^ 2)
end

-- Fastest route from the player to `target` ({ map, x, y, title }, x/y in 0..1).
-- Returns { legs = { { mode, name, label, map, x, y, seconds, yards } }, seconds, yards } or nil.
function Journey:Plan(target)
    if not target or not target.map or not AR.Coords then return nil end
    local pMap, px, py = AR.Coords:GetPlayerPosition()
    if not pMap or not px then return nil end
    local sc, swx, swy = world(pMap, px, py)
    local ec, ewx, ewy = world(target.map, target.x, target.y)
    if not sc or not ec then return nil end
    local S = { kind = "start", c = sc, wx = swx, wy = swy }
    local E = { kind = "end", name = target.title, map = target.map, x = target.x, y = target.y, c = ec, wx = ewx, wy = ewy }
    local nodes = { S, E }
    for _, n in ipairs(self:BuildNodes()) do nodes[#nodes + 1] = n end
    -- The hearthstone works from anywhere: one edge from the start, its cooldown included.
    local H = self:HearthNode()
    if H then nodes[#nodes + 1] = H end

    local speed = self:WalkSpeed()
    local best, prev, how, done = {}, {}, {}, {}
    best[S] = 0
    while true do
        local u, bu
        for _, n in ipairs(nodes) do
            if not done[n] and best[n] and (not bu or best[n] < bu) then u, bu = n, best[n] end
        end
        if not u or u == E then break end
        done[u] = true
        local function relax(v, cost, mode, yards)
            local t = bu + cost
            if not best[v] or t < best[v] then best[v], prev[v], how[v] = t, u, { mode = mode, yards = yards or 0, seconds = cost } end
        end
        for _, v in ipairs(nodes) do
            if v ~= u and not done[v] and v ~= S then
                local d = dist(u, v)
                if d then relax(v, d / speed, "walk", d) end
                if d and u.kind == "taxi" and v.kind == "taxi" then
                    relax(v, d / self.FLY_SPEED + self.FLY_OVERHEAD, "fly", d)
                end
            end
        end
        if u.kind == "dock" and u.pair and not done[u.pair] then
            relax(u.pair, u.transport.seconds, u.transport.mode, 0)
        end
        if u == S and H and not done[H] then
            relax(H, H.cost, "hearth", 0)
        end
    end
    if not best[E] then return nil end

    local chain = {}
    local n = E
    while prev[n] do
        table.insert(chain, 1, { node = n, step = how[n] })
        n = prev[n]
    end
    -- Merge consecutive walks (start -> dock -> taxi on foot reads as one walk to the last stop).
    local legs, total, yards = {}, 0, 0
    for _, c in ipairs(chain) do
        local last = legs[#legs]
        if last and last.mode == "walk" and c.step.mode == "walk" then
            table.remove(legs)
            c.step.seconds = c.step.seconds + last.seconds
            c.step.yards = c.step.yards + last.yards
        end
        local name = c.node.name or ""
        local key = ({ walk = "UI_LEG_WALK", fly = "UI_LEG_FLY", boat = "UI_LEG_BOAT", zeppelin = "UI_LEG_ZEPPELIN", tram = "UI_LEG_TRAM", hearth = "UI_LEG_HEARTH" })[c.step.mode]
        legs[#legs + 1] = {
            mode = c.step.mode, name = name, label = string.format(L(key, "%s"), name),
            map = c.node.map, x = c.node.x, y = c.node.y, seconds = c.step.seconds, yards = c.step.yards,
            final = c.node == E,
        }
    end
    for _, leg in ipairs(legs) do
        total = total + leg.seconds
        yards = yards + leg.yards
    end
    local direct = dist(S, E)
    if #legs > 1 and direct and total >= (direct / speed) * self.MIN_SAVING then
        -- Not worth it: walk straight there.
        legs = { { mode = "walk", name = E.name or "", label = string.format(L("UI_LEG_WALK", "Walk to %s"), E.name or ""),
            map = E.map, x = E.x, y = E.y, seconds = direct / speed, yards = direct, final = true } }
        total, yards = direct / speed, direct
    end
    return { legs = legs, seconds = total, yards = yards, target = target }
end

-- Cached plan for `target`, replanned every few seconds or when the target changes.
function Journey:GetPlan(target)
    if not target then
        self.plan = nil
        return nil
    end
    if _G.UnitOnTaxi and _G.UnitOnTaxi("player") then return self.plan end
    local now = (_G.GetTime and _G.GetTime()) or 0
    local key = string.format("%s:%.4f:%.4f", tostring(target.map), target.x or 0, target.y or 0)
    if self.planKey ~= key or not self.planTime or now - self.planTime >= self.REPLAN_SECONDS then
        self.plan = self:Plan(target)
        self.planKey, self.planTime = key, now
    end
    return self.plan
end

-- Where the arrow should point now: the end of the first leg of a multi-leg plan, or nil
-- (nil means "point at the target itself").
function Journey:GetSteering(target)
    local plan = self:GetPlan(target)
    if not plan or #plan.legs < 2 then return nil end
    local leg = plan.legs[1]
    return { map = leg.map, x = leg.x, y = leg.y, title = leg.label, leg = leg, plan = plan }
end

function Journey:FormatDuration(secs)
    secs = math.max(0, math.floor((secs or 0) + 0.5))
    return string.format("%d:%02d", math.floor(secs / 60), secs % 60)
end

return Journey
