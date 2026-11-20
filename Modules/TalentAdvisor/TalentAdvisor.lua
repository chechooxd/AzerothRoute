-- AzerothRoute: Talent Advisor engine (SPEC-06 / SPEC-21).
-- Binds grid coordinates to Blizzard talent nodes, diffs active vs target build ranks and finds the
-- next point to spend (levels 10-60). Its UI is the Guide Center's Talents mode (UI/Menu/Talents.lua).

local AR = _G.AzerothRoute
local TalentAdvisor = {
    CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" },
    CLASS_SHORT_EN = {
        WARRIOR = "WAR", PALADIN = "PAL", HUNTER = "HUN", ROGUE = "ROG",
        PRIEST = "PRI", SHAMAN = "SHA", MAGE = "MAG", WARLOCK = "WLK", DRUID = "DRU",
    },
    CLASS_SHORT_ES = {
        WARRIOR = "GUE", PALADIN = "PAL", HUNTER = "CAZ", ROGUE = "PIC",
        PRIEST = "SAC", SHAMAN = "CHA", MAGE = "MAG", WARLOCK = "BRU", DRUID = "DRU",
    },
    coordToEntry = {}, -- { ["posX,posY,entryIdx"] = entryID }
    entryToNode = {},  -- { [entryID] = nodeObj }
    buildsByIdent = {},
    selectedClass = nil,
    selectedIdent = nil,
    _blizzHooked = false,
}
AR.TalentAdvisor = TalentAdvisor

local function LGet(key)
    return (AR.L and AR.L:Get(key)) or key
end

local function LFormat(key, ...)
    if AR.L and AR.L.Format then
        return AR.L:Format(key, ...)
    end
    return string.format(key, ...)
end

function TalentAdvisor:Reset()
    self.coordToEntry = {}
    self.entryToNode = {}
    self.buildsByIdent = {}
    self.selectedClass = nil
    self.selectedIdent = nil
    self._blizzHooked = false
    if AR.TalentData then
        AR.TalentData.buildsByClass = {}
    end
end

function TalentAdvisor:RegisterTalentNode(className, talentName, coordKey)
    AR.TalentData.nodesByClass[className] = AR.TalentData.nodesByClass[className] or {}
    AR.TalentData.nodesByClass[className][talentName] = coordKey
end

function TalentAdvisor:RegisterBuild(className, buildSpec)
    AR.TalentData.buildsByClass[className] = AR.TalentData.buildsByClass[className] or {}
    local parsedNames = {}
    for line in (buildSpec.talents or ""):gmatch("[^\r\n]+") do
        local name = line:match("^%s*(.-)%s*$")
        if name ~= "" then
            table.insert(parsedNames, name)
        end
    end
    buildSpec.orderedNames = parsedNames
    buildSpec.class = className
    if buildSpec.ident and self.buildsByIdent[buildSpec.ident] then
        -- Replace existing spec metadata without duplicating list entries
        for i, existing in ipairs(AR.TalentData.buildsByClass[className]) do
            if existing.ident == buildSpec.ident then
                AR.TalentData.buildsByClass[className][i] = buildSpec
                break
            end
        end
    else
        table.insert(AR.TalentData.buildsByClass[className], buildSpec)
    end
    if buildSpec.ident then
        self.buildsByIdent[buildSpec.ident] = buildSpec
    end
end

function TalentAdvisor:LoadDefaultBuilds()
    local presets = AR.TalentData and AR.TalentData.PresetBuilds
    if not presets then return false end
    for _, className in ipairs(self.CLASS_ORDER) do
        local list = presets[className] or {}
        for _, spec in ipairs(list) do
            if not (spec.ident and self.buildsByIdent[spec.ident]) then
                self:RegisterBuild(className, {
                    ident = spec.ident,
                    name = spec.name,
                    nameES = spec.nameES,
                    specIndex = spec.specIndex,
                    suggested = spec.suggested,
                    talents = spec.talents,
                })
            end
        end
    end
    return true
end

function TalentAdvisor:GetLocalizedTalentName(talentName)
    if AR.L and AR.L:IsSpanish() and AR.TalentData and AR.TalentData.talentNamesES then
        return AR.TalentData.talentNamesES[talentName] or talentName
    end
    return talentName
