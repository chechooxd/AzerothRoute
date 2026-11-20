-- AzerothRoute: All-steps browser (Polestar-style step cards over the guide window).
-- Each visible step is a card: "N · heading", its goal lines with done ticks, "+N more".
-- The mouse wheel scrolls by step; clicking a card jumps the guide to that step.

local AR = _G.AzerothRoute
local StepBrowser = {
    WIDTH = 360,
    HEIGHT = 440,
    MAX_CARDS = 10,
    MAX_LINES = 6,
    LINE_H = 18,
    HEADER_H = 20,
    CARD_GAP = 6,
    offset = 1,
    frame = nil,
    cards = {},
}
AR.StepBrowser = StepBrowser

local function L(key, fallback)
    if AR.L then
        local v = AR.L:Get(key)
        if v and v ~= key then return v end
    end
    return fallback or key
end

function StepBrowser:Reset()
    if self.frame then self.frame:Hide() end
    self.frame = nil
    self.cards = {}
    self.offset = 1
end

-- Visible, non-sticky steps of the loaded guide, in order.
function StepBrowser:GetSteps()
    local guide = AR.Progression and AR.Progression.currentGuide
    local list = {}
    for _, st in ipairs((guide and guide.steps) or {}) do
        if not st.is_sticky and (not st.IsVisible or st:IsVisible()) then
            table.insert(list, st)
        end
    end
    return list
end

-- Card model for one step: header text and goal lines ({ text, done, icon }).
function StepBrowser:BuildCard(step)
    local VF = AR.ViewerFrame
    local heading = VF and VF.BuildHeading and VF:BuildHeading(step)
    local header = tostring(step.num)
    local where = (heading and (heading.sub or heading.plain)) or step.title or step.label
    if where then header = header .. " · " .. where end
    local lines, hidden = {}, 0
    for _, g in ipairs(step.goals or {}) do
        local status = g:GetStatus()
        if status ~= "hidden" then
            if #lines < self.MAX_LINES then
                local done = status == "complete"
                local text = g:GetText(done)
                table.insert(lines, {
                    text = (VF and VF.HighlightSubject) and VF:HighlightSubject(g, text, done) or text,
                    plain = text,
                    done = done,
                    icon = done and AR.Skins.CHECK_ICON or AR.Skins:GetActionIcon(g.action),
                })
            else
                hidden = hidden + 1
            end
        end
    end
    return { step = step, header = header, lines = lines, more = hidden }
end

local function createCard(self, parent, i)
    local S = AR.Skins
    local c = AR.UI:Create("Button", parent, "AzerothRouteStepCard" .. i)
    c:SetSize(self.WIDTH - 20, 40)
    if c.CreateTexture then
        c.bg = c:CreateTexture(nil, "BACKGROUND")
        c.bg:SetAllPoints(c)
        S:Paint(c.bg, "panelRaised", 0.85)
        c.accent = c:CreateTexture(nil, "ARTWORK")
        c.accent:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
        c.accent:SetWidth(2)
        S:Paint(c.accent, "accent")
        c.accent:Hide()
    end
    c.header = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.header:SetPoint("TOPLEFT", c, "TOPLEFT", 10, -5)
    c.header:SetJustifyH("LEFT")
    if c.header.SetTextColor then c.header:SetTextColor(S:RGBA("textMuted")) end
    c.lines, c.icons = {}, {}
    for l = 1, self.MAX_LINES + 1 do
        local fs = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetPoint("TOPLEFT", c, "TOPLEFT", 30, -(self.HEADER_H + (l - 1) * self.LINE_H))
        if fs.SetWidth then fs:SetWidth(self.WIDTH - 60) end
        if fs.SetWordWrap then fs:SetWordWrap(false) end
        fs:SetJustifyH("LEFT")
        c.lines[l] = fs
        if c.CreateTexture then
            local ic = c:CreateTexture(nil, "ARTWORK")
            ic:SetSize(13, 13)
            ic:SetPoint("TOPLEFT", c, "TOPLEFT", 11, -(self.HEADER_H + (l - 1) * self.LINE_H + 1))
            c.icons[l] = ic
        end
    end
    c:SetScript("OnEnter", function(b) S:Paint(b.bg, "hover", 1) end)
    c:SetScript("OnLeave", function(b) S:Paint(b.bg, "panelRaised", 0.85) end)
    c:SetScript("OnClick", function(b) if b._step then self:JumpTo(b._step.num) end end)
    c:Hide()
    return c
end

