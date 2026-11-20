-- AzerothRoute: upgrade line in item tooltips.
-- Gear the player could wear gets one line under the tooltip: "AzerothRoute: upgrade +12%"
-- (score against the item it would replace, by the class weights in ItemScore), or nothing.

local AR = _G.AzerothRoute
local GearTooltip = { _hooked = false }
AR.GearTooltip = GearTooltip

-- The line for `link`, or nil when it is not an upgrade (or not gear).
function GearTooltip:LineFor(link)
    if not link or not AR.Upgrades or not AR.ItemScore then return nil end
    local eval = AR.Upgrades:EvaluateCandidate(link)
    if not eval or not eval.isUpgrade then return nil end
    local L = AR.L
    if not eval.oldScore or eval.oldScore <= 0 then
        return (L and L:Get("UI_TIP_UPGRADE_EMPTY")) or "AzerothRoute: upgrade (empty slot)"
    end
    local pct = math.floor((eval.newScore / eval.oldScore - 1) * 100 + 0.5)
    return string.format((L and L:Get("UI_TIP_UPGRADE_FMT")) or "AzerothRoute: upgrade +%d%%", pct)
end

function GearTooltip:OnTooltipSetItem(tooltip)
    if not tooltip or not tooltip.GetItem then return nil end
    local _, link = tooltip:GetItem()
    local line = self:LineFor(link)
    if line and tooltip.AddLine then
        tooltip:AddLine(line, 0.40, 0.82, 0.48)
        if tooltip.Show then tooltip:Show() end
    end
    return line
end

function GearTooltip:Hook()
    if self._hooked then return end
    for _, name in ipairs({ "GameTooltip", "ItemRefTooltip" }) do
        local tip = _G[name]
        if tip and tip.HookScript and tip.GetItem then
            tip:HookScript("OnTooltipSetItem", function(t) self:OnTooltipSetItem(t) end)
            self._hooked = true
        end
    end
end

return GearTooltip
