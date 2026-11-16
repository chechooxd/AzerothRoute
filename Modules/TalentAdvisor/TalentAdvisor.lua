-- AzerothRoute: Talent Advisor Engine (SPEC-06)
-- Binds grid coordinates to PlayerSpellsFrame.TalentsFrame nodes, diffs active vs target build ranks,
-- highlights the next point to spend, and auto-learns via C_Traits.

local AR = _G.AzerothRoute
local TalentAdvisor = {
    coordToEntry = {}, -- { ["posX,posY,entryIdx"] = entryID }
    entryToNode = {},  -- { [entryID] = nodeObj }
    buildsByIdent = {},
}
AR.TalentAdvisor = TalentAdvisor

function TalentAdvisor:Reset()
    self.coordToEntry = {}
    self.entryToNode = {}
    self.buildsByIdent = {}
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
    table.insert(AR.TalentData.buildsByClass[className], buildSpec)
    if buildSpec.ident then
        self.buildsByIdent[buildSpec.ident] = buildSpec
    end
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

    -- Identify the exact next talent entryID in sequence that is still below its cumulative rank at step i
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
    local configID = (_G.MockWoW and _G.MockWoW.player.talents.configID) or 1
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

return TalentAdvisor
