-- AzerothRoute: ViewerFrame — the guide window (SPEC-12 / SPEC-17 / SPEC-20)
-- Night-sky layout: a guide tab with a gold underline, a navigation toolbar
-- (< n / N >, Talents, Guides), plain step lines with coloured subjects and
-- check boxes, a "While you're here" block for sticky goals, dimmed upcoming
-- steps, and a thin gold progress bar with its percentage.

local AR = _G.AzerothRoute
local ViewerFrame = {
    WIDTH = 360,
    HEIGHT = 140,
    LINES_PER_STEP = 20,
    progressMode = "steps", -- "steps" | "quests" | "xp"
    lastGoalSnapshots = {}, -- { [key] = { status = ..., cur = ... } }
    frame = nil,
    titleText = nil,
    stepNumText = nil,
    prevButton = nil,
    nextButton = nil,
    talentButton = nil,
    menuButton = nil,
    stickySeparator = nil,
    stickyHeader = nil,
    progressBar = nil,
    percentText = nil,
    lineRows = {},
}
AR.ViewerFrame = ViewerFrame

-- Layout metrics (pixels).
local PAD = 8
local TAB_H = 28
local TOOLBAR_H = 28
local CONTENT_TOP = TAB_H + TOOLBAR_H + 6
local ROW_H = 22
local SECTION_HEADER_H = 18
local NOTICE_H = 22
local FOOTER_H = 26

local Skins

local function L(key, fallback)
    if AR.L then
        local v = AR.L:Get(key)
        if v and v ~= key then return v end
    end
    return fallback or key
end

local function getShortGuideTitle(guide)
    if type(guide) == "table" then
        if AR.L and AR.L:IsSpanish() and guide.displayTitleES then
            return guide.displayTitleES
        end
        if guide.displayTitleEN then
            return guide.displayTitleEN
        end
        guide = guide.title
    end
    if not guide then return L("UI_ADDON_TITLE", "AzerothRoute") end
    local short = guide:match("([^\\]+)$") or guide
    return short
end

local function attachHintTooltip(button, localeKey)
    if not button or not button.HookScript then return end
    button:HookScript("OnEnter", function(b)
        if _G.GameTooltip and _G.GameTooltip.SetOwner and AR.L then
            _G.GameTooltip:SetOwner(b, "ANCHOR_BOTTOM")
            for hint in tostring(AR.L:Get(localeKey)):gmatch("[^\n]+") do
                _G.GameTooltip:AddLine(hint, 1, 1, 1)
            end
            _G.GameTooltip:Show()
        end
    end)
    button:HookScript("OnLeave", function()
        if _G.GameTooltip and _G.GameTooltip.Hide then _G.GameTooltip:Hide() end
    end)
end

-- Flat toolbar button: muted text on transparent ground, gold text and a soft plate on hover.
local function createFlatButton(parent, name, labelText, width, height, fontObject)
    local btn = AR.UI:Create("Button", parent, name)
    btn:SetSize(width, height)
    if btn.CreateTexture then
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints(btn)
        btn.bg:SetColorTexture(0, 0, 0, 0)
    end
    if btn.CreateFontString then
        btn.label = btn:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlightSmall")
        btn.label:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn.label:SetText(labelText)
        if btn.label.SetTextColor then btn.label:SetTextColor(Skins:RGBA("textMuted")) end
    end
    btn:SetScript("OnEnter", function(b)
        Skins:Paint(b.bg, "hover")
        if b.label and b.label.SetTextColor then b.label:SetTextColor(Skins:RGBA("accent")) end
    end)
    btn:SetScript("OnLeave", function(b)
        if b.bg then b.bg:SetColorTexture(0, 0, 0, 0) end
        if b.label and b.label.SetTextColor then b.label:SetTextColor(Skins:RGBA("textMuted")) end
    end)
    return btn
end

-- Only scalar UIParent anchors are persisted; never serialize frame references.
function ViewerFrame:RestorePosition()
    if not self.frame then return end
    local valid = { CENTER=true, TOP=true, BOTTOM=true, LEFT=true, RIGHT=true,
        TOPLEFT=true, TOPRIGHT=true, BOTTOMLEFT=true, BOTTOMRIGHT=true }
    local saved = AR.db and AR.db.profile and AR.db.profile.viewer_pos
    self.frame:ClearAllPoints()
    if type(saved) == "table" and valid[saved.point] and valid[saved.relPoint]
        and type(saved.x) == "number" and type(saved.y) == "number"
        and math.abs(saved.x) < math.huge and math.abs(saved.y) < math.huge then
        self.frame:SetPoint(saved.point, _G.UIParent, saved.relPoint, saved.x, saved.y)
    else
        self.frame:SetPoint("RIGHT", _G.UIParent, "RIGHT", -50, 80)
    end
    if self.frame.SetClampedToScreen then self.frame:SetClampedToScreen(true) end
end

function ViewerFrame:BuildChrome(f)
    if not f.CreateTexture then return end
    local W = self.WIDTH

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints(f)
    Skins:Paint(f.bg, "bg")
    Skins:AddBorder(f, "border")

    -- Tab strip: raised band across the top, the active guide tab on the panel colour.
    f.tabStrip = f:CreateTexture(nil, "BACKGROUND")
    f.tabStrip:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.tabStrip:SetSize(W - 2, TAB_H - 1)
    Skins:Paint(f.tabStrip, "panelRaised")

    f.tabActive = f:CreateTexture(nil, "ARTWORK")
    f.tabActive:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.tabActive:SetSize(240, TAB_H - 1)
    Skins:Paint(f.tabActive, "bg")

    f.tabUnderline = f:CreateTexture(nil, "OVERLAY")
    f.tabUnderline:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -(TAB_H - 2))
    f.tabUnderline:SetSize(240, 2)
    Skins:Paint(f.tabUnderline, "accent")

    -- Divider between the toolbar and the step lines.
    f.toolbarDivider = f:CreateTexture(nil, "ARTWORK")
    f.toolbarDivider:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -(TAB_H + TOOLBAR_H))
    f.toolbarDivider:SetSize(W - 2, 1)
    Skins:Paint(f.toolbarDivider, "divider")

    -- Notice banner (level gate, unfinished turn-in).
    f.noticeBg = f:CreateTexture(nil, "BACKGROUND")
    f.noticeBg:SetSize(W - 2, NOTICE_H)
    Skins:Paint(f.noticeBg, "whileHere")
    f.noticeBg:Hide()

    -- "While you're here" block behind the sticky goals.
    f.whileHereBg = f:CreateTexture(nil, "BACKGROUND")
    Skins:Paint(f.whileHereBg, "whileHere")
    f.whileHereBg:Hide()
    f.whileHereBar = f:CreateTexture(nil, "ARTWORK")
    f.whileHereBar:SetWidth(2)
    Skins:Paint(f.whileHereBar, "accent")
    f.whileHereBar:Hide()

    -- Divider above the footer.
    f.footerDivider = f:CreateTexture(nil, "ARTWORK")
    f.footerDivider:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, FOOTER_H)
    f.footerDivider:SetSize(W - PAD * 2, 1)
    Skins:Paint(f.footerDivider, "divider")
