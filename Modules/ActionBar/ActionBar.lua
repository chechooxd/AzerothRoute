-- AzerothRoute: Pre-Allocated Secure ActionBar with Combat Lockdown Queue (SPEC-10 / SPEC-16)

local AR = _G.AzerothRoute
local ActionBar = {
    NUM_BUTTONS = 5,
    buttons = {},
    pendingCombatUpdate = false,
}
AR.ActionBar = ActionBar

local targetActions = { talk = true, vendor = true, trainer = true, kill = true, from = true }

local function inCombat()
    return _G.InCombatLockdown and _G.InCombatLockdown()
end

local function safeName(name)
    if _G.issecretvalue and _G.issecretvalue(name) then return nil end
    if type(name) ~= "string" or name == "" or name:find("[%c%[%];]") then return nil end
    return name
end

function ActionBar:GetTargetName(goal)
    local name = goal.target
    if targetActions[goal.action] and AR.Localizers then
        name = AR.Localizers:GetTranslatedNPC(goal.npcid or goal.targetid, name)
    end
    return safeName(name)
end

function ActionBar:Initialize()
    if inCombat() then
        self.pendingCombatUpdate = true
        return self.buttons
    end
    if #self.buttons == self.NUM_BUTTONS then return self.buttons end
    for i = 1, self.NUM_BUTTONS do
        local btn = _G.CreateFrame("Button", "AzerothRouteAB" .. i, _G.UIParent, "SecureActionButtonTemplate")
        btn:SetSize(170, 36)
        if i == 1 then
            btn:SetPoint("RIGHT", _G.UIParent, "RIGHT", -30, 100)
        else
            btn:SetPoint("TOP", self.buttons[i - 1], "BOTTOM", 0, -4)
        end
        btn:RegisterForClicks("AnyUp", "AnyDown")
        btn.background = btn:CreateTexture(nil, "BACKGROUND")
        btn.background:SetAllPoints(btn)
        btn.background:SetColorTexture(0.08, 0.08, 0.08, 0.9)
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetSize(30, 30)
        btn.icon:SetPoint("LEFT", btn, "LEFT", 3, 0)
        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.label:SetPoint("LEFT", btn, "LEFT", 38, 0)
        btn.label:SetWidth(128)
        btn.label:SetJustifyH("LEFT")
        btn:SetScript("OnEnter", function(button)
            if _G.GameTooltip and button.actionLabel then
                _G.GameTooltip:SetOwner(button, "ANCHOR_LEFT")
                _G.GameTooltip:SetText(button.actionLabel)
                _G.GameTooltip:AddLine(AR.L:Get("UI_TARGET_CLICK_HINT"), 1, 1, 1, true)
                _G.GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function()
            if _G.GameTooltip then _G.GameTooltip:Hide() end
        end)
        btn:Hide()
        table.insert(self.buttons, btn)
    end
    return self.buttons
end

function ActionBar:BuildMacroForGoal(goal)
    if not goal then return nil end
    if goal.action == "use" and goal.target then
        return "/use " .. goal.target
    elseif goal.action == "cast" and goal.target then
        return "/cast " .. goal.target
    elseif goal.action == "equip" and goal.target then
        return "/equip " .. goal.target
    elseif targetActions[goal.action] then
        local name = self:GetTargetName(goal)
        if not name then return nil end
        local enemy = goal.action == "kill" or goal.action == "from"
        -- Clear the previous target before searching: a failed lookup must not mark it.
        return "/cleartarget\n/targetexact " .. name
            .. (enemy and "\n/cleartarget [dead]\n/tm 8" or "\n/tm 1")
    end
    return nil
end

