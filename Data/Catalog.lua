-- AzerothRoute: Static Data Catalog (Chains, NPCs, Nodes, Skills, Gear) (SPEC-14B)

local AR = _G.AzerothRoute
local Catalog = {}
AR.Catalog = Catalog

function Catalog:LoadAll()
    if AR.Chains then
        AR.Chains:RegisterChain(364, { prereqs = { 363 } })
        AR.Chains:RegisterChain(380, { prereqs = { 364 } })
    end
    if AR.WhoWhere then
        AR.WhoWhere:RegisterNPC(5675, { name = "Brother Malach", role = "trainer", class = "PALADIN", map = 1420, x = 0.32, y = 0.70 })
        AR.WhoWhere:RegisterNPC(2118, { name = "Abigail Shiel", role = "vendor", map = 1420, x = 0.61, y = 0.52 })
    end
    if AR.Skills then
        AR.Skills:RegisterSkill("PALADIN", { spellID = 21084, name = "Seal of Righteousness", level = 1, optional = false })
        AR.Skills:RegisterSkill("PALADIN", { spellID = 20271, name = "Judgement", level = 4, optional = false })
        AR.Skills:RegisterSkill("PALADIN", { spellID = 639, name = "Holy Light (Rank 2)", level = 6, optional = false })
    end
    if AR.TalentAdvisor then
        AR.TalentAdvisor:RegisterBuild("PALADIN", {
            ident = "PALADIN_RET_LEVELING",
            name = "Retribution Leveling (10-60)",
            suggested = true,
            talents = [[
                Benediction
                Benediction
                Benediction
                Benediction
                Benediction
                Improved Judgement
                Improved Judgement
                Seal of Command
                Pursuit of Justice
                Pursuit of Justice
            ]],
        })
    end
    return true
end

Catalog:LoadAll()

return Catalog