end

function ViewerFrame:BuildHeader(f)
    if f.CreateFontString then
        self.tabIcon = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        self.tabIcon:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
        self.tabIcon:SetText("»")
        if self.tabIcon.SetTextColor then self.tabIcon:SetTextColor(Skins:RGBA("accent")) end

        self.titleText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        self.titleText:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -8)
        if self.titleText.SetWidth then self.titleText:SetWidth(206) end
        if self.titleText.SetWordWrap then self.titleText:SetWordWrap(false) end
        self.titleText:SetJustifyH("LEFT")
        if self.titleText.SetTextColor then self.titleText:SetTextColor(Skins:RGBA("text")) end
        self.titleText:SetText(L("UI_ADDON_TITLE", "AzerothRoute"))
    end

    -- Toolbar: [<] n / N [>] ............ [Talents] [Guides]
    local toolbarY = -(TAB_H + 4)
    self.prevButton = createFlatButton(f, "AzerothRoutePrevButton", "<", 20, 20, "GameFontHighlight")
    self.prevButton:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, toolbarY)
    self.prevButton:SetScript("OnClick", function(_, button)
        self:OnPrevClick(button)
    end)
    attachHintTooltip(self.prevButton, "UI_PREV_HINT")

    if f.CreateFontString then
        self.stepNumText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        self.stepNumText:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 22, toolbarY - 4)
        if self.stepNumText.SetWidth then self.stepNumText:SetWidth(60) end
        self.stepNumText:SetJustifyH("CENTER")
        if self.stepNumText.SetTextColor then self.stepNumText:SetTextColor(Skins:RGBA("text")) end
        self.stepNumText:SetText("1 / 1")
    end

    self.nextButton = createFlatButton(f, "AzerothRouteNextButton", ">", 20, 20, "GameFontHighlight")
    self.nextButton:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 84, toolbarY)
    if self.nextButton.RegisterForClicks then
        self.nextButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
    self.nextButton:SetScript("OnClick", function(_, button)
        self:OnNextClick(button)
    end)
    attachHintTooltip(self.nextButton, "UI_NEXT_HINT")

    -- Step counter opens the all-steps browser.
    self.stepsButton = AR.UI:Create("Button", f, "AzerothRouteStepsButton")
    self.stepsButton:SetSize(60, 20)
    self.stepsButton:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 22, toolbarY)
    self.stepsButton:SetScript("OnClick", function()
        if AR.StepBrowser then AR.StepBrowser:Toggle() end
    end)
    attachHintTooltip(self.stepsButton, "UI_STEPS_HINT")

    -- Right side, from the edge inwards: [...] [Guides] [Talents] [map] [Skip]
    self.moreButton = createFlatButton(f, "AzerothRouteMoreButton", "...", 22, 20, "GameFontHighlight")
    self.moreButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, toolbarY)
    self.moreButton:SetScript("OnClick", function(b) self:ShowMoreMenu(b) end)
    attachHintTooltip(self.moreButton, "UI_MORE_HINT")

    self.menuButton = createFlatButton(f, "AzerothRouteMenuButton", L("UI_GUIDES", "Guides"), 50, 20)
    self.menuButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(PAD + 24), toolbarY)
    self.menuButton:SetScript("OnClick", function()
        if AR.GuideMenu and AR.GuideMenu.Toggle then
            AR.GuideMenu:Toggle()
        end
    end)

    self.talentButton = createFlatButton(f, "AzerothRouteTalentButton", L("UI_TALENTS", "Talents"), 58, 20)
    self.talentButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(PAD + 76), toolbarY)
    self.talentButton:SetScript("OnClick", function()
        if AR.TalentAdvisor and AR.TalentAdvisor.ToggleUI then
            AR.TalentAdvisor:ToggleUI()
        end
    end)

    self.mapButton = createFlatButton(f, "AzerothRouteMapButton", "", 22, 20)
    self.mapButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(PAD + 136), toolbarY)
    if self.mapButton.CreateTexture then
        self.mapButton.icon = self.mapButton:CreateTexture(nil, "ARTWORK")
        self.mapButton.icon:SetSize(14, 14)
        self.mapButton.icon:SetPoint("CENTER", self.mapButton, "CENTER", 0, 0)
        self.mapButton.icon:SetTexture(Skins:GetActionIcon("goto"))
    end
    self.mapButton:SetScript("OnClick", function() self:ShowWaypointOnMap() end)
    attachHintTooltip(self.mapButton, "UI_MAP_HINT")

    self.skipButton = createFlatButton(f, "AzerothRouteSkipButton", L("UI_SKIP", "Skip"), 40, 20)
    self.skipButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(PAD + 160), toolbarY)
    self.skipButton:SetScript("OnClick", function()
        if AR.Progression then AR.Progression:SkipStep(false) end
        self:RefreshVisuals()
    end)
    attachHintTooltip(self.skipButton, "UI_SKIP_HINT")

    if f.CreateFontString then
        self.noticeText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        if self.noticeText.SetWidth then self.noticeText:SetWidth(self.WIDTH - 36) end
        self.noticeText:SetJustifyH("LEFT")
        if self.noticeText.SetTextColor then self.noticeText:SetTextColor(Skins:RGBA("accent")) end
        self.noticeText:Hide()

        -- Step heading: who/where in large coloured text, the zone under it.
        self.headingText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        if self.headingText.SetWidth then self.headingText:SetWidth(self.WIDTH - 44) end
        if self.headingText.SetWordWrap then self.headingText:SetWordWrap(false) end
        self.headingText:SetJustifyH("LEFT")
        self.headingText:Hide()
        self.headingSub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.headingSub:SetJustifyH("LEFT")
        if self.headingSub.SetTextColor then self.headingSub:SetTextColor(Skins:RGBA("textMuted")) end
        self.headingSub:Hide()
        if f.CreateTexture then
            self.headingIcon = f:CreateTexture(nil, "ARTWORK")
            self.headingIcon:SetSize(16, 16)
            self.headingIcon:Hide()
            self.headingBar = f:CreateTexture(nil, "ARTWORK")
            self.headingBar:SetWidth(2)
            Skins:Paint(self.headingBar, "accent")
            self.headingBar:Hide()
        end

        self.stickyHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        self.stickyHeader:SetJustifyH("LEFT")
        if self.stickyHeader.SetTextColor then self.stickyHeader:SetTextColor(Skins:RGBA("accent")) end
        self.stickyHeader:SetText(L("UI_WHILE_HERE", "While you're here"))
        self.stickyHeader:Hide()
    end

    -- 1px rule that opens the "While you're here" block.
    if f.CreateTexture then
        self.stickySeparator = f:CreateTexture(nil, "ARTWORK")
        self.stickySeparator:SetHeight(1)
        Skins:Paint(self.stickySeparator, "accent", 0.55)
        self.stickySeparator:Hide()
    end
