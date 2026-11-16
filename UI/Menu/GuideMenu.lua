-- AzerothRoute: Interactive GuideMenu Command Center with Localization, Pagination & Talent Advisor Link (SPEC-13 / SPEC-17 / SPEC-20 / SPEC-21)

local AR = _G.AzerothRoute
local GuideMenu = {
    WIDTH = 720,
    HEIGHT = 480,
    MAX_ROWS = 14,
    CATEGORIES = {
        { id = "SUGGESTED", labelKey = "UI_SUGGESTED" },
        { id = "LEVELING",  labelKey = "UI_LEVELING" },
        { id = "DUNGEONS",  labelKey = "UI_DUNGEONS" },
        { id = "PROFESSIONS", labelKey = "UI_PROFESSIONS" },
        { id = "GOLD",      labelKey = "UI_GOLD" },
        { id = "ALL",       labelKey = "UI_ALL_GUIDES" },
    },
    activeCategory = "ALL",
    pageOffset = 0,
    selectedGuide = nil,
    frame = nil,
    headerText = nil,
    closeButton = nil,
    loadButton = nil,
    talentButton = nil,
    prevPageButton = nil,
    nextPageButton = nil,
    pageText = nil,
    categoryButtons = {},
    guideRowButtons = {},
    detailTitle = nil,
    detailDesc = nil,
    detailMeta = nil,
}
AR.GuideMenu = GuideMenu

local function LGet(key)
    return (AR.L and AR.L:Get(key)) or key
end

local function LFormat(key, ...)
    if AR.L and AR.L.Format then
        return AR.L:Format(key, ...)
    end
    return string.format(key, ...)
end

local function getDisplayTitle(guide)
    if not guide then return "" end
    if AR.L and AR.L:IsSpanish() and guide.displayTitleES then
        return guide.displayTitleES
    end
    if guide.displayTitleEN then
        return guide.displayTitleEN
    end
    return guide.title or "Guide"
end

function GuideMenu:Reset()
    self.activeCategory = "ALL"
    self.pageOffset = 0
    self.selectedGuide = nil
    self.frame = nil
    self.headerText = nil
    self.closeButton = nil
    self.loadButton = nil
    self.talentButton = nil
    self.prevPageButton = nil
    self.nextPageButton = nil
    self.pageText = nil
    self.categoryButtons = {}
    self.guideRowButtons = {}
    self.detailTitle = nil
    self.detailDesc = nil
    self.detailMeta = nil
end

local function createMenuButton(parent, name, labelText, width, height, centered)
    local btn = AR.UI:Create("Button", parent, name)
    btn:SetSize(width, height)
    if btn.CreateTexture then
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints(btn)
        btn.bg:SetColorTexture(0.14, 0.17, 0.24, 0.95)
    end
    if btn.CreateFontString then
        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        if centered then
            btn.label:SetPoint("CENTER", btn, "CENTER", 0, 0)
            btn.label:SetJustifyH("CENTER")
        else
            btn.label:SetPoint("LEFT", btn, "LEFT", 10, 0)
            btn.label:SetJustifyH("LEFT")
        end
        btn.label:SetText(labelText)
    end
    return btn
end

