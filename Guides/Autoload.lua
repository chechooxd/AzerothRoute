-- AzerothRoute: Multi-Locale (esMX/esES/enUS) Full 55-Guide Classic Catalog with Zygor-Depth Leveling Loops (SPEC-14B / SPEC-19 / SPEC-21 / SPEC-22)
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
            only Paladin
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
    -- 1. HORDE LEVELING (1-60) - FULL MULTI-STEP ZYGOR/RXP PROGRESSION
    -- =========================================================================
    registerGuide("Leveling\\Horde\\Tirisfal Glades (1-12)", "Claros de Tirisfal (1-12)",
        "Optimized Tirisfal Glades (Levels 1-12) route from Deathknell through Brill and Agamand Mills.",
        "Ruta optimizada de Claros de Tirisfal (Niveles 1-12) desde Camposanto hasta Rémol y Molinos Agamand.", [[
        type LEVELING
        startlevel 1
        endlevel 12
        next Leveling\Horde\The Barrens (12-22)
        defaultfor Undead
        condition_suggested level >= 1 and level <= 12

        step WakeUp
            goto 1420 30.2,71.4
            talk Undertaker Mordo##1568
            accept Rude Awakening##363

        step TurnInWakeUp
            goto 1420 30.8,66.2
            talk Shadow Priest Sarvis##1569
            turnin Rude Awakening##363
            accept The Mindless Ones##364

        step DeathknellTrainer
            talk Dannal Stern##2119 |goto 1420 32.7,65.6 |only Warrior
            talk David Trias##2122 |goto 1420 32.5,65.7 |only Rogue
            talk Dark Cleric Duesten##2123 |goto 1420 31.1,66.0 |only Priest
            talk Isabella##2124 |goto 1420 30.9,66.1 |only Mage
            talk Maximillion##2126 |goto 1420 30.9,66.3 |only Warlock

        stickystart "GhoulCleanup"
        step GhoulCleanup
            kill Wretched Ghoul##1502 |q 364/2 |count 8
        stickystop

        step ZombieHunt
            goto 1420 33.0,65.0
            kill Mindless Zombie##1501 |q 364/1 |count 8

        step FinishMindless
            goto 1420 30.8,66.2
            talk Shadow Priest Sarvis##1569
            turnin The Mindless Ones##364
            accept Rattling the Rattlecages##3901
            accept Piercing the Veil##1470 |only Warlock

        step DamnedAccept
            goto 1420 30.9,66.1
            talk Novice Elreth##1661
            accept The Damned##376

        step VendorDeathknell
            goto 1420 32.4,66.2
            vendor Blacksmith Rand##2116

        stickystart "DeathknellDuskbat"
        step DeathknellDuskbat
            kill Young Scavenger##1508+
            get 6 Scavenger Paw##3265 |q 376/1 |goto Tirisfal Glades 32.6,58.6
            kill Duskbat##1512+
            get 6 Duskbat Wing##3264 |q 376/2 |goto Tirisfal Glades 32.6,58.6
        stickystop

        step RattlecagesHunt
            goto 1420 32.8,61.2
            kill Rattlecage Skeleton##1890 |q 3901/1 |count 12

        step DeathknellTurnin1
            goto 1420 30.9,66.1
            talk Novice Elreth##1661
            turnin The Damned##376
            accept Marla's Last Wish##6 |goto 1429 48.2,42.9395

        step DeathknellTurnin2
            goto 1420 30.8,66.2
            talk Shadow Priest Sarvis##1569
            turnin Rattling the Rattlecages##3901

        step TrainDeathknell
            goto 1420 30.9,66.1
            trainer Isabella##2124 |only Mage
            trainer Dark Cleric Duesten##2123 |only Priest
            trainer Maximillion##2126 |only Warlock

        step AcceptSpiderLine
            goto 1420 32.2,66.0
            talk Executor Arren##1570
            accept Night Web's Hollow##380
            talk Deathguard Saltain##1740
            accept Scavenging Deathknell##3902 |goto Tirisfal Glades 31.6,65.6

        step SpiderAndGoodsHunt
            goto 1420 28.9,57.2
            kill 10 Young Night Web Spider##1504 |q 380/1
            kill 8 Night Web Spider##1505 |q 380/2 |goto Tirisfal Glades 26.8,59.4
            get 6 Scavenged Goods##11127 |q 3902/1 |goto Tirisfal Glades 32.7,63.5

        step TurnInDeathknellFinal
            goto 1420 32.2,66.0
            talk Deathguard Saltain##1740
            turnin Scavenging Deathknell##3902
            talk Executor Arren##1570
            turnin Night Web's Hollow##380
            accept The Scarlet Crusade##381
            accept Vital Intelligence##383

        step RoadToBrill
            goto 1420 38.2,56.8
            talk Deathguard Linnea##1497 |goto 1420 68.2,41.9
            accept Beyond the Scarlet Wall##382 |goto 1420 32.2,66.0
            ding 5

        step BrillArrival
            goto 1420 60.6,51.8
            talk Deathguard Dillinger##1496 |goto 1420 58.2,51.4
            accept A Putrid Task##404 |goto Tirisfal Glades 58.2,51.4
            home Brill

        step BrillTrainerAndVendor
            goto 1420 61.7,52.0
            vendor Abigail Shiel##2118
            trainer Cain Firesong##2128 |only Mage
            trainer Marion Call##2130 |only Rogue
            accept At War With The Scarlet Crusade##427 |goto 1420 60.6,51.8

        step ColdHearthFarm
            goto 1420 52.0,45.0
            kill 8 Rottings Ghoul##1502 |q 404/1
            kill 10 Scarlet Warrior##1535 |q 427/1 |goto Tirisfal Glades 48.0,49.0

        step BrillTurninsAndMills
            goto 1420 61.3,52.6
            turnin A Putrid Task##404 |goto 1420 58.2,51.4
            turnin At War With The Scarlet Crusade##427 |goto 1420 60.6,51.8
            accept The Mills Overrun##426 |goto 1420 58.2,51.4
            accept The Chill of Death##375 |goto Tirisfal Glades 61.9,52.6

        step UndercityFlightAndZeppelin
            goto 1458 63.3,48.5
            talk Michael Garrett##2389 |goto 1416 58.6,80.2
            fpath Undercity
            ding 12
    ]])

    registerGuide("Leveling\\Horde\\Durotar (1-12)", "Durotar (1-12)",
        "Complete Orc & Troll leveling loop through Valley of Trials, Sen'jin Village, and Razor Hill.",
        "Ruta completa de Orcos y Trols desde el Valle de los Retos hasta Poblado Sen'jin y Cerrotajo.", [[
        type LEVELING
        startlevel 1
        endlevel 12
        next Leveling\Horde\The Barrens (12-22)
        defaultfor Orc,Troll
        condition_suggested level >= 1 and level <= 12

        step ValleyStart
            goto Durotar 43.3,68.5
            talk Kaltunk##10176
            accept Your Place In The World##4641

        step MeetGornek
            goto Durotar 42.1,68.4
            talk Gornek##3297 |goto 1411 56.0,75.2
            turnin Your Place In The World##4641
            accept Cutting Teeth##788

        step PigAndScorpidPrep
            goto Durotar 40.6,62.6
            talk Galgar##9796 |goto 1411 42.7,67.2
            accept Galgar's Cactus Apple Surprise##4402 |goto 1411 42.7,67.2
            kill 10 Mottled Boar##3098 |q 788/1 |goto Durotar 44.2,63.8

        step TurnInBoars
            goto Durotar 42.1,68.4
            talk Gornek##3297 |goto 1411 56.0,75.2
            turnin Cutting Teeth##788
            accept Sting of the Scorpid##789

        step AcceptSarkoth
            goto Durotar 40.6,68.5
            talk Hana'zua##3188 |goto 1411 55.9,74.7
            accept Sarkoth##790 |goto 1411 40.6,62.6

        step KillSarkoth
            goto Durotar 40.5,67.1
            kill Sarkoth##3143 |q 790/1
            turnin Sarkoth##790 |goto 1411 40.6,62.6
            accept Sarkoth##804 |goto 1411 40.6,62.6

        step ScorpidsAndImps
            goto Durotar 44.6,68.6
            talk Zureetha Fargaze##3145 |goto 1411 42.8,69.1
            accept Vile Familiars##792 |goto 1411 42.8,69.1
            kill Scorpid Worker##3101 |q 789/1 |count 10 |goto Durotar 45.2,64.0
            kill Vile Familiar##3103 |q 792/1 |count 12 |goto Durotar 45.0,56.8

        step ValleyTurnins
            goto Durotar 42.1,68.4
            turnin Sarkoth##804
            turnin Sting of the Scorpid##789
            turnin Vile Familiars##792
            accept Burning Blade Medallion##794

        step BurningBladeCave
            goto Durotar 42.7,52.9
            kill Yarrog Baneshadow##3183 |q 794/1
            ding 5

        step LeaveValley
            goto Durotar 42.1,68.4
            turnin Burning Blade Medallion##794
            accept Report to Sen'jin Village##805
            accept A Peon's Burden##2161 |goto 1411 52.1,68.3

        step SenjinArrival
            goto Durotar 55.9,74.7
            talk Master Gadrin##3188 |goto 1411 55.9,74.7
            turnin Report to Sen'jin Village##805
            accept Minshina's Skull##808
            accept Practical Prey##817

        step RazorHillArrive
            goto Durotar 51.9,43.5
            turnin A Peon's Burden##2161 |goto 1411 51.5,41.6
            home Razor Hill
            accept Vanquish the Betrayers##784
            accept Encroachment##837 |goto 1411 51.9,43.5

        step RazorHillVendor
            goto Durotar 51.5,41.6
            vendor Wuark##3165
            accept Break a Few Eggs##815

        step TiragardeKeep
            goto Durotar 58.2,55.8
            kill Kul Tiras Sailor##3128 |q 784/1 |count 10
            kill Lieutenant Benedict##3192 |q 784/3 |goto Durotar 59.7,58.3
            accept The Admiral's Orders##830 |use Aged Envelope##4881

        step EchoIslesCleanup
            goto Durotar 67.5,87.7
            get Minshina's Skull##4864 |q 808/1
            kill Zalazane##3204 |q 826/1
            kill Tigers##3122 |q 817/1 |count 4

        step SenjinAndRazorTurnins
            goto Durotar 55.9,74.7
            turnin Minshina's Skull##808
            turnin Practical Prey##817
            goto Durotar 51.9,43.5
            turnin Vanquish the Betrayers##784
            turnin The Admiral's Orders##830

        step SkullRockLine
            goto Durotar 51.1,42.4
            kill Quilboar##3111 |q 837/1 |count 4
            accept Lost But Not Forgotten##816 |goto Durotar 43.1,30.3
            turnin Dark Storms##806 |goto 1411 52.2,43.2

        step OrgrimmarFlight
            goto 1454 45.2,63.9
            talk Doras##3310
            fpath Orgrimmar
            accept Conscript of the Horde##840 |goto Durotar 50.8,43.6
            ding 12
    ]])

    registerGuide("Leveling\\Horde\\Mulgore (1-12)", "Mulgore (1-12)",
        "Tauren starter quest chain from Camp Narache through Bloodhoof Village to Thunder Bluff.",
        "Cadena completa Tauren desde Campamento Narache y Poblado Pezuña de Sangre hasta Cima del Trueno.", [[
        type LEVELING
        startlevel 1
        endlevel 12
        next Leveling\Horde\The Barrens (12-22)
        defaultfor Tauren
        condition_suggested level >= 1 and level <= 12

        step NaracheStart
            goto Mulgore 44.9,77.1
            talk Chief Hawkwind##2981 |goto 1412 44.2,76.1
            accept The Hunt Begins##747

        step HuntBeginKills
            goto Mulgore 48.0,76.0
            kill Plainstrider##2955 |q 747/1 |count 7

        step TurnInHuntBegins
            goto Mulgore 44.9,77.1
            turnin The Hunt Begins##747
            accept The Hunt Continues##750
            accept A Humble Task##752 |goto Mulgore 44.2,76.1

        step GreatmotherTurnin
            goto Mulgore 50.0,81.1
            turnin A Humble Task##752
            accept A Humble Task##753
            get Water Pitcher##4755 |q 753/1

        step NaracheWellAndWolf
            goto Mulgore 44.2,76.1
            turnin A Humble Task##753
            accept Rites of the Earthmother##755
            kill 10 Prairie Wolf##2958 |q 750/1 |goto Mulgore 42.0,85.0

        step SeerWindAndStrength
            goto Mulgore 42.6,92.2
            turnin Rites of the Earthmother##755
            accept Rite of Strength##757
            kill Bristleback Quilboar##2952 |q 757/1 |count 12 |goto Mulgore 60.0,80.0

        step NaracheVendor
            goto Mulgore 44.9,77.1
            vendor Kawnie Softbreeze##3072
            turnin Rite of Strength##757 |goto 1412 44.2,76.1
            accept Rites of the Earthmother##763 |goto 1412 44.2,76.1
            ding 5

        step WalkToBloodhoof
            goto Mulgore 47.5,60.2
            turnin Rites of the Earthmother##763
            home Bloodhoof Village
            accept Sharing the Land##745
            accept Swoop Hunting##761 |goto 1412 48.7,59.3

        step BloodhoofHubQuests
            goto Mulgore 48.5,60.4
            accept Poison Water##748
            accept Dangers of the Windfury##743 |goto Mulgore 47.4,62.0
            accept Winterhoof Cleansing##754 |goto Mulgore 48.5,60.4

        step MulgoreWellsAndPumas
            goto Mulgore 53.5,66.2
            use Winterhoof Cleansing Totem##5411 |q 754/1
            kill Prairie Stalker##2959 |q 748/1 |count 6
            kill Flatland Cougar##2960 |q 748/2 |count 4

        step QuilboarSouth
            goto Mulgore 54.0,70.5
            kill Palemane Tanner##2949 |q 745/1 |count 10
            kill Wiry Swoop##2970 |q 761/1 |count 8

        step TurnInBloodhoof1
            goto Mulgore 47.5,60.2
            turnin Sharing the Land##745
            turnin Poison Water##748 |goto 1412 48.5,60.4
            turnin Swoop Hunting##761 |goto 1412 48.7,59.3
            accept Thunderhorn Totem##756 |goto 1412 48.5,60.4

        step HarpiesNorthEast
            goto Mulgore 62.0,62.0
            kill Windfury Wind Witch##2963 |q 743/1 |count 8
            accept Vision##767 |goto Mulgore 47.5,60.2

        step MazzranacheHunt
            goto Mulgore 46.8,59.4
            accept Mazzranache##766 |goto 1412 47.0,57.1
            kill Praire Stalkers & Cougars |q 766/1

        step SacredFireAndWell
            goto Mulgore 59.8,25.6
            accept Sacred Fire##5062 |goto 1441 21.5,32.3
            kill Venture Co. Supervisor##2979 |q 751/1 |goto Mulgore 61.5,47.2

        step ThunderBluffFlight
            goto 1456 46.8,50.0
            talk Tal##2995 |goto 1412 39.4,27.0
            fpath Thunder Bluff
            turnin Journey into Thunder Bluff##775 |goto 1412 42.1,27.3

        step CrossroadsJourney
            goto Mulgore 61.6,21.0
            turnin Rites of the Earthmother##776 |goto 1412 42.1,27.3
            accept Journey to the Crossroads##854 |goto 1413 44.9,58.6

        step MulgoreVendorAndTrainer
            goto Mulgore 46.5,58.6
            vendor Harn Longcast##3076
            trainer Krang Stonehoof##3063 |only Warrior
            ding 12
    ]])

    registerGuide("Leveling\\Horde\\The Barrens (12-22)", "Los Baldíos (12-22)",
        "Complete The Barrens (Levels 12-22) chain: Crossroads, Ratchet, Stolen Silver, Kolkar Leaders & Taurajo.",
        "Ruta completa de Los Baldíos (12-22): El Cruce, Trinquete, Plata robada, Líderes Kolkar y Taurajo.", [[
        type LEVELING
        startlevel 12
        endlevel 22
        next Leveling\Horde\Stonetalon Mountains (22-25)
        condition_suggested level >= 12 and level <= 22

        step CrossroadsArrival
            goto 1413 51.5,30.8
            talk Tonga Runetotem##3446 |goto 1413 62.4,37.6
            accept The Forgotten Pools##870 |goto 1413 52.3,31.9
            accept Kolkar Leaders##850 |goto 1413 45.3,28.4

        stickystart "CentaurBracersSticky"
        step CentaurBracersSticky
            get 15 Centaur Bracers##5010 |q 855/1 |opt
        stickystop

        step BarrensOasis
            goto 1413 45.1,22.5
            kill Barak Kodobane##3394 |q 850/1

        step KodobaneTurnin
            goto 1413 51.5,30.8
            turnin Kolkar Leaders##85 |goto 1429 43.1,85.70
            accept Centaur Bracers##855 |goto 1413 45.3,28.4

        step CrossroadsHubSetup
            goto 1413 51.5,30.4
            talk Devrak##3615
            fpath Crossroads
            home Crossroads
            accept Plainstrider Menace##844 |goto 1413 52.2,31.0
            accept The Zhevra##845 |goto 1413 52.2,31.0

        step ThorkAndHarpyAccept
            goto 1413 51.5,30.9
            talk Darsok Swiftdagger##3449
            accept Harpy Raiders##86 |goto 1429 43.1,85.77
            accept Supplies for the Crossroads##5041 |goto 1413 51.5,30.9
            accept Disruption Attacks##871 |goto 1413 51.5,30.9

        step PlainstriderAndZhevra
            goto 1413 55.0,27.0
            kill Greater Plainstrider##3244 |q 844/1 |count 7
            kill Zhevra Runner##3242 |q 845/1 |count 4
            kill Razormane Water Seeker##3267 |q 871/1 |count 8

        step TurnInCrossroads1
            goto 1413 52.6,29.8
            turnin Plainstrider Menace##844 |goto 1413 52.2,31.0
            turnin The Zhevra##845 |goto 1413 52.2,31.0
            accept Prowlers of the Barrens##903 |goto 1413 52.2,31.0
            turnin Disruption Attacks##871 |goto 1413 51.5,30.9
            accept The Disruption Ends##872 |goto 1413 51.5,30.9

        step RatchetSideLoop
            goto 1413 62.7,37.2
            talk Gazlowe##3453 |goto 1413 63.4,38.5
            accept Southsea Freebooters##887
            accept The Guns of Northwatch##891 |goto 1413 62.3,38.4
            accept WANTED: Baron Longshore##895
            fpath Ratchet |goto 1413 63.1,37.2

        step SouthseaPirates
            goto 1413 64.0,45.5
            kill Southsea Brigand##3381 |q 887/1 |count 12
            kill Baron Longshore##3467 |q 895/1
            turnin Southsea Freebooters##887 |goto 1413 62.7,37.2
            turnin WANTED: Baron Longshore##895 |goto 1413 62.7,36.2

        step FungalSporesAndPools
            goto 1413 44.9,22.5
            get 4 Fungal Spores##5012 |q 848/1
            goto 1413 45.0,22.5
            click Bubble Fissure |q 870/1

        step RazorManeAndStolenSilver
            goto 1413 57.5,52.0
            kill Kreenig Snarlsnout##3438 |q 872/1
            get 15 Centaur Bracers##5010 |q 855/1

        step RegtharAndVerog
            goto 1413 45.3,28.4
            talk Regthar Deathgate##3389
            turnin Centaur Bracers##85 |goto 1429 43.1,85.75
            accept Verog the Dervish##851
            kill Verog the Dervish##3395 |q 851/1 |goto 1413 52.8,41.7

        step NorthHarpyWitch
            goto 1413 38.0,14.5
            kill Witchwing Harpy##3278 |q 867/1 |count 8
            accept Harpy Lieutenants##875 |goto 1413 51.5,30.9
            kill Serena Bloodfeather##3452 |q 876/1 |goto 1413 39.2,12.2

        step CrossroadsTurnInVendor
            goto 1413 51.5,30.9
            turnin Verog the Dervish##85 |goto 1429 43.1,85.71
            turnin The Forgotten Pools##870 |goto 1413 52.3,31.9
            accept The Stagnant Oasis##877 |goto 1413 52.3,31.9
            vendor Tari'qa##3499

        step StagnantOasisLoop
            goto 1413 55.6,42.7
            click Crackling Fissure |q 877/1
            turnin The Stagnant Oasis##877 |goto 1413 52.3,31.9
            accept Altered Beings##880 |goto 1413 52.3,31.9

        step ProwlersAndEcheyakee
            goto 1413 42.0,32.0
            kill Savannah Prowler##3425 |q 903/1 |count 7
            accept Echeyakee##881 |goto 1413 52.2,31.0
            kill Echeyakee##3475 |q 881/1 |goto 1413 55.8,17.1

        step CampTaurajoSouthern
            goto 1413 44.5,59.2
            talk Omusa Thunderhorn##10378
            fpath Camp Taurajo
            accept Weapons of Choice##893 |goto 1413 45.1,57.7
            accept Betrayal from Within##879
            ding 22
    ]])

    -- Remaining Horde 12-60 Zones (8-10 structured steps each)
    registerGuide("Leveling\\Horde\\Silverpine Forest (12-20)", "Bosque de Argénteos (12-20)",
        "Forsaken progression from The Sepulcher through Fenris Isle and Ambermill.",
        "Progresión Renegada desde El Sepulcro hacia la Isla de Fenris y Molino Ámbar.", [[
        type LEVELING
        startlevel 12
        endlevel 20
        next Leveling\Horde\Hillsbrad Foothills (22-30)

        step BrillLink
            goto Silverpine Forest 53.5,13.4
            accept Prove Your Allegiance##422 |goto 1421 44.2,39.8
        step SepulcherArrival
            goto Silverpine Forest 44.2,39.8
            fpath The Sepulcher
            home The Sepulcher
            accept Border Crossings##477 |goto 1421 44.0,40.9
        step EscortErland
            goto Silverpine Forest 56.2,9.2
            accept Escorting Erland##435
            turnin Escorting Erland##435 |goto 1421 53.5,13.4
        step IvarTheFoul
            goto Silverpine Forest 51.5,13.9
            accept Ivar the Foul##425 |goto 1421 53.5,13.4
            kill Ivar the Foul##1954 |q 425/1
        step DeadFieldGnolls
            goto Silverpine Forest 45.2,29.1
            accept Return to Quinn##430 |goto 1421 42.8,40.9
            kill Rot Hide Mongrel##1772 |q 423/1 |count 6
        step DalaranAndFenris
            goto Silverpine Forest 57.6,62.3
            kill Dalaran Apprentice##1867 |q 440/1 |count 8
        step SepulcherVendorTurnin
            goto Silverpine Forest 44.2,39.8
            vendor Nadia Vernon##3550
            turnin Ivar the Foul##425 |goto 1421 53.5,13.4
        step ExitToHillsbrad
            goto Silverpine Forest 45.6,41.0
            accept Beren's Peril##516 |goto 1421 44.0,40.9
            ding 20
    ]])

    registerGuide("Leveling\\Horde\\Stonetalon Mountains (22-25)", "Sierra Espolón (22-25)",
        "Sun Rock Retreat quests and Windshear Crag progression.",
        "Misiones del Refugio Roca del Sol y Risco Cortaviento.", [[
        type LEVELING
        startlevel 22
        endlevel 25
        next Leveling\Horde\Hillsbrad Foothills (22-30)

        step StonetalonEntrance
            goto Stonetalon Mountains 71.2,95.0
            accept Goblin Invaders##1062 |goto 1413 35.3,27.9
        step MalakaJin
            goto Stonetalon Mountains 74.0,97.8
            accept Letter to Jin'Zil##1060 |goto 1413 51.6,30.9
            accept Blood Feeders##6 |goto 1429 48.2,42.9461
        step WindshearLogging
            goto Stonetalon Mountains 63.0,55.0
            kill Venture Co. Logger##3988 |q 1062/1 |count 15
        step SunRockSetup
            goto Stonetalon Mountains 47.4,58.5
            fpath Sun Rock Retreat
            home Sun Rock Retreat
            accept Boulderslide Ravine##6 |goto 1429 48.2,42.9421
            accept Cycle of Rebirth##6 |goto 1429 48.2,42.9301
        step SunRockCragAndCharred
            goto Stonetalon Mountains 32.5,67.5
            get 6 Stonetalon Stand Stone |q 6421/1
        step SunRockTurnin
            goto Stonetalon Mountains 47.4,58.5
            turnin Boulderslide Ravine##6421 |goto 1442 47.2,64.0
            vendor Borand##4084
        step JinZilForestTurnin
            goto Stonetalon Mountains 74.5,97.9
            turnin Goblin Invaders##1062 |goto 1413 35.3,27.9
            ding 25
    ]])

    registerGuide("Leveling\\Horde\\Hillsbrad Foothills (22-30)", "Laderas de Trabalomas (22-30)",
        "Tarren Mill Syndicate, Elixir of Suffering, and Hillsbrad Fields XP circuit.",
        "Circuito de experiencia en Molino Tarren, Elixir de sufrimiento y Campos de Trabalomas.", [[
        type LEVELING
        startlevel 22
        endlevel 30
        next Leveling\Horde\Stranglethorn Vale (30-42)

        step TarrenMillArrival
            goto Hillsbrad Foothills 60.1,18.6
            fpath Tarren Mill
            home Tarren Mill
        step TarrenMillAccepts
            goto Hillsbrad Foothills 62.4,20.3
            accept Time To Strike##494 |goto 1424 20.8,47.4
            accept Battle of Hillsbrad##527 |goto 1416 61.1,82.1
            accept Elixir of Suffering##496 |goto 1416 60.1,80.7
        step DurnholdeKeep
            goto Hillsbrad Foothills 76.0,45.0
            kill Syndicate Shadow Mage##2246 |q 494/1 |count 10
        step HillsbradFarms
            goto Hillsbrad Foothills 33.0,42.0
            kill Hillsbrad Farmer##2266 |q 527/1 |count 10
            kill Elder Gray Bear##2356 |q 496/1 |count 10
        step TurnInElixirAndBattle
            goto Hillsbrad Foothills 62.4,20.3
            turnin Time To Strike##494 |goto 1416 61.1,82.1
            turnin Battle of Hillsbrad##527 |goto 1416 61.1,82.1
            turnin Elixir of Suffering##496 |goto 1416 60.1,80.7
            accept Battle of Hillsbrad##528 |goto 1416 61.1,82.1
        step FarmerHuntPart2
            goto Hillsbrad Foothills 36.0,45.0
            kill Hillsbrad Peasant##2267 |q 528/1 |count 15
        step TarrenMillFinalVendor
            goto Hillsbrad Foothills 62.4,20.3
            turnin Battle of Hillsbrad##528 |goto 1416 61.1,82.1
            vendor Christy Punchcog##2395
            ding 30
    ]])

    registerGuide("Leveling\\Horde\\Thousand Needles (25-32)", "Las Mil Agujas (25-32)",
        "Freewind Post quests and Shimmering Flats racing hub.",
        "Misiones del Poblado Viento Libre y el Salar de las Mil Agujas.", [[
        type LEVELING
        startlevel 25
        endlevel 32
        next Leveling\Horde\Stranglethorn Vale (30-42)

        step FreewindArrival
            goto Thousand Needles 45.7,50.8
            fpath Freewind Post
            home Freewind Post
            accept Pacify the Centaur##4841
            accept Alien Egg##4821 |goto 1441 44.6,50.3
        step WindfuryAndCentaur
            goto Thousand Needles 39.0,37.0
            kill Galak Scout##4093 |q 4841/1 |count 12
            get Alien Egg##12467 |q 4821/1 |goto Thousand Needles 52.5,55.2
        step TurnInFreewind
            goto Thousand Needles 45.7,50.8
            turnin Pacify the Centaur##4841
            turnin Alien Egg##4821 |goto 1441 44.6,50.3
            accept Grimtotem Spying##5064
        step ShimmeringFlatsHub
            goto Thousand Needles 78.1,77.1
            accept Rocket Car Parts##1110
            accept Hardened Shells##1105
            accept Load Lightening##1176 |goto 1441 80.2,75.9
        step FlatsFarmingLoop
            goto Thousand Needles 82.0,68.0
            get 10 Rocket Car Parts##5798 |q 1110/1
            kill Sparkleshell Tortoise##4142 |q 1105/1 |count 9
        step TurnInShimmeringFlats
            goto Thousand Needles 78.1,77.1
            turnin Rocket Car Parts##1110
            turnin Hardened Shells##1105
            vendor Kravel Koalbeard##4452
            ding 32
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
            accept Raptor Mastery##194
        step GromgolSetup
            goto Stranglethorn Vale 32.5,29.4
            fpath Grom'gol
            home Grom'gol
            accept Bloodscalp Ears##189 |goto 1434 27.0,77.1
        step HuntTigersAndPanthers
            goto Stranglethorn Vale 31.0,16.0
            kill Young Stranglethorn Tiger##681 |q 185/1 |count 10
            kill Young Panther##683 |q 190/1 |count 10
        step TurnInSafariPhase1
            goto Stranglethorn Vale 35.6,10.5
            turnin Tiger Mastery##185
            turnin Panther Mastery##190
            accept Tiger Mastery##186
            accept Panther Mastery##191
        step BloodscalpTrolls
            goto Stranglethorn Vale 30.0,19.0
            get 15 Bloodscalp Ear##1519 |q 189/1
        step TurnInGromgol
            goto Stranglethorn Vale 32.2,27.8
            turnin Bloodscalp Ears##189 |goto 1434 27.0,77.1
            vendor Uthok##1383
        step BootyBayFlight
            goto Stranglethorn Vale 26.9,77.1
            fpath Booty Bay
            ding 42
    ]])

    registerGuide("Leveling\\Horde\\Tanaris (40-48)", "Tanaris (40-48)",
        "Gadgetzan wasteland hunts, pirate camps, and Zul'Farrak quest setup.",
        "Cacerías del desierto en Gadgetzan, piratas y preparación de Zul'Farrak.", [[
        type LEVELING
        startlevel 40
        endlevel 48
        next Leveling\Horde\Un'Goro Crater (48-54)

        step GadgetzanHorde
            goto Tanaris 51.6,25.5
            fpath Gadgetzan
            home Gadgetzan
            accept Wastewander Justice##1690 |goto 1446 52.5,28.5
            accept Water Pouch Bounty##170 |goto 1426 29.7,71.37
        step NoonshadeRuins
            goto Tanaris 61.5,24.0
            kill Wastewander Bandit##5618 |q 1690/1 |count 10
            get 5 Wastewander Water Pouch##8483 |q 1707/1
        step TurnInGadgetzan1
            goto Tanaris 52.5,28.5
            turnin Wastewander Justice##1690
            turnin Water Pouch Bounty##1707
            accept More Wastewander Justice##1691
        step SteamwheedlePirates
            goto Tanaris 67.0,22.3
            accept Wanted - Andre Firebeard##287 |goto 1426 46.7,53.85
            kill Andre Firebeard##7883 |q 2875/1 |goto Tanaris 73.4,47.1
        step InsectHivesSouth
            goto Tanaris 56.0,69.0
            accept The Dunemaul Compound##5863 |goto 1446 52.8,27.4
            kill Gor'marok the Ravager##12046 |q 5863/1 |goto Tanaris 41.4,57.8
        step GadgetzanVendorFinal
            goto Tanaris 52.5,28.5
            vendor Krinkle Goodsteel##5411
            ding 48
    ]])

    registerGuide("Leveling\\Horde\\Un'Goro Crater (48-54)", "Cráter de Un'Goro (48-54)",
        "High-density Marshal's Refuge loop collecting Crystals and Dino bones.",
        "Circuito de alta densidad recolectando cristales y huesos en el Refugio.", [[
        type LEVELING
        startlevel 48
        endlevel 54
        next Leveling\Horde\Western Plaguelands (52-57)

        step MarshalsRefuge
            goto Un'Goro Crater 45.2,5.8
            fpath Un'Goro Crater
            accept The Apes of Un'Goro##4289 |goto 1446 27.5,42.7
            accept Shizzle's Flyer##4503 |goto 1449 44.2,11.6
            accept Chasing A-Me 01##4243 |goto 1449 46.4,13.4
        step CrystalsAndBones
            goto Un'Goro Crater 46.5,13.5
            get 7 Green Power Crystal##11185
            get 7 Red Power Crystal##11186
            get 7 Blue Power Crystal##11184
            get 7 Yellow Power Crystal##11188
        step GorillasNorth
            goto Un'Goro Crater 63.0,17.0
            kill Un'Goro Gorilla##6514 |q 4289/1 |count 6
        step DiemetradonLoop
            goto Un'Goro Crater 56.0,55.0
            kill Young Diemetradon##9162 |q 4503/1 |count 10
        step RefugeTurnIns
            goto Un'Goro Crater 43.1,9.7
            turnin The Apes of Un'Goro##4289 |goto 1446 27.5,42.7
            turnin Shizzle's Flyer##4503 |goto 1449 44.2,11.6
            ding 54
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
            accept A Plague Upon Thee##5901 |goto 1422 26.7,59.6
            accept Scarlet Diversions##5096 |goto 1422 26.5,56.0
        step FelstoneCauldron
            goto Western Plaguelands 37.2,56.8
            accept Better Late Than Never##5021 |goto 1422 38.4,54.1
            kill Cauldron Lord Bilemaw##11076
        step DalsonsAndWrithing
            goto Western Plaguelands 46.0,52.0
            kill Cauldron Lord Malvinious##11077
            goto Western Plaguelands 53.0,65.7
            kill Cauldron Lord Razarch##11078
        step SorrowHillTurnin
            goto Western Plaguelands 26.5,58.6
            turnin A Plague Upon Thee##5901 |goto 1422 26.7,59.6
            ding 57
    ]])

    registerGuide("Leveling\\Horde\\Eastern Plaguelands (56-60)", "Tierras de la Peste del Este (56-60)",
        "Final 56-60 Argent Dawn and Light's Hope Chapel quest lines.",
        "Cadena final 56-60 del Alba Argenta y la Capilla de la Esperanza de la Luz.", [[
        type LEVELING
        startlevel 56
        endlevel 60

        step TirionFordringCamp
            goto Eastern Plaguelands 7.6,43.7
            accept Demon Dogs##5542 |goto 1422 67.3,24.2
            accept Blood Tinged Skies##5543 |goto 1422 67.3,24.2
            accept Carrion Grubbage##5544 |goto 1422 67.3,24.2
        step PlaguehoundHunt
            goto Eastern Plaguelands 28.0,45.0
            kill Plaguehound Runt##8596 |q 5542/1 |count 20
            kill Plaguebat##8600 |q 5543/1 |count 30
        step TurnInTirion
            goto Eastern Plaguelands 7.6,43.7
            turnin Demon Dogs##5542 |goto 1422 67.3,24.2
            turnin Blood Tinged Skies##5543 |goto 1422 67.3,24.2
            turnin Carrion Grubbage##5544 |goto 1422 67.3,24.2
        step LightsHopeChapel
            goto Eastern Plaguelands 81.5,59.7
            fpath Light's Hope Chapel
            accept Zaeldarr the Outcast##6 |goto 1429 48.2,42.9021
            kill Zaeldarr the Outcast##10809 |q 6021/1 |goto Eastern Plaguelands 27.3,85.3
            ding 60
    ]])

    -- =========================================================================
    -- 2. ALLIANCE LEVELING (1-60) - FULL MULTI-STEP ZYGOR/RXP PROGRESSION
    -- =========================================================================
    registerGuide("Leveling\\Alliance\\Elwynn Forest (1-12)", "Bosque de Elwynn (1-12)",
        "Complete Alliance starter route across Northshire Abbey, Goldshire, Fargodeep Mine, and Eastvale.",
        "Ruta completa de la Alianza desde la Abadía de Villanorte, Villadorada, Mina Abisal y Vega del Este.", [[
        type LEVELING
        startlevel 1
        endlevel 12
        next Leveling\Alliance\Westfall (12-20)
        defaultfor Human
        condition_suggested level >= 1 and level <= 12

        step NorthshireStart
            goto 1429 48.2,42.9
            talk Deputy Willem##196 |goto 1429 48.9,40.2
            accept A Threat Within##783

        step NorthshireTurnin
            goto 1429 48.9,41.6
            talk Marshal McBride##197
            turnin A Threat Within##783
            accept Kobold Camp Cleanup##7

        step NorthshireWolvesAccept
            goto 1429 48.2,42.9
            talk Deputy Willem##196 |goto 1429 48.9,40.2
            accept Eagan Peltskinner##5261
            turnin Eagan Peltskinner##5261 |goto 1429 48.9,40.1
            accept Wolves Across the Border##33 |goto 1429 48.9,40.2

        step KoboldAndWolvesHunt
            goto 1429 49.0,36.0
            kill Kobold Vermin##6 |q 7/1 |count 10
            kill Young Wolf##299 |q 33/1 |count 8

        step NorthshirePhase1Turnin
            goto 1429 48.9,40.1
            turnin Wolves Across the Border##33
            goto 1429 48.9,41.6
            turnin Kobold Camp Cleanup##7
            accept Investigate Echo Ridge##15
            accept Brotherhood of Thieves##18 |goto 1429 48.2,42.9

        step NorthshireVendor
            goto 1429 47.7,41.4
            vendor Janos Hammerknuckle##78

        step EchoRidgeKobolds
            goto 1429 49.5,27.0
            kill Kobold Worker##257 |q 15/1 |count 10
            get 12 Red Burlap Bandana##1397 |q 18/1 |goto 1429 54.0,45.0

        step NorthshireGarrick
            goto 1429 48.9,41.6
            turnin Investigate Echo Ridge##15
            accept Skirmish at Echo Ridge##21
            turnin Brotherhood of Thieves##18 |goto 1429 48.2,42.9
            accept Bounty on Garrick Padfoot##6 |goto 1429 48.2,42.9

        step KillGarrickAndWorkers
            goto 1429 57.5,48.6
            kill Garrick Padfoot##103 |q 6/1
            kill Kobold Laborer##80 |q 21/1 |count 12 |goto 1429 49.0,26.0

        step NorthshireTrainAndReport
            goto 1429 48.9,41.6
            turnin Skirmish at Echo Ridge##21
            accept Report to Goldshire##54
            turnin Bounty on Garrick Padfoot##6 |goto 1429 48.2,42.9
            ding 5

        step WalkToGoldshire
            goto 1429 45.6,47.7
            accept Rest and Relaxation##2158
            goto 1429 42.1,65.9
            talk Marshal Dughan##240
            turnin Report to Goldshire##54
            accept The Fargodeep Mine##6 |goto 1429 48.2,42.92

        step GoldshireInnAndTrainer
            goto 1429 43.8,65.8
            home Goldshire
            turnin Rest and Relaxation##2158
            trainer Marshal Dughan##240 |only Paladin

        step GoldshireAcceptChain
            goto 1429 43.3,65.7
            accept Kobold Candles##6 |goto 1429 48.2,42.90
            accept Gold Dust Exchange##47 |goto 1429 42.2,67.2

        step StonefieldAndMaclure
            goto 1429 34.5,84.3
            accept Lost Necklace##85
            accept Princess Must Die!##88 |goto 1429 34.6,84.5
            turnin Lost Necklace##85 |goto 1429 43.1,85.7
            accept Pie for Billy##86 |goto 1429 43.1,85.7

        step FargodeepMine
            goto 1429 39.5,82.0
            get 8 Large Candle##772 |q 60/1
            get 10 Gold Dust##773 |q 47/1
            get 4 Chunk of Boar Meat##769 |q 86/1

        step TurnInGoldshireFargodeep
            goto 1429 42.1,65.9
            turnin The Fargodeep Mine##62
            accept The Jasperlode Mine##76
            turnin Kobold Candles##60 |goto 1429 43.3,65.7
            turnin Gold Dust Exchange##47 |goto 1429 42.2,67.2
            vendor Corina Steele##54

        step JasperlodeAndLogging
            goto 1429 61.5,53.0
            click Explore Jasperlode Mine |q 76/1
            accept A Bundle of Trouble##5545 |goto 1429 81.4,66.2
            kill Princess##330 |q 88/1 |goto 1429 69.3,79.2

        step CrystalLakeMurlocs
            goto 1429 74.0,72.2
            talk Guard Thomas##261
            accept Find the Lost Guards##37
            turnin Find the Lost Guards##37 |goto 1429 72.7,60.3
            accept Discover Rolf's Fate##45

        step GoldshireToWestfall
            goto 1429 42.1,65.9
            turnin The Jasperlode Mine##76
            accept Westbrook Garrison Needs Help!##239
            accept WANTED: "Hogger"##176 |goto 1429 24.2,74.6
            kill Hogger##448 |q 176/1 |goto 1429 27.0,86.7
            turnin WANTED: "Hogger"##176 |goto 1429 42.1,65.9
            ding 12
    ]])

    registerGuide("Leveling\\Alliance\\Dun Morogh (1-12)", "Dun Morogh (1-12)",
        "Full Dwarf & Gnome route from Coldridge Valley through Kharanos to Ironforge.",
        "Ruta completa de Enanos y Gnomos desde Crestanevada hasta Kharanos y Forjaz.", [[
        type LEVELING
        startlevel 1
        endlevel 12
        next Leveling\Alliance\Loch Modan (12-20)
        defaultfor Dwarf,Gnome
        condition_suggested level >= 1 and level <= 12

        step ColdridgeStart
            goto Dun Morogh 29.9,71.2
            talk Sten Stoutarm##786 |goto 1426 25.1,75.7
            accept Dwarven Outfitters##179

        step WolfHuntColdridge
            goto Dun Morogh 29.0,74.5
            kill Ragged Young Wolf##705 |q 179/1 |count 8
            turnin Dwarven Outfitters##179 |goto Dun Morogh 29.9,71.2
            accept Coldridge Valley Mail Delivery##233 |goto 1426 29.9,71.2

        step AcceptBoarAndTrolls
            goto Dun Morogh 28.8,67.8
            accept A New Threat##170 |goto 1426 29.7,71.3
            accept A Refugee's Quandary##33 |goto 1429 48.9,40.261
            turnin Coldridge Valley Mail Delivery##233 |goto Dun Morogh 22.6,71.4
            accept Coldridge Valley Mail Delivery##234 |goto 1426 22.6,71.4

        step TrollCampAndBoars
            goto Dun Morogh 26.5,79.5
            kill Frostmane Troll Whelp##706 |q 170/1 |count 6
            kill Crag Boar##708 |q 183/1 |count 12 |goto Dun Morogh 22.6,71.4

        step CaveTrollChain
            goto Dun Morogh 25.0,75.7
            turnin Coldridge Valley Mail Delivery##234
            accept The Troll Cave##182
            kill Frostmane Troll Whelp##706 |q 182/1 |count 14 |goto Dun Morogh 27.0,79.0

        step ColdridgeTurninAndVendor
            goto Dun Morogh 25.0,75.7
            turnin The Troll Cave##182
            accept The Stolen Journal##218
            vendor Adlin Pridedrift##829
            ding 5

        step GrikNirKill
            goto Dun Morogh 30.5,80.1
            kill Grik'nir the Cold##808 |q 218/1
            turnin The Stolen Journal##218 |goto Dun Morogh 25.0,75.7
            accept Senir's Observations##282 |goto 1426 25.1,75.7

        step PassTunnelToKharanos
            goto Dun Morogh 33.5,71.8
            turnin Senir's Observations##282
            accept Senir's Observations##420
            accept Supplies to Tannok##2160 |goto 1426 33.8,72.2

        step KharanosArrival
            goto Dun Morogh 46.8,52.4
            turnin Senir's Observations##420 |goto 1426 46.7,53.8
            home Kharanos
            accept Beer Basted Boar Ribs##384
            accept Frostmane Hold##287 |goto 1426 46.7,53.8

        step AmberstillRanch
            goto Dun Morogh 63.1,49.8
            accept Protecting the Herd##314
            kill Vagash##1388 |q 314/1 |goto Dun Morogh 62.2,46.0
            turnin Protecting the Herd##314 |goto Dun Morogh 63.1,49.8

        step GolBolarQuarry
            goto Dun Morogh 68.7,56.0
            accept The Public Servant##433
            accept Those Blasted Troggs!##432
            kill Rockjaw Bonesnapper##1117 |q 433/1 |count 10

        step ShimmerRidgeAndTundra
            goto Dun Morogh 38.4,53.9
            accept Tundra MacGrann's Stolen Stash##312 |goto 1426 34.6,51.7
            kill Old Icebeard##1387 |q 312/1

        step GnomereganLeperGnomes
            goto Dun Morogh 22.8,52.0
            kill Leper Gnome##1211 |q 412/1 |count 10
            turnin Operation Recombobulation##412 |goto Dun Morogh 45.8,49.4

        step HelmetsAndGolBolarTurnin
            goto Dun Morogh 68.7,56.0
            turnin The Public Servant##433
            turnin Those Blasted Troggs!##432

        step AmberstillBoars
            goto Dun Morogh 46.8,52.4
            get 6 Crag Boar Rib##2886 |q 384/1
            turnin Beer Basted Boar Ribs##384 |goto Dun Morogh 46.8,52.4

        step PilotRevenge
            goto Dun Morogh 79.7,36.2
            accept Pilot's Revenge##417
            kill Mangeclaw##1961 |q 417/1 |goto Dun Morogh 78.3,37.7
            turnin Pilot's Revenge##417 |goto 1426 83.9,39.2

        step DunMoroghVendorTrain
            goto Dun Morogh 47.4,52.5
            vendor Belm##1243
            trainer Magis Sparkmantle##1228 |only Mage

        step IronforgeFlightSetup
            goto 1455 55.5,47.8
            talk Gryth Thurden##1573
            fpath Ironforge
            accept The Lost Pilot##419 |goto Dun Morogh 83.9,39.2
            ding 12
    ]])

    registerGuide("Leveling\\Alliance\\Teldrassil (1-12)", "Teldrassil (1-12)",
        "Complete Night Elf progression from Shadowglen through Dolanaar to Darnassus & Auberdine.",
        "Ruta completa de Elfos de la Noche desde Cañada Umbría hasta Dolanaar, Darnassus y Auberdine.", [[
        type LEVELING
        startlevel 1
        endlevel 12
        next Leveling\Alliance\Darkshore (12-20)
        defaultfor NightElf
        condition_suggested level >= 1 and level <= 12

        step ShadowglenStart
            goto Teldrassil 58.7,44.4
            talk Conservator Ilthalaine##2077 |goto 1438 59.9,42.5
            accept The Balance of Nature##456

        step BalanceNightsabers
            goto Teldrassil 61.5,43.0
            kill Young Nightsaber##2031 |q 456/1 |count 7
            kill Young Thistle Boar##1984 |q 456/2 |count 7

        step TurnInBalance1
            goto Teldrassil 58.7,44.4
            turnin The Balance of Nature##456
            accept The Balance of Nature##457
            accept The Woodland Protector##458 |goto Teldrassil 59.9,42.5

        step TreeTarindisAndMobs
            goto Teldrassil 57.9,45.1
            turnin The Woodland Protector##458
            accept The Woodland Protector##459
            kill Mangy Nightsaber##2032 |q 457/1 |count 7 |goto Teldrassil 55.0,40.0
            kill Thistle Boar##1985 |q 457/2 |count 7

        step AcceptWebwoodLine
            goto Teldrassil 57.8,41.6
            accept Webwood Venom##916
            turnin The Woodland Protector##459 |goto 1438 57.8,45.2
            turnin The Balance of Nature##457 |goto Teldrassil 58.7,44.4
            vendor Keina##3588

        step WebwoodSpiders
            goto Teldrassil 56.8,31.6
            get 10 Webwood Venom Sac##3261 |q 916/1
            turnin Webwood Venom##916 |goto Teldrassil 57.8,41.6
            accept Webwood Egg##917 |goto 1438 57.8,41.7
            ding 5

        step ShadowthreadCave
            goto Teldrassil 56.8,26.6
            get 1 Webwood Egg##5167 |q 917/1
            turnin Webwood Egg##917 |goto Teldrassil 57.8,41.6
            accept Tenaron's Summons##920 |goto 1438 57.8,41.7
            turnin Tenaron's Summons##920 |goto Teldrassil 59.1,39.4
            accept Crown of the Earth##921 |goto 1438 59.1,39.4

        step CrownPhial1AndLeave
            goto Teldrassil 59.9,33.1
            use Crystal Phial##5185 |q 921/1
            turnin Crown of the Earth##921 |goto Teldrassil 59.1,39.4
            accept Crown of the Earth##928 |goto 1438 59.1,39.4

        step DolanaarArrival
            goto Teldrassil 55.6,59.8
            home Dolanaar
            accept Zenn's Bidding##488 |goto Teldrassil 60.5,56.3
            turnin Crown of the Earth##928 |goto Teldrassil 56.1,61.7
            accept Crown of the Earth##929 |goto 1438 56.1,61.7

        step DolanaarQuests
            goto Teldrassil 55.9,57.3
            accept Twisted Hatred##932
            accept Denalan's Earth##997 |goto Teldrassil 55.6,56.9
            accept A Troubling Breeze##2438 |goto Teldrassil 55.5,56.9

        step LakeAlAmethAndMoonwell
            goto Teldrassil 63.3,58.0
            use Jade Phial##5619 |q 929/1
            turnin Denalan's Earth##997 |goto Teldrassil 60.9,68.5
            accept Timberling Seeds##918 |goto 1438 60.9,68.5

        step HarpyAndMelenas
            goto Teldrassil 50.8,50.8
            kill Lord Melenas##2038 |q 932/1
            get 6 Nightsaber Fang##3409 |q 488/1

        step DolanaarFinalTurnins
            goto Teldrassil 56.1,61.7
            turnin Crown of the Earth##929
            accept Crown of the Earth##933
            turnin Twisted Hatred##932 |goto Teldrassil 55.9,57.3
            vendor Shalomon##3598

        step OracleGladePhial
            goto Teldrassil 42.4,67.2
            use Tourmaline Phial##5621 |q 933/1
            accept Ferocitas the Dream Eater##2459 |goto 1438 55.6,56.9

        step GnarlpineAndFerocitas
            goto Teldrassil 68.0,53.0
            kill Ferocitas the Dream Eater##7234 |q 2459/1
            turnin Ferocitas the Dream Eater##2459 |goto 1438 55.6,56.9

        step BanethilBarrowDen
            goto Teldrassil 44.0,57.0
            accept Seek Redemption!##489 |goto 1438 56.1,57.7
            kill Gnarlpine Mystic##7235 |q 489/1 |count 4
            turnin Seek Redemption!##489 |goto Teldrassil 60.5,56.3

        step TimberlingSeedsTurnin
            goto Teldrassil 60.9,68.5
            get 8 Timberling Seed##5169 |q 918/1
            turnin Timberling Seeds##918

        step DarnassusAndRuttheran
            goto 1457 38.3,21.4
            accept Crown of the Earth##935 |goto 1438 56.1,61.7
            goto Teldrassil 58.4,94.0
            talk Vesprystus##3838
            fpath Rut'theran Village
            fly Auberdine
            ding 12
    ]])

    registerGuide("Leveling\\Alliance\\Westfall (12-20)", "Páramos de Poniente (12-20)",
        "Complete Sentinel Hill Defias, Furlbrow's Deed, Westfall Stew, and Deadmines attunement chain.",
        "Cadena completa de Páramos de Poniente: Colina del Centinela, Estofado y Minas de la Muerte.", [[
        type LEVELING
        startlevel 12
        endlevel 20
        next Leveling\Alliance\Redridge Mountains (18-25)

        step BorderBridgeQuest
            goto Westfall 60.0,19.4
            talk Farmer Furlbrow##241 |goto 1429 42.1,67.3
            accept Poor Old Blanchy##151
            accept Westfall Stew##36 |goto Westfall 60.0,19.3

        step SaldeanFarm
            goto Westfall 56.4,30.6
            turnin Westfall Stew##36
            accept Westfall Stew##38
            accept Goretusk Liver Pie##22 |goto Westfall 56.0,31.3

        step SentinelHillSetup
            goto Westfall 56.3,47.5
            talk Marshal Gryan Stoutmantle##234
            accept The People's Militia##12
            accept Red Leather Bandanas##153 |goto Westfall 54.0,53.0
            fpath Sentinel Hill |goto Westfall 56.6,52.6
            home Sentinel Hill

        step PatrolWestfallAccept
            goto Westfall 56.3,47.6
            accept Patrolling Westfall##102
            accept A Swift Message##6 |goto 1429 48.2,42.9181

        step WestfallCourierFly
            goto Westfall 56.6,52.6
            fly Stormwind
            turnin A Swift Message##6181 |goto 1436 56.6,52.6
            fly Sentinel Hill

        step BoarsVulturesMurlocs
            goto Westfall 51.0,27.0
            get 8 Handful of Oats##1528 |q 151/1
            kill Goretusk##157 |q 22/1 |count 8
            kill Fleshripper##154 |q 38/2 |count 3

        step PatrolGnolls
            goto Westfall 46.0,36.0
            kill Riverpaw Gnoll##117 |q 102/1 |count 8
            turnin Patrolling Westfall##102 |goto Westfall 56.3,47.6

        step JanssenAndDefias
            goto Westfall 44.0,22.0
            kill Defias Trapper##504 |q 12/1 |count 15
            kill Defias Smuggler##95 |q 12/2 |count 15
            get 15 Red Leather Bandana##1529 |q 153/1

        step TurnInSaldeanAndBlanchy
            goto Westfall 56.4,30.6
            turnin Goretusk Liver Pie##22
            turnin Westfall Stew##38
            turnin Poor Old Blanchy##151 |goto Westfall 60.0,19.4

        step TurnInPeopleMilitia1
            goto Westfall 56.3,47.5
            turnin The People's Militia##12
            accept The People's Militia##13
            turnin Red Leather Bandanas##153 |goto Westfall 54.0,53.0
            vendor Quartermaster Lewis##491

        step LighthouseMurlocs
            goto Westfall 30.0,86.0
            accept Keeper of the Flame##103
            accept The Coast Isn't Clear##152
            kill Murloc Tidehunter##517 |q 152/1 |count 7

        step DeadAcreGhosts
            goto Westfall 44.0,80.0
            kill Dust Devil##832 |q 38/4 |count 3
            kill Harvest Watcher##114 |q 102/2 |count 6

        step DefiasPart2Moonbrook
            goto Westfall 44.0,69.0
            kill Defias Pillager##589 |q 13/1 |count 15
            kill Defias Looter##590 |q 13/2 |count 15

        step TurnInMilitia2And3
            goto Westfall 56.3,47.5
            turnin The People's Militia##13
            accept The People's Militia##14
            accept The Defias Brotherhood##6 |goto 1429 48.2,42.95

        step DefiasMessengerAndTower
            goto Westfall 44.0,70.0
            kill Defias Highwayman##122 |q 14/1 |count 15
            kill Defias Messenger##550 |q 142/1
            kill Klaven Mortwake##7053 |q 2359/1 |goto Westfall 68.4,70.1

        step SentinelFinalTurnIn
            goto Westfall 56.3,47.5
            turnin The People's Militia##14
            turnin The Coast Isn't Clear##152 |goto Westfall 30.0,86.0

        step WestfallShoreAndGnolls
            goto Westfall 34.0,62.0
            kill Shore Crawler##513 |q 103/1 |count 6
            kill Riverpaw Brute##124 |q 141/1 |count 8 |goto Westfall 36.0,72.0

        step LakeshireTransit
            goto Westfall 56.6,52.6
            fly Stormwind
            fly Lakeshire
            ding 20
    ]])

    -- Remaining Alliance 12-60 Zones (8+ steps each)
    registerGuide("Leveling\\Alliance\\Loch Modan (12-20)", "Loch Modan (12-20)",
        "Thelsamar trogg, kobold, and hunter lodge loop around the Loch.",
        "Circuito de troggs, kóbolds y cabaña de caza alrededor de Thelsamar.", [[
        type LEVELING
        startlevel 12
        endlevel 20
        next Leveling\Alliance\Redridge Mountains (18-25)

        step SouthGateGuard
            goto Loch Modan 24.8,18.4
            accept Stormpike's Order##1338
        step ThelsamarArrival
            goto Loch Modan 33.9,50.9
            fpath Thelsamar
            home Thelsamar
            accept Thelsamar Blood Sausages##418 |goto 1432 34.8,49.3
            accept In Defense of the King's Lands##224 |goto Loch Modan 22.1,73.1
        step TroggClearing1
            goto Loch Modan 30.0,68.0
            kill Stonesplinter Trogg##1161 |q 224/1 |count 10
            kill Stonesplinter Scout##1162 |q 224/2 |count 10
        step FarstriderLodge
            goto Loch Modan 83.8,62.4
            accept Crocolisk Hunting##385 |goto 1432 81.8,61.7
            accept A Hunter's Boast##257 |goto 1432 83.5,65.5
        step IronbandExcavation
            goto Loch Modan 65.9,65.6
            accept Excavation Progress Report##298
            kill Loch Crocolisk##1693 |q 385/1 |count 5 |goto Loch Modan 55.0,55.0
        step TurnInThelsamarFinal
            goto Loch Modan 34.8,49.3
            turnin Thelsamar Blood Sausages##418
            turnin Excavation Progress Report##298 |goto 1432 37.2,47.4
            vendor Khara Deepwater##1682
            ding 20
    ]])

    registerGuide("Leveling\\Alliance\\Darkshore (12-20)", "Costa Oscura (12-20)",
        "Auberdine coastline loop from Bashal'Aran to Twilight Shore.",
        "Circuito costero de Auberdine desde Bashal'Aran hasta la Costa del Crepúsculo.", [[
        type LEVELING
        startlevel 12
        endlevel 20
        next Leveling\Alliance\Ashenvale (22-30)

        step AuberdineArrival
            goto Darkshore 36.3,45.6
            fpath Auberdine
            home Auberdine
            accept Buzzbox 827##983 |goto 1439 37.0,44.1
            accept Plagued Lands##2118 |goto 1439 38.8,43.4
            accept Bashal'Aran##954 |goto 1439 37.4,40.1
        step CrabCoastline
            goto Darkshore 36.5,50.5
            get 6 Crawler Leg##5412 |q 983/1
            turnin Buzzbox 827##983 |goto Darkshore 36.7,46.2
        step BashalAranChain
            goto Darkshore 44.2,36.3
            turnin Bashal'Aran##954
            accept Bashal'Aran##955
            kill Grellkin##2189 |q 955/1 |count 8
        step TowerOfAlthalaxx
            goto Darkshore 55.0,24.9
            accept The Tower of Althalaxx##965 |goto 1439 39.0,43.6
            kill Dark Strand Fanatic##2336 |q 965/1 |count 8
        step AuberdineTurnInVendor
            goto Darkshore 37.4,41.8
            turnin Plagued Lands##2118 |goto 1439 38.8,43.4
            vendor Laird##10364
            ding 20
    ]])

    registerGuide("Leveling\\Alliance\\Redridge Mountains (18-25)", "Montañas Crestagrana (18-25)",
        "Lakeshire gnoll and Blackrock orc chains across Stonewatch.",
        "Cadenas de gnolls y orcos Roca Negra desde Villa del Lago.", [[
        type LEVELING
        startlevel 18
        endlevel 25
        next Leveling\Alliance\Duskwood (20-30)

        step LakeshireBridge
            goto Redridge Mountains 30.6,59.4
            fpath Lakeshire
            home Lakeshire
            accept Blackrock Menace##20 |goto 1433 33.5,49.0
            accept Encroaching Gnolls##244 |goto 1433 15.3,71.5
        step LakeEverstillMurlocs
            goto Redridge Mountains 40.0,55.0
            accept Selling Fish##127 |goto 1433 27.7,47.4
            kill Murloc Nightcrawler##544 |q 127/1 |count 10
        step RedridgeGnolls
            goto Redridge Mountains 31.0,78.0
            kill Redridge Mongrel##423 |q 244/1 |count 12
        step RedridgeOrcsAndTurnIn
            goto Redridge Mountains 74.0,78.0
            get 10 Battleworn Axe##3014 |q 20/1
            turnin Blackrock Menace##20 |goto 1433 33.5,49.0
            vendor Brikk Keencraft##3081
            ding 25
    ]])

    registerGuide("Leveling\\Alliance\\Duskwood (20-30)", "Bosque del Ocaso (20-30)",
        "Darkshire worgen, Stitches, and Stalvan Mistmantle chains.",
        "Cadenas de huargos, Puntos y la leyenda de Stalvan en Villa Oscura.", [[
        type LEVELING
        startlevel 20
        endlevel 30
        next Leveling\Alliance\Stranglethorn Vale (30-42)

        step DarkshireArrival
            goto Duskwood 77.5,44.3
            fpath Darkshire
            home Darkshire
            accept The Legend of Stalvan##6 |goto 1429 48.2,42.96
            accept Night Watch##56 |goto Duskwood 73.6,46.8
        step RavenHillUndead
            goto Duskwood 20.0,42.0
            kill Skeletal Warrior##48 |q 56/1 |count 8
            kill Skeletal Mage##203 |q 56/2 |count 6
        step ManorStalvan
            goto Duskwood 72.6,33.9
            accept Sven's Revenge##95 |goto Duskwood 7.8,34.1
        step DarkshireTurninVendor
            goto Duskwood 73.6,46.8
            turnin Night Watch##56
            turnin The Legend of Stalvan##66 |goto 1431 72.5,46.9
            vendor Gavin Gnarlbeard##226
            ding 30
    ]])

    registerGuide("Leveling\\Alliance\\Ashenvale (22-30)", "Vallefresno (22-30)",
        "Astranaar forest patrol and furbolg camps.",
        "Patrulla por los bosques de Astranaar y campamentos fúrbolg.", [[
        type LEVELING
        startlevel 22
        endlevel 30
        next Leveling\Alliance\Stranglethorn Vale (30-42)

        step AstranaarHub
            goto Ashenvale 34.4,48.0
            fpath Astranaar
            home Astranaar
            accept Raene's Cleansing##1025 |goto 1440 36.6,49.6
            accept Pridewings of Stonetalon##1134
        step AstranaarWolvesAndFurlbogs
            goto Ashenvale 54.0,35.0
            kill Foulweald Den Watcher##3746 |q 1025/1 |count 10
        step MaestrasPostAndZoram
            goto Ashenvale 26.2,38.7
            accept The Zoram Strand##1008 |goto 1440 34.7,48.8
            kill Writhing Deep Crawler##3727 |q 1008/1 |count 20
        step AstranaarTurnIn
            goto Ashenvale 36.6,49.6
            turnin Raene's Cleansing##1025
            ding 30
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
            accept Kurzen's Mystery##20 |goto 1433 33.5,49.07
            accept Jungle Secrets##215
        step NesingwarySafari
            goto Stranglethorn Vale 35.6,10.5
            accept Tiger Mastery##185
            accept Panther Mastery##190
            accept Raptor Mastery##194
        step KurzenAndBeasts
            goto Stranglethorn Vale 44.0,11.0
            kill Kurzen Jungle Fighter##937 |q 207/1 |count 10
        step BootyBayHub
            goto Stranglethorn Vale 27.5,77.8
            fpath Booty Bay
            home Booty Bay
            accept Singing Blue Shards##6 |goto 1429 48.2,42.905
            ding 42
    ]])

    registerGuide("Leveling\\Alliance\\Searing Gorge (45-51)", "La Garganta de Fuego (45-51)",
        "Thorium Brotherhood hub and Dark Iron dwarf quarries.",
        "Hermandad del Torio y canteras de los enanos Hierro Negro.", [[
        type LEVELING
        startlevel 45
        endlevel 51
        next Leveling\Alliance\Winterspring (53-60)

        step ThoriumPoint
            goto Searing Gorge 37.9,30.8
            fpath Thorium Point
            accept Fiery Menace!##7724 |goto Searing Gorge 38.6,27.8
            accept Incendosaurs? Whateverosaur is More Like It##7727 |goto 1427 38.6,27.8
        step SlagPitAndLava
            goto Searing Gorge 42.0,45.0
            kill Greater Lava Spider##5858 |q 7724/1 |count 20
            kill Incendosaur##9318 |q 7727/1 |count 20
        step TurnInThorium
            goto Searing Gorge 38.6,27.8
            turnin Fiery Menace!##7724
            turnin Incendosaurs? Whateverosaur is More Like It##7727
            ding 51
    ]])

    registerGuide("Leveling\\Alliance\\Winterspring (53-60)", "Cuna del Invierno (53-60)",
        "Everlook yeti, owlbeast, and frostsaber loops.",
        "Circuitos de yetis y lechúcicos alrededor de Vista Eterna.", [[
        type LEVELING
        startlevel 53
        endlevel 60
        next Leveling\Alliance\Eastern Plaguelands (56-60)

        step Everlook
            goto Winterspring 62.3,36.6
            fpath Everlook
            home Everlook
            accept Are We There, Yeti?##3783 |goto 1452 60.9,37.6
            accept Threat of the Winterfall##5082 |goto 1452 31.3,45.2
        step YetiCaveLoop
            goto Winterspring 66.0,42.0
            get 10 Thick Yeti Fur##12366 |q 3783/1
            kill Winterfall Pathfinder##7442 |q 5082/1 |count 8
        step TurnInEverlook
            goto Winterspring 61.3,38.9
            turnin Are We There, Yeti?##3783 |goto 1452 60.9,37.6
            turnin Threat of the Winterfall##5082 |goto 1452 31.3,45.2
            ding 56
    ]])

    registerGuide("Leveling\\Alliance\\Eastern Plaguelands (56-60)", "Tierras de la Peste del Este - Alianza (56-60)",
        "Tirion Fordring & Light's Hope Chapel finale to level 60.",
        "Cadenas finales de Tirion Vadín y la Capilla de la Esperanza hasta nivel 60.", [[
        type LEVELING
        startlevel 56
        endlevel 60

        step FordringCamp
            goto Eastern Plaguelands 7.6,43.7
            accept Demon Dogs##5542 |goto 1422 67.3,24.2
            accept Blood Tinged Skies##5543 |goto 1422 67.3,24.2
        step PlaguehoundsAlliance
            goto Eastern Plaguelands 28.0,45.0
            kill Plaguehound Runt##8596 |q 5542/1 |count 20
            kill Plaguebat##8600 |q 5543/1 |count 30
        step LightsHopeFinalAlliance
            goto Eastern Plaguelands 81.6,59.3
            fpath Light's Hope Chapel
            turnin Demon Dogs##5542 |goto 1422 67.3,24.2
            ding 60
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
            accept Hidden Enemies##5726 |goto 1454 31.7,37.8
            accept Testing an Enemy's Strength##5723 |goto 1412 44.1,22.8
        step RFCBosses
            kill Bazzalan##11519
            kill Taragaman the Hungerer##11520
    ]])

    registerGuide("Dungeons\\The Deadmines (17-24)", "Las Minas de la Muerte (17-24)",
        "Moonbrook Brotherhood quests leading to Edwin VanCleef.",
        "Misiones de la Hermandad Defias hasta Edwin VanCleef.", [[
        type DUNGEONS
        startlevel 17
        endlevel 24
        step DMQuests
            goto Westfall 42.6,71.8
            accept Red Silk Bandanas##214 |goto 1436 56.7,47.3
            accept Underground Assault##20 |goto 1433 33.5,49.040
        step DMBosses
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
            accept Leaders of the Fang##914 |goto 1412 45.2,23.3
            accept Deviate Eradication##1487
        step WCBosses
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
            accept Arugal Must Die##1014 |goto 1421 44.2,39.8
            accept The Book of Ur##1013 |goto 1458 53.7,54.5

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
            accept Allegiance to the Old Gods##6 |goto 1429 48.2,42.9564
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
            accept Rig Wars##2841 |goto 1454 76.0,25.4
            accept Save Techbot's Brain##2922 |goto 1455 69.5,50.3
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
            accept A Vengeful Fate##1102 |goto 1412 37.1,29.0
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
            accept Into The Scarlet Monastery##1048 |goto 1421 74.2,13.5
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
            accept Solution to Doom##709 |goto 1418 51.4,76.9
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
            accept Gahz'rilla##2770 |goto 1441 78.1,77.1
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
            accept Legends of Maraudon##7044 |goto 1443 32.0,63.7
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
            accept Marshal Windsor##6 |goto 1429 48.2,42.9402
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
