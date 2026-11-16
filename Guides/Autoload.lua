-- AzerothRoute: Multi-Locale (esMX/esES/enUS) Built-in Guides Catalog (SPEC-14B / SPEC-19)
-- Covers Horde & Alliance Leveling, Professions, Dungeons, and Gold Farming routes.

local AR = _G.AzerothRoute
local GuidesCatalog = {}
AR.GuidesCatalog = GuidesCatalog

local LOCALE_STRINGS = {
    esMX = {
        TIRISFAL_DESC = "Ruta optimizada de Claros de Tirisfal (Niveles 1-12) para No-Muertos y Paladín.",
        BARRENS_DESC = "Ruta completa de Los Baldíos (Niveles 12-22) con tareas paralelas (Stickies).",
        ELWYNN_DESC = "Ruta inicial del Bosque de Elwynn (Niveles 1-12) para la Alianza.",
        SFK_DESC = "Guía de misiones y jefes del Castillo de Colmillo Oscuro (Niveles 18-26).",
        ALCHEMY_DESC = "Guía rápida de Alquimia (1-300) con compra automática de viales.",
        GOLD_DESC = "Circuito de Herboristería y Minería en Claros de Tirisfal para oro por hora.",
    },
    enUS = {
        TIRISFAL_DESC = "Optimized Tirisfal Glades (Levels 1-12) route for Undead & Paladin.",
        BARRENS_DESC = "Complete The Barrens (Levels 12-22) route with parallel Sticky tasks.",
        ELWYNN_DESC = "Alliance starter route for Elwynn Forest (Levels 1-12).",
        SFK_DESC = "Shadowfang Keep (Levels 18-26) dungeon quests and bosses guide.",
        ALCHEMY_DESC = "Fast Alchemy (1-300) leveling guide with automated vial purchasing.",
        GOLD_DESC = "Tirisfal Glades Herbalism & Mining loop for high gold per hour.",
    },
}

function GuidesCatalog:GetLocaleTable()
    local loc = (_G.GetLocale and _G.GetLocale()) or "esMX"
    if loc == "esES" or loc == "esMX" then
        return LOCALE_STRINGS.esMX
    end
    return LOCALE_STRINGS.enUS
end

function GuidesCatalog:LoadAll()
    if not AR.Parser then return false end
    local L = self:GetLocaleTable()

    AR.Parser:RegisterInclude("HordeDeathknellTrainer", [[
        step
            talk %npc%##%npcid%
            learn Seal of Righteousness##21084 |only Paladin
    ]])

    -- 1. Horde Leveling: Tirisfal Glades (1-12)
    AR.Parser:ParseGuide("Leveling\\Horde\\Tirisfal Glades (1-12)", string.format([[
        author AzerothRoute
        description %s
        type LEVELING
        startlevel 1
        endlevel 12
        next Leveling\Horde\The Barrens (12-22)
        defaultfor Undead
        condition_suggested level >= 1 and level <= 12

        step WakeUp
            goto 1420 30.2,71.4
            accept Rude Awakening##363

        step TurnInWakeUp
            goto 1420 32.4,69.8
            turnin Rude Awakening##363
            accept The Mindless Ones##364

        #include "HordeDeathknellTrainer" npc="Brother Malach" npcid="5675"

        stickystart "GhoulCleanup"
        step GhoulCleanup
            kill Wretched Ghoul##1502 |q 364/2 |count 8
        stickystop

        step ZombieHunt
            goto 1420 33.0,65.0
            kill Mindless Zombie##1501 |q 364/1 |count 8

        step FinishMindless
            goto 1420 32.4,69.8
            turnin The Mindless Ones##364
            accept Rattling the Rattlecages##380
    ]], L.TIRISFAL_DESC))

    -- 2. Horde Leveling: The Barrens (12-22)
    AR.Parser:ParseGuide("Leveling\\Horde\\The Barrens (12-22)", string.format([[
        author AzerothRoute
        description %s
        type LEVELING
        startlevel 12
        endlevel 22
        condition_suggested level >= 12 and level <= 22

        step CrossroadsArrival
            goto 1413 51.5,30.8
            accept The Forgotten Pools##870
            accept Kolkar Leaders##850

        stickystart "CentaurBracersSticky"
        step CentaurBracersSticky
            get 15 Centaur Bracers##5010 |q 855/1 |opt
        stickystop

        step BarrensOasis
            goto 1413 45.1,22.5
            kill Barak Kodobane##3394 |q 850/1

        step KodobaneTurnin
            goto 1413 51.5,30.8
            turnin Kolkar Leaders##850
            accept Centaur Bracers##855
    ]], L.BARRENS_DESC))

    -- 3. Alliance Leveling: Elwynn Forest (1-12)
    AR.Parser:ParseGuide("Leveling\\Alliance\\Elwynn Forest (1-12)", string.format([[
        author AzerothRoute
        description %s
        type LEVELING
        startlevel 1
        endlevel 12
        defaultfor Human

        step NorthshireStart
            goto 1429 48.2,42.9
            accept A Threat Within##783

        step NorthshireTurnin
            goto 1429 48.9,41.6
            turnin A Threat Within##783
            accept Kobold Camp Cleanup##7
    ]], L.ELWYNN_DESC))

    -- 4. Dungeons: Shadowfang Keep (18-26)
    AR.Parser:ParseGuide("Dungeons\\Shadowfang Keep (18-26)", string.format([[
        author AzerothRoute
        description %s
        type DUNGEONS
        startlevel 18
        endlevel 26

        step SFKQuests
            goto 1421 45.6,42.6
            accept Arugal Must Die##1014
            accept The Book of Ur##1013

        step SFKBosses
            kill Archmage Arugal##4275 |q 1014/1
            get The Book of Ur##6283 |q 1013/1
    ]], L.SFK_DESC))

    -- 5. Professions: Alchemy (1-300)
    AR.Parser:ParseGuide("Professions\\Alchemy (1-300)", string.format([[
        author AzerothRoute
        description %s
        type PROFESSIONS
        startlevel 1
        endlevel 60
        condition_suggested hasprof("Alchemy")

        step GatherPeacebloom
            buy 10 Empty Vial##3371
            get 10 Peacebloom##2447

        step CraftMinorHealing
            create 10 Minor Healing Potion##2330
    ]], L.ALCHEMY_DESC))

    -- 6. Gold Farming: Tirisfal Herbalism & Mining Loop
    AR.Parser:ParseGuide("Gold\\Tirisfal Herbalism & Mining Loop", string.format([[
        author AzerothRoute
        description %s
        type GOLD
        startlevel 1
        endlevel 60

        step LoopNode1
            goto 1420 35.0,55.0
            get 20 Peacebloom##2447
            get 10 Copper Ore##2770
    ]], L.GOLD_DESC))

    return true
end

GuidesCatalog:LoadAll()

return GuidesCatalog
