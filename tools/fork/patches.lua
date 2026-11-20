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
        replace = '\t<Script file="Builds.lua"/>\n\t<Script file="Apply.lua"/>\n',
        why = "loads Apply.lua",
    },
    {
        file = "AzerothRoute/Talents/View.lua",
        find = [[	d.Auto.psTip = L["Pick the plan for the spec AzerothRoute's gear advice uses."]
]],
        replace = [[	d.Auto.psTip = L["Pick the plan for the spec AzerothRoute's gear advice uses."]
	-- AzerothRoute: Apply talents, on the followed plan while a point waits (Talents/Apply.lua).
	d.Apply = W.Button(d.Foot, L["Apply talents"], function() if T.Apply then T.Apply.Run() end end, { height = 28 })
	d.Apply:SetPoint("BOTTOMLEFT", d.Foot, "BOTTOMLEFT", FOOT_PAD, FOOT_PAD)
	d.Apply.psTip = L["Spend your unspent points on this plan's next picks, in order."]
	d.Apply:Hide()
]],
        why = "adds the Apply talents button to the plan page",
    },
    {
        file = "AzerothRoute/Talents/View.lua",
        find = [[	actions(not mine or choice == "auto", choice ~= "auto")
]],
        replace = [[	actions(not mine or choice == "auto", choice ~= "auto")
	local canApply = mine and c and c.staged and c.staged.status == "behind" and (c.staged.unspent or 0) > 0 or false
	detail.Apply:SetShown(canApply)
	if canApply then detail.Foot:Show() end
	shown.apply = canApply
]],
        why = "shows Apply talents only when a point waits on the followed plan",
    },
    -- Identity: "the route" (2026-11-20). Blue grounds like WoW Forever, Forever azure accent,
    -- gold for the route and names, jade for what is done; own art in tools/fork/assets.
    {
        file = "AzerothRoute/Theme/House.lua", find = "local DEFAULT_ACCENT = { 0.9, 0.73, 0.4 }",
        replace = "local DEFAULT_ACCENT = { 0.302, 0.706, 1 } -- AzerothRoute: Forever azure",
        why = "AzerothRoute's accent",
    },
    {
        file = "AzerothRoute/Theme/House.lua", find = "\tsuccess = { 0.42, 0.85, 0.6, 1 },",
        replace = "\tsuccess = { 0.361, 0.769, 0.604, 1 }, -- AzerothRoute: jade",
        why = "AzerothRoute's done colour",
    },
    {
        file = "AzerothRoute/Theme/House.lua", find = "\tquest = { 1, 0.84, 0.45, 1 },",
        replace = "\tquest = { 0.949, 0.757, 0.306, 1 }, -- AzerothRoute: route gold",
        why = "AzerothRoute's gold for quests and the route",
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
        replace = [[	-- AzerothRoute: the default scheme, "Azeroth": deep Forever blue grounds.
	dusk = {
		bg = { 0.039, 0.102, 0.2, 0.97 },
		panel = { 0.059, 0.141, 0.278, 0.98 },
		panelAlt = { 0.086, 0.2, 0.384, 1 },
		sidebar = { 0.031, 0.078, 0.157, 1 },
		footer = { 0.035, 0.09, 0.18, 1 },
		sky = { 0.102, 0.231, 0.439, 1 },
		text = { 0.918, 0.949, 1, 1 },
		textDim = { 0.761, 0.824, 0.918, 1 },
		textMuted = { 0.561, 0.651, 0.776, 1 },
		ink = { 1, 1, 1, 1 },
		star = { 0.561, 0.784, 1, 1 },
		shade = { 0, 0.01, 0.03, 1 },
		scrim = { 0.01, 0.04, 0.09, 1 },
		onAccent = { 0.02, 0.07, 0.15, 1 },
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
}
