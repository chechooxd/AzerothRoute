-- AzerothRoute: Interactive GuideMenu Command Center with Localization, Pagination & Talent Advisor Link (SPEC-13 / SPEC-17 / SPEC-20 / SPEC-21)

local AR = _G.AzerothRoute
local GuideMenu = {
    WIDTH = 720,
    HEIGHT = 480,
    MAX_ROWS = 14,
    MODES = {
        { id = "guides", labelKey = "UI_GUIDES" },
        { id = "lookup", labelKey = "UI_LOOKUP" },
        { id = "dungeons", labelKey = "UI_DUNGEONS" },
        { id = "rares", labelKey = "UI_LK_RARES" },
        { id = "characters", labelKey = "UI_CHARACTERS" },
        { id = "options", labelKey = "UI_MENU_OPTIONS" },
    },
    mode = "guides",
    CATEGORIES = {
        { id = "HOME",      labelKey = "UI_HOME" },
        { id = "SUGGESTED", labelKey = "UI_SUGGESTED" },
        { id = "LEVELING",  labelKey = "UI_LEVELING" },
        { id = "DUNGEONS",  labelKey = "UI_DUNGEONS" },
        { id = "PROFESSIONS", labelKey = "UI_PROFESSIONS" },
        { id = "GOLD",      labelKey = "UI_GOLD" },
        { id = "ALL",       labelKey = "UI_ALL_GUIDES" },
    },
    activeCategory = "HOME",
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
    self.activeCategory = "HOME"
    self.pageOffset = 0
    self.selectedGuide = nil
    self.searchQuery = ""
    self.searchBox = nil
    self.mode = "guides"
    self.modeQueries = {}
    self.modeButtons = {}
    if AR.Lookup and AR.Lookup.Reset then AR.Lookup:Reset() end
    if AR.Dungeons and AR.Dungeons.Reset then AR.Dungeons:Reset() end
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

        -- Kept for callers that read the one-line summary; the chips and stats below replace it on screen.
        self.detailMeta = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.detailMeta:SetPoint("TOPLEFT", f, "TOPLEFT", 488, -90)
        self.detailMeta:SetText("")
        self.detailMeta:Hide()

        -- Chips row: level range, "your level", guide type.
        self.chips = {}
        for c = 1, 3 do
            local chip = AR.UI:Create("Frame", f, "AzerothRouteGuideChip" .. c)
            chip:SetSize(60, 18)
            if chip.CreateTexture then
                chip.bg = chip:CreateTexture(nil, "BACKGROUND")
                chip.bg:SetAllPoints(chip)
            end
            chip.label = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            chip.label:SetPoint("CENTER", chip, "CENTER", 0, 0)
            chip:Hide()
            self.chips[c] = chip
        end

        -- Status ("Not started" / "Step x of y") with its progress bar.
        self.detailStatus = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.detailStatus:SetPoint("TOPLEFT", f, "TOPLEFT", 488, -116)
        self.detailStatus:SetJustifyH("LEFT")
        if self.detailStatus.SetTextColor then self.detailStatus:SetTextColor(S:RGBA("textMuted")) end
        self.detailStatus:SetText("")
        if f.CreateTexture then
            self.detailTrack = f:CreateTexture(nil, "ARTWORK")
            self.detailTrack:SetPoint("TOPLEFT", f, "TOPLEFT", 488, -134)
            self.detailTrack:SetSize(210, 3)
            S:Paint(self.detailTrack, "track")
            self.detailFill = f:CreateTexture(nil, "OVERLAY")
            self.detailFill:SetPoint("TOPLEFT", f, "TOPLEFT", 488, -134)
            self.detailFill:SetSize(1, 3)
            S:Paint(self.detailFill, "accent")
            self.detailFill:Hide()
        end

        -- Stats: Steps, Quests, Next.
        self.statRows = {}
        for r, key in ipairs({ "UI_STAT_STEPS", "UI_STAT_QUESTS", "UI_STAT_NEXT" }) do
            local y = -150 - (r - 1) * 18
            local k = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            k:SetPoint("TOPLEFT", f, "TOPLEFT", 488, y)
            if k.SetTextColor then k:SetTextColor(S:RGBA("textMuted")) end
            k:SetText(LGet(key))
            local v = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            v:SetPoint("TOPLEFT", f, "TOPLEFT", 560, y)
            if v.SetWidth then v:SetWidth(140) end
            if v.SetWordWrap then v:SetWordWrap(false) end
            v:SetJustifyH("LEFT")
            if v.SetTextColor then v:SetTextColor(S:RGBA("text")) end
            self.statRows[r] = { key = k, value = v, labelKey = key }
        end

        self.detailDesc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.detailDesc:SetPoint("TOPLEFT", f, "TOPLEFT", 488, -212)
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

    -- Mode tabs: Guides | Lookup | Dungeons.
    self.modeButtons = {}
    for idx, mode in ipairs(self.MODES) do
        local b = createMenuButton(f, "AzerothRouteModeBtn" .. idx, LGet(mode.labelKey), 50, 24, true, "list")
        -- Two rows of three tabs.
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 1 + ((idx - 1) % 3) * 50, -50 - math.floor((idx - 1) / 3) * 25)
        b._mode = mode.id
        b._labelKey = mode.labelKey
        b:SetScript("OnClick", function() self:SetMode(mode.id) end)
        self.modeButtons[idx] = b
    end

    -- Sidebar search box: filters the list by guide name (or quest:<id>) as you type;
    -- in Lookup and Dungeons it feeds their search instead.
    local box = _G.CreateFrame("EditBox", "AzerothRouteGuideSearch", f)
    box:SetSize(128, 22)
    box:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -103)
    if box.SetAutoFocus then box:SetAutoFocus(false) end
    if box.SetFontObject then box:SetFontObject("GameFontHighlightSmall") end
    if box.SetTextInsets then box:SetTextInsets(8, 8, 0, 0) end
    if box.CreateTexture then
        box.bg = box:CreateTexture(nil, "BACKGROUND")
        box.bg:SetAllPoints(box)
        S:Paint(box.bg, "panel", 1)
        S:AddBorder(box, "border")
    end
    if box.CreateFontString then
        box.placeholder = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        box.placeholder:SetPoint("LEFT", box, "LEFT", 8, 0)
        if box.placeholder.SetTextColor then box.placeholder:SetTextColor(S:RGBA("textDone")) end
        box.placeholder:SetText(LGet("UI_SEARCH"))
    end
    box:SetScript("OnTextChanged", function(b)
        local q = (b.GetText and b:GetText()) or ""
        if b.placeholder then
            if q == "" then b.placeholder:Show() else b.placeholder:Hide() end
        end
        self:SetSearch(q)
    end)
    box:SetScript("OnEscapePressed", function(b)
        if b.SetText then b:SetText("") end
        if b.ClearFocus then b:ClearFocus() end
        self:SetSearch("")
    end)
    self.searchBox = box

    -- Left Sidebar Category Buttons
    self.categoryButtons = {}
    for idx, cat in ipairs(self.CATEGORIES) do
        local cBtn = createMenuButton(f, "AzerothRouteCatBtn" .. idx, LGet(cat.labelKey), 151, 28, false)
        cBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -132 - (idx - 1) * 30)
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
        if rowBtn.CreateFontString then
            -- Right-hand tag: progress "x/y" on the loaded guide, "Your level" on matching guides.
            rowBtn.tag = rowBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            rowBtn.tag:SetPoint("RIGHT", rowBtn, "RIGHT", -10, 0)
            rowBtn.tag:SetJustifyH("RIGHT")
            rowBtn.tag:SetText("")
        end
        if rowBtn.label and rowBtn.label.SetWidth then rowBtn.label:SetWidth(220) end
        if rowBtn.label and rowBtn.label.SetWordWrap then rowBtn.label:SetWordWrap(false) end
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
        if self.selectedGuide and AR.Progression and AR.Progression.currentGuide == self.selectedGuide then
            -- Continue: the guide is already running; just bring its window back.
            if AR.ViewerFrame then
                if AR.ViewerFrame.frame then AR.ViewerFrame.frame:Show() end
                AR.ViewerFrame:RefreshVisuals()
            end
            f:Hide()
            return
        end
        if self.selectedGuide and AR.Progression then
            -- Reopening a guide that is already a tab resumes at its step.
            if AR.ViewerFrame and AR.ViewerFrame.RememberCurrentTab then AR.ViewerFrame:RememberCurrentTab() end
            local steps = AR.db and AR.db.char and AR.db.char.tabsteps
            AR.Progression:LoadGuide(self.selectedGuide, (steps and steps[self.selectedGuide.title]) or 1)
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

    -- Sidebar "+ Import" (opens the import window) and, for imported guides, "Delete".
    self.importButton = createMenuButton(f, "AzerothRouteGuideImport", "+ " .. LGet("UI_IMPORT_DO"), 151, 28, false)
    self.importButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 10)
    self.importButton:SetScript("OnClick", function()
        if AR.ImportWindow then AR.ImportWindow:Show() end
    end)
    self.deleteButton = createMenuButton(f, "AzerothRouteGuideDelete", LGet("UI_IMPORT_DELETE"), 210, 24, true)
    self.deleteButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 488, 98)
    if self.deleteButton.label and self.deleteButton.label.SetTextColor then
        self.deleteButton.label:SetTextColor(0.94, 0.45, 0.42, 1)
    end
    self.deleteButton:SetScript("OnClick", function()
        local g = self.selectedGuide
        if g and AR.GuideImport and AR.GuideImport:Delete(g) then
            self.selectedGuide = nil
            self:RenderGuidePage()
        end
    end)
    self.deleteButton:Hide()

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

