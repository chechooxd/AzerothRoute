-- AzerothRoute: Classic flight-path nodes and fixed transports (boats, zeppelins, tram).
-- Names are the client's flight-path names before the comma (as TaxiTracker canonicalizes them).
-- Coordinates are approximate (uiMapID, 0..100); Journey snaps each node to the nearest flight
-- master in the generated database, so only transport docks keep these values as they are.
-- side: A Alliance, H Horde, B both.

local AR = _G.AzerothRoute
local TravelData = {}
AR.TravelData = TravelData

TravelData.TAXI_NODES = {
    -- Eastern Kingdoms, Alliance
    { name = "Stormwind", side = "A", map = 1453, x = 66.3, y = 62.1 },
    { name = "Ironforge", side = "A", map = 1455, x = 55.5, y = 47.7 },
    { name = "Sentinel Hill", side = "A", map = 1436, x = 56.6, y = 52.6 },
    { name = "Lakeshire", side = "A", map = 1433, x = 30.6, y = 59.4 },
    { name = "Darkshire", side = "A", map = 1431, x = 77.5, y = 44.3 },
    { name = "Thelsamar", side = "A", map = 1432, x = 33.9, y = 50.9 },
    { name = "Menethil Harbor", side = "A", map = 1437, x = 9.5, y = 59.7 },
    { name = "Refuge Pointe", side = "A", map = 1417, x = 45.8, y = 46.1 },
    { name = "Southshore", side = "A", map = 1424, x = 49.3, y = 52.3 },
    { name = "Aerie Peak", side = "A", map = 1425, x = 11.1, y = 46.2 },
    { name = "Morgan's Vigil", side = "A", map = 1428, x = 84.3, y = 68.3 },
    { name = "Nethergarde Keep", side = "A", map = 1419, x = 65.5, y = 24.3 },
    { name = "Booty Bay", side = "A", map = 1434, x = 27.5, y = 77.8 },
    { name = "Rebel Camp", side = "A", map = 1434, x = 38.2, y = 4.0 },
    { name = "Chillwind Camp", side = "A", map = 1422, x = 42.9, y = 85.1 },
    -- Eastern Kingdoms, Horde
    { name = "Undercity", side = "H", map = 1458, x = 63.3, y = 48.5 },
    { name = "The Sepulcher", side = "H", map = 1421, x = 45.6, y = 42.5 },
    { name = "Tarren Mill", side = "H", map = 1424, x = 60.1, y = 18.6 },
    { name = "Hammerfall", side = "H", map = 1417, x = 73.1, y = 32.7 },
    { name = "Revantusk Village", side = "H", map = 1425, x = 81.7, y = 81.8 },
    { name = "Kargath", side = "H", map = 1418, x = 4.0, y = 44.8 },
    { name = "Flame Crest", side = "H", map = 1428, x = 65.7, y = 24.2 },
    { name = "Grom'gol", side = "H", map = 1434, x = 32.5, y = 29.3 },
    { name = "Stonard", side = "H", map = 1435, x = 46.1, y = 54.8 },
    { name = "Booty Bay", side = "H", map = 1434, x = 26.9, y = 77.1 },
    -- Eastern Kingdoms, both
    { name = "Thorium Point", side = "B", map = 1427, x = 37.9, y = 30.9 },
    { name = "Light's Hope Chapel", side = "B", map = 1423, x = 81.6, y = 59.3 },
    -- Kalimdor, Alliance
    { name = "Rut'theran Village", side = "A", map = 1438, x = 58.4, y = 94.0 },
    { name = "Auberdine", side = "A", map = 1439, x = 36.3, y = 45.6 },
    { name = "Astranaar", side = "A", map = 1440, x = 34.4, y = 48.0 },
    { name = "Stonetalon Peak", side = "A", map = 1442, x = 36.4, y = 7.2 },
    { name = "Nijel's Point", side = "A", map = 1443, x = 64.7, y = 10.5 },
    { name = "Feathermoon", side = "A", map = 1444, x = 30.2, y = 43.3 },
    { name = "Thalanaar", side = "A", map = 1444, x = 89.5, y = 45.9 },
    { name = "Theramore", side = "A", map = 1445, x = 67.5, y = 51.3 },
    { name = "Talrendis Point", side = "A", map = 1447, x = 11.9, y = 77.6 },
    { name = "Talonbranch Glade", side = "A", map = 1448, x = 62.5, y = 24.2 },
    { name = "Moonglade", side = "A", map = 1450, x = 48.1, y = 67.4 },
    -- Kalimdor, Horde
    { name = "Orgrimmar", side = "H", map = 1454, x = 45.2, y = 63.9 },
    { name = "Crossroads", side = "H", map = 1413, x = 51.5, y = 30.3 },
    { name = "Thunder Bluff", side = "H", map = 1456, x = 47.0, y = 49.8 },
    { name = "Camp Taurajo", side = "H", map = 1413, x = 44.4, y = 59.2 },
    { name = "Sun Rock Retreat", side = "H", map = 1442, x = 45.1, y = 59.8 },
    { name = "Splintertree Post", side = "H", map = 1440, x = 73.2, y = 61.6 },
    { name = "Zoram'gar Outpost", side = "H", map = 1440, x = 12.2, y = 33.8 },
    { name = "Shadowprey Village", side = "H", map = 1443, x = 21.6, y = 74.1 },
    { name = "Camp Mojache", side = "H", map = 1444, x = 75.4, y = 44.4 },
    { name = "Freewind Post", side = "H", map = 1441, x = 45.1, y = 49.1 },
    { name = "Brackenwall Village", side = "H", map = 1445, x = 35.6, y = 31.9 },
    { name = "Valormok", side = "H", map = 1447, x = 22.0, y = 49.6 },
    { name = "Bloodvenom Post", side = "H", map = 1448, x = 34.4, y = 53.9 },
    { name = "Moonglade", side = "H", map = 1450, x = 44.3, y = 45.9 },
    -- Kalimdor, both
    { name = "Ratchet", side = "B", map = 1413, x = 63.1, y = 37.2 },
    { name = "Gadgetzan", side = "B", map = 1446, x = 51.0, y = 29.3 },
    { name = "Everlook", side = "B", map = 1452, x = 62.3, y = 36.6 },
    { name = "Cenarion Hold", side = "B", map = 1451, x = 50.6, y = 34.5 },
    { name = "Marshal's Refuge", side = "B", map = 1449, x = 45.2, y = 5.8 },
}