end

function ViewerFrame:OnRowClick(r, button)
    if r._isFold then
        self.expandDone = not self.expandDone
        self:RefreshVisuals()
        return
    end
    if not r._goal then return end
    if r._isPreview and button == "RightButton" then return end
    if button == "RightButton" and r._goal:ToggleManualArrival() then
        if AR.Progression then AR.Progression:TryToCompleteStep(true) end
        self:RefreshVisuals()
        return
    end
    if r._goal.map and r._goal.x and r._goal.y and AR.Pointer then
        if _G.WorldMapFrame and _G.WorldMapFrame:IsShown() and _G.WorldMapFrame.SetMapID then
            _G.WorldMapFrame:SetMapID(r._goal.map)
        end
        AR.Pointer:PlaceStepPins({
            { map = r._goal.map, x = r._goal.x, y = r._goal.y, title = r._plainText or "Waypoint", objectiveIndex = r._index, action = r._goal.action },
        })
        AR.Pointer:UpdateArrow(0)
    end
    local act = r._goal.action
    if r._goal.confirm or act == "confirm" or act == "vendor" or act == "trainer" or act == "home" or act == "hearth" or act == "fpath" or act == "fly" or act == "click" or act == "use" then
        r._goal.confirmed = true
        if AR.Progression then
            AR.Progression:TryToCompleteStep(true)
        end
        self:RefreshVisuals()
    end
end

function ViewerFrame:CreateRow(f, i)
    local row = AR.UI:Create("Button", f, "AzerothRouteStepLine" .. i)
    row._index = i
    row:SetSize(self.WIDTH - PAD * 2, ROW_H)
    row:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -CONTENT_TOP - (i - 1) * ROW_H)
    if row.CreateTexture then
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints(row)
        row.bg:SetColorTexture(0, 0, 0, 0)

        row.accent = row:CreateTexture(nil, "ARTWORK")
        row.accent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.accent:SetSize(2, ROW_H)
        Skins:Paint(row.accent, "accent")
        row.accent:Hide()

        row.flash = row:CreateTexture(nil, "OVERLAY")
        row.flash:SetAllPoints(row)
        row.flash:SetColorTexture(1, 1, 1, 0)
        row.flash:Hide()

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(14, 14)
        row.icon:SetPoint("LEFT", row, "LEFT", 8, 0)

        row.check = row:CreateTexture(nil, "ARTWORK")
        row.check:SetSize(16, 16)
        row.check:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        row.check:SetTexture(Skins.CHECKBOX_ICON)
        row.check:Hide()

        row.checkMark = row:CreateTexture(nil, "OVERLAY")
        row.checkMark:SetSize(16, 16)
        row.checkMark:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        row.checkMark:SetTexture(Skins.CHECKBOX_CHECK_ICON)
        row.checkMark:Hide()
    end
    if row.CreateFontString then
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.label:SetPoint("LEFT", row, "LEFT", 28, 0)
        if row.label.SetWidth then row.label:SetWidth(self.WIDTH - PAD * 2 - 28 - 22) end
        if row.label.SetWordWrap then row.label:SetWordWrap(false) end
        row.label:SetJustifyH("LEFT")
    end
    -- "While you're here" extras: distance to the goal and a × that dismisses it for the session.
    if row.CreateFontString then
        row.dist = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.dist:SetPoint("RIGHT", row, "RIGHT", -24, 0)
        row.dist:SetJustifyH("RIGHT")
        if row.dist.SetTextColor then row.dist:SetTextColor(Skins:RGBA("textMuted")) end
        row.dist:Hide()
    end
    row.dismiss = createFlatButton(row, "AzerothRouteStepLine" .. i .. "Dismiss", "×", 18, 18)
    row.dismiss:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.dismiss:SetScript("OnClick", function()
        if row._goal then
            row._goal.dismissed = true
            self:RefreshVisuals()
        end
    end)
    row.dismiss:Hide()

    if row.RegisterForClicks then row:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    row:SetScript("OnClick", function(r, button) self:OnRowClick(r, button) end)
    row:SetScript("OnEnter", function(r)
        if r._goal and not r._isHeader then Skins:Paint(r.bg, "hover", 0.55) end
    end)
    row:SetScript("OnLeave", function(r)
        if r.bg then r.bg:SetColorTexture(0, 0, 0, 0) end
    end)
    row:Hide()
    return row
end

