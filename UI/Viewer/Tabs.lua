-- AzerothRoute: Draggable Guide Tabs Manager (Up to 30 Tabs) (SPEC-12)

local AR = _G.AzerothRoute
local Tabs = {
    MAX_TABS = 30,
}
AR.Tabs = Tabs

function Tabs:Reset()
    if AR.db and AR.db.char then
        AR.db.char.tabguides = {}
    end
end

function Tabs:GetTabs()
    if not AR.db or not AR.db.char then return {} end
    AR.db.char.tabguides = AR.db.char.tabguides or {}
    return AR.db.char.tabguides
end

function Tabs:AddTab(guideTitle)
    if not guideTitle or not AR.db or not AR.db.char then return false end
    local list = self:GetTabs()
    for _, existing in ipairs(list) do
        if existing == guideTitle then
            return true
        end
    end
    if #list >= self.MAX_TABS then
        table.remove(list, 1)
    end
    table.insert(list, guideTitle)
    return true
end

function Tabs:RemoveTab(guideTitle)
    local list = self:GetTabs()
    for i = #list, 1, -1 do
        if list[i] == guideTitle then
            table.remove(list, i)
            return true
        end
    end
    return false
end

return Tabs
