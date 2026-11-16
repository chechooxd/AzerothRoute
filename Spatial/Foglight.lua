-- AzerothRoute: Unexplored Map Overlay Calculator (Foglight) (SPEC-05)

local AR = _G.AzerothRoute
local Foglight = {
    zoneOverlays = {}, -- { [mapID] = { "Overlay1", "Overlay2", ... } }
}
AR.Foglight = Foglight

function Foglight:RegisterZoneOverlays(mapID, overlays)
    self.zoneOverlays[mapID] = overlays or {}
end

function Foglight:GetUnexploredOverlays(mapID)
    local all = self.zoneOverlays[mapID] or {}
    local explored = (_G.C_MapExplorationInfo and _G.C_MapExplorationInfo.GetExploredMapTextures and _G.C_MapExplorationInfo.GetExploredMapTextures(mapID)) or {}
    local unexplored = {}
    for _, tex in ipairs(all) do
        if not explored[tex] then
            table.insert(unexplored, tex)
        end
    end
    return unexplored
end

return Foglight
