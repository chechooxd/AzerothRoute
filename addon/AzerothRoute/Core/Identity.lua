-- AzerothRoute: the words of AzerothRoute's own identity ("the route") in the client's language.
-- The theme (Theme/House.lua, patched: WoW Forever night blue grounds, gold accent, Forever blue route) and the art
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
	["A new page in the menu: your XP per hour, the time to your next level and to 60 at your pace, and every level you played as a bar."] =
		"Una página nueva en el menú: tu XP por hora, el tiempo para tu siguiente nivel y para el 60 a tu ritmo, y cada nivel que jugaste como una barra.",
	["Rounded windows and buttons, a flat header, blue buttons and switches, and Continue guide at the foot of the menu, in the style of the Battle.net app."] =
		"Ventanas y botones redondeados, una cabecera plana, botones e interruptores azules, y Continuar guía al pie del menú, al estilo de la app de Battle.net.",
	["A new page in the menu: a loop of herb or ore spots for your Herbalism or Mining in the best zones, and the arrow takes you round it."] =
		"Una página nueva en el menú: un circuito de puntos de hierbas o vetas para tu Herboristería o Minería en las mejores zonas, y la flecha te lleva por él.",
	["Self-found, respected"] = "Autosuficiente, respetado",
	["Self-found characters no longer get auction house buys."] = "Los personajes autosuficientes ya no reciben compras de la casa de subastas.",
	["A card every 10 levels"] = "Una tarjeta cada 10 niveles",
	["At 20, 30, 40, 50 and 60: those ten levels' time, kills, quests and deaths, against your best character. At 60, your whole run."] =
		"En el 20, 30, 40, 50 y 60: el tiempo, enemigos, misiones y muertes de esos diez niveles, contra tu mejor personaje. En el 60, toda tu subida.",
	["Race your best character"] = "Compite con tu mejor personaje",
	["Leveling pace now compares every level with your fastest other character: a mark on the bar and how much faster or slower you were."] =
		"Ritmo de subida ahora compara cada nivel con tu otro personaje más rápido: una marca en la barra y cuánto más rápido o lento fuiste.",
	["Options window fix"] = "Arreglo de la ventana de Opciones",
	["Resizing the Options window no longer shows an error."] = "Cambiar el tamaño de la ventana de Opciones ya no muestra un error.",
	["WoW Forever's blue and gold"] = "El azul y dorado de WoW Forever",
	["The Azeroth colours now match WoW Forever: night blue grounds, gold, and Forever blue for quests and the route."] =
		"Los colores Azeroth ahora son los de WoW Forever: fondos azul noche, dorado y el azul de Forever para misiones y la ruta.",
	["Talent points, one click"] = "Puntos de talento, en un clic",
	["After a level-up a card names your plan's next talent: Apply talents spends the point without opening anything."] =
		"Al subir de nivel, una tarjeta muestra el siguiente talento de tu plan: Aplicar talentos gasta el punto sin abrir nada.",
	["Import your own talent plan"] = "Importa tu propio plan de talentos",
	["Paste an Icy Veins talent calculator link under Talents > Import a plan: it becomes a plan you can follow and apply, in the order of its points."] =
		"Pega un enlace del calculador de talentos de Icy Veins en Talentos > Importar un plan: se vuelve un plan que puedes seguir y aplicar, en el orden de sus puntos.",
	["Talent plans from Icy Veins"] = "Planes de talentos de Icy Veins",
	["Every spec's leveling build from Icy Veins' WoW Forever guides, one point a level from 10 to 60."] =
		"La build de subida de cada especialización de las guías de WoW Forever de Icy Veins, un punto por nivel del 10 al 60.",
	["Today's talent trees"] = "Los árboles de talentos actuales",
	["Talents Forever added or changed, like Shieldsworn or Boot Knife, are in the plans and the trees."] =
		"Los talentos que Forever agregó o cambió, como Shieldsworn o Boot Knife, están en los planes y en los árboles.",
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
	-- Flight games (Games/Host.lua, Maps/Arcade.lua).
	["Play a game"] = "Jugar un juego",
	["Flight games"] = "Juegos en vuelo",
	["Offer a game on long flights"] = "Ofrecer un juego en vuelos largos",
	["On a flight with a minute or more to go, AzerothRoute asks if you want to play one of its light games while you wait: Rune Fall or Sky Patrol. 10 seconds before you land, or in a fight, the game is paused and closed, and it goes on where it was. /ar arcade opens them any time."] =
		"En un vuelo de un minuto o más, AzerothRoute te pregunta si quieres jugar uno de sus juegos ligeros mientras esperas: Rune Fall o Sky Patrol. 10 segundos antes de aterrizar, o en un combate, el juego se pausa y se cierra, y sigue donde quedó. /ar arcade los abre cuando quieras.",
	["Long flight ahead. Play while you wait?"] = "Vuelo largo por delante. ¿Juegas mientras esperas?",
	["Light games of AzerothRoute's own. Esc closes them, and they wait for you."] =
		"Juegos ligeros propios de AzerothRoute. Esc los cierra y te esperan donde quedaron.",
	["Your game is paused for the fight: type %s to go on."] = "Tu juego quedó en pausa por el combate: escribe %s para seguir.",
	["Your game is paused."] = "Tu juego quedó en pausa.",
	["Landed. Your game is paused: type %s to go on."] = "Aterrizaste. Tu juego quedó en pausa: escribe %s para seguir.",
	["The games open after the fight."] = "Los juegos se abren después del combate.",
	["Score %d   Best %d"] = "Puntos %d   Récord %d",
	["Score %d"] = "Puntos %d",
	["P: pause   Esc: close"] = "P: pausa   Esc: cerrar",
	["Space to start"] = "Espacio para empezar",
	["Paused"] = "En pausa",
	["Space or P to go on"] = "Espacio o P para seguir",
	["Game over"] = "Fin del juego",
	["New best: %d"] = "¡Nuevo récord: %d!",
	["Space to play again"] = "Espacio para jugar otra vez",
	["Rune Fall"] = "Rune Fall",
	["Fit the falling runestones into full rows to dissolve them."] = "Encaja las runas que caen en filas completas para disolverlas.",
	["Arrows or WASD: move, turn (up), drop (down)   Space: slam"] = "Flechas o WASD: mover, girar (arriba), bajar (abajo)   Espacio: soltar",
	["Level %d"] = "Nivel %d",
	["Sky Patrol"] = "Sky Patrol",
	["Hold off the bats and harpies from your gryphon."] = "Detén a los murciélagos y arpías desde tu grifo.",
	["Arrows or A/D: fly   Space: throw"] = "Flechas o A/D: volar   Espacio: lanzar",
	["Wave %d"] = "Oleada %d",
	["Sound on"] = "Sonido activado",
	["Sound off"] = "Sonido desactivado",
}

local loc = GetLocale and GetLocale()
if loc == "esMX" or loc == "esES" then
	for k, v in pairs(ES) do L[k] = v end
end
