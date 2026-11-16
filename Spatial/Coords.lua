-- AzerothRoute: Continent & World-Yard Coordinate Projection Engine (SPEC-05 / SPEC-18 / SPEC-21)
-- Projects zone normalized coordinates (0..1) into continuous continent world yards (or C_Map.GetWorldPosFromMapPos when available),
-- and resolves English/Spanish zone names to canonical WoW mapIDs.

local AR = _G.AzerothRoute
local Coords = {
    ZONE_SCALE_YARDS = 1000.0,
    mapAxisCache = {},
    ZONE_BOUNDS = {
        -- Eastern Kingdoms (Continent 0)
        [1416] = { continent = 0, width = 2800, height = 1866, offsetX = 14800, offsetY = 6500 },  -- Alterac Mountains
        [1417] = { continent = 0, width = 3600, height = 2400, offsetX = 16500, offsetY = 8500 },  -- Arathi Highlands
        [1418] = { continent = 0, width = 2487, height = 1658, offsetX = 16500, offsetY = 14500 }, -- Badlands
        [1419] = { continent = 0, width = 3350, height = 2233, offsetX = 16000, offsetY = 20500 }, -- Blasted Lands
        [1420] = { continent = 0, width = 4518, height = 3012, offsetX = 12000, offsetY = 4000 },  -- Tirisfal Glades
        [1421] = { continent = 0, width = 4200, height = 2800, offsetX = 12159, offsetY = 6700 },  -- Silverpine Forest
        [1422] = { continent = 0, width = 4300, height = 2866, offsetX = 15200, offsetY = 4800 },  -- Western Plaguelands
        [1423] = { continent = 0, width = 4031, height = 2687, offsetX = 18200, offsetY = 4600 },  -- Eastern Plaguelands
        [1424] = { continent = 0, width = 3200, height = 2133, offsetX = 13800, offsetY = 7800 },  -- Hillsbrad Foothills
        [1425] = { continent = 0, width = 3850, height = 2566, offsetX = 17500, offsetY = 6800 },  -- The Hinterlands
        [1426] = { continent = 0, width = 4925, height = 3283, offsetX = 13000, offsetY = 14000 }, -- Dun Morogh
        [1427] = { continent = 0, width = 2231, height = 1487, offsetX = 15200, offsetY = 15800 }, -- Searing Gorge
        [1428] = { continent = 0, width = 2929, height = 1952, offsetX = 15400, offsetY = 17000 }, -- Burning Steppes
        [1429] = { continent = 0, width = 3470, height = 2314, offsetX = 13500, offsetY = 18500 }, -- Elwynn Forest
        [1430] = { continent = 0, width = 2499, height = 1666, offsetX = 15400, offsetY = 19500 }, -- Deadwind Pass
        [1431] = { continent = 0, width = 2700, height = 1800, offsetX = 13500, offsetY = 20500 }, -- Duskwood
        [1432] = { continent = 0, width = 2758, height = 1839, offsetX = 16200, offsetY = 13500 }, -- Loch Modan
        [1433] = { continent = 0, width = 2170, height = 1447, offsetX = 15500, offsetY = 18200 }, -- Redridge Mountains
        [1434] = { continent = 0, width = 6381, height = 4254, offsetX = 12800, offsetY = 22500 }, -- Stranglethorn Vale
        [1435] = { continent = 0, width = 2293, height = 1529, offsetX = 16800, offsetY = 19500 }, -- Swamp of Sorrows
        [1436] = { continent = 0, width = 3500, height = 2333, offsetX = 11200, offsetY = 19500 }, -- Westfall
        [1437] = { continent = 0, width = 4135, height = 2756, offsetX = 15000, offsetY = 10800 }, -- Wetlands
        [1453] = { continent = 0, width = 1737, height = 1158, offsetX = 13200, offsetY = 18100 }, -- Stormwind City
        [1455] = { continent = 0, width = 790,  height = 527,  offsetX = 14800, offsetY = 14400 }, -- Ironforge
        [1458] = { continent = 0, width = 959,  height = 640,  offsetX = 13800, offsetY = 5800 },  -- Undercity
        -- Kalimdor (Continent 1)
        [1411] = { continent = 1, width = 5287, height = 3525, offsetX = 19000, offsetY = 14000 }, -- Durotar
        [1412] = { continent = 1, width = 5137, height = 3425, offsetX = 13000, offsetY = 16000 }, -- Mulgore
        [1413] = { continent = 1, width = 10133, height = 6756, offsetX = 14500, offsetY = 14500 },-- The Barrens
        [1438] = { continent = 1, width = 5091, height = 3394, offsetX = 12000, offsetY = 2000 },  -- Teldrassil
        [1439] = { continent = 1, width = 6550, height = 4366, offsetX = 13500, offsetY = 5500 },  -- Darkshore
        [1440] = { continent = 1, width = 5766, height = 3843, offsetX = 15000, offsetY = 10500 }, -- Ashenvale
        [1441] = { continent = 1, width = 4400, height = 2933, offsetX = 16000, offsetY = 20500 }, -- Thousand Needles
        [1442] = { continent = 1, width = 4883, height = 3256, offsetX = 13000, offsetY = 12000 }, -- Stonetalon Mountains
        [1443] = { continent = 1, width = 4495, height = 2997, offsetX = 11500, offsetY = 14500 }, -- Desolace
        [1444] = { continent = 1, width = 6950, height = 4633, offsetX = 11500, offsetY = 17500 }, -- Feralas
        [1445] = { continent = 1, width = 5250, height = 3500, offsetX = 17500, offsetY = 17500 }, -- Dustwallow Marsh
        [1446] = { continent = 1, width = 6900, height = 4600, offsetX = 16500, offsetY = 22500 }, -- Tanaris
        [1447] = { continent = 1, width = 5070, height = 3380, offsetX = 19000, offsetY = 9500 },  -- Azshara
        [1448] = { continent = 1, width = 5750, height = 3833, offsetX = 15500, offsetY = 7000 },  -- Felwood
        [1449] = { continent = 1, width = 3700, height = 2466, offsetX = 14000, offsetY = 22500 }, -- Un'Goro Crater
        [1450] = { continent = 1, width = 2308, height = 1539, offsetX = 16500, offsetY = 5500 },  -- Moonglade
        [1451] = { continent = 1, width = 3483, height = 2322, offsetX = 11500, offsetY = 22500 }, -- Silithus
        [1452] = { continent = 1, width = 7100, height = 4733, offsetX = 17500, offsetY = 5000 },  -- Winterspring
        [1454] = { continent = 1, width = 1402, height = 935,  offsetX = 20100, offsetY = 13500 }, -- Orgrimmar
        [1456] = { continent = 1, width = 1043, height = 695,  offsetX = 14200, offsetY = 16200 }, -- Thunder Bluff
        [1457] = { continent = 1, width = 1058, height = 705,  offsetX = 12600, offsetY = 2800 },  -- Darnassus
    },
    ZONE_NAME_TO_ID = {
        ["alterac mountains"] = 1416, ["montañas de alterac"] = 1416,
        ["arathi highlands"] = 1417, ["tierras altas de arathi"] = 1417,
        ["badlands"] = 1418, ["tierras inhóspitas"] = 1418,
        ["blasted lands"] = 1419, ["las tierras devastadas"] = 1419,
        ["tirisfal glades"] = 1420, ["claros de tirisfal"] = 1420,
        ["silverpine forest"] = 1421, ["bosque de argénteos"] = 1421,
        ["western plaguelands"] = 1422, ["tierras de la peste del oeste"] = 1422,
        ["eastern plaguelands"] = 1423, ["tierras de la peste del este"] = 1423,
        ["hillsbrad foothills"] = 1424, ["laderas de trabalomas"] = 1424,
        ["the hinterlands"] = 1425, ["tierras del interior"] = 1425,
        ["dun morogh"] = 1426,
        ["searing gorge"] = 1427, ["la garganta de fuego"] = 1427,
        ["burning steppes"] = 1428, ["las estepas ardientes"] = 1428,
        ["elwynn forest"] = 1429, ["bosque de elwynn"] = 1429,
        ["deadwind pass"] = 1430, ["paso de la muerte"] = 1430,
        ["duskwood"] = 1431, ["bosque del ocaso"] = 1431,
        ["loch modan"] = 1432,
        ["redridge mountains"] = 1433, ["montañas crestagrana"] = 1433,
        ["stranglethorn vale"] = 1434, ["vega de tuercespina"] = 1434,
        ["swamp of sorrows"] = 1435, ["pantano de las penas"] = 1435,
        ["westfall"] = 1436, ["páramos de poniente"] = 1436,
        ["wetlands"] = 1437, ["los humedales"] = 1437,
        ["stormwind city"] = 1453, ["ventormenta"] = 1453,
        ["ironforge"] = 1455, ["forjaz"] = 1455,
        ["undercity"] = 1458, ["entrañas"] = 1458,
        ["durotar"] = 1411,
        ["mulgore"] = 1412,
        ["the barrens"] = 1413, ["los baldíos"] = 1413,
        ["teldrassil"] = 1438,
        ["darkshore"] = 1439, ["costa oscura"] = 1439,
        ["ashenvale"] = 1440, ["vallefresno"] = 1440,
        ["thousand needles"] = 1441, ["las mil agujas"] = 1441,
        ["stonetalon mountains"] = 1442, ["sierra espolón"] = 1442,
        ["desolace"] = 1443,
        ["feralas"] = 1444,
        ["dustwallow marsh"] = 1445, ["marjal revolcafango"] = 1445,
        ["tanaris"] = 1446,
        ["azshara"] = 1447,
        ["felwood"] = 1448, ["frondavil"] = 1448,
        ["un'goro crater"] = 1449, ["cráter de un'goro"] = 1449,
        ["moonglade"] = 1450, ["claro de la luna"] = 1450,
        ["silithus"] = 1451,
        ["winterspring"] = 1452, ["cuna del invierno"] = 1452,
        ["orgrimmar"] = 1454,
        ["thunder bluff"] = 1456, ["cima del trueno"] = 1456,
        ["darnassus"] = 1457,
    },
}
AR.Coords = Coords

