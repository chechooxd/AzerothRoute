-- AzerothRoute: Inventory, Merchant Auto-Buy, Auto-Repair, Grey Seller & Bank Serializer (SPEC-07 / SPEC-22)

local AR = _G.AzerothRoute
local Inventory = {
    _liveRegistered = false,
}
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

local function isGreySellable(info)
    if not info or info.quality ~= 0 or info.hasNoValue then
        return false
    end
    if info.sellPrice ~= nil then
        return info.sellPrice > 0
    end
    local ref = info.hyperlink or info.itemID
    if ref and _G.GetItemInfo then
        local _, _, _, _, _, _, _, _, _, _, sellPrice = _G.GetItemInfo(ref)
        if sellPrice ~= nil then
            return sellPrice > 0
        end
    end
    return true
end

function Inventory:SellGreyItems()
    if AR.db and AR.db.global and AR.db.global.autogrey == false then
        return 0
    end
    local sold = 0
    local numBags = (_G.NUM_BAG_SLOTS and _G.NUM_BAG_SLOTS >= 4) and _G.NUM_BAG_SLOTS or 4
    for bag = 0, numBags do
        local numSlots = (_G.C_Container and _G.C_Container.GetContainerNumSlots and _G.C_Container.GetContainerNumSlots(bag)) or 0
        for slot = 1, numSlots do
            local info = _G.C_Container.GetContainerItemInfo(bag, slot)
            if isGreySellable(info) then
                _G.C_Container.UseContainerItem(bag, slot)
                sold = sold + 1
            end
        end
    end
    return sold
end

function Inventory:AutoRepair()
    if AR.db and AR.db.global and AR.db.global.autorepair == false then
        return false
    end
    if _G.CanMerchantRepair and _G.CanMerchantRepair() and _G.RepairAllItems then
        local cost = (_G.GetRepairAllCost and _G.GetRepairAllCost()) or 0
        if cost == nil or cost > 0 then
            _G.RepairAllItems()
            return true
        end
    end
    return false
end

function Inventory:ExecuteAutoBuy()
    if AR.db and AR.db.global and AR.db.global.autobuy == false then
        return 0
    end
    local needed = self:FindItemsToBuy()
    if #needed == 0 or not _G.GetMerchantNumItems or not _G.BuyMerchantItem then
        return 0
    end
    local byID = {}
    for _, req in ipairs(needed) do
        byID[req.itemID] = req.neededCount
    end

    local bought = 0
    local total = _G.GetMerchantNumItems() or 0
    for idx = 1, total do
        local link = _G.GetMerchantItemLink and _G.GetMerchantItemLink(idx)
        local itemID = link and tonumber(tostring(link):match("item:(%d+)"))
        if itemID and byID[itemID] and byID[itemID] > 0 then
            _G.BuyMerchantItem(idx, byID[itemID])
            bought = bought + 1
        end
    end
    return bought
end

local function matchesMerchant(goal)
    if not goal.npcid and (not goal.target or goal.target == "") then return true end
    local guid = _G.UnitGUID and _G.UnitGUID("npc")
    if _G.issecretvalue and _G.issecretvalue(guid) then return false end
    local npcID = type(guid) == "string" and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    if goal.npcid and npcID then return tonumber(goal.npcid) == npcID end
    local name = _G.UnitName and _G.UnitName("npc")
    if _G.issecretvalue and _G.issecretvalue(name) then return false end
    local expected = AR.Localizers:GetTranslatedNPC(goal.npcid, goal.target)
    if _G.issecretvalue and _G.issecretvalue(expected) then return false end
    return type(name) == "string" and name ~= "" and name == expected
end

function Inventory:OnMerchantShow()
    local sold = self:SellGreyItems()
    self:AutoRepair()
    local bought = self:ExecuteAutoBuy()

    if (sold > 0 or bought > 0) and _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
        local msg = (AR.L and AR.L:IsSpanish())
            and string.format("|cff33ff99AzerothRoute:|r Vendidos %d objetos grises.", sold)
            or string.format("|cff33ff99AzerothRoute:|r Auto-sold %d grey items.", sold)
        if sold > 0 then
            _G.DEFAULT_CHAT_FRAME:AddMessage(msg)
        end
    end

    if AR.Progression and AR.Progression.currentStep then
        for _, g in ipairs(AR.Progression.currentStep.goals or {}) do
            if g.action == "vendor" and g:IsVisible() and matchesMerchant(g) then
                g.visited = true
            end
        end
        if AR.Progression:TryToCompleteStep(false) and AR.ViewerFrame then
            AR.ViewerFrame:RefreshVisuals()
        end
    end
end

function Inventory:RegisterLiveEvents()
    if self._liveRegistered or not AR.Events then return end
    self._liveRegistered = true
    AR.Events:RegisterEvent("MERCHANT_SHOW", function()
        self:OnMerchantShow()
    end)
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
