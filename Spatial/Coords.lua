-- AzerothRoute: Continent & World-Yard Coordinate Projection Engine (SPEC-05 / SPEC-18)
-- Projects zone normalized coordinates (0..1) into continuous continent world yards (or C_Map.GetWorldPosFromMapPos when available).

local AR = _G.AzerothRoute
local Coords = {
    ZONE_SCALE_YARDS = 1000.0,
    -- Calibrated zone bounds in continent world yards: { continent=0 (EK) / 1 (Kalimdor), width=..., height=..., offsetX=..., offsetY=... }
    ZONE_BOUNDS = {
        -- Eastern Kingdoms (Continent 0)
        [1420] = { continent = 0, width = 4518, height = 3012, offsetX = 12000, offsetY = 4000 },  -- Tirisfal Glades
        [1421] = { continent = 0, width = 4200, height = 2800, offsetX = 12159, offsetY = 6700 },  -- Silverpine Forest
        [1422] = { continent = 0, width = 4300, height = 2866, offsetX = 15200, offsetY = 4800 },  -- Western Plaguelands
        [1423] = { continent = 0, width = 4031, height = 2687, offsetX = 18200, offsetY = 4600 },  -- Eastern Plaguelands
        [1424] = { continent = 0, width = 3200, height = 2133, offsetX = 13800, offsetY = 7800 },  -- Hillsbrad Foothills
        [1426] = { continent = 0, width = 4925, height = 3283, offsetX = 13000, offsetY = 14000 }, -- Dun Morogh
        [1429] = { continent = 0, width = 3470, height = 2314, offsetX = 13500, offsetY = 18500 }, -- Elwynn Forest
        [1436] = { continent = 0, width = 3500, height = 2333, offsetX = 11200, offsetY = 19500 }, -- Westfall
        [1434] = { continent = 0, width = 6381, height = 4254, offsetX = 12800, offsetY = 22500 }, -- Stranglethorn Vale
        [1458] = { continent = 0, width = 959,  height = 640,  offsetX = 13800, offsetY = 5800 },  -- Undercity
        [1453] = { continent = 0, width = 1737, height = 1158, offsetX = 13200, offsetY = 18100 }, -- Stormwind City
        -- Kalimdor (Continent 1)
        [1411] = { continent = 1, width = 5287, height = 3525, offsetX = 19000, offsetY = 14000 }, -- Durotar
        [1412] = { continent = 1, width = 5137, height = 3425, offsetX = 13000, offsetY = 16000 }, -- Mulgore
        [1413] = { continent = 1, width = 10133, height = 6756, offsetX = 14500, offsetY = 14500 },-- The Barrens
        [1438] = { continent = 1, width = 5091, height = 3394, offsetX = 12000, offsetY = 2000 },  -- Teldrassil
        [1439] = { continent = 1, width = 6550, height = 4366, offsetX = 13500, offsetY = 5500 },  -- Darkshore
        [1440] = { continent = 1, width = 5766, height = 3843, offsetX = 15000, offsetY = 10500 }, -- Ashenvale
        [1454] = { continent = 1, width = 1402, height = 935,  offsetX = 20100, offsetY = 13500 }, -- Orgrimmar
        [1456] = { continent = 1, width = 1043, height = 695,  offsetX = 14200, offsetY = 16200 }, -- Thunder Bluff
    },
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

function Coords:ToWorldYards(mapID, x, y)
    if not mapID or not x or not y then return nil, nil, nil end
    if x > 1 then x = x / 100.0 end
    if y > 1 then y = y / 100.0 end
    -- Prefer native C_Map.GetWorldPosFromMapPos when running in a client that exposes CreateVector2D
    if _G.C_Map and _G.C_Map.GetWorldPosFromMapPos and _G.CreateVector2D then
        local contID, worldPos = _G.C_Map.GetWorldPosFromMapPos(mapID, _G.CreateVector2D(x, y))
        if contID and worldPos and worldPos.GetXY then
            local wx, wy = worldPos:GetXY()
            return contID, wx, wy
        end
    end

    local b = self.ZONE_BOUNDS[mapID]
    if b then
        local wx = b.offsetX + (x * b.width)
        local wy = b.offsetY + (y * b.height)
        return b.continent, wx, wy
    end
    -- Fallback synthetic continent per mapID if uncalibrated
    return mapID, x * self.ZONE_SCALE_YARDS, y * self.ZONE_SCALE_YARDS
end

function Coords:GetDistanceBetween(map1, x1, y1, map2, x2, y2)
    if not map1 or not map2 or not x1 or not y1 or not x2 or not y2 then
        return nil
    end
    local c1, wx1, wy1 = self:ToWorldYards(map1, x1, y1)
    local c2, wx2, wy2 = self:ToWorldYards(map2, x2, y2)
    if not c1 or not c2 or c1 ~= c2 then
        return nil -- Different continents: direct walking distance is undefined
    end
    local dx = wx2 - wx1
    local dy = wy2 - wy1
    return math.sqrt(dx * dx + dy * dy)
end

function Coords:GetDistanceTo(targetMap, targetX, targetY)
    local pMap, px, py = self:GetPlayerPosition()
    return self:GetDistanceBetween(pMap, px, py, targetMap, targetX, targetY)
end

function Coords:GetBearingTo(targetMap, targetX, targetY)
    local pMap, px, py = self:GetPlayerPosition()
    if not targetX or not targetY then return 0 end
    local c1, wx1, wy1 = self:ToWorldYards(pMap, px, py)
    local c2, wx2, wy2 = self:ToWorldYards(targetMap or pMap, targetX, targetY)
    if c1 and c2 and c1 == c2 then
        return math.atan2(wx2 - wx1, -(wy2 - wy1))
    end
    return math.atan2(targetX - px, -(targetY - py))
end

return Coords
