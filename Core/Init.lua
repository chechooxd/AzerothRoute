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
        elseif msg == "talents" or msg == "talentos" then
            if AR.TalentAdvisor and AR.TalentAdvisor.ToggleUI then
                AR.TalentAdvisor:ToggleUI()
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
        elseif msg == "minimap" then
            if AR.MinimapButton then AR.MinimapButton:Toggle() end
        elseif msg == "config" or msg == "opciones" or msg == "options" then
            if AR.Config then AR.Config:Open() end
        elseif msg == "macro" then
            if AR.TargetMacro then AR.TargetMacro:Update() end
            if _G.ShowMacroFrame and not (_G.InCombatLockdown and _G.InCombatLockdown()) then
                _G.ShowMacroFrame()
            end
        else
            AR:ToggleViewer()
        end
    end
end

function AR:ToggleViewer()
    if self.ViewerFrame and self.ViewerFrame.frame then
        if self.ViewerFrame.frame:IsShown() then
            self.ViewerFrame.frame:Hide()
        else
            self.ViewerFrame.frame:Show()
            self.ViewerFrame:RefreshVisuals()
        end
    end
end

function AR:Print(msg)
    local text = "|cfff4bf2aAzerothRoute|r: " .. tostring(msg)
    if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
        _G.DEFAULT_CHAT_FRAME:AddMessage(text)
    elseif _G.print then
        _G.print(text)
    end
end

-- The Blizzard popup never names the blocked call; report it in chat (once per function) so
-- in-game taint reports carry the evidence needed to fix them.
function AR:OnActionBlocked(event, addonName, funcName)
    if addonName ~= "AzerothRoute" then return end
    self.blockedReported = self.blockedReported or {}
    local key = tostring(funcName)
    if key:find("SetRaidTarget", 1, true) and self.ActionBar and not self.ActionBar.raidMarkBlocked then
        self.ActionBar.raidMarkBlocked = true
        if not (_G.InCombatLockdown and _G.InCombatLockdown()) then
            self.ActionBar:UpdateFromCurrentStep()
            if self.TargetMacro then self.TargetMacro:Update() end
        else
            self.ActionBar.pendingCombatUpdate = true
            if self.TargetMacro then self.TargetMacro.pending = true end
        end
    end
    if self.blockedReported[key] then return end
    self.blockedReported[key] = true
    local L = self.L
    local fmt = (L and L:Get("UI_ACTION_BLOCKED_FMT")) or "Blocked protected action (%s): %s"
    self:Print(string.format(fmt, tostring(event), key))
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
            local retarget = self.Progression:ConsumeWaypointVisited()
            if (advanced or retarget) and self.ViewerFrame then
                self.ViewerFrame:RefreshVisuals()
            end
        end
    end)

    -- WoW loads SavedVariables after every addon file has run, replacing the globals the first
    -- Storage:Initialize() bound to. Rebind here so settings and progress actually persist.
    self.Events:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName ~= "AzerothRoute" then return end
        self.Storage:Initialize()
        if self.MinimapButton then
            self.MinimapButton:Initialize()
        end
        if self.Config then
            self.Config:Initialize()
        end
    end)

    self.Events:RegisterEvent("ADDON_ACTION_BLOCKED", function(event, addonName, funcName)
        self:OnActionBlocked(event, addonName, funcName)
    end)
    self.Events:RegisterEvent("ADDON_ACTION_FORBIDDEN", function(event, addonName, funcName)
        self:OnActionBlocked(event, addonName, funcName)
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
        if self.Inventory and self.Inventory.RegisterLiveEvents then
            self.Inventory:RegisterLiveEvents()
        end
        if self.TaxiTracker and self.TaxiTracker.RegisterLiveEvents then
            self.TaxiTracker:RegisterLiveEvents()
            self.TaxiTracker:SeedRacialStarters()
        end
        if self.Trainers and self.Trainers.RegisterLiveEvents then
            self.Trainers:RegisterLiveEvents()
        end
        if self.QuestLoot and self.QuestLoot.RegisterLiveEvents then
            self.QuestLoot:RegisterLiveEvents()
        end
        if self.ActionBar then
            self.ActionBar:Initialize()
            self.ActionBar:RegisterLiveEvents()
        end
        if self.Pointer then
            self.Pointer:InitializeFrames()
        end
        if self.TalentAdvisor and self.TalentAdvisor.HookBlizzardFrames then
            self.TalentAdvisor:HookBlizzardFrames()
        end
        if self.PartySync then
            self.PartySync:RegisterLiveEvents()
        end
        if self.ViewerFrame then
            self.ViewerFrame:Initialize()
            if not self.Progression.currentGuide then
                if self.Progression:RestoreSaved() then
                    local guide = self.Progression.currentGuide
                    local es = self.L and self.L:IsSpanish()
                    local name = (es and guide.displayTitleES) or guide.displayTitleEN or guide.title
                    local fmt = (self.L and self.L:Get("UI_GUIDE_RESUMED_FMT")) or "Resumed guide: %s (step %d)"
                    self:Print(string.format(fmt, name, self.Progression.currentStep.num))
                elseif self.GuideMenu then
                    local suggested = self.GuideMenu:FindSuggestedGuides()
                    if suggested[1] then
                        self.Progression:LoadGuide(suggested[1])
                    end
                end
            end
            self.ViewerFrame:RefreshVisuals()
        end
    end)

    return true
end

AR:Initialize()

return AR