function Coords:ResolveMapID(token)
    if not token then return nil end
    local num = tonumber(token)
    if num then return num end
    local clean = tostring(token):gsub("/%d+$", ""):match("^%s*(.-)%s*$"):lower()
    return self.ZONE_NAME_TO_ID[clean]
end

function Coords:GetPlayerPosition()
    local mapID = (_G.C_Map and _G.C_Map.GetBestMapForUnit and _G.C_Map.GetBestMapForUnit("player")) or 1420
    local pos = _G.C_Map and _G.C_Map.GetPlayerMapPosition and _G.C_Map.GetPlayerMapPosition(mapID, "player")
    local x, y = 0.5, 0.5
    if pos and pos.GetXY then
        x, y = pos:GetXY()
    end
    return mapID, x or 0.5, y or 0.5
end

local function normalizeCoord(x, y)
    if not x or not y then return nil, nil end
    if x > 1 then x = x / 100.0 end
    if y > 1 then y = y / 100.0 end
    return x, y
end

local function toHBDWorldYards(mapID, nx, ny)
    if not _G.LibStub then return nil, nil, nil end
    local hbd = _G.LibStub("HereBeDragons-2.0", true)
    if not hbd or not hbd.GetWorldCoordinatesFromZone then return nil, nil, nil end
    local hx, hy, inst = hbd:GetWorldCoordinatesFromZone(nx, ny, mapID)
    if not hx or not hy or not inst then return nil, nil, nil end
    -- HBD world space is (+West, +North); invert to (+East, +South) to preserve Coords & Pointer bearings.
    return inst, -hx, -hy
