-- AzerothRoute: ViewerFrame Step & Sticky Renderer + Polished In-Game Frame Hierarchy (SPEC-12 / SPEC-17 / SPEC-20)
-- Fixes header text collision, renders visible labeled [<], [>], and [Guides] buttons, and supports interactive step rows.

local AR = _G.AzerothRoute
local ViewerFrame = {
    WIDTH = 360,
    HEIGHT = 250,
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
    progressBar = nil,
    lineRows = {},
}
AR.ViewerFrame = ViewerFrame

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
    if not guide then return (AR.L and AR.L:Get("UI_ADDON_TITLE")) or "AzerothRoute" end
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

local function createStyledToolbarButton(parent, name, labelText, width, height)
    local btn = AR.UI:Create("Button", parent, name)
    btn:SetSize(width, height)
    if btn.CreateTexture then
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints(btn)
        btn.bg:SetColorTexture(0.18, 0.22, 0.30, 0.95)
    end
    if btn.CreateFontString then
        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.label:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn.label:SetText(labelText)
    end
    btn:SetScript("OnEnter", function(b)
        if b.bg then b.bg:SetColorTexture(0.28, 0.36, 0.50, 1.0) end
    end)
    btn:SetScript("OnLeave", function(b)
        if b.bg then b.bg:SetColorTexture(0.18, 0.22, 0.30, 0.95) end
    end)
    return btn
end

