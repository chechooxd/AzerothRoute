-- AzerothRoute: Headless WoW Client API Mock (SPEC-14A)
-- Simulates World of Warcraft client globals and namespaces for offline deterministic testing.

local MockWoW = {}
_G.MockWoW = MockWoW

function MockWoW:Reset()
    self.clockMs = 1000.0
    self.fps = 60.0
    self.inCombat = false
    self.isAltKeyDown = false
    self.loadingScreenDisabled = true
    self.cvars = {
        InputDeviceInterfaceStyle = "0",
    }
    self.player = {
        name = "Sylvanas",
        realm = "ForeverRealm",
        faction = "Horde",
        race = "Scourge",
        class = "PALADIN",
        spec = 1,
        level = 1,
        xp = 0,
        maxXp = 400,
        mapID = 1420, -- Tirisfal Glades
        x = 0.30,
        y = 0.71,
        facing = 0,
        isDead = false,
        corpseMapID = nil,
        corpseX = nil,
        corpseY = nil,
        money = 100000, -- 10 gold in copper
        guildRepair = true,
        buffs = {},
        spellsKnown = { [6603] = true }, -- Auto Attack
        professions = {}, -- { [skillLineID] = { name=..., rank=..., maxRank=... } }
        recipesKnown = {}, -- { [recipeID] = { skillLineID=..., reagents={...}, learned=true, numAvailable=1 } }
        factions = {}, -- { [factionID] = { name=..., standing=4, min=0, max=3000, val=0 } }
        taxisKnown = {}, -- { [nodeID] = true }
        talents = {
            configID = 1,
            treeID = 1,
            currencyAvailable = 10,
            nodes = {}, -- { [nodeID] = { posX=..., posY=..., entries={entryID1, ...}, activeRank=0, maxRanks=5, activeEntryID=nil } }
            entries = {}, -- { [entryID] = { nodeID=..., maxRanks=5, spellID=... } }
        },
        itemsInBags = {}, -- { [itemID] = count }
        bagSlots = {}, -- { [bag] = { [slot] = { itemID=..., count=..., link=..., quality=..., sellPrice=... } } }
        itemsInBank = {}, -- { [itemID] = count }
        equipped = {}, -- { [slotID] = itemLink }
        mountsKnown = {},
        petsKnown = {},
        achievements = {},
    }
    self.quests = {
        completed = {}, -- { [questID] = true }
        inLog = {},     -- { [questID] = { title=..., level=..., isComplete=false, objectives={ { text=..., type=..., finished=false, numFulfilled=0, numRequired=1 } } } }
        choices = {},   -- { { itemID=..., link=..., name=..., count=1, sellPrice=100 } }
    }
    self.merchant = {
        isOpen = false,
        items = {}, -- { { itemID=..., name=..., price=..., stackCount=1, numAvailable=-1 } }
    }
    self.auction = {
        replicateItems = {}, -- { { itemID=..., name=..., count=..., buyoutPrice=..., minBid=... } }
        posted = {},
        bought = {},
    }
    self.exploredOverlays = {} -- { [mapID] = { [textureName] = true } }
    self.frames = {}
    self.timers = {}
    self.commMessages = {}
    self.craftedLog = {}
    self.macroExecutions = {}
    self.tooltips = {
        npcs = {},
        quests = {},
        items = {},
    }
end

MockWoW:Reset()

-- Global constants & functions
_G.WOW_PROJECT_ID = 19
_G.WOW_PROJECT_CAMELOT = 19

_G.debugprofilestop = function()
    return MockWoW.clockMs
end

function MockWoW:AdvanceTime(ms)
    self.clockMs = self.clockMs + (ms or 0)
end

_G.GetTime = function()
    return MockWoW.clockMs / 1000.0
end

_G.GetFramerate = function()
    return MockWoW.fps
end

_G.InCombatLockdown = function()
    return MockWoW.inCombat
end

_G.IsAltKeyDown = function()
    return MockWoW.isAltKeyDown
