-- AzerothRoute: "Apply talents". Spends the character's unspent talent points on the next picks
-- of the plan it follows, in the plan's order, then commits them, as AzerothRoute 1's talent
-- advisor did. Out of combat only; a plan the character has left (points off the plan) or one the
-- live tree no longer matches is never applied. Original AzerothRoute code (GPL-3.0-only).
--
--   T.Apply.Picks(c)  -> { { node, live, entry }... }, why   the picks Apply would buy now
--   T.Apply.Run()     -> bought, why                          buys and commits them

local ADDON, ns = ...
local T = ns.Talents
local L = ns.L
if not T then return end

local A = {}
T.Apply = A

if GetLocale and (GetLocale() == "esMX" or GetLocale() == "esES") then
	L["Apply talents"] = "Aplicar talentos"
	L["Spend your unspent points on this plan's next picks, in order."] = "Gasta tus puntos libres en los siguientes talentos de este plan, en orden."
	L["Applied %d talent points from the %s plan."] = "Se aplicaron %d puntos de talento del plan %s."
	L["Talents can't be changed in combat."] = "No se pueden cambiar talentos en combate."
	L["No points to spend on this plan right now."] = "Ahora no hay puntos que gastar en este plan."
	L["Some points are off this plan: reset your talents first, then apply."] = "Hay puntos fuera de este plan: reinicia tus talentos primero y luego aplica."
	L["The game did not take the talent %s."] = "El juego no aceptó el talento %s."
end

local function call(fn, ...)
	if not fn then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return a end
	return nil
end

-- The ranks the frame shows now (staged ones included), by plan node.
local function ranksNow(c)
	local out = {}
	for planId, liveId in pairs(c.valid.map) do
		local n = c.live.nodes[liveId]
		out[planId] = n and (n.current or n.active) or 0
	end
	return out
end

function A.Picks(c)
	if not (c and c.valid and c.valid.ok and c.staged) then return {}, "nostate" end
	local s = c.staged
	if s.status == "offplan" then return {}, "offplan" end
	local budget = s.unspent or 0
	if budget <= 0 then return {}, "nopoints" end
	local ranks, out = ranksNow(c), {}
	for _, p in ipairs(c.build.picks) do
		if #out >= budget then break end
		local have = ranks[p.node] or 0
		if have < p.rank then
			-- One rank at a time: a plan's ranks of a node come in order.
			if p.rank ~= have + 1 then break end
			local node = c.data.nodes[p.node]
			out[#out + 1] = { node = p.node, live = c.valid.map[p.node], entry = node and node.entry, rank = p.rank }
			ranks[p.node] = p.rank
		end
	end
	if #out == 0 then return out, "nopoints" end
	return out, nil
end

local function buy(config, pick)
	local C = C_Traits
	if not C then return false end
	local info = call(C.GetNodeInfo, config, pick.live)
	local entries = info and info.entryIDs
	-- A choice node takes its entry; a plain one a rank.
	if type(entries) == "table" and #entries > 1 and pick.entry and C.SetSelection then
		return call(C.SetSelection, config, pick.live, pick.entry) and true or false
	end
	if C.PurchaseRank then return call(C.PurchaseRank, config, pick.live) and true or false end
	return false
end

local function commit(config)
	if C_ClassTalents and C_ClassTalents.CommitConfig then return call(C_ClassTalents.CommitConfig, config) end
	if C_Traits and C_Traits.CommitConfig then return call(C_Traits.CommitConfig, config) end
end

function A.Run()
	if InCombatLockdown and InCombatLockdown() then
		ns.Print(L["Talents can't be changed in combat."])
		return 0, "combat"
	end
	local c = T.Refresh()
	local picks, why = A.Picks(c)
	if why == "offplan" then
		ns.Print(L["Some points are off this plan: reset your talents first, then apply."])
		return 0, why
	elseif #picks == 0 then
		ns.Print(L["No points to spend on this plan right now."])
		return 0, why or "nopoints"
	end
	local config = c.live.config
	local bought = 0
	for _, pick in ipairs(picks) do
		if not buy(config, pick) then
			ns.Print(string.format(L["The game did not take the talent %s."], T.NodeName(c.data, pick.node, c.valid) or "?"))
			break
		end
		bought = bought + 1
	end
	if bought > 0 then
		commit(config)
		ns.Print(string.format(L["Applied %d talent points from the %s plan."], bought, c.build.specName or ""))
	end
	T.Queue()
	return bought, nil
end
