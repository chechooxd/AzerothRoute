-- The Talents section of the hub (the guide menu's shell): the talent plans
-- for the player's class, one per spec (Builds.lua), and where the player
-- stands on the one being followed (Talents.lua).
--
-- Tabs: one per spec (the sidebar index). Under them two panes on the guide
-- menu's grid, as Rares: the plan (left, its picks in order, numbered, in
-- bands of ten; learned picks muted, the next one marked) and the plan's
-- page (right, on the panel ground): where you stand, "Follow this plan" /
-- "Follow my spec", the plan's notes (at approximate levels: points can come
-- earlier than one a level), and its source. Talent names are the client's
-- on every tab, not only the followed plan's.
--
-- Registered with UI.RegisterSection; opened by SHOW_TALENTS.
--
-- AzerothRoute: tabs are keyed by plan, not spec, so plans imported from a talent calculator link
-- (Talents/Import.lua) get tabs of their own beside the class's three, and a last tab, "Import a
-- plan", holds the paste box. An imported plan's page names its link and can remove it.

local ADDON, ns = ...
local UI, Theme, W = ns.UI, ns.Theme, ns.Widgets
local T = ns.Talents
local L = ns.L
local max, min, floor, ipairs, pairs, format, tostring = math.max, math.min, math.floor, ipairs, pairs, string.format, tostring

if not (UI and W and W.SHELL and T) then return end

local SH = W.SHELL
local LIST_W = 272
local ROW_X = 12
local TEXT_X = SH.pad - ROW_X
local ROW_H = 26
local HEAD_H = 34
local FOOT_PAD = 24
local FOOT_H = 28 + FOOT_PAD * 2
local DPAD = SH.side
local DOT = "  \194\183  "
local BAND = 10 -- picks per list heading

local TV = {}
UI.TalentsSection = TV

local tab -- the plan key shown, or IMPORT_TAB; nil: the followed plan's
local IMPORT_TAB = "import"
local root, shellRef, list, detail, soon, importer
local rows, bands, heads, notes = {}, {}, {}, {}
local shown = {}

-- AzerothRoute: each pick shows its talent's icon, and the talent's tooltip on hover.
local ICON = 18
local function spellIcon(spell)
	if not spell then return nil end
	if C_Spell and C_Spell.GetSpellTexture then
		local ok, t = pcall(C_Spell.GetSpellTexture, spell)
		if ok and t then return t end
	end
	if GetSpellTexture then
		local ok, t = pcall(GetSpellTexture, spell)
		if ok and t then return t end
	end
	return table.concat({ "Interface", "Icons", "INV_Misc_QuestionMark" }, string.char(92))
end
TV.SpellIcon = spellIcon

local function showPickTip(r)
	local p, GT = r.psPick, GameTooltip
	if not (p and GT) then return end
	GT:SetOwner(r, "ANCHOR_RIGHT")
	local ok = r.psSpell and GT.SetSpellByID and pcall(GT.SetSpellByID, GT, r.psSpell)
	if not ok then GT:SetText(r.Title:GetText() or "") end
	local n = r.psNode
	GT:AddLine(" ")
	GT:AddLine(format(L["Pick %d of the plan, rank %d of %d"], p.order, p.rank, n and n.max or p.rank), 0.6, 0.8, 1)
	GT:Show()
end

local function row(i)
	local r = rows[i]
	if r then return r end
	r = CreateFrame("Frame", nil, list.Scroll.Child)
	r:SetHeight(ROW_H)
	r.Selected = r:CreateTexture(nil, "BACKGROUND")
	r.Selected:SetTexture(Theme.Media("white"))
	r.Selected:SetAllPoints(r)
	W.Painter(r.Selected, function(t) t:SetVertexColor(Theme.Wash("selected")) end)
	r.Bar = r:CreateTexture(nil, "ARTWORK")
	r.Bar:SetTexture(Theme.Media("white"))
	r.Bar:SetWidth(2)
	r.Bar:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
	r.Bar:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
	W.Color(r.Bar, "accent")
	r.Level = W.Text(r, "number", "textMuted")
	r.Level:SetPoint("RIGHT", r, "LEFT", TEXT_X - 8, 0)
	r.Icon = r:CreateTexture(nil, "ARTWORK")
	r.Icon:SetSize(ICON, ICON)
	r.Icon:SetPoint("LEFT", r, "LEFT", TEXT_X, 0)
	r.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	r.Title = W.Text(r, "body", "text")
	r.Title:SetPoint("LEFT", r.Icon, "RIGHT", 6, 0)
	r:EnableMouse(true)
	r:SetScript("OnEnter", showPickTip)
	r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	r.Sub = W.Text(r, "small", "textMuted")
	r.Sub:SetJustifyH("RIGHT")
	r.Sub:SetPoint("RIGHT", r, "RIGHT", -10, 0)
	rows[i] = r
	return r
