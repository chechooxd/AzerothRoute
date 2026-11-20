-- AzerothRoute: trainers learned in game for Nearby services.
-- The database has no trainer data, so trainers are recorded as the player meets them:
--   * mouse-over: the NPC's tooltip title ("Warrior Trainer", "Cooking Trainer", "Weapon Master")
--   * opening a trainer window (TRAINER_SHOW): confirms the trainer and pins its position
-- Records live in AR.db.global.trainers (shared by every character):
--   [npcId] = { name, title, kind = "class"|"profession"|"weapon", class = CLASSFILE|nil, side, map, x, y }

local AR = _G.AzerothRoute
local Trainers = {
    -- Title words that mark a trainer, per client language (lower case).
    TRAINER_WORDS = { "trainer", "instructor", "instructora", "entrenador", "entrenadora" },
    WEAPON_WORDS = { "weapon master", "maestro de armas", "maestra de armas" },
    _registered = false,
}
AR.Trainers = Trainers

local function store()
    if not AR.db or not AR.db.global then return nil end
    AR.db.global.trainers = AR.db.global.trainers or {}
    return AR.db.global.trainers
end

local function has(text, words)
    for _, w in ipairs(words) do
        if text:find(w, 1, true) then return true end
    end
    return false
end

-- CLASSFILE whose localized name appears in the title, or nil.
local function classInTitle(lower)
    for _, tbl in ipairs({ _G.LOCALIZED_CLASS_NAMES_MALE or {}, _G.LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
        for file, name in pairs(tbl) do
            if type(name) == "string" and lower:find(name:lower(), 1, true) then return file end
        end
    end
    -- Fallback for clients without the tables: English class words.
    for _, file in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }) do
        if lower:find(file:lower(), 1, true) then return file end
    end
    return nil
end

-- Classifies a tooltip title: returns kind ("class", "profession", "weapon") and class file, or nil.
function Trainers:Classify(title)
    if type(title) ~= "string" or title == "" then return nil end
    local lower = title:lower():gsub("[<>]", "")
    if has(lower, self.WEAPON_WORDS) then return "weapon" end
    if not has(lower, self.TRAINER_WORDS) then return nil end
    local class = classInTitle(lower)
    if class then return "class", class end
    return "profession"
end

-- NPC id from a creature GUID ("Creature-0-xxxx-xxxx-xxxx-<id>-xxxx").
function Trainers:NpcIdFromGUID(guid)
    if type(guid) ~= "string" then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if kind ~= "Creature" then return nil end
    return tonumber(id)
end

local function sideOf(unit)
    local f = _G.UnitFactionGroup and _G.UnitFactionGroup(unit)
    return (f == "Alliance" and "A") or (f == "Horde" and "H") or "B"
end

-- Records (or refreshes) a trainer seen on `unit`. Position: where the player stands now.
function Trainers:Record(unit, title, kindOverride, classOverride)
    local db = store()
    if not db or not _G.UnitGUID or not AR.Coords then return nil end
    local id = self:NpcIdFromGUID(_G.UnitGUID(unit))
    if not id then return nil end
    local kind, class = self:Classify(title)
    kind, class = kindOverride or kind, classOverride or class
    if not kind then return nil end
    local map, x, y = AR.Coords:GetPlayerPosition()
    if not map or not x then return nil end
    local prev = db[id] or {}
    db[id] = {
        name = (_G.UnitName and _G.UnitName(unit)) or prev.name or "?",
        title = title or prev.title,
        kind = kind, class = class or prev.class,
        side = sideOf(unit), map = map, x = x, y = y,
    }
    return db[id]
end

-- Title line of the unit tooltip currently shown (line 2 when it is not the level line).
function Trainers:TooltipTitle()
    local line = _G.GameTooltipTextLeft2
    local text = line and line.GetText and line:GetText()
    if type(text) ~= "string" or text == "" then return nil end
    local level = _G.UnitLevel and _G.UnitLevel("mouseover")
    if level and text:find(tostring(level), 1, true) then return nil end -- "Level 30 Humanoid"
    return text
