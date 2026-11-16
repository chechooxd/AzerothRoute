-- AzerothRoute: Built-in Guides Catalog (Leveling, Professions, Dungeons, Gold) (SPEC-14B)

local AR = _G.AzerothRoute
local GuidesCatalog = {}
AR.GuidesCatalog = GuidesCatalog

function GuidesCatalog:LoadAll()
    if not AR.Parser then return false end

    AR.Parser:RegisterInclude("HordeDeathknellTrainer", [[
        step
            talk %npc%##%npcid%
            learn Seal of Righteousness##21084 |only Paladin
    ]])

    AR.Parser:ParseGuide("Leveling\\Horde\\Tirisfal Glades (1-12)", [[
        author AzerothRoute
        type LEVELING
        startlevel 1
        endlevel 12
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
    ]])

    AR.Parser:ParseGuide("Professions\\Alchemy (1-300)", [[
        author AzerothRoute
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

    return true
end

GuidesCatalog:LoadAll()

return GuidesCatalog
