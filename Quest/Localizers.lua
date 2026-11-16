-- AzerothRoute: Dynamic Tooltip & Locale Cache (SPEC-04 / SPEC-21)
-- Resolves Quest, NPC, Mob, and Item names in the active client locale (live WoW APIs + Spanish fallback dictionary).

local AR = _G.AzerothRoute
local Localizers = {
    npcCache = {},
    questCache = {}, -- { [questID] = { title = ..., timestamp = ... } }
    TTL_SECONDS = 1800,
    questsES = {
        -- Horde Starter & Kalimdor / EK Leveling
        [354] = "Muertes en la familia",
        [356] = "Patrulla de la retaguardia",
        [357] = "La identidad del exánime",
        [358] = "Profanadores de tumbas",
        [359] = "El deber de los Renegados",
        [360] = "El regreso del magistrado",
        [361] = "Una carta sin entregar",
        [362] = "Los molinos fantasma",
        [363] = "Despertar abrupto",
        [364] = "Los descerebrados",
        [365] = "Campos de Pena",
        [366] = "El regreso del libro",
        [367] = "Una nueva peste",
        [368] = "Una nueva peste",
        [369] = "Una nueva peste",
        [370] = "En guerra con la Cruzada Escarlata",
        [371] = "En guerra con la Cruzada Escarlata",
        [372] = "En guerra con la Cruzada Escarlata",
        [374] = "Pruebas de defunción",
        [375] = "El frío de la muerte",
        [376] = "Los malditos",
        [380] = "Haciendo ruido en Agamand",
        [381] = "La Cruzada Escarlata",
        [382] = "El mensajero rojo",
        [383] = "Información vital",
        [398] = "SE BUSCA: Ojo de Gusano",
        [404] = "Una tarea putrefacta",
        [407] = "Campos de Pena",
        [408] = "La cripta de la familia",
        [409] = "Lealtad a la Reina alma en pena",
        [410] = "La sombra latente",
        [421] = "Demuestra tu valía",
        [422] = "La locura de Arugal",
        [425] = "Ivar el Hediondo",
        [426] = "Los molinos invadidos",
        [427] = "En guerra con la Cruzada Escarlata",
        [435] = "El rescate de Erland",
        [445] = "Entrega en Bosque de Argénteos",
        [447] = "Una receta mortífera",
        [464] = "Estandartes de guerra",
        [478] = "Mapas y runas",
        [6395] = "El último deseo de Marla",
        [3901] = "Sacudir las cajas de huesos",
        [3902] = "Hurgar en Camposanto",
        [747] = "Comienza la caza",
        [748] = "Agua envenenada",
        [749] = "La caravana devastada",
        [750] = "La caza continúa",
        [752] = "Una humilde tarea",
        [753] = "Una humilde tarea",
        [755] = "Ritos de la Madre Tierra",
        [757] = "Rito de la Fuerza",
        [761] = "La caza de los aguilones",
        [763] = "Ritos de la Madre Tierra",
        [766] = "Mazzranache",
        [767] = "Rito de la Visión",
        [770] = "La capa del demonio marcado",
        [771] = "Rito de la Visión",
        [772] = "Rito de la Visión",
        [775] = "Viaje a Cima del Trueno",
        [776] = "Ritos de la Madre Tierra",
        [784] = "Vencer a los traidores",
        [786] = "Frustrar el ataque de los Kolkar",
        [788] = "Dientes afilados",
        [789] = "El aguijón del escórpido",
        [790] = "Sarkoth",
        [791] = "Lleva tu carga",
        [792] = "Familiares viles",
        [794] = "Medallón del Filo Ardiente",
        [804] = "Sarkoth",
        [805] = "Informa en el Poblado Sen'jin",
        [806] = "Tormentas oscuras",
        [808] = "La miniatura de Minshina",
        [815] = "Romper unos cuantos huevos",
        [817] = "Presa práctica",
        [818] = "Un espíritu doméstico",
        [823] = "Informa a Orgnil",
        [825] = "De los restos",
        [826] = "Zalazane",
        [830] = "Órdenes del almirante",
        [831] = "La insignia del almirante",
        [837] = "Intrusión",
        [844] = "La amenaza de los zancudos",
        [845] = "Las zhevras",
        [848] = "Esporas fungales",
        [850] = "Líderes Kolkar",
        [851] = "Verog el Derviche",
        [852] = "Hezrul Marca de Sangre",
        [854] = "Viaje a El Cruce",
        [855] = "Brazales de centauro",
        [869] = "Ladrones raptores",
        [870] = "Las Pozas del Olvido",
        [871] = "Interrumpe los ataques",
        [872] = "El fin de la interrupción",
        [875] = "Tenientes arpías",
        [876] = "Serena Plumasangre",
        [877] = "El Oasis Estancado",
        [880] = "Seres alterados",
        [881] = "Echeyakee",
        [895] = "SE BUSCA: Barón Longavilla",
        [903] = "Merodeadores de Los Baldíos",
        [905] = "Los furiosos garrafilada",
        [959] = "Problemas en los muelles",
        [1062] = "Invasores goblins",
        [1130] = "Melor envía noticias",
        [1131] = "Muerdehierro",
        [1195] = "La llama sagrada",
        [1362] = "Los Kolkar de Desolace",
        [1431] = "Relaciones con la Alianza",
        [1705] = "Sangre ardiente",
        [2841] = "La guerra de los carros",
        [2922] = "Salva el cerebro de Techbot",
        [3091] = "Nota simple",
        [4641] = "Tu lugar en el mundo",
        [4921] = "Perdidos en batalla",
        [5041] = "Suministros para El Cruce",
        [6361] = "Un fardo de pieles",
        [6362] = "Viaje a Cima del Trueno",
        -- Alliance Starter & Leveling
        [6]   = "Recompensa por Garrick Padfoot",
        [7]   = "Limpieza en el campamento kóbold",
        [11]  = "Recompensas por los gnolls Zarparrío",
        [12]  = "La Milicia Popular",
        [13]  = "La Milicia Popular",
        [15]  = "Investigar la cresta",
        [18]  = "Hermandad de los Defias",
        [21]  = "Escaramuza en Abisal",
        [22]  = "Pastel de hígado de jabalí sangriento",
        [33]  = "Los lobos cruzan la frontera",
        [35]  = "Más preocupaciones",
        [36]  = "Estofado de Páramos de Poniente",
        [37]  = "Encuentra a los guardias perdidos",
        [38]  = "Estofado de Páramos de Poniente",
        [39]  = "Entrega el informe de Thomas",
        [40]  = "Un peligro con aletas",
        [45]  = "Descubre el destino de Rolf",
        [46]  = "Recompensas por los múrlocs",
        [47]  = "Intercambio de polvo de oro",
        [52]  = "Proteger la frontera",
        [54]  = "Informa en Villadorada",
        [55]  = "Morbentos Vil",
        [59]  = "Armadura de tela y cuero",
        [60]  = "Las velas de los kóbolds",
        [61]  = "Envío a Ventormenta",
        [62]  = "La Mina Abisal",
        [64]  = "La reliquia olvidada",
        [65]  = "La Hermandad Defias",
        [71]  = "Informa a Thomas",
        [76]  = "La Cantera de Jaspe",
        [83]  = "Pañuelos de lino rojo",
        [84]  = "Vuelve con Billy",
        [85]  = "El collar perdido",
        [86]  = "Empanada para Billy",
        [87]  = "Dientes de Oro",
        [88]  = "¡Princesa debe morir!",
        [102] = "Patrullando Páramos de Poniente",
        [106] = "Jóvenes enamorados",
        [109] = "Informa a Gryan Mantorrecio",
        [111] = "Habla con la Abuela",
        [112] = "La recolección de algas",
        [151] = "Pobre Viejo Blanchy",
        [152] = "La costa no es segura",
        [153] = "Pañuelos de cuero rojo",
        [176] = "SE BUSCA: Hogger",
        [179] = "Equípate como enano",
        [182] = "La amenaza trol",
        [183] = "El cazador de jabalíes",
        [218] = "El diario robado",
        [233] = "Entrega de correo de Crestanevada",
        [234] = "Entrega de correo de Crestanevada",
        [239] = "El Cuartel de Arroyoeste necesita ayuda",
        [282] = "Observaciones de Senir",
        [287] = "Poblado Peloescarcha",
        [291] = "Los informes",
        [312] = "La reserva de Tundra MacGrann",
        [313] = "El Cubil Griego",
        [314] = "Proteger el ganado",
        [317] = "Suministros para el Tanque a vapor",
        [318] = "Evershine",
        [319] = "Un favor a Evershine",
        [320] = "Regresa junto a Bellowfiz",
        [384] = "Costillas de jabalí a la cerveza",
        [412] = "Operación Recombobulación",
        [416] = "Caza ratas",
        [417] = "La venganza del piloto",
        [418] = "Morcilla de Thelsamar",
        [419] = "El piloto perdido",
        [420] = "Observaciones de Senir",
        [456] = "El equilibrio de la naturaleza",
        [457] = "El equilibrio de la naturaleza",
        [458] = "La protectora del bosque",
        [459] = "La protectora del bosque",
        [487] = "El camino a Darnassus",
        [488] = "El encargo de Zenn",
        [489] = "Buscar la redención",
        [783] = "Una amenaza en el interior",
        [916] = "Veneno de tejemadera",
        [917] = "Huevo de tejemadera",
        [920] = "Invocación de Tenaron",
        [921] = "Corona de la Tierra",
        [928] = "Corona de la Tierra",
        [932] = "Odio retorcido",
        [933] = "Corona de la Tierra",
        [935] = "Corona de la Tierra",
        [997] = "Las tierras de Denalan",
        [1638] = "Entrenamiento de guerrero",
        -- Dungeons
        [1013] = "El Libro de Ur",
        [1014] = "Arugal debe morir",
        [1486] = "Pellejo descarriado",
        [1487] = "Erradicación de descarriados",
        [166]  = "La Hermandad Defias",
        [1048] = "Hacia el Monasterio Escarlata",
        [2781] = "SE BUSCA: Kalifaz",
        [2936] = "El dios araña",
        [4494] = "Marcha en Silithus",
        [5242] = "Un golpe final",
    },
    npcsES = {
        [1568] = "Enterrador Mordo",
        [1569] = "Sacerdote oscuro Sarvis",
        [1570] = "Ejecutor Arren",
        [1501] = "Zombi descerebrado",
        [1502] = "Necrófago desdichado",
        [1504] = "Araña Telanoche joven",
        [1505] = "Araña Telanoche",
        [1508] = "Carroñero joven",
        [1512] = "Murciélago del ocaso",
        [1519] = "Sombra de Agamand",
        [1520] = "Depravado de Rémol",
        [1535] = "Guerrero Escarlata",
        [1536] = "Iniciado Escarlata",
        [1661] = "Novicia Elreth",
        [1740] = "Guardia de la muerte Saltain",
        [1890] = "Esqueleto Matraca",
        [1496] = "Magistrado Sevren",
        [1497] = "Guardia de la muerte Linnea",
        [1499] = "Botikario Johaan",
        [1515] = "Colgante Escarlata",
        [1652] = "Capitán Perrine",
        [2116] = "Herrero Rand",
        [2118] = "Abigail Shiel",
        [2122] = "David Trias",
        [2123] = "Clérigo oscuro Duesten",
        [2124] = "Isabella",
        [2126] = "Maximillion",
        [2128] = "Cain Pirosong",
        [2130] = "Marion Call",
        [2215] = "Gran Ejecutor Darthalia",
        [2389] = "Michael Garrett",
        [5675] = "Hermano Malach",
        [3394] = "Barak Kodobane",
        [3449] = "Darsok Daga Veloz",
        [3446] = "Tonga Runatótem",
        [3442] = "Kadrak",
        [3448] = "Sergra Espina Oscura",
        [3453] = "Piloto de muelle Gazlowe",
        [3389] = "Regthar Puerta de la Muerte",
        [3297] = "Gornek",
        [3143] = "Sarkoth",
        [3098] = "Jabalí moteado",
        [3101] = "Escórpido trabajador",
        [3103] = "Familiar vil",
        [3145] = "Canalla de las Tierras Altas",
        [3188] = "Hana'zua",
        [3204] = "Zalazane",
        [2955] = "Zancudo de llanura",
        [2956] = "Zancudo de llanura adulto",
        [2960] = "Puma de las praderas",
        [2975] = "Camina-sueños",
        [2980] = "Grull Hawkwind",
        [2981] = "Jefe Hawkwind",
        [2983] = "Vidente Wiserunner",
        [2985] = "Baine Pezuña de Sangre",
        [197]  = "Alguacil McBride",
        [196]  = "Alguacil adjunto Willem",
        [240]  = "Alguacil Dughan",
        [233]  = "Granjero Saldean",
        [234]  = "Alguacil Gryan Mantorrecio",
        [235]  = "Capitana Danuvin",
        [237]  = "Salma Saldean",
        [241]  = "Tío Furlbrow",
        [261]  = "Guardián Thomas",
        [263]  = "Billy Maclure",
        [264]  = "William Pestle",
        [295]  = "Tabernero Farley",
        [448]  = "Hogger",
        [6]    = "Kóbold alimaña",
        [40]   = "Kóbold obrero",
        [80]   = "Kóbold geomántico",
        [113]  = "Lobo de madera",
        [118]  = "Prowler",
        [123]  = "Bandido Defias",
        [299]  = "Lobo joven",
        [658]  = "Balir Frosthammer",
        [705]  = "Lobo joven desharrapado",
        [706]  = "Lobo lobuno",
        [708]  = "Jabalí Peñasco",
        [711]  = "Trol Peloescarcha",
        [713]  = "Trogg Cavaroca",
        [786]  = "Sten Brazofuerte",
        [1105] = "Talin Keeneye",
        [1265] = "Grelin Barba Blanca",
        [1378] = "Senir Barba Blanca",
        [1275] = "Rejold Cebadiz",
        [2031] = "Sable de la noche joven",
        [2032] = "Sable de la noche mangosta",
        [2042] = "Arácnido tejemadera",
        [2077] = "Conservadora Ilithaine",
        [2078] = "Melithar Staghelm",
        [2080] = "Corina Steele",
        [2150] = "Zenn Pezuña Fétida",
        [2151] = "Syral Filohoja",
        [3514] = "Tenaron Tormenta",
        [4275] = "Archimago Arugal",
        [11520] = "Taragaman el Hambriento",
        [3654] = "Mutanus el Devorador",
        [639]  = "Edwin VanCleef",
        [3975] = "Comandante Mograine",
        [4421] = "Charlga Filonavaja",
        [7267] = "Jefe Ukorz Cabellarena",
        [1853] = "Maestro oscuro Gandling",
    },
    itemsES = {
        [2447] = "Flor de paz",
        [765]  = "Hojaplata",
        [2450] = "Brezospina",
        [2770] = "Mena de cobre",
        [2771] = "Mena de estaño",
        [2772] = "Mena de hierro",
        [3371] = "Vial vacío",
        [2589] = "Paño de lino",
        [2592] = "Paño de lana",
        [4306] = "Paño de seda",
        [2318] = "Cuero ligero",
        [2672] = "Carne fibrosa de lobo",
        [2835] = "Piedra burda",
        [2862] = "Piedra de afilar burda",
        [2996] = "Madeja de paño de lino",
        [2304] = "Refuerzo para armadura ligero",
        [1251] = "Venda de lino",
        [3264] = "Ala de murciélago del ocaso",
        [3265] = "Garra de carroñero",
        [4862] = "Pata de escórpido",
        [5010] = "Brazales de centauro",
        [5058] = "Calavera de Rattlecage",
        [11127] = "Mercancía carroñada",
        [6283] = "El Libro de Ur",
        [10940] = "Polvo extraño",
        [6522] = "Pez descarriado",
        [7068] = "Fuego elemental",
        [8846] = "Sangregroms",
        [10620] = "Mena de torio",
        [769]  = "Trozo de carne de jabalí",
        [772]  = "Vela grande",
        [773]  = "Polvo de oro",
        [1397] = "Pañuelo de lino rojo",
        [1529] = "Pañuelo de cuero rojo",
        [2855] = "Brazalete de Garrick",
        [2886] = "Costilla de jabalí Peñasco",
        [3261] = "Veneno de tejemadera",
        [5168] = "Pluma de arpía",
    },
}
AR.Localizers = Localizers

