-- AzerothRoute: Talent Advisor Engine & Interactive 9-Class/27-Spec UI (SPEC-06 / SPEC-21)
-- Binds grid coordinates to Blizzard Talent nodes, diffs active vs target build ranks,
-- highlights the next point to spend (Levels 10-60), and renders a bilingual interactive roadmap window.

local AR = _G.AzerothRoute
local TalentAdvisor = {
    WIDTH = 620,
    HEIGHT = 520,
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
    nextTalentIcon = nil,
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
    self.nextTalentIcon = nil
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

-- Flat button in the addon's look: transparent until hovered or selected (gold accent bar).
local function createFlatButton(parent, name, labelText, width, height, style)
    local S = AR.Skins
    local btn = AR.UI:Create("Button", parent, name)
    btn:SetSize(width, height)
    btn._style = style or "list"
    if btn.CreateTexture then
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints(btn)
        if btn._style == "primary" then
            S:Paint(btn.bg, "accent", 1)
        elseif btn._style == "ghost" then
            S:Paint(btn.bg, "panelRaised", 1)
            S:AddBorder(btn, "border")
        else
            btn.bg:SetColorTexture(0, 0, 0, 0)
        end
        btn.accent = btn:CreateTexture(nil, "ARTWORK")
        btn.accent:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        btn.accent:SetSize(2, height)
        S:Paint(btn.accent, "accent")
        btn.accent:Hide()
    end
    if btn.CreateFontString then
        btn.label = btn:CreateFontString(nil, "OVERLAY", btn._style == "primary" and "GameFontNormal" or "GameFontHighlight")
        btn.label:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn.label:SetText(labelText or "")
        if btn.label.SetTextColor then
            if btn._style == "primary" then btn.label:SetTextColor(0.10, 0.09, 0.07, 1)
            else btn.label:SetTextColor(S:RGBA(btn._style == "ghost" and "text" or "textMuted")) end
        end
    end
    btn:SetScript("OnEnter", function(b)
        if b._style == "list" and not b._selected then S:Paint(b.bg, "hover") end
        if b._style == "ghost" then S:Paint(b.bg, "hover", 1) end
    end)
    btn:SetScript("OnLeave", function(b)
        if b._style == "list" and not b._selected and b.bg then b.bg:SetColorTexture(0, 0, 0, 0) end
        if b._style == "ghost" then S:Paint(b.bg, "panelRaised", 1) end
    end)
    return btn
end

local function setSelected(btn, on)
    local S = AR.Skins
    btn._selected = on == true
    if btn.bg then
        if on then S:Paint(btn.bg, "selected") else btn.bg:SetColorTexture(0, 0, 0, 0) end
    end
    if btn.accent then
        if on then btn.accent:Show() else btn.accent:Hide() end
    end
    if btn.label and btn.label.SetTextColor then
        btn.label:SetTextColor(S:RGBA(on and "text" or "textMuted"))
    end
end

-- Layout (Guide Center look): sidebar of classes, header with the build and points, spec tabs with a
-- gold underline, a "next point" card, the level roadmap, a thin progress bar and a gold Apply button.
local SIDE_W, HEADER_H = 150, 50
local ROW_H = 20

function TalentAdvisor:InitializeUI()
    if self.frame then return self.frame end
    self:LoadDefaultBuilds()
    local S = AR.Skins

    if not self.selectedClass then
        self:SelectClass(self:GetActivePlayerClass())
    elseif not self.selectedIdent then
        self:SelectClass(self.selectedClass)
    end

    local W, H = self.WIDTH, self.HEIGHT
    local f = AR.UI:Create("Frame", _G.UIParent, "AzerothRouteTalentFrame")
    f:SetSize(W, H)
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
    if f.EnableMouseWheel then f:EnableMouseWheel(true) end
    f:SetScript("OnMouseWheel", function(_, delta) self:ScrollRoadmap(-(delta or 0) * 3) end)

    local x0 = SIDE_W + 1
    if f.CreateTexture then
        f.bg = f:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAllPoints(f)
        S:Paint(f.bg, "panel", 0.98)
        S:AddBorder(f, "border")

        f.side = f:CreateTexture(nil, "BACKGROUND")
        f.side:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        f.side:SetSize(SIDE_W, H - 2)
        S:Paint(f.side, "panelRaised")

        f.headerBar = f:CreateTexture(nil, "ARTWORK")
        f.headerBar:SetPoint("TOPLEFT", f, "TOPLEFT", x0, -1)
        f.headerBar:SetSize(W - x0 - 1, HEADER_H)
        S:Paint(f.headerBar, "panel", 1)
        f.headerRule = f:CreateTexture(nil, "ARTWORK")
        f.headerRule:SetPoint("TOPLEFT", f, "TOPLEFT", x0, -(HEADER_H + 30))
        f.headerRule:SetSize(W - x0 - 1, 1)
        S:Paint(f.headerRule, "divider")

        -- Spec tab underline (moved under the selected tab on refresh).
        f.specUnderline = f:CreateTexture(nil, "OVERLAY")
        f.specUnderline:SetSize(120, 2)
        S:Paint(f.specUnderline, "accent")

        -- "Next point" card.
        f.nextBannerBg = f:CreateTexture(nil, "ARTWORK")
        f.nextBannerBg:SetPoint("TOPLEFT", f, "TOPLEFT", x0 + 12, -(HEADER_H + 40))
        f.nextBannerBg:SetSize(W - x0 - 24, 34)
        S:Paint(f.nextBannerBg, "whileHere")
        f.nextBannerBar = f:CreateTexture(nil, "OVERLAY")
        f.nextBannerBar:SetPoint("TOPLEFT", f, "TOPLEFT", x0 + 12, -(HEADER_H + 40))
        f.nextBannerBar:SetSize(2, 34)
        S:Paint(f.nextBannerBar, "accent")

        self.nextTalentIcon = f:CreateTexture(nil, "OVERLAY")
        self.nextTalentIcon:SetSize(22, 22)
        self.nextTalentIcon:SetPoint("TOPLEFT", f, "TOPLEFT", x0 + 22, -(HEADER_H + 46))
        self.nextTalentIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

        -- Points progress (spent / build length).
        f.track = f:CreateTexture(nil, "ARTWORK")
        f.track:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x0 + 12, 52)
        f.track:SetSize(W - x0 - 24, 3)
        S:Paint(f.track, "track")
        f.fill = f:CreateTexture(nil, "OVERLAY")
        f.fill:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x0 + 12, 52)
        f.fill:SetSize(1, 3)
        S:Paint(f.fill, "accent")
        f.fill:Hide()

        -- Brand mark (rotated gold square) in the sidebar.
        f.mark = f:CreateTexture(nil, "OVERLAY")
        f.mark:SetPoint("TOPLEFT", f, "TOPLEFT", 17, -16)
        f.mark:SetSize(10, 10)
        S:Paint(f.mark, "accent", 1)
        if f.mark.SetRotation then f.mark:SetRotation(math.pi / 4) end
    end

    if f.CreateFontString then
        f.brand = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.brand:SetPoint("TOPLEFT", f, "TOPLEFT", 34, -10)
        f.brand:SetText("|cffffffffAzeroth|r|cfff4c54aRoute|r")
        f.brandTag = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.brandTag:SetPoint("TOPLEFT", f, "TOPLEFT", 34, -26)
        if f.brandTag.SetTextColor then f.brandTag:SetTextColor(S:RGBA("textMuted")) end

        self.titleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        self.titleText:SetPoint("TOPLEFT", f, "TOPLEFT", x0 + 16, -10)
        if self.titleText.SetTextColor then self.titleText:SetTextColor(S:RGBA("text")) end
        self.titleText:SetText(LGet("UI_TALENT_TITLE"))

        self.headerSub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.headerSub:SetPoint("TOPLEFT", f, "TOPLEFT", x0 + 16, -30)
        if self.headerSub.SetTextColor then self.headerSub:SetTextColor(S:RGBA("textMuted")) end

        self.nextTalentText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        self.nextTalentText:SetPoint("TOPLEFT", f, "TOPLEFT", x0 + 52, -(HEADER_H + 51))
        if self.nextTalentText.SetWidth then self.nextTalentText:SetWidth(W - x0 - 80) end
        if self.nextTalentText.SetWordWrap then self.nextTalentText:SetWordWrap(false) end
        self.nextTalentText:SetJustifyH("LEFT")

        self.pageLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.pageLabel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 60)
        if self.pageLabel.SetTextColor then self.pageLabel:SetTextColor(S:RGBA("textMuted")) end

        self.pointsText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.pointsText:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x0 + 12, 60)
        if self.pointsText.SetTextColor then self.pointsText:SetTextColor(S:RGBA("textMuted")) end
    end

    -- Close ×
    self.closeButton = createFlatButton(f, "AzerothRouteTalentClose", "×", 22, 22, "list")
    self.closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    self.closeButton:SetScript("OnClick", function() f:Hide() end)

    -- Class list in the sidebar (crest + full class name).
    self.classButtons = {}
    local classCoords = AR.TalentData and AR.TalentData.CLASS_ICON_TCOORDS or {}
    for idx, clsToken in ipairs(self.CLASS_ORDER) do
        local cBtn = createFlatButton(f, "AzerothRouteTalentClass" .. clsToken, clsToken, SIDE_W, 28, "list")
        cBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -56 - (idx - 1) * 30)
        cBtn._classToken = clsToken
        if cBtn.CreateTexture then
            cBtn.icon = cBtn:CreateTexture(nil, "OVERLAY")
            cBtn.icon:SetSize(16, 16)
            cBtn.icon:SetPoint("LEFT", cBtn, "LEFT", 12, 0)
            cBtn.icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            local tc = classCoords[clsToken]
            if tc and cBtn.icon.SetTexCoord then
                cBtn.icon:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
            end
        end
        if cBtn.label then
            if cBtn.label.ClearAllPoints then cBtn.label:ClearAllPoints() end
            cBtn.label:SetPoint("LEFT", cBtn, "LEFT", 36, 0)
            cBtn.label:SetJustifyH("LEFT")
        end
        cBtn:SetScript("OnClick", function()
            self:SelectClass(clsToken)
        end)
        table.insert(self.classButtons, cBtn)
    end

    -- Spec tabs (text tabs; the selected one is bright with a gold underline).
    self.specTabs = {}
    for idx = 1, 3 do
        local sBtn = createFlatButton(f, "AzerothRouteTalentSpec" .. idx, "Spec " .. idx, 120, 26, "tab")
        sBtn:SetPoint("TOPLEFT", f, "TOPLEFT", x0 + 12 + (idx - 1) * 126, -(HEADER_H + 2))
        sBtn:SetScript("OnClick", function(btn)
            if btn._ident then
                self:SelectBuild(btn._ident)
            end
        end)
        table.insert(self.specTabs, sBtn)
    end

    -- Level roadmap rows (talent icon, "Level N: Talent", tick when spent).
    self.roadmapRows = {}
    local listTop = HEADER_H + 84
    for r = 1, self.ROWS_VISIBLE do
        local row = AR.UI:Create("Frame", f, "AzerothRouteTalentRow" .. r)
        row:SetSize(W - x0 - 48, ROW_H)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", x0 + 12, -listTop - (r - 1) * ROW_H)
        if row.CreateTexture then
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints(row)
            row.bg:SetColorTexture(0, 0, 0, 0)

            row.accent = row:CreateTexture(nil, "ARTWORK")
            row.accent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            row.accent:SetSize(2, ROW_H)
            S:Paint(row.accent, "accent")
            row.accent:Hide()

            row.icon = row:CreateTexture(nil, "OVERLAY")
            row.icon:SetSize(16, 16)
            row.icon:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

            row.check = row:CreateTexture(nil, "OVERLAY")
            row.check:SetSize(14, 14)
            row.check:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            row.check:SetTexture(AR.Skins.CHECK_ICON)
            row.check:Hide()
        end
        if row.CreateFontString then
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.label:SetPoint("LEFT", row, "LEFT", 32, 0)
            row.label:SetJustifyH("LEFT")
        end
        row:Hide()
        table.insert(self.roadmapRows, row)
    end

    -- Scroll buttons beside the roadmap.
    self.scrollUpBtn = createFlatButton(f, "AzerothRouteTalentUp", "^", 22, 22, "list")
    self.scrollUpBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -listTop)
    self.scrollUpBtn:SetScript("OnClick", function() self:ScrollRoadmap(-8) end)

    self.scrollDownBtn = createFlatButton(f, "AzerothRouteTalentDown", "v", 22, 22, "list")
    self.scrollDownBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -(listTop + (self.ROWS_VISIBLE - 1) * ROW_H))
    self.scrollDownBtn:SetScript("OnClick", function() self:ScrollRoadmap(8) end)

    -- Apply the selected build (gold primary button).
    self.applyButton = createFlatButton(f, "AzerothRouteTalentApply", LGet("UI_TALENT_APPLY"), 200, 30, "primary")
    self.applyButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)
    self.applyButton:SetScript("OnClick", function()
        if not self.selectedIdent then return end
        local spentCap = math.max(1, self:GetSpentPointsCount() + 1)
        self:LearnBuild(self.selectedIdent, spentCap)
        if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
            local b = self.buildsByIdent[self.selectedIdent]
            _G.DEFAULT_CHAT_FRAME:AddMessage("|cfff4c54aAzerothRoute:|r " .. LGet("UI_TALENT_APPLY") .. " -> " .. self:GetLocalizedBuildName(b))
        end
        self:RefreshUI()
    end)

    f:Hide()
    self.frame = f
    self:RefreshUI()
    return f
