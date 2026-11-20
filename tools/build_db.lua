-- AzerothRoute database generator.
-- Reads pfQuest's Classic Era tables (MIT, https://github.com/shagu/pfQuest) and writes the
-- compact string-encoded tables under DB/ that Lookup and Dungeons read at runtime.
--
-- Usage (from the repository root):
--   luajit tools/build_db.lua <path-to-pfQuest/db>
--
-- Record formats (fields separated by "^"; lists by ","):
--   Quests[id]  = "lvl^min^side^starts^ends^objUnits^objItems^objObjects"
--                 side: A, H or B; starts/ends: "U123,O45,I678" (unit/object/item ids)
--   QuestNames[id] = title
--   Units[id]   = "name^level^side^map^x^y^flags"   (map = uiMapID, 0 when unknown; flags: v r i f b a s, x = rare)
--   Objects[id] = "name^map^x^y^flags"          (flags: m = mailbox)
--   Items[id]   = "name^drops^vendors^objects^kind"  (top sources; kind: R recipe, M mount, Q quest item, '')
--   Dungeons    = hand-written facts in DB/Dungeons.lua plus generated DungeonQuests / DungeonUnits.

local SRC = arg[1]
assert(SRC, "usage: luajit tools/build_db.lua <pfQuest/db>")
local OUT = "DB"

