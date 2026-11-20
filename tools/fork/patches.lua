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
}