end

local function toNativeWorldYards(self, mapID, nx, ny)
    if not (_G.C_Map and _G.C_Map.GetWorldPosFromMapPos and _G.CreateVector2D) then
        return nil, nil, nil
    end
    local contID, worldPos = _G.C_Map.GetWorldPosFromMapPos(mapID, _G.CreateVector2D(nx, ny))
    if not (contID and worldPos and worldPos.GetXY) then
        return nil, nil, nil
    end
    local a, b = worldPos:GetXY()
    local isNorthWest = self.mapAxisCache[mapID]
    if isNorthWest == nil then
        local c0, wp0 = _G.C_Map.GetWorldPosFromMapPos(mapID, _G.CreateVector2D(0, 0))
        local c5, wp5 = _G.C_Map.GetWorldPosFromMapPos(mapID, _G.CreateVector2D(0.5, 0.5))
        if c0 and c5 and wp0 and wp5 then
            local a0, b0 = wp0:GetXY()
            local a5, b5 = wp5:GetXY()
            isNorthWest = (a0 > a5 and b0 > b5)
        else
            isNorthWest = true
        end
        self.mapAxisCache[mapID] = isNorthWest
    end
    if isNorthWest then
        return contID, -b, -a
    end
    return contID, a, b
end

local function toTableWorldYards(self, mapID, nx, ny)
    local b = self.ZONE_BOUNDS[mapID]
    if not b then return nil, nil, nil end
    local wx = b.offsetX + (nx * b.width)
    local wy = b.offsetY + (ny * b.height)
    return b.continent, wx, wy