-- Loads one pfQuest data file into `pfDB` inside an environment that exposes nothing else.
-- pfQuest files are one huge table literal, beyond LuaJIT's 65536-constant limit per chunk, so
-- each file is split on its top-level entries ("  [id] = ...") and compiled in batches.
local pfDB = { quests = {}, units = {}, objects = {}, items = {}, zones = {}, meta = {} }
local BATCH = 2000
local function load(rel)
    local fh = assert(io.open(SRC .. "/" .. rel, "r"))
    local text = fh:read("*a")
    fh:close()
    local lines = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = (line:gsub("\r$", "")) end
    local a, b = lines[1]:match('^pfDB%["(%w+)"%]%["?(%w*)"?%]? = {$')
    if not a then a = lines[1]:match('^pfDB%["(%w+)"%] = {$') end
    assert(a, "unexpected header in " .. rel .. ": " .. lines[1])
    local target = {}
    if b and b ~= "" then pfDB[a][b] = target else pfDB[a] = target end

    local entries, cur = {}, nil
    local function flush()
        if not cur then return end
        cur[#cur] = cur[#cur]:gsub(",%s*$", "")
        entries[#entries + 1] = table.concat(cur, "\n")
        cur = nil
    end
    for i = 2, #lines do
        local line = lines[i]
        local key, rest = line:match("^  (%[[^%]]+%]) = (.*)$")
        if key then
            flush()
            cur = { "T" .. key .. " = " .. rest }
        elseif line == "}" then
            flush()
        elseif cur then
            cur[#cur + 1] = line
        end
    end
    flush()
    for s = 1, #entries, BATCH do
        local code = "local T = ...\n" .. table.concat(entries, "\n", s, math.min(#entries, s + BATCH - 1))
        local chunk = assert(loadstring(code, "=" .. rel))
        setfenv(chunk, {})
        chunk(target)
    end
end
for _, f in ipairs({ "quests.lua", "units.lua", "objects.lua", "items.lua", "meta.lua",
    "enUS/quests.lua", "enUS/units.lua", "enUS/objects.lua", "enUS/items.lua", "enUS/zones.lua",
    "esES/quests.lua", "esES/units.lua", "esES/objects.lua", "esES/items.lua", "esES/zones.lua" }) do
    load(f)
end

-- AreaTable zone id -> Classic Era uiMapID (outdoor zones and capitals; instances stay unmapped).
local AREA_TO_UIMAP = {
    [1] = 1426, [3] = 1418, [4] = 1419, [8] = 1435, [10] = 1431, [11] = 1437, [12] = 1429,
    [14] = 1411, [15] = 1445, [16] = 1447, [17] = 1413, [28] = 1422, [33] = 1434, [36] = 1416,
    [38] = 1432, [40] = 1436, [41] = 1430, [44] = 1433, [45] = 1417, [46] = 1428, [47] = 1425,
    [51] = 1427, [85] = 1420, [130] = 1421, [139] = 1423, [141] = 1438, [148] = 1439,
    [215] = 1412, [267] = 1424, [331] = 1440, [357] = 1444, [361] = 1448, [400] = 1441,
    [405] = 1443, [406] = 1442, [440] = 1446, [490] = 1449, [493] = 1450, [618] = 1452,
    [1377] = 1451, [1497] = 1458, [1519] = 1453, [1537] = 1455, [1637] = 1454, [1638] = 1456,
    [1657] = 1457,
}

local ALLIANCE_MASK, HORDE_MASK = 77, 178
local function sideOfRace(mask)
    if not mask or mask == 0 or mask == 255 then return "B" end
    local a = bit.band(mask, ALLIANCE_MASK) ~= 0
    local h = bit.band(mask, HORDE_MASK) ~= 0
    if a and h then return "B" end
    return a and "A" or (h and "H" or "B")
end
local function sideOfFac(fac)
    if fac == "A" then return "A" elseif fac == "H" then return "H" end
    return "B"
end

local function clean(s)
    return (tostring(s or ""):gsub("[%^\r\n]", " "))
end
local function q(s) return string.format("%q", s) end

-- Best spawn: the coordinate whose zone has a uiMap, else the first one.
local function bestCoord(coords)
    if type(coords) ~= "table" then return 0, 0, 0, nil end
    local first
    for _, c in ipairs(coords) do
        first = first or c
        if AREA_TO_UIMAP[c[3]] then return AREA_TO_UIMAP[c[3]], c[1], c[2], c[3] end
    end
    if first then return 0, first[1], first[2], first[3] end
    return 0, 0, 0, nil
end

local function writeTable(path, header, name, rows, ids)
    local fh = assert(io.open(path, "w"))
    fh:write(header)
    fh:write("local DB = _G.AzerothRoute.DB\nDB." .. name .. " = {\n")
    for _, id in ipairs(ids) do
        fh:write("[" .. id .. "]=" .. q(rows[id]) .. ",\n")
    end
    fh:write("}\n")
    fh:close()
end
local function sortedKeys(t)
    local ids = {}
    for k in pairs(t) do ids[#ids + 1] = k end
    table.sort(ids)
    return ids
end

local HEADER = "-- Generated by tools/build_db.lua from pfQuest (MIT, see DB/LICENSE-pfQuest.txt). Do not edit.\n"

-- Service flags from pfQuest meta lists.
local FLAG_OF = { vendor = "v", repair = "r", innkeeper = "i", flight = "f", banker = "b",
    auctioneer = "a", stablemaster = "s", rares = "x" }
local unitFlags = {}
for list, flag in pairs(FLAG_OF) do
    for id in pairs(pfDB.meta[list] or {}) do
        unitFlags[id] = (unitFlags[id] or "") .. flag
    end
end

-- Units ---------------------------------------------------------------------------------------
local units, unitArea = {}, {}
for id, d in pairs(pfDB.units.data) do
    local name = pfDB.units.enUS[id]
    if name and name ~= "" then
        local map, x, y, area = bestCoord(d.coords)
        unitArea[id] = area
        units[id] = table.concat({ clean(name), clean(d.lvl or ""), sideOfFac(d.fac), map, x, y, unitFlags[id] or "" }, "^")
    end
end

-- Objects -------------------------------------------------------------------------------------
-- Mailboxes are listed in pfQuest meta under negative object ids.
local mailbox = {}
for id in pairs(pfDB.meta.mailbox or {}) do mailbox[math.abs(id)] = true end
local objects, objectArea = {}, {}
for id, d in pairs(pfDB.objects.data) do
    local name = pfDB.objects.enUS[id]
    if name and name ~= "" and type(d.coords) == "table" and #d.coords > 0 then
        local map, x, y, area = bestCoord(d.coords)
        objectArea[id] = area
        objects[id] = table.concat({ clean(name), map, x, y, mailbox[id] and "m" or "" }, "^")
    end
end

-- Quests --------------------------------------------------------------------------------------
local function refs(t)
    local out = {}
    for _, kind in ipairs({ "U", "O", "I" }) do
        for _, id in ipairs((t and t[kind]) or {}) do out[#out + 1] = kind .. id end
    end
    return table.concat(out, ",")
end
local function idList(list)
    local out = {}
    for _, id in ipairs(list or {}) do out[#out + 1] = tostring(id) end
    return table.concat(out, ",")
end
local quests, questNames, questItems = {}, {}, {}
for id, d in pairs(pfDB.quests.data) do
    local loc = pfDB.quests.enUS[id]
    local title = loc and loc.T
    if title and title ~= "" and not title:find("UNUSED", 1, true) and not title:find("%[") then
        local obj = d.obj or {}
        quests[id] = table.concat({ d.lvl or 0, d.min or 0, sideOfRace(d.race), refs(d.start), refs(d["end"]),
            idList(obj.U), idList(obj.I), idList(obj.O) }, "^")
        questNames[id] = clean(title)
        for _, iid in ipairs(obj.I or {}) do questItems[iid] = true end
    end
end

-- Items ---------------------------------------------------------------------------------------
local RECIPE_PREFIX = { "^Recipe:", "^Pattern:", "^Plans:", "^Formula:", "^Schematic:", "^Manual:" }
local MOUNT_NAMES = { "^Reins of", "^Horn of the", "^Whistle of the", "Mechanostrider$", "^Skeletal ",
    "Bridle$", "^Swift .*Ram$", "Ram$", "Raptor$", "Kodo$", "Steed$", "Palomino$", "Pinto$",
    "Stallion$", "Nightsaber$", "Frostsaber$", "Mistsaber$", "Stormsaber$", "Wolf$", "Warhorse$",
    "Charger$", "Battle Tank$", "Qiraji Resonating Crystal$" }
local function itemKind(name, id)
    for _, p in ipairs(RECIPE_PREFIX) do if name:find(p) then return "R" end end
    for _, p in ipairs(MOUNT_NAMES) do if name:find(p) then return "M" end end
    if questItems[id] then return "Q" end
    return ""
end
local function topSources(t, n)
    local list = {}
    for sid, chance in pairs(t or {}) do list[#list + 1] = { sid, tonumber(chance) or 0 } end
    table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
    local out = {}
    for i = 1, math.min(n, #list) do out[#out + 1] = tostring(list[i][1]) end
    return table.concat(out, ",")
end
local items = {}
for id, d in pairs(pfDB.items.data) do
    local name = pfDB.items.enUS[id]
    if name and name ~= "" and not name:find("^OLD") and not name:find("^Deprecated") and not name:find("^TEST") then
        local drops, vendors, objs = topSources(d.U, 3), topSources(d.V, 3), topSources(d.O, 2)
        local kind = itemKind(name, id)
        if drops ~= "" or vendors ~= "" or objs ~= "" or kind ~= "" then
            items[id] = table.concat({ clean(name), drops, vendors, objs, kind }, "^")
        end
    end
end

-- Spanish names (loaded only on esES/esMX clients) --------------------------------------------
local es = { quests = {}, units = {}, objects = {}, items = {} }
for id in pairs(questNames) do
    local loc = pfDB.quests.esES[id]
    if loc and loc.T and loc.T ~= "" and loc.T ~= pfDB.quests.enUS[id].T then es.quests[id] = clean(loc.T) end
end
for kind, src in pairs({ units = units, objects = objects, items = items }) do
    for id in pairs(src) do
        local n = pfDB[kind].esES[id]
        if n and n ~= "" and n ~= pfDB[kind].enUS[id] then es[kind][id] = clean(n) end
    end
end

-- Dungeon membership. pfQuest keeps no coordinates for instance creatures, so a quest belongs to a
-- dungeon when its objective text names it, or when its description names it and an objective is
-- a creature (or an item dropped only by creatures) with no open-world spawn.
local dungeonDefs = dofile("DB/DungeonDefs.lua")
local dungeonUnits, dungeonQuests = {}, {}
local function hasSpawn(uid)
    local u = pfDB.units.data[uid]
    return u and type(u.coords) == "table" and #u.coords > 0
end
local function instanceObjective(obj)
    for _, u in ipairs(obj.U or {}) do if not hasSpawn(u) then return true end end
    for _, iid in ipairs(obj.I or {}) do
        local drops, open = 0, false
        for u in pairs(((pfDB.items.data[iid] or {}).U) or {}) do
            drops = drops + 1
            if hasSpawn(u) then open = true end
        end
        if drops > 0 and not open then return true end
    end
    return false
end
local function mentions(text, dg)
    if not text then return false end
    for _, m in ipairs(dg.match or {}) do
        if text:find(m, 1, true) then return true end
    end
    return false
end
for id, d in pairs(pfDB.quests.data) do
    local loc = pfDB.quests.enUS[id]
    if quests[id] and loc then
        local key
        for _, dg in ipairs(dungeonDefs) do
            if mentions(loc.O, dg) then key = dg.key break end
        end
        local inside = instanceObjective(d.obj or {})
        if not key and inside then
            for _, dg in ipairs(dungeonDefs) do
                if mentions(loc.D, dg) then key = dg.key break end
            end
        end
        -- Last rule: an instance objective given in the zone that holds a dungeon of the quest's
        -- level (closest level band wins when a zone has several, e.g. The Barrens).
        if not key and inside and d.start and d.start.U then
            local giver = pfDB.units.data[d.start.U[1]]
            local map = giver and bestCoord(giver.coords)
            local lvl, best, bestGap = d.lvl or 0, nil, math.huge
            for _, dg in ipairs(dungeonDefs) do
                if dg.zone == map and lvl >= dg.min - 3 and lvl <= dg.max + 2 then
                    local gap = math.abs(lvl - (dg.min + dg.max) / 2)
                    if gap < bestGap then best, bestGap = dg.key, gap end
                end
            end
            key = best
        end
        if key then
            dungeonQuests[key] = dungeonQuests[key] or {}
            table.insert(dungeonQuests[key], id)
        end
    end
end

-- Write ---------------------------------------------------------------------------------------
writeTable(OUT .. "/Units.lua", HEADER, "Units", units, sortedKeys(units))
writeTable(OUT .. "/Objects.lua", HEADER, "Objects", objects, sortedKeys(objects))
writeTable(OUT .. "/Items.lua", HEADER, "Items", items, sortedKeys(items))
writeTable(OUT .. "/Quests.lua", HEADER, "Quests", quests, sortedKeys(quests))
writeTable(OUT .. "/QuestNames.lua", HEADER, "QuestNames", questNames, sortedKeys(questNames))

do
    local fh = assert(io.open(OUT .. "/Names_esES.lua", "w"))
    fh:write(HEADER)
    fh:write("local loc = _G.GetLocale and _G.GetLocale()\nif loc ~= \"esES\" and loc ~= \"esMX\" then return end\n")
    fh:write("local DB = _G.AzerothRoute.DB\nDB.NamesES = { quests = {}, units = {}, objects = {}, items = {} }\n")
    for _, kind in ipairs({ "quests", "units", "objects", "items" }) do
        fh:write("DB.NamesES." .. kind .. " = {\n")
        for _, id in ipairs(sortedKeys(es[kind])) do fh:write("[" .. id .. "]=" .. q(es[kind][id]) .. ",\n") end
        fh:write("}\n")
    end
    fh:close()
end

do
    local fh = assert(io.open(OUT .. "/DungeonData.lua", "w"))
    fh:write(HEADER)
    fh:write("local DB = _G.AzerothRoute.DB\nDB.DungeonQuests = {\n")
    for _, key in ipairs(sortedKeys(dungeonQuests)) do
        table.sort(dungeonQuests[key])
        fh:write("[" .. q(key) .. "]={" .. table.concat(dungeonQuests[key], ",") .. "},\n")
    end
    fh:write("}\nDB.DungeonUnitCount = {\n")
    for _, key in ipairs(sortedKeys(dungeonUnits)) do
        fh:write("[" .. q(key) .. "]=" .. #dungeonUnits[key] .. ",\n")
    end
    fh:write("}\n")
    fh:close()
end

local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
print(string.format("units %d, objects %d, items %d, quests %d, es names %d/%d/%d/%d, dungeons with quests %d",
    count(units), count(objects), count(items), count(quests),
    count(es.quests), count(es.units), count(es.objects), count(es.items), count(dungeonQuests)))
