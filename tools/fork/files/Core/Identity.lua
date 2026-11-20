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
	["Send it to the developer"] = "Envíalo al desarrollador",
	["1. Press Copy report, then Ctrl+C (Cmd+C on a Mac).\n2. Paste it where you talk with the AzerothRoute developer, with a short line about what went wrong."] =
		"1. Pulsa Copiar informe y luego Ctrl+C (Cmd+C en Mac).\n2. Pégalo donde hablas con el desarrollador de AzerothRoute, con una línea sobre qué salió mal.",
	["Write what went wrong and copy the report for the AzerothRoute developer."] = "Escribe qué salió mal y copia el informe para el desarrollador de AzerothRoute.",
	["report a problem with a step"] = "informar un problema con un paso",
	["This translation was made with AI."] = "Esta traducción se hizo con IA.",
	["Played to the end in tests, but not yet by players. If a step is wrong, press %s in the guide window and send a report with /ar report."] =
		"Se recorrió hasta el final en pruebas, pero todavía no la han probado jugadores. Si un paso está mal, pulsa %s en la ventana de la guía y envía un informe con /ar report.",
}

local loc = GetLocale and GetLocale()
if loc == "esMX" or loc == "esES" then
	for k, v in pairs(ES) do L[k] = v end
end