function ViewerFrame:BuildFooter(f)
    local trackW = self.WIDTH - PAD * 2 - 44
    self.progressBar = AR.UI:Create("Button", f, "AzerothRouteProgressBar")
    self.progressBar:SetSize(trackW, 14)
    self.progressBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD + 2, 6)
    self.progressBar._trackWidth = trackW
    if self.progressBar.CreateTexture then
        local h = Skins:GetProp("progressBarHeight") or 4
        self.progressBar.track = self.progressBar:CreateTexture(nil, "BACKGROUND")
        self.progressBar.track:SetPoint("LEFT", self.progressBar, "LEFT", 0, 0)
        self.progressBar.track:SetSize(trackW, h)
        Skins:Paint(self.progressBar.track, "track")

        self.progressBar.fill = self.progressBar:CreateTexture(nil, "ARTWORK")
        self.progressBar.fill:SetPoint("LEFT", self.progressBar, "LEFT", 0, 0)
        self.progressBar.fill:SetSize(1, h)
        Skins:Paint(self.progressBar.fill, "accent")
        self.progressBar.fill:Hide()
    end
    self.progressBar:SetScript("OnClick", function()
        self:CycleProgressMode()
        self:RefreshVisuals()
    end)
    attachHintTooltip(self.progressBar, "UI_PROGRESS_HINT")

    if f.CreateFontString then
        self.percentText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        self.percentText:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD - 2, 6)
        self.percentText:SetJustifyH("RIGHT")
        if self.percentText.SetTextColor then self.percentText:SetTextColor(Skins:RGBA("text")) end
        self.percentText:SetText("0%")

        -- "» 24.0k XP/h · 1m to level" above the bar once a rate is known.
        self.xpText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.xpText:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD + 2, 24)
        if self.xpText.SetWidth then self.xpText:SetWidth(self.WIDTH - PAD * 2 - 4) end
        if self.xpText.SetWordWrap then self.xpText:SetWordWrap(false) end
        self.xpText:SetJustifyH("LEFT")
        if self.xpText.SetTextColor then self.xpText:SetTextColor(Skins:RGBA("textMuted")) end
        self.xpText:Hide()

        -- "Guide complete" banner above the footer.
        self.completeText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        self.completeText:SetPoint("BOTTOM", f, "BOTTOM", 0, FOOTER_H + 4)
        if self.completeText.SetTextColor then self.completeText:SetTextColor(Skins:RGBA("accent")) end
        self.completeText:Hide()
    end

    -- Whole-window flash when a step completes.
    if f.CreateTexture then
        self.borderFlash = f:CreateTexture(nil, "OVERLAY")
        self.borderFlash:SetAllPoints(f)
        Skins:Paint(self.borderFlash, "accent", 1)
        self.borderFlash:SetAlpha(0)
        self.borderFlash:Hide()
        if self.borderFlash.CreateAnimationGroup then
            local ag = self.borderFlash:CreateAnimationGroup()
            local fade = ag:CreateAnimation("Alpha")
            fade:SetFromAlpha(0.22)
            fade:SetToAlpha(0)
            fade:SetDuration(0.6)
            ag:SetScript("OnFinished", function() self.borderFlash:Hide() end)
            self.borderFlashAnim = ag
        end
    end
end

function ViewerFrame:Initialize()
    Skins = AR.Skins
    self.progressMode = "steps"
    self.lastGoalSnapshots = {}
    self.lineRows = {}

    local f = AR.UI:Create("Frame", _G.UIParent, "AzerothRouteViewerFrame")
    f:SetSize(self.WIDTH, self.HEIGHT)
    self.frame = f
    self:RestorePosition()
    if f.SetMovable then f:SetMovable(true) end
    if f.EnableMouse then f:EnableMouse(true) end
    if f.RegisterForDrag then f:RegisterForDrag("LeftButton") end
    f:SetScript("OnDragStart", function(frame)
        if frame.StartMoving then frame:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(frame)
        if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end
        AR.ActionBar:SaveBarPosition("viewer_pos", frame)
    end)

    self:BuildChrome(f)
    self:BuildHeader(f)
    for i = 1, self.LINES_PER_STEP do
        table.insert(self.lineRows, self:CreateRow(f, i))
    end
    self:BuildFooter(f)
    f:SetScript("OnUpdate", function(_, elapsed) self:OnTick(elapsed) end)
    return f
end

-- Opens the world map on the current waypoint's zone.
function ViewerFrame:ShowWaypointOnMap()
    local target = AR.Pointer and AR.Pointer.activeTarget
    if not target or not target.map then return false end
    local wm = _G.WorldMapFrame
    if wm and not (wm.IsShown and wm:IsShown()) then
        if _G.ToggleWorldMap then _G.ToggleWorldMap() elseif wm.Show then wm:Show() end
    end
    if wm and wm.SetMapID then wm:SetMapID(target.map) end
    return true
end

function ViewerFrame:BuildMoreMenuItems()
    local items = {
        { text = L("UI_MENU_STEPS", "All steps"), onClick = function() if AR.StepBrowser then AR.StepBrowser:Show() end end },
        { text = L("UI_MENU_QUESTLOG", "Clean up quest log"), onClick = function() if AR.QuestLogCleanup then AR.QuestLogCleanup:Show() end end },
        { separator = true },
        { text = L("UI_GUIDES", "Guides"), onClick = function() if AR.GuideMenu then AR.GuideMenu:Show("guides") end end },
        { text = L("UI_LOOKUP", "Lookup"), onClick = function() if AR.GuideMenu then AR.GuideMenu:Show("lookup") end end },
        { text = L("UI_DUNGEONS", "Dungeons"), onClick = function() if AR.GuideMenu then AR.GuideMenu:Show("dungeons") end end },
        { text = L("UI_TALENTS", "Talents"), onClick = function() if AR.TalentAdvisor and AR.TalentAdvisor.ToggleUI then AR.TalentAdvisor:ToggleUI() end end },
        { text = L("UI_MENU_OPTIONS", "Options"), onClick = function() if AR.Config and AR.Config.Open then AR.Config:Open() end end },
        { separator = true },
        { text = L("UI_MENU_HIDE", "Hide guide window"), onClick = function() if self.frame then self.frame:Hide() end end },
    }
    return items
end

function ViewerFrame:ShowMoreMenu(anchor)
    return AR.UI:ShowMenu(anchor or self.moreButton, self:BuildMoreMenuItems())
end

-- XP rate over the session: gained XP (level-ups included) divided by elapsed time.
ViewerFrame.XP_MIN_SECONDS = 30

function ViewerFrame:ResetXPTracker()
    self.xp = nil
end

function ViewerFrame:SampleXP(now)
    if not _G.UnitXP or not _G.UnitXPMax then return end
    now = now or (_G.GetTime and _G.GetTime()) or 0
    local cur, max = _G.UnitXP("player") or 0, _G.UnitXPMax("player") or 0
    local x = self.xp
    if not x then
        self.xp = { start = now, gained = 0, cur = cur, max = max }
        return
    end
    if cur >= x.cur then
        x.gained = x.gained + (cur - x.cur)
    else -- levelled up: the rest of the old bar plus the new progress
        x.gained = x.gained + math.max(0, x.max - x.cur) + cur
    end
    x.cur, x.max = cur, max