end

function TalentAdvisor:GetTalentIcon(talentName, className)
    local icons = AR.TalentData and AR.TalentData.talentIcons
    if icons and talentName and icons[talentName] then
        return icons[talentName]
    end
    local clsMap = AR.TalentData and AR.TalentData.CLASS_DEFAULT_ICON
    return (clsMap and clsMap[className or self.selectedClass or "PALADIN"]) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function TalentAdvisor:GetClassFullName(classToken)
    if AR.L and AR.L:IsSpanish() and AR.TalentData and AR.TalentData.CLASS_NAMES_ES then
        return AR.TalentData.CLASS_NAMES_ES[classToken] or classToken
    end
    if AR.TalentData and AR.TalentData.CLASS_NAMES_EN then
        return AR.TalentData.CLASS_NAMES_EN[classToken] or classToken
    end
    return classToken
end

function TalentAdvisor:GetLocalizedBuildName(buildSpec)
    if not buildSpec then return "" end
    if AR.L and AR.L:IsSpanish() and buildSpec.nameES then
        return buildSpec.nameES
    end
    return buildSpec.name or buildSpec.ident or "Build"
end

function TalentAdvisor:GetClassBuilds(className)
    if not AR.TalentData.buildsByClass[className] or #AR.TalentData.buildsByClass[className] == 0 then
        self:LoadDefaultBuilds()
    end
    return AR.TalentData.buildsByClass[className] or {}
end

function TalentAdvisor:GetActivePlayerClass()
    if _G.UnitClass then
        local first, eng = _G.UnitClass("player")
        local presets = AR.TalentData and (AR.TalentData.PresetBuilds or AR.TalentData.nodesByClass) or {}
        if eng and presets[eng] then
            return eng
        end
        if type(first) == "string" and presets[first:upper()] then
            return first:upper()
        end
    end
    return "PALADIN"
end

function TalentAdvisor:BindBlizzardTalentNodes(blizzNodes)
    self.coordToEntry = {}
    self.entryToNode = {}
    for _, node in pairs(blizzNodes or {}) do
        for entryIdx, entryID in ipairs(node.entries or {}) do
            local key = string.format("%s,%s,%d", tostring(node.posX), tostring(node.posY), entryIdx)
            self.coordToEntry[key] = entryID
            self.entryToNode[entryID] = node
        end
    end
end

function TalentAdvisor:ResolveBuildEntries(ident)
    local build = self.buildsByIdent[ident]
    if not build then return {} end
    local classMap = AR.TalentData.nodesByClass[build.class] or {}
    local sequence = {}
    for _, tName in ipairs(build.orderedNames or {}) do
        local coordKey = classMap[tName]
        local entryID = coordKey and self.coordToEntry[coordKey]
        if entryID then
            table.insert(sequence, entryID)
        end
    end
    return sequence
end

