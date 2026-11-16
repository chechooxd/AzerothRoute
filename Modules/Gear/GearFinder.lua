-- AzerothRoute: Dungeon Loot Recommender (GearFinder) (SPEC-08)

local AR = _G.AzerothRoute
local GearFinder = {
    dungeons = {},
}
AR.GearFinder = GearFinder

function GearFinder:Reset()
    self.dungeons = {}
end

function GearFinder:RegisterDungeonLoot(dungeonName, minLevel, maxLevel, itemLinks)
    table.insert(self.dungeons, {
        name = dungeonName,
        minLevel = minLevel or 1,
        maxLevel = maxLevel or 60,
        items = itemLinks or {},
    })
end

function GearFinder:FindBestDungeonUpgrades()
    local pLevel = (_G.UnitLevel and _G.UnitLevel("player")) or 1
    local recommendations = {}

    for _, d in ipairs(self.dungeons) do
        if pLevel >= d.minLevel and pLevel <= (d.maxLevel + 5) then
            for _, link in ipairs(d.items) do
                local eval = AR.Upgrades:EvaluateCandidate(link)
                if eval and eval.isUpgrade then
                    table.insert(recommendations, {
                        dungeon = d.name,
                        itemLink = link,
                        slot = eval.slot,
                        delta = eval.delta,
                    })
                end
            end
        end
    end

    table.sort(recommendations, function(a, b)
        return a.delta > b.delta
    end)
    return recommendations
end

return GearFinder