function Localizers:Reset()
    self.npcCache = {}
    self.questCache = {}
end

function Localizers:GetTranslatedNPC(npcID, fallbackName)
    npcID = tonumber(npcID)
    if not npcID then return fallbackName end
    if self.npcCache[npcID] then
        return self.npcCache[npcID]
    end
    local mockTooltip = _G.MockWoW and _G.MockWoW.tooltips and _G.MockWoW.tooltips.npcs and _G.MockWoW.tooltips.npcs[npcID]
    if mockTooltip then
        self.npcCache[npcID] = mockTooltip
        AR.Events:SendMessage("AR_NPC_TRANSLATED", npcID, mockTooltip)
        return mockTooltip
    end
    if _G.C_TooltipInfo and _G.C_TooltipInfo.GetHyperlink then
        local data = _G.C_TooltipInfo.GetHyperlink(("unit:Creature-0-0-0-0-%d-0"):format(npcID))
        local name = data and data.lines and data.lines[1] and data.lines[1].leftText
        if not (_G.issecretvalue and _G.issecretvalue(name)) and type(name) == "string" and name ~= "" then
            self.npcCache[npcID] = name
            return name
        end
    end
    if AR.L and AR.L:IsSpanish() and self.npcsES[npcID] then
        return self.npcsES[npcID]
    end
    return fallbackName