function ViewerFrame:Initialize()
    self.progressMode = "steps"
    self.lastGoalSnapshots = {}
    self.lineRows = {}

    local f = AR.UI:Create("Frame", _G.UIParent, "AzerothRouteViewerFrame")
    f:SetSize(self.WIDTH, self.HEIGHT)
    f:SetPoint("RIGHT", _G.UIParent, "RIGHT", -50, 80)
    if f.SetMovable then f:SetMovable(true) end
    if f.EnableMouse then f:EnableMouse(true) end
    if f.RegisterForDrag then f:RegisterForDrag("LeftButton") end
    f:SetScript("OnDragStart", function(frame)
        if frame.StartMoving then frame:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(frame)
        if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end
    end)

    local bgProp = AR.Skins:GetProp("bg") or { r = 0.08, g = 0.09, b = 0.12, a = 0.94 }
    if f.CreateTexture then
        f.bg = f:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAllPoints(f)
        f.bg:SetColorTexture(bgProp.r, bgProp.g, bgProp.b, bgProp.a or 0.94)

        f.headerBar = f:CreateTexture(nil, "ARTWORK")
        f.headerBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        f.headerBar:SetSize(self.WIDTH, 28)
        f.headerBar:SetColorTexture(0.12, 0.14, 0.20, 0.98)
    end

    if f.CreateFontString then
        self.titleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        self.titleText:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -7)
        if self.titleText.SetWidth then self.titleText:SetWidth(145) end
        if self.titleText.SetWordWrap then self.titleText:SetWordWrap(false) end
        self.titleText:SetJustifyH("LEFT")
        self.titleText:SetText((AR.L and AR.L:Get("UI_ADDON_TITLE")) or "AzerothRoute")

        self.stepNumText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.stepNumText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -166, -8)
        self.stepNumText:SetText("1/1")
    end

    -- Visible, labeled toolbar buttons: [<] [>] [Talents] [Guides]
    self.prevButton = createStyledToolbarButton(f, "AzerothRoutePrevButton", "<", 20, 20)
    self.prevButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -142, -4)
    self.prevButton:SetScript("OnClick", function(_, button)
        self:OnPrevClick(button)
    end)
    attachHintTooltip(self.prevButton, "UI_PREV_HINT")

    self.nextButton = createStyledToolbarButton(f, "AzerothRouteNextButton", ">", 20, 20)
    self.nextButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -118, -4)
    if self.nextButton.RegisterForClicks then
        self.nextButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
    self.nextButton:SetScript("OnClick", function(_, button)
        self:OnNextClick(button)
    end)
    attachHintTooltip(self.nextButton, "UI_NEXT_HINT")

    self.talentButton = createStyledToolbarButton(f, "AzerothRouteTalentButton", (AR.L and AR.L:Get("UI_TALENTS")) or "Talents", 56, 20)
    self.talentButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -58, -4)
    self.talentButton:SetScript("OnClick", function()
        if AR.TalentAdvisor and AR.TalentAdvisor.ToggleUI then
            AR.TalentAdvisor:ToggleUI()
        end
    end)

    self.menuButton = createStyledToolbarButton(f, "AzerothRouteMenuButton", (AR.L and AR.L:Get("UI_GUIDES")) or "Guides", 50, 20)
    self.menuButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    self.menuButton:SetScript("OnClick", function()
        if AR.GuideMenu and AR.GuideMenu.Toggle then
            AR.GuideMenu:Toggle()
        end
    end)

    -- 1px Sticky Separator
    if f.CreateTexture then
        self.stickySeparator = f:CreateTexture(nil, "ARTWORK")
        self.stickySeparator:SetHeight(1)
        self.stickySeparator:SetColorTexture(0.35, 0.38, 0.45, 0.9)
        self.stickySeparator:Hide()
    end

    -- Pre-allocate 20 visual StepLine rows
    for i = 1, self.LINES_PER_STEP do
        local row = AR.UI:Create("Button", f, "AzerothRouteStepLine" .. i)
        row:SetSize(self.WIDTH - 16, 20)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -32 - (i - 1) * 21)
        if row.CreateTexture then
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints(row)
            row.flash = row:CreateTexture(nil, "OVERLAY")
            row.flash:SetAllPoints(row)
            row.flash:SetColorTexture(1, 1, 1, 0)
            row.flash:Hide()
        end
        if row.CreateFontString then
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.label:SetPoint("LEFT", row, "LEFT", 6, 0)
            row.label:SetJustifyH("LEFT")
        end
        row:SetScript("OnClick", function(r)
            if not r._goal then return end
            if r._goal.map and r._goal.x and r._goal.y and AR.Pointer then
                AR.Pointer:PlaceStepPins({
                    { map = r._goal.map, x = r._goal.x, y = r._goal.y, title = r.label and r.label:GetText() or "Waypoint", objectiveIndex = i, action = r._goal.action },
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
        end)
        row:Hide()
        table.insert(self.lineRows, row)
    end

    -- 7px interactive bottom progress bar
    self.progressBar = AR.UI:Create("Button", f, "AzerothRouteProgressBar")
    self.progressBar:SetSize(self.WIDTH - 16, AR.Skins:GetProp("progressBarHeight") or 7)
    self.progressBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 6)
    if self.progressBar.CreateTexture then
        self.progressBar.fill = self.progressBar:CreateTexture(nil, "ARTWORK")
        self.progressBar.fill:SetPoint("TOPLEFT", self.progressBar, "TOPLEFT", 0, 0)
        self.progressBar.fill:SetHeight(7)
        self.progressBar.fill:SetColorTexture(0.22, 0.74, 0.97, 0.9)
    end
    self.progressBar:SetScript("OnClick", function()
        self:CycleProgressMode()
        self:RefreshVisuals()
    end)

    -- Whole-window green flash when a step completes (Zygor's "ThinFlash" border cue).
    if f.CreateTexture then
        self.borderFlash = f:CreateTexture(nil, "OVERLAY")
        self.borderFlash:SetAllPoints(f)
        self.borderFlash:SetColorTexture(0.30, 0.90, 0.40, 1)
        self.borderFlash:SetAlpha(0)
        self.borderFlash:Hide()
        if self.borderFlash.CreateAnimationGroup then
            local ag = self.borderFlash:CreateAnimationGroup()
            local fade = ag:CreateAnimation("Alpha")
            fade:SetFromAlpha(0.35)
            fade:SetToAlpha(0)
            fade:SetDuration(0.6)
            ag:SetScript("OnFinished", function() self.borderFlash:Hide() end)
            self.borderFlashAnim = ag
        end
    end

    -- "Guide complete" banner over the progress bar.
    if f.CreateFontString then
        self.completeText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        self.completeText:SetPoint("BOTTOM", f, "BOTTOM", 0, 16)
        self.completeText:Hide()
    end

    self.frame = f
    return f
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
        self.borderFlash:SetAlpha(0.35)
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

    return {
        goal = goal,
        text = goal:GetText(),
        status = status,
        bgColor = bgColor,
        checkIcon = (status == "complete"),
        flashDuration = flashDuration,
        isSticky = isSticky == true,
    }
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
            local line = self:FormatGoalLine(g, i, true)
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

    if AR.Pointer and #pinsToPlace > 0 then
        AR.Pointer:PlaceStepPins(pinsToPlace)
    end

    local notice = AR.Progression and AR.Progression:GetStepNotice(step)

    return {
        stepNum = step and step.num or 1,
        mainLines = mainLines,
        hasStickySeparator = (#stickyLines > 0),
        stickySeparatorHeight = 1,
        stickyLines = stickyLines,
        notice = notice,
        progressBarHeight = AR.Skins:GetProp("progressBarHeight"),
        progressMode = self.progressMode,
        guideComplete = (AR.Progression and AR.Progression.guideComplete) == true,
    }
end

function ViewerFrame:RefreshVisuals()
    if not self.frame then
        self:Initialize()
    end
    local vm = self:RenderCurrentStep()

    if self.menuButton and self.menuButton.label and AR.L then
        self.menuButton.label:SetText(AR.L:Get("UI_GUIDES"))
    end
    if self.talentButton and self.talentButton.label and AR.L then
        self.talentButton.label:SetText(AR.L:Get("UI_TALENTS"))
    end
    if self.titleText and AR.Progression and AR.Progression.currentGuide then
        self.titleText:SetText(getShortGuideTitle(AR.Progression.currentGuide))
    end
    if self.stepNumText then
        local totalSteps = (AR.Progression and AR.Progression.currentGuide and #AR.Progression.currentGuide.steps) or 1
        self.stepNumText:SetText(string.format("%d/%d", vm.stepNum or 1, totalSteps))
    end

    local rowIdx = 0
    for _, line in ipairs(vm.mainLines) do
        rowIdx = rowIdx + 1
        local row = self.lineRows[rowIdx]
        if row then
            row._goal = line.goal
            if row.label then row.label:SetText(line.text) end
            if row.bg and line.bgColor then
                row.bg:SetColorTexture(line.bgColor.r, line.bgColor.g, line.bgColor.b, 0.88)
            end
            if row.flash then
                if line.flashDuration > 0 then
                    row.flash:SetAlpha(0.75)
                    row.flash:Show()
                else
                    row.flash:Hide()
                end
            end
            row:Show()
        end
    end

    if self.stickySeparator then
        if vm.hasStickySeparator then
            self.stickySeparator:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 8, -32 - rowIdx * 21)
            self.stickySeparator:SetWidth(self.WIDTH - 16)
            self.stickySeparator:Show()
        else
            self.stickySeparator:Hide()
        end
    end

    for _, line in ipairs(vm.stickyLines) do
        rowIdx = rowIdx + 1
        local row = self.lineRows[rowIdx]
        if row then
            row._goal = line.goal
            if row.label then row.label:SetText(line.text) end
            if row.bg and line.bgColor then
                row.bg:SetColorTexture(line.bgColor.r, line.bgColor.g, line.bgColor.b, 0.65)
            end
            row:Show()
        end
    end

    for i = rowIdx + 1, self.LINES_PER_STEP do
        if self.lineRows[i] then
            self.lineRows[i]:Hide()
        end
    end

    if self.completeText then
        if vm.guideComplete then
            self.completeText:SetText((AR.L and AR.L:Get("UI_GUIDE_COMPLETE")) or "Guide complete!")
            self.completeText:Show()
        else
            self.completeText:Hide()
        end
    end

    return vm
end

return ViewerFrame
