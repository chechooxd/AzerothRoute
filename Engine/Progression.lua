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
    guideComplete = nil,
    -- SOUNDKIT.MAP_PING, the sound Zygor plays when a step completes.
    STEP_COMPLETE_SOUND = (_G.SOUNDKIT and _G.SOUNDKIT.MAP_PING) or 3175,
}
AR.Progression = Progression

local function say(key, fallback, ...)
    if not AR.Print then return end
    local fmt = (AR.L and AR.L:Get(key)) or fallback
    if fmt == key then fmt = fallback end
    AR:Print(string.format(fmt, ...))
end

local function displayTitle(guide)
    if not guide then return "" end
    local es = AR.L and AR.L.IsSpanish and AR.L:IsSpanish()
    return (es and guide.displayTitleES) or guide.displayTitleEN or guide.title or ""
end

function Progression:LoadGuide(guide, startStepNum)
    self.currentGuide = guide
    self.pause = nil
    self.fastforward = false
    self.completionStreak = 0
    self.completionInterval = 1.0
    self.postponedNotices = {}
    self.guideComplete = nil

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
    return self:OnGuideEnd()
end

-- Resume the guide and step saved for this character (Zygor restores the active tab on login).
function Progression:RestoreSaved()
    local char = AR.db and AR.db.char
    local title = char and char.currentGuideTitle
    local guide = title and AR.Parser and AR.Parser.guidesByTitle and AR.Parser.guidesByTitle[title]
    if not guide or not guide.steps or #guide.steps == 0 then return false end
    local stepNum = math.max(1, math.min(tonumber(char.currentStepNum) or 1, #guide.steps))
    self:LoadGuide(guide, stepNum)
    return true
end

-- Last step done: load the guide named by the "next" header, or mark the guide finished (once).
function Progression:OnGuideEnd()
    if self.guideComplete or not self.currentGuide then return nil end
    local finished = self.currentGuide
    local nextGuide = finished.next and AR.Parser and AR.Parser.guidesByTitle and AR.Parser.guidesByTitle[finished.next]
    if nextGuide and nextGuide ~= finished then
        self:LoadGuide(nextGuide)
        say("UI_GUIDE_NEXT_FMT", "Guide complete: %s. Next guide: %s", displayTitle(finished), displayTitle(nextGuide))
        AR.Events:SendMessage("AR_GUIDE_CHANGED", nextGuide)
        return self.currentStep
    end
    self.guideComplete = true
    say("UI_GUIDE_DONE_FMT", "Guide complete: %s. Open /ar menu to pick the next one.", displayTitle(finished))
    AR.Events:SendMessage("AR_GUIDE_COMPLETE", finished)
    return nil
end

local function firstRegularStep(guide, fromNum, toNum, step)
    for n = fromNum, toNum, step do
        local candidate = guide:GetStep(n)
        if candidate and not candidate.is_sticky then return candidate end
    end
    return nil
end

local function pauseForManualJump(self)
    self.pause = true
    self.fastforward = false
    self.completionStreak = 0
    self.completionInterval = 1.0
end

-- Next button right-click: first later step that is not complete yet.
function Progression:SkipToNextIncomplete()
    if not self.currentGuide or not self.currentStep then return nil end
    pauseForManualJump(self)
    for n = self.currentStep.num + 1, #self.currentGuide.steps do
        local candidate = self.currentGuide:GetStep(n)
        if candidate and not candidate.is_sticky and not candidate:IsComplete() then
            return self:FocusStep(n, false)
        end
    end
    return self:OnGuideEnd()
end

-- Next button Shift-click: move several steps at once, clamped to the guide.
function Progression:JumpSteps(count)
    if not self.currentGuide or not self.currentStep then return nil end
    pauseForManualJump(self)
    local total = #self.currentGuide.steps
    local target = math.max(1, math.min(self.currentStep.num + count, total))
    -- Prefer the nearest regular step in the jump direction, else the nearest one before the target.
    local step = (count >= 0 and firstRegularStep(self.currentGuide, target, total, 1))
        or firstRegularStep(self.currentGuide, target, 1, -1)
    if step then return self:FocusStep(step.num, false) end
    return nil
end

-- Prev button Ctrl-click: back to the first step.
function Progression:GoToFirstStep()
    if not self.currentGuide then return nil end
    pauseForManualJump(self)
    local step = firstRegularStep(self.currentGuide, 1, #self.currentGuide.steps, 1)
    if step then return self:FocusStep(step.num, false) end
    return nil
end

-- Feedback for the step the player just finished (not for steps fast-forwarded past).
function Progression:NotifyStepComplete()
    if not (AR.db and AR.db.profile and AR.db.profile.stepsound == false) and _G.PlaySound then
        _G.PlaySound(self.STEP_COMPLETE_SOUND)
    end
    if AR.ViewerFrame and AR.ViewerFrame.FlashBorder then
        AR.ViewerFrame:FlashBorder()
    end
    AR.Events:SendMessage("AR_STEP_COMPLETED", self.currentStep and self.currentStep.num)
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
    if self.guideComplete then return false end
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
        if self.completionStreak == 0 then
            self:NotifyStepComplete()
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
