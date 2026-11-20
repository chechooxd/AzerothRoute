-- AzerothRoute: route recorder.
-- While recording, every quest accepted or handed in, every hearthstone bind and every flight
-- path learned becomes a guide line, grouped into steps by place: a new step (with a `goto` to
-- where the player stood) starts when the player has moved more than STEP_YARDS since the last
-- one. Stop and save turns it into an imported guide (Guides/Import.lua), so it is listed, kept
-- across sessions and can be shared as text.

local AR = _G.AzerothRoute
local Recorder = { STEP_YARDS = 40, recording = false, steps = {}, _registered = false, bar = nil }
AR.Recorder = Recorder

local function L(key, fallback)
    if AR.L then
        local v = AR.L:Get(key)
        if v and v ~= key then return v end
    end
    return fallback or key
end

function Recorder:Reset()
    self.recording, self.steps = false, {}
    if self.bar then self.bar:Hide() end
    self.bar = nil
end

function Recorder:Start()
    self.recording = true
    self:RefreshBar()
    return true
end

function Recorder:Pause()
    self.recording = false
    self:RefreshBar()
end

function Recorder:Discard()
    self.recording, self.steps = false, {}
    self:RefreshBar()
end

local function position()
    if not AR.Coords then return nil end
    local map, x, y = AR.Coords:GetPlayerPosition()
    if not map or not x then return nil end
    return map, x, y
end

