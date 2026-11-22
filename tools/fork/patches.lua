-- AzerothRoute changes applied on top of the renamed Polestar code by tools/fork_polestar.lua.
-- Each patch: file (relative to addon/), find (exact text after the rename) and replace, or
-- create = true with the whole file in replace; why says what it is for.
-- A patch that no longer finds its text is reported and fails the run.

local function read(rel)
    local root = (debug.getinfo(1, "S").source:match("^@(.*)[/\\]tools[/\\]fork[/\\]patches%.lua$")) or "."
    local f = assert(io.open(root .. "/tools/fork/files/" .. rel, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

return {
    -- Flight games (odd/tasks/flight-games.md): AzerothRoute's own games on long flights, in place of
    -- Polestar's Freedoom Arcade (user, 2026-11-22: "se pueda jugar algo ligero ... menos Doom").
    { file = "AzerothRoute/Games/Games.xml", create = true, replace = read("Games/Games.xml"), why = "flight games: load list" },
    { file = "AzerothRoute/Games/Host.lua", create = true, replace = read("Games/Host.lua"), why = "flight games: the game window" },
    { file = "AzerothRoute/Games/RuneFall.lua", create = true, replace = read("Games/RuneFall.lua"), why = "flight games: Rune Fall" },
    { file = "AzerothRoute/Games/SkyPatrol.lua", create = true, replace = read("Games/SkyPatrol.lua"), why = "flight games: Sky Patrol" },
    {
        file = "AzerothRoute/Maps/Arcade.lua", overwrite = true, replace = read("Maps/Arcade.lua"),
        why = "flight games: the offer on flights opens AzerothRoute's games",
    },
    {
        file = "AzerothRoute/AzerothRoute.toc",
        find = "UI\\UI.xml\r\n",
        replace = "UI\\UI.xml\r\nGames\\Games.xml\r\n",
        why = "flight games: loaded after the interface",
    },
    {
        file = "AzerothRoute_Options/Maps/Options.lua",
        find = [=[	register({ page = L["Integrations"], section = "Freedoom Arcade", controls = {
		{ kind = "toggle", key = "maps.flightArcade", label = L["Offer Freedoom Arcade on flights"],
			help = L["On a flight with a minute or more to go, AzerothRoute asks if you want to play Freedoom Arcade by petllama while you wait: three levels of Freedoom, or the whole game when the Freedoom Arcade addon is installed. 10 seconds before you land, the game is saved, paused and closed. /ar arcade opens it any time."],
			search = "doom, freedoom, arcade, game, flight, taxi, petllama",]=],
        replace = [=[	register({ page = L["Integrations"], section = L["Flight games"], controls = {
		{ kind = "toggle", key = "maps.flightArcade", label = L["Offer a game on long flights"],
			help = L["On a flight with a minute or more to go, AzerothRoute asks if you want to play one of its light games while you wait: Rune Fall or Sky Patrol. 10 seconds before you land, or in a fight, the game is paused and closed, and it goes on where it was. /ar arcade opens them any time."],
			search = "game, games, arcade, flight, taxi, rune fall, sky patrol, play",]=],
        why = "flight games: the option names AzerothRoute's games",
    },
    {
        file = "AzerothRoute/UI/GuideFrameMenu.lua",
        find = [=[table.insert(items, 5, { text = L["Play Freedoom Arcade"], icon = "gamepad", onClick = function() arcade.Open() end })]=],
        replace = [=[table.insert(items, 5, { text = L["Play a game"], icon = "gamepad", onClick = function() arcade.Open() end })]=],
        why = "flight games: the menu row",
    },
    -- The looks and skin folders are not shipped (tools/fork_polestar.lua EXCLUDE): nothing asks for them.
    {
        file = "AzerothRoute/Core/Data.lua",
        find = [[local COMPANIONS = { "AzerothRoute_Guides", "AzerothRoute_Codex", "AzerothRoute_Options", "AzerothRoute_Looks", "AzerothRoute_Nav", "AzerothRoute_SkinAPI", "AzerothRoute_Arcade", "AzerothRoute_QuestDB", "AzerothRoute_ItemDB" }
local REQUIRED = { AzerothRoute_Guides = true, AzerothRoute_Codex = true, AzerothRoute_Options = true, AzerothRoute_Looks = true }]],
        replace = [[local COMPANIONS = { "AzerothRoute_Guides", "AzerothRoute_Codex", "AzerothRoute_Options", "AzerothRoute_Nav", "AzerothRoute_QuestDB", "AzerothRoute_ItemDB" }
local REQUIRED = { AzerothRoute_Guides = true, AzerothRoute_Codex = true, AzerothRoute_Options = true }]],
        why = "the looks, skin checks and arcade folders are not shipped, so they are neither required nor compared",
    },
    {
        file = "AzerothRoute/UI/Packs.lua",
        find = "local NEEDED = { AzerothRoute_Options = true, AzerothRoute_Looks = true }",
        replace = "local NEEDED = { AzerothRoute_Options = true }",
        why = "the looks folder is not shipped, so it is not turned back on",
    },
    {
        file = "AzerothRoute/README.txt", create = true, replace = read("README.txt"),
        why = "AzerothRoute's install notes and credits in place of Polestar's README",
    },
    -- HU-05: AzerothRoute 1's settings carry over once.
    {
        file = "AzerothRoute/Core/MigrateV1.lua", create = true, replace = read("Core/MigrateV1.lua"),
        why = "reads AzerothRoute 1's saved settings once (HU-05)",
    },
    {
        file = "AzerothRoute/Core/Core.xml",
        find = '\t<Script file="Perf.lua"/>\n',
        replace = '\t<Script file="Perf.lua"/>\n\t<Script file="MigrateV1.lua"/>\n',
        why = "loads the AzerothRoute 1 migration",
    },
    {
        file = "AzerothRoute/AzerothRoute.toc",
        find = "## SavedVariables: AzerothRouteDB\r\n",
        replace = "## SavedVariables: AzerothRouteDB, AzerothRouteSavedDB\r\n",
        why = "AzerothRoute 1's account settings (AzerothRouteSavedDB), read by Core/MigrateV1.lua",
    },
    -- Talents: Polestar's plans (27, every class) are on, with AzerothRoute's "Apply talents".
    {
        file = "AzerothRoute/Talents/Talents.lua", find = "T.SOON = true",
        replace = "T.SOON = false -- AzerothRoute: the plans are on (user request, 2026-11-20)",
        why = "shows the talent plans instead of Coming soon",
    },
    {
        file = "AzerothRoute_Options/UI/Options.lua",
        find = [[		-- Talents: { L["Talents"], { L["Talent plan"] } } here once the plans are back (Talents.lua, T.SOON).]],
        replace = [[		{ L["Talents"], { L["Talent plan"] } },]],
        why = "restores the Talents tab in Options now that the plans are on",
    },
    {
        file = "AzerothRoute/Talents/Apply.lua", create = true, replace = read("Talents/Apply.lua"),
        why = "Apply talents: spends unspent points on the followed plan (AzerothRoute 1 feature)",
    },
    {
        file = "AzerothRoute/Talents/Talents.xml",
        find = '\t<Script file="Builds.lua"/>\n',
        replace = '\t<Script file="Builds.lua"/>\n\t<Script file="Sources.lua"/>\n\t<Script file="IcyVeins.lua"/>\n\t<Script file="Import.lua"/>\n\t<Script file="Apply.lua"/>\n\t<Script file="Toast.lua"/>\n',
        why = "loads the Icy Veins plans (Sources.lua, generated IcyVeins.lua), imported plans, Apply.lua and the talent point card",
    },
    -- The Battle.net look (Theme/Battlenet.lua): rounded surfaces, flat headers, blue primary buttons.
    {
        file = "AzerothRoute/Theme/Battlenet.lua", create = true, replace = read("Theme/Battlenet.lua"),
        why = "the Battle.net look over the house style",
    },
    {
        -- The settings' groups are tabs in the top bar (Theme/Battlenet.lua): a group folded before
        -- would leave its tab without its pages, so none is folded.
        file = "AzerothRoute_Options/UI/Options.lua",
        find = "\t\t\tlocal fold = folded[g.key] and true or false\n",
        replace = "\t\t\tlocal fold = false -- AzerothRoute: groups are top bar tabs, never folded\n",
        why = "settings groups are never folded",
    },
    {
        -- The top bar's search is global (Theme/Battlenet.lua): typed outside a section with its own search,
        -- it looks the text up in Lookup (guides, items, mounts, NPCs, quests, places) instead of the guide list.
        file = "AzerothRoute/UI/Picker.lua",
        find = [=[	if s and text ~= "" then section = nil end
	-- A new search looks through every guide; a category picked while
	-- searching narrows it.]=],
        replace = [=[	-- AzerothRoute: the global search: Lookup takes the text.
	if text ~= "" and UI.ShowLookup then
		UI.ShowLookup({ query = text })
		return
	end
	if s and text ~= "" then section = nil end
	-- A new search looks through every guide; a category picked while
	-- searching narrows it.]=],
        why = "the hub's search is global (Lookup)",
    },
    {
        file = "AzerothRoute/UI/Picker.lua",
        find = "\twin.Search:SetShown(not s or s.search ~= nil)\n",
        replace = "\twin.Search:Show() -- AzerothRoute: the global search is there in every section\n",
        why = "the global search shows in every section",
    },
    -- Quest icons on enemy nameplates: on by default; the sword to kill, the bag to loot, as the target list
    -- (user, 2026-11-21: "que la barra del enemigo salga el saquito o espada segun lo que se requiera").
    {
        file = "AzerothRoute/Quests/QuestDB.lua",
        find = "\tnameplateIcons = false, -- quest icon on nameplates of objective mobs\n",
        replace = "\tnameplateIcons = true, -- quest icon on nameplates of objective mobs (AzerothRoute: on)\n",
        why = "nameplate quest icons on by default",
    },
    {
        file = "AzerothRoute/Quests/Tooltips.lua",
        find = [=[	-- All objectives on nameplates are mobs to kill or loot: show the game's skull.
	local skullTex = ns.Theme and ns.Theme.Media and ns.Theme.Media("icon-skull")
		or "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
	f.tex:SetTexture(skullTex)
	f.tex:SetVertexColor(1, 1, 1, 1)]=],
        replace = [=[		-- AzerothRoute: what the quest needs from the mob, as the target list shows it: the sword to kill
	-- it, the bag to loot an item it drops; in the accent.
	local T = ns.Theme
	f.tex:SetTexture(T and T.Media and T.Media((Q.NameplateLook(npc))) or "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
	if T and T.Accent then f.tex:SetVertexColor(T.Accent()) else f.tex:SetVertexColor(1, 1, 1, 1) end]=],
        why = "the nameplate icon says kill or loot",
    },
    {
        file = "AzerothRoute/Quests/Tooltips.lua",
        find = "-- Units currently showing a quest icon (tests, debugging).\n",
        replace = [=[-- AzerothRoute: the nameplate icon for NPC id: "icon-kill" while an open objective needs it killed, else
-- "icon-collect" while one needs an item it drops (the sword when both). -> media name
function Q.NameplateLook(npcID)
	local list = npcID and Q.ObjectivesForNpc(npcID)
	local loot = false
	for _, o in ipairs(list or {}) do
		if not o.done and not (o.entry and o.entry.ready) then
			if o.kind == 1 then return "icon-kill" end
			if o.kind == 2 then loot = true end
		end
	end
	return loot and "icon-collect" or "icon-kill"
end

-- Units currently showing a quest icon (tests, debugging).
]=],
        why = "kill or loot on the nameplate",
    },
    -- Lookup's preview (UI/Preview.lua): mounts, gear and NPCs as the collections show them.
    {
        file = "AzerothRoute/UI/Preview.lua", create = true, replace = read("UI/Preview.lua"),
        why = "Lookup's model preview",
    },
    {
        file = "AzerothRoute/UI/Lookup.lua",
        find = [=[	else
		d.Status:Hide()
	end
	local Lk = ns.Lookup]=],
        replace = [=[	else
		d.Status:Hide()
	end
	-- AzerothRoute: the thing itself, as the game's collections show it (UI/Preview.lua).
	if UI.LookupPreview then y = y + UI.LookupPreview.Show(d, s.kind, s.id, y, DETAIL_W - DPAD * 2) end
	local Lk = ns.Lookup]=],
        why = "the preview under a result's title",
    },
    {
        file = "AzerothRoute/UI/Lookup.lua",
        find = [=[	for _, p in ipairs({ d.Well, d.Title, d.Sub, d.Status, d.Head, d.Scroll, d.Note, d.Primary, d.Secondary }) do p:Hide() end]=],
        replace = [=[	for _, p in ipairs({ d.Well, d.Title, d.Sub, d.Status, d.Head, d.Scroll, d.Note, d.Primary, d.Secondary }) do p:Hide() end
	if UI.LookupPreview then UI.LookupPreview.Hide(d) end -- AzerothRoute]=],
        why = "no preview on an empty page",
    },
    {
        file = "AzerothRoute/UI/UI.xml",
        find = '\t<Script file="Lookup.lua"/>\n',
        replace = '\t<Script file="Preview.lua"/>\n\t<Script file="Lookup.lua"/>\n',
        why = "loads the preview before Lookup",
    },
    {
        -- Folded under the top bar (Theme/Battlenet.lua): the bar alone, the header and its title go too.
        file = "AzerothRoute_Options/UI/Options.lua",
        find = [=[		away(rawget(win, "ThanksLink"))
		O.HideMore()
		W.HideMenu()
		win:SetHeight(SH.header + 2)]=],
        replace = [=[		away(rawget(win, "ThanksLink"))
		-- AzerothRoute: under the top bar the window folds to the bar; the header (its title) goes too.
		local bar = rawget(win, "psTopBar")
		if bar then away(win.Header) end
		O.HideMore()
		W.HideMenu()
		win:SetHeight(bar and (bar + 2) or (SH.header + 2))]=],
        why = "folded settings keep the top bar only",
    },
    {
        -- The body's view height leaves out the Battle.net look's top bar (Theme/Battlenet.lua).
        file = "AzerothRoute/Theme/Widgets.lua",
        find = "\tf.psViewH = f:GetHeight() - SHELL.header - (tabs and SHELL.tabs or 0) - (foot and SHELL.footer or 0) - ph\n",
        replace = "\tf.psViewH = f:GetHeight() - (rawget(f, \"psTopBar\") or 0) - SHELL.header - (tabs and SHELL.tabs or 0) - (foot and SHELL.footer or 0) - ph\n",
        why = "the body's height under a top bar",
    },
    {
        file = "AzerothRoute/Theme/Theme.xml",
        find = '\t<Script file="Widgets.lua"/>\n',
        replace = '\t<Script file="Widgets.lua"/>\n\t<Script file="Battlenet.lua"/>\n\t<Script file="SkinClassic.lua"/>\n\t<Script file="SkinMarble.lua"/>\n\t<Script file="SkinTerminal.lua"/>\n',
        why = "loads the Battle.net look after the widgets it wraps, then AzerothRoute's skins over it",
    },
    -- AzerothRoute's own skins (user, 2026-11-22: "crea 2 nuevas skin para esta nueva ui"): Classic (the game's
    -- buttons and frames) and Marble (white marble and gold), registered through the Skin API's checks,
    -- which now load with the core (tools/fork_polestar.lua MOVE) instead of a folder of their own.
    {
        file = "AzerothRoute/Theme/Theme.xml",
        find = '\t<Script file="SkinApi.lua"/>\n',
        replace = '\t<Script file="SkinApi.lua"/>\n\t<Script file="SkinCheck.lua"/>\n',
        why = "loads the Skin API's checks with the core",
    },
    {
        file = "AzerothRoute/Theme/SkinClassic.lua", create = true, replace = read("Theme/SkinClassic.lua"),
        why = "the Classic skin",
    },
    {
        file = "AzerothRoute/Theme/SkinMarble.lua", create = true, replace = read("Theme/SkinMarble.lua"),
        why = "the Marble skin",
    },
    -- World objects that glow (user, 2026-11-22: "cuando se trate de misiones de interactuar con cosas del
    -- mundo ... estos objetos brillen como en wow retail y que esa opcion se pueda activar o no"): the object
    -- the game's interact targeting picks, when a quest needs it or it is a herb or ore vein.
    {
        file = "AzerothRoute/QoL/ObjectGlow.lua", create = true, replace = read("QoL/ObjectGlow.lua"),
        why = "the glow on quest objects, herbs and ore",
    },
    {
        file = "AzerothRoute/QoL/QoL.xml",
        find = '\t<Script file="InstanceTrack.lua"/>\n',
        replace = '\t<Script file="InstanceTrack.lua"/>\n\t<Script file="ObjectGlow.lua"/>\n',
        why = "loads the object glow",
    },
    {
        file = "AzerothRoute_Options/QoL/ObjectGlowOptions.lua", create = true, replace = read("QoL/ObjectGlowOptions.lua"),
        why = "the World objects settings",
    },
    {
        file = "AzerothRoute_Options/AzerothRoute_Options.toc",
        find = "Quests\\Options.lua\r\n",
        replace = "Quests\\Options.lua\r\nQoL\\ObjectGlowOptions.lua\r\n",
        why = "loads the World objects settings",
    },
    -- The XP bar's marks (the guide's level, completed quest XP) on a classic-style XP bar too (user,
    -- 2026-11-22: "en la barra de experiencia no se ve el dato que generamos", a screenshot of a classic bar):
    -- Polestar only looked for the game's tracking bars (StatusTrackingBarManager).
    {
        file = "AzerothRoute/QoL/XPMark.lua",
        find = [=[		if type(bar) == "table" and bar.StatusBar and bar.IsShown and bar:IsShown() then return bar end
	end
	return nil
end
Mark.Bar = xpBar]=],
        replace = [=[		if type(bar) == "table" and bar.StatusBar and bar.IsShown and bar:IsShown() then return bar end
	end
	return Mark.ClassicBar()
end
Mark.Bar = xpBar

-- AzerothRoute: without the game's tracking bars, the classic XP bar (MainMenuExpBar), or a UI addon's own,
-- found by its values: a shown StatusBar, named like an XP bar, holding the player's XP out of the level's.
-- The search runs once every 30 seconds at most while none is found; the bar found is kept.
local found, searched
local function isXPBar(sb)
	local ok, kind = pcall(sb.GetObjectType, sb)
	if not ok or kind ~= "StatusBar" then return false end
	local okShown, shown = pcall(sb.IsShown, sb)
	if not (okShown and shown) then return false end
	local xp = readable(UnitXP and UnitXP("player"))
	local limit = readable(UnitXPMax and UnitXPMax("player"))
	if type(xp) ~= "number" or type(limit) ~= "number" or limit <= 0 then return false end
	local okRange, _, hi = pcall(sb.GetMinMaxValues, sb)
	local okValue, value = pcall(sb.GetValue, sb)
	return okRange and okValue and readable(hi) == limit and readable(value) == xp
end
Mark.IsXPBar = isXPBar
function Mark.ClassicBar()
	local classic = _G.MainMenuExpBar
	if type(classic) == "table" and classic.IsShown and classic:IsShown() then return classic end
	if found and found:IsShown() then return found end
	local now = GetTime and GetTime() or 0
	if searched and now - searched < 30 then return nil end
	searched = now
	for name, v in pairs(_G) do
		if type(name) == "string" and type(v) == "table" and type(v.GetObjectType) == "function"
			and (name:find("[Xx][Pp]") or name:find("[Ee]xp")) and isXPBar(v) then
			found = v
			return v
		end
	end
	return nil
end
-- The part of the bar its fill covers: the tracking bar's StatusBar, or the bar itself.
function Mark.Fill(bar) return type(bar.StatusBar) == "table" and bar.StatusBar or bar end]=],
        why = "the guide mark on a classic-style XP bar",
    },
    {
        file = "AzerothRoute/QoL/XPMark.lua",
        find = "\t\tframe:SetAllPoints(bar.StatusBar)\n",
        replace = "\t\tframe:SetAllPoints(Mark.Fill(bar))\n",
        why = "the guide mark over a classic bar's fill",
    },
    {
        file = "AzerothRoute/QoL/QuestXP.lua",
        find = "\t\tframe:SetAllPoints(bar.StatusBar)\n",
        replace = "\t\tframe:SetAllPoints(type(bar.StatusBar) == \"table\" and bar.StatusBar or bar)\n",
        why = "completed quest XP over a classic bar's fill",
    },
    {
        file = "AzerothRoute/QoL/QuestXP.lua",
        find = "\tlocal tick = type(bar.ExhaustionTick) == \"table\" and bar.ExhaustionTick or nil\n",
        replace = "\tlocal tick = type(bar.ExhaustionTick) == \"table\" and bar.ExhaustionTick\n\t\tor (bar == _G.MainMenuExpBar and type(_G.ExhaustionTick) == \"table\" and _G.ExhaustionTick) or nil\n",
        why = "the classic bar's rested tick",
    },
    {
        file = "AzerothRoute/QoL/QuestXP.lua",
        find = "\tlocal bar = QoL.XPMark.Bar()\n\tif not bar then if frame then frame:Hide() end; return end\n",
        replace = "\tlocal bar = QoL.XPMark.Bar()\n\tif not bar then if frame then frame:Hide() end; return end\n\t-- A classic-style bar is hooked as the tracking bars are (hookBars).\n\tif type(bar.StatusBar) ~= \"table\" and bar.HookScript then hook(bar) end\n",
        why = "a classic bar's show and tooltip hooks",
    },
    -- A classic bar has no OverlayFrame (a UI addon's may hold anything there): only a frame's level is read.
    {
        file = "AzerothRoute/QoL/XPMark.lua",
        find = "\tlocal over = bar.OverlayFrame\n",
        replace = "\tlocal over = type(bar.OverlayFrame) == \"table\" and bar.OverlayFrame or nil\n",
        why = "a classic bar without an overlay frame",
    },
    {
        file = "AzerothRoute/QoL/QuestXP.lua",
        find = "\tlocal overlay = bar.OverlayFrame\n",
        replace = "\tlocal overlay = type(bar.OverlayFrame) == \"table\" and bar.OverlayFrame or nil\n",
        why = "a classic bar without an overlay frame",
    },
    -- A third (user, 2026-11-22: "agrega otra skin tipo terminal code, cyberpunk").
    {
        file = "AzerothRoute/Theme/SkinTerminal.lua", create = true, replace = read("Theme/SkinTerminal.lua"),
        why = "the Terminal skin",
    },
    {
        file = "AzerothRoute/Theme/Widgets.lua",
        find = [=[		if self.psPrimary then
			local r, g, bb = Theme.Accent()
			if d and d.bg then d.bg:SetVertexColor(r, g, bb, 1) end
			if self.psBorder then for i = 1, 4 do self.psBorder[i]:SetVertexColor(r, g, bb, 1) end end
			W.Uncolor(self.Label)
			self.Label:SetTextColor(Theme.Color("onAccent"))
			if icon then icon:SetVertexColor(Theme.Color("onAccent")) end
			-- The house primary: one lit line inside its top edge.
			if Theme.SkinKey() == "polestar" and not self.psGhost then]=],
        replace = [=[		if self.psPrimary then
			-- AzerothRoute: a look may give primary buttons its own colour (Theme.PrimaryFill); else the accent.
			local r, g, bb = (Theme.PrimaryFill or Theme.Accent)()
			if d and d.bg then d.bg:SetVertexColor(r, g, bb, 1) end
			if self.psBorder then for i = 1, 4 do self.psBorder[i]:SetVertexColor(r, g, bb, 1) end end
			W.Uncolor(self.Label)
			if Theme.PrimaryText then self.Label:SetTextColor(Theme.PrimaryText()) else self.Label:SetTextColor(Theme.Color("onAccent")) end
			if icon then if Theme.PrimaryText then icon:SetVertexColor(Theme.PrimaryText()) else icon:SetVertexColor(Theme.Color("onAccent")) end end
			-- The house primary: one lit line inside its top edge (not on the Battle.net look's rounded button).
			if Theme.SkinKey() == "polestar" and not self.psGhost and not Theme.Battlenet then]=],
        why = "primary buttons in Battle.net blue with white text",
    },
    -- The target button and its list: common mobs in the accent gold, not red (user, 2026-11-21: "corrige esos
    -- colores, son horribles y no pega con el azul"); elites stay quest blue, NPCs green, far items red.
    {
        file = "AzerothRoute/QoL/Buttons.lua",
        find = '\treturn VERB_ICON[verb] or "icon-kill", "danger", false\n',
        replace = '\treturn VERB_ICON[verb] or "icon-kill", "accent", false -- AzerothRoute: gold, not red\n',
        why = "common mobs in the accent gold",
    },
    {
        file = "AzerothRoute/QoL/Buttons.lua",
        find = [=[		local tone = look and select(2, Buttons.TargetLook(look[1], r.applied, look[2], look[3])) or "danger"
		color(r.Name, tone)
		color(r.Note, "textDim")
		color(r.Mark, (r.closeUnit or r.psNear) and "success" or (tone == "success" and "textDim" or "danger"))]=],
        replace = [=[		local tone = look and select(2, Buttons.TargetLook(look[1], r.applied, look[2], look[3])) or "accent"
		color(r.Name, tone)
		color(r.Note, "textDim")
		color(r.Mark, (r.closeUnit or r.psNear) and "success" or (tone == "success" and "textDim" or "accent"))]=],
        why = "the target list's mob rows in the accent gold",
    },
    {
        file = "AzerothRoute/QoL/Buttons.lua",
        find = [=[		b.Icon:SetTexture(media("qol-target"))
		color(b.Icon, "danger")]=],
        replace = [=[		b.Icon:SetTexture(media("qol-target"))
		color(b.Icon, "accent")]=],
        why = "the target button's plain icon in the accent gold",
    },
    -- Only AzerothRoute's own design (the Battle.net look): Polestar's other looks are neither drawn nor offered.
    {
        file = "AzerothRoute/Theme/Theme.lua",
        find = [=[	local id = "polestar"
	if SKINS[k] and not FAILED[k] and (Theme._testShowHidden or not HIDDEN_SKINS[k]) then id = k end]=],
        replace = [=[	-- AzerothRoute: its own designs only (its look and its own skins, Theme/SkinClassic.lua,
	-- SkinMarble.lua); another saved choice is kept, never drawn.
	local id = "polestar"
	local own = SKINS[k]
	if own and not own.builtin and own.addon == ADDON and not FAILED[k] then id = k end]=],
        why = "only AzerothRoute's designs are drawn",
    },
    {
        file = "AzerothRoute/Theme/Theme.lua",
        find = [=[		if s and (Theme._testShowHidden or not HIDDEN_SKINS[id]) then
			if s.builtin then]=],
        replace = [=[		-- AzerothRoute: its own designs only (its look and its own skins).
		if s and (id == "polestar" or (not s.builtin and s.addon == ADDON)) and (Theme._testShowHidden or not HIDDEN_SKINS[id]) then
			if s.builtin then]=],
        why = "only AzerothRoute's designs are offered",
    },
    -- Gathering routes (Core/Routes.lua, UI/Routes.lua): every spot of a zone from the gather data.
    {
        file = "AzerothRoute/Core/Gather.lua",
        find = 'ns.RegisterEvent("MINIMAP_UPDATE_TRACKING", function() ns.Fire("GATHER_UP_CHANGED") end)\n',
        replace = [=[ns.RegisterEvent("MINIMAP_UPDATE_TRACKING", function() ns.Fire("GATHER_UP_CHANGED") end)

-- AzerothRoute: every spot of a zone, whatever the character gathers now (Core/Routes.lua):
-- { { k, x, y, f }... }, x and y in map percent, f "e" on an Era frame.
function Gather.Spots(map)
	local out = {}
	local text = data and data.maps and data.maps[map]
	if not text then return out end
	local frame = text:sub(1, 1) == "e" and "e" or nil
	for k, spots in text:gmatch(";(%d+):([^;]*)") do
		k = tonumber(k)
		for p = 1, #spots - 3, 4 do
			local x, y = percent(spots, p), percent(spots, p + 2)
			if k and x and y then out[#out + 1] = { k = k, x = x, y = y, f = frame } end
		end
	end
	return out
end

-- AzerothRoute: the zones the data has spots for (uiMapIDs, sorted).
function Gather.Maps()
	local out = {}
	for map in pairs(data and data.maps or {}) do out[#out + 1] = map end
	table.sort(out)
	return out
end
]=],
        why = "gathering routes read every spot of a zone",
    },
    {
        file = "AzerothRoute/Core/Core.xml",
        find = '\t<Script file="GatherData.lua"/>\n',
        replace = '\t<Script file="GatherData.lua"/>\n\t<Script file="Routes.lua"/>\n',
        why = "loads the gathering routes after the gather data",
    },
    {
        file = "AzerothRoute/Core/Routes.lua", create = true, replace = read("Core/Routes.lua"),
        why = "gathering routes: loops of node spawn spots for the character's skill",
    },
    {
        file = "AzerothRoute/UI/Routes.lua", create = true, replace = read("UI/Routes.lua"),
        why = "the Gathering routes section of the hub",
    },
    -- Self-found characters have no auction house: no buys on the card, the reminder or the list.
    {
        file = "AzerothRoute/Quests/AuctionBuys.lua",
        find = 'function AB.On() return ns.Get("qol.auctionBuys") and true or false end',
        replace = [=[function AB.On()
	-- AzerothRoute: never for a self-found character (C_PlayerInfo.IsSelfFoundActive), who has no auction house.
	local M = ns.Materials
	if M and M.SelfFound and M.SelfFound() then return false end
	return ns.Get("qol.auctionBuys") and true or false
end]=],
        why = "no auction house buys for self-found characters",
    },
    -- Deaths at each level in the XP tracker's splits (the milestone card, UI/Milestone.lua).
    {
        file = "AzerothRoute/QoL/XP.lua",
        find = "\ts.levelSeconds, s.levelXP, s.levelKills, s.levelQuests = 0, 0, 0, 0\n",
        replace = "\ts.levelSeconds, s.levelXP, s.levelKills, s.levelQuests = 0, 0, 0, 0\n\ts.levelDeaths = 0 -- AzerothRoute: deaths at this level\n",
        why = "a new level starts with no deaths",
    },
    {
        file = "AzerothRoute/QoL/XP.lua",
        find = "\t\tquests = s.levelQuests or 0,\n",
        replace = "\t\tquests = s.levelQuests or 0,\n\t\tdeaths = s.levelDeaths or 0, -- AzerothRoute\n",
        why = "each level's split keeps its deaths",
    },
    {
        file = "AzerothRoute/QoL/XP.lua",
        find = 'ns.RegisterEvent("PLAYER_LOGOUT", tick)\n',
        replace = [=[ns.RegisterEvent("PLAYER_LOGOUT", tick)
-- AzerothRoute: deaths at this level (PLAYER_DEAD), for the milestone card (UI/Milestone.lua).
ns.RegisterEvent("PLAYER_DEAD", function()
	if not enabled() then return end
	local s = levelState()
	s.levelDeaths = (s.levelDeaths or 0) + 1
end)
]=],
        why = "counts deaths at each level",
    },
    {
        file = "AzerothRoute/UI/Milestone.lua", create = true, replace = read("UI/Milestone.lua"),
        why = "the milestone card every 10 levels",
    },
    {
        file = "AzerothRoute_Options/QoL/Options.lua",
        find = [=[		help = L["XP per hour, time, kills and quests to level, and level splits (/ar xp)."], search = "experience, xp per hour, exp, leveling speed, time to level" },
]=],
        replace = [=[		help = L["XP per hour, time, kills and quests to level, and level splits (/ar xp)."], search = "experience, xp per hour, exp, leveling speed, time to level" },
	-- AzerothRoute: the milestone card (UI/Milestone.lua).
	{ kind = "toggle", key = "qol.milestoneCard", label = L["Milestone card every 10 levels"], child = true,
		disabled = function() return not ns.Get("qol.xpTracker") end,
		help = L["At levels 20, 30, 40, 50 and 60, a card with those ten levels' time, kills, quests and deaths, against your best other character."],
		search = "milestone, level 60, leveling time, deaths, speedrun" },
]=],
        why = "the milestone card's setting",
    },
    {
        file = "AzerothRoute/UI/Pace.lua", create = true, replace = read("UI/Pace.lua"),
        why = "the Leveling pace section: XP per hour, time to the next level and to the cap, level bars",
    },
    {
        file = "AzerothRoute/UI/UI.xml",
        find = '\t<Script file="WhatsNew.lua"/>\n',
        replace = '\t<Script file="WhatsNew.lua"/>\n\t<Script file="Pace.lua"/>\n\t<Script file="Milestone.lua"/>\n\t<Script file="Routes.lua"/>\n',
        why = "loads the Leveling pace section after the hub (Picker.lua) and the milestone card",
    },
    {
        file = "AzerothRoute/Talents/Toast.lua", create = true, replace = read("Talents/Toast.lua"),
        why = "the talent point card: the plan's next talent with Apply and View plan after a level-up",
    },
    {
        file = "AzerothRoute/Talents/Talents.lua",
        find = [=[	ns.Print(format(L["Talent point: %s (%s plan)."], T.PickText(c.data, s.next, c.valid), c.build.specName))
end]=],
        replace = [=[	ns.Print(format(L["Talent point: %s (%s plan)."], T.PickText(c.data, s.next, c.valid), c.build.specName))
	-- AzerothRoute: and the talent point card, with Apply (Talents/Toast.lua).
	if T.Toast then T.Toast.Notify(c) end
end]=],
        why = "shows the talent point card after a level-up",
    },
    {
        file = "AzerothRoute_Options/Talents/Options.lua",
        find = [=[			help = L["A chat line naming the plan's next talent when a point is waiting."] },
]=],
        replace = [=[			help = L["A chat line naming the plan's next talent when a point is waiting."] },
		-- AzerothRoute: the talent point card (Talents/Toast.lua).
		{ kind = "toggle", key = "talents.toast", label = L["Show a card with Apply when a point is waiting"], disabled = function() return off() or not T.Get("reminder") end, child = true,
			search = "talents, talent points, card, toast, apply, level up",
			help = L["After a level-up, a card names the plan's next talent with Apply talents and View plan."] },
]=],
        why = "the talent point card's setting",
    },
    {
        file = "AzerothRoute/Talents/Sources.lua", create = true, replace = read("Talents/Sources.lua"),
        why = "T.UseSource: the talent plans from another source in place of the snapshot's",
    },
    {
        file = "AzerothRoute/Talents/Import.lua", create = true, replace = read("Talents/Import.lua"),
        why = "talent plans imported from an Icy Veins calculator link pasted in the game",
    },
    {
        -- AzerothRoute owns the Talents view: Polestar's, with the Apply button, icons and tooltips,
        -- the talent trees, the Icy Veins source line, tabs keyed by plan and the Import page.
        file = "AzerothRoute/Talents/View.lua", overwrite = true, replace = read("Talents/View.lua"),
        why = "AzerothRoute's Talents view",
    },
    -- Identity: "the route" (2026-11-21). WoW Forever's blue and gold: night blue #0A1A33 grounds,
    -- gold #F2C14E accent, Forever blue #4DB4FF for quests and the route, warm white #F5EFE0 text,
    -- jade for what is done; own art in tools/fork/assets.
    {
        file = "AzerothRoute/Theme/House.lua", find = "local DEFAULT_ACCENT = { 0.9, 0.73, 0.4 }",
        replace = "local DEFAULT_ACCENT = { 0.949, 0.757, 0.306 } -- AzerothRoute: Forever gold #F2C14E",
        why = "AzerothRoute's accent",
    },
    {
        file = "AzerothRoute/Theme/House.lua", find = "\tsuccess = { 0.42, 0.85, 0.6, 1 },",
        replace = "\tsuccess = { 0.361, 0.769, 0.604, 1 }, -- AzerothRoute: jade",
        why = "AzerothRoute's done colour",
    },
    {
        file = "AzerothRoute/Theme/House.lua", find = "\tquest = { 1, 0.84, 0.45, 1 },",
        replace = "\tquest = { 0.302, 0.706, 1, 1 }, -- AzerothRoute: Forever blue #4DB4FF",
        why = "AzerothRoute's Forever blue for quests and the route",
    },
    {
        file = "AzerothRoute/Theme/House.lua",
        find = [[	dusk = {
		bg = { 0.095, 0.115, 0.178, 0.97 },
		panel = { 0.11, 0.133, 0.203, 0.98 },
		panelAlt = { 0.139, 0.166, 0.249, 1 },
		sidebar = { 0.072, 0.088, 0.14, 1 },
		footer = { 0.08, 0.097, 0.151, 1 },
		sky = { 0.156, 0.196, 0.329, 1 },
		text = { 0.967, 0.974, 0.991, 1 },
		textDim = { 0.765, 0.793, 0.868, 1 },
		textMuted = { 0.606, 0.637, 0.726, 1 },
		ink = { 1, 1, 1, 1 },
		star = { 1, 1, 1, 1 },
		shade = { 0, 0, 0.02, 1 },
		scrim = { 0.02, 0.03, 0.06, 1 },
		onAccent = { 0.04, 0.05, 0.08, 1 },
		shadow = { 0, 0, 0.02, 0.6 },
	},]],
        replace = [[	-- AzerothRoute: the default scheme, "Azeroth": WoW Forever's night blue #0A1A33 grounds, warm white #F5EFE0 text.
	dusk = {
		bg = { 0.039, 0.102, 0.2, 0.97 },
		panel = { 0.059, 0.141, 0.278, 0.98 },
		panelAlt = { 0.086, 0.2, 0.384, 1 },
		sidebar = { 0.031, 0.078, 0.165, 1 },
		footer = { 0.035, 0.09, 0.188, 1 },
		sky = { 0.102, 0.231, 0.439, 1 },
		text = { 0.961, 0.937, 0.878, 1 },
		textDim = { 0.824, 0.784, 0.69, 1 },
		textMuted = { 0.561, 0.651, 0.776, 1 },
		ink = { 0.961, 0.937, 0.878, 1 },
		star = { 0.949, 0.757, 0.306, 1 },
		shade = { 0, 0.01, 0.03, 1 },
		scrim = { 0.01, 0.04, 0.09, 1 },
		onAccent = { 0.039, 0.102, 0.2, 1 },
		shadow = { 0, 0.01, 0.03, 0.6 },
	},]],
        why = "AzerothRoute's default colour scheme",
    },
    {
        file = "AzerothRoute/Theme/SkinApi.lua", find = [[dusk = function() return ns.L["Dusk"] end,]],
        replace = [[dusk = function() return ns.L["Azeroth"] end,]],
        why = "names the default scheme Azeroth",
    },
    {
        file = "AzerothRoute/Theme/Widgets.lua", find = [[f.Tagline:SetText(opts.tagline or L["A community project"])]],
        replace = [[f.Tagline:SetText(opts.tagline or L["Your route through Azeroth"])]],
        why = "AzerothRoute's tagline in the Guide Center",
    },
    {
        file = "AzerothRoute/UI/OptionsLoader.lua", find = [[	tag:SetText(L["A community project"])]],
        replace = [[	tag:SetText(L["Your route through Azeroth"])]],
        why = "AzerothRoute's tagline in the game's AddOns options",
    },
    {
        file = "AzerothRoute/UI/Welcome.lua",
        find = [[L["AzerothRoute guides you step by step: who to talk to, what to kill or collect, and where to go."]],
        replace = [[L["AzerothRoute plans your route step by step: who to talk to, what to kill or collect, and where to go next."]],
        why = "the setup's welcome line in AzerothRoute's voice",
    },
    {
        file = "AzerothRoute/Core/Identity.lua", create = true, replace = read("Core/Identity.lua"),
        why = "AzerothRoute's identity words in Spanish",
    },
    {
        file = "AzerothRoute/Core/Core.xml",
        find = '\t<Script file="MigrateV1.lua"/>\n',
        replace = '\t<Script file="MigrateV1.lua"/>\n\t<Script file="Identity.lua"/>\n',
        why = "loads Identity.lua",
    },
    -- No trace of Polestar's channels (2026-11-20, user: "elimina todo rastro de polestar").
    {
        file = "AzerothRoute/Core/Commands.lua",
        find = [=[ns.RegisterCommand("discord", function() ns.Fire("SHOW_DISCORD") end, L["The invite to the AzerothRoute Discord"])
]=],
        replace = [=[]=],
        why = "no /ar discord: Polestar's community channel",
    },
    {
        file = "AzerothRoute/UI/Report.lua",
        find = [=[	F.DiscordTitle:SetText(L["Report it on Discord"])]=],
        replace = [=[	F.DiscordTitle:SetText(L["Send it to the developer"])]=],
        why = "report window: no Discord",
    },
    {
        file = "AzerothRoute/UI/Report.lua",
        find = [=[	F.DiscordNote:SetText(L["1. Press Copy report, then Ctrl+C (Cmd+C on a Mac).\n2. In the AzerothRoute Discord, open #bugs and press New Post. Not in it yet? Get the invite.\n3. Paste the report, give it a short title and post it. A bot files it for the developers and tells you in your thread when it's fixed."])]=],
        replace = [=[	F.DiscordNote:SetText(L["1. Press Copy report, then Ctrl+C (Cmd+C on a Mac).\n2. Paste it where you talk with the AzerothRoute developer, with a short line about what went wrong."])]=],
        why = "report window: no Discord",
    },
    {
        file = "AzerothRoute/UI/Report.lua",
        find = [=[	F.Invite = W.Button(F, L["Get the invite"], function() UI.ShowDiscord() end)]=],
        replace = [=[	F.Invite = W.Button(F, L["Get the invite"], function() UI.ShowDiscord() end)
	for _, w in ipairs({ F.Invite, F.Logo }) do w:Hide() w.Show = w.Hide w.SetShown = w.Hide end -- AzerothRoute: no Polestar channel]=],
        why = "report window: no Discord invite",
    },
    {
        file = "AzerothRoute/UI/Report.lua",
        find = [=[	F.GitHub = W.Button(F, L["Open on GitHub"], openGitHub)]=],
        replace = [=[	F.GitHub = W.Button(F, L["Open on GitHub"], openGitHub)
	for _, w in ipairs({ F.GitHub, F.GitHubNote, F.GitHubRule }) do w:Hide() w.Show = w.Hide w.SetShown = w.Hide end -- AzerothRoute: no Polestar channel]=],
        why = "report window: no Polestar GitHub issues",
    },
    {
        file = "AzerothRoute/UI/Report.lua",
        find = [=[function UI.ShowDiscord()]=],
        replace = [=[function UI.ShowDiscord()
	do return end -- AzerothRoute: no Polestar Discord]=],
        why = "no Discord invite window",
    },
    {
        file = "AzerothRoute/UI/Report.lua",
        find = [=[	if rawget(f, "Discord") or not rawget(f, "Sidebar") then return end]=],
        replace = [=[	do return end -- AzerothRoute: no Discord mark in the sidebar
	if rawget(f, "Discord") or not rawget(f, "Sidebar") then return end]=],
        why = "no Discord mark in the hub and options sidebar",
    },
    {
        file = "AzerothRoute/UI/Welcome.lua",
        find = [=[		p.Beta.Text:SetText((L["Played to the end in tests, but not yet by players. If a step is wrong, press %s in the guide window and tell us on Discord."]):format(cmd(L["Skip"])))]=],
        replace = [=[		p.Beta.Text:SetText((L["Played to the end in tests, but not yet by players. If a step is wrong, press %s in the guide window and send a report with /ar report."]):format(cmd(L["Skip"])))]=],
        why = "setup: no Discord",
    },
    {
        file = "AzerothRoute/UI/Welcome.lua",
        find = [=[		y = layNote(p, p.Recorder, y, true)]=],
        replace = [=[		y = layNote(p, p.Recorder, y, false) -- AzerothRoute: no Polestar Recorder]=],
        why = "setup: no Polestar Recorder row",
    },
    {
        file = "AzerothRoute/UI/Welcome.lua",
        find = [=[		y = layNote(p, p.Discord, y, true)]=],
        replace = [=[		y = layNote(p, p.Discord, y, false) -- AzerothRoute: no Discord]=],
        why = "setup: no Discord row",
    },
    {
        file = "AzerothRoute/UI/GuideFrame.lua",
        find = [=[		nav.Report.psTipLines = { L["Write what went wrong, copy the report and paste it on the AzerothRoute Discord."] }]=],
        replace = [=[		nav.Report.psTipLines = { L["Write what went wrong and copy the report for the AzerothRoute developer."] }]=],
        why = "guide window: no Discord",
    },
    {
        file = "AzerothRoute/Rares/Rares.lua",
        find = [=[	founder = true, -- say when the founder is nearby (Rares.FOUNDER)]=],
        replace = [=[	founder = false, -- AzerothRoute: no founder alert (Polestar's founder)]=],
        why = "no Polestar founder alert",
    },
    {
        file = "AzerothRoute_Options/Rares/Options.lua",
        find = [=[		{ kind = "toggle", key = "rares.founder", label = L["Say when AzerothRoute's founder is nearby"], disabled = off,
			search = "founder, fitz, wave, hello, say hi",
			help = string.format(L["When %s comes into sight, a card says so and the rare button targets him and waves. At most once a day, never in combat or instances."], Rares.FOUNDER) },
]=],
        replace = [=[]=],
        why = "no founder alert setting",
    },
    {
        file = "AzerothRoute_Options/UI/Options.lua",
        find = [=[	aiNote:SetText(L["This translation was made with AI. Help improve it on Discord."])]=],
        replace = [=[	aiNote:SetText(L["This translation was made with AI."])]=],
        why = "options: no Discord",
    },
    {
        file = "AzerothRoute_Options/UI/Options.lua",
        find = [=[	local aiLink = W.Link(view, (ns.DiscordURL:gsub("^%a+://", "")), function() UI.ShowDiscord() end)]=],
        replace = [=[	local aiLink = W.Link(view, (ns.DiscordURL:gsub("^%a+://", "")), function() UI.ShowDiscord() end)
	for _, w in ipairs({ aiLink }) do w:Hide() w.Show = w.Hide w.SetShown = w.Hide end -- AzerothRoute: no Polestar channel]=],
        why = "options: no Discord link",
    },
    {
        file = "AzerothRoute_Options/UI/Options.lua",
        find = [=[		.. hex .. "/ar report|r   " .. L["report a problem with a step on the AzerothRoute Discord"] .. "\n"]=],
        replace = [=[		.. hex .. "/ar report|r   " .. L["report a problem with a step"] .. "\n"]=],
        why = "options: no Discord",
    },
    {
        file = "AzerothRoute_Options/UI/Options.lua",
        find = [=[		.. hex .. "/ar arcade|r   " .. L["play Freedoom Arcade by petllama"] .. "\n"
]=],
        replace = [=[]=],
        why = "options: no arcade command (Arcade not shipped)",
    },
    {
        file = "AzerothRoute_Options/UI/Options.lua",
        find = [=[		.. L["Freedoom Arcade by petllama (GPL-2.0 or later) plays three levels of Freedoom by the Freedoom project (BSD License), from the AzerothRoute_Arcade folder."] .. "\n"
		.. L["Discord and its logo are trademarks of Discord Inc.; the logo marks the link to the AzerothRoute Discord."] .. "\n"]=],
        replace = [=[		.. L["Based on Polestar by The Polestar authors"] .. " (GPL-3.0-only)." .. "\n"]=],
        why = "options credits: the legal notice in place of the arcade and Discord lines",
    },
    {
        file = "AzerothRoute_Options/UI/Options.lua",
        find = [=[add({ page = REC, key = "recorder", icon = "record", order = 90, subtitle = L["The data recorder for guide authors."], custom = buildRecorder }, true)
]=],
        replace = [=[]=],
        why = "options: no Polestar Recorder page",
    },
    -- No Polestar history, thanks or community wording (2026-11-20, user: "cualquier rastro de polestar debe desaparecer").
    {
        file = "AzerothRoute_Options/UI/Options.lua",
        find = [=[add({ page = L["Guiding Stars"], key = "thanks", icon = "star", order = 80, subtitle = L["Celebrating the supporters, contributors and bug reporters behind AzerothRoute."],
	custom = UI.Thanks.Build }, true)
]=],
        replace = [=[]=],
        why = "no thanks page (Polestar's supporters and contributors)",
    },
    {
        -- With the special-thanks line off (Thanks.HeaderLink returns early) PlaceThanks is never
        -- set; Polestar's resize handler called it bare (0.5.1: an error on resizing Options).
        file = "AzerothRoute_Options/UI/Options.lua",
        find = [=[		if rawget(win, "psHeadTools") then placeInstall() end
		win.PlaceThanks()
	end)]=],
        replace = [=[		if rawget(win, "psHeadTools") then placeInstall() end
		if rawget(win, "PlaceThanks") then win.PlaceThanks() end
	end)]=],
        why = "resizing Options no longer calls the missing special-thanks placer",
    },
    {
        file = "AzerothRoute_Options/UI/Options.lua",
        find = [=[		.. L["Wordmark set in Cinzel by The Cinzel Project Authors, SIL Open Font License 1.1."] .. "\n"
]=],
        replace = [=[]=],
        why = "no Cinzel credit: the wordmark is AzerothRoute's own drawing",
    },
    {
        file = "AzerothRoute_Options/UI/Options.lua",
        find = [=[	-- Why Polestar: the manifesto, right under the hero. Body type so it reads
	-- as the page's lead; what Polestar does not claim stands out in text
	-- colour; the closing line apart in Title and text. The beta paragraph
	-- goes with the release stage.
	local whyH = W.SectionHeader(view)
	W.SetSection(whyH, L["Why AzerothRoute"])
	local paras = {
		L["Leveling guides have become a business: the best routes sit behind subscriptions and paywalls. AzerothRoute goes the other way. It is free, open source under the GPL-3.0, and built by the community that plays it."],
		hex .. L["AzerothRoute doesn't claim to be the fastest guide, or the smoothest. It is a free alternative, and it gets better with time."] .. "|r",
		L["Anyone can read the code, fix a step, sharpen a route or write a new guide, and contributions are welcome. The GPL keeps it that way: every copy and every fork stays open."],]=],
        replace = [=[	-- AzerothRoute: why it exists, in its own words.
	local whyH = W.SectionHeader(view)
	W.SetSection(whyH, L["Why AzerothRoute"])
	local paras = {
		L["AzerothRoute plans your road through Azeroth: every quest, every flight and every step, in order, so you play instead of planning."],
		hex .. L["It is free and open source under the GPL-3.0."] .. "|r",
	}
	if ns.stage then
		paras[#paras + 1] = L["It is young, so expect the odd wrong step or waypoint. Send a report with /ar report and it gets fixed."]
	end]=],
        why = "the About page's Why in AzerothRoute's words",
    },
    {
        file = "AzerothRoute/UI/Report.lua",
        find = [=[L["(trimmed to fit Discord)"]]=],
        replace = [=[L["(trimmed)"]]=],
        why = "report: no Discord",
    },
    {
        file = "AzerothRoute/UI/WhatsNew.lua",
        find = [=[local NOTES = {
	{
		version = "0.4.0",
		notes = {
			{ glyph = "icon-forever", color = "accent", head = L["Two new zones in your route"], text = function()
				return L["%s and %s are now part of the 1 to 60 route, for both factions."]:format(zone(2548, "Riverglades"), zone(2652, "Shen'dralas"))
			end },
			{ glyph = "guides", color = "accent", head = L["Safer, smoother routes"], text = function()
				return L["Every zone reviewed: less walking back, less grinding, fewer mobs well above your level."]
			end },
			{ glyph = "icon-dungeon", color = "accent", head = L["A dungeon instead of a grind"], text = function()
				return L["Grind steps suggest a dungeon that fits you now, with the game's own level ranges."]
			end },
			{ glyph = "icon-turnin", color = "accent", head = L["Finished quests stay found"], text = function()
				return L["Handed in where the route passes their NPC; when a guide ends, it says what carries on."]
			end },
			{ glyph = "sliders", color = "accent", head = L["A new settings window"], text = function()
				return L["Live previews, search that answers questions, Undo, and a short %s for new characters."]:format(L["Install"])
			end },
			{ glyph = "palette", color = "accent", head = L["New and rebuilt skins"], setting = "ui.skin", text = function()
				return L["Nine new skins; %s, %s, %s and %s rebuilt, arrow and all."]:format(L["WoW Forever"], L["Blizzard"], L["Classic"], L["Hearth"])
			end },
			{ glyph = "qol-target", color = "accent", head = L["A target list"], setting = "qol.targetRows", text = function()
				return L["The target button lists the step's mobs and what they drop; click one to target it."]
			end },
			{ glyph = "icon-repair", color = "accent", head = L["Small helpers"], setting = "behavior.whileHereVendors", text = function()
				return L["Sell and repair reminders before you leave town; compact mode now has tabs."]
			end },
			{ glyph = "icon-talk", color = "accent", head = L["Fully translated"], text = function()
				return L["In 9 languages, now with German and Latin American Spanish guides. Thanks, translators!"]
			end },
			{ glyph = "check", color = "success", head = L["Fixes from your reports"], text = function()
				return L["Caves, cities, flights and more. Found something off? Type %s."]:format(cmd("/ar report"))
			end },
		},
	},
	{
		version = "0.3.7",
		notes = {
			{ glyph = "dart", color = "accent", head = L["A steadier arrow"], text = function()
				return L["Keeps up on slopes and ledges, takes the faster flight, and no turning back after you land."]
			end },
			{ glyph = "bolt", color = "accent", head = L["Smoother indoors"], text = function()
				return L["No more stutter in the Undercity, buildings and caves; less work in the background."]
			end },
			{ glyph = "reload", color = "accent", head = L["Update notice"], setting = "update.card", text = function()
				return L["At login, a card says when a newer AzerothRoute is out and how to update."]
			end },
			{ glyph = "icon-train", color = "accent", head = L["New spells"], setting = "qol.levelUpSpells", text = function()
				return L["A level-up card lists what to train; %s updates your bars."]:format(cmd(L["Upgrade"]))
			end },
			{ glyph = "icon-accept", color = "accent", head = L["Quest helpers"], setting = "qol.questLoot", text = function()
				return L["Loot that starts a quest glows on the quest item button; timed quests count down."]
			end },
			{ glyph = "emblem", color = "accent", head = L["Hide it all"], setting = "maps.minimapButton", text = function()
				return L["A click on the minimap button hides all of AzerothRoute; another brings it back."]
			end },
			{ glyph = "menu", color = "accent", head = L["Browse all steps"], text = function()
				return L["Click the step number to see every step of the guide (thanks TTik3r and aalejandrofer)."]
			end },
			{ glyph = "icon-craft", color = "accent", head = L["Profession guides"], text = function()
				return L["Rebuilt on Forever's trainers, and they start where your skill is."]
			end },
			{ glyph = "icon-talk", color = "accent", head = L["Fully translated"], text = function()
				return L["All of 0.3.7 in 9 languages, with thanks to our translators."]
			end },
			{ glyph = "check", color = "success", head = L["Fixes from your reports"], text = function()
				return L["Routes, trainers, dungeons and more. Found something off? Type %s."]:format(cmd("/ar report"))
			end },
		},
	},
	{
		version = "0.3.6",
		notes = {
			{ glyph = "guides", color = "accent", head = L["Every route reviewed"], text = function()
				return L["More quests and shorter grinds at 40-60, fewer walk-backs, no pointless travel steps."]
			end },
			{ glyph = "icon-turnin", color = "accent", head = L["Dynamic Questing saves trips"], text = function()
				return L["Hand in and pick up at NPCs on your way; auto-accept takes the next steps' quests."]
			end },
			{ glyph = "qol-target", color = "accent", head = L["The arrow finds your targets"], text = function()
				return L["Grinds go to the nearest spawns, past emptied camps; Target shows who, pings, marks."]
			end },
			{ glyph = "dart", color = "accent", head = L["Route lines your way"], text = function()
				return L["%s, %s or %s on map and minimap: set in Install or in Settings."]:format(L["Line"], L["Dots"], L["Sparkles"])
			end },
			{ glyph = "icon-forever", color = "accent", head = L["New in Forever"], text = function()
				return L["Quests only Forever has carry a small ∞ mark."]
			end },
			{ glyph = "window", color = "accent", head = L["Tabs and windows"], text = function()
				return L["Closed tabs reopen where you were; %s backing; floating button; Esc menu."]:format(L["Transparent"])
			end },
			{ glyph = "icon-dungeon", color = "accent", head = L["Groups and dungeons"], text = function()
				return L["%s in a party; Dungeons shows what fits your level, when more unlock."]:format(cmd(L["Sync to my guide"]))
			end },
			{ glyph = "icon-elite", color = "accent", head = L["Rares"], text = function()
				return L["Target and ping a rare right from its card."]
			end },
			{ glyph = "icon-talk", color = "accent", head = L["Fully translated"], text = function()
				return L["In 9 languages, with thanks to our translators."]
			end },
			{ glyph = "check", color = "success", head = L["Fixes from your reports"], text = function()
				return L["Gear spec, trainers, map spots and more. Found something off? Type %s."]:format(cmd("/ar report"))
			end },
		},
	},
}]=],
        replace = [=[-- AzerothRoute: its own release notes (Polestar's history is not AzerothRoute's).
-- The newest release says @VERSION@ (from VERSION); older ones keep their number.
local NOTES = {
	{
		version = "@VERSION@",
		notes = {
			{ glyph = "palette", color = "accent", head = L["A new look"], text = function()
				return L["Rounded windows and buttons, a flat header, blue buttons and switches, and Continue guide at the foot of the menu, in the style of the Battle.net app."]
			end },
			{ glyph = "icon-collect", color = "accent", head = L["Gathering routes"], text = function()
				return L["A new page in the menu: a loop of herb or ore spots for your Herbalism or Mining in the best zones, and the arrow takes you round it."]
			end },
			{ glyph = "hourglass", color = "accent", head = L["Race your best character"], text = function()
				return L["Leveling pace now compares every level with your fastest other character: a mark on the bar and how much faster or slower you were."]
			end },
			{ glyph = "icon-level", color = "accent", head = L["A card every 10 levels"], text = function()
				return L["At 20, 30, 40, 50 and 60: those ten levels' time, kills, quests and deaths, against your best character. At 60, your whole run."]
			end },
			{ glyph = "check", color = "success", head = L["Self-found, respected"], text = function()
				return L["Self-found characters no longer get auction house buys."]
			end },
		},
	},
	{
		version = "0.5.2",
		notes = {
			{ glyph = "check", color = "success", head = L["Options window fix"], text = function()
				return L["Resizing the Options window no longer shows an error."]
			end },
			{ glyph = "palette", color = "accent", head = L["WoW Forever's blue and gold"], text = function()
				return L["The Azeroth colours now match WoW Forever: night blue grounds, gold, and Forever blue for quests and the route."]
			end },
		},
	},
	{
		version = "0.5.1",
		notes = {
			{ glyph = "palette", color = "accent", head = L["WoW Forever's blue and gold"], text = function()
				return L["The Azeroth colours now match WoW Forever: night blue grounds, gold, and Forever blue for quests and the route."]
			end },
		},
	},
	{
		version = "0.5.0",
		notes = {
			{ glyph = "hourglass", color = "accent", head = L["Leveling pace"], text = function()
				return L["A new page in the menu: your XP per hour, the time to your next level and to 60 at your pace, and every level you played as a bar."]
			end },
		},
	},
	{
		version = "0.4.0",
		notes = {
			{ glyph = "icon-learn", color = "accent", head = L["Talent points, one click"], text = function()
				return L["After a level-up a card names your plan's next talent: Apply talents spends the point without opening anything."]
			end },
		},
	},
	{
		version = "0.3.0",
		notes = {
			{ glyph = "plus", color = "accent", head = L["Import your own talent plan"], text = function()
				return L["Paste an Icy Veins talent calculator link under Talents > Import a plan: it becomes a plan you can follow and apply, in the order of its points."]
			end },
		},
	},
	{
		version = "0.2.0",
		notes = {
			{ glyph = "icon-learn", color = "accent", head = L["Talent plans from Icy Veins"], text = function()
				return L["Every spec's leveling build from Icy Veins' WoW Forever guides, one point a level from 10 to 60."]
			end },
			{ glyph = "check", color = "success", head = L["Today's talent trees"], text = function()
				return L["Talents Forever added or changed, like Shieldsworn or Boot Knife, are in the plans and the trees."]
			end },
		},
	},
	{
		version = "0.1.0",
		notes = {
			{ glyph = "guides", color = "accent", head = L["The first AzerothRoute release"], text = function()
				return L["A new engine: leveling 1 to 60 for every race, class quests, professions, reputations, dungeons and rares."]
			end },
			{ glyph = "icon-goto", color = "accent", head = L["Your route, walked for you"], text = function()
				return L["The arrow takes real roads, the journey lists every flight and boat, and the map draws the way."]
			end },
			{ glyph = "icon-learn", color = "accent", head = L["Talent plans"], text = function()
				return L["A plan for every spec, pick by pick, and Apply talents to spend your points in order."]
			end },
			{ glyph = "palette", color = "accent", head = L["A new look"], text = function()
				return L["The Azeroth colours and the route mark, with every theme still in Options."]
			end },
		},
	},
}]=],
        why = "what's new: AzerothRoute's own notes",
    },
    {
        file = "AzerothRoute_Options/UI/Options.lua",
        find = [=[	end
	}
	if ns.stage then
		paras[#paras + 1] = L["It is young and still in beta, so expect the odd wrong step, waypoint or quest. Every report and every fix tunes it, and together we'll get it where it should be."]
	end
]=],
        replace = [=[	end
]=],
        why = "drops the rest of Polestar's Why paragraphs",
    },
    -- Talents: icons and tooltips on the plan's picks (2026-11-20).
    {
        file = "AzerothRoute/UI/Thanks.lua",
        find = "function T.HeaderLink(f)\n",
        replace = "function T.HeaderLink(f)\n\tdo return end -- AzerothRoute: no special-thanks line (Polestar's supporters)\n",
        why = "no Special thanks to: in the hub and options headers",
    },
    -- Talents: the plan as talent trees, like a talent calculator (2026-11-20).
    {
        file = "AzerothRoute/Talents/Tree.lua", create = true, replace = read("Talents/Tree.lua"),
        why = "the plan drawn as the three talent trees",
    },
    {
        file = "AzerothRoute/Talents/Talents.xml",
        find = [=[	<Script file="View.lua"/>
]=],
        replace = [=[	<Script file="View.lua"/>
	<Script file="Tree.lua"/>
]=],
        why = "loads Tree.lua after View.lua",
    },
}
