-- Integration checks load the unmodified upstream libraries against a deterministic WoW map API.
local T = require("Tests.run_tests")
local MockWoW = require("Tests.mock_wow_api")
local files = {
    "Libs/LibStub/LibStub.lua",
    "Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
    "Libs/HereBeDragons/HereBeDragons-2.0.lua",
}

local function withMaps(fn)
    MockWoW:Reset()
    local names = { "C_Map", "CreateVector2D", "Enum", "IsLoggedIn", "UnitPosition",
        "securecallfunction", "LibStub", "WOW_PROJECT_ID" }
    local saved = {}
    for _, name in ipairs(names) do saved[name] = _G[name] end
    local ok, err = pcall(function()
        local maps = {
            [1420] = { 2000, 4000, -1000, 2000, 0 },
            [1421] = { 1000, 4000, -3000, 2000, 0 },
            [1413] = { 2000, 4000, -1000, 2000, 1 },
        }
        local api = {}
        for k, v in pairs(saved.C_Map) do api[k] = v end
        _G.C_Map = api
        _G.CreateVector2D = function(x, y)
            return { x = x, y = y, GetXY = function() return x, y end }
        end
        api.GetMapInfo = function(id)
            if maps[id] then return { name = tostring(id), mapType = 3, parentMapID = 0 } end
        end
        api.GetMapChildrenInfo = function() return {} end
        api.GetWorldPosFromMapPos = function(id, v)
            local m = maps[id]
            if m then return m[5], CreateVector2D(m[4] - v.y * m[2], m[3] - v.x * m[1]) end
        end
        _G.Enum = { UIMapType = { Continent = 2, Zone = 3, Micro = 5 } }
        _G.IsLoggedIn = function() return false end
        _G.UnitPosition = function() return 0, -2000, 0, 0 end
        _G.securecallfunction = function(f, ...) return f(...) end
        _G.WOW_PROJECT_ID = _G.WOW_PROJECT_CAMELOT
        _G.LibStub = nil
        for _, path in ipairs(files) do dofile(path) end
        _G.AzerothRoute.Coords.mapAxisCache = {}
        fn(LibStub("HereBeDragons-2.0"))
    end)
    for _, name in ipairs(names) do _G[name] = saved[name] end
    _G.AzerothRoute.Coords.mapAxisCache = {}
    if not ok then error(err, 0) end
end

T:Describe("Upstream map libraries", function()
    T:It("loads pinned libraries before consumers in both TOC and test bootstrap", function()
        T:AssertTrue(_G.LibStub ~= nil, "Bootstrap must load actual libraries")
        local toc = assert(io.open("AzerothRoute.toc", "r"))
        local text = toc:read("*a"):gsub("\\", "/")
        toc:close()
        local previous = 0
        for _, path in ipairs(files) do
            local pos = assert(text:find(path, 1, true), "Missing TOC entry: " .. path)
            T:AssertTrue(pos > previous, "Dependencies must load in order")
            previous = pos
        end
        T:AssertTrue(previous < text:find("Spatial/Coords.lua", 1, true))
        withMaps(function(hbd)
            T:AssertTrue(LibStub("CallbackHandler-1.0") ~= nil)
            T:AssertEqual(LibStub.minors["HereBeDragons-2.0"], 35)
            T:AssertEqual(next(hbd.transforms), nil, "Forever must not load retail transforms")
            dofile(files[3])
            T:AssertEqual(LibStub("HereBeDragons-2.0"), hbd, "Duplicate load must reuse the registry")
        end)
    end)

    T:It("adapts real HBD axes and percentages for distance, bearing and minimap consumers", function()
        withMaps(function()
            local AR = _G.AzerothRoute
            MockWoW.player.mapID, MockWoW.player.x, MockWoW.player.y = 1420, 0.5, 0.5
            _G.C_Map.GetWorldPosFromMapPos = function() error("Must use cached HBD data") end
            local c, east, south = AR.Coords:ToWorldYards(1420, 60, 50)
            T:AssertEqual(c, 0)
            T:AssertEqual(east, 2200)
            T:AssertEqual(south, 0)
            T:AssertEqual(AR.Coords:GetDistanceTo(1420, 0.6, 0.5), 200)
            T:AssertEqual(AR.Coords:GetDistanceBetween(1420, 0.5, 0.5, 1421, 0.2, 0.5), 1200)
            T:AssertEqual(AR.Coords:GetDistanceTo(1413, 0.6, 0.5), nil)
            T:AssertEqual(AR.Coords:GetBearingTo(1420, 0.6, 0.5), math.pi / 2)
            AR.Pointer:Reset()
            AR.Pointer:InitializeFrames()
            AR.Pointer:PlaceStepPins({
                { map = 1420, x = 0.51, y = 0.50, title = "East", action = "goto" },
                { map = 1413, x = 0.51, y = 0.50, title = "Other continent", action = "goto" },
            })
            local pin = AR.Pointer.minimapPinFrames[1]
            local _, _, _, x, y = pin:GetPoint()
            T:AssertTrue(pin:IsShown() and x > 0 and math.abs(y) < 0.00001)
            T:AssertFalse(AR.Pointer.minimapPinFrames[2]:IsShown())
        end)
    end)

    T:It("falls back as a pair without mixing HBD, native and estimated coordinate spaces", function()
        withMaps(function(hbd)
            local coords = _G.AzerothRoute.Coords
            hbd.mapData[1420][3] = 90000
            hbd.mapData[1421] = nil
            T:AssertEqual(coords:GetDistanceBetween(1420, 0.5, 0.5, 1421, 0.2, 0.5), 1200)
            _G.C_Map.GetWorldPosFromMapPos = nil
            local c1, x1, y1, c2, x2, y2 = coords:GetWorldPair(1420, 0.5, 0.5, 1421, 0.2, 0.5)
            _G.LibStub = nil
            local b1, bx1, by1 = coords:ToWorldYards(1420, 0.5, 0.5)
            local b2, bx2, by2 = coords:ToWorldYards(1421, 0.2, 0.5)
            T:AssertEqual(c1, b1); T:AssertEqual(x1, bx1); T:AssertEqual(y1, by1)
            T:AssertEqual(c2, b2); T:AssertEqual(x2, bx2); T:AssertEqual(y2, by2)
            T:AssertEqual(coords:GetDistanceBetween(1420, 0.5, 0.5, 1421, 0.2, 0.5),
                math.sqrt((bx2 - bx1)^2 + (by2 - by1)^2))
            T:AssertEqual(coords:ToWorldYards(nil, 0, 0), nil)
            local unknown, ux, uy = coords:ToWorldYards(9999, 20, 30)
            T:AssertEqual(unknown, 9999); T:AssertEqual(ux, 200); T:AssertEqual(uy, 300)
        end)
    end)
end)

if arg and arg[0] and arg[0]:find("test_map_libraries%.lua") then
    T:BootstrapAddon()
    for _, suite in ipairs(T.suites) do suite.fn(T) end
    print(string.format("Summary: %d passed, %d failed", T.passed, T.failed))
    if T.failed > 0 then os.exit(1) end
end
