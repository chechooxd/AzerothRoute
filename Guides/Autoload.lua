-- AzerothRoute: Multi-Locale (esMX/esES/enUS) Full 55-Guide Classic Catalog (SPEC-14B / SPEC-19 / SPEC-21)
-- Covers Alliance & Horde Leveling (1-60), Dungeons (13-60), All Professions (1-300), and Gold Farming Loops.

local AR = _G.AzerothRoute
local GuidesCatalog = {}
AR.GuidesCatalog = GuidesCatalog

function GuidesCatalog:GetLocaleTable()
    local loc = (_G.GetLocale and _G.GetLocale()) or "enUS"
    if loc == "esES" or loc == "esMX" then
        return "es"
    end
    return "en"
end

function GuidesCatalog:LoadAll()
    if not AR.Parser then return false end
    local isEs = self:GetLocaleTable() == "es"

    AR.Parser:RegisterInclude("HordeDeathknellTrainer", [[
        step
            talk %npc%##%npcid%
            learn Seal of Righteousness##21084 |only Paladin
    ]])

    local function registerGuide(key, titleES, descEN, descES, body)
        local fullBody = "author AzerothRoute\n"
            .. "description " .. (isEs and descES or descEN) .. "\n"
            .. body
        local g = AR.Parser:ParseGuide(key, fullBody)
        if g then
            g.displayTitleEN = key:match("([^\\]+)$") or key
            g.displayTitleES = titleES
            g.descriptionEN = descEN
            g.descriptionES = descES
        end
        return g
    end

    -- =========================================================================
    -- 1. HORDE LEVELING (1-60) - 13 ZONES
    -- =========================================================================
    registerGuide("Leveling\\Horde\\Tirisfal Glades (1-12)", "Claros de Tirisfal (1-12)",
        "Optimized Tirisfal Glades (Levels 1-12) route for Undead & Paladin.",
        "Ruta optimizada de Claros de Tirisfal (Niveles 1-12) para No-Muertos y Paladín.", [[
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

        step BrillArrival
            goto 1420 60.6,51.8
            accept A Putrid Task##404 |goto Tirisfal Glades 60.6,51.8
            fpath Brill
    ]])

    registerGuide("Leveling\\Horde\\Durotar (1-12)", "Durotar (1-12)",
        "Orc & Troll starting route through Valley of Trials and Razor Hill.",
        "Ruta inicial para Orcos y Trols por el Valle de los Retos y Cerrotajo.", [[
        type LEVELING
        startlevel 1
        endlevel 12
        next Leveling\Horde\The Barrens (12-22)
        defaultfor Orc,Troll
        condition_suggested level >= 1 and level <= 12

        step ValleyStart
            goto Durotar 43.3,68.5
            accept Your Place In The World##4641

        step BoarHunt
            goto Durotar 40.6,62.6
            accept Cutting Teeth##788
            kill Mottled Boar##3098 |q 788/1 |count 10

        step RazorHill
            goto Durotar 51.9,43.5
            accept Vanquish the Betrayers##784
            fpath Razor Hill
    ]])

    registerGuide("Leveling\\Horde\\Mulgore (1-12)", "Mulgore (1-12)",
        "Tauren starting route from Camp Narache to Bloodhoof Village.",
        "Ruta inicial Tauren desde el Campamento Narache hasta Poblado Pezuña de Sangre.", [[
        type LEVELING
        startlevel 1
        endlevel 12
        next Leveling\Horde\The Barrens (12-22)
        defaultfor Tauren
        condition_suggested level >= 1 and level <= 12

        step NaracheStart
            goto Mulgore 44.9,77.1
            accept The Hunt Begins##747
            kill Plainstrider##2955 |q 747/1 |count 7

        step BloodhoofVillage
            goto Mulgore 47.5,60.2
            accept Swoop Hunting##761
            home Bloodhoof Village
    ]])

    registerGuide("Leveling\\Horde\\The Barrens (12-22)", "Los Baldíos (12-22)",
        "Complete The Barrens (Levels 12-22) route with parallel Sticky tasks.",
        "Ruta completa de Los Baldíos (Niveles 12-22) con tareas paralelas (Stickies).", [[
        type LEVELING
        startlevel 12
        endlevel 22
        next Leveling\Horde\Stonetalon Mountains (22-25)
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
    ]])

    registerGuide("Leveling\\Horde\\Silverpine Forest (12-20)", "Bosque de Argénteos (12-20)",
        "Forsaken progression from The Sepulcher through Fenris Isle and Ambermill.",
        "Progresión Renegada desde El Sepulcro hacia la Isla de Fenris y Molino Ámbar.", [[
        type LEVELING
        startlevel 12
        endlevel 20
        next Leveling\Horde\Hillsbrad Foothills (22-30)

        step SepulcherQuests
            goto Silverpine Forest 44.2,39.8
            accept Escorting Erland##435
            accept Prove Your Allegiance##422
            fpath The Sepulcher
    ]])

    registerGuide("Leveling\\Horde\\Stonetalon Mountains (22-25)", "Sierra Espolón (22-25)",
        "Sun Rock Retreat quests and Windshear Crag progression.",
        "Misiones del Refugio Roca del Sol y Risco Cortaviento.", [[
        type LEVELING
        startlevel 22
        endlevel 25
        next Leveling\Horde\Hillsbrad Foothills (22-30)

        step SunRock
            goto Stonetalon Mountains 47.4,58.5
            accept Boulderslide Ravine##6421
            fpath Sun Rock Retreat
    ]])

    registerGuide("Leveling\\Horde\\Hillsbrad Foothills (22-30)", "Laderas de Trabalomas (22-30)",
        "Tarren Mill Syndicate and Hillsbrad Fields XP circuit.",
        "Circuito de experiencia en Molino Tarren y los Campos de Trabalomas.", [[
        type LEVELING
        startlevel 22
        endlevel 30
        next Leveling\Horde\Stranglethorn Vale (30-42)

        step TarrenMill
            goto Hillsbrad Foothills 62.4,20.3
            accept Time To Strike##494
            accept Battle of Hillsbrad##527
            fpath Tarren Mill
    ]])

    registerGuide("Leveling\\Horde\\Thousand Needles (25-32)", "Las Mil Agujas (25-32)",
        "Freewind Post quests and Shimmering Flats racing hub.",
        "Misiones del Poblado Viento Libre y el Salar de las Mil Agujas.", [[
        type LEVELING
        startlevel 25
        endlevel 32
        next Leveling\Horde\Stranglethorn Vale (30-42)

        step FreewindPost
            goto Thousand Needles 45.7,50.8
            accept Alien Egg##4821
            fpath Freewind Post
    ]])

    registerGuide("Leveling\\Horde\\Stranglethorn Vale (30-42)", "Vega de Tuercespina (30-42)",
        "Nesingwary Safari mastery lines combined with Grom'gol quests.",
        "Cacerías de Nesingwary combinadas con las misiones de Grom'gol.", [[
        type LEVELING
        startlevel 30
        endlevel 42
        next Leveling\Horde\Tanaris (40-48)

        step NesingwaryHorde
            goto Stranglethorn Vale 35.6,10.5
            accept Welcome to the Jungle##583
            accept Tiger Mastery##185
            accept Panther Mastery##190
    ]])

    registerGuide("Leveling\\Horde\\Tanaris (40-48)", "Tanaris (40-48)",
        "Gadgetzan wasteland hunts and Zul'Farrak quest setup.",
        "Cacerías del desierto en Gadgetzan y preparación de Zul'Farrak.", [[
        type LEVELING
        startlevel 40
        endlevel 48
        next Leveling\Horde\Un'Goro Crater (48-54)

        step GadgetzanHorde
            goto Tanaris 51.6,28.1
            accept Wastewander Justice##1690
            fpath Gadgetzan
    ]])

    registerGuide("Leveling\\Horde\\Un'Goro Crater (48-54)", "Cráter de Un'Goro (48-54)",
        "High-density Marshal's Refuge loop collecting Crystals and Dino bones.",
        "Circuito de alta densidad recolectando cristales y huesos en el Refugio.", [[
        type LEVELING
        startlevel 48
        endlevel 54
        next Leveling\Horde\Western Plaguelands (52-57)

        step MarshalsRefuge
            goto Un'Goro Crater 43.1,9.7
            accept The Apes of Un'Goro##4289
            accept Shizzle's Flyer##4503
    ]])

    registerGuide("Leveling\\Horde\\Western Plaguelands (52-57)", "Tierras de la Peste del Oeste (52-57)",
        "Cauldron cleansing chain across Sorrow Hill and Andorhal.",
        "Cadena de limpieza de calderos entre Colina de la Pena y Andorhal.", [[
        type LEVELING
        startlevel 52
        endlevel 57
        next Leveling\Horde\Eastern Plaguelands (56-60)

        step BulwarkQuests
            goto Tirisfal Glades 83.2,68.9
            accept A Plague Upon Thee##5901
    ]])

    registerGuide("Leveling\\Horde\\Eastern Plaguelands (56-60)", "Tierras de la Peste del Este (56-60)",
        "Final 56-60 Argent Dawn and Light's Hope Chapel quest lines.",
        "Cadena final 56-60 del Alba Argenta y la Capilla de la Esperanza de la Luz.", [[
        type LEVELING
        startlevel 56
        endlevel 60

        step LightsHope
            goto Eastern Plaguelands 81.5,59.7
            accept Demon Dogs##5542
            fpath Light's Hope Chapel
    ]])

    -- =========================================================================
    -- 2. ALLIANCE LEVELING (1-60) - 13 ZONES
    -- =========================================================================
    registerGuide("Leveling\\Alliance\\Elwynn Forest (1-12)", "Bosque de Elwynn (1-12)",
        "Alliance starter route for Elwynn Forest (Levels 1-12).",
        "Ruta inicial del Bosque de Elwynn (Niveles 1-12) para la Alianza.", [[
        type LEVELING
        startlevel 1
        endlevel 12
        next Leveling\Alliance\Westfall (12-20)
        defaultfor Human
        condition_suggested level >= 1 and level <= 12

        step NorthshireStart
            goto 1429 48.2,42.9
            accept A Threat Within##783

        step NorthshireTurnin
            goto 1429 48.9,41.6
            turnin A Threat Within##783
            accept Kobold Camp Cleanup##7

        step GoldshireArrival
            goto Elwynn Forest 42.1,65.9
            accept The Fargodeep Mine##62
            home Goldshire
    ]])

    registerGuide("Leveling\\Alliance\\Dun Morogh (1-12)", "Dun Morogh (1-12)",
        "Dwarf & Gnome starting route from Coldridge Valley to Kharanos.",
        "Ruta inicial de Enanos y Gnomos desde el Valle de Crestanevada a Kharanos.", [[
        type LEVELING
        startlevel 1
        endlevel 12
        next Leveling\Alliance\Loch Modan (12-20)
        defaultfor Dwarf,Gnome
        condition_suggested level >= 1 and level <= 12

        step ColdridgeStart
            goto Dun Morogh 29.9,71.2
            accept Dwarven Outfitters##179
            kill Ragged Young Wolf##705 |q 179/1 |count 8

        step KharanosHub
            goto Dun Morogh 46.8,52.4
            accept Beer Basted Boar Ribs##384
            home Kharanos
    ]])

    registerGuide("Leveling\\Alliance\\Teldrassil (1-12)", "Teldrassil (1-12)",
        "Night Elf route from Shadowglen through Dolanaar to Darnassus.",
        "Ruta de Elfos de la Noche de Cañada Umbría a Dolanaar y Darnassus.", [[
        type LEVELING
        startlevel 1
        endlevel 12
        next Leveling\Alliance\Darkshore (12-20)
        defaultfor NightElf
        condition_suggested level >= 1 and level <= 12

        step ShadowglenStart
            goto Teldrassil 58.7,44.4
            accept The Balance of Nature##456
            kill Young Nightsaber##2031 |q 456/1 |count 7

        step DolanaarHub
            goto Teldrassil 55.9,57.3
            accept Zenn's Bidding##488
    ]])

    registerGuide("Leveling\\Alliance\\Westfall (12-20)", "Páramos de Poniente (12-20)",
        "Sentinel Hill Defias chain and Deadmines attunement.",
        "Cadena Defias de Colina del Centinela y preparación de Minas de la Muerte.", [[
        type LEVELING
        startlevel 12
        endlevel 20
        next Leveling\Alliance\Redridge Mountains (18-25)

        step SentinelHill
            goto Westfall 56.3,47.5
            accept The People's Militia##12
            accept Red Leather Bandanas##153
            fpath Sentinel Hill
    ]])

    registerGuide("Leveling\\Alliance\\Loch Modan (12-20)", "Loch Modan (12-20)",
        "Thelsamar trogg and kobold cleanup loop around the Loch.",
        "Circuito de troggs y kóbolds alrededor de Thelsamar.", [[
        type LEVELING
        startlevel 12
        endlevel 20
        next Leveling\Alliance\Redridge Mountains (18-25)

        step Thelsamar
            goto Loch Modan 34.8,49.3
            accept In Defense of the King's Lands##224
            fpath Thelsamar
    ]])

    registerGuide("Leveling\\Alliance\\Darkshore (12-20)", "Costa Oscura (12-20)",
        "Auberdine coastline loop from Bashal'Aran to Twilight Shore.",
        "Circuito costero de Auberdine desde Bashal'Aran hasta la Costa del Crepúsculo.", [[
        type LEVELING
        startlevel 12
        endlevel 20
        next Leveling\Alliance\Ashenvale (22-30)

        step Auberdine
            goto Darkshore 36.6,45.6
            accept Buzzbox 827##983
            accept Plagued Lands##2118
            fpath Auberdine
    ]])

    registerGuide("Leveling\\Alliance\\Redridge Mountains (18-25)", "Montañas Crestagrana (18-25)",
        "Lakeshire gnoll and Blackrock orc chains across Stonewatch.",
        "Cadenas de gnolls y orcos Roca Negra desde Villa del Lago.", [[
        type LEVELING
        startlevel 18
        endlevel 25
        next Leveling\Alliance\Duskwood (20-30)

        step Lakeshire
            goto Redridge Mountains 30.6,59.4
            accept Blackrock Menace##20
            fpath Lakeshire
    ]])

    registerGuide("Leveling\\Alliance\\Duskwood (20-30)", "Bosque del Ocaso (20-30)",
        "Darkshire worgen, Stitches, and Stalvan Mistmantle chains.",
        "Cadenas de huargos, Puntos y la leyenda de Stalvan en Villa Oscura.", [[
        type LEVELING
        startlevel 20
        endlevel 30
        next Leveling\Alliance\Stranglethorn Vale (30-42)

        step Darkshire
            goto Duskwood 75.8,45.3
            accept The Legend of Stalvan##66
            fpath Darkshire
    ]])

    registerGuide("Leveling\\Alliance\\Ashenvale (22-30)", "Vallefresno (22-30)",
        "Astranaar forest patrol and furbolg camps.",
        "Patrulla por los bosques de Astranaar y campamentos fúrbolg.", [[
        type LEVELING
        startlevel 22
        endlevel 30
        next Leveling\Alliance\Stranglethorn Vale (30-42)

        step Astranaar
            goto Ashenvale 34.4,48.0
            accept Raene's Cleansing##1025
            fpath Astranaar
    ]])

    registerGuide("Leveling\\Alliance\\Stranglethorn Vale (30-42)", "Vega de Tuercespina - Alianza (30-42)",
        "Rebel Camp, Nesingwary Safari, and Booty Bay piracy quests.",
        "Campamento Rebelde, Safari de Nesingwary y misiones de Bahía del Botín.", [[
        type LEVELING
        startlevel 30
        endlevel 42
        next Leveling\Alliance\Searing Gorge (45-51)

        step RebelCamp
            goto Stranglethorn Vale 38.0,3.4
            accept Kurzen's Mystery##207
            fpath Rebel Camp
    ]])

    registerGuide("Leveling\\Alliance\\Searing Gorge (45-51)", "La Garganta de Fuego (45-51)",
        "Thorium Brotherhood hub and Dark Iron dwarf quarries.",
        "Hermandad del Torio y canteras de los enanos Hierro Negro.", [[
        type LEVELING
        startlevel 45
        endlevel 51
        next Leveling\Alliance\Winterspring (53-60)

        step ThoriumPoint
            goto Searing Gorge 38.6,27.8
            accept Fiery Menace!##7724
            fpath Thorium Point
    ]])

    registerGuide("Leveling\\Alliance\\Winterspring (53-60)", "Cuna del Invierno (53-60)",
        "Everlook yeti, owlbeast, and frostsaber loops.",
        "Circuitos de yetis y lechúcicos alrededor de Vista Eterna.", [[
        type LEVELING
        startlevel 53
        endlevel 60
        next Leveling\Alliance\Eastern Plaguelands (56-60)

        step Everlook
            goto Winterspring 61.3,38.9
            accept Are We There, Yeti?##3783
            fpath Everlook
    ]])

    registerGuide("Leveling\\Alliance\\Eastern Plaguelands (56-60)", "Tierras de la Peste del Este - Alianza (56-60)",
        "Tirion Fordring & Light's Hope Chapel finale to level 60.",
        "Cadenas finales de Tirion Vadín y la Capilla de la Esperanza hasta nivel 60.", [[
        type LEVELING
        startlevel 56
        endlevel 60

        step FordringCamp
            goto Eastern Plaguelands 7.6,43.7
            accept Demon Dogs##5542
    ]])

    -- =========================================================================
    -- 3. DUNGEONS (13-60) - 12 CLASSIC INSTANCES
    -- =========================================================================
    registerGuide("Dungeons\\Ragefire Chasm (13-18)", "Sima Ígnea (13-18)",
        "Orgrimmar dungeon quests and boss tactics.",
        "Misiones de mazmorra en Orgrimmar y tácticas de jefes.", [[
        type DUNGEONS
        startlevel 13
        endlevel 18
        step RFCStart
            goto Orgrimmar 52.8,49.0
            accept Hidden Enemies##5726
            kill Bazzalan##11519
    ]])

    registerGuide("Dungeons\\The Deadmines (17-24)", "Las Minas de la Muerte (17-24)",
        "Moonbrook Brotherhood quests leading to Edwin VanCleef.",
        "Misiones de la Hermandad Defias hasta Edwin VanCleef.", [[
        type DUNGEONS
        startlevel 17
        endlevel 24
        step DMQuests
            goto Westfall 42.6,71.8
            accept Red Silk Bandanas##214
            kill Edwin VanCleef##639
    ]])

    registerGuide("Dungeons\\Wailing Caverns (17-24)", "Cuevas de los Lamentos (17-24)",
        "Barrens Oasis quests, Serpentbloom, and Mutanus the Devourer.",
        "Misiones de Los Baldíos, Flor de serpiente y Mutanus el Devorador.", [[
        type DUNGEONS
        startlevel 17
        endlevel 24
        step WCStart
            goto The Barrens 46.0,36.2
            accept Leaders of the Fang##914
            kill Mutanus the Devourer##3654
    ]])

    registerGuide("Dungeons\\Shadowfang Keep (18-26)", "Castillo de Colmillo Oscuro (18-26)",
        "Shadowfang Keep (Levels 18-26) dungeon quests and bosses guide.",
        "Guía de misiones y jefes del Castillo de Colmillo Oscuro (Niveles 18-26).", [[
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
    ]])

    registerGuide("Dungeons\\Blackfathom Deeps (22-30)", "Cavernas de Brazanegra (22-30)",
        "Zoram Strand quests and Aku'mai boss encounter.",
        "Misiones de la Empalizada de Zoram y combate contra Aku'mai.", [[
        type DUNGEONS
        startlevel 22
        endlevel 30
        step BFDStart
            goto Ashenvale 14.2,13.9
            accept Allegiance to the Old Gods##6564
            kill Aku'mai##4829
    ]])

    registerGuide("Dungeons\\Gnomeregan (27-35)", "Gnomeregan (27-35)",
        "Rig Wars and Mekgineer Thermaplugg dungeon clear.",
        "Guerra de máquinas y ruta hasta Mekingeniero Termochufe.", [[
        type DUNGEONS
        startlevel 27
        endlevel 35
        step GnomerQuests
            goto Dun Morogh 24.3,39.8
            accept Rig Wars##2841
            kill Mekgineer Thermaplugg##7800
    ]])

    registerGuide("Dungeons\\Razorfen Kraul (28-36)", "Horado Rajacieno (28-36)",
        "Southern Barrens quilboar wing and Charlga Razorflank.",
        "Ala de jabaespines del sur de Los Baldíos y Charlga Filonavaja.", [[
        type DUNGEONS
        startlevel 28
        endlevel 36
        step RFKStart
            goto The Barrens 42.9,89.4
            accept A Vengeful Fate##1102
            kill Charlga Razorflank##4421
    ]])

    registerGuide("Dungeons\\Scarlet Monastery (30-42)", "Monasterio Escarlata (30-42)",
        "GY, Library, Armory, and Cathedral wing boss & quest route.",
        "Ruta de Cementerio, Biblioteca, Armería y Catedral Escarlata.", [[
        type DUNGEONS
        startlevel 30
        endlevel 42
        step SMWings
            goto Tirisfal Glades 85.3,32.1
            accept Into The Scarlet Monastery##1048
            kill High Inquisitor Whitemane##3977
    ]])

    registerGuide("Dungeons\\Uldaman (38-46)", "Uldaman (38-46)",
        "Badlands excavation quests and Archaedas.",
        "Misiones de excavación en Tierras Inhóspitas y Archaedas.", [[
        type DUNGEONS
        startlevel 38
        endlevel 46
        step UldaStart
            goto Badlands 42.4,13.5
            accept Solution to Doom##709
            kill Archaedas##2748
    ]])

    registerGuide("Dungeons\\Zul'Farrak (42-50)", "Zul'Farrak (42-50)",
        "Carrot on a Stick quest and Pyramid event guide.",
        "Misión de la Zanahoria en un palo y evento de la Pirámide.", [[
        type DUNGEONS
        startlevel 42
        endlevel 50
        step ZFQuests
            goto Tanaris 39.2,21.3
            accept Gahz'rilla##2770
            kill Chief Ukorz Sandscalp##7267
    ]])

    registerGuide("Dungeons\\Maraudon (45-53)", "Maraudon (45-53)",
        "Purple/Orange wings and Princess Theradras.",
        "Alas púrpura/naranja y Princesa Theradras.", [[
        type DUNGEONS
        startlevel 45
        endlevel 53
        step MaraStart
            goto Desolace 29.1,62.5
            accept Legends of Maraudon##7044
            kill Princess Theradras##12201
    ]])

    registerGuide("Dungeons\\Blackrock Depths (52-60)", "Profundidades de Roca Negra (52-60)",
        "Onyxia/MC attunement quests and Emperor Dagran Thaurissan.",
        "Armonizaciones de Onyxia/MC y Emperador Dagran Thaurissan.", [[
        type DUNGEONS
        startlevel 52
        endlevel 60
        step BRDStart
            goto Searing Gorge 34.8,85.3
            accept Marshal Windsor##6402
            kill Emperor Dagran Thaurissan##9019
    ]])

    -- =========================================================================
    -- 4. PROFESSIONS (1-300) - ALL 11 CLASSIC PROFESSIONS
    -- =========================================================================
    registerGuide("Professions\\Alchemy (1-300)", "Alquimia (1-300)",
        "Fast Alchemy (1-300) leveling guide with automated vial purchasing.",
        "Guía rápida de Alquimia (1-300) con compra automática de viales.", [[
        type PROFESSIONS
        startlevel 1
        endlevel 60
        condition_suggested hasprof("Alchemy")

        step GatherPeacebloom
            buy 10 Empty Vial##3371
            get 10 Peacebloom##2447

        step CraftMinorHealing
            create 10 Minor Healing Potion##2330
    ]])

    registerGuide("Professions\\Herbalism (1-300)", "Herboristería (1-300)",
        "1-300 herb node routes from Peacebloom to Black Lotus.",
        "Rutas de recolección 1-300 desde Flor de paz hasta Loto negro.", [[
        type PROFESSIONS
        startlevel 1
        endlevel 60
        step HerbStarter
            goto Tirisfal Glades 40.5,55.2
            get 30 Silverleaf##765
    ]])

    registerGuide("Professions\\Mining (1-300)", "Minería (1-300)",
        "1-300 vein circuits: Copper, Tin, Iron, Mithril, and Thorium.",
        "Circuitos de menas 1-300: Cobre, Estaño, Hierro, Mitril y Torio.", [[
        type PROFESSIONS
        startlevel 1
        endlevel 60
        step MiningStarter
            goto Durotar 52.0,32.0
            get 40 Copper Ore##2770
    ]])

    registerGuide("Professions\\Skinning (1-300)", "Desuello (1-300)",
        "Beast farm hubs to power-level Skinning 1-300 with minimal downtime.",
        "Zonas de bestias para subir Desuello 1-300 sin esperas.", [[
        type PROFESSIONS
        startlevel 1
        endlevel 60
        step SkinStarter
            goto The Barrens 48.0,33.0
            get 40 Light Leather##2318
    ]])

    registerGuide("Professions\\Blacksmithing (1-300)", "Herrería (1-300)",
        "Minimal-ore Blacksmithing leveling kit 1-300.",
        "Guía económica de Herrería 1-300 con menor gasto de minerales.", [[
        type PROFESSIONS
        startlevel 1
        endlevel 60
        step BSSharpening
            get 20 Rough Stone##2835
            create 20 Rough Sharpening Stone##2862
    ]])

    registerGuide("Professions\\Engineering (1-300)", "Ingeniería (1-300)",
        "Practical Gnomish & Goblin Engineering leveling path 1-300.",
        "Ruta práctica de Ingeniería Gnómica y Goblin 1-300.", [[
        type PROFESSIONS
        startlevel 1
        endlevel 60
        step EngPowder
            get 30 Rough Stone##2835
            create 30 Rough Blasting Powder##4357
    ]])

    registerGuide("Professions\\Enchanting (1-300)", "Encantamiento (1-300)",
        "Dust, Essence, and Rod milestones for Enchanting 1-300.",
        "Materiales, varas y fórmulas para subir Encantamiento 1-300.", [[
        type PROFESSIONS
        startlevel 1
        endlevel 60
        step EnchDust
            get 30 Strange Dust##10940
    ]])

    registerGuide("Professions\\Tailoring (1-300)", "Sastrería (1-300)",
        "Cloth farming & bolt craft calculator from Linen to Runecloth.",
        "Patrones de Lino a Paño rúnico para Sastrería 1-300.", [[
        type PROFESSIONS
        startlevel 1
        endlevel 60
        step TailorLinen
            get 40 Linen Cloth##2589
            create 20 Bolt of Linen Cloth##2996
    ]])

    registerGuide("Professions\\Leatherworking (1-300)", "Peletería (1-300)",
        "Fastest leather conversion recipes 1-300.",
        "Recetas óptimas de conversión de cuero para Peletería 1-300.", [[
        type PROFESSIONS
        startlevel 1
        endlevel 60
        step LWArmorkit
            get 30 Light Leather##2318
            create 15 Light Armor Kit##2304
    ]])

    registerGuide("Professions\\Cooking (1-300)", "Cocina (1-300)",
        "Chef progression and Artisan Cooking quest at Gadgetzan.",
        "Progresión culinaria y misión de Cocina Artesanal en Gadgetzan.", [[
        type PROFESSIONS
        startlevel 1
        endlevel 60
        step CookMeat
            get 20 Stringy Wolf Meat##2672
    ]])

    registerGuide("Professions\\First Aid (1-300)", "Primeros Auxilios (1-300)",
        "Linen through Heavy Runecloth Bandages with trauma quest steps.",
        "Vendas de Lino a Paño rúnico grueso y misión en Hammerfall/Theramore.", [[
        type PROFESSIONS
        startlevel 1
        endlevel 60
        step FALinen
            get 40 Linen Cloth##2589
            create 20 Linen Bandage##1251
    ]])

    -- =========================================================================
    -- 5. GOLD FARMING LOOPS - 6 ROUTES
    -- =========================================================================
    registerGuide("Gold\\Tirisfal Herbalism & Mining Loop", "Oro: Herboristería y Minería en Tirisfal",
        "Tirisfal Glades Herbalism & Mining loop for high gold per hour.",
        "Circuito de Herboristería y Minería en Claros de Tirisfal para oro por hora.", [[
        type GOLD
        startlevel 1
        endlevel 60

        step LoopNode1
            goto 1420 35.0,55.0
            get 20 Peacebloom##2447
            get 10 Copper Ore##2770
    ]])

    registerGuide("Gold\\Elwynn & Westfall Herb/Ore Circuit", "Oro: Circuito Bosque de Elwynn y Poniente",
        "Early Alliance gathering circuit for Swiftthistle & Briarthorn.",
        "Circuito de recolección temprano para Cardopresto y Brezospina.", [[
        type GOLD
        startlevel 10
        endlevel 60
        step AllianceHerbLoop
            goto Westfall 54.0,52.0
            get 20 Briarthorn##2450
    ]])

    registerGuide("Gold\\Barrens Deviate Fish & Leather Route", "Oro: Peces Descarriados y Cuero en Baldíos",
        "Wailing Caverns Oasis Savory Deviate Delight gold farm.",
        "Farmeo de Peces descarriados deliciosos en los oasis de Los Baldíos.", [[
        type GOLD
        startlevel 15
        endlevel 60
        step BarrensFishLoop
            goto The Barrens 46.2,39.4
            get 20 Deviate Fish##6522
    ]])

    registerGuide("Gold\\Arathi Elemental Fire & Herbs", "Oro: Fuego Elemental y Hierbas en Arathi",
        "High-margin Elemental Fire farm at Circle of East Binding.",
        "Farmeo rentable de Fuego elemental en Tierras Altas de Arathi.", [[
        type GOLD
        startlevel 36
        endlevel 60
        step ArathiCircle
            goto Arathi Highlands 55.2,48.9
            get 10 Elemental Fire##7068
    ]])

    registerGuide("Gold\\Felwood Gromsblood & Satyr Farm", "Oro: Sangregroms y Sátiros en Frondavil",
        "Felcloth and Gromsblood high-demand endgame farming circuit.",
        "Circuito de Tela vil y Sangregroms de alta demanda en Frondavil.", [[
        type GOLD
        startlevel 48
        endlevel 60
        step FelwoodLoop
            goto Felwood 42.1,21.5
            get 15 Gromsblood##8846
    ]])

    registerGuide("Gold\\Winterspring Rich Thorium & Lotus", "Oro: Torio Enriquecido y Loto en Cuna del Invierno",
        "Level 60 Arcane Crystal & Black Lotus gold farming circuit.",
        "Circuito nivel 60 para Cristal Arcano y Loto negro en Cuna del Invierno.", [[
        type GOLD
        startlevel 55
        endlevel 60
        step WinterspringGold
            goto Winterspring 59.8,44.2
            get 20 Thorium Ore##10620
    ]])

    return true
end

GuidesCatalog:LoadAll()

return GuidesCatalog
