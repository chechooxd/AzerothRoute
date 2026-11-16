-- AzerothRoute: Gold/Hour Route & Chore Scorer (GoldGuide) (SPEC-09)

local AR = _G.AzerothRoute
local GoldGuide = {
    chores = {},
}
AR.GoldGuide = GoldGuide

function GoldGuide:Reset()
    self.chores = {}
end

function GoldGuide:RegisterChore(choreSpec)
    table.insert(self.chores, choreSpec)
end

function GoldGuide:GetRankedChores()
    local scored = {}
    for _, c in ipairs(self.chores) do
        local copperPerHour = 0
        for itemID, qtyPerHour in pairs(c.yieldsPerHour or {}) do
            local trend = AR.ServerTrends and AR.ServerTrends:GetTrend(itemID)
            local unitVal = (trend and trend.p_md) or 0
            copperPerHour = copperPerHour + (unitVal * qtyPerHour)
        end
        table.insert(scored, {
            title = c.title,
            copperPerHour = copperPerHour,
        })
    end
    table.sort(scored, function(a, b)
        return a.copperPerHour > b.copperPerHour
    end)
    return scored
end

return GoldGuide
