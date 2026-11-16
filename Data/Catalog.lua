-- AzerothRoute: Complete Static Data Catalog (9-Class Builds, Multi-Continent Travel Graph, Chains, NPCs, Skills, Gear) (SPEC-14B / SPEC-19)

local AR = _G.AzerothRoute
local Catalog = {}
AR.Catalog = Catalog

function Catalog:LoadQuestChains()
    if not AR.Chains then return end
    -- Tirisfal Glades & Silverpine chains
    AR.Chains:RegisterChain(364, { prereqs = { 363 } })
    AR.Chains:RegisterChain(380, { prereqs = { 364 } })
    AR.Chains:RegisterChain(381, { prereqs = { 380 } })
    AR.Chains:RegisterChain(382, { prereqs = { 381 } })
    AR.Chains:RegisterChain(427, { prereqs = { 364 } })
    -- The Barrens chains
    AR.Chains:RegisterChain(855, { prereqs = { 850 } })
    AR.Chains:RegisterChain(870, { prereqs = {} })
    AR.Chains:RegisterChain(877, { prereqs = { 870 } })
end

function Catalog:LoadTravelGraph()
    if not AR.Pathfinder then return end
    -- Eastern Kingdoms Nodes
    AR.Pathfinder:AddNode({ id = "ek_deathknell", type = "walk", map = 1420, x = 0.31, y = 0.71 })
    AR.Pathfinder:AddNode({ id = "ek_brill", type = "walk", map = 1420, x = 0.60, y = 0.52 })
    AR.Pathfinder:AddNode({ id = "ek_brill_zep", type = "zeppelin", map = 1420, x = 0.61, y = 0.59 })
    AR.Pathfinder:AddNode({ id = "ek_undercity", type = "taxi", taxiName = "Undercity", map = 1458, x = 0.63, y = 0.48 })
    AR.Pathfinder:AddNode({ id = "ek_sepulcher", type = "taxi", taxiName = "The Sepulcher", map = 1421, x = 0.45, y = 0.42 })
    AR.Pathfinder:AddNode({ id = "ek_booty_bay", type = "ship", map = 1434, x = 0.26, y = 0.73 })

    -- Kalimdor Nodes
    AR.Pathfinder:AddNode({ id = "kal_org_zep", type = "zeppelin", map = 1411, x = 0.51, y = 0.13 })
    AR.Pathfinder:AddNode({ id = "kal_orgrimmar", type = "taxi", taxiName = "Orgrimmar", map = 1454, x = 0.45, y = 0.63 })
    AR.Pathfinder:AddNode({ id = "kal_crossroads", type = "taxi", taxiName = "The Crossroads", map = 1413, x = 0.51, y = 0.30 })
    AR.Pathfinder:AddNode({ id = "kal_ratchet", type = "ship", taxiName = "Ratchet", map = 1413, x = 0.63, y = 0.37 })
    AR.Pathfinder:AddNode({ id = "kal_thunder_bluff", type = "taxi", taxiName = "Thunder Bluff", map = 1456, x = 0.47, y = 0.50 })

    -- Edges (Eastern Kingdoms <-> Kalimdor via Zeppelin and Ship)
    AR.Pathfinder:AddEdge("ek_deathknell", "ek_brill", "walk", 90)
    AR.Pathfinder:AddEdge("ek_brill", "ek_undercity", "walk", 45)
    AR.Pathfinder:AddEdge("ek_undercity", "ek_brill_zep", "walk", 35)
    AR.Pathfinder:AddEdge("ek_brill_zep", "kal_org_zep", "zeppelin", 120)
    AR.Pathfinder:AddEdge("kal_org_zep", "kal_orgrimmar", "walk", 30)
    AR.Pathfinder:AddEdge("kal_orgrimmar", "kal_crossroads", "walk", 180)
    AR.Pathfinder:AddEdge("kal_crossroads", "kal_ratchet", "walk", 95)
    AR.Pathfinder:AddEdge("kal_ratchet", "ek_booty_bay", "ship", 180)
end

