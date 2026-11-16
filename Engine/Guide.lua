-- AzerothRoute: Guide Model (SPEC-03)

local AR = _G.AzerothRoute
local Guide = AR:Class("Guide")
AR.Guide = Guide

function Guide:GetStep(num)
    return self.steps and self.steps[num] or nil
end

function Guide:GetStepByLabel(label)
    return self.stepsByLabel and self.stepsByLabel[label] or nil
end

function Guide:GetStickiesForStep(currentStepNum)
    local out = {}
    if not self.steps then return out end
    for _, step in ipairs(self.steps) do
        if step.is_sticky and step.num ~= currentStepNum then
            if step:IsVisible() and step:CanBeSticky() and not step:IsComplete() then
                table.insert(out, step)
            end
        end
    end
    return out
end

function Guide:GetCompletionFraction()
    if not self.steps or #self.steps == 0 then return 0, 0, 0 end
    local done = 0
    local total = 0
    for _, step in ipairs(self.steps) do
        if not step.is_sticky and step:IsVisible() then
            total = total + 1
            if step:IsComplete() then
                done = done + 1
            end
        end
    end
    if total == 0 then return 1, 0, 0 end
    return done / total, done, total
end

return Guide
