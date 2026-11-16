-- AzerothRoute: ViewerFrame Step & Sticky Renderer (SPEC-12)
-- Implements 1-line-per-goal formatting, 3-stop progress background gradient, 0.5s white completion flash,
-- separated Stickies block below a 1px divider, and a 7px interactive progress bar.

local AR = _G.AzerothRoute
local ViewerFrame = {
    LINES_PER_STEP = 20,
    progressMode = "steps", -- "steps" | "quests" | "xp"
    lastGoalSnapshots = {}, -- { [key] = { status = ..., cur = ... } }
    frame = nil,
}
AR.ViewerFrame = ViewerFrame

function ViewerFrame:Initialize()
    self.progressMode = "steps"
    self.lastGoalSnapshots = {}
    self.frame = AR.UI:Create("Frame", nil, "AzerothRouteViewerFrame")
    return self.frame
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

return ViewerFrame
