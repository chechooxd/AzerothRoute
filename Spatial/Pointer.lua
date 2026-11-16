-- AzerothRoute: Pointer UI, On-Screen Directional Arrow, GamePad-Safe Map Pins, Corpse Arrow & Ant Trails (SPEC-05 / SPEC-17 / SPEC-18)
-- Invariant: Map and minimap pins are NEVER suppressed when GamePad / InputDeviceInterfaceStyle is active.

local AR = _G.AzerothRoute
local Pointer = {
    OBJECTIVE_PALETTE = {
        "#38bdf8", -- Sky Blue
        "#facc15", -- Amber Gold
        "#4ade80", -- Emerald Green
        "#f472b6", -- Pink
        "#a78bfa", -- Violet
        "#fb923c", -- Orange
    },
    MINIMAP_RADIUS_PX = 70,
    MINIMAP_VIEW_YARDS = 200,
    worldMapPins = {},
    minimapPins = {},
    worldMapPinFrames = {},
    minimapPinFrames = {},
    antPoints = {},
    activeTarget = nil,
    arrowBearing = 0,
    arrowFrame = nil,
    speedSamples = {},
}
AR.Pointer = Pointer

function Pointer:Reset()
    self.worldMapPins = {}
    self.minimapPins = {}
    self.worldMapPinFrames = {}
    self.minimapPinFrames = {}
    self.antPoints = {}
    self.activeTarget = nil
    self.arrowBearing = 0
    self.speedSamples = {}
end

function Pointer:InitializeFrames()
    if not self.arrowFrame then
        local af = _G.CreateFrame("Button", "AzerothRoutePointerArrow", _G.UIParent)
        af:SetSize(56, 56)
        af:SetPoint("TOP", _G.UIParent, "TOP", 0, -90)
        if af.CreateTexture then
            af.icon = af:CreateTexture(nil, "ARTWORK")
            af.icon:SetAllPoints(af)
            af.icon:SetColorTexture(0.22, 0.74, 0.97, 0.95)
        end
        if af.CreateFontString then
            af.label = af:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            af.label:SetPoint("TOP", af, "BOTTOM", 0, -4)
            af.label:SetText("AzerothRoute Waypoint")
        end
        self.arrowFrame = af
    end
    return self.arrowFrame
end

function Pointer:GetObjectiveColor(index)
    local idx = ((tonumber(index) or 1) - 1) % #self.OBJECTIVE_PALETTE + 1
    return self.OBJECTIVE_PALETTE[idx]
end

function Pointer:PositionPinFrames(pin, wmPin, mmPin)
    local wmCanvas = (_G.WorldMapFrame and _G.WorldMapFrame.ScrollContainer) or _G.WorldMapFrame or _G.UIParent
    local cw, ch = 1002, 668
    if wmCanvas and wmCanvas.GetSize then
        local w, h = wmCanvas:GetSize()
        if w and w > 0 then cw = w end
        if h and h > 0 then ch = h end
    end
    wmPin:SetPoint("CENTER", wmCanvas, "TOPLEFT", (pin.x or 0.5) * cw, -(pin.y or 0.5) * ch)

    -- Minimap radar projection in world yards (clamped to minimap circle radius)
    local pMap, px, py = AR.Coords:GetPlayerPosition()
    local c1, wx1, wy1 = AR.Coords:ToWorldYards(pMap, px, py)
    local c2, wx2, wy2 = AR.Coords:ToWorldYards(pin.map or pMap, pin.x or 0.5, pin.y or 0.5)
    local dxPx, dyPx = 0, 0
    if c1 and c2 and c1 == c2 then
        local dxYd = wx2 - wx1
        local dyYd = -(wy2 - wy1)
        local distYd = math.sqrt(dxYd * dxYd + dyYd * dyYd)
        local scale = self.MINIMAP_RADIUS_PX / self.MINIMAP_VIEW_YARDS
        dxPx = dxYd * scale
        dyPx = dyYd * scale
        if distYd > self.MINIMAP_VIEW_YARDS and distYd > 0 then
            dxPx = (dxYd / distYd) * self.MINIMAP_RADIUS_PX
            dyPx = (dyYd / distYd) * self.MINIMAP_RADIUS_PX
        end
    end
    mmPin:SetPoint("CENTER", _G.Minimap or _G.UIParent, "CENTER", dxPx, dyPx)
