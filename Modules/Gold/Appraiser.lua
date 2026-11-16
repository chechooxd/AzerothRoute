-- AzerothRoute: Auction House Shopping & Undercut Appraiser (SPEC-09)

local AR = _G.AzerothRoute
local Appraiser = {}
AR.Appraiser = Appraiser

function Appraiser:GetShoppingListFromGuide()
    local list = {}
    if not AR.Progression or not AR.Progression.currentStep then
        return list
    end
    for _, g in ipairs(AR.Progression.currentStep.goals or {}) do
        if (g.action == "buy" or g.action == "get") and g.targetid then
            local targetCount = g.count or 1
            local haveCount = AR.Compat:GetItemCount(g.targetid, false)
            if haveCount < targetCount then
                table.insert(list, {
                    itemID = g.targetid,
                    name = g.target,
                    needed = targetCount - haveCount,
                })
            end
        end
    end
    return list
end

function Appraiser:SuggestUndercutPrice(itemID, currentLowestBuyout)
    if currentLowestBuyout and currentLowestBuyout > 1 then
        return currentLowestBuyout - 1
    end
    local trend = AR.ServerTrends and AR.ServerTrends:GetTrend(itemID)
    return (trend and trend.p_md) or 100
end

return Appraiser
