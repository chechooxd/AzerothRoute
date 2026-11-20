-- AzerothRoute: runs Polestar's guides (Guides/Polestar/*.lua, GPL-3.0-only, Copyright (c) 2026
-- The Polestar authors) on AzerothRoute's guide engine.
--
-- The data files call PolestarGuides:Add(pack, id, fn) with one function per guide; LoadAll builds
-- the guides of the shared pack and of the player's faction into Guide/Step/Goal objects and
-- registers them in the Guide Center as "Polestar\<id>".
--
-- Mapping:
--   guide  category -> type (LEVELING, PROFESSIONS, CLASS, REPUTATION, COLLECTIBLES, OTHER),
--          minLevel/maxLevel -> startlevel/endlevel, next, races/classes/faction -> who it is for
--   step   title, label, note (tooltip of its first goal), `only` and `when` -> visibility
--   goal   one Polestar goal kind -> one AzerothRoute goal action, with its quest objective,
--          coordinates and note; kinds AzerothRoute has no handler for complete through a
--          condition (skill, reputation, money...) or by confirming them.
-- Text tokens such as {npc:3171} are replaced by the name, translated by id where AzerothRoute
-- knows the translation.

local AR = _G.AzerothRoute
local PolestarGuides = { packs = { shared = {}, horde = {}, alliance = {} }, loaded = {} }
AR.PolestarGuides = PolestarGuides

local PREFIX = "Polestar\\"

PolestarGuides.TYPES = {
    Leveling = "LEVELING",
    Professions = "PROFESSIONS",
    Class = "CLASS",
    Reputation = "REPUTATION",
    Collectibles = "COLLECTIBLES",
}

-- Profession skill lines Polestar names by id (craft goals that run until a skill level).
local SKILL_LINES = {
    [164] = "Blacksmithing", [165] = "Leatherworking", [171] = "Alchemy", [182] = "Herbalism",
    [185] = "Cooking", [186] = "Mining", [197] = "Tailoring", [202] = "Engineering",
    [333] = "Enchanting", [356] = "Fishing", [393] = "Skinning", [129] = "First Aid", [762] = "Riding",
}