-- Fixed transports: two docks and the crossing time in seconds (waiting included on average).
TravelData.TRANSPORTS = {
    { mode = "boat", side = "A", seconds = 150,
        a = { name = "Menethil Harbor", map = 1437, x = 4.6, y = 57.2 },
        b = { name = "Theramore", map = 1445, x = 71.6, y = 56.4 } },
    { mode = "boat", side = "A", seconds = 150,
        a = { name = "Menethil Harbor", map = 1437, x = 4.8, y = 63.6 },
        b = { name = "Auberdine", map = 1439, x = 32.4, y = 43.8 } },
    { mode = "boat", side = "A", seconds = 120,
        a = { name = "Auberdine", map = 1439, x = 33.2, y = 40.2 },
        b = { name = "Rut'theran Village", map = 1438, x = 54.9, y = 96.8 } },
    { mode = "boat", side = "B", seconds = 150,
        a = { name = "Booty Bay", map = 1434, x = 25.9, y = 73.1 },
        b = { name = "Ratchet", map = 1413, x = 63.7, y = 38.6 } },
    { mode = "zeppelin", side = "H", seconds = 150,
        a = { name = "Orgrimmar", map = 1411, x = 50.8, y = 12.7 },
        b = { name = "Tirisfal Glades", map = 1420, x = 60.7, y = 58.8 } },
    { mode = "zeppelin", side = "H", seconds = 150,
        a = { name = "Orgrimmar", map = 1411, x = 51.4, y = 13.9 },
        b = { name = "Grom'gol", map = 1434, x = 31.5, y = 29.0 } },
    { mode = "zeppelin", side = "H", seconds = 150,
        a = { name = "Tirisfal Glades", map = 1420, x = 61.9, y = 59.0 },
        b = { name = "Grom'gol", map = 1434, x = 31.6, y = 30.3 } },
    { mode = "tram", side = "A", seconds = 90,
        a = { name = "Stormwind", map = 1453, x = 69.1, y = 30.8 },
        b = { name = "Ironforge", map = 1455, x = 76.6, y = 51.2 } },
}

return TravelData