end

local function band(i)
	local h = bands[i]
	if h then return h end
	h = CreateFrame("Frame", nil, list.Scroll.Child)
	h:SetHeight(HEAD_H)
	h.Text = W.Text(h, "label", "textMuted")
	h.Text:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", TEXT_X, 8)
	bands[i] = h
	return h
end

function TV.Build(parent, shell)
	if root then return root end
	shellRef = shell
	root = CreateFrame("Frame", nil, parent)
	root:SetAllPoints(parent)
	list = CreateFrame("Frame", nil, root)
	list:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
	list:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 0, 0)
	list:SetWidth(LIST_W)
	list.Scroll = W.Scroll(list)
	list.Scroll:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -4)
	list.Scroll:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, 8)
	list.Scroll.Child:SetWidth(LIST_W)
	list.Empty = W.Text(list.Scroll.Child, "note", "textMuted")
	list.Empty:SetWordWrap(true)
	list.Empty:SetWidth(LIST_W - TEXT_X * 2)
	list.Empty:SetJustifyH("LEFT")
	list.Empty:SetPoint("TOPLEFT", list.Scroll.Child, "TOPLEFT", SH.pad, -8)

	local d = CreateFrame("Frame", nil, root)
	detail = d
	d:SetPoint("TOPLEFT", list, "TOPRIGHT", 0, 0)
	d:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0)
	W.Fill(d, "panel")
	local rule = W.Divider(d, true)
	rule:SetPoint("TOPLEFT", d, "TOPLEFT", 0, 0)
	rule:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 0, 0)
	d.Foot = CreateFrame("Frame", nil, d)
	d.Foot:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 1, 0)
	d.Foot:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", 0, 0)
	d.Foot:SetHeight(FOOT_H)
	d.FootRule = W.Divider(d.Foot)
	d.FootRule:SetPoint("TOPLEFT", d.Foot, "TOPLEFT", 0, 0)
	d.FootRule:SetPoint("TOPRIGHT", d.Foot, "TOPRIGHT", 0, 0)
	d.Follow = W.Button(d.Foot, L["Follow this plan"], function() TV.Follow() end, { primary = true, height = 28, icon = "icon-learn" })
	d.Follow:SetPoint("BOTTOMRIGHT", d.Foot, "BOTTOMRIGHT", -FOOT_PAD, FOOT_PAD)
	d.Auto = W.Button(d.Foot, L["Follow my spec"], function() TV.FollowSpec() end, { height = 28 })
	d.Auto.psTip = L["Pick the plan for the spec AzerothRoute's gear advice uses."]
	-- AzerothRoute: Apply talents, on the followed plan while a point waits (Talents/Apply.lua).
	d.Apply = W.Button(d.Foot, L["Apply talents"], function() if T.Apply then T.Apply.Run() end end, { height = 28 })
	d.Apply:SetPoint("BOTTOMLEFT", d.Foot, "BOTTOMLEFT", FOOT_PAD, FOOT_PAD)
	d.Apply.psTip = L["Spend your unspent points on this plan's next picks, in order."]
	d.Apply:Hide()
	-- AzerothRoute: Remove, on an imported plan (a second click within three seconds confirms).
	d.Remove = W.Button(d.Foot, L["Remove plan"], nil, { ghost = true, height = 28 })
	d.Remove.psSetText = W.SetButtonText
	W.Confirm(d.Remove, L["Remove plan"], function() TV.RemoveShown() end)
	d.Remove:SetPoint("BOTTOMLEFT", d.Foot, "BOTTOMLEFT", FOOT_PAD, FOOT_PAD)
	d.Remove:Hide()
	d.Scroll = W.Scroll(d)
	d.Scroll:SetPoint("TOPLEFT", d, "TOPLEFT", 0, -1)
	d.Scroll:SetPoint("BOTTOMRIGHT", d.Foot, "TOPRIGHT", -4, 4)
	d.Body = d.Scroll.Child
	d.Title = W.Text(d.Body, "display", "text")
	d.Sub = W.Text(d.Body, "small", "textDim")

	-- Coming soon (T.SOON): the AzerothRoute emblem in colour, in its soft glow (as on the
	-- options' About page), the heading, why, and what still follows the
	-- player's own talents, centred on the panel.
	soon = CreateFrame("Frame", nil, root)
	soon:SetAllPoints(root)
	W.Fill(soon, "panel")
	soon.Glyph = W.Tex(soon, "ARTWORK", "emblem-color")
	soon.Glyph:SetSize(72, 72)
	soon.Glyph:SetPoint("CENTER", soon, "CENTER", 0, 92)
	soon.Glow = W.Tex(soon, "BACKGROUND", "glow")
	soon.Glow:SetSize(200, 200)
	soon.Glow:SetPoint("CENTER", soon.Glyph, "CENTER", 0, 0)
	W.Painter(soon.Glow, function(t) local r, g, b = Theme.Accent(); t:SetVertexColor(r, g, b, 0.14) end)
	soon.Title = W.Text(soon, "hero", "text")
	soon.Title:SetJustifyH("CENTER")
	soon.Title:SetPoint("TOP", soon.Glyph, "BOTTOM", 0, -26)
	soon.Title:SetText(L["Coming soon"])
	soon.Text = W.Text(soon, "note", "textDim")
	soon.Text:SetJustifyH("CENTER")
	soon.Text:SetWordWrap(true)
	soon.Text:SetSpacing(3)
	soon.Text:SetWidth(420)
	soon.Text:SetPoint("TOP", soon.Title, "BOTTOM", 0, -12)
	soon.Text:SetText(L["Talent plans for every class are on their way. We're taking the time to get every pick right before AzerothRoute suggests one."])
	soon.Foot = W.Text(soon, "small", "textMuted")
	soon.Foot:SetJustifyH("CENTER")
	soon.Foot:SetWidth(420)
	soon.Foot:SetPoint("TOP", soon.Text, "BOTTOM", 0, -18)
	soon.Foot:SetText(L["Gear advice still follows the talents you choose."])
	soon:Hide()
	return root
end

local function detailWidth()
	local full = shellRef and (shellRef:GetWidth() - (shellRef.psRail or 0) - (shellRef.psSidebar or SH.sidebar) - 2) or 0
	if full <= 0 then full = 878 end
	return full - LIST_W
end

local function writer()
	local d = detail
	local width = detailWidth()
	d.Body:SetWidth(width)
	local w = { y = -24, h = 0, n = 0, width = width - DPAD * 2 - 8 }
	function w.title(text, sub)
		d.Title:ClearAllPoints()
		d.Title:SetPoint("TOPLEFT", d.Body, "TOPLEFT", DPAD, w.y)
		d.Title:SetText(text)
		d.Sub:ClearAllPoints()
		d.Sub:SetPoint("TOPLEFT", d.Title, "BOTTOMLEFT", 0, -8)
		d.Sub:SetText(sub or "")
		w.y = w.y - 24 - 8 - 14 - 8
	end
	function w.head(text, count)
		w.h = w.h + 1
		local h = heads[w.h] or W.SectionHeader(d.Body)
		heads[w.h] = h
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", d.Body, "TOPLEFT", DPAD, w.y)
		h:SetWidth(w.width)
		W.SetSection(h, text, count)
		h:Show()
		w.y = w.y - 44 - 2
	end
	function w.note(text, color)
		w.n = w.n + 1
		local n = notes[w.n]
		if not n then
			n = W.Text(d.Body, "note", "textDim")
			n:SetWordWrap(true)
			n:SetJustifyH("LEFT")
			n:SetJustifyV("TOP")
			notes[w.n] = n
		end
		W.Color(n, color or "textDim")
		n:ClearAllPoints()
		n:SetPoint("TOPLEFT", d.Body, "TOPLEFT", DPAD, w.y - 6)
		n:SetWidth(min(560, w.width))
		n:SetText(text)
		n:Show()
		w.y = w.y - 6 - n:GetStringHeight() - 10
		shown.notes[#shown.notes + 1] = text
	end
	return w
end

local function hideAll()
	for _, t in ipairs({ rows, bands, heads, notes }) do
		for _, r in ipairs(t) do r:Hide() end
	end
	if TV.HideTree then TV.HideTree() end
	if importer then importer:Hide() end
	if detail then detail.Remove:Hide() end
end

---------------------------------------------------------------------------
-- AzerothRoute: the Import a plan page
---------------------------------------------------------------------------

local function inputBox(parent, hint, onEnter)
	local e = CreateFrame("EditBox", nil, parent)
	e:SetAutoFocus(false)
	e:SetMaxLetters(400)
	Theme.Font(e, "label")
	W.Color(e, "text")
	e:SetHeight(30)
	e:SetTextInsets(10, 10, 0, 0)
	Theme.Skin(e, "editbox")
	e.Hint = W.Text(e, "label", "textMuted")
	e.Hint:SetWordWrap(false)
	e.Hint:SetJustifyH("LEFT")
	e.Hint:SetPoint("LEFT", e, "LEFT", 10, 0)
	e.Hint:SetPoint("RIGHT", e, "RIGHT", -10, 0)
	e.Hint:SetText(hint)
	e:SetScript("OnEditFocusGained", function(self) Theme.SetFocused(self, true) end)
	e:SetScript("OnEditFocusLost", function(self) Theme.SetFocused(self, false) end)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed", function(self) self:ClearFocus() onEnter() end)
	e:SetScript("OnTextChanged", function(self) self.Hint:SetShown(self:GetText() == "") end)
	return e
end

local lastImport -- { text, color }: the line under the boxes after the last try

-- Imports what the boxes hold; on success shows the new plan's tab.
function TV.ImportFromBoxes(link, name)
	local I = T.Import
	if not I then return end
	if importer then
		link = link or importer.Link:GetText()
		name = name or importer.Name:GetText()
	end
	local b, reason, a, c = I.Add(link, name)
	if not b then
		lastImport = { I.Message(reason, a, c), "warning" }
		TV.Render()
		return nil, reason
	end
	lastImport = nil
	if importer then
		importer.Link:SetText("")
		importer.Name:SetText("")
	end
	TV.SetTab(b.key)
	return b
end

local function buildImporter()
	if importer then return importer end
	local f = CreateFrame("Frame", nil, detail.Body)
	importer = f
	f.Link = inputBox(f, L["Paste the calculator link here (Ctrl+V)"], function() TV.ImportFromBoxes() end)
	f.Name = inputBox(f, L["A name for the plan (optional)"], function() TV.ImportFromBoxes() end)
	f.Go = W.Button(f, L["Import plan"], function() TV.ImportFromBoxes() end, { primary = true, height = 28, icon = "plus" })
	f:Hide()
	return f
end

local function renderImport(w)
	w.title(L["Import a plan"], L["From an Icy Veins talent calculator link"])
	w.note(L["Build a plan in the Icy Veins WoW Forever talent calculator, or open a guide's \"Open in Calculator\", and copy the page's address. Its points keep the order you spent them in."])
	local f = buildImporter()
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", detail.Body, "TOPLEFT", DPAD, w.y - 8)
	local width = min(560, w.width)
	f:SetSize(width, 30 + 10 + 30 + 12 + 28)
	f.Link:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
	f.Link:SetWidth(width)
	f.Name:SetPoint("TOPLEFT", f.Link, "BOTTOMLEFT", 0, -10)
	f.Name:SetWidth(width)
	f.Go:SetPoint("TOPLEFT", f.Name, "BOTTOMLEFT", 0, -12)
	f:Show()
	w.y = w.y - 8 - f:GetHeight() - 12
	if lastImport then
		w.note(lastImport[1], lastImport[2])
		shown.importError = lastImport[1]
	end
	local I = T.Import
	local list = I and I.List() or {}
	w.head(L["Imported plans"], #list)
	if #list == 0 then w.note(L["None yet. Imported plans get a tab of their own above."]) end
	for _, entry in ipairs(list) do w.note(entry.name, "text") end
	shown.page = IMPORT_TAB
end

-- Where the player stands on the plan they follow.
local function statusText(c)
	local s = c.state
	local data, nxt = c.data, s.next
	if s.status == "early" then return L["No talent points yet. The first pick is marked once the game gives you one."], "textDim" end
	if s.status == "complete" then return L["Every pick in this plan is learned."], "success" end
	if s.status == "offplan" then
		local n = 0
		for _, r in pairs(s.offPlan) do n = n + r end
		return format(n == 1 and L["1 point is spent outside this plan. Its marks on the talent frame show where; a respec puts you back on it."] or L["%d points are spent outside this plan. Its marks on the talent frame show where; a respec puts you back on it."], n), "warning"
	end
	if s.status == "behind" then
		if s.unspent == 1 then return format(L["1 point to spend. Next: %s."], T.PickText(data, nxt, c.valid)), "accent" end
		return format(L["%d points to spend. Next: %s."], s.unspent, T.PickText(data, nxt, c.valid)), "accent"
	end
	return format(L["On plan. Next point: %s."], T.PickText(data, nxt, c.valid)), "text"
end

local REASONS = {
	off = L["Talent plans are turned off. Turn them on under Options > Questing > Talents."],
	class = L["There is no talent plan for your class yet."],
	noconfig = L["The talent tree is not loaded yet. It will be once you are in the world."],
	notree = L["The talent tree is not loaded yet. It will be once you are in the world."],
}

-- c: the current state when this is the followed plan (progress marks);
-- valid: the live tree's names, for every plan.
local function renderList(build, c, valid)
	local s = c and c.state
	local y, nr, nb = 0, 0, 0
	local lastBand
	for _, p in ipairs(build.picks) do
		local b = floor((p.order - 1) / BAND) * BAND + 1
		if b ~= lastBand then
			lastBand = b
			nb = nb + 1
			local h = band(nb)
			h:ClearAllPoints()
			h:SetPoint("TOPLEFT", list.Scroll.Child, "TOPLEFT", ROW_X, -y)
			h:SetWidth(LIST_W - ROW_X * 2)
			h.Text:SetText(format(L["Picks %d-%d"], b, min(b + BAND - 1, #build.picks)))
			h:Show()
			y = y + HEAD_H
		end
		nr = nr + 1
		local r = row(nr)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", list.Scroll.Child, "TOPLEFT", ROW_X, -y)
		r:SetWidth(LIST_W - ROW_X * 2)
		local n = build.data.nodes[p.node]
		local done = s and (p.order < (s.next and s.next.order or math.huge))
		local isNext = s and s.next == p
		r.Selected:SetShown(isNext or false)
		r.Bar:SetShown(isNext or false)
		r.Level:SetText(tostring(p.order))
		r.Title:SetText(T.NodeName(build.data, p.node, valid))
		W.Color(r.Title, isNext and "accent" or (done and "textMuted" or "text"))
		r.Sub:SetText(format("%d/%d", p.rank, n.max))
		r.Title:SetWidth(max(40, min(LIST_W - ROW_X * 2 - TEXT_X - 50 - ICON - 6, floor(r.Title:GetStringWidth() + 1))))
		r.psPick = p
		r.psNode, r.psSpell = n, n and n.spell
		r.Icon:SetTexture(spellIcon(n and n.spell))
		r.Icon:SetDesaturated(done and true or false)
		r.Icon:SetAlpha(done and 0.6 or 1)
		r:Show()
		y = y + ROW_H
	end
	for i = nr + 1, #rows do rows[i]:Hide() end
	for i = nb + 1, #bands do bands[i]:Hide() end
	list.Empty:SetShown(nr == 0)
	W.SetScrollContent(list.Scroll, y + 16)
	shown.rows = nr
	shown.titles = {}
	for i = 1, nr do shown.titles[i] = rows[i].Title:GetText() end
end

local function actions(follow, auto)
	local d = detail
	d.Follow:SetShown(follow)
	d.Auto:SetShown(auto)
	d.Auto:ClearAllPoints()
	if follow then d.Auto:SetPoint("RIGHT", d.Follow, "LEFT", -8, 0) else d.Auto:SetPoint("BOTTOMRIGHT", d.Foot, "BOTTOMRIGHT", -FOOT_PAD, FOOT_PAD) end
	d.Foot:SetShown(follow or auto)
end

function TV.Render()
	if not root then return end
	hideAll()
	for k in pairs(shown) do shown[k] = nil end
	shown.notes = {}
	local data = T.Data()
	local c, reason = T.Current()
	-- Coming soon (T.SOON): one page over the whole section, no plan panes.
	local paused = reason == "soon"
	soon:SetShown(paused)
	list:SetShown(not paused)
	detail:SetShown(not paused)
	if paused then
		if shellRef then W.ShellTitle(shellRef, L["Talents"], L["A talent plan, pick by pick"]) end
		shown.empty = reason
		return
	end
	local w = writer()
	if not data or reason == "off" then
		reason = reason or "class"
		if shellRef then W.ShellTitle(shellRef, L["Talents"], L["A talent plan, pick by pick"]) end
		renderList({ picks = {} }, nil)
		list.Empty:SetText(L["No plan for this character."])
		w.title(L["Talents"])
		w.note(REASONS[reason] or REASONS.class)
		actions(false, false)
		shown.empty = reason
		W.SetScrollContent(detail.Scroll, -w.y + 24)
		return
	end
	local followed = c and c.build or T.ActiveBuild(data)
	-- AzerothRoute: the Import a plan tab.
	if tab == IMPORT_TAB then
		if shellRef then W.ShellTitle(shellRef, L["Talents"], L["Import a plan"]) end
		renderList({ picks = {} }, nil)
		list.Empty:SetText(L["Paste a link on the right; the plan shows here once imported."])
		renderImport(w)
		actions(false, false)
		detail.Apply:Hide()
		W.SetScrollContent(detail.Scroll, -w.y + 24)
		return
	end
	-- Tabs are keyed by plan; a key that is gone (a removed import) shows the followed plan.
	local build = (tab and T.BuildByKey(data, tab)) or followed
	local mine = build == followed
	if shellRef then
		W.ShellTitle(shellRef, L["Talents"], format(L["%s plan for %s"], followed.specName, UnitClass("player") or "")
			.. (c and c.state and (DOT .. format(L["%d of %d picks"], c.state.done, c.state.total)) or ""))
	end
	renderList(build, mine and c and c.state and c or nil, c and c.valid)
	w.title(format(L["%s plan"], build.specName), build.split .. DOT .. format(L["%d picks, in order"], #build.picks))
	shown.spec, shown.followed, shown.mine = build.specName, followed.specName, mine
	if reason == "stale" then
		w.note(format(L["This plan no longer matches the game's talent tree (missing: %s). It is shown as written, without marks on the talent frame, until AzerothRoute is updated."], table.concat(c.valid.missing, ", ")), "warning")
		shown.status = "stale"
	elseif not mine then
		w.note(format(L["You are following the %s plan."], followed.specName))
		shown.status = "other"
	elseif c and c.state then
		local text, color = statusText(c)
		w.note(text, color)
		shown.status = c.state.status
	elseif reason then
		w.note(REASONS[reason] or tostring(reason))
		shown.status = reason
	end
	if data.summary and mine then w.note(data.summary) end
	-- AzerothRoute: the plan as the class's talent trees, above the notes.
	if TV.DrawTree then
		w.head(L["Talent trees"])
		local th = TV.DrawTree(detail.Body, DPAD, w.y - 8, w.width, build, c, mine)
		w.y = w.y - 8 - th - 16
	end
	-- Keyed by the level the source plan reaches them at; shown as a rough
	-- guide only, since points can come sooner. Plans without notes skip the heading.
	local lvs = {}
	for lv in pairs(build.notes or {}) do lvs[#lvs + 1] = lv end
	table.sort(lvs)
	if #lvs > 0 then w.head(L["Notes"]) end
	for _, lv in ipairs(lvs) do w.note(format(L["Around level %d: %s"], lv, build.notes[lv]), "text") end
	w.head(L["Source"])
	if build.imported then
		w.note(format(L["Imported from %s, in the order of its points."], build.link or "?"))
	elseif build.updated then
		w.note(format(L["Picks from %s (%s, updated %s), one point a level, checked against the game's talent tree."], data.source, build.link or data.url, build.updated))
	else
		w.note(format(L["Picks from %s (%s), checked against the game's talent tree; notes in AzerothRoute's words."], data.source, data.url))
	end
	local choice = T.Choice()
	actions(not mine or choice == "auto", choice ~= "auto")
	local canApply = mine and c and c.staged and c.staged.status == "behind" and (c.staged.unspent or 0) > 0 or false
	detail.Apply:SetShown(canApply)
	if canApply then detail.Foot:Show() end
	shown.apply = canApply
	-- AzerothRoute: an imported plan can be removed (where Apply would sit when it has no points).
	detail.Remove:SetShown(build.imported and not canApply or false)
	if build.imported then detail.Foot:Show() end
	shown.removable = build.imported and true or false
	TV.shownKey = build.key
	if mine and choice == "auto" then W.SetButtonText(detail.Follow, L["Keep this plan"]) else W.SetButtonText(detail.Follow, L["Follow this plan"]) end
	detail.Follow.psTip = L["Follow this plan whatever spec gear advice uses."]
	shown.follow, shown.auto = detail.Follow:IsShown(), detail.Auto:IsShown()
	W.SetScrollContent(detail.Scroll, -w.y + 24)
end

local function repaint()
	local P = UI.Picker
	if root and root:IsVisible() and P and P.Render then P.Render() else TV.Render() end
end

function TV.SetTab(key)
	tab = key and tostring(key) or nil
	if list then W.ScrollTo(list.Scroll, 0) end
	if detail then W.ScrollTo(detail.Scroll, 0) end
	repaint()
end

-- The sidebar index: one tab per plan (the class's, then imported ones), then Import a plan.
function TV.Nav()
	local data = T.Data()
	if not data or T.SOON then return {}, nil end
	local c = T.Current()
	local followed = c and c.build or T.ActiveBuild(data)
	local out = {}
	for _, b in ipairs(data.builds) do
		out[#out + 1] = { key = b.key, label = b.specName, icon = b == followed and "icon-learn" or nil, count = b.split }
	end
	if T.Import then out[#out + 1] = { key = IMPORT_TAB, label = L["Import a plan"], icon = "plus" } end
	local current = tab
	if current ~= IMPORT_TAB and not (current and T.BuildByKey(data, current)) then current = followed.key end
	return out, current
end

function TV.Follow()
	local data = T.Data()
	if not data then return end
	local c = T.Current()
	local b = (tab and T.BuildByKey(data, tab)) or (c and c.build) or T.ActiveBuild(data)
	if b then return T.Choose(b.key) end
end

-- Removes the imported plan on show, then shows the followed plan.
function TV.RemoveShown()
	local key = TV.shownKey
	if not (key and T.Import and T.Import.Remove(key)) then return end
	tab = nil
	repaint()
end

function TV.FollowSpec()
	tab = nil
	T.Choose("auto")
end

function TV.Shown() return shown end
TV.rows = rows

function TV.Show()
	local P = UI.Picker
	if UI.ShowPicker then UI.ShowPicker() end
	if P and P.ShowSection then P.ShowSection("Talents") end
	TV.Render()
end

ns.On("SHOW_TALENTS", TV.Show)
ns.On("TALENTS_UPDATED", function() if root and root:IsVisible() then repaint() end end)

if UI.RegisterSection then
	UI.RegisterSection({
		key = "Talents", label = L["Talents"], icon = "icon-learn", order = 40,
		build = TV.Build, render = TV.Render,
		nav = TV.Nav, onNav = TV.SetTab,
	})
end
