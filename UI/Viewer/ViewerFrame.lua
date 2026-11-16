-- AzerothRoute: ViewerFrame Step & Sticky Renderer + Real In-Game Frame Hierarchy (SPEC-12 / SPEC-17)
-- Implements 1-line-per-goal formatting, 3-stop progress background gradient, 0.5s white completion flash,
-- separated Stickies block below a 1px divider, a 7px interactive progress bar, and real WoW Frame objects.

local AR = _G.AzerothRoute
local ViewerFrame = {
    LINES_PER_STEP = 20,
    progressMode = "steps", -- "steps" | "quests" | "xp"
    lastGoalSnapshots = {}, -- { [key] = { status = ..., cur = ... } }
    frame = nil,
    titleText = nil,
    stepNumText = nil,
    prevButton = nil,
    nextButton = nil,
    menuButton = nil,
    stickySeparator = nil,
    progressBar = nil,
    lineRows = {},
}
AR.ViewerFrame = ViewerFrame

function ViewerFrame:Initialize()
    self.progressMode = "steps"
    self.lastGoalSnapshots = {}
    self.lineRows = {}

    local f = AR.UI:Create("Frame", _G.UIParent, "AzerothRouteViewerFrame")
    f:SetSize(310, 240)
    f:SetPoint("RIGHT", _G.UIParent, "RIGHT", -60, 80)
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
    end

    if f.CreateFontString then
        self.titleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        self.titleText:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
        self.titleText:SetText("AzerothRoute")

        self.stepNumText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        self.stepNumText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -75, -8)
        self.stepNumText:SetText("Step 1")
    end

    -- Toolbar Prev / Next / Menu buttons
    self.prevButton = AR.UI:Create("Button", f, "AzerothRoutePrevButton")
    self.prevButton:SetSize(22, 18)
    self.prevButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -52, -5)
    self.prevButton:SetScript("OnClick", function()
        if AR.Progression then
            AR.Progression:PreviousStep()
            self:RefreshVisuals()
        end
    end)

    self.nextButton = AR.UI:Create("Button", f, "AzerothRouteNextButton")
    self.nextButton:SetSize(22, 18)
    self.nextButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -5)
    self.nextButton:SetScript("OnClick", function()
        if AR.Progression then
            AR.Progression:SkipStep(false)
            self:RefreshVisuals()
        end
    end)

    self.menuButton = AR.UI:Create("Button", f, "AzerothRouteMenuButton")
    self.menuButton:SetSize(22, 18)
    self.menuButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -5)
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
        row:SetSize(294, 20)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -28 - (i - 1) * 21)
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
            if r._goal and r._goal.map and r._goal.x and r._goal.y and AR.Pointer then
                AR.Pointer:PlaceStepPins({
                    { map = r._goal.map, x = r._goal.x, y = r._goal.y, title = r.label and r.label:GetText() or "Waypoint", objectiveIndex = i },
                })
            end
        end)
        row:Hide()
        table.insert(self.lineRows, row)
    end

    -- 7px interactive bottom progress bar
    self.progressBar = AR.UI:Create("Button", f, "AzerothRouteProgressBar")
    self.progressBar:SetSize(294, AR.Skins:GetProp("progressBarHeight") or 7)
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

    self.frame = f
    return f
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
    }
end

function ViewerFrame:RefreshVisuals()
    if not self.frame then
        self:Initialize()
    end
    local vm = self:RenderCurrentStep()

    if self.titleText and AR.Progression and AR.Progression.currentGuide then
        self.titleText:SetText(AR.Progression.currentGuide.title or "AzerothRoute")
    end
    if self.stepNumText then
        self.stepNumText:SetText("Step " .. tostring(vm.stepNum or 1))
    end

    local rowIdx = 0
    for _, line in ipairs(vm.mainLines) do
        rowIdx = rowIdx + 1
        local row = self.lineRows[rowIdx]
        if row then
            row._goal = line.goal
            if row.label then row.label:SetText(line.text) end
            if row.bg and line.bgColor then
                row.bg:SetColorTexture(line.bgColor.r, line.bgColor.g, line.bgColor.b, 0.85)
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
            self.stickySeparator:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 8, -28 - rowIdx * 21)
            self.stickySeparator:SetWidth(294)
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

    return vm
end

return ViewerFrame
