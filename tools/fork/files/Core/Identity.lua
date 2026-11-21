-- AzerothRoute: the words of AzerothRoute's own identity ("the route") in the client's language.
-- The theme (Theme/House.lua, patched: deep sapphire grounds, pearl white text, ember orange accent) and the art
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
	["Talent trees"] = "Árboles de talentos",
	["The plan puts %d of %d ranks here"] = "El plan pone %d de %d rangos aquí",
	["First point: pick %d"] = "Primer punto: punto %d del plan",
	["Not in this plan"] = "No está en este plan",
	["Learned: %d of %d"] = "Aprendido: %d de %d",
	["Pick %d of the plan, rank %d of %d"] = "Punto %d del plan, rango %d de %d",
	["(trimmed)"] = "(recortado)",
	["AzerothRoute plans your road through Azeroth: every quest, every flight and every step, in order, so you play instead of planning."] =
		"AzerothRoute traza tu camino por Azeroth: cada misión, cada vuelo y cada paso, en orden, para que juegues en vez de planificar.",
	["It is free and open source under the GPL-3.0."] = "Es gratis y de código abierto bajo la GPL-3.0.",
	["It is young, so expect the odd wrong step or waypoint. Send a report with /ar report and it gets fixed."] =
		"Es joven: puede haber algún paso o punto equivocado. Envía un informe con /ar report y se corrige.",
	["The first AzerothRoute release"] = "La primera versión de AzerothRoute",
	["A new engine: leveling 1 to 60 for every race, class quests, professions, reputations, dungeons and rares."] =
		"Un motor nuevo: subida del 1 al 60 para cada raza, misiones de clase, profesiones, reputaciones, calabozos y raros.",
	["Your route, walked for you"] = "Tu ruta, trazada para ti",
	["The arrow takes real roads, the journey lists every flight and boat, and the map draws the way."] =
		"La flecha va por caminos reales, el trayecto lista cada vuelo y barco, y el mapa dibuja el camino.",
	["Talent plans"] = "Planes de talentos",
	["A plan for every spec, pick by pick, and Apply talents to spend your points in order."] =
		"Un plan para cada especialización, punto por punto, y Aplicar talentos para gastarlos en orden.",
	["A new look"] = "Un aspecto nuevo",
	["The Azeroth colours and the route mark, with every theme still in Options."] =
		"Los colores Azeroth y la marca de la ruta, con todos los temas aún en Opciones.",
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
