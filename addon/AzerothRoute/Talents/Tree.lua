-- AzerothRoute: the talent plan drawn as the class's three talent trees, the way talent calculators
-- (Icy Veins and the like) show a build: each tree a grid of talent icons at their row and column,
-- the arrows between them, and on each talent the ranks the plan puts there (learned ranks too when
-- it is the character's own plan). Hovering a talent shows its tooltip. Original AzerothRoute code
-- (GPL-3.0-only).
--
--   TV.DrawTree(parent, x, y, width, build, c) -> height     draws under (x, y) in `parent`
--   TV.HideTree()

local ADDON, ns = ...
local UI, Theme, W = ns.UI, ns.Theme, ns.Widgets
local TV = UI and UI.TalentsSection
local L = ns.L
if not (TV and Theme and W) then return end

local floor, max, min, format = math.floor, math.max, math.min, string.format

local GAP_TREE = 18   -- between trees
local HEAD = 26       -- a tree's name line
local MAX_NODE = 34   -- the largest talent square

local root
local cells, lines, heads = {}, {}, {}

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

function TV.DrawTree(parent, x, y, width, build, c)
	local data = build and build.data
	if not data then return 0 end
	if not root then root = CreateFrame("Frame", nil, parent) end
	root:SetParent(parent)
	root:ClearAllPoints()
	root:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	root:SetWidth(width)
	hideAll()

	-- The plan's ranks by node, and the pick that first reaches each node.
	local plan, first = {}, {}
	local perTree = { 0, 0, 0 }
	for _, p in ipairs(build.picks) do
		plan[p.node] = max(plan[p.node] or 0, p.rank)
		first[p.node] = first[p.node] or p.order
	end
	-- Learned ranks on the character's own plan.
	local have
	if c and c.valid and c.live then
		have = {}
		for planId, liveId in pairs(c.valid.map) do
			local n = c.live.nodes[liveId]
			have[planId] = n and n.active or 0
		end
	end

	local rows, cols = 1, 1
	for _, n in pairs(data.nodes) do
		rows, cols = max(rows, n.row or 1), max(cols, n.col or 1)
		if plan[n.id] then perTree[n.spec] = perTree[n.spec] + plan[n.id] end
	end
	local treeW = floor((width - GAP_TREE * 2) / 3)
	local size = min(MAX_NODE, floor(treeW / (cols + (cols - 1) * 0.45)))
	local step = floor((treeW - size) / max(1, cols - 1))
	local vstep = size + floor(size * 0.45)
	local function pos(n)
		local tx = (n.spec - 1) * (treeW + GAP_TREE)
		return tx + (n.col - 1) * step, -(HEAD + (n.row - 1) * vstep)
	end

	-- Tree names with the plan's points in each.
	for t = 1, 3 do
		local h = head(t, root)
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", root, "TOPLEFT", (t - 1) * (treeW + GAP_TREE), 0)
		local name = data.specs and data.specs[t] and L[data.specs[t]] or ""
		h:SetText(format("%s  |cff8fa6c6%d|r", name, perTree[t]))
		h:Show()
	end

	-- Arrows (prerequisites): a line from the source's centre to the target's, bent at the
	-- target's column when they sit in different columns.
	local li = 0
	local half = size / 2
	for _, e in ipairs(data.edges or {}) do
		local a, b = data.nodes[e[1]], data.nodes[e[2]]
		if a and b and a.spec == b.spec then
			local ax, ay = pos(a)
			local bx, by = pos(b)
			local taken = (plan[e[1]] or 0) > 0 and (plan[e[2]] or 0) > 0
			local function seg(x1, y1, x2, y2)
				li = li + 1
				local t = line(li, root)
				t:ClearAllPoints()
				local lx, ty = min(x1, x2), max(y1, y2)
				t:SetPoint("TOPLEFT", root, "TOPLEFT", lx - 1, ty + 1)
				t:SetSize(max(3, math.abs(x2 - x1) + 3), max(3, math.abs(y2 - y1) + 3))
				if taken then accent(t, 0.85) else color(t, "textMuted", 0.35) end
				t:Show()
			end
			local acx, acy = ax + half, ay - half
			local bcx, bcy = bx + half, by - half
			if ax == bx then
				seg(acx, acy - half, bcx, bcy + half)
			elseif ay == by then
				seg(acx + (bcx > acx and half or -half), acy, bcx + (bcx > acx and -half or half), bcy)
			else
				seg(acx, acy, bcx, acy)
				seg(bcx, acy, bcx, bcy + half)
			end
		end
	end

	-- Talents.
	local ci = 0
	for id, n in pairs(data.nodes) do
		ci = ci + 1
		local f = cell(ci, root)
		local px, py = pos(n)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", root, "TOPLEFT", px, py)
		f:SetSize(size, size)
		f.Icon:SetTexture(TV.SpellIcon and TV.SpellIcon(n.spell) or nil)
		local planned = plan[id] or 0
		local got = have and have[id] or nil
		f.Icon:SetDesaturated(planned == 0)
		f.Icon:SetAlpha(planned == 0 and 0.45 or 1)
		if got and got >= planned and planned > 0 then
			color(f.Edge, "success", 1)
		elseif planned > 0 then
			accent(f.Edge, 1)
		else
			color(f.Edge, "textMuted", 0.35)
		end
		if planned > 0 then
			f.Rank:SetText(got and format("%d/%d", min(got, planned), planned) or format("%d/%d", planned, n.max))
			color(f.RankBg, "bg", 0.9)
			f.RankBg:Show()
			f.Rank:Show()
		else
			f.RankBg:Hide()
			f.Rank:Hide()
		end
		f.psSpell, f.psName, f.psMax = n.spell, n.name, n.max
		f.psPlan, f.psFirst, f.psHave = planned, first[id], got
		f:Show()
	end

	local height = HEAD + (rows - 1) * vstep + size + 6
	root:SetHeight(height)
	root:Show()
	return height
end
