-- AzerothRoute: "Make room in your quest log" dialog.
-- Lists quests in the log that the loaded route never hands in from the current step on.
-- Abandon only selects the quest and opens the game's own ABANDON_QUEST confirmation;
-- the player still confirms (or cancels) in Blizzard's window.

local AR = _G.AzerothRoute
local QuestLogCleanup = {
    WIDTH = 420,
    MAX_ROWS = 10,
    ROW_H = 40,
    frame = nil,
    rows = {},
}
AR.QuestLogCleanup = QuestLogCleanup

local function L(key, fallback)
    if AR.L then
        local v = AR.L:Get(key)
        if v and v ~= key then return v end
    end
    return fallback or key
end

function QuestLogCleanup:Reset()
    if self.frame then self.frame:Hide() end
    self.frame = nil
    self.rows = {}
end

-- Quest IDs the loaded guide still turns in, from the current step onwards (stickies included).
function QuestLogCleanup:GetRouteTurnins()
    local P = AR.Progression
    local guide = P and P.currentGuide
    if not guide then return nil end
    local from = (P.currentStep and P.currentStep.num) or 1
    local set = {}
    for _, st in ipairs(guide.steps or {}) do
        if st.is_sticky or (st.num or 0) >= from then
            for _, g in ipairs(st.goals or {}) do
                if g.action == "turnin" and g.questid then set[g.questid] = true end
            end
        end
    end
    return set
end

-- Quests in the log the route does not need, sorted by title. Empty when no guide is loaded.
function QuestLogCleanup:GetCandidates()
    local turnins = self:GetRouteTurnins()
    local list = {}
    if not turnins then return list end
    local QT = AR.QuestTracking
    for qid, entry in pairs((QT and QT.questsById) or {}) do
        if not turnins[qid] then
            table.insert(list, { id = qid, title = entry.title or ("Quest " .. qid), logIndex = entry.logIndex })
        end
    end
    table.sort(list, function(a, b) return a.title < b.title end)
    return list
end

-- Opens the game's abandon confirmation for `quest`; returns true when it was offered.
function QuestLogCleanup:Abandon(quest)
    if not quest then return false end
    local name = quest.title
    if _G.C_QuestLog and _G.C_QuestLog.SetSelectedQuest and _G.C_QuestLog.SetAbandonQuest then
        _G.C_QuestLog.SetSelectedQuest(quest.id)
        _G.C_QuestLog.SetAbandonQuest()
    elseif _G.SelectQuestLogEntry and _G.SetAbandonQuest then
        local idx = quest.logIndex or (_G.GetQuestLogIndexByID and _G.GetQuestLogIndexByID(quest.id))
        if not idx or idx == 0 then return false end
        _G.SelectQuestLogEntry(idx)
        _G.SetAbandonQuest()
        if _G.GetAbandonQuestName then name = _G.GetAbandonQuestName() or name end
    else
        return false
    end
    if _G.StaticPopup_Show then _G.StaticPopup_Show("ABANDON_QUEST", name) end
    return true
end

local function createRow(self, f, i)
    local S = AR.Skins
    local row = AR.UI:Create("Frame", f, "AzerothRouteQuestCleanupRow" .. i)
    row:SetSize(self.WIDTH - 40, self.ROW_H)
    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -4)
    row.title:SetJustifyH("LEFT")
    if row.title.SetTextColor then row.title:SetTextColor(S:RGBA("text")) end
    row.reason = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.reason:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -22)
    row.reason:SetJustifyH("LEFT")
    if row.reason.SetTextColor then row.reason:SetTextColor(S:RGBA("textMuted")) end

    local b = AR.UI:Create("Button", row, "AzerothRouteQuestCleanupAbandon" .. i)
    b:SetSize(90, 22)
    b:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.label:SetPoint("RIGHT", b, "RIGHT", 0, 0)
    if b.label.SetTextColor then b.label:SetTextColor(0.94, 0.45, 0.42, 1) end
    b:SetScript("OnEnter", function(btn) if btn.label.SetTextColor then btn.label:SetTextColor(1, 0.62, 0.58, 1) end end)
    b:SetScript("OnLeave", function(btn) if btn.label.SetTextColor then btn.label:SetTextColor(0.94, 0.45, 0.42, 1) end end)
    b:SetScript("OnClick", function() self:Abandon(row._quest) end)
    row.abandon = b
    row:Hide()
    return row
end

function QuestLogCleanup:InitializeFrame()
    if self.frame then return self.frame end
    local S = AR.Skins
    local f = AR.UI:Create("Frame", _G.UIParent, "AzerothRouteQuestCleanup")
    f:SetSize(self.WIDTH, 200)
    f:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 60)
    if f.SetFrameStrata then f:SetFrameStrata("DIALOG") end
    if f.EnableMouse then f:EnableMouse(true) end
    if f.SetMovable then f:SetMovable(true) end
    if f.RegisterForDrag then f:RegisterForDrag("LeftButton") end
    f:SetScript("OnDragStart", function(frame) if frame.StartMoving then frame:StartMoving() end end)
    f:SetScript("OnDragStop", function(frame) if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end end)
    if f.CreateTexture then
        f.bg = f:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAllPoints(f)
        S:Paint(f.bg, "panel", 0.98)
        f.band = f:CreateTexture(nil, "BACKGROUND")
        f.band:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        f.band:SetSize(self.WIDTH - 2, 46)
        S:Paint(f.band, "panelRaised", 1)
        S:AddBorder(f, "border")
    end
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -15)
    if f.title.SetTextColor then f.title:SetTextColor(S:RGBA("text")) end
    f.desc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.desc:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -58)
    if f.desc.SetWidth then f.desc:SetWidth(self.WIDTH - 40) end
    f.desc:SetJustifyH("LEFT")
    if f.desc.SetTextColor then f.desc:SetTextColor(S:RGBA("textMuted")) end

    local close = AR.UI:Create("Button", f, "AzerothRouteQuestCleanupClose")
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -12)
    close.label = close:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    close.label:SetPoint("CENTER", close, "CENTER", 0, 0)
    close.label:SetText("×")
    close:SetScript("OnClick", function() f:Hide() end)
    self.closeButton = close

    self.rows = {}
    for i = 1, self.MAX_ROWS do self.rows[i] = createRow(self, f, i) end
    f:Hide()
    self.frame = f
    return f
end

function QuestLogCleanup:Render()
    local f = self:InitializeFrame()
    f.title:SetText(L("UI_QL_TITLE", "Make room in your quest log"))
    local list = self:GetCandidates()
    f.desc:SetText(#list > 0 and L("UI_QL_DESC") or L("UI_QL_EMPTY"))
    local y = 96
    for i, row in ipairs(self.rows) do
        local q = list[i]
        if q then
            row._quest = q
            row.title:SetText(q.title)
            row.reason:SetText(L("UI_QL_REASON", "Not handed in on this route"))
            row.abandon.label:SetText(L("UI_QL_ABANDON", "Abandon"))
            row:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -y)
            row:Show()
            y = y + self.ROW_H + 4
        else
            row._quest = nil
            row:Hide()
        end
    end
    f:SetSize(self.WIDTH, y + 16)
    self.candidates = list
    return list
end

function QuestLogCleanup:Show()
    local QT = AR.QuestTracking
    if QT and QT.ScanQuestLog then pcall(QT.ScanQuestLog, QT) end
    self:Render()
    self.frame:Show()
end

function QuestLogCleanup:Toggle()
    local f = self:InitializeFrame()
    if f:IsShown() then f:Hide() else self:Show() end
end

return QuestLogCleanup