-- The step for the player's current place: the last one when close enough, else a new one.
function Recorder:CurrentStep()
    local map, x, y = position()
    local last = self.steps[#self.steps]
    if last and map and last.map == map then
        local d = AR.Coords:GetDistanceBetween(last.map, last.x, last.y, map, x, y)
        if d and d <= self.STEP_YARDS then return last end
    elseif last and not map then
        return last
    end
    local step = { map = map, x = x, y = y, lines = {} }
    self.steps[#self.steps + 1] = step
    return step
end

-- Adds one guide line at the current place (ignored while not recording). Returns the line.
function Recorder:Add(line)
    if not self.recording or not line then return nil end
    local step = self:CurrentStep()
    for _, l in ipairs(step.lines) do if l == line then return nil end end
    table.insert(step.lines, line)
    self:RefreshBar()
    return line
end

local function questTitle(questID)
    local QT = AR.QuestTracking
    local e = QT and QT.questsById and QT.questsById[questID]
    local q = AR.DB and AR.DB.GetQuest and AR.DB:GetQuest(questID)
    return (e and e.title) or (q and q.name) or ("Quest " .. questID)
end

-- The NPC the player is talking to, as "Name##id" (or nil).
local function talkingTo()
    local name = _G.UnitName and _G.UnitName("npc")
    local id = AR.Trainers and _G.UnitGUID and AR.Trainers:NpcIdFromGUID(_G.UnitGUID("npc"))
    if not name then return nil end
    return id and (name .. "##" .. id) or name
end

function Recorder:OnQuestAccepted(questID)
    if not questID then return nil end
    local npc = talkingTo()
    if npc then self:Add("    talk " .. npc) end
    return self:Add(string.format("    accept %s##%d", questTitle(questID), questID))
end

function Recorder:OnQuestTurnedIn(questID)
    if not questID then return nil end
    return self:Add(string.format("    turnin %s##%d", questTitle(questID), questID))
end

function Recorder:OnHearthBound()
    local where = _G.GetBindLocation and _G.GetBindLocation()
    if not where or where == "" then return nil end
    return self:Add("    home " .. where)
end

-- Guide text in the addon's guide language (nil when nothing was recorded).
function Recorder:BuildText(name)
    local out = {}
    if name and name ~= "" then out[#out + 1] = "guide " .. name end
    local level = (_G.UnitLevel and _G.UnitLevel("player")) or 1
    out[#out + 1] = "type LEVELING"
    out[#out + 1] = "startlevel " .. level
    local n = 0
    for i, st in ipairs(self.steps) do
        if #st.lines > 0 then
            n = n + 1
            out[#out + 1] = "step Step" .. i
            if st.map then out[#out + 1] = string.format("    goto %d %.1f,%.1f", st.map, st.x * 100, st.y * 100) end
            for _, l in ipairs(st.lines) do out[#out + 1] = l end
        end
    end
    if n == 0 then return nil end
    return table.concat(out, "\n")
end

-- Saves the recording as an imported guide. Returns the guide or nil and an error key.
function Recorder:Save(name)
    local text = self:BuildText()
    if not text then return nil, "UI_REC_EMPTY" end
    local guide, err = AR.GuideImport:Import(text, name)
    if guide then self.steps, self.recording = {}, false end
    self:RefreshBar()
    return guide, err
end

function Recorder:LineCount()
    local n = 0
    for _, st in ipairs(self.steps) do n = n + #st.lines end
    return n
end

function Recorder:RegisterLiveEvents()
    if self._registered or not AR.Events then return end
    self._registered = true
    -- Classic passes (logIndex, questID); later clients pass (questID).
    AR.Events:RegisterEvent("QUEST_ACCEPTED", function(_, a, b) self:OnQuestAccepted(tonumber(b) or tonumber(a)) end)
    AR.Events:RegisterEvent("QUEST_TURNED_IN", function(_, questID) self:OnQuestTurnedIn(tonumber(questID)) end)
    AR.Events:RegisterEvent("HEARTHSTONE_BOUND", function() self:OnHearthBound() end)
end

-- Small floating bar: ● REC / paused, lines recorded, Record/Pause, Save, Discard.
function Recorder:InitializeBar()
    if self.bar then return self.bar end
    local S = AR.Skins
    local b = AR.UI:Create("Frame", _G.UIParent, "AzerothRouteRecorder")
    b:SetSize(380, 34)
    b:SetPoint("TOP", _G.UIParent, "TOP", 0, -60)
    if b.SetMovable then b:SetMovable(true) end
    if b.EnableMouse then b:EnableMouse(true) end
    if b.RegisterForDrag then b:RegisterForDrag("LeftButton") end
    b:SetScript("OnDragStart", function(f) if f.StartMoving then f:StartMoving() end end)
    b:SetScript("OnDragStop", function(f) if f.StopMovingOrSizing then f:StopMovingOrSizing() end end)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    S:Paint(b.bg, "panel", 0.97)
    S:AddBorder(b, "border")
    b.dot = b:CreateTexture(nil, "ARTWORK")
    b.dot:SetSize(10, 10)
    b.dot:SetPoint("LEFT", b, "LEFT", 12, 0)
    b.status = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.status:SetPoint("LEFT", b, "LEFT", 30, 0)
    local function btn(name, w, x)
        local x2 = AR.UI:Create("Button", b, name)
        x2:SetSize(w, 22)
        x2:SetPoint("RIGHT", b, "RIGHT", x, 0)
        x2.bg = x2:CreateTexture(nil, "BACKGROUND")
        x2.bg:SetAllPoints(x2)
        S:Paint(x2.bg, "panelRaised", 1)
        x2.label = x2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        x2.label:SetPoint("CENTER", x2, "CENTER", 0, 0)
        return x2
    end
    b.discard = btn("AzerothRouteRecorderDiscard", 70, -8)
    b.discard:SetScript("OnClick", function() self:Discard() end)
    b.save = btn("AzerothRouteRecorderSave", 70, -82)
    b.save:SetScript("OnClick", function()
        local name = string.format(L("UI_REC_NAME_FMT", "Recorded route %s"), (_G.date and _G.date("%Y-%m-%d %H:%M")) or "")
        local guide, err = self:Save(name)
        if AR.Print then AR:Print(guide and string.format(L("UI_IMPORT_DONE_FMT"), guide.displayTitleEN, #guide.steps) or L(err, err)) end
    end)
    b.toggle = btn("AzerothRouteRecorderToggle", 70, -156)
    b.toggle:SetScript("OnClick", function() if self.recording then self:Pause() else self:Start() end end)
    self.bar = b
    return b
end

function Recorder:RefreshBar()
    local b = self.bar
    if not b then return end
    if self.recording then b.dot:SetColorTexture(0.94, 0.30, 0.28, 1) else b.dot:SetColorTexture(0.55, 0.57, 0.62, 1) end
    b.status:SetText(string.format(L(self.recording and "UI_REC_ON_FMT" or "UI_REC_OFF_FMT", "%d lines"), self:LineCount()))
    b.toggle.label:SetText(L(self.recording and "UI_REC_PAUSE" or "UI_REC_START", self.recording and "Pause" or "Record"))
    b.save.label:SetText(L("UI_REC_SAVE", "Save"))
    b.discard.label:SetText(L("UI_REC_DISCARD", "Discard"))
end

function Recorder:ShowBar()
    local b = self:InitializeBar()
    self:RefreshBar()
    b:Show()
    return b
end

function Recorder:ToggleBar()
    local b = self:InitializeBar()
    if b:IsShown() then b:Hide() else self:ShowBar() end
end

return Recorder