function PolestarGuides:Add(pack, id, fn)
    local list = self.packs[pack]
    if not list then return end
    list[#list + 1] = { id = id, fn = fn }
end

local function L(key, fallback)
    if AR.L then
        local v = AR.L:Get(key)
        if v and v ~= key then return v end
    end
    return fallback
end

local function F(key, fallback, ...)
    return string.format(L(key, fallback), ...)
end

local function spanish()
    return AR.L and AR.L.IsSpanish and AR.L:IsSpanish() or false
end

-- Name for a "{kind:id}" token: translated by id when AzerothRoute knows it, else Polestar's.
local function tokenName(names, kind, id)
    local fallback = names and names[kind .. ":" .. id]
    local n = tonumber(id)
    local loc = AR.Localizers
    if loc and n and spanish() then
        if kind == "npc" and loc.GetTranslatedNPC then return loc:GetTranslatedNPC(n, fallback) or fallback end
        if kind == "quest" and loc.GetTranslatedQuest then return loc:GetTranslatedQuest(n, fallback) or fallback end
        if kind == "item" and loc.GetTranslatedItem then return loc:GetTranslatedItem(n, fallback) or fallback end
    end
    if fallback then return fallback end
    if kind == "zone" and n and _G.C_Map and _G.C_Map.GetMapInfo then
        local info = _G.C_Map.GetMapInfo(n)
        if info and info.name then return info.name end
    end
    if kind == "spell" and n and _G.GetSpellInfo then
        local s = _G.GetSpellInfo(n)
        if s then return s end
    end
    return kind .. " " .. tostring(id)
end

function PolestarGuides:Resolve(text, names)
    if type(text) ~= "string" then return text end
    return (text:gsub("{(%a+):([%w_%-]+)}", function(kind, id) return tokenName(names, kind, id) end))
end

-- Conditions -----------------------------------------------------------------------------------

local function playerRace()
    if not _G.UnitRace then return nil end
    local _, token = _G.UnitRace("player")
    return token
end

local function playerClass()
    if not _G.UnitClass then return nil end
    local _, token = _G.UnitClass("player")
    return token
end

local function playerFaction()
    if not _G.UnitFactionGroup then return nil end
    return (_G.UnitFactionGroup("player"))
end

local function contains(list, v)
    if not list then return true end
    if v == nil then return true end
    for _, x in ipairs(list) do if x == v then return true end end
    return false
end

-- `only` = { races = {...}, classes = {...}, factions = {...} }
function PolestarGuides:OnlyMatches(only)
    if not only then return true end
    return contains(only.races, playerRace()) and contains(only.classes, playerClass())
        and contains(only.factions, playerFaction())
end

local function inLog(q)
    if AR.QuestTracking and AR.QuestTracking.questsById and AR.QuestTracking.questsById[q] then
        return AR.QuestTracking.questsById[q]
    end
    local log = _G.MockWoW and _G.MockWoW.quests and _G.MockWoW.quests.inLog
    return log and log[q] or nil
end

local function turnedIn(q)
    return AR.Compat and AR.Compat:IsQuestCompleted(q) or false
end

local function compare(a, op, b)
    if op == "<" then return a < b end
    if op == "<=" then return a <= b end
    if op == ">" then return a > b end
    if op == "==" or op == "=" then return a == b end
    return a >= b
end

local function level()
    return (_G.UnitLevel and _G.UnitLevel("player")) or 1
end

local function skillLevel(name)
    if AR.Professions and AR.Professions.GetSkillLevel then return AR.Professions:GetSkillLevel(name) or 0 end
    return 0
end

local function zoneIs(name)
    for _, fn in ipairs({ "GetRealZoneText", "GetZoneText", "GetSubZoneText", "GetMinimapZoneText" }) do
        local f = _G[fn]
        if f and f() == name then return true end
    end
    return false
end

-- One Polestar `when` test.
local function test(w, guide)
    local k = w.k
    if k == "onquest" then
        local qs = type(w.q) == "table" and w.q or { w.q }
        for _, q in ipairs(qs) do if inLog(q) then return true end end
        return false
    elseif k == "turnedin" then
        return turnedIn(w.q)
    elseif k == "complete" then
        local e = inLog(w.q)
        return e ~= nil and e.isComplete == true
    elseif k == "available" then
        if turnedIn(w.q) or inLog(w.q) then return false end
        if w.minLevel and level() < w.minLevel then return false end
        for _, p in ipairs(w.pre or {}) do if not turnedIn(p) then return false end end
        return true
    elseif k == "level" then
        return compare(level(), w.op, w.n or 1)
    elseif k == "money" then
        return compare((_G.GetMoney and _G.GetMoney()) or 0, w.op, w.n or 0)
    elseif k == "has" then
        return (AR.Compat and AR.Compat:GetItemCount(w.item, false) or 0) >= (w.n or 1)
    elseif k == "knows" then
        return (_G.IsSpellKnown and _G.IsSpellKnown(w.spell)) or (_G.IsPlayerSpell and _G.IsPlayerSpell(w.spell)) or false
    elseif k == "skill" then
        return skillLevel(w.name) >= (w.n or 1)
    elseif k == "taxi" then
        return AR.TaxiTracker and AR.TaxiTracker.KnowsTaxi and AR.TaxiTracker:KnowsTaxi(w.name) or false
    elseif k == "bound" then
        if AR.TaxiTracker and AR.TaxiTracker.IsHearthBoundAt and AR.TaxiTracker:IsHearthBoundAt(w.name) then return true end
        return (_G.GetBindLocation and _G.GetBindLocation() == w.name) or false
    elseif k == "zone" then
        return zoneIs(w.name)
    elseif k == "dungeon" then
        local name = _G.GetInstanceInfo and _G.GetInstanceInfo()
        return name == w.name
    elseif k == "group" then
        return not (AR.GroupQuests and AR.GroupQuests.IsSkipped and AR.GroupQuests:IsSkipped(w.q))
    elseif k == "done" then
        local s = guide and guide.stepsByLabel and guide.stepsByLabel[w.label]
        if not s then return false end
        local ok, done = pcall(s.IsComplete, s)
        return ok and done == true
    end
    return true
end

-- All of `when` must hold (each test may be negated).
function PolestarGuides:When(list, guide)
    for _, w in ipairs(list or {}) do
        local res = test(w, guide)
        if w.neg then res = not res end
        if not res then return false end
    end
    return true
end

-- Goals ----------------------------------------------------------------------------------------

local function coords(goal, raw, dist)
    if raw.map and raw.x and raw.y then
        goal.map = raw.map
        goal.x = raw.x / 100
        goal.y = raw.y / 100
        goal.dist = dist or 8
    end
end

local function newGoal(step, fields)
    local g = AR.Goal:New(fields)
    g.parentStep = step
    return g
end

function PolestarGuides:BuildGoal(raw, step, guide, names)
    local t = raw.t
    local R = function(s) return self:Resolve(s, names) end
    local g = newGoal(step, { source = "polestar", kind = t })
    if raw.note then g.tooltip = R(raw.note) end
    if raw.optional then g.optional = true end
    -- A quest goal follows its objective (oi), or the whole quest when it names none.
    if raw.quest then
        g.questid, g.objnum = raw.quest, raw.oi
    end

    if t == "accept" or t == "turnin" then
        g.action = t
        g.quest = raw.title
        g.questid = raw.quest
        g.objnum = nil
        g.npcid = raw.npc
        g.target = raw.npcName
        coords(g, raw)
    elseif t == "kill" then
        g.action = "kill"
        g.target = raw.target or raw.npcName
        g.targetid = raw.npc
        g.count = raw.count
        if not raw.quest then g.optional = true end
        coords(g, raw)
    elseif t == "collect" then
        g.action = "get"
        g.target = raw.itemName
        g.targetid = raw.item
        g.count = raw.count
        if raw.from and not g.tooltip then g.tooltip = raw.from end
        coords(g, raw)
    elseif t == "complete" then
        g.action = "complete"
        g.questid = raw.quest
        g.objnum = nil
        g.text = F("GOAL_COMPLETE_QUEST", "Complete %s", (spanish() and AR.Localizers and AR.Localizers:GetTranslatedQuest(raw.quest, raw.title)) or raw.title or "")
        coords(g, raw)
    elseif t == "talk" then
        g.action = "talk"
        g.target = raw.npcName
        g.npcid = raw.npc
        if not raw.oi then g.questid = nil end
        coords(g, raw)
    elseif t == "goto" or t == "explore" or t == "enter" then
        g.action = "goto"
        coords(g, raw, (t == "goto") and 8 or 30)
        local where = R(raw.text or raw.location) or ""
        if t == "explore" then g.text = F("GOAL_EXPLORE", "Explore %s", where)
        elseif t == "enter" then g.text = F("GOAL_ENTER", "Enter %s", where)
        elseif where ~= "" then g.text = F("GOAL_GOTO_PLACE", "Go to %s", where) end
    elseif t == "fly" then
        g.action, g.param = "fly", raw.location
    elseif t == "getfp" then
        g.action, g.param = "fpath", raw.location
        g.npcid, g.target = raw.npc, raw.npcName
        coords(g, raw)
    elseif t == "sethome" then
        g.action, g.param = "home", raw.location
        g.npcid, g.target = raw.npc, raw.npcName
        coords(g, raw)
    elseif t == "level" then
        g.action, g.level = "ding", raw.level
    elseif t == "learn" then
        g.action, g.target, g.spellid = "learn", raw.spellName, raw.spell
    elseif t == "train" then
        g.action, g.target, g.npcid = "trainer", raw.npcName, raw.npc
        coords(g, raw)
    elseif t == "vendor" then
        g.action, g.target, g.npcid = "vendor", raw.npcName, raw.npc
        coords(g, raw)
    elseif t == "buy" or t == "auction" then
        g.action, g.target, g.targetid, g.count = "buy", raw.itemName, raw.item, raw.count
        if t == "auction" then g.tooltip = g.tooltip or L("GOAL_AUCTION_TIP", "From the auction house") end
        coords(g, raw)
    elseif t == "use" then
        g.action, g.target, g.targetid = "use", raw.itemName, raw.item
        coords(g, raw)
    elseif t == "interact" then
        g.action, g.target, g.targetid = "click", raw.objName or R(raw.text), raw.object
        coords(g, raw)
    elseif t == "craft" then
        g.action, g.target, g.recipeid, g.count = "create", raw.spellName or raw.itemName, raw.spell, raw.count
        local prof = SKILL_LINES[raw.skillLine]
        if raw.untilSkill and prof then
            local target = raw.untilSkill
            g.condition_complete = function() return skillLevel(prof) >= target end
            g.text = F("GOAL_CRAFT_UNTIL", "Craft %s until %s %d", g.target or "", prof, target)
        elseif not g.count then
            g.condition_complete = function() return false end
            g.optional = true
        end
    elseif t == "skill" then
        local name, lv = raw.skill or SKILL_LINES[raw.skillLine] or "", raw.level or 1
        g.action = "skill"
        g.text = F("GOAL_SKILL", "Reach %s %d", name, lv)
        g.condition_complete = function() return skillLevel(name) >= lv end
    elseif t == "rep" then
        local name, standing = raw.factionName, raw.standing or 4
        g.action = "rep"
        local label = _G["FACTION_STANDING_LABEL" .. standing] or tostring(standing)
        g.text = F("GOAL_REP", "Reach %s with %s", label, name or "")
        g.condition_complete = function()
            return (AR.Faction and AR.Faction.GetStanding and AR.Faction:GetStanding(name) or 0) >= standing
        end
    elseif t == "money" then
        local amount = raw.money or 0
        g.action = "money"
        local fmt = (AR.Report and AR.Report.FormatMoney) and AR.Report:FormatMoney(amount)
            or string.format("%dg %ds %dc", math.floor(amount / 10000), math.floor(amount / 100) % 100, amount % 100)
        g.text = F("GOAL_MONEY", "Have %s", fmt)
        g.condition_complete = function() return ((_G.GetMoney and _G.GetMoney()) or 0) >= amount end
    elseif t == "abandon" then
        local q = raw.quest
        g.action = "abandon"
        g.text = F("GOAL_ABANDON", "Abandon %s", raw.title or "")
        g.condition_complete = function() return inLog(q) == nil end
    elseif t == "die" then
        g.action, g.confirm = "confirm", true
        g.text = F("GOAL_DIE", "Die near %s and take the spirit healer's way", raw.location or "")
        coords(g, raw)
    elseif t == "task" then
        g.action, g.confirm = "confirm", true
        g.text = R(raw.text)
    else -- "note" and anything new: a line to read.
        g.action = "text"
        g.text = R(raw.text or raw.note or "")
        g.tooltip = nil
    end

    if raw.only then
        local only = raw.only
        g.condition_visible = function() return PolestarGuides:OnlyMatches(only) end
    end
    return g
end

-- Guides ---------------------------------------------------------------------------------------

function PolestarGuides:Key(id)
    return PREFIX .. id
end

function PolestarGuides:BuildGuide(raw)
    local names = raw.names
    local R = function(s) return self:Resolve(s, names) end
    local guide = AR.Guide:New({ title = self:Key(raw.id), steps = {}, stepsByLabel = {} })
    guide.source = "polestar"
    guide.polestarId = raw.id
    guide.author = "Polestar"
    guide.type = self.TYPES[raw.category] or "OTHER"
    guide.folder = raw.folder
    guide.startlevel = raw.minLevel
    guide.endlevel = raw.maxLevel
    guide.zone = raw.zone
    guide.keywords = raw.keywords
    if raw.next then guide.next = self:Key(raw.next) end
    local title = R(raw.title) or raw.id
    guide.displayTitleEN = title
    guide.displayTitleES = title
    local why = raw.why and R(raw.why) or ""
    guide.description = why
    guide.descriptionEN = why
    guide.descriptionES = why

    local races, classes, faction = raw.races, raw.classes, raw.faction
    local function forPlayer()
        if faction and playerFaction() and faction ~= playerFaction() then return false end
        return contains(races, playerRace()) and contains(classes, playerClass())
    end
    guide.condition_valid = forPlayer
    if guide.type == "LEVELING" then
        local lo, hi = raw.minLevel or 1, raw.maxLevel or 60
        guide.condition_suggested = function()
            local lv = level()
            return forPlayer() and lv >= lo and lv <= hi
        end
    end

    for i, rs in ipairs(raw.steps or {}) do
        local step = AR.Step:New({ num = i, parentGuide = guide, goals = {} })
        step.source = "polestar"
        if rs.title then step.title = R(rs.title) end
        if rs.label then
            step.label = rs.label
            guide.stepsByLabel[rs.label] = step
        end
        local only, when = rs.only, rs.when
        if only or when then
            step.condition_visible = function()
                return PolestarGuides:OnlyMatches(only) and PolestarGuides:When(when, guide)
            end
        end
        for _, rg in ipairs(rs.goals or {}) do
            local g = self:BuildGoal(rg, step, guide, names)
            g.num = #step.goals + 1
            step.goals[#step.goals + 1] = g
        end
        -- The step's note explains it: shown on its first goal.
        if rs.note and step.goals[1] then
            local note = R(rs.note)
            local first = step.goals[1]
            first.tooltip = first.tooltip and (note .. "\n" .. first.tooltip) or note
        end
        guide.steps[#guide.steps + 1] = step
    end
    return guide
end

-- The packs to build: the shared one and the player's faction (both when it is not known yet).
function PolestarGuides:PacksFor(faction)
    if faction == "Horde" then return { "shared", "horde" } end
    if faction == "Alliance" then return { "shared", "alliance" } end
    return { "shared", "horde", "alliance" }
end

-- Builds and registers the guides once; returns how many were registered.
function PolestarGuides:LoadAll(faction)
    if not (AR.Parser and AR.Guide and AR.Step and AR.Goal) then return 0 end
    faction = faction or playerFaction()
    AR.Parser.guidesByTitle = AR.Parser.guidesByTitle or {}
    local n = 0
    for _, pack in ipairs(self:PacksFor(faction)) do
        for _, entry in ipairs(self.packs[pack]) do
            if not self.loaded[entry.id] then
                local ok, raw = pcall(entry.fn)
                if ok and type(raw) == "table" and not (faction and raw.faction and raw.faction ~= faction) then
                    local built, guide = pcall(self.BuildGuide, self, raw)
                    if built and guide then
                        AR.Parser.guidesByTitle[guide.title] = guide
                        self.loaded[entry.id] = guide
                        n = n + 1
                    elseif AR.Report and AR.Report.Note then
                        AR.Report:Note("Polestar guide " .. entry.id .. ": " .. tostring(guide))
                    end
                end
            end
        end
    end
    return n
end

-- Built-in guides Polestar's replace once they are loaded: every leveling guide (Polestar covers
-- 1-60 for every race) and the profession guides. Dungeon and gold guides stay. Replaced guides
-- drop out of the Guide Center lists, search and suggestions; one already open keeps working.
PolestarGuides.REPLACED_PREFIXES = { "Leveling\\", "Professions\\" }

function PolestarGuides:Replaces(guide)
    if not guide or guide.source == "polestar" or next(self.loaded) == nil then return false end
    local title = guide.title or ""
    for _, prefix in ipairs(self.REPLACED_PREFIXES) do
        if title:sub(1, #prefix) == prefix then return true end
    end
    return false
end

function PolestarGuides:Reset()
    for id, guide in pairs(self.loaded) do
        if AR.Parser and AR.Parser.guidesByTitle and AR.Parser.guidesByTitle[guide.title] == guide then
            AR.Parser.guidesByTitle[guide.title] = nil
        end
        self.loaded[id] = nil
    end
end

return PolestarGuides
