-- AzerothRoute: Auction House Replicate/Browse State-Machine Scanner (SPEC-09)

local AR = _G.AzerothRoute
local GoldScanner = {
    state = "SS_IDLE", -- SS_IDLE | SS_QUERYING | SS_RECEIVING | SS_SCANNING
}
AR.GoldScanner = GoldScanner

function GoldScanner:Reset()
    self.state = "SS_IDLE"
end

function GoldScanner:RunFullScan()
    self.state = "SS_QUERYING"
    local items = (_G.MockWoW and _G.MockWoW.auction and _G.MockWoW.auction.replicateItems) or {}
    self.state = "SS_RECEIVING"

    local byItem = {}
    self.state = "SS_SCANNING"
    for _, listing in ipairs(items) do
        local count = math.max(1, listing.count or 1)
        local unitPrice = math.floor((listing.buyoutPrice or 0) / count)
        if unitPrice > 0 then
            byItem[listing.itemID] = byItem[listing.itemID] or {}
            table.insert(byItem[listing.itemID], unitPrice)
        end
    end

    if AR.db and AR.db.factionrealm then
        AR.db.factionrealm.gold_scan_data = byItem
    end
    if AR.ServerTrends then
        AR.ServerTrends:ComputeTrendsFromScan(byItem)
    end

    self.state = "SS_IDLE"
    return byItem
end

return GoldScanner
