-- AzerothRoute: shared layout for the Guide Center's extra modes (Lookup, Dungeons).
-- A panel draws over the guide list: its own sidebar categories with counts, a paged result list,
-- and a details pane (title, chips, key/value lines, a clickable list and up to two buttons).
-- The owning module supplies the data:
--   module:GetCategories()          -> { { id = ..., label = ... } }
--   module:CountCategory(id)        -> number
--   module:GetRows(id)              -> { { text = rich text, tag = right text, data = any } }
--   module:Describe(row)            -> { title, subtitle, chips = { {text, accent} }, info = { {key, value} },
--                                        list = { {text, onClick} }, primary = {text, onClick}, secondary = {...} }
--   module:HeaderTitle(), module:HeaderSub(total)

local AR = _G.AzerothRoute
local MenuPanel = {}
MenuPanel.__index = MenuPanel
AR.MenuPanel = MenuPanel

local ROWS, ROW_H = 14, 26
local LIST_ROWS = 8
local INFO_ROWS = 7

function MenuPanel:New(module)
    return setmetatable({ module = module, category = nil, page = 0, rows = {}, cats = {} }, MenuPanel)
end

local function flatButton(parent, name, width, height)
    local S = AR.Skins
    local b = AR.UI:Create("Button", parent, name)
    b:SetSize(width, height)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetColorTexture(0, 0, 0, 0)
    b.accent = b:CreateTexture(nil, "ARTWORK")
    b.accent:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.accent:SetSize(2, height)
    S:Paint(b.accent, "accent")
    b.accent:Hide()
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.label:SetPoint("LEFT", b, "LEFT", 12, 0)
    b.label:SetJustifyH("LEFT")
    if b.label.SetWordWrap then b.label:SetWordWrap(false) end
    b.tag = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.tag:SetPoint("RIGHT", b, "RIGHT", -10, 0)
    b.tag:SetJustifyH("RIGHT")
    if b.tag.SetTextColor then b.tag:SetTextColor(S:RGBA("textMuted")) end
    b:SetScript("OnEnter", function(btn) if not btn._selected then S:Paint(btn.bg, "hover") end end)
    b:SetScript("OnLeave", function(btn) if not btn._selected then btn.bg:SetColorTexture(0, 0, 0, 0) end end)
    return b
end

local function setSelected(btn, on)
    local S = AR.Skins
    btn._selected = on
    if on then S:Paint(btn.bg, "selected") else btn.bg:SetColorTexture(0, 0, 0, 0) end
    if on then btn.accent:Show() else btn.accent:Hide() end
end

local function actionButton(parent, name, primary)
    local S = AR.Skins
    local b = AR.UI:Create("Button", parent, name)
    b:SetSize(210, 30)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    if primary then S:Paint(b.bg, "accent", 1) else S:Paint(b.bg, "panelRaised"); S:AddBorder(b, "border") end
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
    if b.label.SetTextColor then
        if primary then b.label:SetTextColor(0.10, 0.09, 0.07, 1) else b.label:SetTextColor(S:RGBA("text")) end
    end
    b:SetScript("OnClick", function(btn) if btn._onClick then btn._onClick() end end)
    b:Hide()
    return b
end

