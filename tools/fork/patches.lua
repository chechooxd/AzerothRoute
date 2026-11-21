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
        replace = '\t<Script file="Builds.lua"/>\n\t<Script file="Sources.lua"/>\n\t<Script file="IcyVeins.lua"/>\n\t<Script file="Import.lua"/>\n\t<Script file="Apply.lua"/>\n\t<Script file="Toast.lua"/>\n',
        why = "loads the Icy Veins plans (Sources.lua, generated IcyVeins.lua), imported plans, Apply.lua and the talent point card",
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
        replace = '\t<Script file="WhatsNew.lua"/>\n\t<Script file="Pace.lua"/>\n\t<Script file="Milestone.lua"/>\n',
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
			{ glyph = "hourglass", color = "accent", head = L["Race your best character"], text = function()
				return L["Leveling pace now compares every level with your fastest other character: a mark on the bar and how much faster or slower you were."]
			end },
			{ glyph = "icon-level", color = "accent", head = L["A card every 10 levels"], text = function()
				return L["At 20, 30, 40, 50 and 60: those ten levels' time, kills, quests and deaths, against your best character. At 60, your whole run."]
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
