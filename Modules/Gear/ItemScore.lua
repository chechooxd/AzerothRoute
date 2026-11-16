-- AzerothRoute: Item Scoring Engine with Soft Caps, Armor Transition Grace & Pawn Support (SPEC-08)

local AR = _G.AzerothRoute
local ItemScore = {
    equippedStatTotals = {},
}
AR.ItemScore = ItemScore

function ItemScore:GetItemMeta(itemLink)
    if _G.MockWoW and _G.MockWoW.tooltips and _G.MockWoW.tooltips.items then
        return _G.MockWoW.tooltips.items[itemLink]
    end
    return nil
end

function ItemScore:ScoreItem(itemLink)
    local meta = self:GetItemMeta(itemLink)
    if not meta then return 0 end
    if meta.isQuestProtected then
        return 999999
    end

    local rule = AR.Statweights:GetActiveRule()
    if not rule then return 0 end

    local pLevel = (_G.UnitLevel and _G.UnitLevel("player")) or 1
    local armorType = meta.armorType
    local armorMultiplier = 1.0

    if armorType and rule.itemtypes then
        local limit = rule.itemtypes[armorType]
        if not limit then
            return 0 -- Unwearable armor class
        elseif limit > 0 and pLevel < limit then
            return 0 -- Requires higher level (e.g. Plate before 40)
        elseif limit < 0 then
            local threshold = -limit
            if pLevel >= (threshold + 10) then
                armorMultiplier = 0.5
            elseif pLevel >= threshold then
                armorMultiplier = 0.9
            end
        end
    end

    local totalScore = 0
    for statKey, statVal in pairs(meta.stats or {}) do
        local weight = rule.stats and rule.stats[statKey] or 0
        if weight > 0 then
            if rule.caps and rule.caps[statKey] then
                local currentEquipped = self.equippedStatTotals[statKey] or 0
                if currentEquipped >= rule.caps[statKey] then
                    weight = weight * 0.5 -- Soft cap: halve stat weight once cap is met
                end
            end
            totalScore = totalScore + (statVal * weight)
        end
    end

    return totalScore * armorMultiplier
end

function ItemScore:ExportPawnString()
    local rule = AR.Statweights:GetActiveRule()
    if not rule then return "" end
    local parts = {}
    for k, v in pairs(rule.stats or {}) do
        table.insert(parts, string.format("%s=%.2f", k, v))
    end
    table.sort(parts)
    return string.format('( Pawn: v1: "%s": %s )', rule.name or "AzerothRoute", table.concat(parts, ", "))
end

return ItemScore