function GuideMenu:InitializeFrame()
    if self.frame then return self.frame end

    local f = AR.UI:Create("Frame", _G.UIParent, "AzerothRouteGuideMenu")
    f:SetSize(self.WIDTH, self.HEIGHT)
    f:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
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
        f.bg:SetColorTexture(0.06, 0.07, 0.10, 0.97)

        f.headerBar = f:CreateTexture(nil, "ARTWORK")
        f.headerBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        f.headerBar:SetSize(self.WIDTH, 36)
        f.headerBar:SetColorTexture(0.11, 0.13, 0.19, 1.0)

        -- Left sidebar divider
        f.leftPaneBg = f:CreateTexture(nil, "ARTWORK")
        f.leftPaneBg:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -44)
        f.leftPaneBg:SetSize(140, self.HEIGHT - 54)
        f.leftPaneBg:SetColorTexture(0.09, 0.10, 0.14, 0.95)

        -- Center guide list background
        f.centerPaneBg = f:CreateTexture(nil, "ARTWORK")
        f.centerPaneBg:SetPoint("TOPLEFT", f, "TOPLEFT", 158, -44)
        f.centerPaneBg:SetSize(310, self.HEIGHT - 54)
        f.centerPaneBg:SetColorTexture(0.08, 0.09, 0.13, 0.95)

        -- Right details pane background
        f.rightPaneBg = f:CreateTexture(nil, "ARTWORK")
        f.rightPaneBg:SetPoint("TOPLEFT", f, "TOPLEFT", 476, -44)
        f.rightPaneBg:SetSize(234, self.HEIGHT - 54)
        f.rightPaneBg:SetColorTexture(0.09, 0.11, 0.16, 0.95)
    end

    if f.CreateFontString then
        self.headerText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        self.headerText:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -10)
        self.headerText:SetText(LGet("UI_GUIDE_MENU_TITLE"))

        self.detailTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        self.detailTitle:SetPoint("TOPLEFT", f, "TOPLEFT", 488, -56)
        if self.detailTitle.SetWidth then self.detailTitle:SetWidth(210) end
        self.detailTitle:SetJustifyH("LEFT")
        self.detailTitle:SetText(LGet("UI_SELECT_GUIDE"))

        self.detailMeta = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.detailMeta:SetPoint("TOPLEFT", f, "TOPLEFT", 488, -90)
        if self.detailMeta.SetWidth then self.detailMeta:SetWidth(210) end
        self.detailMeta:SetJustifyH("LEFT")
        self.detailMeta:SetText("")

        self.detailDesc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.detailDesc:SetPoint("TOPLEFT", f, "TOPLEFT", 488, -120)
        if self.detailDesc.SetWidth then self.detailDesc:SetWidth(210) end
        self.detailDesc:SetJustifyH("LEFT")
        self.detailDesc:SetText(LGet("UI_SELECT_GUIDE_DESC"))

        self.pageText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.pageText:SetPoint("BOTTOM", f, "BOTTOMLEFT", 313, 24)
        self.pageText:SetJustifyH("CENTER")
        self.pageText:SetText("1/1")
    end

    -- Top-right Close [X] button
    self.closeButton = createMenuButton(f, "AzerothRouteGuideMenuClose", "X", 26, 24, true)
    self.closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -6)
    self.closeButton:SetScript("OnClick", function()
        f:Hide()
    end)

    -- Left Sidebar Category Buttons
    self.categoryButtons = {}
    for idx, cat in ipairs(self.CATEGORIES) do
        local cBtn = createMenuButton(f, "AzerothRouteCatBtn" .. idx, LGet(cat.labelKey), 128, 28, false)
        cBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -52 - (idx - 1) * 32)
        cBtn._categoryID = cat.id
        cBtn._labelKey = cat.labelKey
        cBtn:SetScript("OnClick", function()
            self:SelectCategory(cat.id)
        end)
        table.insert(self.categoryButtons, cBtn)
    end

    -- Center Column Clickable Guide List Rows (14 per page)
    self.guideRowButtons = {}
    for r = 1, self.MAX_ROWS do
        local rowBtn = createMenuButton(f, "AzerothRouteGuideRow" .. r, "", 298, 24, false)
        rowBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 164, -50 - (r - 1) * 26)
        rowBtn:SetScript("OnClick", function(btn)
            if btn._guide then
                self:SelectGuide(btn._guide)
            end
        end)
        rowBtn:Hide()
        table.insert(self.guideRowButtons, rowBtn)
    end

    -- Pagination Controls at bottom of Center Column
    self.prevPageButton = createMenuButton(f, "AzerothRouteGuidePrevPage", LGet("UI_PREV_PAGE"), 88, 22, true)
    self.prevPageButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 164, 18)
    self.prevPageButton:SetScript("OnClick", function()
        self:PrevPage()
    end)

    self.nextPageButton = createMenuButton(f, "AzerothRouteGuideNextPage", LGet("UI_NEXT_PAGE"), 88, 22, true)
    self.nextPageButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 374, 18)
    self.nextPageButton:SetScript("OnClick", function()
        self:NextPage()
    end)

    -- Right Column "Talents" Advisor Button
    self.talentButton = createMenuButton(f, "AzerothRouteMenuTalentsButton", LGet("UI_TALENTS"), 210, 28, true)
    self.talentButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 488, 62)
    if self.talentButton.bg then
        self.talentButton.bg:SetColorTexture(0.24, 0.34, 0.56, 1.0)
    end
    self.talentButton:SetScript("OnClick", function()
        if AR.TalentAdvisor and AR.TalentAdvisor.ToggleUI then
            AR.TalentAdvisor:ToggleUI()
        end
    end)

    -- Right Column "Load Selected Guide" Action Button
    self.loadButton = createMenuButton(f, "AzerothRouteLoadGuideButton", LGet("UI_LOAD_GUIDE"), 210, 32, true)
    self.loadButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 488, 22)
    if self.loadButton.bg then
        self.loadButton.bg:SetColorTexture(0.14, 0.52, 0.28, 1.0)
    end
    self.loadButton:SetScript("OnClick", function()
        if self.selectedGuide and AR.Progression then
            AR.Progression:LoadGuide(self.selectedGuide, 1)
            if AR.Tabs then
                AR.Tabs:AddTab(self.selectedGuide.title)
            end
            if AR.ViewerFrame then
                if AR.ViewerFrame.frame then AR.ViewerFrame.frame:Show() end
                AR.ViewerFrame:RefreshVisuals()
            end
            f:Hide()
        end
    end)

    f:Hide()
    self.frame = f
    self:SelectCategory(self.activeCategory)
    return f
