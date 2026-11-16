-- AzerothRoute: Skin & Style Registry (SPEC-12)

local AR = _G.AzerothRoute
local Skins = {
    styles = {
        default = {
            bg = { r = 0.08, g = 0.09, b = 0.12, a = 0.94 },
            goalIncomplete = { r = 0.45, g = 0.12, b = 0.12 },
            goalProgressing = { r = 0.48, g = 0.38, b = 0.10 },
            goalComplete = { r = 0.12, g = 0.42, b = 0.20 },
            goalImpossible = { r = 0.25, g = 0.25, b = 0.28 },
            goalWarning = { r = 0.55, g = 0.28, b = 0.08 },
            goalPassive = { r = 0.16, g = 0.20, b = 0.28 },
            stickySeparator = { r = 0.35, g = 0.38, b = 0.45, height = 1 },
            progressBarHeight = 7,
        },
        starlight = {
            bg = { r = 0.04, g = 0.05, b = 0.08, a = 0.96 },
            goalIncomplete = { r = 0.40, g = 0.10, b = 0.15 },
            goalProgressing = { r = 0.45, g = 0.35, b = 0.12 },
            goalComplete = { r = 0.10, g = 0.40, b = 0.22 },
            goalImpossible = { r = 0.22, g = 0.22, b = 0.25 },
            goalWarning = { r = 0.52, g = 0.25, b = 0.08 },
            goalPassive = { r = 0.14, g = 0.17, b = 0.24 },
            stickySeparator = { r = 0.30, g = 0.35, b = 0.42, height = 1 },
            progressBarHeight = 7,
        },
    },
}
AR.Skins = Skins

function Skins:GetProp(key)
    local styleName = (AR.db and AR.db.global and AR.db.global.style) or "default"
    local style = self.styles[styleName] or self.styles.default
    return style[key]
end

return Skins
