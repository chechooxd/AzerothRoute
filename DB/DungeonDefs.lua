-- AzerothRoute: hand-written dungeon and raid facts (names, level ranges, where the entrance is).
-- `areas` are the AreaTable names tools/build_db.lua uses to attach units and quests to each one.
-- `zone` is the uiMapID of the outdoor zone holding the entrance; `side` is who owns that ground
-- (A/H for capital-city instances, B elsewhere).

local DEFS = {
    { key = "RFC", name = "Ragefire Chasm", nameES = "Sima Ígnea", min = 13, max = 18, zone = 1454, side = "H", areas = { "Ragefire Chasm" }, match = { "Ragefire Chasm" } },
    { key = "WC", name = "Wailing Caverns", nameES = "Cuevas de los Lamentos", min = 17, max = 24, zone = 1413, side = "B", areas = { "Wailing Caverns" }, match = { "Wailing Caverns" } },
    { key = "DM", name = "The Deadmines", nameES = "Las Minas de la Muerte", min = 17, max = 26, zone = 1436, side = "B", areas = { "The Deadmines" }, match = { "Deadmines" } },
    { key = "SFK", name = "Shadowfang Keep", nameES = "Castillo de Colmillo Oscuro", min = 22, max = 30, zone = 1421, side = "B", areas = { "Shadowfang Keep" }, match = { "Shadowfang Keep" } },
    { key = "BFD", name = "Blackfathom Deeps", nameES = "Cavernas de Brazanegra", min = 24, max = 32, zone = 1440, side = "B", areas = { "Blackfathom Deeps" }, match = { "Blackfathom Deeps" } },
    { key = "STOCKS", name = "The Stockade", nameES = "Las Mazmorras", min = 24, max = 32, zone = 1453, side = "A", areas = { "The Stockade" }, match = { "Stockade" } },
    { key = "GNOMER", name = "Gnomeregan", nameES = "Gnomeregan", min = 29, max = 38, zone = 1426, side = "B", areas = { "Gnomeregan" }, match = { "Gnomeregan" } },
    { key = "RFK", name = "Razorfen Kraul", nameES = "Horado Rajacieno", min = 29, max = 38, zone = 1413, side = "B", areas = { "Razorfen Kraul" }, match = { "Razorfen Kraul" } },
    { key = "SM", name = "Scarlet Monastery", nameES = "Monasterio Escarlata", min = 34, max = 45, zone = 1420, side = "B", areas = { "Scarlet Monastery" }, match = { "Scarlet Monastery" } },
    { key = "RFD", name = "Razorfen Downs", nameES = "Zahúrda Rajacieno", min = 37, max = 46, zone = 1413, side = "B", areas = { "Razorfen Downs" }, match = { "Razorfen Downs" } },
    { key = "ULDA", name = "Uldaman", nameES = "Uldaman", min = 41, max = 51, zone = 1418, side = "B", areas = { "Uldaman" }, match = { "Uldaman" } },
    { key = "ZF", name = "Zul'Farrak", nameES = "Zul'Farrak", min = 44, max = 54, zone = 1446, side = "B", areas = { "Zul'Farrak" }, match = { "Zul'Farrak" } },
    { key = "MARA", name = "Maraudon", nameES = "Maraudon", min = 46, max = 55, zone = 1443, side = "B", areas = { "Maraudon" }, match = { "Maraudon" } },
    { key = "ST", name = "The Temple of Atal'Hakkar", nameES = "El Templo de Atal'Hakkar", min = 50, max = 56, zone = 1435, side = "B", areas = { "The Temple of Atal'Hakkar", "Sunken Temple" }, match = { "Atal'Hakkar", "Sunken Temple" } },
    { key = "BRD", name = "Blackrock Depths", nameES = "Profundidades de Roca Negra", min = 52, max = 60, zone = 1428, side = "B", areas = { "Blackrock Depths" }, match = { "Blackrock Depths" } },
    { key = "BRS", name = "Blackrock Spire", nameES = "Cumbre de Roca Negra", min = 55, max = 60, zone = 1428, side = "B", areas = { "Blackrock Spire" }, match = { "Blackrock Spire" } },
    { key = "DIRE", name = "Dire Maul", nameES = "La Masacre", min = 55, max = 60, zone = 1444, side = "B", areas = { "Dire Maul" }, match = { "Dire Maul" } },
    { key = "SCHOLO", name = "Scholomance", nameES = "Scholomance", min = 58, max = 60, zone = 1422, side = "B", areas = { "Scholomance" }, match = { "Scholomance" } },
    { key = "STRAT", name = "Stratholme", nameES = "Stratholme", min = 58, max = 60, zone = 1423, side = "B", areas = { "Stratholme" }, match = { "Stratholme" } },
    { key = "MC", name = "Molten Core", nameES = "Núcleo de Magma", min = 60, max = 60, zone = 1428, side = "B", raid = true, areas = { "Molten Core" }, match = { "Molten Core" } },
    { key = "ONY", name = "Onyxia's Lair", nameES = "Guarida de Onyxia", min = 60, max = 60, zone = 1445, side = "B", raid = true, areas = { "Onyxia's Lair" }, match = { "Onyxia" } },
    { key = "ZG", name = "Zul'Gurub", nameES = "Zul'Gurub", min = 60, max = 60, zone = 1434, side = "B", raid = true, areas = { "Zul'Gurub" }, match = { "Zul'Gurub" } },
    { key = "BWL", name = "Blackwing Lair", nameES = "Guarida Alanegra", min = 60, max = 60, zone = 1428, side = "B", raid = true, areas = { "Blackwing Lair" }, match = { "Blackwing Lair" } },
    { key = "AQ20", name = "Ruins of Ahn'Qiraj", nameES = "Ruinas de Ahn'Qiraj", min = 60, max = 60, zone = 1451, side = "B", raid = true, areas = { "Ruins of Ahn'Qiraj" }, match = { "Ruins of Ahn'Qiraj" } },
    { key = "AQ40", name = "Temple of Ahn'Qiraj", nameES = "Templo de Ahn'Qiraj", min = 60, max = 60, zone = 1451, side = "B", raid = true, areas = { "Ahn'Qiraj" }, match = { "Temple of Ahn'Qiraj" } },
    { key = "NAXX", name = "Naxxramas", nameES = "Naxxramas", min = 60, max = 60, zone = 1423, side = "B", raid = true, areas = { "Naxxramas" }, match = { "Naxxramas" } },
}

local AR = rawget(_G, "AzerothRoute")
if AR then
    AR.DB = AR.DB or {}
    AR.DB.Dungeons = DEFS
end
return DEFS