end

local function toEstimatedWorldYards(self, mapID, nx, ny)
    return mapID, nx * self.ZONE_SCALE_YARDS, ny * self.ZONE_SCALE_YARDS
end

function Coords:ToWorldYards(mapID, x, y)
    local nx, ny = normalizeCoord(x, y)
    if not mapID or not nx or not ny then return nil, nil, nil end

    local c, wx, wy = toHBDWorldYards(mapID, nx, ny)
    if c ~= nil then return c, wx, wy end

    c, wx, wy = toNativeWorldYards(self, mapID, nx, ny)
    if c ~= nil then return c, wx, wy end

    c, wx, wy = toTableWorldYards(self, mapID, nx, ny)
    if c ~= nil then return c, wx, wy end

    return toEstimatedWorldYards(self, mapID, nx, ny)
end

-- Resolve both endpoints through the same coordinate provider so cross-zone math never mixes world spaces.
function Coords:GetWorldPair(map1, x1, y1, map2, x2, y2)
    local nx1, ny1 = normalizeCoord(x1, y1)
    local nx2, ny2 = normalizeCoord(x2, y2)
    if not map1 or not map2 or not nx1 or not ny1 or not nx2 or not ny2 then
        return nil, nil, nil, nil, nil, nil
    end

    local c1, wx1, wy1 = toHBDWorldYards(map1, nx1, ny1)
    local c2, wx2, wy2 = toHBDWorldYards(map2, nx2, ny2)
    if c1 ~= nil and c2 ~= nil then
        return c1, wx1, wy1, c2, wx2, wy2
    end

    c1, wx1, wy1 = toNativeWorldYards(self, map1, nx1, ny1)
    c2, wx2, wy2 = toNativeWorldYards(self, map2, nx2, ny2)
    if c1 ~= nil and c2 ~= nil then
        return c1, wx1, wy1, c2, wx2, wy2
    end

    c1, wx1, wy1 = toTableWorldYards(self, map1, nx1, ny1)
    c2, wx2, wy2 = toTableWorldYards(self, map2, nx2, ny2)
    if c1 ~= nil and c2 ~= nil then
        return c1, wx1, wy1, c2, wx2, wy2
    end

    c1, wx1, wy1 = toEstimatedWorldYards(self, map1, nx1, ny1)
    c2, wx2, wy2 = toEstimatedWorldYards(self, map2, nx2, ny2)
    return c1, wx1, wy1, c2, wx2, wy2
end

function Coords:GetDistanceBetween(map1, x1, y1, map2, x2, y2)
    local c1, wx1, wy1, c2, wx2, wy2 = self:GetWorldPair(map1, x1, y1, map2, x2, y2)
    if c1 == nil or c2 == nil or c1 ~= c2 then
        return nil
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
    local c1, wx1, wy1, c2, wx2, wy2 = self:GetWorldPair(pMap, px, py, targetMap or pMap, targetX, targetY)
    if c1 ~= nil and c2 ~= nil and c1 == c2 then
        return math.atan2(wx2 - wx1, -(wy2 - wy1))
    end
    return math.atan2(targetX - px, -(targetY - py))
end

return Coords
