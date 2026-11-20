-- AzerothRoute: "Report a problem".
-- The player writes what went wrong; the report puts that first, then everything a fix needs,
-- taken when the window opens: the guide and the step on screen with every goal's state, ids and
-- position, the arrow, where the player stands, versions, other loaded addons, settings changed
-- from their defaults and the AzerothRoute errors caught this session. The text is selected in a
-- box so Ctrl+C copies it to share with the addon's author. Nothing is sent anywhere.

local AR = _G.AzerothRoute
local Report = { WIDTH = 560, HEIGHT = 470, MAX_ERRORS = 20, errors = {}, frame = nil }
AR.Report = Report

local function L(key, fallback)
    if AR.L then
        local v = AR.L:Get(key)
        if v and v ~= key then return v end
    end
    return fallback or key
end

function Report:Reset()
    if self.frame then self.frame:Hide() end
    self.frame, self.lastText = nil, nil
end

-- Keeps every Lua error of the session (chaining the game's handler, which still shows them):
-- the message, how many times it happened, and the first lines of its stack, so an error raised
-- inside Blizzard code by one of our calls still shows which AzerothRoute file led there.
function Report:Record(msg, stack)
    local text = tostring(msg)
    for _, e in ipairs(self.errors) do
        if type(e) == "table" and e.msg == text then
            e.count = e.count + 1
            return e
        end
    end
    local lines = {}
    for line in tostring(stack or ""):gmatch("[^\n]+") do
        if #lines < 6 then lines[#lines + 1] = line end
    end
    local e = { msg = text, count = 1, stack = lines, ours = text:find("AzerothRoute", 1, true) ~= nil
        or tostring(stack or ""):find("AzerothRoute", 1, true) ~= nil }
    table.insert(self.errors, e)
    while #self.errors > self.MAX_ERRORS do table.remove(self.errors, 1) end
    return e
end

function Report:CaptureErrors()
    if self._capturing or not _G.geterrorhandler or not _G.seterrorhandler then return false end
    self._capturing = true
    local previous = _G.geterrorhandler()
    _G.seterrorhandler(function(msg, ...)
        pcall(function()
            self:Record(msg, _G.debugstack and _G.debugstack(3, 8, 0) or nil)
        end)
        if previous then return previous(msg, ...) end
    end)
    return true
end

local function addonVersion()
    local get = (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    return get and get("AzerothRoute", "Version") or "?"
end

local function loadedAddons()
    local A = _G.C_AddOns
    local num = (A and A.GetNumAddOns and A.GetNumAddOns()) or (_G.GetNumAddOns and _G.GetNumAddOns()) or 0
    local info = (A and A.GetAddOnInfo) or _G.GetAddOnInfo
    local loaded = (A and A.IsAddOnLoaded) or _G.IsAddOnLoaded
    local out = {}
    for i = 1, num do
        local name = info and info(i)
        if name and name ~= "AzerothRoute" and (not loaded or loaded(i)) then out[#out + 1] = name end
    end
    table.sort(out)
    return out
end

-- Settings different from their defaults ("key=value").
local function changedSettings()
    local out, defaults = {}, (AR.Storage and AR.Storage.ProfileDefaults) or {}
    local p = (AR.db and AR.db.profile) or {}
    for k, def in pairs(defaults) do
        if p[k] ~= nil and p[k] ~= def then out[#out + 1] = k .. "=" .. tostring(p[k]) end
    end
    for _, k in ipairs({ "accent", "scheme", "bgalpha", "viewerscale" }) do
        if p[k] ~= nil then out[#out + 1] = k .. "=" .. tostring(p[k]) end
    end
    table.sort(out)
    return out
end

local function fmtPos(map, x, y)
    if not map or not x then return "?" end
    if x <= 1 and y and y <= 1 then x, y = x * 100, y * 100 end
    return string.format("%s %.1f,%.1f", tostring(map), x, y or 0)
end

-- The report text for `what` (the player's own words).
function Report:Build(what)
    local lines = {}
    local function add(s) lines[#lines + 1] = s end
    add("AzerothRoute report")
    add("What happened: " .. ((what and what ~= "") and what or "(not described)"))
    add("")
    local version, build = addonVersion(), "?"
    if _G.GetBuildInfo then
        local v, b = _G.GetBuildInfo()
        build = tostring(v) .. " (" .. tostring(b) .. ")"
    end
    add(string.format("Addon %s · client %s · locale %s", tostring(version), build, (_G.GetLocale and _G.GetLocale()) or "?"))
    local class = _G.UnitClass and select(2, _G.UnitClass("player")) or "?"
    add(string.format("Character: level %s %s %s", tostring((_G.UnitLevel and _G.UnitLevel("player")) or "?"),
        tostring((_G.UnitFactionGroup and _G.UnitFactionGroup("player")) or "?"), tostring(class)))
    local map, x, y
    if AR.Coords then map, x, y = AR.Coords:GetPlayerPosition() end
    add("Position: " .. fmtPos(map, x, y))

    local P = AR.Progression
    local guide, step = P and P.currentGuide, P and P.currentStep
    if guide then
        add(string.format("Guide: %s · step %d/%d%s", tostring(guide.title), step and step.num or 0, #(guide.steps or {}),
            (P.pause and " · paused") or ""))
        for i, g in ipairs((step and step.goals) or {}) do
            local ok, status = pcall(g.GetStatus, g)
            local ids = {}
            if g.questid then ids[#ids + 1] = "q" .. g.questid end
            if g.npcid then ids[#ids + 1] = "npc" .. g.npcid end
            if g.targetid then ids[#ids + 1] = "id" .. g.targetid end
            add(string.format("  %d. %s %s [%s]%s%s", i, tostring(g.action), tostring(g.target or g.quest or g.param or ""),
                ok and tostring(status) or "error", #ids > 0 and (" " .. table.concat(ids, ",")) or "",
                g.map and (" @ " .. fmtPos(g.map, g.x, g.y)) or ""))
        end
    else
        add("Guide: none loaded")
    end
    local t = AR.Pointer and AR.Pointer.activeTarget
    add("Arrow: " .. (t and string.format("%s %s (%s)", tostring(t.title or "?"), fmtPos(t.map, t.x, t.y), tostring(t.type or "waypoint")) or "none"))
    local settings = changedSettings()
    add("Settings changed: " .. (#settings > 0 and table.concat(settings, ", ") or "none"))
    local addons = loadedAddons()
    add("Other addons: " .. (#addons > 0 and table.concat(addons, ", ") or "none"))
    if #self.errors > 0 then
        add("Errors this session:")
        for _, e in ipairs(self.errors) do
            if type(e) == "string" then e = { msg = e, count = 1, stack = {} } end
            add(string.format("  [x%d]%s %s", e.count, e.ours and " (AzerothRoute)" or "", (e.msg:gsub("\n", " | "))))
            for _, s in ipairs(e.stack or {}) do add("      " .. s) end
        end
    else
        add("Errors this session: none")
    end
    return table.concat(lines, "\n")
end

local function editBox(parent, name)
    local e = _G.CreateFrame("EditBox", name, parent)
    if e.SetAutoFocus then e:SetAutoFocus(false) end
    if e.SetMultiLine then e:SetMultiLine(true) end
    if e.SetFontObject then e:SetFontObject("GameFontHighlightSmall") end
    if e.SetTextInsets then e:SetTextInsets(8, 8, 4, 4) end
    if e.SetMaxLetters then e:SetMaxLetters(0) end
    e:SetScript("OnEscapePressed", function(b) if b.ClearFocus then b:ClearFocus() end end)
    return e
end

function Report:InitializeFrame()
    if self.frame then return self.frame end
    local S = AR.Skins
    local W, H = self.WIDTH, self.HEIGHT
    local f = AR.UI:Create("Frame", _G.UIParent, "AzerothRouteReport")
    f:SetSize(W, H)
    f:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 20)
    if f.SetFrameStrata then f:SetFrameStrata("DIALOG") end
    if f.EnableMouse then f:EnableMouse(true) end
    if f.SetMovable then f:SetMovable(true) end
    if f.RegisterForDrag then f:RegisterForDrag("LeftButton") end
    f:SetScript("OnDragStart", function(frame) if frame.StartMoving then frame:StartMoving() end end)
    f:SetScript("OnDragStop", function(frame) if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end end)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints(f)
    S:Paint(f.bg, "panel", 0.98)
    f.band = f:CreateTexture(nil, "BACKGROUND")
    f.band:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.band:SetSize(W - 2, 48)
    S:Paint(f.band, "panelRaised", 1)
    S:AddBorder(f, "border")
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -15)
    if f.title.SetTextColor then f.title:SetTextColor(S:RGBA("text")) end
    f.help = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.help:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -60)
    if f.help.SetWidth then f.help:SetWidth(W - 40) end
    f.help:SetJustifyH("LEFT")
    if f.help.SetTextColor then f.help:SetTextColor(S:RGBA("textMuted")) end

    f.whatBg = f:CreateTexture(nil, "BACKGROUND")
    f.whatBg:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -82)
    f.whatBg:SetSize(W - 40, 70)
    S:Paint(f.whatBg, "panelRaised", 1)
    self.whatBox = editBox(f, "AzerothRouteReportWhat")
    self.whatBox:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -82)
    self.whatBox:SetSize(W - 40, 70)

    f.reportBg = f:CreateTexture(nil, "BACKGROUND")
    f.reportBg:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -164)
    f.reportBg:SetSize(W - 40, H - 224)
    S:Paint(f.reportBg, "panelRaised", 1)
    local scroll = _G.CreateFrame("ScrollFrame", "AzerothRouteReportScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -168)
    scroll:SetSize(W - 70, H - 232)
    self.reportBox = editBox(scroll, "AzerothRouteReportText")
    self.reportBox:SetSize(W - 70, H - 232)
    if scroll.SetScrollChild then scroll:SetScrollChild(self.reportBox) end

    local function button(name, width, primary)
        local b = AR.UI:Create("Button", f, name)
        b:SetSize(width, 30)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints(b)
        if primary then S:Paint(b.bg, "accent", 1) else S:Paint(b.bg, "panelRaised", 1); S:AddBorder(b, "border") end
        b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
        if b.label.SetTextColor then
            if primary then b.label:SetTextColor(0.10, 0.09, 0.07, 1) else b.label:SetTextColor(S:RGBA("text")) end
        end
        return b
    end
    self.buildButton = button("AzerothRouteReportBuild", 200, true)
    self.buildButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 14)
    self.buildButton:SetScript("OnClick", function()
        self:Fill(self.whatBox.GetText and self.whatBox:GetText() or "")
    end)
    self.closeButton = button("AzerothRouteReportClose", 100, false)
    self.closeButton:SetPoint("RIGHT", self.buildButton, "LEFT", -8, 0)
    self.closeButton:SetScript("OnClick", function() f:Hide() end)
    f:Hide()
    self.frame = f
    return f
end

-- Builds the report into the copy box and selects it for Ctrl+C. Returns the text.
function Report:Fill(what)
    local text = self:Build(what)
    if self.reportBox then
        if self.reportBox.SetText then self.reportBox:SetText(text) end
        if self.reportBox.HighlightText then self.reportBox:HighlightText() end
        if self.reportBox.SetFocus then self.reportBox:SetFocus() end
    end
    self.lastText = text
    return text
end

function Report:Show()
    local f = self:InitializeFrame()
    f.title:SetText(L("UI_REPORT_TITLE", "Report a problem"))
    f.help:SetText(L("UI_REPORT_HELP"))
    self.buildButton.label:SetText(L("UI_REPORT_BUILD", "Make the report"))
    self.closeButton.label:SetText(L("UI_IMPORT_CANCEL", "Close"))
    self:Fill("")
    f:Show()
    return f
end

-- Capture from load time, so errors during login are in the report too.
Report:CaptureErrors()

return Report
