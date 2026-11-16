-- AzerothRoute: Bootstrapper, Live Event Wiring & /ar Slash Command (SPEC-01 / SPEC-16 / SPEC-17)

local AR = _G.AzerothRoute

function AR:RegisterSlashCommands()
    _G.SLASH_AZEROTHROUTE1 = "/ar"
    _G.SLASH_AZEROTHROUTE2 = "/azerothroute"
    _G.SlashCmdList = _G.SlashCmdList or {}
    _G.SlashCmdList["AZEROTHROUTE"] = function(msg)
        msg = (msg or ""):match("^%s*(.-)%s*$"):lower()
        if msg == "menu" then
            if AR.GuideMenu then
                AR.GuideMenu:Toggle()
            end
        elseif msg == "next" then
            if AR.Progression then
                AR.Progression:SkipStep(false)
                if AR.ViewerFrame then AR.ViewerFrame:RefreshVisuals() end
            end
        elseif msg == "prev" then
            if AR.Progression then
                AR.Progression:PreviousStep()
                if AR.ViewerFrame then AR.ViewerFrame:RefreshVisuals() end
            end
        else
            if AR.ViewerFrame and AR.ViewerFrame.frame then
                if AR.ViewerFrame.frame:IsShown() then
                    AR.ViewerFrame.frame:Hide()
                else
                    AR.ViewerFrame.frame:Show()
                    AR.ViewerFrame:RefreshVisuals()
                end
            end
        end
    end
end

function AR:Initialize()
    self.Storage:Initialize()
    self.Events:EnsureFrame()
    self:RegisterSlashCommands()

    -- Frame-budgeted coroutine scheduler tick
    self.Events:SubscribeUpdate("scheduler_tick", 0, function()
        self.Scheduler:StepFrame()
    end)

    -- 30 FPS pointer arrow tick
    self.Events:SubscribeUpdate("pointer_tick", 0.033, function(dt)
        if self.Pointer then
            self.Pointer:UpdateArrow(dt)
        end
    end)

    -- 0.1s reactive step completion tick
    self.Events:SubscribeUpdate("progression_tick", 0.1, function()
        if self.Progression and self.Progression.currentStep then
            local advanced = self.Progression:TryToCompleteStep(false)
            if advanced and self.ViewerFrame then
                self.ViewerFrame:RefreshVisuals()
            end
        end
    end)

    -- Wire live client events when entering world
    self.Events:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        if self.QuestTracking then
            self.QuestTracking:RegisterLiveEvents()
            self.QuestTracking:ScanQuestLog()
        end
        if self.QuestAutoAccept then
            self.QuestAutoAccept:RegisterLiveEvents()
        end
        if self.ActionBar then
            self.ActionBar:Initialize()
            self.ActionBar:RegisterLiveEvents()
        end
        if self.Pointer then
            self.Pointer:InitializeFrames()
        end
        if self.PartySync then
            self.PartySync:RegisterLiveEvents()
        end
        if self.ViewerFrame then
            self.ViewerFrame:Initialize()
            if not self.Progression.currentGuide and self.GuideMenu then
                local suggested = self.GuideMenu:FindSuggestedGuides()
                if suggested[1] then
                    self.Progression:LoadGuide(suggested[1])
                end
            end
            self.ViewerFrame:RefreshVisuals()
        end
    end)

    return true
end

AR:Initialize()

return AR
