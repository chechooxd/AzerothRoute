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

function FrameProto:EnableMouse(flag)
    self._mouseEnabled = flag
end

function FrameProto:SetMovable(flag)
    self._movable = flag
end

function FrameProto:RegisterForDrag(...)
    self._dragButtons = { ... }
end

function FrameProto:StartMoving()
    self._moving = true
end

function FrameProto:StopMovingOrSizing()
    self._moving = false
end

function FrameProto:CreateTexture(name, layer)
    local tex = {
        _name = name,
        _layer = layer,
        _shown = true,
        SetAllPoints = function(t, rel) t._allPoints = rel or true end,
        SetPoint = function(t, ...) t._point = { ... } end,
        SetSize = function(t, w, h) t._width, t._height = w, h end,
        SetHeight = function(t, h) t._height = h end,
        SetWidth = function(t, w) t._width = w end,
        SetColorTexture = function(t, r, g, b, a) t._color = { r = r, g = g, b = b, a = a or 1 } end,
        GetColorTexture = function(t) return t._color end,
        SetTexture = function(t, path) t._texture = path end,
        GetTexture = function(t) return t._texture end,
        SetVertexColor = function(t, r, g, b, a) t._vertexColor = { r = r, g = g, b = b, a = a or 1 } end,
        GetVertexColor = function(t) return t._vertexColor end,
        SetTexCoord = function(t, ...) t._texCoord = { ... } end,
        SetRotation = function(t, rad) t._rotation = rad end,
        GetRotation = function(t) return t._rotation or 0 end,
        SetAlpha = function(t, a) t._alpha = a end,
        GetAlpha = function(t) return t._alpha or 1 end,
        Show = function(t) t._shown = true end,
        Hide = function(t) t._shown = false end,
        IsShown = function(t) return t._shown end,
    }
    table.insert(self._textures, tex)
    return tex
end

function FrameProto:CreateFontString(name, layer, inherits)
    local fs = {
        _name = name,
        _layer = layer,
        _inherits = inherits,
        _text = "",
        _shown = true,
        SetPoint = function(s, ...) s._point = { ... } end,
        SetWidth = function(s, w) s._width = w end,
        SetHeight = function(s, h) s._height = h end,
        SetWordWrap = function(s, flag) s._wordWrap = flag end,
        SetJustifyH = function(s, j) s._justifyH = j end,
        SetTextColor = function(s, r, g, b, a) s._color = { r = r, g = g, b = b, a = a or 1 } end,
        SetText = function(s, txt) s._text = tostring(txt or "") end,
        GetText = function(s) return s._text end,
        Show = function(s) s._shown = true end,
        Hide = function(s) s._shown = false end,
        IsShown = function(s) return s._shown end,
    }
    table.insert(self._fontStrings, fs)
    return fs
end

function FrameProto:Click(button)
    if self._scripts.OnClick then
        self._scripts.OnClick(self, button or "LeftButton")
    end
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
        _textures = {},
        _fontStrings = {},
        _shown = true,
    }, FrameProto)
    if name then
        _G[name] = f
    end
    table.insert(MockWoW.frames, f)
    return f
end

_G.UIParent = _G.CreateFrame("Frame", "UIParent")
_G.WorldMapFrame = _G.CreateFrame("Frame", "WorldMapFrame")
_G.Minimap = _G.CreateFrame("Frame", "Minimap")
_G.SlashCmdList = _G.SlashCmdList or {}

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
