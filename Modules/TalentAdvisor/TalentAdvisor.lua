-- AzerothRoute: Talent Advisor Engine & Interactive 9-Class/27-Spec UI (SPEC-06 / SPEC-21)
-- Binds grid coordinates to Blizzard Talent nodes, diffs active vs target build ranks,
-- highlights the next point to spend (Levels 10-60), and renders a bilingual interactive roadmap window.

local AR = _G.AzerothRoute
local TalentAdvisor = {
    WIDTH = 460,
    HEIGHT = 480,
    ROWS_VISIBLE = 16,
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
    scrollOffset = 0,
    frame = nil,
    titleText = nil,
    closeButton = nil,
    classButtons = {},
    specTabs = {},
    nextTalentText = nil,
    roadmapRows = {},
    scrollUpBtn = nil,
    scrollDownBtn = nil,
    pageLabel = nil,
    applyButton = nil,
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
    self.scrollOffset = 0
    self.frame = nil
    self.titleText = nil
    self.closeButton = nil
    self.classButtons = {}
    self.specTabs = {}
    self.nextTalentText = nil
    self.roadmapRows = {}
    self.scrollUpBtn = nil
    self.scrollDownBtn = nil
    self.pageLabel = nil
    self.applyButton = nil
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
    self.scrollOffset = 0
    local chosen = builds[1]
    for _, b in ipairs(builds) do
        if b.suggested then
            chosen = b
            break
        end
    end
    self.selectedIdent = chosen and chosen.ident or nil
    if self.frame then
        self:RefreshUI()
    end
end

function TalentAdvisor:SelectBuild(ident)
    self:LoadDefaultBuilds()
    local b = self.buildsByIdent[ident]
    if not b then return end
    self.selectedClass = b.class
    self.selectedIdent = ident
    self.scrollOffset = 0
    if self.frame then
        self:RefreshUI()
    end
end

local function createFlatButton(parent, name, labelText, width, height)
    local btn = AR.UI:Create("Button", parent, name)
    btn:SetSize(width, height)
    if btn.CreateTexture then
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints(btn)
        btn.bg:SetColorTexture(0.15, 0.18, 0.26, 0.95)
    end
    if btn.CreateFontString then
        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.label:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn.label:SetText(labelText or "")
    end
    return btn
end

function TalentAdvisor:InitializeUI()
    if self.frame then return self.frame end
    self:LoadDefaultBuilds()

    if not self.selectedClass then
        self:SelectClass(self:GetActivePlayerClass())
    elseif not self.selectedIdent then
        self:SelectClass(self.selectedClass)
    end

    local f = AR.UI:Create("Frame", _G.UIParent, "AzerothRouteTalentFrame")
    f:SetSize(self.WIDTH, self.HEIGHT)
    f:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
    if f.SetFrameStrata then f:SetFrameStrata("DIALOG") end
    if f.SetFrameLevel then f:SetFrameLevel(120) end
    if f.SetMovable then f:SetMovable(true) end
    if f.EnableMouse then f:EnableMouse(true) end
    if f.RegisterForDrag then f:RegisterForDrag("LeftButton") end
    f:SetScript("OnDragStart", function(frame)
        if frame.StartMoving then frame:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(frame)
        if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end
    end)

    if f.CreateTexture then
        f.bg = f:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAllPoints(f)
        f.bg:SetColorTexture(0.06, 0.07, 0.11, 0.97)

        f.headerBar = f:CreateTexture(nil, "ARTWORK")
        f.headerBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        f.headerBar:SetSize(self.WIDTH, 32)
        f.headerBar:SetColorTexture(0.11, 0.13, 0.20, 1.0)

        f.nextBannerBg = f:CreateTexture(nil, "ARTWORK")
        f.nextBannerBg:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -104)
        f.nextBannerBg:SetSize(self.WIDTH - 24, 26)
        f.nextBannerBg:SetColorTexture(0.16, 0.24, 0.18, 0.95)
    end

    if f.CreateFontString then
        self.titleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        self.titleText:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -8)
        self.titleText:SetText(LGet("UI_TALENT_TITLE"))

        self.nextTalentText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.nextTalentText:SetPoint("LEFT", f, "TOPLEFT", 20, -117)
        self.nextTalentText:SetJustifyH("LEFT")

        self.pageLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.pageLabel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 22)
    end

    -- Top-right close [X]
    self.closeButton = createFlatButton(f, "AzerothRouteTalentClose", "X", 24, 22)
    self.closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -5)
    self.closeButton:SetScript("OnClick", function() f:Hide() end)

    -- 9 Class Selector Buttons
    self.classButtons = {}
    for idx, clsToken in ipairs(self.CLASS_ORDER) do
        local cBtn = createFlatButton(f, "AzerothRouteTalentClass" .. clsToken, clsToken:sub(1, 3), 46, 24)
        cBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 10 + (idx - 1) * 49, -40)
        cBtn._classToken = clsToken
        cBtn:SetScript("OnClick", function()
            self:SelectClass(clsToken)
        end)
        table.insert(self.classButtons, cBtn)
    end

    -- 3 Specialization Tab Buttons
    self.specTabs = {}
    for idx = 1, 3 do
        local sBtn = createFlatButton(f, "AzerothRouteTalentSpec" .. idx, "Spec " .. idx, 142, 26)
        sBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 10 + (idx - 1) * 149, -70)
        sBtn:SetScript("OnClick", function(btn)
            if btn._ident then
                self:SelectBuild(btn._ident)
            end
        end)
        table.insert(self.specTabs, sBtn)
    end

    -- 16 Scrollable Level 10-60 Roadmap Rows
    self.roadmapRows = {}
    for r = 1, self.ROWS_VISIBLE do
        local row = AR.UI:Create("Frame", f, "AzerothRouteTalentRow" .. r)
        row:SetSize(self.WIDTH - 48, 17)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -138 - (r - 1) * 18)
        if row.CreateTexture then
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints(row)
            row.bg:SetColorTexture(0.11, 0.13, 0.18, 0.90)
        end
        if row.CreateFontString then
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.label:SetJustifyH("LEFT")
        end
        row:Hide()
        table.insert(self.roadmapRows, row)
    end

    -- Roadmap Scroll Up / Down Buttons
    self.scrollUpBtn = createFlatButton(f, "AzerothRouteTalentUp", "^", 24, 24)
    self.scrollUpBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -138)
    self.scrollUpBtn:SetScript("OnClick", function()
        self.scrollOffset = math.max(0, (self.scrollOffset or 0) - 8)
        self:RefreshUI()
    end)

    self.scrollDownBtn = createFlatButton(f, "AzerothRouteTalentDown", "v", 24, 24)
    self.scrollDownBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 56)
    self.scrollDownBtn:SetScript("OnClick", function()
        local b = self.selectedIdent and self.buildsByIdent[self.selectedIdent]
        local maxOff = math.max(0, ((b and b.orderedNames and #b.orderedNames) or 51) - self.ROWS_VISIBLE)
        self.scrollOffset = math.min(maxOff, (self.scrollOffset or 0) + 8)
        self:RefreshUI()
    end)

    -- Apply Selected Build Button
    self.applyButton = createFlatButton(f, "AzerothRouteTalentApply", LGet("UI_TALENT_APPLY"), 180, 28)
    self.applyButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 12)
    if self.applyButton.bg then
        self.applyButton.bg:SetColorTexture(0.16, 0.50, 0.28, 1.0)
    end
    self.applyButton:SetScript("OnClick", function()
        if not self.selectedIdent then return end
        local spentCap = math.max(1, self:GetSpentPointsCount() + 1)
        self:LearnBuild(self.selectedIdent, spentCap)
        if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
            local b = self.buildsByIdent[self.selectedIdent]
            _G.DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99AzerothRoute:|r " .. LGet("UI_TALENT_APPLY") .. " -> " .. self:GetLocalizedBuildName(b))
        end
        self:RefreshUI()
    end)

    f:Hide()
    self.frame = f
    self:RefreshUI()
    return f
end

function TalentAdvisor:RefreshUI()
    if not self.frame then return end

    if self.titleText then
        self.titleText:SetText(LGet("UI_TALENT_TITLE"))
    end
    if self.applyButton and self.applyButton.label then
        self.applyButton.label:SetText(LGet("UI_TALENT_APPLY"))
    end

    local isEs = AR.L and AR.L:IsSpanish()
    local shortMap = isEs and self.CLASS_SHORT_ES or self.CLASS_SHORT_EN
    for _, cBtn in ipairs(self.classButtons) do
        local cls = cBtn._classToken
        if cBtn.label then
            cBtn.label:SetText(shortMap[cls] or cls:sub(1, 3))
        end
        if cBtn.bg then
            if cls == self.selectedClass then
                cBtn.bg:SetColorTexture(0.24, 0.45, 0.74, 1.0)
            else
                cBtn.bg:SetColorTexture(0.14, 0.17, 0.24, 0.95)
            end
        end
    end

    local builds = self:GetClassBuilds(self.selectedClass or "PALADIN")
    for idx = 1, 3 do
        local sBtn = self.specTabs[idx]
        local b = builds[idx]
        if sBtn then
            if b then
                sBtn._ident = b.ident
                if sBtn.label then
                    local prefix = b.suggested and "* " or ""
                    sBtn.label:SetText(prefix .. self:GetLocalizedBuildName(b))
                end
                if sBtn.bg then
                    if b.ident == self.selectedIdent then
                        sBtn.bg:SetColorTexture(0.22, 0.50, 0.34, 1.0)
                    else
                        sBtn.bg:SetColorTexture(0.14, 0.17, 0.24, 0.95)
                    end
                end
                sBtn:Show()
            else
                sBtn._ident = nil
                sBtn:Hide()
            end
        end
    end

    local activeBuild = self.selectedIdent and self.buildsByIdent[self.selectedIdent]
    local sequence = (activeBuild and activeBuild.orderedNames) or {}
    local spent = self:GetSpentPointsCount()
    local nextStep = math.min(#sequence, spent + 1)

    if self.nextTalentText then
        if #sequence == 0 then
            self.nextTalentText:SetText("")
        elseif spent >= #sequence then
            self.nextTalentText:SetText(LGet("UI_TALENT_COMPLETED"))
        else
            local nextName = self:GetLocalizedTalentName(sequence[nextStep])
            self.nextTalentText:SetText(LFormat("UI_TALENT_NEXT_POINT", 9 + nextStep, nextName))
        end
    end

    local offset = self.scrollOffset or 0
    for r = 1, self.ROWS_VISIBLE do
        local row = self.roadmapRows[r]
        local seqIdx = offset + r
        local tName = sequence[seqIdx]
        if row then
            if tName then
                local locName = self:GetLocalizedTalentName(tName)
                local lineText = LFormat("UI_TALENT_LEVEL_FMT", 9 + seqIdx, locName)
                if row.label then
                    row.label:SetText(lineText)
                    if row.label.SetTextColor then
                        if seqIdx <= spent then
                            row.label:SetTextColor(0.35, 0.90, 0.45)
                        elseif seqIdx == nextStep then
                            row.label:SetTextColor(1.0, 0.85, 0.25)
                        else
                            row.label:SetTextColor(0.82, 0.85, 0.90)
                        end
                    end
                end
                if row.bg then
                    if seqIdx == nextStep then
                        row.bg:SetColorTexture(0.22, 0.32, 0.16, 0.95)
                    elseif seqIdx <= spent then
                        row.bg:SetColorTexture(0.10, 0.20, 0.14, 0.90)
                    else
                        row.bg:SetColorTexture(0.11, 0.13, 0.18, 0.90)
                    end
                end
                row:Show()
            else
                row:Hide()
            end
        end
    end

    if self.pageLabel and #sequence > 0 then
        local firstLvl = 10 + offset
        local lastLvl = math.min(9 + #sequence, 9 + offset + self.ROWS_VISIBLE)
        self.pageLabel:SetText(string.format("Lv %d-%d", firstLvl, lastLvl))
    end
end

function TalentAdvisor:ShowUI()
    local f = self:InitializeUI()
    self:RefreshUI()
    f:Show()
end

function TalentAdvisor:ToggleUI()
    local f = self:InitializeUI()
    if f:IsShown() then
        f:Hide()
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