end

function Localizers:GetTranslatedQuest(questID, fallbackTitle)
    questID = tonumber(questID)
    if not questID then return fallbackTitle end
    if AR.QuestTracking and AR.QuestTracking.questsById and AR.QuestTracking.questsById[questID] then
        local title = AR.QuestTracking.questsById[questID].title
        if title and title ~= "" then
            return title
        end
    end
    if _G.C_QuestLog then
        local t = (_G.C_QuestLog.GetTitleForQuestID and _G.C_QuestLog.GetTitleForQuestID(questID))
            or (_G.C_QuestLog.GetQuestInfo and _G.C_QuestLog.GetQuestInfo(questID))
        if t and t ~= "" then
            return t
        end
    end
    if AR.L and AR.L:IsSpanish() and self.questsES[questID] then
        return self.questsES[questID]
    end
    local qData = self:GetQuestData(questID)
    if qData and qData.title then
        return qData.title
    end
    return fallbackTitle
end

function Localizers:GetTranslatedItem(itemID, fallbackName)
    itemID = tonumber(itemID)
    if not itemID then return fallbackName end
    if _G.GetItemInfo then
        local name = _G.GetItemInfo(itemID)
        if name and name ~= "" then
            return name
        end
    end
    if AR.L and AR.L:IsSpanish() and self.itemsES[itemID] then
        return self.itemsES[itemID]
    end
    return fallbackName
end

function Localizers:GetQuestData(questID)
    questID = tonumber(questID)
    if not questID then return nil end
    local now = (_G.GetTime and _G.GetTime()) or 0
    local cached = self.questCache[questID]
    if cached and (now - cached.timestamp) <= self.TTL_SECONDS then
        return cached
    end
    local mockQuest = _G.MockWoW and _G.MockWoW.tooltips and _G.MockWoW.tooltips.quests and _G.MockWoW.tooltips.quests[questID]
    if mockQuest then
        local entry = { title = mockQuest.title, timestamp = now }
        self.questCache[questID] = entry
        return entry
    end
    return nil
end

function Localizers:PruneExpiredQuests()
    local now = (_G.GetTime and _G.GetTime()) or 0
    for qid, entry in pairs(self.questCache) do
        local inLog = AR.QuestTracking and AR.QuestTracking:IsInLog(qid)
        if not inLog and (now - entry.timestamp) > self.TTL_SECONDS then
            self.questCache[qid] = nil
        end
    end
end

return Localizers
