-- AzerothRoute: Item Scoring Engine with Soft Caps, Armor Transition Grace & Native WoW API Fallback (SPEC-08 / SPEC-16)

local AR = _G.AzerothRoute
local ItemScore = {
    equippedStatTotals = {},
    STAT_KEY_MAP = {
        ITEM_MOD_STRENGTH_SHORT = "STR",
        ITEM_MOD_AGILITY_SHORT = "AGI",
        ITEM_MOD_STAMINA_SHORT = "STA",
        ITEM_MOD_INTELLECT_SHORT = "INT",
        ITEM_MOD_SPIRIT_SHORT = "SPI",
        ITEM_MOD_CRIT_RATING_SHORT = "CRIT",
        ITEM_MOD_HIT_RATING_SHORT = "HIT",
        ITEM_MOD_ATTACK_POWER_SHORT = "AP",
        ITEM_MOD_SPELL_POWER_SHORT = "SP",
    },
}
AR.ItemScore = ItemScore

function ItemScore:GetItemMeta(itemLink)
    if not itemLink or itemLink == "" then return nil end
    if _G.MockWoW and _G.MockWoW.tooltips and _G.MockWoW.tooltips.items and _G.MockWoW.tooltips.items[itemLink] then
        return _G.MockWoW.tooltips.items[itemLink]
    end
    -- Native WoW client GetItemInfo + C_Item.GetItemStats fallback
    if _G.GetItemInfo then
        local name, _, _, _, minLevel, _, itemSubType, stackCount, equipLoc, _, sellPrice = _G.GetItemInfo(itemLink)
        if name then
            local rawStats = (_G.C_Item and _G.C_Item.GetItemStats and _G.C_Item.GetItemStats(itemLink)) or (_G.GetItemStats and _G.GetItemStats(itemLink)) or {}
            local normalized = {}
            for k, v in pairs(rawStats) do
                local mapped = self.STAT_KEY_MAP[k] or k
                normalized[mapped] = (normalized[mapped] or 0) + (tonumber(v) or 0)
            end
            return {
                name = name,
                minLevel = minLevel or 1,
                armorType = itemSubType and itemSubType:upper() or nil,
                slot = equipLoc,
                stats = normalized,
                sellPrice = sellPrice or 0,
                count = stackCount or 1,
            }
        end
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