-- Builds the overlays inside the Guide Center frame `f` (720 x 480).
function MenuPanel:Attach(f, prefix)
    if self.side then return end
    local S = AR.Skins
    local W, H = f:GetWidth() or 720, f:GetHeight() or 480
    local level = (f.GetFrameLevel and f:GetFrameLevel() or 1) + 20

    local side = AR.UI:Create("Frame", f, prefix .. "Side")
    side:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -82)
    side:SetSize(151, H - 83)
    if side.SetFrameLevel then side:SetFrameLevel(level) end
    if side.EnableMouse then side:EnableMouse(true) end
    side.bg = side:CreateTexture(nil, "BACKGROUND")
    side.bg:SetAllPoints(side)
    S:Paint(side.bg, "panelRaised", 1)

    local main = AR.UI:Create("Frame", f, prefix .. "Main")
    main:SetPoint("TOPLEFT", f, "TOPLEFT", 153, -46)
    main:SetSize(W - 154, H - 47)
    if main.SetFrameLevel then main:SetFrameLevel(level) end
    if main.EnableMouse then main:EnableMouse(true) end
    main.bg = main:CreateTexture(nil, "BACKGROUND")
    main.bg:SetAllPoints(main)
    S:Paint(main.bg, "panel", 1)
    main.rule = main:CreateTexture(nil, "ARTWORK")
    main.rule:SetPoint("TOPLEFT", main, "TOPLEFT", 315, 0)
    main.rule:SetSize(1, H - 47)
    S:Paint(main.rule, "divider")
    main.rightBg = main:CreateTexture(nil, "BACKGROUND")
    main.rightBg:SetPoint("TOPLEFT", main, "TOPLEFT", 316, 0)
    main.rightBg:SetSize(W - 154 - 316, H - 47)
    S:Paint(main.rightBg, "panelRaised", 0.6)

    -- Sidebar categories (built on first render, the module may change them).
    self.cats = {}
    for i = 1, 10 do
        local b = flatButton(side, prefix .. "Cat" .. i, 151, 28)
        b:SetPoint("TOPLEFT", side, "TOPLEFT", 0, -4 - (i - 1) * 30)
        b:SetScript("OnClick", function(btn) self:SelectCategory(btn._id) end)
        b:Hide()
        self.cats[i] = b
    end

    -- Result list.
    self.rows = {}
    for i = 1, ROWS do
        local b = flatButton(main, prefix .. "Row" .. i, 300, 24)
        b:SetPoint("TOPLEFT", main, "TOPLEFT", 4, -6 - (i - 1) * ROW_H)
        if b.label.SetWidth then b.label:SetWidth(180) end
        b:SetScript("OnClick", function(btn) self:SelectRow(btn._row) end)
        b:Hide()
        self.rows[i] = b
    end
    main.pageText = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    main.pageText:SetPoint("BOTTOM", main, "BOTTOMLEFT", 158, 12)
    if main.pageText.SetTextColor then main.pageText:SetTextColor(S:RGBA("textMuted")) end
    self.prevButton = flatButton(main, prefix .. "Prev", 40, 22)
    self.prevButton:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 10, 6)
    self.prevButton.label:SetText("<")
    self.prevButton:SetScript("OnClick", function() self:Page(-1) end)
    self.nextButton = flatButton(main, prefix .. "Next", 40, 22)
    self.nextButton:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 265, 6)
    self.nextButton.label:SetText(">")
    self.nextButton:SetScript("OnClick", function() self:Page(1) end)

    -- Details pane.
    local dx = 332
    -- Zone painting behind the details title (Dungeons, Rares, Lookup places).
    if AR.ZoneArt then
        self.art = AR.ZoneArt:Create(main, W - 154 - 317, 50, prefix .. "Art")
        self.art:SetPoint("TOPLEFT", main, "TOPLEFT", 317, 0)
    end
    main.title = main:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    main.title:SetPoint("TOPLEFT", main, "TOPLEFT", dx, -14)
    if main.title.SetWidth then main.title:SetWidth(220) end
    if main.title.SetWordWrap then main.title:SetWordWrap(false) end
    main.title:SetJustifyH("LEFT")
    if main.title.SetTextColor then main.title:SetTextColor(S:RGBA("text")) end
    main.subtitle = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if AR.ZoneArt then
        AR.ZoneArt:Lift(self.art, main.title)
        AR.ZoneArt:Lift(self.art, main.subtitle)
    end
    main.subtitle:SetPoint("TOPLEFT", main, "TOPLEFT", dx, -36)
    if main.subtitle.SetTextColor then main.subtitle:SetTextColor(S:RGBA("textMuted")) end
    self.chips = {}
    for i = 1, 3 do
        local c = AR.UI:Create("Frame", main, prefix .. "Chip" .. i)
        c:SetSize(60, 18)
        c.bg = c:CreateTexture(nil, "BACKGROUND")
        c.bg:SetAllPoints(c)
        c.label = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        c.label:SetPoint("CENTER", c, "CENTER", 0, 0)
        c:Hide()
        self.chips[i] = c
    end
    self.info = {}
    for i = 1, INFO_ROWS do
        local y = -84 - (i - 1) * 18
        local k = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        k:SetPoint("TOPLEFT", main, "TOPLEFT", dx, y)
        if k.SetTextColor then k:SetTextColor(S:RGBA("textMuted")) end
        local v = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        v:SetPoint("TOPLEFT", main, "TOPLEFT", dx + 70, y)
        if v.SetWidth then v:SetWidth(150) end
        if v.SetWordWrap then v:SetWordWrap(false) end
        v:SetJustifyH("LEFT")
        if v.SetTextColor then v:SetTextColor(S:RGBA("text")) end
        self.info[i] = { key = k, value = v }
    end
    self.list = {}
    for i = 1, LIST_ROWS do
        local b = flatButton(main, prefix .. "List" .. i, 230, 20)
        b:SetPoint("TOPLEFT", main, "TOPLEFT", dx - 8, -84 - INFO_ROWS * 18 - 8 - (i - 1) * 20)
        if b.label.SetFontObject then b.label:SetFontObject("GameFontHighlightSmall") end
        if b.label.SetWidth then b.label:SetWidth(170) end
        b:SetScript("OnClick", function(btn) if btn._onClick then btn._onClick() end end)
        b:HookScript("OnEnter", function(btn)
            if btn._tooltip and _G.GameTooltip and _G.GameTooltip.SetOwner then
                _G.GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                _G.GameTooltip:SetText(btn.label:GetText() or "")
                _G.GameTooltip:AddLine(btn._tooltip, 1, 1, 1, true)
                _G.GameTooltip:Show()
            end
        end)
        b:HookScript("OnLeave", function() if _G.GameTooltip and _G.GameTooltip.Hide then _G.GameTooltip:Hide() end end)
        b:Hide()
        self.list[i] = b
    end
    self.primary = actionButton(main, prefix .. "Primary", true)
    self.primary:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", dx, 50)
    self.secondary = actionButton(main, prefix .. "Secondary", false)
    self.secondary:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", dx, 12)

    side:Hide()
    main:Hide()
    self.side, self.main = side, main
