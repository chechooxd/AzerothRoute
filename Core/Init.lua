-- AzerothRoute: Bootstrapper & Addon Entrypoint (SPEC-01)

local AR = _G.AzerothRoute

function AR:Initialize()
    self.Storage:Initialize()
    self.Events:EnsureFrame()
    self.Events:SubscribeUpdate("scheduler_tick", 0, function()
        self.Scheduler:StepFrame()
    end)
    return true
end

AR:Initialize()

return AR
