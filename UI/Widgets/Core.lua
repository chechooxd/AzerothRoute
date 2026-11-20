-- AzerothRoute: Low-Level Skinnable UI Widget Primitives (SPEC-12)

local AR = _G.AzerothRoute
local UI = {
    createdWidgets = {},
}
AR.UI = UI

function UI:Create(widgetType, parent, name, template)
    local frameType = (widgetType == "Button" or widgetType == "ActionButton" or widgetType == "ToggleButton") and "Button" or "Frame"
    local f = _G.CreateFrame(frameType, name, parent, template)
    f._widgetType = widgetType
    table.insert(self.createdWidgets, f)
    return f
end

function UI:Gradient3(t, c1, c2, c3)
    t = math.max(0, math.min(1, tonumber(t) or 0))
    if t < 0.5 then
        local k = t * 2
        return {
            r = c1.r + (c2.r - c1.r) * k,
            g = c1.g + (c2.g - c1.g) * k,
            b = c1.b + (c2.b - c1.b) * k,
        }
    else
        local k = (t - 0.5) * 2
        return {
            r = c2.r + (c3.r - c2.r) * k,
            g = c2.g + (c3.g - c2.g) * k,
            b = c2.b + (c3.b - c2.b) * k,
        }
    end
end

-- Popup menu in the addon's look: navy panel, gold check marks, thin separators.
-- items: { { text = "...", checked = bool|nil, onClick = fn, separator = bool, disabled = bool } }
UI.MENU_ITEM_H = 24
UI.MENU_WIDTH = 220

local function hideMenu(self)
    if self.menu then self.menu:Hide() end
    if self.menuCatcher then self.menuCatcher:Hide() end
end

function UI:HideMenu()
    hideMenu(self)
end

function UI:EnsureMenu()
    if self.menu then return self.menu end
    local S = AR.Skins
    -- Full-screen click catcher closes the menu when clicking elsewhere.
    local catcher = _G.CreateFrame("Button", "AzerothRouteMenuCatcher", _G.UIParent)
    if catcher.SetAllPoints then catcher:SetAllPoints(_G.UIParent) end
    if catcher.SetFrameStrata then catcher:SetFrameStrata("DIALOG") end
    if catcher.RegisterForClicks then catcher:RegisterForClicks("AnyUp") end
    catcher:SetScript("OnClick", function() hideMenu(self) end)
    catcher:Hide()
    self.menuCatcher = catcher

    local m = _G.CreateFrame("Frame", "AzerothRouteMenu", _G.UIParent)
    m:SetSize(self.MENU_WIDTH, 40)
    if m.SetFrameStrata then m:SetFrameStrata("FULLSCREEN_DIALOG") end
    if m.EnableMouse then m:EnableMouse(true) end
    if m.SetClampedToScreen then m:SetClampedToScreen(true) end
    if m.CreateTexture then
        m.bg = m:CreateTexture(nil, "BACKGROUND")
        m.bg:SetAllPoints(m)
        S:Paint(m.bg, "panelRaised", 0.98)
        S:AddBorder(m, "border")
    end
    m.buttons, m.separators = {}, {}
    m:Hide()
    self.menu = m
    return m
end

local function menuButton(self, m, i)
    local S = AR.Skins
    local b = m.buttons[i]
    if b then return b end
    b = _G.CreateFrame("Button", "AzerothRouteMenuItem" .. i, m)
    b:SetSize(self.MENU_WIDTH - 2, self.MENU_ITEM_H)
    if b.CreateTexture then
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints(b)
        b.bg:SetColorTexture(0, 0, 0, 0)
        b.check = b:CreateTexture(nil, "ARTWORK")
        b.check:SetSize(14, 14)
        b.check:SetPoint("RIGHT", b, "RIGHT", -10, 0)
        b.check:SetTexture(S.CHECKBOX_CHECK_ICON)
        if b.check.SetVertexColor then b.check:SetVertexColor(S:RGBA("accent")) end
        b.check:Hide()
    end
    if b.CreateFontString then
        b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.label:SetPoint("LEFT", b, "LEFT", 14, 0)
        b.label:SetJustifyH("LEFT")
    end
    b:SetScript("OnEnter", function(btn) if not btn._disabled then S:Paint(btn.bg, "hover", 1) end end)
    b:SetScript("OnLeave", function(btn) btn.bg:SetColorTexture(0, 0, 0, 0) end)
    b:SetScript("OnClick", function(btn)
        if btn._disabled then return end
        hideMenu(self)
        if btn._onClick then btn._onClick() end
    end)
    m.buttons[i] = b
    return b
end

-- Opens the menu under `anchor` (or at `point` on it). Returns the menu frame.
function UI:ShowMenu(anchor, items, point, relPoint, x, y)
    local S = AR.Skins
    local m = self:EnsureMenu()
    local yOff, bi, si = 4, 0, 0
    for _, item in ipairs(items or {}) do
        if item.separator then
            si = si + 1
            local sep = m.separators[si]
            if not sep and m.CreateTexture then
                sep = m:CreateTexture(nil, "ARTWORK")
                sep:SetSize(self.MENU_WIDTH - 24, 1)
                S:Paint(sep, "divider")
                m.separators[si] = sep
            end
            if sep then
                sep:SetPoint("TOPLEFT", m, "TOPLEFT", 12, -(yOff + 4))
                sep:Show()
            end
            yOff = yOff + 9
        else
            bi = bi + 1
            local b = menuButton(self, m, bi)
            b:SetPoint("TOPLEFT", m, "TOPLEFT", 1, -yOff)
            b._onClick = item.onClick
            b._disabled = item.disabled == true
            b._item = item
            b.label:SetText(item.text or "")
            if b.label.SetTextColor then
                b.label:SetTextColor(S:RGBA(item.disabled and "textDone" or "text"))
            end
            if item.checked then b.check:Show() else b.check:Hide() end
            b:Show()
            yOff = yOff + self.MENU_ITEM_H
        end
    end
    for i = bi + 1, #m.buttons do m.buttons[i]:Hide() end
    for i = si + 1, #m.separators do m.separators[i]:Hide() end
    m:SetSize(self.MENU_WIDTH, yOff + 4)
    if m.ClearAllPoints then m:ClearAllPoints() end
    if anchor then
        m:SetPoint(point or "TOPRIGHT", anchor, relPoint or "BOTTOMRIGHT", x or 0, y or -2)
    else
        m:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
    end
    if self.menuCatcher then self.menuCatcher:Show() end
    m:Show()
    return m
end

-- The shown item whose label equals `text` (for tests and keyboard shortcuts).
function UI:FindMenuItem(text)
    if not self.menu then return nil end
    for _, b in ipairs(self.menu.buttons) do
        if b:IsShown() and b.label:GetText() == text then return b end
    end
    return nil
end

return UI
