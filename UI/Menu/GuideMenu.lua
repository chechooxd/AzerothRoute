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

-- Paints a list/sidebar button as selected (raised plate, gold bar, bright text) or idle (flat, muted).
local function paintSelectable(btn, selected)
    local S = AR.Skins
    btn._selected = selected == true
    if btn.bg then
        if selected then S:Paint(btn.bg, "selected") else btn.bg:SetColorTexture(0, 0, 0, 0) end
    end
    if btn.accent then
        if selected then btn.accent:Show() else btn.accent:Hide() end
    end
    if btn.label and btn.label.SetTextColor then
        btn.label:SetTextColor(S:RGBA(selected and "text" or "textMuted"))
    end
end

-- Flat button. `style`: "list" (left-aligned, hover plate, gold selection bar),
-- "primary" (gold plate, dark text) or "ghost" (bordered, centred).
local function createMenuButton(parent, name, labelText, width, height, centered, style)
    local S = AR.Skins
    style = style or (centered and "ghost" or "list")
    local btn = AR.UI:Create("Button", parent, name)
    btn:SetSize(width, height)
    btn._style = style
    if btn.CreateTexture then
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints(btn)
        if style == "primary" then
            S:Paint(btn.bg, "accent", 1)
        elseif style == "ghost" then
            S:Paint(btn.bg, "panelRaised")
            S:AddBorder(btn, "border")
        else
            btn.bg:SetColorTexture(0, 0, 0, 0)
            btn.accent = btn:CreateTexture(nil, "ARTWORK")
            btn.accent:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
            btn.accent:SetSize(2, height)
            S:Paint(btn.accent, "accent")
            btn.accent:Hide()
        end
    end
    if btn.CreateFontString then
        btn.label = btn:CreateFontString(nil, "OVERLAY", style == "list" and "GameFontHighlight" or "GameFontNormal")
        if centered then
            btn.label:SetPoint("CENTER", btn, "CENTER", 0, 0)
            btn.label:SetJustifyH("CENTER")
        else
            btn.label:SetPoint("LEFT", btn, "LEFT", 12, 0)
            btn.label:SetJustifyH("LEFT")
        end
        btn.label:SetText(labelText)
        if btn.label.SetTextColor then
            if style == "primary" then
                btn.label:SetTextColor(0.10, 0.09, 0.07, 1)
            else
                btn.label:SetTextColor(S:RGBA(style == "ghost" and "text" or "textMuted"))
            end
        end
    end
    btn:SetScript("OnEnter", function(b)
        if b._style == "list" and not b._selected then S:Paint(b.bg, "hover") end
        if b._style == "ghost" then S:Paint(b.bg, "hover", 1) end
        if b._style == "primary" and b.bg then b.bg:SetColorTexture(1.0, 0.85, 0.42, 1) end
    end)
    btn:SetScript("OnLeave", function(b)
        if b._style == "list" and not b._selected and b.bg then b.bg:SetColorTexture(0, 0, 0, 0) end
        if b._style == "ghost" then S:Paint(b.bg, "panelRaised") end
        if b._style == "primary" then S:Paint(b.bg, "accent", 1) end
    end)
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

    local S = AR.Skins
    if f.CreateTexture then
        f.bg = f:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAllPoints(f)
        S:Paint(f.bg, "panel", 0.98)
        S:AddBorder(f, "border")

        -- Sidebar (categories) on the raised panel colour, full height.
        f.leftPaneBg = f:CreateTexture(nil, "BACKGROUND")
        f.leftPaneBg:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        f.leftPaneBg:SetSize(152, self.HEIGHT - 2)
        S:Paint(f.leftPaneBg, "panelRaised")

        -- Header band over the list and details.
        f.headerBar = f:CreateTexture(nil, "ARTWORK")
        f.headerBar:SetPoint("TOPLEFT", f, "TOPLEFT", 153, -1)
        f.headerBar:SetSize(self.WIDTH - 154, 44)
        S:Paint(f.headerBar, "panel", 1)
        f.headerRule = f:CreateTexture(nil, "ARTWORK")
        f.headerRule:SetPoint("TOPLEFT", f, "TOPLEFT", 153, -45)
        f.headerRule:SetSize(self.WIDTH - 154, 1)
        S:Paint(f.headerRule, "divider")

        -- Center guide list sits on the panel; a rule separates the details pane.
        f.centerPaneBg = f:CreateTexture(nil, "ARTWORK")
        f.centerPaneBg:SetPoint("TOPLEFT", f, "TOPLEFT", 468, -46)
        f.centerPaneBg:SetSize(1, self.HEIGHT - 47)
        S:Paint(f.centerPaneBg, "divider")

        -- Right details pane background
        f.rightPaneBg = f:CreateTexture(nil, "BACKGROUND")
        f.rightPaneBg:SetPoint("TOPLEFT", f, "TOPLEFT", 469, -46)
        f.rightPaneBg:SetSize(self.WIDTH - 470, self.HEIGHT - 47)
        S:Paint(f.rightPaneBg, "panelRaised", 0.6)

        -- Sidebar brand underline.
        f.brandRule = f:CreateTexture(nil, "ARTWORK")
        f.brandRule:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -45)
        f.brandRule:SetSize(126, 1)
        S:Paint(f.brandRule, "accent", 0.6)
    end

    if f.CreateFontString then
        -- Sidebar brand: gold star mark, addon name, tagline.
        if f.CreateTexture then
            -- Gold diamond mark (a rotated square; no font glyph dependency).
            self.brandMark = f:CreateTexture(nil, "OVERLAY")
            self.brandMark:SetPoint("TOPLEFT", f, "TOPLEFT", 17, -16)
            self.brandMark:SetSize(10, 10)
            S:Paint(self.brandMark, "accent", 1)
            if self.brandMark.SetRotation then self.brandMark:SetRotation(math.pi / 4) end
        end
        self.brandName = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        self.brandName:SetPoint("TOPLEFT", f, "TOPLEFT", 34, -10)
        self.brandName:SetText("|cffffffffAzeroth|r|cfff4c54aRoute|r")
        self.brandTag = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.brandTag:SetPoint("TOPLEFT", f, "TOPLEFT", 34, -26)
        if self.brandTag.SetTextColor then self.brandTag:SetTextColor(S:RGBA("textMuted")) end
        self.brandTag:SetText(LGet("UI_GUIDES"))

        self.headerText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        self.headerText:SetPoint("TOPLEFT", f, "TOPLEFT", 170, -10)
        if self.headerText.SetTextColor then self.headerText:SetTextColor(S:RGBA("text")) end
        self.headerText:SetText(LGet("UI_GUIDE_MENU_TITLE"))

        self.headerSub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.headerSub:SetPoint("TOPLEFT", f, "TOPLEFT", 170, -28)
        if self.headerSub.SetTextColor then self.headerSub:SetTextColor(S:RGBA("textMuted")) end
        self.headerSub:SetText("")

        self.detailTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        if self.detailTitle.SetTextColor then self.detailTitle:SetTextColor(S:RGBA("text")) end
        self.detailTitle:SetPoint("TOPLEFT", f, "TOPLEFT", 488, -60)
        if self.detailTitle.SetWidth then self.detailTitle:SetWidth(210) end
        self.detailTitle:SetJustifyH("LEFT")
        self.detailTitle:SetText(LGet("UI_SELECT_GUIDE"))

        self.detailMeta = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.detailMeta:SetPoint("TOPLEFT", f, "TOPLEFT", 488, -90)
        if self.detailMeta.SetWidth then self.detailMeta:SetWidth(210) end
        self.detailMeta:SetJustifyH("LEFT")
        if self.detailMeta.SetTextColor then self.detailMeta:SetTextColor(S:RGBA("textMuted")) end
        self.detailMeta:SetText("")

        self.detailDesc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.detailDesc:SetPoint("TOPLEFT", f, "TOPLEFT", 488, -120)
        if self.detailDesc.SetWidth then self.detailDesc:SetWidth(210) end
        self.detailDesc:SetJustifyH("LEFT")
        if self.detailDesc.SetTextColor then self.detailDesc:SetTextColor(S:RGBA("text")) end
        self.detailDesc:SetText(LGet("UI_SELECT_GUIDE_DESC"))

        self.pageText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.pageText:SetPoint("BOTTOM", f, "BOTTOMLEFT", 313, 24)
        self.pageText:SetJustifyH("CENTER")
        if self.pageText.SetTextColor then self.pageText:SetTextColor(S:RGBA("textMuted")) end
        self.pageText:SetText("1/1")
    end

    -- Top-right Close [X] button
    self.closeButton = createMenuButton(f, "AzerothRouteGuideMenuClose", "x", 22, 22, true)
    self.closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
    self.closeButton:SetScript("OnClick", function()
        f:Hide()
    end)

    -- Left Sidebar Category Buttons
    self.categoryButtons = {}
    for idx, cat in ipairs(self.CATEGORIES) do
        local cBtn = createMenuButton(f, "AzerothRouteCatBtn" .. idx, LGet(cat.labelKey), 151, 28, false)
        cBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -58 - (idx - 1) * 30)
        if cBtn.CreateFontString then
            cBtn.count = cBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            cBtn.count:SetPoint("RIGHT", cBtn, "RIGHT", -12, 0)
            cBtn.count:SetJustifyH("RIGHT")
            if cBtn.count.SetTextColor then cBtn.count:SetTextColor(S:RGBA("textMuted")) end
        end
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
        local rowBtn = createMenuButton(f, "AzerothRouteGuideRow" .. r, "", 310, 24, false)
        rowBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 156, -52 - (r - 1) * 26)
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
    self.talentButton:SetScript("OnClick", function()
        if AR.TalentAdvisor and AR.TalentAdvisor.ToggleUI then
            AR.TalentAdvisor:ToggleUI()
        end
    end)

    -- Right Column "Load Selected Guide" Action Button
    self.loadButton = createMenuButton(f, "AzerothRouteLoadGuideButton", LGet("UI_LOAD_GUIDE"), 210, 32, true, "primary")
    self.loadButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 488, 22)
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
        paintSelectable(rowBtn, rowBtn._guide ~= nil and rowBtn._guide == guide)
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
        paintSelectable(cBtn, cBtn._categoryID == self.activeCategory)
        if cBtn.count then
            cBtn.count:SetText(tostring(#self:GetGuidesForCategory(cBtn._categoryID)))
        end
    end

    local guides = self:GetGuidesForCategory(self.activeCategory)
    local total = #guides
    if self.headerSub then
        self.headerSub:SetText(LFormat("UI_GUIDE_COUNT_FMT", total))
    end
    if self.brandTag then self.brandTag:SetText(LGet("UI_GUIDES")) end
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