function Catalog:LoadTalentBuilds()
    if not AR.TalentAdvisor then return end
    local builds = {
        WARRIOR = {
            ident = "WARRIOR_ARMS_LEVELING",
            name = "Arms Leveling (10-60)",
            suggested = true,
            talents = "Deflection\nDeflection\nCruelty\nCruelty\nTactical Mastery\nAnger Management\nMortal Strike",
        },
        PALADIN = {
            ident = "PALADIN_RET_LEVELING",
            name = "Retribution Leveling (10-60)",
            suggested = true,
            talents = "Benediction\nBenediction\nBenediction\nBenediction\nBenediction\nImproved Judgement\nImproved Judgement\nSeal of Command\nPursuit of Justice\nPursuit of Justice",
        },
        HUNTER = {
            ident = "HUNTER_BM_LEVELING",
            name = "Beast Mastery Leveling (10-60)",
            suggested = true,
            talents = "Improved Aspect of the Hawk\nEndurance Training\nThick Hide\nBestial Wrath",
        },
        ROGUE = {
            ident = "ROGUE_COMBAT_LEVELING",
            name = "Combat Swords Leveling (10-60)",
            suggested = true,
            talents = "Improved Sinister Strike\nImproved Sinister Strike\nMalice\nPrecision\nBlade Flurry",
        },
        PRIEST = {
            ident = "PRIEST_WAND_SHADOW_LEVELING",
            name = "Wand & Shadow Leveling (10-60)",
            suggested = true,
            talents = "Wand Specialization\nWand Specialization\nSpirit Tap\nShadow Focus\nShadowform",
        },
        SHAMAN = {
            ident = "SHAMAN_ENH_LEVELING",
            name = "Enhancement Leveling (10-60)",
            suggested = true,
            talents = "Ancestral Knowledge\nThundering Strikes\nFlurry\nStormstrike",
        },
        MAGE = {
            ident = "MAGE_FROST_LEVELING",
            name = "Frost AoE & Single-Target Leveling (10-60)",
            suggested = true,
            talents = "Elemental Precision\nImproved Frostbolt\nFrostbite\nIce Shards\nIce Barrier",
        },
        WARLOCK = {
            ident = "WARLOCK_AFFLICTION_LEVELING",
            name = "Affliction Drain-Tank Leveling (10-60)",
            suggested = true,
            talents = "Suppression\nImproved Corruption\nFel Concentration\nSiphon Life",
        },
        DRUID = {
            ident = "DRUID_FERAL_LEVELING",
            name = "Feral Cat/Bear Leveling (10-60)",
            suggested = true,
            talents = "Ferocity\nFeral Instinct\nFeline Swiftness\nLeader of the Pack",
        },
    }
    for cls, spec in pairs(builds) do
        AR.TalentAdvisor:RegisterBuild(cls, spec)
    end
end

function Catalog:LoadAll()
    self:LoadQuestChains()
    self:LoadTravelGraph()
    self:LoadTalentBuilds()

    if AR.WhoWhere then
        AR.WhoWhere:RegisterNPC(5675, { name = "Brother Malach", role = "trainer", class = "PALADIN", map = 1420, x = 0.32, y = 0.70 })
        AR.WhoWhere:RegisterNPC(2118, { name = "Abigail Shiel", role = "vendor", map = 1420, x = 0.61, y = 0.52 })
        AR.WhoWhere:RegisterNPC(3449, { name = "Darsok Swiftdagger", role = "QuestGiver", map = 1413, x = 0.51, y = 0.30 })
    end
    if AR.Skills then
        AR.Skills:RegisterSkill("PALADIN", { spellID = 21084, name = "Seal of Righteousness", level = 1, optional = false })
        AR.Skills:RegisterSkill("PALADIN", { spellID = 20271, name = "Judgement", level = 4, optional = false })
        AR.Skills:RegisterSkill("PALADIN", { spellID = 639, name = "Holy Light (Rank 2)", level = 6, optional = false })
    end
    return true
end

Catalog:LoadAll()

return Catalog
