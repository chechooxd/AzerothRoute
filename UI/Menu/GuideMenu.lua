-- AzerothRoute: 825x630 GuideMenu Command Center, Suggested Guides & Global Search (SPEC-13 / SPEC-17)

local AR = _G.AzerothRoute
local GuideMenu = {
    WIDTH = 825,
    HEIGHT = 630,
    SECTIONS = { "Home", "Featured", "Current", "Recent", "Suggested", "Search", "Options" },
    activeSection = "Home",
    frame = nil,
}
AR.GuideMenu = GuideMenu

function GuideMenu:InitializeFrame()
    if self.frame then return self.frame end
    local f = AR.UI:Create("Frame", _G.UIParent, "AzerothRouteGuideMenu")
    f:SetSize(self.WIDTH, self.HEIGHT)
    f:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
    if f.CreateTexture then
        f.bg = f:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAllPoints(f)
        f.bg:SetColorTexture(0.06, 0.07, 0.10, 0.96)
    end
    if f.CreateFontString then
        f.header = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        f.header:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
        f.header:SetText("AzerothRoute — Guide Center")
    end
    f:Hide()
    self.frame = f
    return f
end

function GuideMenu:Toggle()
    local f = self:InitializeFrame()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
    end
end

function GuideMenu:FindSuggestedGuides()
    local suggested = {}
    for _, guide in pairs((AR.Parser and AR.Parser.guidesByTitle) or {}) do
        if guide.condition_suggested then
            local ok, res = pcall(guide.condition_suggested)
            if ok and res == true then
                table.insert(suggested, guide)
            end
        end
    end
    table.sort(suggested, function(a, b)
        return (a.startlevel or 0) < (b.startlevel or 0)
    end)
    return suggested
end

function GuideMenu:Search(query)
    if not query or query == "" then return {} end
    local results = {}
    local questIdStr = query:match("^quest:(%d+)$")
    local targetQuestID = questIdStr and tonumber(questIdStr) or nil
    local lowerQuery = query:lower()

    for _, guide in pairs((AR.Parser and AR.Parser.guidesByTitle) or {}) do
        local matched = false
        if targetQuestID then
            for _, step in ipairs(guide.steps or {}) do
                for _, goal in ipairs(step.goals or {}) do
                    if goal.questid == targetQuestID then
                        matched = true
                        break
                    end
                end
                if matched then break end
            end
        elseif guide.title and guide.title:lower():find(lowerQuery, 1, true) then
            matched = true
        end

        if matched then
            table.insert(results, guide)
        end
    end

    table.sort(results, function(a, b)
        return (a.title or "") < (b.title or "")
    end)
    return results
end

return GuideMenu
