-- AzerothRoute: FPS-Adaptive Coroutine Scheduler (SPEC-01)
-- Budgets 5ms (<40 FPS), 10ms (<60 FPS), 20ms (>=60 FPS), or 1ms in combat across ordered startup phases.

local AR = _G.AzerothRoute
local Scheduler = {
    PHASES = { "before_guides", "load_guides", "after_guides", "after_all", "postcombat" },
    phaseTasks = {},
    thread = nil,
    frameStartMs = 0,
    currentBudgetMs = 10,
    startupComplete = false,
    backgroundThreads = {},
}
AR.Scheduler = Scheduler

function Scheduler:Reset()
    self.phaseTasks = {}
    for _, p in ipairs(self.PHASES) do
        self.phaseTasks[p] = {}
    end
    self.thread = nil
    self.frameStartMs = 0
    self.currentBudgetMs = 10
    self.startupComplete = false
    self.backgroundThreads = {}
end

Scheduler:Reset()

function Scheduler:GetFrameBudgetMs()
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        return 1
    end
    if AR.db and AR.db.profile and AR.db.profile.loadguidesfully then
        return 100
    end
    local fps = (_G.GetFramerate and _G.GetFramerate()) or 60
    if fps < 40 then
        return 5
    elseif fps < 60 then
        return 10
    else
        return 20
    end
end

function Scheduler:RegisterPhaseTask(phase, name, fn)
    if not self.phaseTasks[phase] then
        error("Unknown startup phase: " .. tostring(phase))
    end
    table.insert(self.phaseTasks[phase], { name = name, fn = fn })
end

function Scheduler:YieldIfNeeded()
    if not coroutine.running() then return end
    local now = (_G.debugprofilestop and _G.debugprofilestop()) or 0
    if (now - self.frameStartMs) >= self.currentBudgetMs then
        coroutine.yield("budget_exceeded")
    end
end

function Scheduler:BuildStartupThread()
    return coroutine.create(function()
        for _, phase in ipairs(self.PHASES) do
            if phase == "postcombat" then
                while _G.InCombatLockdown and _G.InCombatLockdown() do
                    coroutine.yield("waiting_for_combat")
                end
            end
            local tasks = self.phaseTasks[phase] or {}
            for i = 1, #tasks do
                tasks[i].fn()
                self:YieldIfNeeded()
            end
        end
        self.startupComplete = true
    end)
end

function Scheduler:StepFrame()
    self.frameStartMs = (_G.debugprofilestop and _G.debugprofilestop()) or 0
    self.currentBudgetMs = self:GetFrameBudgetMs()

    if not self.startupComplete then
        if not self.thread then
            self.thread = self:BuildStartupThread()
        end
        if coroutine.status(self.thread) ~= "dead" then
            local ok, err = coroutine.resume(self.thread)
            if not ok then
                error("Startup coroutine failed: " .. tostring(err))
            end
        else
            self.startupComplete = true
        end
    end

    -- Also step any active background worker coroutines within remaining budget
    for name, co in pairs(self.backgroundThreads) do
        if coroutine.status(co) == "dead" then
            self.backgroundThreads[name] = nil
        else
            local now = (_G.debugprofilestop and _G.debugprofilestop()) or 0
            if (now - self.frameStartMs) < self.currentBudgetMs then
                local ok, err = coroutine.resume(co)
                if not ok then
                    self.backgroundThreads[name] = nil
                    error("Background coroutine [" .. name .. "] failed: " .. tostring(err))
                end
            end
        end
    end
end

function Scheduler:SpawnBackgroundThread(name, fn)
    local co = coroutine.create(fn)
    self.backgroundThreads[name] = co
    return co
end

function Scheduler:IsStartupComplete()
    return self.startupComplete == true
end

return Scheduler