function TalentAdvisor:GetBuildStatus(ident, maxPointsToEvaluate)
    local sequence = self:ResolveBuildEntries(ident)
    local limit = math.min(#sequence, tonumber(maxPointsToEvaluate) or #sequence)

    local targetRanks = {}
    for i = 1, limit do
        local entryID = sequence[i]
        targetRanks[entryID] = (targetRanks[entryID] or 0) + 1
    end

    local cumulative = {}
    local nextEntryID = nil
    for i = 1, limit do
        local entryID = sequence[i]
        cumulative[entryID] = (cumulative[entryID] or 0) + 1
        local node = self.entryToNode[entryID]
        local active = (node and node.activeRank) or 0
        if active < cumulative[entryID] then
            nextEntryID = entryID
            break
        end
    end

    local byEntry = {}
    local hasBad = false
    for entryID, node in pairs(self.entryToNode) do
        local req = targetRanks[entryID] or 0
        local cur = node.activeRank or 0
        if cur > req then
            hasBad = true
            byEntry[entryID] = { state = "BAD", delta = cur - req, isNext = false }
        elseif cur == req then
            byEntry[entryID] = { state = "GOOD", delta = 0, isNext = false }
        else
            byEntry[entryID] = {
                state = "PENDING",
                delta = req - cur,
                isNext = (entryID == nextEntryID),
            }
        end
    end

    return {
        hasBad = hasBad,
        nextEntryID = nextEntryID,
        byEntry = byEntry,
    }
end

function TalentAdvisor:LearnBuild(ident, maxPointsToSpend)
    local status = self:GetBuildStatus(ident, maxPointsToSpend)
    local configID = (_G.MockWoW and _G.MockWoW.player.talents.configID)
        or (_G.C_ClassTalents and _G.C_ClassTalents.GetActiveConfigID and _G.C_ClassTalents.GetActiveConfigID())
        or 1
    local treeID = (_G.MockWoW and _G.MockWoW.player.talents.treeID) or 1

    if status.hasBad and _G.C_Traits and _G.C_Traits.ResetTree then
        _G.C_Traits.ResetTree(configID, treeID)
    end

    local sequence = self:ResolveBuildEntries(ident)
    local limit = math.min(#sequence, tonumber(maxPointsToSpend) or #sequence)
    local seenRanks = {}

    for i = 1, limit do
        local entryID = sequence[i]
        seenRanks[entryID] = (seenRanks[entryID] or 0) + 1
        local node = self.entryToNode[entryID]
        if node and (node.activeRank or 0) < seenRanks[entryID] then
            if node.entries and #node.entries > 1 and _G.C_Traits and _G.C_Traits.SetSelection then
                _G.C_Traits.SetSelection(configID, node.nodeID, entryID)
            elseif _G.C_Traits and _G.C_Traits.PurchaseRank then
                _G.C_Traits.PurchaseRank(configID, node.nodeID)
            end
        end
    end
    return true
end

function TalentAdvisor:GetSpentPointsCount()
    local total = 0
    local seenNodes = {}
    for _, node in pairs(self.entryToNode) do
        local nid = node.nodeID or node
        if not seenNodes[nid] then
            seenNodes[nid] = true
            total = total + (node.activeRank or 0)
        end
    end
    if total > 0 then return total end
    local lvl = (_G.UnitLevel and _G.UnitLevel("player")) or 10
    return math.max(0, math.min(51, lvl - 9))
end

function TalentAdvisor:SelectClass(className)
    self:LoadDefaultBuilds()
    local builds = self:GetClassBuilds(className)
    self.selectedClass = className
    local chosen = builds[1]
    for _, b in ipairs(builds) do
        if b.suggested then
            chosen = b
            break
        end
    end
    self.selectedIdent = chosen and chosen.ident or nil
    self:RefreshUI()
end

function TalentAdvisor:SelectBuild(ident)
    self:LoadDefaultBuilds()
    local b = self.buildsByIdent[ident]
    if not b then return end
    self.selectedClass = b.class
    self.selectedIdent = ident
    self:RefreshUI()
end

-- The talents section is a mode of the Guide Center (UI/Menu/Talents.lua): these open and refresh it.
function TalentAdvisor:RefreshUI()
    local TP = AR.TalentsPanel
    if TP then
        TP.cache = nil
        if TP.panel and TP.panel:IsShown() then TP.panel:Render() end
    end
end

function TalentAdvisor:ShowUI()
    if AR.GuideMenu and AR.GuideMenu.Show then AR.GuideMenu:Show("talents") end
end

-- Opens the Guide Center on Talents, or closes it when Talents is already showing.
function TalentAdvisor:ToggleUI()
    local GM = AR.GuideMenu
    if not GM then return end
    if GM.frame and GM.frame:IsShown() and GM.mode == "talents" then
        GM.frame:Hide()
    else
        self:ShowUI()
    end
end

function TalentAdvisor:HookBlizzardFrames()
    if self._blizzHooked then return end
    self._blizzHooked = true

    local targetFrame = _G.PlayerSpellsFrame or _G.TalentFrame
    if targetFrame and targetFrame.HookScript then
        targetFrame:HookScript("OnShow", function()
            if _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.TalentsFrame and _G.PlayerSpellsFrame.TalentsFrame.GetTalentContainer then
                local container = _G.PlayerSpellsFrame.TalentsFrame:GetTalentContainer()
                if container and container.GetNodes then
                    self:BindBlizzardTalentNodes(container:GetNodes())
                end
            end
        end)
    end
end

return TalentAdvisor
