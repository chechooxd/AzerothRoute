-- AzerothRoute: Dynamic Tooltip & Locale Cache (SPEC-04 / SPEC-21)
-- Resolves Quest, NPC, Mob, and Item names in the active client locale (live WoW APIs + Spanish fallback dictionary).

local AR = _G.AzerothRoute
local Localizers = {
    npcCache = {},
    questCache = {}, -- { [questID] = { title = ..., timestamp = ... } }
    TTL_SECONDS = 1800,
    questsES = {
        -- Horde Starter & Kalimdor / EK Leveling
        [363] = "Despertar abrupto",
        [364] = "Los descerebrados",
        [365] = "Campos de Pena",
        [367] = "Una nueva peste",
        [374] = "Pruebas de defunción",
        [380] = "Haciendo ruido en Agamand",
        [381] = "La cruzada escarlata",
        [382] = "El mensajero rojo",
        [404] = "Una tarea putrefacta",
        [427] = "En guerra con la Cruzada Escarlata",
        [421] = "Demuestra tu valía",
        [435] = "El rescate de Erland",
        [445] = "Entrega en Bosque de Argénteos",
        [447] = "Una receta mortífera",
        [464] = "Estandartes de guerra",
        [478] = "Mapas y runas",
        [788] = "Dientes afilados",
        [789] = "El aguijón del escórpido",
        [790] = "Sarkoth",
        [791] = "Lleva tu carga",
        [792] = "Familiares viles",
        [808] = "La miniatura de Minshina",
        [818] = "Un espíritu doméstico",
        [823] = "Informa a Orgnil",
        [825] = "De los restos",
        [844] = "La amenaza de los zancudos",
        [845] = "Las zhevras",
        [850] = "Líderes Kolkar",
        [851] = "Verog el Derviche",
        [855] = "Brazales de centauro",
        [869] = "Ladrones raptores",
        [870] = "Las Pozas del Olvido",
        [871] = "Interrumpe los ataques",
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
        -- Alliance Leveling
        [7]   = "Limpieza en el campamento kóbold",
        [11]  = "Recompensas por los gnolls Zarparrío",
        [18]  = "Hermandad de los Defias",
        [21]  = "Escaramuza en Abisal",
        [33]  = "Los lobos cruzan la frontera",
        [37]  = "Encuentra a los guardias perdidos",
        [45]  = "Descubre el destino de Rolf",
        [47]  = "Intercambio de polvo de oro",
        [52]  = "Proteger la frontera",
        [54]  = "Informa en Villadorada",
        [60]  = "Las velas de los kóbolds",
        [62]  = "La Mina Abisal",
        [71]  = "Informa a Thomas",
        [76]  = "La Cantera de Jaspe",
        [83]  = "Pañuelos de lino rojo",
        [84]  = "Vuelve con Billy",
        [87]  = "Dientes de Oro",
        [88]  = "¡Princesa debe morir!",
        [106] = "Jóvenes enamorados",
        [112] = "La recolección de algas",
        [176] = "SE BUSCA: Hogger",
        [179] = "Equípate como enano",
        [182] = "La amenaza trol",
        [218] = "El diario robado",
        [239] = "El Cuartel de Arroyoeste necesita ayuda",
        [282] = "Observaciones de Senir",
        [416] = "Caza ratas",
        [456] = "El equilibrio de la naturaleza",
        [457] = "El equilibrio de la naturaleza",
        [783] = "Una amenaza en el interior",
        [916] = "Veneno de tejemadera",
        [920] = "Invocación de Tenaron",
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
        [1569] = "Ejecutor Arren",
        [1501] = "Zombi descerebrado",
        [1502] = "Necrófago desdichado",
        [1512] = "Murciélago del ocaso",
        [2118] = "Abigail Shiel",
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
        [197]  = "Alguacil McBride",
        [240]  = "Alguacil Dughan",
        [233]  = "Granjero Saldean",
        [234]  = "Alguacil Gryan Mantorrecio",
        [448]  = "Hogger",
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
        [5010] = "Brazales de centauro",
        [6283] = "El Libro de Ur",
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
        if data and data.lines and data.lines[1] and data.lines[1].leftText and data.lines[1].leftText ~= "" then
            self.npcCache[npcID] = data.lines[1].leftText
            return data.lines[1].leftText
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