end

-- Scrolls the roadmap by `delta` rows within the build length.
function TalentAdvisor:ScrollRoadmap(delta)
    local b = self.selectedIdent and self.buildsByIdent[self.selectedIdent]
    local maxOff = math.max(0, ((b and b.orderedNames and #b.orderedNames) or 51) - self.ROWS_VISIBLE)
    self.scrollOffset = math.max(0, math.min(maxOff, (self.scrollOffset or 0) + (delta or 0)))
    self:RefreshUI()
    return self.scrollOffset
end

function TalentAdvisor:RefreshUI()
    if not self.frame then return end
    local S = AR.Skins
    local f = self.frame

    if self.titleText then
        self.titleText:SetText(LGet("UI_TALENTS"))
    end
    if f.brandTag then f.brandTag:SetText(LGet("UI_TALENT_TITLE"):match("—%s*(.+)$") or LGet("UI_TALENTS")) end
    if self.applyButton and self.applyButton.label then
        self.applyButton.label:SetText(LGet("UI_TALENT_APPLY"))
    end

    for _, cBtn in ipairs(self.classButtons) do
        local cls = cBtn._classToken
        if cBtn.label then cBtn.label:SetText(self:GetClassFullName(cls)) end
        setSelected(cBtn, cls == self.selectedClass)
    end

    local builds = self:GetClassBuilds(self.selectedClass or "PALADIN")
    for idx = 1, 3 do
        local sBtn = self.specTabs[idx]
        local b = builds[idx]
        if sBtn then
            if b then
                sBtn._ident = b.ident
                if sBtn.label then
                    local prefix = b.suggested and "|cfff4c54a*|r " or ""
                    sBtn.label:SetText(prefix .. self:GetLocalizedBuildName(b))
                    if sBtn.label.SetTextColor then
                        sBtn.label:SetTextColor(S:RGBA(b.ident == self.selectedIdent and "text" or "textMuted"))
                    end
                end
                if b.ident == self.selectedIdent and f.specUnderline then
                    f.specUnderline:SetPoint("TOPLEFT", sBtn, "BOTTOMLEFT", 0, 0)
                    f.specUnderline:SetWidth(120)
                    f.specUnderline:Show()
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

    if self.headerSub then
        local buildName = activeBuild and self:GetLocalizedBuildName(activeBuild) or ""
        self.headerSub:SetText(string.format("%s · %s · %d / %d",
            self:GetClassFullName(self.selectedClass or "PALADIN"), buildName, math.min(spent, #sequence), #sequence))
    end

    if self.nextTalentText then
        if #sequence == 0 then
            self.nextTalentText:SetText("")
            if self.nextTalentIcon then self.nextTalentIcon:Hide() end
        elseif spent >= #sequence then
            self.nextTalentText:SetText(LGet("UI_TALENT_COMPLETED"))
            if self.nextTalentIcon then
                self.nextTalentIcon:SetTexture(self:GetTalentIcon(sequence[#sequence], self.selectedClass))
                self.nextTalentIcon:Show()
            end
        else
            local nextName = self:GetLocalizedTalentName(sequence[nextStep])
            self.nextTalentText:SetText(LFormat("UI_TALENT_NEXT_POINT", 9 + nextStep, nextName))
            if self.nextTalentIcon then
                self.nextTalentIcon:SetTexture(self:GetTalentIcon(sequence[nextStep], self.selectedClass))
                self.nextTalentIcon:Show()
            end
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
                local done, isNext = seqIdx <= spent, seqIdx == nextStep and spent < #sequence
                if row.icon then
                    row.icon:SetTexture(self:GetTalentIcon(tName, self.selectedClass))
                    if row.icon.SetAlpha then row.icon:SetAlpha(done and 0.6 or 1) end
                    row.icon:Show()
                end
                if row.label then
                    row.label:SetText(lineText)
                    if row.label.SetTextColor then
                        if done then row.label:SetTextColor(S:RGBA("textDone"))
                        elseif isNext then row.label:SetTextColor(S:RGBA("accent"))
                        else row.label:SetTextColor(S:RGBA("text")) end
                    end
                end
                if row.bg then
                    if isNext then S:Paint(row.bg, "selected") else row.bg:SetColorTexture(0, 0, 0, 0) end
                end
                if row.accent then if isNext then row.accent:Show() else row.accent:Hide() end end
                if row.check then if done then row.check:Show() else row.check:Hide() end end
                row:Show()
            else
                row:Hide()
            end
        end
    end

    if self.pageLabel and #sequence > 0 then
        local firstLvl = 10 + offset
        local lastLvl = math.min(9 + #sequence, 9 + offset + self.ROWS_VISIBLE)
        self.pageLabel:SetText(string.format("%d-%d", firstLvl, lastLvl))
    end
    if self.pointsText then
        self.pointsText:SetText(string.format("%d / %d", math.min(spent, #sequence), #sequence))
    end
    if f.fill and f.track then
        local frac = #sequence > 0 and math.min(1, spent / #sequence) or 0
        local w = math.floor((self.WIDTH - SIDE_W - 25) * frac + 0.5)
        if w >= 1 then f.fill:SetWidth(w); f.fill:Show() else f.fill:Hide() end
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
