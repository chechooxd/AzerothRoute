-- AzerothRoute: the World objects section of the Questing page (Quests tab), the settings of the glow on
-- quest objects, herbs and ore veins (QoL/ObjectGlow.lua). Part of the settings' addon.
-- Original AzerothRoute code (GPL-3.0-only).

local ns = AzerothRoute
local L = ns and ns.L
if not (ns and ns.RegisterOptions and L) then return end

local function off() return not ns.Get("qol.objectGlow") end
local function yards(v) return L["%d yd"]:format(math.floor((tonumber(v) or 0) + 0.5)) end

ns.RegisterOptions({
	page = L["Questing"], tab = L["Quests"], section = L["World objects"],
	controls = {
		{ kind = "toggle", key = "qol.objectGlow", label = L["Make world objects glow"],
			search = "glow, highlight, sparkle, objects, interact, wood, crates, herbs, ore, soft target",
			help = L["When you face an object a quest still needs, or a herb or ore vein, near you, it glows with an icon and its name. The game only tells addons about the nearest object in front of you, so that one glows. AzerothRoute turns on the game's interact targeting for objects while this is on and puts your own settings back when you turn it off."] },
		{ kind = "toggle", key = "qol.objectGlowQuest", label = L["Quest objects"], disabled = off, child = true,
			search = "quest items, objectives, collect, click, use",
			help = L["Objects an open quest still needs glow gold, with the quest and your progress under them."] },
		{ kind = "toggle", key = "qol.objectGlowGather", label = L["Herbs and ore"], disabled = off, child = true,
			search = "herbalism, mining, gathering, nodes, veins",
			help = L["Herbs glow green and ore veins copper."] },
		{ kind = "slider", key = "qol.objectGlowRange", label = L["Detection range"], disabled = off, child = true,
			min = 5, max = 30, step = 1, format = yards, release = true,
			search = "distance, range, yards, how far",
			help = L["How far away an object can be for the game to pick it."] },
	},
})