end

function Pointer:PlaceStepPins(pinSpecs)
    self.worldMapPins = {}
    self.minimapPins = {}
    self.worldMapPinFrames = {}
    self.minimapPinFrames = {}
    if not pinSpecs then return end

    for i, spec in ipairs(pinSpecs) do
        local color = spec.color or self:GetObjectiveColor(spec.objectiveIndex or i)
        local pin = {
            map = spec.map,
            x = spec.x,
            y = spec.y,
            title = spec.title or "Waypoint",
            objectiveIndex = spec.objectiveIndex or i,
            color = color,
        }
        table.insert(self.worldMapPins, pin)
        table.insert(self.minimapPins, pin)

        local wmPin = _G.CreateFrame("Button", "AzerothRouteWorldMapPin" .. i, _G.WorldMapFrame or _G.UIParent)
        wmPin:SetSize(14, 14)
        local mmPin = _G.CreateFrame("Button", "AzerothRouteMinimapPin" .. i, _G.Minimap or _G.UIParent)
        mmPin:SetSize(12, 12)

        self:PositionPinFrames(pin, wmPin, mmPin)
        wmPin:Show()
        mmPin:Show()

        table.insert(self.worldMapPinFrames, wmPin)
        table.insert(self.minimapPinFrames, mmPin)
    end

    if #self.worldMapPins > 0 then
        local first = self.worldMapPins[1]
        self.activeTarget = {
            type = "waypoint",
            map = first.map,
            x = first.x,
            y = first.y,
            title = first.title,
        }
    end
end

function Pointer:SpawnCurveAnts(p1, p2, count)
    self.antPoints = {}
    count = count or 5
    for i = 1, count do
        local t = i / (count + 1)
        table.insert(self.antPoints, {
            x = p1.x + (p2.x - p1.x) * t,
            y = p1.y + (p2.y - p1.y) * t,
            phase = t,
        })
    end
    return self.antPoints
end

function Pointer:CheckCorpseArrow()
    if AR.db and AR.db.global and AR.db.global.corpsearrow == false then
        return false
    end
    if _G.UnitIsDeadOrGhost and _G.UnitIsDeadOrGhost("player") then
        local pMap = AR.Coords:GetPlayerPosition()
        local corpsePos = _G.C_DeathInfo and _G.C_DeathInfo.GetCorpseMapPosition and _G.C_DeathInfo.GetCorpseMapPosition(pMap)
        if corpsePos and corpsePos.GetXY then
            local cx, cy = corpsePos:GetXY()
            if cx and cy then
                self.activeTarget = {
                    type = "corpse",
                    map = pMap,
                    x = cx,
                    y = cy,
                    title = "Retrieve Your Corpse",
                }
                return true
            end
        end
    end
    return false
end

function Pointer:UpdateArrow(elapsed)
    self:CheckCorpseArrow()
    if not self.activeTarget then
        if self.arrowFrame then self.arrowFrame:Hide() end
        return
    end
    if not self.arrowFrame then
        self:InitializeFrames()
    end
    local angle = AR.Coords:GetBearingTo(self.activeTarget.map, self.activeTarget.x, self.activeTarget.y)
    local facing = (_G.GetPlayerFacing and _G.GetPlayerFacing()) or 0
    self.arrowBearing = (angle or 0) - facing

    if self.arrowFrame then
        self.arrowFrame:Show()
        if self.arrowFrame.icon and self.arrowFrame.icon.SetRotation then
            self.arrowFrame.icon:SetRotation(self.arrowBearing)
        end
        if self.arrowFrame.label then
            local dist = AR.Coords:GetDistanceTo(self.activeTarget.map, self.activeTarget.x, self.activeTarget.y) or 0
            self.arrowFrame.label:SetText(string.format("%s (%d yd)", self.activeTarget.title or "Waypoint", math.floor(dist)))
        end
    end
end

return Pointer
