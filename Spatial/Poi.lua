-- AzerothRoute: Points of Interest (Rares / Treasures) Manager (SPEC-05)

local AR = _G.AzerothRoute
local Poi = {
    pointsByMap = {},
}
AR.Poi = Poi

function Poi:RegisterPOI(mapID, poiSpec)
    self.pointsByMap[mapID] = self.pointsByMap[mapID] or {}
    table.insert(self.pointsByMap[mapID], poiSpec)
end

function Poi:GetPOIsForMap(mapID)
    return self.pointsByMap[mapID] or {}
end

return Poi