end

_G.GetLocale = function()
    return MockWoW.locale or "esMX"
end

_G.UnitName = function(unit)
    if unit == "player" then
        return MockWoW.player.name, MockWoW.player.realm
    end
    return "Unknown", MockWoW.player.realm
end

_G.GetRealmName = function()
    return MockWoW.player.realm
end

_G.UnitFactionGroup = function(unit)
    return MockWoW.player.faction, MockWoW.player.faction
end

_G.UnitRace = function(unit)
    return MockWoW.player.race, MockWoW.player.race
end

_G.UnitClass = function(unit)
    return MockWoW.player.class, MockWoW.player.class
end

_G.UnitLevel = function(unit)
    return MockWoW.player.level
end

_G.UnitXP = function(unit)
    return MockWoW.player.xp
end

_G.UnitXPMax = function(unit)
    return MockWoW.player.maxXp
end

_G.UnitIsDeadOrGhost = function(unit)
    return MockWoW.player.isDead
end

_G.GetPlayerFacing = function()
    return MockWoW.player.facing
end

_G.GetMoney = function()
    return MockWoW.player.money
end

_G.IsSpellKnown = function(spellID)
    return MockWoW.player.spellsKnown[spellID] == true
end

-- Frame system mock
local FrameProto = {}
FrameProto.__index = FrameProto

function FrameProto:SetScript(scriptType, handler)
    self._scripts[scriptType] = handler
end

function FrameProto:GetScript(scriptType)
    return self._scripts[scriptType]
end

function FrameProto:RegisterEvent(event)
    self._events[event] = true
end

function FrameProto:UnregisterEvent(event)
    self._events[event] = nil
end

function FrameProto:Show()
    self._shown = true
    if self._scripts.OnShow then
        self._scripts.OnShow(self)
    end
end

function FrameProto:Hide()
    self._shown = false
    if self._scripts.OnHide then
        self._scripts.OnHide(self)
    end
end

function FrameProto:IsShown()
    return self._shown
end

function FrameProto:SetSize(w, h)
    self._width, self._height = w, h
end

function FrameProto:GetSize()
    return self._width or 0, self._height or 0
end

function FrameProto:SetPoint(point, rel, relPoint, x, y)
    self._point = { point, rel, relPoint, x, y }
end

function FrameProto:SetAttribute(key, val)
    if MockWoW.inCombat and self._template and self._template:find("Secure") then
        error("ADDON_ACTION_BLOCKED: Attempted to modify secure attribute in combat lockdown")
    end
    self._attributes[key] = val
end

function FrameProto:GetAttribute(key)
    return self._attributes[key]
end

_G.CreateFrame = function(frameType, name, parent, template)
    local f = setmetatable({
        _type = frameType,
        _name = name,
        _parent = parent,
        _template = template,
        _scripts = {},
        _events = {},
        _attributes = {},
        _shown = true,
    }, FrameProto)
    if name then
        _G[name] = f
    end
    table.insert(MockWoW.frames, f)
    return f
end

function MockWoW:FireEvent(event, ...)
    for _, f in ipairs(self.frames) do
        if f._events[event] and f._scripts.OnEvent then
            f._scripts.OnEvent(f, event, ...)
        end
    end
end

function MockWoW:TickFrames(elapsed)
    for _, f in ipairs(self.frames) do
        if f._shown and f._scripts.OnUpdate then
            f._scripts.OnUpdate(f, elapsed or 0.016)
        end
    end
end

-- Modern C_* namespaces
_G.C_CVar = {
    GetCVar = function(name)
        return MockWoW.cvars[name]
    end,
}

_G.C_GamePad = {
    IsEnabled = function()
        return MockWoW.cvars.InputDeviceInterfaceStyle == "1"
    end,
}