-- Home: the guide in progress, the other open tabs, then the suggestions for this character.
function GuideMenu:GetHomeGuides()
    local out, seen = {}, {}
    local function add(g) if g and not seen[g] then seen[g] = true; out[#out + 1] = g end end
    local P = AR.Progression
    add(P and P.currentGuide)
    for _, title in ipairs((AR.Tabs and AR.Tabs:GetTabs()) or {}) do
        add(AR.Parser and AR.Parser.guidesByTitle and AR.Parser.guidesByTitle[title])
    end
    for _, g in ipairs(self:FindSuggestedGuides()) do add(g) end
    return out
end

-- True when `guide` is open (current guide or a tab): loading it means continuing it.
function GuideMenu:IsOpen(guide)
    if not guide then return false end
    local P = AR.Progression
    if P and P.currentGuide == guide then return true end
    for _, title in ipairs((AR.Tabs and AR.Tabs:GetTabs()) or {}) do
        if title == guide.title then return true end
    end
    return false
end

function GuideMenu:GetGuidesForCategory(categoryID)
    if categoryID == "HOME" then
        local home = self:GetHomeGuides()
        if #home > 0 then return home end
        categoryID = "ALL"
    end
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
    self:RenderDetails(guide)
    if self.deleteButton then
        if AR.GuideImport and AR.GuideImport:IsImported(guide) then self.deleteButton:Show() else self.deleteButton:Hide() end
    end
    if self.loadButton and self.loadButton.label then
        self.loadButton.label:SetText(self:IsOpen(guide) and LGet("UI_CONTINUE") or LGet("UI_LOAD_GUIDE"))
    end

    for _, rowBtn in ipairs(self.guideRowButtons) do
        paintSelectable(rowBtn, rowBtn._guide ~= nil and rowBtn._guide == guide)
    end
end

local function playerLevel()
    return (_G.UnitLevel and _G.UnitLevel("player")) or 1
end

local function inLevelRange(guide)
    local lvl = playerLevel()
    return guide.startlevel ~= nil and lvl >= guide.startlevel and lvl <= (guide.endlevel or guide.startlevel)
end

-- Details model for a guide: chips, status line, progress fraction and stats.
function GuideMenu:BuildDetails(guide)
    local chips = {}
    if guide.startlevel then
        table.insert(chips, { text = LFormat("UI_LEVELS_FMT", guide.startlevel, guide.endlevel or guide.startlevel), accent = true })
    end
    if inLevelRange(guide) then
        table.insert(chips, { text = LGet("UI_YOUR_LEVEL"), accent = true })
    end
    local typeKey = guide.type and ({ LEVELING = "UI_LEVELING", DUNGEONS = "UI_DUNGEONS", PROFESSIONS = "UI_PROFESSIONS", GOLD = "UI_GOLD" })[guide.type:upper()]
    if typeKey then table.insert(chips, { text = LGet(typeKey) }) end

    local steps = guide.steps and #guide.steps or 0
    local quests, seen = 0, {}
    for _, st in ipairs(guide.steps or {}) do
        for _, g in ipairs(st.goals or {}) do
            if g.action == "accept" and g.questid and not seen[g.questid] then
                seen[g.questid] = true
                quests = quests + 1
            end
        end
    end

    local P = AR.Progression
    local status, frac = LGet("UI_STATUS_NOT_STARTED"), 0
    if P and P.currentGuide == guide then
        local n = (P.currentStep and P.currentStep.num) or 1
        if P.guideComplete then
            status, frac = LGet("UI_STATUS_DONE"), 1
        else
            status = LFormat("UI_STATUS_STEP_FMT", n, steps)
            frac = steps > 0 and n / steps or 0
        end
    end

    local nextTitle = "-"
    if guide.next and AR.Parser and AR.Parser.guidesByTitle then
        local ng = AR.Parser.guidesByTitle[guide.next]
        nextTitle = ng and getDisplayTitle(ng) or (guide.next:match("([^\\]+)$") or guide.next)
    end
    return { chips = chips, status = status, progress = frac, steps = steps, quests = quests, next = nextTitle }
end

function GuideMenu:RenderDetails(guide)
    local S = AR.Skins
    local d = self:BuildDetails(guide)
    self.details = d
    local x = 488
    for c, chip in ipairs(self.chips or {}) do
        local model = d.chips[c]
        if model then
            chip.label:SetText(model.text)
            if chip.label.SetTextColor then chip.label:SetTextColor(S:RGBA(model.accent and "accent" or "text")) end
            local w = (chip.label.GetStringWidth and chip.label:GetStringWidth()) or (#model.text * 6)
            w = math.floor(w + 16)
            chip:SetSize(w, 18)
            chip:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, -88)
            if chip.bg then S:Paint(chip.bg, model.accent and "whileHere" or "selected", 1) end
            chip:Show()
            x = x + w + 6
        else
            chip:Hide()
        end
    end
    if self.detailStatus then self.detailStatus:SetText(d.status) end
    if self.detailFill then
        local w = math.floor(210 * d.progress + 0.5)
        if w >= 1 then self.detailFill:SetWidth(w); self.detailFill:Show() else self.detailFill:Hide() end
    end
    if self.statRows then
        local values = { tostring(d.steps), tostring(d.quests), d.next }
        for r, row in ipairs(self.statRows) do
            row.key:SetText(LGet(row.labelKey))
            row.value:SetText(values[r])
        end
    end
    return d
end

-- Guides shown in the list: the search results while a query is typed, else the category.
function GuideMenu:GetVisibleGuides()
    local q = self.searchQuery
    if q and q ~= "" then return self:Search(q) end
    return self:GetGuidesForCategory(self.activeCategory)
end

local MODE_MODULES = { lookup = "Lookup", dungeons = "Dungeons", rares = "Rares", characters = "Characters", options = "OptionsPanel" }

function GuideMenu:ModeModule(mode)
    local name = MODE_MODULES[mode or self.mode]
    return name and AR[name] or nil
end

function GuideMenu:SetSearch(query)
    query = query or ""
    local module = self:ModeModule()
    if module then
        self.modeQueries = self.modeQueries or {}
        self.modeQueries[self.mode] = query
        module:SetQuery(query)
        return
    end
    self.searchQuery = query
    self.pageOffset = 0
    if self.searchBox and self.searchBox.SetText and self.searchBox.GetText and self.searchBox:GetText() ~= query then
        self.searchBox:SetText(query)
    end
    if self.frame then self:RenderGuidePage() end
end

-- Switches the Guide Center between its guide list and the Lookup / Dungeons panels.
function GuideMenu:SetMode(mode)
    local f = self:InitializeFrame()
    mode = MODE_MODULES[mode] and mode or "guides"
    self.mode = mode
    for _, name in pairs(MODE_MODULES) do
        local m = AR[name]
        if m and m.Attach then
            local panel = m:Attach(f)
            panel:SetShown(false)
        end
    end
    local module = self:ModeModule(mode)
    local query = (module and (self.modeQueries or {})[mode]) or (not module and self.searchQuery) or ""
    if self.searchBox and self.searchBox.SetText then self.searchBox:SetText(query) end
    for _, b in ipairs(self.modeButtons or {}) do
        paintSelectable(b, b._mode == mode)
        if b.label then b.label:SetText(LGet(b._labelKey)) end
    end
    if module then
        module:SetQuery(query)
        module.panel:SetShown(true)
    else
        self:RenderGuidePage()
    end
    return mode
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

    local guides = self:GetVisibleGuides()
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
                if rowBtn.tag then
                    local P = AR.Progression
                    if P and P.currentGuide == g then
                        local n = (P.currentStep and P.currentStep.num) or 1
                        rowBtn.tag:SetText(string.format("%d/%d", n, g.steps and #g.steps or 0))
                        if rowBtn.tag.SetTextColor then rowBtn.tag:SetTextColor(AR.Skins:RGBA("accent")) end
                    elseif inLevelRange(g) then
                        rowBtn.tag:SetText(LGet("UI_YOUR_LEVEL"))
                        if rowBtn.tag.SetTextColor then rowBtn.tag:SetTextColor(AR.Skins:RGBA("textMuted")) end
                    else
                        rowBtn.tag:SetText("")
                    end
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
    if self.searchQuery and self.searchQuery ~= "" then
        self.searchQuery = ""
        if self.searchBox and self.searchBox.SetText then self.searchBox:SetText("") end
    end
    self:RenderGuidePage()
end

function GuideMenu:NextPage()
    local guides = self:GetVisibleGuides()
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

function GuideMenu:Show(mode)
    local f = self:InitializeFrame()
    mode = mode or self.mode or "guides"
    if mode ~= "guides" or (self.mode and self.mode ~= "guides") then
        self:SetMode(mode)
    else
        self:SelectCategory(self.activeCategory)
    end
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
        elseif getDisplayTitle(guide):lower():find(lowerQuery, 1, true) then
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
