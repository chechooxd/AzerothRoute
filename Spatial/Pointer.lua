-- AzerothRoute: Pointer UI, Real Textured Directional Arrow, GamePad-Safe Map Pins, Corpse Arrow & Ant Trails (SPEC-05 / SPEC-17 / SPEC-18 / SPEC-20)
-- Invariant: Map and minimap pins are NEVER suppressed when GamePad / InputDeviceInterfaceStyle is active.

local AR = _G.AzerothRoute
local Pointer = {
    OBJECTIVE_PALETTE = {
        { hex = "#38bdf8", r = 0.22, g = 0.74, b = 0.97 }, -- Sky Blue
        { hex = "#facc15", r = 0.98, g = 0.80, b = 0.08 }, -- Amber Gold
        { hex = "#4ade80", r = 0.29, g = 0.87, b = 0.50 }, -- Emerald Green
        { hex = "#f472b6", r = 0.96, g = 0.45, b = 0.71 }, -- Pink
        { hex = "#a78bfa", r = 0.65, g = 0.55, b = 0.98 }, -- Violet
        { hex = "#fb923c", r = 0.98, g = 0.57, b = 0.24 }, -- Orange
    },
    ARROW_TEXTURE = "Interface\\Minimap\\Minimap-QuestArrow",
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
    self.arrowFrame = nil
    self.speedSamples = {}
end

function Pointer:InitializeFrames()
    if not self.arrowFrame then
        local af = _G.CreateFrame("Button", "AzerothRoutePointerArrow", _G.UIParent)
        af:SetSize(52, 52)
        af:SetPoint("TOP", _G.UIParent, "TOP", 0, -90)
        if af.SetMovable then af:SetMovable(true) end
        if af.EnableMouse then af:EnableMouse(true) end
        if af.RegisterForDrag then af:RegisterForDrag("LeftButton") end
        af:SetScript("OnDragStart", function(frame)
            if frame.StartMoving then frame:StartMoving() end
        end)
        af:SetScript("OnDragStop", function(frame)
            if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end
        end)

        if af.CreateTexture then
            -- Subtle dark circular backing plate so the arrow pops against any skybox
            af.ring = af:CreateTexture(nil, "BACKGROUND")
            af.ring:SetSize(44, 44)
            af.ring:SetPoint("CENTER", af, "CENTER", 0, 0)
            af.ring:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
            if af.ring.SetVertexColor then
                af.ring:SetVertexColor(0.05, 0.07, 0.12, 0.70)
            end

            -- Real WoW directional arrow texture (never SetColorTexture square!)
            af.icon = af:CreateTexture(nil, "ARTWORK")
            af.icon:SetSize(42, 42)
            af.icon:SetPoint("CENTER", af, "CENTER", 0, 0)
            af.icon:SetTexture(self.ARROW_TEXTURE)
            if af.icon.SetVertexColor then
                af.icon:SetVertexColor(0.15, 0.95, 0.35, 1.0)
            end
        end
        if af.CreateFontString then
            af.label = af:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            af.label:SetPoint("TOP", af, "BOTTOM", 0, -4)
            af.label:SetText("AzerothRoute Waypoint")

            af.sublabel = af:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            af.sublabel:SetPoint("TOP", af, "BOTTOM", 0, -18)
            af.sublabel:SetText("")
        end
        self.arrowFrame = af
    end
    return self.arrowFrame
end

function Pointer:GetObjectiveColorEntry(index)
    local idx = ((tonumber(index) or 1) - 1) % #self.OBJECTIVE_PALETTE + 1
    return self.OBJECTIVE_PALETTE[idx]
end

function Pointer:GetObjectiveColor(index)
    return self:GetObjectiveColorEntry(index).hex
end

function Pointer:PositionPinFrames(pin, wmPin, mmPin)
    local nx = (pin.x and pin.x > 1) and (pin.x / 100.0) or (pin.x or 0.5)
    local ny = (pin.y and pin.y > 1) and (pin.y / 100.0) or (pin.y or 0.5)

    local wmCanvas = (_G.WorldMapFrame and _G.WorldMapFrame.ScrollContainer) or _G.WorldMapFrame or _G.UIParent
    local cw, ch = 1002, 668
    if wmCanvas and wmCanvas.GetSize then
        local w, h = wmCanvas:GetSize()
        if w and w > 0 then cw = w end
        if h and h > 0 then ch = h end
    end
    wmPin:SetPoint("CENTER", wmCanvas, "TOPLEFT", nx * cw, -ny * ch)

    -- Minimap radar projection in world yards (clamped to minimap circle radius)
    local pMap, px, py = AR.Coords:GetPlayerPosition()
    local c1, wx1, wy1 = AR.Coords:ToWorldYards(pMap, px, py)
    local c2, wx2, wy2 = AR.Coords:ToWorldYards(pin.map or pMap, nx, ny)
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
    for _, f in ipairs(self.worldMapPinFrames or {}) do
        if f.Hide then f:Hide() end
    end
    for _, f in ipairs(self.minimapPinFrames or {}) do
        if f.Hide then f:Hide() end
    end

    self.worldMapPins = {}
    self.minimapPins = {}
    self.worldMapPinFrames = {}
    self.minimapPinFrames = {}
    if not pinSpecs then return end

    for i, spec in ipairs(pinSpecs) do
        local nx = (spec.x and spec.x > 1) and (spec.x / 100.0) or spec.x
        local ny = (spec.y and spec.y > 1) and (spec.y / 100.0) or spec.y
        local colorEntry = self:GetObjectiveColorEntry(spec.objectiveIndex or i)
        local color = spec.color or colorEntry.hex
        local pin = {
            map = spec.map,
            x = nx,
            y = ny,
            title = spec.title or "Waypoint",
            objectiveIndex = spec.objectiveIndex or i,
            color = color,
        }
        table.insert(self.worldMapPins, pin)
        table.insert(self.minimapPins, pin)

        local wmPin = _G.CreateFrame("Button", "AzerothRouteWorldMapPin" .. i, _G.WorldMapFrame or _G.UIParent)
        wmPin:SetSize(16, 16)
        if wmPin.CreateTexture then
            wmPin.tex = wmPin:CreateTexture(nil, "OVERLAY")
            wmPin.tex:SetAllPoints(wmPin)
            wmPin.tex:SetTexture("Interface\\Minimap\\POIIcons")
            if wmPin.tex.SetVertexColor then
                wmPin.tex:SetVertexColor(colorEntry.r, colorEntry.g, colorEntry.b, 1.0)
            end
        end

        local mmPin = _G.CreateFrame("Button", "AzerothRouteMinimapPin" .. i, _G.Minimap or _G.UIParent)
        mmPin:SetSize(12, 12)
        if mmPin.CreateTexture then
            mmPin.tex = mmPin:CreateTexture(nil, "OVERLAY")
            mmPin.tex:SetAllPoints(mmPin)
            mmPin.tex:SetTexture("Interface\\Minimap\\ObjectIcons")
            if mmPin.tex.SetVertexColor then
                mmPin.tex:SetVertexColor(colorEntry.r, colorEntry.g, colorEntry.b, 1.0)
            end
        end

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

function Pointer:ComputeBearingColor(relAngleRad)
    -- Normalize angle difference to [0, pi]
    local diff = math.abs(math.atan2(math.sin(relAngleRad or 0), math.cos(relAngleRad or 0)))
    local t = diff / math.pi -- 0 = dead ahead (green), 0.5 = 90 deg (yellow), 1.0 = behind (red)
    if t < 0.5 then
        local k = t * 2
        return 0.15 + 0.85 * k, 0.95, 0.25 * (1 - k)
    else
        local k = (t - 0.5) * 2
        return 1.0, 0.95 * (1 - k) + 0.15 * k, 0.15
    end
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
        if self.arrowFrame.icon then
            if self.arrowFrame.icon.SetRotation then
                self.arrowFrame.icon:SetRotation(self.arrowBearing)
            end
            if self.arrowFrame.icon.SetVertexColor then
                local r, g, b = self:ComputeBearingColor(self.arrowBearing)
                self.arrowFrame.icon:SetVertexColor(r, g, b, 1.0)
            end
        end
        if self.arrowFrame.label then
            local dist = AR.Coords:GetDistanceTo(self.activeTarget.map, self.activeTarget.x, self.activeTarget.y)
            if dist then
                self.arrowFrame.label:SetText(string.format("%s (%d yd)", self.activeTarget.title or "Waypoint", math.floor(dist + 0.5)))
            else
                self.arrowFrame.label:SetText(self.activeTarget.title or "Waypoint")
            end
        end
    end
end

return Pointer