end

function ViewerFrame:GetXPPerHour(now)
    local x = self.xp
    if not x then return nil end
    now = now or (_G.GetTime and _G.GetTime()) or 0
    local elapsed = now - x.start
    if elapsed < self.XP_MIN_SECONDS or x.gained <= 0 then return nil end
    return x.gained / elapsed * 3600
end

local function shortNumber(n)
    if n >= 1000 then return string.format("%.1fk", n / 1000) end
    return tostring(math.floor(n + 0.5))
end

local function shortDuration(secs)
    secs = math.max(0, math.floor(secs + 0.5))
    if secs < 60 then return secs .. "s" end
    if secs < 3600 then return math.floor(secs / 60) .. "m" end
    return string.format("%dh %dm", math.floor(secs / 3600), math.floor((secs % 3600) / 60))
end

-- "24.0k XP/h · 1m to level", or nil until enough XP has been gained to estimate.
function ViewerFrame:FormatXPLine(now)
    local rate = self:GetXPPerHour(now)
    if not rate or not self.xp or self.xp.max <= 0 then return nil end
    local left = (self.xp.max - self.xp.cur) / rate * 3600
    return string.format(L("UI_XP_LINE_FMT", "%s XP/h · %s to level"), shortNumber(rate), shortDuration(left))
end

-- Every 5 s: resample XP; relayout only when the XP line appears or disappears.
ViewerFrame.TICK_SECONDS = 5
function ViewerFrame:OnTick(elapsed)
    self._tick = (self._tick or 0) + (elapsed or 0)
    if self._tick < self.TICK_SECONDS then return end
    self._tick = 0
    for _, row in ipairs(self.lineRows) do
        if row:IsShown() and row.dismiss and row.dismiss:IsShown() then self:UpdateRowDistance(row) end
    end
    self:SampleXP()
    local line = self:FormatXPLine()
    local shown = self.xpText and self.xpText:IsShown()
    if (line ~= nil) ~= (shown == true) then
        self:RefreshVisuals()
    elseif line and self.xpText then
        self.xpText:SetText("» " .. line)
    end
end

local function modifierDown(fnName)
    return _G[fnName] and _G[fnName]() and true or false
end

function ViewerFrame:OnNextClick(button)
    local progression = AR.Progression
    if not progression then return end
    if button == "RightButton" then
        progression:SkipToNextIncomplete()
    elseif modifierDown("IsShiftKeyDown") then
        progression:JumpSteps(10)
    else
        progression:SkipStep(false)
    end
    self:RefreshVisuals()
end

function ViewerFrame:OnPrevClick(button)
    local progression = AR.Progression
    if not progression then return end
    if modifierDown("IsControlKeyDown") then
        progression:GoToFirstStep()
    else
        progression:PreviousStep()
    end
    self:RefreshVisuals()
end

function ViewerFrame:FlashBorder()
    self.borderFlashCount = (self.borderFlashCount or 0) + 1
    if not self.borderFlash then return end
    self.borderFlash:Show()
    if self.borderFlashAnim then
        self.borderFlashAnim:Stop()
        self.borderFlashAnim:Play()
    else
        self.borderFlash:SetAlpha(0.22)
        if _G.C_Timer and _G.C_Timer.After then
            _G.C_Timer.After(0.6, function() self.borderFlash:Hide() end)
        end
    end
end

function ViewerFrame:CycleProgressMode()
    if self.progressMode == "steps" then
        self.progressMode = "quests"
    elseif self.progressMode == "quests" then
        self.progressMode = "xp"
    else
        self.progressMode = "steps"
    end
    return self.progressMode
end

