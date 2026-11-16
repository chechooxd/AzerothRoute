-- AzerothRoute: Coordinate & Affine Transform Engine (SPEC-05)

local AR = _G.AzerothRoute
local Coords = {
    ZONE_SCALE_YARDS = 1000.0,
}
AR.Coords = Coords

function Coords:GetPlayerPosition()
    local mapID = (_G.C_Map and _G.C_Map.GetBestMapForUnit and _G.C_Map.GetBestMapForUnit("player")) or 1420
    local pos = _G.C_Map and _G.C_Map.GetPlayerMapPosition and _G.C_Map.GetPlayerMapPosition(mapID, "player")
    local x, y = 0.5, 0.5
    if pos and pos.GetXY then
        x, y = pos:GetXY()
    end
    return mapID, x or 0.5, y or 0.5
end

function Coords:GetDistanceBetween(map1, x1, y1, map2, x2, y2)
    if not map1 or not map2 or not x1 or not y1 or not x2 or not y2 then
        return nil
    end
    local crossZonePenalty = (map1 == map2) and 0 or 500
    local dx = (x2 - x1) * self.ZONE_SCALE_YARDS
    local dy = (y2 - y1) * self.ZONE_SCALE_YARDS
    return math.sqrt(dx * dx + dy * dy) + crossZonePenalty
end

function Coords:GetDistanceTo(targetMap, targetX, targetY)
    local pMap, px, py = self:GetPlayerPosition()
    return self:GetDistanceBetween(pMap, px, py, targetMap, targetX, targetY)
end

function Coords:GetBearingTo(targetMap, targetX, targetY)
    local _, px, py = self:GetPlayerPosition()
    if not targetX or not targetY then return 0 end
    local dx = targetX - px
    local dy = targetY - py
    return math.atan2(dx, -dy)
end

return Coords