end

function MenuPanel:IsShown()
    return self.main ~= nil and self.main:IsShown()
end

function MenuPanel:SetShown(shown)
    if not self.side then return end
    if shown then
        self.side:Show()
        self.main:Show()
        self:Render()
    else
        self.side:Hide()
        self.main:Hide()
    end
end

function MenuPanel:SelectCategory(id)
    self.category = id
    self.page = 0
    self:Render()
end

function MenuPanel:Page(delta)
    local total = #(self.lastRows or {})
    local maxPage = math.max(0, math.ceil(total / ROWS) - 1)
    local nextPage = math.max(0, math.min(maxPage, self.page + delta))
    if nextPage ~= self.page then
        self.page = nextPage
        self:Render()
    end
end

function MenuPanel:Render()
    if not self.side then return end
    local m = self.module
    local cats = m:GetCategories()
    if not self.category or not (function()
        for _, c in ipairs(cats) do if c.id == self.category then return true end end
    end)() then
        self.category = cats[1] and cats[1].id
    end
    for i, b in ipairs(self.cats) do
        local c = cats[i]
        if c then
            b._id = c.id
            b.label:SetText(c.label)
            b.tag:SetText(tostring(m:CountCategory(c.id)))
            setSelected(b, c.id == self.category)
            b:Show()
        else
            b:Hide()
        end
    end

    local rows = m:GetRows(self.category) or {}
    self.lastRows = rows
    -- Optional module hook: open a category on a given row (Talents opens on the next pick).
    if m.FocusRow and self._focused ~= self.category then
        self._focused = self.category
        local idx = m:FocusRow(rows)
        if idx and rows[idx] then
            self.page = math.floor((idx - 1) / ROWS)
            self.selected = rows[idx]
        end
    end
    local maxPage = math.max(0, math.ceil(#rows / ROWS) - 1)
    self.page = math.max(0, math.min(self.page, maxPage))
    for i, b in ipairs(self.rows) do
        local r = rows[self.page * ROWS + i]
        b._row = r
        if r then
            b.label:SetText(r.text)
            b.tag:SetText(r.tag or "")
            setSelected(b, r == self.selected)
            b:Show()
        else
            b:Hide()
        end
    end
    self.main.pageText:SetText(string.format("%d / %d", self.page + 1, maxPage + 1))

    local menu = AR.GuideMenu
    if menu and menu.headerText then menu.headerText:SetText(m:HeaderTitle()) end
    if menu and menu.headerSub then menu.headerSub:SetText(m:HeaderSub(#rows)) end

    local keep = false
    for _, r in ipairs(rows) do if r == self.selected then keep = true break end end
    if not keep then self.selected = rows[1] end
    self:RenderDetails()
end

function MenuPanel:SelectRow(row)
    self.selected = row
    for _, b in ipairs(self.rows) do setSelected(b, b._row ~= nil and b._row == row) end
    self:RenderDetails()
end

function MenuPanel:RenderDetails()
    local S = AR.Skins
    local main = self.main
    local d = (self.selected and self.module:Describe(self.selected)) or {}
    self.details = d
    main.title:SetText(d.title or "")
    if self.art and AR.ZoneArt then AR.ZoneArt:Paint(self.art, d.art, d.artFocus) end
    main.subtitle:SetText(d.subtitle or "")
    local x = 332
    for i, c in ipairs(self.chips) do
        local chip = d.chips and d.chips[i]
        if chip then
            c.label:SetText(chip.text)
            if c.label.SetTextColor then c.label:SetTextColor(S:RGBA(chip.accent and "accent" or "text")) end
            local w = math.floor(((c.label.GetStringWidth and c.label:GetStringWidth()) or #chip.text * 6) + 16)
            c:SetSize(w, 18)
            c:SetPoint("TOPLEFT", main, "TOPLEFT", x, -56)
            S:Paint(c.bg, chip.accent and "whileHere" or "selected", 1)
            c:Show()
            x = x + w + 6
        else
            c:Hide()
        end
    end
    for i, row in ipairs(self.info) do
        local kv = d.info and d.info[i]
        row.key:SetText(kv and kv[1] or "")
        row.value:SetText(kv and kv[2] or "")
    end
    for i, b in ipairs(self.list) do
        local item = d.list and d.list[i]
        if item then
            b.label:SetText(item.text)
            b.tag:SetText(item.tag or "")
            b._onClick = item.onClick
            b._tooltip = item.tooltip
            b:Show()
        else
            b._onClick = nil
            b:Hide()
        end
    end
    for _, pair in ipairs({ { self.primary, d.primary }, { self.secondary, d.secondary } }) do
        local btn, spec = pair[1], pair[2]
        if spec then
            btn.label:SetText(spec.text)
            btn._onClick = spec.onClick
            btn:Show()
        else
            btn._onClick = nil
            btn:Hide()
        end
    end
end

return MenuPanel