_G.C_Map = {
    GetBestMapForUnit = function(unit)
        return MockWoW.player.mapID
    end,
    GetPlayerMapPosition = function(mapID, unit)
        return {
            GetXY = function()
                return MockWoW.player.x, MockWoW.player.y
            end,
        }
    end,
}

_G.C_DeathInfo = {
    GetCorpseMapPosition = function(mapID)
        if not MockWoW.player.isDead or not MockWoW.player.corpseX then
            return nil
        end
        return {
            GetXY = function()
                return MockWoW.player.corpseX, MockWoW.player.corpseY
            end,
        }
    end,
}

_G.C_QuestLog = {
    IsQuestFlaggedCompleted = function(questID)
        return MockWoW.quests.completed[tonumber(questID) or 0] == true
    end,
    GetNumQuestLogEntries = function()
        local count = 0
        for _ in pairs(MockWoW.quests.inLog) do
            count = count + 1
        end
        return count
    end,
    GetQuestObjectives = function(questID)
        local q = MockWoW.quests.inLog[questID]
        return q and q.objectives or {}
    end,
}

_G.C_Item = {
    GetItemCount = function(itemID, includeBank)
        local bagCount = MockWoW.player.itemsInBags[itemID] or 0
        if includeBank then
            bagCount = bagCount + (MockWoW.player.itemsInBank[itemID] or 0)
        end
        return bagCount
    end,
    GetItemStats = function(itemLink)
        local itemData = MockWoW.tooltips.items[itemLink]
        return itemData and itemData.stats or {}
    end,
}

_G.C_Spell = {
    GetSpellInfo = function(spellID)
        return { name = "Spell_" .. tostring(spellID), spellID = spellID }
    end,
    GetSpellCooldown = function(spellID)
        return { startTime = 0, duration = 0, isEnabled = true }
    end,
}

_G.C_Traits = {
    ResetTree = function(configID, treeID)
        for _, node in pairs(MockWoW.player.talents.nodes) do
            node.activeRank = 0
            node.activeEntryID = nil
        end
        return true
    end,
    PurchaseRank = function(configID, nodeID)
        local node = MockWoW.player.talents.nodes[nodeID]
        if node and (node.activeRank or 0) < (node.maxRanks or 1) then
            node.activeRank = (node.activeRank or 0) + 1
            node.activeEntryID = node.activeEntryID or (node.entries and node.entries[1])
            return true
        end
        return false
    end,
    SetSelection = function(configID, nodeID, entryID)
        local node = MockWoW.player.talents.nodes[nodeID]
        if node then
            node.activeEntryID = entryID
            node.activeRank = (node.activeRank or 0) + 1
            return true
        end
        return false
    end,
}

_G.C_TradeSkillUI = {
    GetAllRecipeIDs = function()
        local ids = {}
        for id in pairs(MockWoW.player.recipesKnown) do
            table.insert(ids, id)
        end
        table.sort(ids)
        return ids
    end,
    GetRecipeInfo = function(recipeID)
        return MockWoW.player.recipesKnown[recipeID]
    end,
    CraftRecipe = function(recipeID, count)
        table.insert(MockWoW.craftedLog, { recipeID = recipeID, count = count or 1 })
        return true
    end,
}

_G.C_Container = {
    GetContainerNumSlots = function(bag)
        local b = MockWoW.player.bagSlots[bag]
        return b and #b or 0
    end,
    GetContainerItemInfo = function(bag, slot)
        local b = MockWoW.player.bagSlots[bag]
        return b and b[slot] or nil
    end,
    UseContainerItem = function(bag, slot)
        local b = MockWoW.player.bagSlots[bag]
        if b and b[slot] and MockWoW.merchant.isOpen then
            local info = b[slot]
            MockWoW.player.money = MockWoW.player.money + (info.sellPrice or 0) * (info.count or 1)
            b[slot] = nil
        end
    end,
}

_G.C_MapExplorationInfo = {
    GetExploredMapTextures = function(mapID)
        return MockWoW.exploredOverlays[mapID] or {}
    end,
}

return MockWoW
