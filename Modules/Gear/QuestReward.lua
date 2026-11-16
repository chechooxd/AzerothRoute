-- AzerothRoute: Quest Reward Advisor (Best Upgrade vs Highest Vendor Gold) (SPEC-08)

local AR = _G.AzerothRoute
local QuestReward = {}
AR.QuestReward = QuestReward

function QuestReward:SelectBestReward(choiceLinks)
    if not choiceLinks or #choiceLinks == 0 then return nil end

    local bestUpgradeIdx = nil
    local bestUpgradeDelta = 0
    local bestMoneyIdx = 1
    local bestMoneyVal = -1

    for idx, link in ipairs(choiceLinks) do
        local eval = AR.Upgrades:EvaluateCandidate(link)
        if eval and eval.isUpgrade and eval.delta > bestUpgradeDelta then
            bestUpgradeDelta = eval.delta
            bestUpgradeIdx = idx
        end

        local meta = AR.ItemScore:GetItemMeta(link)
        local vendorVal = ((meta and meta.sellPrice) or 0) * ((meta and meta.count) or 1)
        if vendorVal > bestMoneyVal then
            bestMoneyVal = vendorVal
            bestMoneyIdx = idx
        end
    end

    if bestUpgradeIdx then
        return {
            index = bestUpgradeIdx,
            itemLink = choiceLinks[bestUpgradeIdx],
            reason = "upgrade",
            delta = bestUpgradeDelta,
        }
    end

    return {
        index = bestMoneyIdx,
        itemLink = choiceLinks[bestMoneyIdx],
        reason = "money",
        vendorValue = bestMoneyVal,
    }
end

return QuestReward