-- Fraction (0..1) shown by the footer bar for the current progress mode.
function ViewerFrame:ComputeProgress(mode, stepNum)
    mode = mode or self.progressMode
    if mode == "xp" and _G.UnitXP and _G.UnitXPMax then
        local cur, max = _G.UnitXP("player") or 0, _G.UnitXPMax("player") or 0
        if max > 0 then return math.max(0, math.min(1, cur / max)) end
        return 0
    end
    local guide = AR.Progression and AR.Progression.currentGuide
    local steps = guide and guide.steps
    if not steps or #steps == 0 then return 0 end
    stepNum = stepNum or (AR.Progression.currentStep and AR.Progression.currentStep.num) or 1
    if mode == "quests" then
        local total, done = 0, 0
        for _, st in ipairs(steps) do
            for _, g in ipairs(st.goals or {}) do
                if g.action == "turnin" then
                    total = total + 1
                    if (st.num or 0) < stepNum then done = done + 1 end
                end
            end
        end
        if total > 0 then return done / total end
    end
    return math.max(0, math.min(1, stepNum / #steps))
end

function ViewerFrame:FormatGoalLine(goal, index, isSticky)
    local status = goal:GetStatus()
    if status == "hidden" then
        return nil
    end
    -- A reached waypoint reads as done even while it is a passive (non-blocking) goal.
    if status == "passive" and goal.action == "goto" and goal.visited then
        status = "complete"
    end
    local cur, max = goal:GetProgress()
    local frac = 0
    if status == "complete" then
        frac = 1
    elseif cur and max and max > 0 then
        frac = math.min(1, cur / max)
    end

    local bgColor
    if status == "impossible" then
        bgColor = AR.Skins:GetProp("goalImpossible")
    elseif status == "warning" then
        bgColor = AR.Skins:GetProp("goalWarning")
    elseif status == "passive" then
        bgColor = AR.Skins:GetProp("goalPassive")
    else
        bgColor = AR.UI:Gradient3(
            frac,
            AR.Skins:GetProp("goalIncomplete"),
            AR.Skins:GetProp("goalProgressing"),
            AR.Skins:GetProp("goalComplete")
        )
    end

    local snapKey = string.format("%s:%d:%d", isSticky and "S" or "M", (goal.parentStep and goal.parentStep.num) or 0, goal.num or index)
    local prev = self.lastGoalSnapshots[snapKey]
    local flashDuration = 0
    if prev and ((prev.cur and cur and cur > prev.cur) or (prev.status ~= "complete" and status == "complete")) then
        flashDuration = 0.5
    end
    self.lastGoalSnapshots[snapKey] = { status = status, cur = cur }

    local isDone = status == "complete"
    local plain = goal:GetText(isDone)
    return {
        goal = goal,
        text = plain,
        richText = self:HighlightSubject(goal, plain, isDone),
        status = status,
        bgColor = bgColor,
        icon = isDone and AR.Skins.CHECK_ICON or AR.Skins:GetActionIcon(goal.action),
        checkIcon = isDone,
        flashDuration = flashDuration,
        isSticky = isSticky == true,
    }
end

-- Colours the goal's subject (quest gold, NPC blue, item violet) inside its plain text.
function ViewerFrame:HighlightSubject(goal, text, isDone)
    if isDone or not text or not goal.GetSubject then return text end
    local name, kind = goal:GetSubject()
    if type(name) ~= "string" or name == "" then return text end
    local s, e = text:find(name, 1, true)
    if not s then return text end
    return text:sub(1, s - 1) .. AR.Skins:Colorize(name, kind) .. text:sub(e + 1)
end

function ViewerFrame:RenderCurrentStep()
    local step = AR.Progression and AR.Progression.currentStep
    local mainLines = {}
    local stickyLines = {}
    local pinsToPlace = {}

    if step and step.goals then
        for i, g in ipairs(step.goals) do
            local line = self:FormatGoalLine(g, i, false)
            if line then
                table.insert(mainLines, line)
                if g.map and g.x and g.y and line.status ~= "complete" then
                    table.insert(pinsToPlace, {
                        map = g.map,
                        x = g.x,
                        y = g.y,
                        title = line.text,
                        objectiveIndex = i,
                        action = g.action,
                    })
                end
            end
        end
    end

    local activeStickies = (AR.Progression and AR.Progression:GetActiveStickies()) or {}
    for _, sStep in ipairs(activeStickies) do
        for i, g in ipairs(sStep.goals or {}) do
            local line = (not g.dismissed) and self:FormatGoalLine(g, i, true) or nil
            if line then
                table.insert(stickyLines, line)
                if g.map and g.x and g.y and line.status ~= "complete" then
                    table.insert(pinsToPlace, {
                        map = g.map,
                        x = g.x,
                        y = g.y,
                        title = "[Sticky] " .. line.text,
                        objectiveIndex = #pinsToPlace + 1,
                        action = g.action,
                    })
                end
            end
        end
    end

    if AR.Pointer then
        AR.Pointer:PlaceStepPins(pinsToPlace)
    end

    local notice = AR.Progression and AR.Progression:GetStepNotice(step)
    local previewLines = self:BuildPreviewLines(step)

    return {
        heading = self:BuildHeading(step),
        note = self:FindStepNote(step),
        thenLine = (#previewLines == 0) and self:BuildThenLine(step) or nil,
        previewLines = previewLines,
        stepNum = step and step.num or 1,
        mainLines = mainLines,
        hasStickySeparator = (#stickyLines > 0),
        stickySeparatorHeight = 1,
        stickyLines = stickyLines,
        notice = notice,
        progressBarHeight = AR.Skins:GetProp("progressBarHeight"),
        progressMode = self.progressMode,
        progress = self:ComputeProgress(self.progressMode, step and step.num),
        guideComplete = (AR.Progression and AR.Progression.guideComplete) == true,
    }
end

local function mapName(mapID)
    if not mapID or not _G.C_Map or not _G.C_Map.GetMapInfo then return nil end
    local ok, info = pcall(_G.C_Map.GetMapInfo, mapID)
    return ok and info and info.name or nil
end

local HEADING_ACTIONS = { talk = true, vendor = true, trainer = true, kill = true }

-- Step heading: the step's explicit title, else the first person to see, else the place to go.
-- Returns { text = rich text, plain = text, sub = zone name or nil, icon = texture } or nil.
function ViewerFrame:BuildHeading(step)
    if not step or not step.goals then return nil end
    local zoneID = step.map
    local text, plain, icon
    if step.title and step.title ~= "" then
        text, plain = step.title, step.title
    end
    for _, g in ipairs(step.goals) do
        if not zoneID and g.map then zoneID = g.map end
        if not text and HEADING_ACTIONS[g.action] and g:IsVisible() then
            local name, kind = g:GetSubject()
            if type(name) == "string" and name ~= "" then
                text, plain = AR.Skins:Colorize(name, kind), name
                icon = AR.Skins:GetActionIcon(g.action)
            end
        end
    end
    local zone = mapName(zoneID)
    if not text then
        if not zone then return nil end
        return { text = zone, plain = zone, icon = AR.Skins:GetActionIcon("goto") }
    end
    return { text = text, plain = plain, sub = zone, icon = icon or AR.Skins:GetActionIcon("talk") }
end

-- The first author tip attached to the step's goals, shown as a muted note line.
function ViewerFrame:FindStepNote(step)
    for _, g in ipairs((step and step.goals) or {}) do
        if type(g.tooltip) == "string" and g.tooltip ~= "" and g:IsVisible() then
            return g.tooltip
        end
    end
    return nil
end

-- One-line summary of the next visible regular step: "Then: <heading or first goal>".
function ViewerFrame:BuildThenLine(step)
    local guide = AR.Progression and AR.Progression.currentGuide
    if not guide or not step or not guide.GetStep then return nil end
    for n = step.num + 1, #guide.steps do
        local nextStep = guide:GetStep(n)
        if nextStep and not nextStep.is_sticky and nextStep:IsVisible() then
            local heading = self:BuildHeading(nextStep)
            local summary, plain
            if heading and heading.sub then
                summary, plain = heading.text, heading.plain
            end
            for _, g in ipairs(nextStep.goals or {}) do
                local status = g:GetStatus()
                if status ~= "hidden" and status ~= "complete" and g.action ~= "goto" then
                    local text = g:GetText(false)
                    local rich = self:HighlightSubject(g, text, false)
                    summary = summary and (summary .. " · " .. rich) or rich
                    plain = plain and (plain .. " · " .. text) or text
                    break
                end
            end
            if not summary and heading then summary, plain = heading.text, heading.plain end
            if not summary then return nil end
            local prefix = L("UI_THEN", "Then:")
            return { isHeader = true, isThen = true, text = prefix .. " " .. plain, richText = prefix .. " " .. summary, stepNum = n }
        end
    end
    return nil
end

-- Upcoming steps, dimmed, each under a "Step N" header. No pins.
function ViewerFrame:BuildPreviewLines(step)
    local lines = {}
    local count = (AR.db and AR.db.profile and tonumber(AR.db.profile.previewsteps)) or 0
    local guide = AR.Progression and AR.Progression.currentGuide
    if count <= 0 or not guide or not step then return lines end
    local shown = 0
    for n = step.num + 1, #guide.steps do
        if shown >= count then break end
        local nextStep = guide:GetStep(n)
        if nextStep and not nextStep.is_sticky and nextStep:IsVisible() then
            shown = shown + 1
            local header = string.format(L("UI_STEP_HEADER_FMT", "Step %d"), nextStep.num)
            table.insert(lines, { isHeader = true, text = header })
            for i, g in ipairs(nextStep.goals or {}) do
                local line = self:FormatGoalLine(g, i, false)
                if line then
                    line.isPreview = true
                    line.flashDuration = 0
                    table.insert(lines, line)
                end
            end
        end
    end
    return lines
end

-- Yards from the player to a sticky goal's coordinates, shown at the row's right edge.
function ViewerFrame:UpdateRowDistance(row)
    if not row.dist then return end
    local g = row._goal
    local d = g and g.map and g.x and g.y and AR.Coords and AR.Coords.GetDistanceTo
        and AR.Coords:GetDistanceTo(g.map, (g.x > 1) and g.x / 100 or g.x, (g.y > 1) and g.y / 100 or g.y)
    if d then
        row.dist:SetText(string.format("%d yd", math.floor(d + 0.5)))
        row.dist:Show()
    else
        row.dist:Hide()
    end
end

-- Paints one row. `tone` is "current", "normal", "done", "sticky", "preview" or "header".
local function paintRow(row, line, tone)
    row._goal = line.goal
    row._isPreview = line.isPreview == true
    row._isHeader = line.isHeader == true
    row._isFold = line.isFold == true
    row._plainText = line.text
    local done = line.status == "complete"
    local dim = (tone == "preview") and 0.55 or 1

    if row.label then
        row.label:SetText(line.richText or line.text)
        if row.label.SetTextColor then
            if tone == "header" then
                row.label:SetTextColor(Skins:RGBA("textMuted"))
            elseif done then
                row.label:SetTextColor(Skins:RGBA("textDone", dim))
            elseif line.status == "warning" then
                row.label:SetTextColor(Skins:RGBA("warn", dim))
            elseif line.status == "impossible" then
                row.label:SetTextColor(Skins:RGBA("textMuted", dim))
            else
                row.label:SetTextColor(Skins:RGBA("text", dim))
            end
        end
    end
    if row.icon then
        if line.icon then
            row.icon:SetTexture(line.icon)
            if row.icon.SetAlpha then row.icon:SetAlpha(done and 0.8 or dim) end
            row.icon:Show()
        else
            row.icon:Hide()
        end
    end
    -- Check box for goals the player completes; passive lines and headers have none.
    local showBox = line.goal ~= nil and tone ~= "preview" and (done or line.status ~= "passive")
    if row.check then
        if showBox then row.check:Show() else row.check:Hide() end
    end
    if row.checkMark then
        if showBox and done then row.checkMark:Show() else row.checkMark:Hide() end
    end
    if row.accent then
        if tone == "current" then row.accent:Show() else row.accent:Hide() end
    end
    local sticky = tone == "sticky" and line.goal ~= nil
    if row.label and row.label.SetWidth then
        row.label:SetWidth(ViewerFrame.WIDTH - PAD * 2 - 28 - (sticky and 70 or 22))
    end
    if row.dismiss then
        if sticky then row.dismiss:Show() else row.dismiss:Hide() end
    end
    if sticky then
        if row.check then row.check:Hide() end
        if row.checkMark then row.checkMark:Hide() end
        ViewerFrame:UpdateRowDistance(row)
    elseif row.dist then
        row.dist:Hide()
    end
    if row.bg then row.bg:SetColorTexture(0, 0, 0, 0) end
    row:Show()
end

local function placeRow(self, row, y, indent)
    row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", PAD + (indent or 0), -y)
    if row.label then
        row.label:SetPoint("LEFT", row, "LEFT", row._isHeader and 8 or 28, 0)
    end
end

function ViewerFrame:RefreshVisuals()
    if not self.frame then
        self:Initialize()
    end
    Skins = AR.Skins
    local vm = self:RenderCurrentStep()
    local f = self.frame
    if vm.stepNum ~= self._lastStepNum then
        self.expandDone = false
        self._lastStepNum = vm.stepNum
    end

    if self.menuButton and self.menuButton.label then
        self.menuButton.label:SetText(L("UI_GUIDES", "Guides"))
    end
    if self.talentButton and self.talentButton.label then
        self.talentButton.label:SetText(L("UI_TALENTS", "Talents"))
    end
    if self.skipButton and self.skipButton.label then
        self.skipButton.label:SetText(L("UI_SKIP", "Skip"))
    end
    if self.stickyHeader then
        self.stickyHeader:SetText(L("UI_WHILE_HERE", "While you're here"))
    end
    if self.titleText and AR.Progression and AR.Progression.currentGuide then
        self.titleText:SetText(getShortGuideTitle(AR.Progression.currentGuide))
    end
    if self.stepNumText then
        local totalSteps = (AR.Progression and AR.Progression.currentGuide and #AR.Progression.currentGuide.steps) or 1
        self.stepNumText:SetText(string.format("%d / %d", vm.stepNum or 1, totalSteps))
    end

    local y = CONTENT_TOP

    -- Notice banner.
    if vm.notice and vm.notice.message and self.noticeText then
        f.noticeBg:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -(TAB_H + TOOLBAR_H + 1))
        f.noticeBg:Show()
        self.noticeText:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -(TAB_H + TOOLBAR_H + 6))
        self.noticeText:SetText(vm.notice.message)
        self.noticeText:Show()
        y = y + NOTICE_H
    elseif self.noticeText then
        self.noticeText:Hide()
        if f.noticeBg then f.noticeBg:Hide() end
    end

    -- Step heading (who / where) with the zone underneath and a gold bar.
    if vm.heading and self.headingText then
        local top = y
        if self.headingIcon then
            self.headingIcon:SetTexture(vm.heading.icon)
            self.headingIcon:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 8, -(y + 2))
            self.headingIcon:Show()
        end
        self.headingText:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 28, -y)
        self.headingText:SetText(vm.heading.text)
        if self.headingText.SetTextColor then self.headingText:SetTextColor(Skins:RGBA("text")) end
        self.headingText:Show()
        y = y + 20
        if vm.heading.sub then
            self.headingSub:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 28, -y)
            self.headingSub:SetText(vm.heading.sub)
            self.headingSub:Show()
            y = y + 14
        else
            self.headingSub:Hide()
        end
        if self.headingBar then
            self.headingBar:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -top)
            self.headingBar:SetSize(2, y - top)
            self.headingBar:Show()
        end
        y = y + 6
    else
        if self.headingText then self.headingText:Hide() end
        if self.headingSub then self.headingSub:Hide() end
        if self.headingIcon then self.headingIcon:Hide() end
        if self.headingBar then self.headingBar:Hide() end
    end

    local rowIdx = 0
    local currentMarked = false
    local function nextRow()
        rowIdx = rowIdx + 1
        return self.lineRows[rowIdx]
    end

    -- Two or more finished goals fold into one "N done" line (click to unfold).
    local doneCount = 0
    for _, line in ipairs(vm.mainLines) do
        if line.status == "complete" then doneCount = doneCount + 1 end
    end
    local fold = doneCount >= 2 and not self.expandDone
    vm.doneFolded = fold and doneCount or 0
    local foldShown = false

    for _, line in ipairs(vm.mainLines) do
        local folded = fold and line.status == "complete"
        local row = (not folded or not foldShown) and nextRow() or nil
        if folded and row then
            foldShown = true
            local text = string.format(L("UI_DONE_FMT", "%d done"), doneCount)
            paintRow(row, { isFold = true, text = text, status = "complete", icon = AR.Skins.CHECK_ICON }, "normal")
            placeRow(self, row, y)
            if row.flash then row.flash:Hide() end
            y = y + ROW_H
            row = nil
        end
        if row then
            local tone = "normal"
            if not currentMarked and (line.status == "incomplete" or line.status == "warning") then
                tone = "current"
                currentMarked = true
            end
            paintRow(row, line, tone)
            placeRow(self, row, y)
            if row.flash then
                if line.flashDuration > 0 then
                    row.flash:SetAlpha(0.35)
                    row.flash:Show()
                else
                    row.flash:Hide()
                end
            end
            y = y + ROW_H
        end
    end

    -- Author tip for the step, muted, on one line.
    if vm.note then
        local row = nextRow()
        if row then
            paintRow(row, { isHeader = true, text = "› " .. vm.note }, "header")
            placeRow(self, row, y)
            if row.flash then row.flash:Hide() end
            y = y + ROW_H
        end
    end

    -- "While you're here": accent rule, gold header, tinted block behind the sticky goals.
    local hasSticky = vm.hasStickySeparator and rowIdx < self.LINES_PER_STEP
    if hasSticky then
        y = y + 6
        local blockTop = y
        if self.stickySeparator then
            self.stickySeparator:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -y)
            self.stickySeparator:SetWidth(self.WIDTH - PAD * 2)
            self.stickySeparator:Show()
        end
        if self.stickyHeader then
            self.stickyHeader:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 8, -(y + 4))
            self.stickyHeader:Show()
        end
        y = y + SECTION_HEADER_H
        for _, line in ipairs(vm.stickyLines) do
            local row = nextRow()
            if row then
                paintRow(row, line, "sticky")
                placeRow(self, row, y)
                if row.flash then row.flash:Hide() end
                y = y + ROW_H
            end
        end
        y = y + 4
        if f.whileHereBg then
            f.whileHereBg:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -blockTop)
            f.whileHereBg:SetSize(self.WIDTH - PAD * 2, y - blockTop)
            f.whileHereBg:Show()
            f.whileHereBar:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -blockTop)
            f.whileHereBar:SetSize(2, y - blockTop)
            f.whileHereBar:Show()
        end
    else
        if self.stickySeparator then self.stickySeparator:Hide() end
        if self.stickyHeader then self.stickyHeader:Hide() end
        if f.whileHereBg then f.whileHereBg:Hide() end
        if f.whileHereBar then f.whileHereBar:Hide() end
    end

    if vm.thenLine then
        local row = nextRow()
        if row then
            y = y + 2
            paintRow(row, vm.thenLine, "header")
            placeRow(self, row, y)
            if row.flash then row.flash:Hide() end
            y = y + ROW_H
        end
    end

    if #vm.previewLines > 0 then y = y + 4 end
    for _, line in ipairs(vm.previewLines) do
        local row = nextRow()
        if row then
            paintRow(row, line, line.isHeader and "header" or "preview")
            placeRow(self, row, y)
            if row.flash then row.flash:Hide() end
            y = y + ROW_H
        end
    end

    for i = rowIdx + 1, self.LINES_PER_STEP do
        if self.lineRows[i] then
            self.lineRows[i]:Hide()
        end
    end

    -- Footer: thin gold progress bar and its percentage.
    local frac = vm.progress or 0
    if self.progressBar and self.progressBar.fill then
        local w = math.floor((self.progressBar._trackWidth or 0) * frac + 0.5)
        if w >= 1 then
            self.progressBar.fill:SetWidth(w)
            self.progressBar.fill:Show()
        else
            self.progressBar.fill:Hide()
        end
    end
    if self.percentText then
        self.percentText:SetText(string.format("%d%%", math.floor(frac * 100 + 0.5)))
    end

    -- XP rate line grows the footer when shown.
    self:SampleXP()
    local footerH = FOOTER_H
    local xpLine = self:FormatXPLine()
    vm.xpLine = xpLine
    if self.xpText then
        if xpLine then
            self.xpText:SetText("» " .. xpLine)
            self.xpText:Show()
            footerH = FOOTER_H + 18
        else
            self.xpText:Hide()
        end
    end
    if f.footerDivider then
        f.footerDivider:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, footerH)
    end
    if self.completeText then
        self.completeText:SetPoint("BOTTOM", f, "BOTTOM", 0, footerH + 4)
    end

    if self.completeText then
        if vm.guideComplete then
            self.completeText:SetText(L("UI_GUIDE_COMPLETE", "Guide complete!"))
            self.completeText:Show()
            y = y + ROW_H
        else
            self.completeText:Hide()
        end
    end

    -- Grow the window to fit the visible rows (never below the default height).
    local wanted = math.max(self.HEIGHT, y + 6 + footerH)
    if f.SetHeight then
        f:SetHeight(wanted)
    else
        f:SetSize(self.WIDTH, wanted)
    end

    return vm
end

return ViewerFrame