end

local CATEGORY_ORDER = {
    LEVELING = 1,
    DUNGEONS = 2,
    PROFESSIONS = 3,
    GOLD = 4,
}

function GuideMenu:GetGuidesForCategory(categoryID)
    if categoryID == "SUGGESTED" then
        local sug = self:FindSuggestedGuides()
        if #sug > 0 then return sug end
    end

    local list = {}
    for _, guide in pairs((AR.Parser and AR.Parser.guidesByTitle) or {}) do
        if categoryID == "ALL" or categoryID == "SUGGESTED" or (guide.type and guide.type:upper() == categoryID) then
            table.insert(list, guide)
        end
    end
    table.sort(list, function(a, b)
        local pa = CATEGORY_ORDER[a.type and a.type:upper() or ""] or 9
        local pb = CATEGORY_ORDER[b.type and b.type:upper() or ""] or 9
        if pa ~= pb then
            return pa < pb
        end
        local la = a.startlevel or 99
        local lb = b.startlevel or 99
        if la ~= lb then
            return la < lb
        end
        return (a.title or "") < (b.title or "")
    end)
    return list
end

function GuideMenu:SelectGuide(guide)
    self.selectedGuide = guide
    if not guide then return end

    if self.detailTitle then
        self.detailTitle:SetText(getDisplayTitle(guide))
    end
    if self.detailMeta then
        local stepCount = guide.steps and #guide.steps or 0
        local typeLabel = guide.type or "LEVELING"
        if AR.L then
            local keyMap = {
                LEVELING = "UI_LEVELING",
                DUNGEONS = "UI_DUNGEONS",
                PROFESSIONS = "UI_PROFESSIONS",
                GOLD = "UI_GOLD",
            }
            if keyMap[typeLabel:upper()] then
                typeLabel = AR.L:Get(keyMap[typeLabel:upper()])
            end
        end
        self.detailMeta:SetText(LFormat("UI_GUIDE_META_FMT", typeLabel, guide.startlevel or 1, guide.endlevel or 60, stepCount))
    end
    if self.detailDesc then
        local desc = (AR.L and AR.L:IsSpanish() and guide.descriptionES) or guide.description or LGet("UI_SELECT_GUIDE_DESC")
        self.detailDesc:SetText(desc)
    end

    for _, rowBtn in ipairs(self.guideRowButtons) do
        if rowBtn.bg then
            if rowBtn._guide == guide then
                rowBtn.bg:SetColorTexture(0.22, 0.42, 0.68, 0.98)
            else
                rowBtn.bg:SetColorTexture(0.13, 0.15, 0.22, 0.90)
            end
        end
    end
end

