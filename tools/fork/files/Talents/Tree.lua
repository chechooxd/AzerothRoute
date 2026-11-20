-- AzerothRoute: the talent plan drawn as the class's three talent trees, the way talent calculators
-- (Icy Veins and the like) show a build. The layout is the game's own tree when the client has it
-- loaded (C_Traits: each talent's position, icon, learned ranks and arrows), so it matches the
-- talent frame whatever Forever changes; before that, the plan's snapshot of the tree. On each
-- talent: the ranks the plan puts there, and the learned ones on the character's own plan.
-- Hovering a talent shows its tooltip. Original AzerothRoute code (GPL-3.0-only).
--
--   TV.TreeLayout(build, c)                          -> layout (see below), "live" | "snapshot"
--   TV.DrawTree(parent, x, y, width, build, c, mine) -> height     draws under (x, y) in `parent`
--   TV.HideTree()
--
-- layout = { trees = { { name, points }... }, rows, nodes = { { key, tree, row, col, spell, name,
--            max, planned, first, have }... }, edges = { { fromKey, toKey }... } }

local ADDON, ns = ...
local UI, Theme, W = ns.UI, ns.Theme, ns.Widgets
local TV = UI and UI.TalentsSection
local L = ns.L
if not (TV and Theme and W) then return end

local floor, max, min, format, abs = math.floor, math.max, math.min, string.format, math.abs

local GAP_TREE = 18   -- between trees
local HEAD = 26       -- a tree's name line
local MAX_NODE = 34   -- the largest talent square

local root
local cells, lines, heads = {}, {}, {}

local function readable(v)
	if issecretvalue and issecretvalue(v) then return nil end
	return v
end

local function call(fn, ...)
	if not fn then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
end

-- Layouts --------------------------------------------------------------------------------------

-- The plan's ranks and first pick by plan node.
local function planOf(build)
	local plan, first = {}, {}
	for _, p in ipairs(build.picks) do
		plan[p.node] = max(plan[p.node] or 0, p.rank)
		first[p.node] = first[p.node] or p.order
	end
	return plan, first
end

-- Index of each distinct value in sorted order (values within `tol` count as one).
local function ranks(values, tol)
	table.sort(values)
	local out, last, n = {}, nil, 0
	for _, v in ipairs(values) do
		if not last or v - last > tol then n = n + 1 last = v end
		out[v] = n
	end
	return out, n
end

-- Splits sorted x positions into `k` trees at the k-1 widest gaps -> function(x) -> tree.
local function splitter(xs, k)
	table.sort(xs)
	local gaps = {}
	for i = 2, #xs do gaps[#gaps + 1] = { at = (xs[i] + xs[i - 1]) / 2, size = xs[i] - xs[i - 1] } end
	table.sort(gaps, function(a, b) return a.size > b.size end)
	local cuts = {}
	for i = 1, min(k - 1, #gaps) do cuts[#cuts + 1] = gaps[i].at end
	table.sort(cuts)
	return function(x)
		local t = 1
		for _, c in ipairs(cuts) do if x > c then t = t + 1 end end
		return t
	end
end

local function liveLayout(build, c, mine)
	local T = ns.Talents
	local data = build.data
	local C = T and T.Client
	if not (C and C_Traits and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo) then return nil end
	local config = C.ConfigID()
	if not config then return nil end
	local ids = call(C_Traits.GetTreeNodes, data.tree)
	if type(ids) ~= "table" or not ids[1] then return nil end

	local plan, first = planOf(build)
	-- Plan node -> live node, by the spell or name Polestar's validation matches.
	local back = {}
	local valid = c and c.valid
	if not valid and T.Read and T.Validate then
		local live = T.Read(data)
		valid = live and T.Validate(data, live) or nil
	end
	for planId, liveId in pairs(valid and valid.map or {}) do back[liveId] = planId end

	local raw, xs, ys = {}, {}, {}
	for _, id in ipairs(ids) do
		local info = call(C_Traits.GetNodeInfo, config, id)
		local nodeID = info and readable(info.ID)
		local x, y = info and readable(info.posX), info and readable(info.posY)
		if nodeID and nodeID ~= 0 and readable(info.isVisible) ~= false and type(x) == "number" and type(y) == "number" then
			local entry = (info.activeEntry and readable(info.activeEntry.entryID)) or (info.entryIDs and readable(info.entryIDs[1]))
			local spell, name = C.Entry(config, entry)
			local rank = readable(info.activeRank) or readable(info.ranksPurchased) or 0
			raw[#raw + 1] = { id = id, x = x, y = y, max = readable(info.maxRanks) or 1, spell = spell, name = name,
				have = rank, edges = info.visibleEdges }
			xs[#xs + 1], ys[#ys + 1] = x, y
		end
	end
	if #raw == 0 then return nil end

	local treeOf = splitter({ unpack(xs) }, 3)
	local rowOf = ranks({ unpack(ys) }, 200)
	local byTree = { {}, {}, {} }
	for _, n in ipairs(raw) do
		n.tree = treeOf(n.x)
		local list = byTree[n.tree]
		list[#list + 1] = n.x
	end
	local colOf = {}
	for t = 1, 3 do colOf[t] = ranks(byTree[t], 200) end

	local out = { trees = {}, nodes = {}, edges = {}, rows = 1 }
	for t = 1, 3 do out.trees[t] = { name = data.specs and data.specs[t] and L[data.specs[t]] or "", points = 0 } end
	for _, n in ipairs(raw) do
		local planId = back[n.id]
		local planned = planId and plan[planId] or 0
		local node = {
			key = n.id, tree = n.tree, row = rowOf[n.y], col = colOf[n.tree][n.x],
			spell = n.spell, name = n.name, max = n.max,
			planned = planned, first = planId and first[planId] or nil, have = mine and n.have or nil,
		}
		out.rows = max(out.rows, node.row)
		out.trees[n.tree].points = out.trees[n.tree].points + planned
		out.nodes[#out.nodes + 1] = node
		for _, e in ipairs(type(n.edges) == "table" and n.edges or {}) do
			local to = readable(e.targetNode)
			if to then out.edges[#out.edges + 1] = { n.id, to } end
		end
	end
	return out
end

local function snapshotLayout(build, c, mine)
	local data = build.data
	local plan, first = planOf(build)
	local have
	if mine and c and c.valid and c.live then
		have = {}
		for planId, liveId in pairs(c.valid.map) do
			local n = c.live.nodes[liveId]
			have[planId] = n and n.active or 0
		end
	end
	local out = { trees = {}, nodes = {}, edges = {}, rows = 1 }
	for t = 1, 3 do out.trees[t] = { name = data.specs and data.specs[t] and L[data.specs[t]] or "", points = 0 } end
	for id, n in pairs(data.nodes) do
		local planned = plan[id] or 0
		out.nodes[#out.nodes + 1] = { key = id, tree = n.spec, row = n.row, col = n.col, spell = n.spell, name = n.name,
			max = n.max, planned = planned, first = first[id], have = have and have[id] or nil }
		out.rows = max(out.rows, n.row or 1)
		out.trees[n.spec].points = out.trees[n.spec].points + planned
	end
	for _, e in ipairs(data.edges or {}) do out.edges[#out.edges + 1] = { e[1], e[2] } end
	return out
end

function TV.TreeLayout(build, c, mine)
	local live = liveLayout(build, c, mine)
	if live then return live, "live" end
	return snapshotLayout(build, c, mine), "snapshot"
end

-- Drawing --------------------------------------------------------------------------------------

local function color(t, name, alpha)
	local r, g, b = Theme.Color(name)
	t:SetColorTexture(r or 1, g or 1, b or 1, alpha or 1)
end

local function accent(t, alpha)
	local r, g, b = Theme.Accent()
	t:SetColorTexture(r, g, b, alpha or 1)
end

local function hideAll()
	for _, t in ipairs({ cells, lines, heads }) do
		for _, f in ipairs(t) do f:Hide() end
	end
end

function TV.HideTree()
	hideAll()
	if root then root:Hide() end
end

local function tip(cell)
	local GT = GameTooltip
	if not GT then return end
	GT:SetOwner(cell, "ANCHOR_RIGHT")
	local ok = cell.psSpell and GT.SetSpellByID and pcall(GT.SetSpellByID, GT, cell.psSpell)
	if not ok then GT:SetText(cell.psName or "") end
	GT:AddLine(" ")
	if (cell.psPlan or 0) > 0 then
		GT:AddLine(format(L["The plan puts %d of %d ranks here"], cell.psPlan, cell.psMax), 0.6, 0.8, 1)
		if cell.psFirst then GT:AddLine(format(L["First point: pick %d"], cell.psFirst), 0.7, 0.7, 0.7) end
	else
		GT:AddLine(L["Not in this plan"], 0.6, 0.6, 0.6)
	end
	if cell.psHave then GT:AddLine(format(L["Learned: %d of %d"], cell.psHave, cell.psMax), 0.4, 0.85, 0.6) end
	GT:Show()
end

local function cell(i, parent)
	local c = cells[i]
	if c then return c end
	c = CreateFrame("Frame", nil, parent)
	c.Edge = c:CreateTexture(nil, "BACKGROUND")
	c.Edge:SetAllPoints(c)
	c.Icon = c:CreateTexture(nil, "ARTWORK")
	c.Icon:SetPoint("TOPLEFT", c, "TOPLEFT", 2, -2)
	c.Icon:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -2, 2)
	c.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	c.RankBg = c:CreateTexture(nil, "OVERLAY")
	c.RankBg:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 3, -3)
	c.RankBg:SetSize(22, 12)
	c.Rank = W.Text(c, "small", "text")
	c.Rank:SetPoint("CENTER", c.RankBg, "CENTER", 0, 0)
	c:EnableMouse(true)
	c:SetScript("OnEnter", tip)
	c:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	cells[i] = c
	return c
end

local function line(i, parent)
	local t = lines[i]
	if t then return t end
	t = parent:CreateTexture(nil, "BORDER")
	lines[i] = t
	return t
end

local function head(i, parent)
	local h = heads[i]
	if h then return h end
	h = W.Text(parent, "label", "text")
	heads[i] = h
	return h
end

function TV.DrawTree(parent, x, y, width, build, c, mine)
	if not (build and build.data) then return 0 end
	local layout, source = TV.TreeLayout(build, c, mine)
	TV.treeSource = source
	if not root then root = CreateFrame("Frame", nil, parent) end
	root:SetParent(parent)
	root:ClearAllPoints()
	root:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	root:SetWidth(width)
	hideAll()

	local cols = 1
	for _, n in ipairs(layout.nodes) do cols = max(cols, n.col or 1) end
	local treeW = floor((width - GAP_TREE * 2) / 3)
	local size = min(MAX_NODE, floor(treeW / (cols + (cols - 1) * 0.45)))
	local step = floor((treeW - size) / max(1, cols - 1))
	local vstep = size + floor(size * 0.45)
	local at = {}
	for _, n in ipairs(layout.nodes) do
		at[n.key] = { (n.tree - 1) * (treeW + GAP_TREE) + (n.col - 1) * step, -(HEAD + (n.row - 1) * vstep), n }
	end

	for t = 1, 3 do
		local h = head(t, root)
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", root, "TOPLEFT", (t - 1) * (treeW + GAP_TREE), 0)
		local tr = layout.trees[t] or { name = "", points = 0 }
		h:SetText(format("%s  |cff8fa6c6%d|r", tr.name, tr.points))
		h:Show()
	end

	-- Arrows: a line from the source's centre to the target's, bent at the target's column.
	local li, half = 0, size / 2
	for _, e in ipairs(layout.edges) do
		local a, b = at[e[1]], at[e[2]]
		if a and b and a[3].tree == b[3].tree then
			local taken = (a[3].planned or 0) > 0 and (b[3].planned or 0) > 0
			local function seg(x1, y1, x2, y2)
				li = li + 1
				local t = line(li, root)
				t:ClearAllPoints()
				t:SetPoint("TOPLEFT", root, "TOPLEFT", min(x1, x2) - 1, max(y1, y2) + 1)
				t:SetSize(max(3, abs(x2 - x1) + 3), max(3, abs(y2 - y1) + 3))
				if taken then accent(t, 0.85) else color(t, "textMuted", 0.35) end
				t:Show()
			end
			local acx, acy = a[1] + half, a[2] - half
			local bcx, bcy = b[1] + half, b[2] - half
			if a[1] == b[1] then
				seg(acx, acy - half, bcx, bcy + half)
			elseif a[2] == b[2] then
				seg(acx + (bcx > acx and half or -half), acy, bcx + (bcx > acx and -half or half), bcy)
			else
				seg(acx, acy, bcx, acy)
				seg(bcx, acy, bcx, bcy + half)
			end
		end
	end

	local ci = 0
	for _, n in ipairs(layout.nodes) do
		ci = ci + 1
		local f = cell(ci, root)
		local p = at[n.key]
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", root, "TOPLEFT", p[1], p[2])
		f:SetSize(size, size)
		f.Icon:SetTexture(TV.SpellIcon and TV.SpellIcon(n.spell) or nil)
		local planned, got = n.planned or 0, n.have
		f.Icon:SetDesaturated(planned == 0 and not (got and got > 0))
		f.Icon:SetAlpha((planned == 0 and not (got and got > 0)) and 0.45 or 1)
		if got and planned > 0 and got >= planned then
			color(f.Edge, "success", 1)
		elseif planned > 0 then
			accent(f.Edge, 1)
		elseif got and got > 0 then
			color(f.Edge, "warning", 1)
		else
			color(f.Edge, "textMuted", 0.35)
		end
		if planned > 0 or (got and got > 0) then
			-- Learned of planned on the own plan, planned of the talent's ranks otherwise.
			if got then
				f.Rank:SetText(format("%d/%d", got, planned > 0 and planned or n.max))
			else
				f.Rank:SetText(format("%d/%d", planned, n.max))
			end
			color(f.RankBg, "bg", 0.9)
			f.RankBg:Show()
			f.Rank:Show()
		else
			f.RankBg:Hide()
			f.Rank:Hide()
		end
		f.psSpell, f.psName, f.psMax = n.spell, n.name, n.max
		f.psPlan, f.psFirst, f.psHave = planned, n.first, got
		f:Show()
	end

	local height = HEAD + (layout.rows - 1) * vstep + size + 6
	root:SetHeight(height)
	root:Show()
	return height
end
