-- AzerothRoute: class spells learned from the class trainer window.
-- A class trainer lists what it teaches now and at later levels ("available"/"unavailable"), with
-- the level and cost of each rank. Recording that list once lets the addon say, on each level-up,
-- which spells are new and whether the player can pay for them.
-- Stored per class in AR.db.global.classSpells[CLASSFILE]["Name|Rank"] = { name, rank, level, cost, icon }.

local AR = _G.AzerothRoute
local ClassSpells = { _registered = false }
AR.ClassSpells = ClassSpells

local function playerClass()
    if not _G.UnitClass then return nil end
    return select(2, _G.UnitClass("player"))
end

local function store(class)
    if not AR.db or not AR.db.global or not class then return nil end
    AR.db.global.classSpells = AR.db.global.classSpells or {}
    AR.db.global.classSpells[class] = AR.db.global.classSpells[class] or {}
    return AR.db.global.classSpells[class]
end

-- Reads the open class trainer window; returns the number of spells recorded.
function ClassSpells:RecordTrainer()
    if _G.IsTradeskillTrainer and _G.IsTradeskillTrainer() then return 0 end
    local db = store(playerClass())
    if not db or not _G.GetNumTrainerServices or not _G.GetTrainerServiceInfo then return 0 end
    local n = 0
    for i = 1, _G.GetNumTrainerServices() or 0 do
        local name, rank, category = _G.GetTrainerServiceInfo(i)
        if name and category ~= "header" then
            local level = _G.GetTrainerServiceLevelReq and _G.GetTrainerServiceLevelReq(i) or 0
            local cost = _G.GetTrainerServiceCost and _G.GetTrainerServiceCost(i) or 0
            local icon = _G.GetTrainerServiceIcon and _G.GetTrainerServiceIcon(i) or nil
            db[name .. "|" .. (rank or "")] = { name = name, rank = rank, level = level or 0, cost = cost or 0, icon = icon }
            n = n + 1
        end
    end
    return n
end

-- True once the player's class trainer list has been recorded.
function ClassSpells:HasData()
    local db = store(playerClass())
    return db ~= nil and next(db) ~= nil
end

-- Spells that unlock exactly at `level`, sorted by name: { { name, rank, level, cost, icon } }.
function ClassSpells:ForLevel(level)
    local out = {}
    for _, s in pairs(store(playerClass()) or {}) do
        if s.level == level then out[#out + 1] = s end
    end
    table.sort(out, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return (a.rank or "") < (b.rank or "")
    end)
    return out
end

function ClassSpells:TotalCost(list)
    local sum = 0
    for _, s in ipairs(list or {}) do sum = sum + (s.cost or 0) end
    return sum
end

-- "1g 20s 5c" style money text (copper in, no icons).
function ClassSpells:FormatMoney(copper)
    copper = math.max(0, math.floor(copper or 0))
    local g, s, c = math.floor(copper / 10000), math.floor((copper % 10000) / 100), copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
    return table.concat(parts, " ")
end

function ClassSpells:RegisterLiveEvents()
    if self._registered or not AR.Events then return end
    self._registered = true
    AR.Events:RegisterEvent("TRAINER_SHOW", function() self:RecordTrainer() end)
    AR.Events:RegisterEvent("TRAINER_UPDATE", function() self:RecordTrainer() end)
    AR.Events:RegisterEvent("PLAYER_LEVEL_UP", function(_, level)
        if AR.SpellToast then AR.SpellToast:OnLevelUp(tonumber(level)) end
    end)
end

return ClassSpells
