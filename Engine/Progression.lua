-- AzerothRoute: Reactive Progression Controller (SPEC-03)
-- Implements FocusStep, StepHistory stack, Skip Streak decay (0.8x -> 0.01s), Manual Pause Latch, and explicit step notices.

local AR = _G.AzerothRoute
local Progression = {
    currentGuide = nil,
    currentStep = nil,
    pause = nil,
    fastforward = false,
    completionStreak = 0,
    completionInterval = 1.0,
    postponedNotices = {},
}
AR.Progression = Progression

function Progression:LoadGuide(guide, startStepNum)
    self.currentGuide = guide
    self.pause = nil
    self.fastforward = false
    self.completionStreak = 0
    self.completionInterval = 1.0
    self.postponedNotices = {}

    if AR.db and AR.db.char then
        AR.db.char.currentGuideTitle = guide and guide.title or nil
        AR.db.char.guidestephistory[guide.title] = AR.db.char.guidestephistory[guide.title] or { steps = {} }
    end

    local targetStep = startStepNum or (AR.Chains and AR.Chains:FindStartingPoint(guide)) or 1
    self:FocusStep(targetStep, true)
end

function Progression:FocusStep(stepNumOrLabel, isAutoAdvance)
    if not self.currentGuide then return nil end
    local step = nil
    if type(stepNumOrLabel) == "string" then
        step = self.currentGuide:GetStepByLabel(stepNumOrLabel)
    else
        step = self.currentGuide:GetStep(stepNumOrLabel)
    end
    if not step then return nil end

    if self.currentStep and self.currentStep.num ~= step.num and AR.db and AR.db.char and isAutoAdvance then
        local hist = AR.db.char.guidestephistory[self.currentGuide.title]
        if hist and hist.steps then
            table.insert(hist.steps, self.currentStep.num)
        end
    end

    self.currentStep = step
    if AR.db and AR.db.char then
        AR.db.char.currentStepNum = step.num
    end

    -- Clear pause latch automatically when landing on an incomplete step
    local isDone = step:IsComplete()
    if self.pause and not isDone then
        self.pause = nil
    end

    AR.Events:SendMessage("AR_STEP_CHANGED", step.num, step)
    return step
end

function Progression:SkipStep(isAuto)
    if not self.currentGuide or not self.currentStep then return end
    if not isAuto then
        self.pause = true
        self.fastforward = false
        self.completionStreak = 0
        self.completionInterval = 1.0
    end

    local nextNum = self.currentStep.num + 1
    while nextNum <= #self.currentGuide.steps do
        local candidate = self.currentGuide:GetStep(nextNum)
        if candidate and not candidate.is_sticky then
            return self:FocusStep(nextNum, isAuto)
        end
        nextNum = nextNum + 1
    end
end

function Progression:PreviousStep()
    if not self.currentGuide or not self.currentStep then return end
    self.pause = true
    self.fastforward = false
    self.completionStreak = 0
    self.completionInterval = 1.0

    local hist = AR.db and AR.db.char and AR.db.char.guidestephistory[self.currentGuide.title]
    if hist and hist.steps and #hist.steps > 0 then
        local prevNum = table.remove(hist.steps)
        return self:FocusStep(prevNum, false)
    end

    local prevNum = math.max(1, self.currentStep.num - 1)
    return self:FocusStep(prevNum, false)
end

function Progression:TryToCompleteStep(force)
    if not self.currentGuide or not self.currentStep then return false end
    self.currentStep:CheckVisitedGotos()

    if self.pause then
        return false
    end

    local isDone, reason = self.currentStep:IsComplete()
    if isDone then
        if reason == "override" then
            -- Record postponed incomplete objectives when an override (#completewith) completes the step early
            for _, g in ipairs(self.currentStep.goals or {}) do
                if not g.override and g:GetStatus() == "incomplete" then
                    table.insert(self.postponedNotices, {
                        stepNum = self.currentStep.num,
                        goalText = g:GetText(),
                    })
                end
            end
        end
        self.fastforward = true
        self.completionStreak = self.completionStreak + 1
        self.completionInterval = math.max(0.01, self.completionInterval * 0.8)
        self:SkipStep(true)
        return true
    else
        self.fastforward = false
        self.completionStreak = 0
        self.completionInterval = 1.0
        return false
    end
end

function Progression:GetActiveStickies()
    if not self.currentGuide or not self.currentStep then return {} end
    return self.currentGuide:GetStickiesForStep(self.currentStep.num)
end

function Progression:GetStepNotice(step)
    step = step or self.currentStep
    if not step or not step.goals then return nil end
    local playerLvl = (_G.UnitLevel and _G.UnitLevel("player")) or 1
    for _, g in ipairs(step.goals) do
        if g.action == "ding" and (g.level or 1) > playerLvl then
            return {
                type = "level_gate",
                requiredLevel = g.level,
                message = string.format("Waiting for Level %d (Current: %d)", g.level, playerLvl),
            }
        elseif g:GetStatus() == "warning" then
            return {
                type = "incomplete_turnin",
                message = "Quest objectives are not yet complete for turn-in.",
            }
        end
    end
    return nil
end

return Progression