end

function Trainers:OnMouseover()
    if not _G.UnitExists or not _G.UnitExists("mouseover") then return nil end
    if _G.UnitIsPlayer and _G.UnitIsPlayer("mouseover") then return nil end
    local title = self:TooltipTitle()
    if not self:Classify(title) then return nil end
    return self:Record("mouseover", title)
end

-- Trainer window: profession trainers say so; anything else trains the player's class
-- unless its title already told us it is a weapon master.
function Trainers:OnTrainerShow()
    local db = store()
    local id = db and _G.UnitGUID and self:NpcIdFromGUID(_G.UnitGUID("npc"))
    local known = id and db[id]
    if _G.IsTradeskillTrainer and _G.IsTradeskillTrainer() then
        return self:Record("npc", known and known.title, "profession")
    end
    if known and known.kind == "weapon" then return self:Record("npc", known.title, "weapon") end
    local classFile
    if _G.UnitClass then classFile = select(2, _G.UnitClass("player")) end
    return self:Record("npc", known and known.title, "class", classFile)
end

function Trainers:RegisterLiveEvents()
    if self._registered or not AR.Events then return end
    self._registered = true
    -- Read the title once the tooltip is filled; fall back to the mouse-over event without the hook.
    local tip = _G.GameTooltip
    if tip and tip.HookScript and tip.GetUnit then
        tip:HookScript("OnTooltipSetUnit", function() self:OnMouseover() end)
    else
        AR.Events:RegisterEvent("UPDATE_MOUSEOVER_UNIT", function() self:OnMouseover() end)
    end
    AR.Events:RegisterEvent("TRAINER_SHOW", function() self:OnTrainerShow() end)
end

-- Nearest learned trainer matching `filter(record)` for the player's faction and continent:
-- returns { name, map, x (0..100), y (0..100), title } and yards, or nil.
function Trainers:FindNearest(filter)
    local db = store()
    if not db or not AR.Coords then return nil end
    local me = sideOf("player")
    local best, bestDist
    for _, t in pairs(db) do
        if (t.side == "B" or t.side == me) and filter(t) then
            local d = AR.Coords:GetDistanceTo(t.map, t.x, t.y)
            if d and (not bestDist or d < bestDist) then best, bestDist = t, d end
        end
    end
    if not best then return nil end
    return { name = best.name, title = best.title, map = best.map, x = best.x * 100, y = best.y * 100 }, bestDist
end

-- Service entries for the nearby menu: the player's class trainer, a weapon master and one per
-- profession trainer title learned so far (nearest of each).
function Trainers:ServiceEntries()
    local db = store() or {}
    local L = AR.L
    local myClass
    if _G.UnitClass then myClass = select(2, _G.UnitClass("player")) end
    local out = {}
    local rec, d = self:FindNearest(function(t) return t.kind == "class" and t.class == myClass end)
    if rec then out[#out + 1] = { label = (L and L:Get("UI_SV_CLASS")) or "Class trainer", record = rec, distance = d } end
    rec, d = self:FindNearest(function(t) return t.kind == "weapon" end)
    if rec then out[#out + 1] = { label = (L and L:Get("UI_SV_WEAPON")) or "Weapon master", record = rec, distance = d } end
    -- Profession trainers met only through their window (no title yet) share one generic entry.
    local generic = (L and L:Get("UI_SV_PROFESSION")) or "Profession trainer"
    local function label(t) return t.title or generic end
    local titles = {}
    for _, t in pairs(db) do
        if t.kind == "profession" then titles[label(t)] = true end
    end
    local sorted = {}
    for title in pairs(titles) do sorted[#sorted + 1] = title end
    table.sort(sorted)
    for _, title in ipairs(sorted) do
        rec, d = self:FindNearest(function(t) return t.kind == "profession" and label(t) == title end)
        if rec then out[#out + 1] = { label = title, record = rec, distance = d } end
    end
    return out
end

return Trainers
