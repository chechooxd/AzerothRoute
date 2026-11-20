-- AzerothRoute: the words of AzerothRoute's own identity ("the route") in the client's language.
-- The theme (Theme/House.lua, patched: blue grounds, Forever azure accent, gold route) and the art
-- (Media/UI: emblem, logo, wordmark, watermark, band) come from tools/fork. Original AzerothRoute
-- code (GPL-3.0-only).

local ADDON, ns = ...
local L = ns.L
if not L then return end

local ES = {
	["Your route through Azeroth"] = "Tu camino por Azeroth",
	["Azeroth"] = "Azeroth",
	["AzerothRoute plans your route step by step: who to talk to, what to kill or collect, and where to go next."] =
		"AzerothRoute traza tu ruta paso a paso: con quién hablar, qué matar o conseguir y a dónde ir después.",
	["Based on Polestar by The Polestar authors"] = "Basado en Polestar, de los autores de Polestar",
}

local loc = GetLocale and GetLocale()
if loc == "esMX" or loc == "esES" then
	for k, v in pairs(ES) do L[k] = v end
end
