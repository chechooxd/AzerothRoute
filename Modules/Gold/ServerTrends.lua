-- AzerothRoute: 10th/50th/90th Percentile Market Trends Engine (ServerTrends) (SPEC-09)

local AR = _G.AzerothRoute
local ServerTrends = {}
AR.ServerTrends = ServerTrends

local function percentile(sortedList, p)
    if not sortedList or #sortedList == 0 then return 0 end
    local idx = math.max(1, math.min(#sortedList, math.ceil(#sortedList * p)))
    return sortedList[idx]
end

function ServerTrends:SetTrend(itemID, trendObj)
    if not AR.db or not AR.db.factionrealm then return end
    AR.db.factionrealm.gold_trends = AR.db.factionrealm.gold_trends or {}
    AR.db.factionrealm.gold_trends[itemID] = trendObj
end

function ServerTrends:GetTrend(itemID)
    if not AR.db or not AR.db.factionrealm or not AR.db.factionrealm.gold_trends then
        return nil
    end
    return AR.db.factionrealm.gold_trends[itemID]
end

function ServerTrends:ComputeTrendsFromScan(scanByItem)
    if not AR.db or not AR.db.factionrealm then return end
    AR.db.factionrealm.gold_trends = AR.db.factionrealm.gold_trends or {}

    for itemID, prices in pairs(scanByItem or {}) do
        table.sort(prices)
        AR.db.factionrealm.gold_trends[itemID] = {
            p_lo = percentile(prices, 0.10),
            p_md = percentile(prices, 0.50),
            p_hi = percentile(prices, 0.90),
            volume = #prices,
        }
    end
end

function ServerTrends:ClassifyPrice(itemID, unitPrice)
    local t = self:GetTrend(itemID)
    if not t then return "PRICESTATUS_UNKNOWN" end
    if unitPrice < t.p_lo then
        return "PRICESTATUS_DUMPED"
    elseif unitPrice <= t.p_md then
        return "PRICESTATUS_DEAL"
    elseif unitPrice <= t.p_hi then
        return "PRICESTATUS_NORMAL"
    elseif unitPrice >= (t.p_hi * 1.5) then
        return "PRICESTATUS_GOUGED"
    end
    return "PRICESTATUS_INFLATED"
end

return ServerTrends