function ActionBar:UpdateFromCurrentStep()
    if inCombat() then
        self.pendingCombatUpdate = true
        return false
    end
    self.pendingCombatUpdate = false
    self:Initialize()

    local step = AR.Progression and AR.Progression.currentStep
    local actions, seen = {}, {}
    if step and step.goals then
        for _, g in ipairs(step.goals) do
            local status = g:GetStatus()
            if status ~= "complete" and status ~= "hidden" and status ~= "obsolete" then
                local m = self:BuildMacroForGoal(g)
                if m and not seen[m] then
                    seen[m] = true
                    local targeting = targetActions[g.action]
                    local name = targeting and self:GetTargetName(g) or g.target
                    local enemy = g.action == "kill" or g.action == "from"
                    table.insert(actions, {
                        macro = m,
                        label = targeting and AR.L:Format("UI_TARGET_NAME", name) or name,
                        icon = targeting and (enemy and "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
                            or "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
                            or "Interface\\Icons\\INV_Misc_QuestionMark",
                    })
                    if #actions == self.NUM_BUTTONS then break end
                end
            end
        end
    end

    for i = 1, self.NUM_BUTTONS do
        local btn = self.buttons[i]
        if btn then
            local action = actions[i]
            local macro = action and action.macro or nil
            if btn:GetAttribute("macrotext1") ~= macro then
                btn:SetAttribute("type", "macro")
                btn:SetAttribute("macrotext1", macro)
            end
            if action then
                if btn.actionLabel ~= action.label then
                    btn.actionLabel = action.label
                    btn.label:SetText(action.label)
                end
                btn.icon:SetTexture(action.icon)
                if not btn:IsShown() then btn:Show() end
            else
                btn.actionLabel = nil
                if btn:IsShown() then btn:Hide() end
            end
        end
    end
    return true
end

function ActionBar:OnCombatEnd()
    if self.pendingCombatUpdate then
        self:UpdateFromCurrentStep()
    end
end

local function parseUnitNpcID(unit)
    local guid = _G.UnitGUID and _G.UnitGUID(unit)
    if type(guid) ~= "string" then return nil end
    return tonumber(guid:match("Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
        or tonumber(guid:match("%-(%d+)%-[^%-]+$"))
end

function ActionBar:MarkMatchingUnit(unit)
    if not unit then return false end
    if AR.db and AR.db.global and AR.db.global.automark == false then return false end
    if _G.IsInGroup and _G.IsInGroup() then
        local canMark = (_G.UnitIsGroupLeader and _G.UnitIsGroupLeader("player"))
            or (_G.UnitIsGroupAssistant and _G.UnitIsGroupAssistant("player"))
        if not canMark then return false end
    end
    if _G.UnitIsDead and _G.UnitIsDead(unit) then return false end
    if _G.GetRaidTargetIndex and _G.GetRaidTargetIndex(unit) then return false end

    local unitName = _G.UnitName and _G.UnitName(unit)
    if type(unitName) ~= "string" or unitName == "" or unitName == "Unknown" then return false end
    local unitNpcID = parseUnitNpcID(unit)

    local goals = {}
    if AR.Progression and AR.Progression.currentStep then
        for _, g in ipairs(AR.Progression.currentStep.goals or {}) do
            table.insert(goals, g)
        end
        for _, sticky in ipairs(AR.Progression:GetActiveStickies() or {}) do
            for _, g in ipairs(sticky.goals or {}) do
                table.insert(goals, g)
            end
        end
    end

    local lowerUnit = unitName:lower()
    for _, g in ipairs(goals) do
        local status = g:GetStatus()
        if status ~= "complete" and status ~= "hidden" and targetActions[g.action] then
            local goalNpcID = g.npcid or g.targetid
            local targetName = self:GetTargetName(g)
            local rawName = safeName(g.target)
            local matched = (goalNpcID and unitNpcID and goalNpcID == unitNpcID)
                or (targetName and lowerUnit == targetName:lower())
                or (rawName and lowerUnit == rawName:lower())
            if matched then
                if _G.SetRaidTarget then
                    local enemy = g.action == "kill" or g.action == "from"
                    _G.SetRaidTarget(unit, enemy and 8 or 1)
                end
                return true
            end
        end
    end
    return false
end

function ActionBar:RegisterLiveEvents()
    if not AR.Events then return end
    -- Events:Reset replaces the handler tables in the headless harness.
    if self._eventHandlers == AR.Events.eventHandlers then return end
    self._eventHandlers = AR.Events.eventHandlers
    AR.Events:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        self:OnCombatEnd()
    end)
    AR.Events:RegisterEvent("PLAYER_TARGET_CHANGED", function()
        self:MarkMatchingUnit("target")
    end)
    AR.Events:RegisterEvent("UPDATE_MOUSEOVER_UNIT", function()
        self:MarkMatchingUnit("mouseover")
    end)
    AR.Events:RegisterMessage("AR_STEP_CHANGED", function()
        self:UpdateFromCurrentStep()
    end)
    -- Goal status and NPC cache changes can occur without a step transition.
    -- Polling avoids reentrant updates when name resolution broadcasts a message.
    AR.Events:SubscribeUpdate("actionbar_refresh", 0.2, function()
        self:UpdateFromCurrentStep()
    end)
end

return ActionBar