function GuideMenu:RenderGuidePage()
    if self.headerText then self.headerText:SetText(LGet("UI_GUIDE_MENU_TITLE")) end
    if self.loadButton and self.loadButton.label then self.loadButton.label:SetText(LGet("UI_LOAD_GUIDE")) end
    if self.talentButton and self.talentButton.label then self.talentButton.label:SetText(LGet("UI_TALENTS")) end
    if self.prevPageButton and self.prevPageButton.label then self.prevPageButton.label:SetText(LGet("UI_PREV_PAGE")) end
    if self.nextPageButton and self.nextPageButton.label then self.nextPageButton.label:SetText(LGet("UI_NEXT_PAGE")) end

    for _, cBtn in ipairs(self.categoryButtons) do
        if cBtn.label and cBtn._labelKey then
            cBtn.label:SetText(LGet(cBtn._labelKey))
        end
        if cBtn.bg then
            if cBtn._categoryID == self.activeCategory then
                cBtn.bg:SetColorTexture(0.24, 0.44, 0.72, 1.0)
            else
                cBtn.bg:SetColorTexture(0.14, 0.17, 0.24, 0.95)
            end
        end
    end

    local guides = self:GetGuidesForCategory(self.activeCategory)
    local total = #guides
    local maxOff = math.max(0, math.floor((total - 1) / self.MAX_ROWS) * self.MAX_ROWS)
    self.pageOffset = math.max(0, math.min(maxOff, self.pageOffset or 0))

    for i = 1, self.MAX_ROWS do
        local rowBtn = self.guideRowButtons[i]
        local g = guides[self.pageOffset + i]
        if rowBtn then
            if g then
                rowBtn._guide = g
                if rowBtn.label then
                    rowBtn.label:SetText(getDisplayTitle(g))
                end
                rowBtn:Show()
            else
                rowBtn._guide = nil
                rowBtn:Hide()
            end
        end
    end

    local totalPages = math.max(1, math.ceil(total / self.MAX_ROWS))
    local curPage = math.floor(self.pageOffset / self.MAX_ROWS) + 1
    if self.pageText then
        self.pageText:SetText(LFormat("UI_PAGE_FMT", curPage, totalPages))
    end

    local firstVisible = guides[self.pageOffset + 1]
    if firstVisible then
        self:SelectGuide(firstVisible)
    end
end

function GuideMenu:SelectCategory(categoryID)
    self.activeCategory = categoryID or "ALL"
    self.pageOffset = 0
    self:RenderGuidePage()
end

function GuideMenu:NextPage()
    local guides = self:GetGuidesForCategory(self.activeCategory)
    if (self.pageOffset + self.MAX_ROWS) < #guides then
        self.pageOffset = self.pageOffset + self.MAX_ROWS
        self:RenderGuidePage()
    end
end

function GuideMenu:PrevPage()
    if (self.pageOffset or 0) > 0 then
        self.pageOffset = math.max(0, self.pageOffset - self.MAX_ROWS)
        self:RenderGuidePage()
    end
end

function GuideMenu:Show()
    local f = self:InitializeFrame()
    self:SelectCategory(self.activeCategory)
    f:Show()
end

function GuideMenu:Toggle()
    local f = self:InitializeFrame()
    if f:IsShown() then
        f:Hide()
    else
        self:Show()
    end
end

function GuideMenu:FindSuggestedGuides()
    local suggested = {}
    for _, guide in pairs((AR.Parser and AR.Parser.guidesByTitle) or {}) do
        if guide.condition_suggested then
            local ok, res = pcall(guide.condition_suggested)
            if ok and res == true then
                table.insert(suggested, guide)
            end
        end
    end
    table.sort(suggested, function(a, b)
        return (a.startlevel or 0) < (b.startlevel or 0)
    end)
    return suggested
end

function GuideMenu:Search(query)
    if not query or query == "" then return {} end
    local results = {}
    local questIdStr = query:match("^quest:(%d+)$")
    local targetQuestID = questIdStr and tonumber(questIdStr) or nil
    local lowerQuery = query:lower()

    for _, guide in pairs((AR.Parser and AR.Parser.guidesByTitle) or {}) do
        local matched = false
        if targetQuestID then
            for _, step in ipairs(guide.steps or {}) do
                for _, goal in ipairs(step.goals or {}) do
                    if goal.questid == targetQuestID then
                        matched = true
                        break
                    end
                end
                if matched then break end
            end
        elseif guide.title and guide.title:lower():find(lowerQuery, 1, true) then
            matched = true
        end

        if matched then
            table.insert(results, guide)
        end
    end

    table.sort(results, function(a, b)
        return (a.title or "") < (b.title or "")
    end)
    return results
end

return GuideMenu