function StepBrowser:InitializeFrame()
    if self.frame then return self.frame end
    local S = AR.Skins
    local f = AR.UI:Create("Frame", _G.UIParent, "AzerothRouteStepBrowser")
    f:SetSize(self.WIDTH, self.HEIGHT)
    if f.SetFrameStrata then f:SetFrameStrata("HIGH") end
    if f.EnableMouse then f:EnableMouse(true) end
    if f.CreateTexture then
        f.bg = f:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAllPoints(f)
        S:Paint(f.bg, "panel", 0.98)
        S:AddBorder(f, "border")
    end
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
    if f.title.SetTextColor then f.title:SetTextColor(S:RGBA("text")) end
    f.pos = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.pos:SetPoint("TOPRIGHT", f, "TOPRIGHT", -34, -12)
    if f.pos.SetTextColor then f.pos:SetTextColor(S:RGBA("textMuted")) end

    local close = AR.UI:Create("Button", f, "AzerothRouteStepBrowserClose")
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -6)
    close.label = close:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    close.label:SetPoint("CENTER", close, "CENTER", 0, 0)
    close.label:SetText("×")
    close:SetScript("OnClick", function() f:Hide() end)
    self.closeButton = close

    if f.EnableMouseWheel then f:EnableMouseWheel(true) end
    f:SetScript("OnMouseWheel", function(_, delta) self:Scroll(-(delta or 0)) end)

    self.cards = {}
    for i = 1, self.MAX_CARDS do self.cards[i] = createCard(self, f, i) end
    f:Hide()
    self.frame = f
    return f
end

-- Lays the browser over the guide window (or centred when the window is missing).
function StepBrowser:Anchor()
    local f = self.frame
    if f.ClearAllPoints then f:ClearAllPoints() end
    local viewer = AR.ViewerFrame and AR.ViewerFrame.frame
    if viewer then
        f:SetPoint("TOPRIGHT", viewer, "TOPLEFT", -6, 0)
    else
        f:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
    end
end

function StepBrowser:Render()
    local f = self:InitializeFrame()
    local steps = self:GetSteps()
    self.offset = math.max(1, math.min(self.offset or 1, math.max(1, #steps)))
    f.title:SetText(L("UI_ALL_STEPS", "All steps"))
    local current = AR.Progression and AR.Progression.currentStep
    local y, used = 36, 0
    for idx = self.offset, #steps do
        if used >= self.MAX_CARDS then break end
        local model = self:BuildCard(steps[idx])
        local nLines = #model.lines + (model.more > 0 and 1 or 0)
        local h = self.HEADER_H + nLines * self.LINE_H + 6
        if y + h > self.HEIGHT - 8 and used > 0 then break end
        used = used + 1
        local c = self.cards[used]
        c._step = model.step
        c._model = model
        c:SetSize(self.WIDTH - 20, h)
        c:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -y)
        c.header:SetText(model.header)
        for l = 1, self.MAX_LINES + 1 do
            local fs, ic, line = c.lines[l], c.icons[l], model.lines[l]
            if line then
                fs:SetText(line.text)
                if fs.SetTextColor then fs:SetTextColor(AR.Skins:RGBA(line.done and "textDone" or "text")) end
                fs:Show()
                if ic then ic:SetTexture(line.icon); ic:Show() end
            elseif l == #model.lines + 1 and model.more > 0 then
                fs:SetText(string.format(L("UI_MORE_GOALS_FMT", "+%d more"), model.more))
                if fs.SetTextColor then fs:SetTextColor(AR.Skins:RGBA("textMuted")) end
                fs:Show()
                if ic then ic:Hide() end
            else
                fs:Hide()
                if ic then ic:Hide() end
            end
        end
        if c.accent then
            c.accent:SetHeight(h)
            if current and current == model.step then c.accent:Show() else c.accent:Hide() end
        end
        c:Show()
        y = y + h + self.CARD_GAP
    end
    for i = used + 1, self.MAX_CARDS do self.cards[i]:Hide() end
    f.pos:SetText(string.format("%d / %d", math.min(self.offset, #steps), #steps))
    self.visibleCount = used
    return used
end

function StepBrowser:Scroll(delta)
    self.offset = (self.offset or 1) + (delta or 0)
    return self:Render()
end

-- Index of `stepNum` among the visible steps, or 1.
function StepBrowser:IndexOf(stepNum)
    for i, st in ipairs(self:GetSteps()) do
        if st.num == stepNum then return i end
    end
    return 1
end

function StepBrowser:Show()
    local f = self:InitializeFrame()
    self:Anchor()
    local current = AR.Progression and AR.Progression.currentStep
    -- Start a couple of cards above the current step so recent context stays visible.
    self.offset = math.max(1, self:IndexOf(current and current.num or 1) - 2)
    self:Render()
    f:Show()
end

function StepBrowser:Toggle()
    local f = self:InitializeFrame()
    if f:IsShown() then f:Hide() else self:Show() end
end

-- Moves the guide to `stepNum`; a finished step is held (pause) so it is not skipped again at once.
function StepBrowser:JumpTo(stepNum)
    local P = AR.Progression
    if not P or not P.FocusStep then return nil end
    local step = P:FocusStep(stepNum, false)
    if step and step.IsComplete and step:IsComplete() then P.pause = true end
    if self.frame then self.frame:Hide() end
    if AR.ViewerFrame then AR.ViewerFrame:RefreshVisuals() end
    return step
end

return StepBrowser
