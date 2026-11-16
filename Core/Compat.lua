-- AzerothRoute: Client API Compatibility & Class Layer (SPEC-01)

local AR = _G.AzerothRoute or {}
_G.AzerothRoute = AR

AR.Version = "1.0.0"
AR.Interface = 16001
AR.IsForever = (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_CAMELOT)

local Compat = {}
AR.Compat = Compat

-- Weak-keyed class metadata registry
local classRegistry = setmetatable({}, { __mode = "k" })

function AR:Class(name, parent)
    local cls = {}
    cls.__index = cls
    cls.__name = name
    if parent then
        setmetatable(cls, { __index = parent })
    end
    function cls:New(obj)
        obj = obj or {}
        setmetatable(obj, cls)
        classRegistry[obj] = name
        return obj
    end
    return cls
end

function AR:GetClassName(obj)
    return classRegistry[obj]
end

-- Unified wrappers for Forever / Classic / Retail client APIs
function Compat:GetSpellInfo(spellID)
    if _G.C_Spell and _G.C_Spell.GetSpellInfo then
        return _G.C_Spell.GetSpellInfo(spellID)
    elseif _G.GetSpellInfo then
        local name, rank, icon, castTime, minRange, maxRange, id = _G.GetSpellInfo(spellID)
        if name then
            return {
                name = name,
                rank = rank,
                iconID = icon,
                castTime = castTime,
                minRange = minRange,
                maxRange = maxRange,
                spellID = id or spellID,
            }
        end
    end
    return nil
end

function Compat:GetSpellCooldown(spellID)
    if _G.C_Spell and _G.C_Spell.GetSpellCooldown then
        return _G.C_Spell.GetSpellCooldown(spellID)
    elseif _G.GetSpellCooldown then
        local start, duration, enabled = _G.GetSpellCooldown(spellID)
        return {
            startTime = start or 0,
            duration = duration or 0,
            isEnabled = enabled == 1 or enabled == true,
        }
    end
    return { startTime = 0, duration = 0, isEnabled = true }
end

function Compat:IsQuestCompleted(questID)
    questID = tonumber(questID) or 0
    if questID <= 0 then return false end
    if _G.C_QuestLog and _G.C_QuestLog.IsQuestFlaggedCompleted then
        return _G.C_QuestLog.IsQuestFlaggedCompleted(questID) == true
    elseif _G.IsQuestFlaggedCompleted then
        return _G.IsQuestFlaggedCompleted(questID) == true
    end
    return false
end

function Compat:GetItemCount(itemID, includeBank)
    if _G.C_Item and _G.C_Item.GetItemCount then
        return _G.C_Item.GetItemCount(itemID, includeBank) or 0
    elseif _G.GetItemCount then
        return _G.GetItemCount(itemID, includeBank) or 0
    end
    return 0
end

function Compat:GetPlayerKey()
    local name = (_G.UnitName and _G.UnitName("player")) or "Player"
    local realm = (_G.GetRealmName and _G.GetRealmName()) or "Realm"
    return string.format("%s - %s", name, realm)
end

function Compat:GetFactionRealmKey()
    local faction = (_G.UnitFactionGroup and _G.UnitFactionGroup("player")) or "Neutral"
    local realm = (_G.GetRealmName and _G.GetRealmName()) or "Realm"
    return string.format("%s - %s", faction, realm)
end

return Compat
