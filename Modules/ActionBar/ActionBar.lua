-- AzerothRoute: Pre-Allocated Secure ActionBar with Combat Lockdown Queue (SPEC-10)

local AR = _G.AzerothRoute
local ActionBar = {
    NUM_BUTTONS = 5,
    buttons = {},
    pendingCombatUpdate = false,
}
AR.ActionBar = ActionBar

function ActionBar:Initialize()
    self.buttons = {}
    self.pendingCombatUpdate = false
    for i = 1, self.NUM_BUTTONS do
        local btn = _G.CreateFrame("Button", "AzerothRouteAB" .. i, nil, "SecureActionButtonTemplate")
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
    elseif (goal.action == "talk" or goal.action == "kill") and goal.target then
        return string.format("/target %s\n/tm 8", goal.target)
    end
    return nil
end

function ActionBar:UpdateFromCurrentStep()
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        self.pendingCombatUpdate = true
        return false
    end
    self.pendingCombatUpdate = false

    local step = AR.Progression and AR.Progression.currentStep
    local macros = {}
    if step and step.goals then
        for _, g in ipairs(step.goals) do
            if g:GetStatus() ~= "complete" and g:GetStatus() ~= "hidden" then
                local m = self:BuildMacroForGoal(g)
                if m then
                    table.insert(macros, m)
                end
            end
        end
    end

    for i = 1, self.NUM_BUTTONS do
        local btn = self.buttons[i]
        if btn then
            if macros[i] then
                btn:SetAttribute("type1", "macro")
                btn:SetAttribute("macrotext1", macros[i])
                btn:Show()
            else
                btn:SetAttribute("macrotext1", nil)
                btn:Hide()
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

return ActionBar
