-- AzerothRoute: read access to the generated database (DB/*.lua, built by tools/build_db.lua).
-- Records are "^"-separated strings decoded on demand, so the tables stay small in memory.

local AR = _G.AzerothRoute
local DB = AR.DB or {}
AR.DB = DB

local SEP = "%^"

local function split(s)
    local out, i = {}, 1
    for field in (s .. "^"):gmatch("([^^]*)" .. SEP) do
        out[i] = field
        i = i + 1
    end
    return out
end

local function idList(s)
    local out = {}
    for id in (s or ""):gmatch("%d+") do out[#out + 1] = tonumber(id) end
    return out
end

local function refList(s)
    local out = {}
    for kind, id in (s or ""):gmatch("(%a)(%d+)") do out[#out + 1] = { kind = kind, id = tonumber(id) } end
    return out
end

local function isSpanish()
    return DB.NamesES ~= nil and AR.L and AR.L.IsSpanish and AR.L:IsSpanish()
end

-- Localized display name for a record kind ("quests", "units", "objects", "items").
function DB:LocalName(kind, id, english)
    if isSpanish() then
        local es = DB.NamesES[kind] and DB.NamesES[kind][id]
        if es then return es end
    end
    return english
end

function DB:GetUnit(id)
    local raw = DB.Units and DB.Units[id]
    if not raw then return nil end
    local f = split(raw)
    return {
        kind = "npc", id = id, name = self:LocalName("units", id, f[1]), level = f[2], side = f[3],
        map = tonumber(f[4]) or 0, x = tonumber(f[5]) or 0, y = tonumber(f[6]) or 0, flags = f[7] or "",
    }
end

function DB:GetObject(id)
    local raw = DB.Objects and DB.Objects[id]
    if not raw then return nil end
    local f = split(raw)
    return { kind = "object", id = id, name = self:LocalName("objects", id, f[1]),
        map = tonumber(f[2]) or 0, x = tonumber(f[3]) or 0, y = tonumber(f[4]) or 0 }
end

function DB:GetItem(id)
    local raw = DB.Items and DB.Items[id]
    if not raw then return nil end
    local f = split(raw)
    local kind = ({ R = "recipe", M = "mount" })[f[5]] or "item"
    return { kind = kind, id = id, name = self:LocalName("items", id, f[1]),
        drops = idList(f[2]), vendors = idList(f[3]), objects = idList(f[4]), questItem = f[5] == "Q" }
end

function DB:GetQuest(id)
    local raw = DB.Quests and DB.Quests[id]
    local title = DB.QuestNames and DB.QuestNames[id]
    if not raw or not title then return nil end
    local f = split(raw)
    return {
        kind = "quest", id = id, name = self:LocalName("quests", id, title),
        level = tonumber(f[1]) or 0, minLevel = tonumber(f[2]) or 0, side = f[3],
        starts = refList(f[4]), ends = refList(f[5]),
        objUnits = idList(f[6]), objItems = idList(f[7]), objObjects = idList(f[8]),
    }
end

-- Where a record can be found: { map, x (0..1), y (0..1), name } or nil.
function DB:LocationOf(rec)
    if not rec then return nil end
    if (rec.kind == "npc" or rec.kind == "object") and rec.map and rec.map > 0 then
        return { map = rec.map, x = rec.x / 100, y = rec.y / 100, name = rec.name }
    end
    if rec.kind == "quest" then
        for _, ref in ipairs(rec.starts or {}) do
            local src = (ref.kind == "U" and self:GetUnit(ref.id)) or (ref.kind == "O" and self:GetObject(ref.id)) or nil
            local loc = self:LocationOf(src)
            if loc then return loc end
        end
    end
    if rec.kind == "item" or rec.kind == "recipe" or rec.kind == "mount" then
        for _, list in ipairs({ { rec.vendors, "GetUnit" }, { rec.drops, "GetUnit" }, { rec.objects, "GetObject" } }) do
            for _, sid in ipairs(list[1] or {}) do
                local loc = self:LocationOf(self[list[2]](self, sid))
                if loc then return loc end
            end
        end
    end
    return nil
end

local function playerSide()
    local f = _G.UnitFactionGroup and _G.UnitFactionGroup("player")
    if f == "Alliance" then return "A" elseif f == "Horde" then return "H" end
    return nil
end

-- True when a record's side is open to the player (B = both, unknown faction = everything).
function DB:IsForPlayer(side)
    local me = playerSide()
    return not me or side == nil or side == "" or side == "B" or side == me
end

-- Name search over every table. kinds: set of "quest","npc","item","mount","recipe","object" (nil = all).
-- Returns results sorted prefix-first then alphabetically; each { kind, id, name }.
function DB:Search(query, kinds, limit)
    local q = tostring(query or ""):lower()
    if #q < 2 then return {} end
    limit = limit or 500
    local results = {}
    local function want(kind) return not kinds or kinds[kind] end
    local function consider(kind, id, name)
        local lower = name:lower()
        local at = lower:find(q, 1, true)
        if at then results[#results + 1] = { kind = kind, id = id, name = name, prefix = at == 1 } end
    end
    if want("quest") then
        for id, title in pairs(DB.QuestNames or {}) do
            consider("quest", id, self:LocalName("quests", id, title))
        end
    end
    if want("npc") then
        for id, raw in pairs(DB.Units or {}) do
            consider("npc", id, self:LocalName("units", id, raw:match("^[^^]*")))
        end
    end
    if want("object") then
        for id, raw in pairs(DB.Objects or {}) do
            consider("object", id, self:LocalName("objects", id, raw:match("^[^^]*")))
        end
    end
    if want("item") or want("mount") or want("recipe") then
        for id, raw in pairs(DB.Items or {}) do
            local tag = raw:match("%^([RMQ]?)$") or ""
            local kind = (tag == "R" and "recipe") or (tag == "M" and "mount") or "item"
            if want(kind) then consider(kind, id, self:LocalName("items", id, raw:match("^[^^]*"))) end
        end
    end
    table.sort(results, function(a, b)
        if a.prefix ~= b.prefix then return a.prefix end
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    for i = limit + 1, #results do results[i] = nil end
    return results
end

-- Dungeon list with quest counts; each def gets `quests` (ids) from the generated data.
function DB:GetDungeons()
    local list = {}
    for _, d in ipairs(DB.Dungeons or {}) do
        local qs = (DB.DungeonQuests and DB.DungeonQuests[d.key]) or {}
        list[#list + 1] = setmetatable({ quests = qs }, { __index = d })
    end
    return list
end

function DB:DungeonName(d)
    if isSpanish() or (AR.L and AR.L.IsSpanish and AR.L:IsSpanish()) then return d.nameES or d.name end
    return d.name
end

return DB
