-- AzerothRoute: Runtime Condition Environment (SPEC-02)
-- Compiles only if / complete expressions against live game state without caching dynamic level/quest results.

local AR = _G.AzerothRoute
local ConditionEnv = {
    compiledCache = {},
    guideFlags = {},
}
AR.ConditionEnv = ConditionEnv

local RACE_ALIASES = {
    Scourge = { "Undead", "Scourge" },
    Undead = { "Undead", "Scourge" },
    Human = { "Human" },
    Dwarf = { "Dwarf" },
    NightElf = { "NightElf", "Night Elf" },
    Gnome = { "Gnome" },
    Orc = { "Orc" },
    Troll = { "Troll" },
    Tauren = { "Tauren" },
    BloodElf = { "BloodElf", "Blood Elf" },
    Draenei = { "Draenei" },
}

local CLASS_ALIASES = {
    WARRIOR = "Warrior",
    PALADIN = "Paladin",
    HUNTER = "Hunter",
    ROGUE = "Rogue",
    PRIEST = "Priest",
    SHAMAN = "Shaman",
    MAGE = "Mage",
    WARLOCK = "Warlock",
    DRUID = "Druid",
}

function ConditionEnv:RaceClassMatch(tokenString)
    if not tokenString or tokenString == "" then return true end
    local pRace = (_G.UnitRace and _G.UnitRace("player")) or "Scourge"
    local pClass = (_G.UnitClass and _G.UnitClass("player")) or "PALADIN"
    local pFaction = (_G.UnitFactionGroup and _G.UnitFactionGroup("player")) or "Horde"
    local canonicalClass = CLASS_ALIASES[pClass:upper()] or pClass
    local raceList = RACE_ALIASES[pRace] or { pRace }

    for clause in tokenString:gmatch("[^,]+") do
        clause = clause:match("^%s*(.-)%s*$")
        local inverted = false
        if clause:sub(1, 1) == "!" then
            inverted = true
            clause = clause:sub(2):match("^%s*(.-)%s*$")
        end
        local matched = false
        if clause:lower() == pFaction:lower() or clause:lower() == canonicalClass:lower() or clause:lower() == pClass:lower() then
            matched = true
        else
            for _, r in ipairs(raceList) do
                if clause:lower() == r:lower() then
                    matched = true
                    break
                end
            end
        end
        if inverted then matched = not matched end
        if matched then return true end
    end
    return false
end

local envMeta = {
    __index = function(_, key)
        if key == "level" then
            local lvl = (_G.UnitLevel and _G.UnitLevel("player")) or 1
            local xp = (_G.UnitXP and _G.UnitXP("player")) or 0
            local maxXp = (_G.UnitXPMax and _G.UnitXPMax("player")) or 1
            if maxXp <= 0 then maxXp = 1 end
            return lvl + (xp / maxXp)
        elseif key == "intlevel" then
            return (_G.UnitLevel and _G.UnitLevel("player")) or 1
        elseif key == "completedq" then
            return function(qid)
                if AR.QuestTracking and AR.QuestTracking.IsCompleted then
                    return AR.QuestTracking:IsCompleted(qid)
                end
                return AR.Compat:IsQuestCompleted(qid)
            end
        elseif key == "haveq" then
            return function(qid)
                local qLog = _G.MockWoW and _G.MockWoW.quests and _G.MockWoW.quests.inLog
                if AR.QuestTracking and AR.QuestTracking.questsById and AR.QuestTracking.questsById[qid] then
                    return true
                end
                return (qLog and qLog[qid] ~= nil) or false
            end
        elseif key == "readyq" then
            return function(qid)
                if AR.QuestTracking and AR.QuestTracking.questsById and AR.QuestTracking.questsById[qid] then
                    return AR.QuestTracking.questsById[qid].isComplete == true
                end
                local qLog = _G.MockWoW and _G.MockWoW.quests and _G.MockWoW.quests.inLog
                return (qLog and qLog[qid] and qLog[qid].isComplete == true) or false
            end
        elseif key == "questpossible" then
            return function(qid)
                if AR.Chains and AR.Chains.IsQuestPossible then
                    return AR.Chains:IsQuestPossible(qid)
                end
                return true
            end
        elseif key == "itemcount" then
            return function(itemID)
                return AR.Compat:GetItemCount(itemID, false)
            end
        elseif key == "itembanked" then
            return function(itemID)
                return AR.Compat:GetItemCount(itemID, true)
            end
        elseif key == "skill" then
            return function(skillName)
                if AR.Professions and AR.Professions.GetSkillLevel then
                    return AR.Professions:GetSkillLevel(skillName)
                end
                return 0
            end
        elseif key == "hasprof" then
            return function(skillName)
                if AR.Professions and AR.Professions.GetSkillLevel then
                    return AR.Professions:GetSkillLevel(skillName) > 0
                end
                return false
            end
        elseif key == "rep" then
            return function(factionName)
                if AR.Faction and AR.Faction.GetStanding then
                    return AR.Faction:GetStanding(factionName)
                end
                return 4
            end
        elseif key == "knowspell" then
            return function(spellID)
                return (_G.IsSpellKnown and _G.IsSpellKnown(spellID)) or false
            end
        elseif key == "knowstaxi" then
            return function(nodeID)
                return (AR.db and AR.db.char and AR.db.char.taxis and AR.db.char.taxis[nodeID] == true) or false
            end
        elseif key == "guideflag" then
            return function(flagName, val)
                if val ~= nil then
                    ConditionEnv.guideFlags[flagName] = val
                end
                return ConditionEnv.guideFlags[flagName]
            end
        else
            -- Check dynamic race/class/faction boolean identifiers
            if ConditionEnv:RaceClassMatch(tostring(key)) then
                return true
            end
            return _G[key]
        end
    end,
}

ConditionEnv.env = setmetatable({}, envMeta)

function ConditionEnv:Compile(expr)
    if not expr or expr == "" then return nil end
    if self.compiledCache[expr] then
        return self.compiledCache[expr]
    end
    local loader = _G.loadstring or _G.load
    local chunk, err = loader("return (" .. expr .. ")", "ConditionEnv:" .. expr, "t", self.env)
    if not chunk then
        error("Failed to compile ConditionEnv expression [" .. tostring(expr) .. "]: " .. tostring(err))
    end
    if _G.setfenv then
        _G.setfenv(chunk, self.env)
    end
    self.compiledCache[expr] = chunk
    return chunk
end

return ConditionEnv
