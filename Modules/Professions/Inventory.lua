-- AzerothRoute: Inventory, Merchant Auto-Buy, Grey Seller & Bank Serializer (SPEC-07)

local AR = _G.AzerothRoute
local Inventory = {}
AR.Inventory = Inventory

function Inventory:FindItemsToBuy()
    local results = {}
    if not AR.Progression or not AR.Progression.currentStep then
        return results
    end
    for _, g in ipairs(AR.Progression.currentStep.goals or {}) do
        if g.action == "buy" and g.targetid then
            local targetCount = g.count or 1
            local haveCount = AR.Compat:GetItemCount(g.targetid, false)
            if haveCount < targetCount then
                table.insert(results, {
                    itemID = g.targetid,
                    name = g.target,
                    neededCount = targetCount - haveCount,
                })
            end
        end
    end
    return results
end

function Inventory:SellGreyItems()
    local sold = 0
    for bag = 0, 4 do
        local numSlots = (_G.C_Container and _G.C_Container.GetContainerNumSlots and _G.C_Container.GetContainerNumSlots(bag)) or 0
        for slot = 1, numSlots do
            local info = _G.C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == 0 and (info.sellPrice or 0) > 0 then
                _G.C_Container.UseContainerItem(bag, slot)
                sold = sold + 1
            end
        end
    end
    return sold
end

function Inventory:RecordBank(slotEntries)
    if not AR.db or not AR.db.char then return end
    local serialized = {}
    local totals = {}
    for _, entry in ipairs(slotEntries or {}) do
        table.insert(serialized, string.format("%d^%d^%d^%d", entry.itemID or 0, entry.bag or -1, entry.slot or 1, entry.count or 1))
        totals[entry.itemID] = (totals[entry.itemID] or 0) + (entry.count or 1)
    end
    AR.db.char.bank_cache = {
        raw = table.concat(serialized, ";"),
        totals = totals,
    }
    if _G.MockWoW and _G.MockWoW.player then
        _G.MockWoW.player.itemsInBank = totals
    end
end

function Inventory:GetBankedCount(itemID)
    if AR.db and AR.db.char and AR.db.char.bank_cache and AR.db.char.bank_cache.totals then
        return AR.db.char.bank_cache.totals[itemID] or 0
    end
    return 0
end

return Inventory
