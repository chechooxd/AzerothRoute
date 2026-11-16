-- AzerothRoute: Interactive 825x630 GuideMenu Command Center, Category Tabs, Guide List & Details Pane (SPEC-13 / SPEC-17 / SPEC-20)

local AR = _G.AzerothRoute
local GuideMenu = {
    WIDTH = 720,
    HEIGHT = 480,
    MAX_ROWS = 14,
    CATEGORIES = {
        { id = "SUGGESTED", label = "Suggested" },
        { id = "LEVELING",  label = "Leveling" },
        { id = "DUNGEONS",  label = "Dungeons" },
        { id = "PROFESSIONS", label = "Professions" },
        { id = "GOLD",      label = "Gold" },
        { id = "ALL",       label = "All Guides" },
    },
    activeCategory = "ALL",
    selectedGuide = nil,
    frame = nil,
    closeButton = nil,
    loadButton = nil,
    categoryButtons = {},
    guideRowButtons = {},
    detailTitle = nil,
    detailDesc = nil,
    detailMeta = nil,
}
AR.GuideMenu = GuideMenu

function GuideMenu:Reset()
    self.activeCategory = "ALL"
    self.selectedGuide = nil
    self.frame = nil
    self.closeButton = nil
    self.loadButton = nil
    self.categoryButtons = {}
    self.guideRowButtons = {}
end

local function createMenuButton(parent, name, labelText, width, height)
    local btn = AR.UI:Create("Button", parent, name)
    btn:SetSize(width, height)
    if btn.CreateTexture then
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints(btn)
        btn.bg:SetColorTexture(0.14, 0.17, 0.24, 0.95)
    end
    if btn.CreateFontString then
        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.label:SetPoint("LEFT", btn, "LEFT", 10, 0)
        btn.label:SetJustifyH("LEFT")
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
        f.header = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        f.header:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -10)
        f.header:SetText("AzerothRoute — Guide Center")

        self.detailTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        self.detailTitle:SetPoint("TOPLEFT", f, "TOPLEFT", 488, -56)
        if self.detailTitle.SetWidth then self.detailTitle:SetWidth(210) end
        self.detailTitle:SetJustifyH("LEFT")
        self.detailTitle:SetText("Select a Guide")

        self.detailMeta = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.detailMeta:SetPoint("TOPLEFT", f, "TOPLEFT", 488, -90)
        if self.detailMeta.SetWidth then self.detailMeta:SetWidth(210) end
        self.detailMeta:SetJustifyH("LEFT")
        self.detailMeta:SetText("")

        self.detailDesc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.detailDesc:SetPoint("TOPLEFT", f, "TOPLEFT", 488, -120)
        if self.detailDesc.SetWidth then self.detailDesc:SetWidth(210) end
        self.detailDesc:SetJustifyH("LEFT")
        self.detailDesc:SetText("Click any guide on the left to inspect its steps and load it into the viewer.")
    end

    -- Top-right Close [X] button
    self.closeButton = createMenuButton(f, "AzerothRouteGuideMenuClose", "X", 26, 24)
    self.closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -6)
    self.closeButton:SetScript("OnClick", function()
        f:Hide()
    end)

    -- Left Sidebar Category Buttons
    self.categoryButtons = {}
    for idx, cat in ipairs(self.CATEGORIES) do
        local cBtn = createMenuButton(f, "AzerothRouteCatBtn" .. idx, cat.label, 128, 28)
        cBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -52 - (idx - 1) * 32)
        cBtn._categoryID = cat.id
        cBtn:SetScript("OnClick", function()
            self:SelectCategory(cat.id)
        end)
        table.insert(self.categoryButtons, cBtn)
    end

    -- Center Column Clickable Guide List Rows
    self.guideRowButtons = {}
    for r = 1, self.MAX_ROWS do
        local rowBtn = createMenuButton(f, "AzerothRouteGuideRow" .. r, "", 298, 26)
        rowBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 164, -52 - (r - 1) * 28)
        rowBtn:SetScript("OnClick", function(btn)
            if btn._guide then
                self:SelectGuide(btn._guide)
            end
        end)
        rowBtn:Hide()
        table.insert(self.guideRowButtons, rowBtn)
    end

    -- Right Column "Load Guide" Action Button
    self.loadButton = createMenuButton(f, "AzerothRouteLoadGuideButton", "Load Selected Guide", 210, 32)
    self.loadButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 488, 24)
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
        return (a.title or "") < (b.title or "")
    end)
    return list
end

function GuideMenu:SelectGuide(guide)
    self.selectedGuide = guide
    if not guide then return end

    if self.detailTitle then
        self.detailTitle:SetText(guide.title or "Guide")
    end
    if self.detailMeta then
        local stepCount = guide.steps and #guide.steps or 0
        self.detailMeta:SetText(string.format("Type: %s | Levels: %d-%d | Steps: %d", guide.type or "LEVELING", guide.startlevel or 1, guide.endlevel or 60, stepCount))
    end
    if self.detailDesc then
        self.detailDesc:SetText(guide.description or "Step-by-step route with automatic waypoint & quest tracking.")
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

function GuideMenu:SelectCategory(categoryID)
    self.activeCategory = categoryID or "ALL"
    for _, cBtn in ipairs(self.categoryButtons) do
        if cBtn.bg then
            if cBtn._categoryID == self.activeCategory then
                cBtn.bg:SetColorTexture(0.24, 0.44, 0.72, 1.0)
            else
                cBtn.bg:SetColorTexture(0.14, 0.17, 0.24, 0.95)
            end
        end
    end

    local guides = self:GetGuidesForCategory(self.activeCategory)
    for i = 1, self.MAX_ROWS do
        local rowBtn = self.guideRowButtons[i]
        local g = guides[i]
        if rowBtn then
            if g then
                rowBtn._guide = g
                if rowBtn.label then
                    rowBtn.label:SetText(g.title or "Guide")
                end
                rowBtn:Show()
            else
                rowBtn._guide = nil
                rowBtn:Hide()
            end
        end
    end

    if guides[1] then
        self:SelectGuide(guides[1])
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
