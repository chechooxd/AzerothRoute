-- AzerothRoute: Client Locale & Translation Engine (SPEC-21)
-- Automatically adapts UI labels and guide step text to the active WoW client language (esMX/esES vs enUS).

local AR = _G.AzerothRoute
local L = {}
AR.L = L

L.STRINGS = {
    en = {
        -- Goal Verbs & Actions
        GOAL_ACCEPT = "Accept %s",
        GOAL_TURNIN = "Turn in %s",
        GOAL_KILL = "Kill %s%s",
        GOAL_KILL_PLURAL = "Kill %d %s%s",
        GOAL_COLLECT = "Collect %s%s",
        GOAL_COLLECT_PLURAL = "Collect %d %s%s",
        GOAL_BUY = "Buy %s%s",
        GOAL_BUY_PLURAL = "Buy %d %s%s",
        GOAL_TALK = "Talk to %s",
        GOAL_DING = "Reach Level %d",
        GOAL_GOTO = "Go to %.1f, %.1f",
        GOAL_LEARN = "Learn %s",
        GOAL_CREATE = "Create %s%s",
        GOAL_CREATE_PLURAL = "Create %d %s%s",
        GOAL_CONFIRM = "Click here to continue",
        GOAL_FPATH = "Discover flight path: %s",
        GOAL_HOME = "Set hearthstone at %s",
        GOAL_HEARTH = "Use Hearthstone to %s",
        GOAL_VENDOR = "Sell junk / Repair at %s",
        GOAL_TRAINER = "Train abilities with %s",

        -- UI Labels
        UI_ADDON_TITLE = "AzerothRoute",
        UI_GUIDES = "Guides",
        UI_TALENTS = "Talents",
        UI_STEP_FMT = "%d/%d",
        UI_GUIDE_MENU_TITLE = "AzerothRoute — Guide Center",
        UI_SUGGESTED = "Suggested",
        UI_LEVELING = "Leveling",
        UI_DUNGEONS = "Dungeons",
        UI_PROFESSIONS = "Professions",
        UI_GOLD = "Gold",
        UI_ALL_GUIDES = "All Guides",
        UI_LOAD_GUIDE = "Load Selected Guide",
        UI_SELECT_GUIDE = "Select a Guide",
        UI_SELECT_GUIDE_DESC = "Click any guide on the left to inspect its steps and load it into the viewer.",
        UI_GUIDE_META_FMT = "Type: %s | Levels: %d-%d | Steps: %d",
        UI_CORPSE = "Retrieve Your Corpse",
        UI_PREV_PAGE = "< Prev",
        UI_NEXT_PAGE = "Next >",
        UI_PAGE_FMT = "Page %d/%d",
        UI_TALENT_TITLE = "AzerothRoute — Talent Advisor",
        UI_TALENT_NEXT_POINT = "Level %d — Next talent: %s",
        UI_TALENT_APPLY = "Auto-Apply Build",
        UI_TALENT_LEVEL_FMT = "Level %d: %s",
        UI_TALENT_COMPLETED = "Build complete (60)",
        UI_WAIT_LEVEL_FMT = "Waiting for Level %d (Current: %d)",
        UI_INCOMPLETE_TURNIN = "Quest objectives are not yet complete for turn-in.",
    },
    es = {
        -- Goal Verbs & Actions
        GOAL_ACCEPT = "Acepta %s",
        GOAL_TURNIN = "Entrega %s",
        GOAL_KILL = "Mata a %s%s",
        GOAL_KILL_PLURAL = "Mata a %d %s%s",
        GOAL_COLLECT = "Consigue %s%s",
        GOAL_COLLECT_PLURAL = "Consigue %d %s%s",
        GOAL_BUY = "Compra %s%s",
        GOAL_BUY_PLURAL = "Compra %d %s%s",
        GOAL_TALK = "Habla con %s",
        GOAL_DING = "Alcanza el nivel %d",
        GOAL_GOTO = "Ve a %.1f, %.1f",
        GOAL_LEARN = "Aprende %s",
        GOAL_CREATE = "Crea %s%s",
        GOAL_CREATE_PLURAL = "Crea %d %s%s",
        GOAL_CONFIRM = "Haz clic aquí para continuar",
        GOAL_FPATH = "Descubre la ruta de vuelo: %s",
        GOAL_HOME = "Fija tu Piedra de Hogar en %s",
        GOAL_HEARTH = "Usa Piedra de Hogar hacia %s",
        GOAL_VENDOR = "Vende basura / Repara con %s",
        GOAL_TRAINER = "Entrena habilidades con %s",

        -- UI Labels
        UI_ADDON_TITLE = "AzerothRoute",
        UI_GUIDES = "Guías",
        UI_TALENTS = "Talentos",
        UI_STEP_FMT = "%d/%d",
        UI_GUIDE_MENU_TITLE = "AzerothRoute — Centro de Guías",
        UI_SUGGESTED = "Sugeridas",
        UI_LEVELING = "Leveo",
        UI_DUNGEONS = "Mazmorras",
        UI_PROFESSIONS = "Profesiones",
        UI_GOLD = "Oro",
        UI_ALL_GUIDES = "Todas las Guías",
        UI_LOAD_GUIDE = "Cargar Guía Seleccionada",
        UI_SELECT_GUIDE = "Selecciona una Guía",
        UI_SELECT_GUIDE_DESC = "Haz clic en cualquier guía de la lista para ver sus pasos y cargarla en el visor.",
        UI_GUIDE_META_FMT = "Tipo: %s | Niveles: %d-%d | Pasos: %d",
        UI_CORPSE = "Recupera tu cadáver",
        UI_PREV_PAGE = "< Anterior",
        UI_NEXT_PAGE = "Siguiente >",
        UI_PAGE_FMT = "Página %d/%d",
        UI_TALENT_TITLE = "AzerothRoute — Asesor de Talentos",
        UI_TALENT_NEXT_POINT = "Nivel %d — Próximo talento: %s",
        UI_TALENT_APPLY = "Aplicar Talentos",
        UI_TALENT_LEVEL_FMT = "Nivel %d: %s",
        UI_TALENT_COMPLETED = "Build completa (60)",
        UI_WAIT_LEVEL_FMT = "Esperando nivel %d (Actual: %d)",
        UI_INCOMPLETE_TURNIN = "Aún faltan objetivos antes de entregar la misión.",
    },
}

function L:GetLocale()
    return (_G.GetLocale and _G.GetLocale()) or "enUS"
end

function L:IsSpanish()
    local loc = self:GetLocale()
    return loc == "esMX" or loc == "esES"
end

function L:Get(key)
    local lang = self:IsSpanish() and "es" or "en"
    local tbl = self.STRINGS[lang] or self.STRINGS.en
    return tbl[key] or self.STRINGS.en[key] or key
end

function L:Format(key, ...)
    return string.format(self:Get(key), ...)
end

return L
