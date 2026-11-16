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

return UI
