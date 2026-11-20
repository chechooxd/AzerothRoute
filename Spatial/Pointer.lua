-- AzerothRoute: Pointer UI, Real Textured Directional Arrow, WorldMap Canvas Pins & Ant Trails (SPEC-05 / SPEC-17 / SPEC-18 / SPEC-20 / SPEC-21)
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
    ARROW_SIZE = 56,
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
    worldMapHooked = false,
    speedSamples = {},
}
AR.Pointer = Pointer

function Pointer:Reset()
    self:ClearLibraryPins()
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
    self.worldMapPinPool = {}
    self.minimapPinPool = {}
    self.antPoints = {}
    self.activeTarget = nil
    self.arrowBearing = 0
    self.arrowFrame = nil
    self.arrowState = nil
    self.manualTarget = nil
    self.worldMapHooked = false
    self.speedSamples = {}
    self.speedSampleTimer = 0
end

function Pointer:GetWorldMapCanvas()
    if _G.WorldMapFrame then
        if _G.WorldMapFrame.GetCanvas then
            local c = _G.WorldMapFrame:GetCanvas()
            if c then return c end
        end
        if _G.WorldMapFrame.ScrollContainer and _G.WorldMapFrame.ScrollContainer.Child then
            return _G.WorldMapFrame.ScrollContainer.Child
        end
        if _G.WorldMapFrame.ScrollContainer then
            return _G.WorldMapFrame.ScrollContainer
        end
        return _G.WorldMapFrame
    end
    return _G.UIParent
end

function Pointer:EnsureWorldMapHook()
    if self.worldMapHooked or not _G.WorldMapFrame then return end
    if _G.WorldMapFrame.HookScript then
        _G.WorldMapFrame:HookScript("OnShow", function()
            self:RefreshWorldMapPins()
        end)
    end
    self.worldMapHooked = true
end

function Pointer:InitializeFrames()
    self:EnsureWorldMapHook()
    if not self.arrowFrame then
        local af = _G.CreateFrame("Button", "AzerothRoutePointerArrow", _G.UIParent)
        af:SetSize(self.ARROW_SIZE, self.ARROW_SIZE)
        af:SetPoint("TOP", _G.UIParent, "TOP", 0, -90)
        if af.SetFrameStrata then af:SetFrameStrata("HIGH") end
        if af.SetMovable then af:SetMovable(true) end
        if af.EnableMouse then af:EnableMouse(true) end
        if af.RegisterForDrag then af:RegisterForDrag("LeftButton") end
        af:SetScript("OnDragStart", function(frame)
            if frame.StartMoving then frame:StartMoving() end
        end)
        af:SetScript("OnDragStop", function(frame)
            if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end
        end)

        -- Free-floating arrow (no backdrop) with a soft drop shadow, then three centred lines:
        -- distance (large, coloured by closeness), destination, and ETA (muted).
        if af.CreateTexture then
            af.shadow = af:CreateTexture(nil, "BACKGROUND")
            af.shadow:SetSize(self.ARROW_SIZE, self.ARROW_SIZE)
            af.shadow:SetPoint("CENTER", af, "CENTER", 1, -3)
            af.shadow:SetTexture(self.ARROW_TEXTURE)
            if af.shadow.SetVertexColor then af.shadow:SetVertexColor(0, 0, 0, 0.55) end

            af.icon = af:CreateTexture(nil, "ARTWORK")
            af.icon:SetSize(self.ARROW_SIZE, self.ARROW_SIZE)
            af.icon:SetPoint("CENTER", af, "CENTER", 0, 0)
            af.icon:SetTexture(self.ARROW_TEXTURE)
            if af.icon.SetVertexColor then
                af.icon:SetVertexColor(0.22, 0.92, 0.48, 1.0)
            end
        end
        if af.CreateFontString then
            af.sublabel = af:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
            af.sublabel:SetPoint("TOP", af, "BOTTOM", 0, -2)
            af.sublabel:SetText("")

            af.label = af:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            af.label:SetPoint("TOP", af, "BOTTOM", 0, -22)
            if af.label.SetTextColor then af.label:SetTextColor(0.93, 0.92, 0.88, 1) end
            af.label:SetText("AzerothRoute")

            af.etaLabel = af:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            af.etaLabel:SetPoint("TOP", af, "BOTTOM", 0, -38)
            if af.etaLabel.SetTextColor then af.etaLabel:SetTextColor(0.72, 0.74, 0.80, 1) end
            af.etaLabel:SetText("")
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

local MINIMAP_ZOOM_YARDS = {
    [0] = 150,
    [1] = 120,
    [2] = 90,
    [3] = 60,
    [4] = 40,
    [5] = 25,
}

local function applyActionPinTexture(tex, action)
    if not tex then return end
    if tex.SetTexCoord then
        tex:SetTexCoord(0, 1, 0, 1)
    end
    tex:SetTexture(AR.Skins:GetActionIcon(action))
end

function Pointer:PositionPinFrames(pin, wmPin, mmPin)
    local nx = (pin.x and pin.x > 1) and (pin.x / 100.0) or (pin.x or 0.5)
    local ny = (pin.y and pin.y > 1) and (pin.y / 100.0) or (pin.y or 0.5)

    local wmCanvas = self:GetWorldMapCanvas()
    local cw, ch = 1002, 668
    if wmCanvas and wmCanvas.GetSize then
        local w, h = wmCanvas:GetSize()
        if w and w > 0 then cw = w end
        if h and h > 0 then ch = h end
    end
    if wmPin then
        if wmPin.SetParent then wmPin:SetParent(wmCanvas) end
        if wmPin.ClearAllPoints then wmPin:ClearAllPoints() end
        wmPin:SetPoint("CENTER", wmCanvas, "TOPLEFT", nx * cw, -ny * ch)
    end

    -- Minimap radar projection in world yards (clamped to minimap circle radius, hidden if cross-continent/invalid)
    if mmPin then
        local pMap, px, py = AR.Coords:GetPlayerPosition()
        local c1, wx1, wy1, c2, wx2, wy2
        if AR.Coords.GetWorldPair then
            c1, wx1, wy1, c2, wx2, wy2 = AR.Coords:GetWorldPair(pMap, px, py, pin.map or pMap, nx, ny)
        else
            c1, wx1, wy1 = AR.Coords:ToWorldYards(pMap, px, py)
            c2, wx2, wy2 = AR.Coords:ToWorldYards(pin.map or pMap, nx, ny)
        end
        if c1 == nil or c2 == nil or c1 ~= c2 then
            if mmPin.Hide then mmPin:Hide() end
            return
        end

        local dxYd = wx2 - wx1
        local dyYd = -(wy2 - wy1)

        local rotateMinimap = (_G.C_CVar and _G.C_CVar.GetCVar and _G.C_CVar.GetCVar("rotateMinimap") == "1")
            or (_G.GetCVar and _G.GetCVar("rotateMinimap") == "1")
        if rotateMinimap and _G.GetPlayerFacing then
            local facing = _G.GetPlayerFacing() or 0
            local sinF, cosF = math.sin(facing), math.cos(facing)
            local rx = dxYd * cosF - dyYd * sinF
            local ry = dxYd * sinF + dyYd * cosF
            dxYd, dyYd = rx, ry
        end

        local viewYards = (_G.C_Minimap and _G.C_Minimap.GetViewRadius and _G.C_Minimap.GetViewRadius())
            or (_G.Minimap and _G.Minimap.GetZoom and MINIMAP_ZOOM_YARDS[_G.Minimap:GetZoom()])
            or self.MINIMAP_VIEW_YARDS
        local radiusPx = self.MINIMAP_RADIUS_PX
        if _G.Minimap and _G.Minimap.GetWidth then
            local mw = _G.Minimap:GetWidth()
            if mw and mw > 0 then
                radiusPx = (mw / 2) * 0.90
            end
        end

        local distYd = math.sqrt(dxYd * dxYd + dyYd * dyYd)
        local scale = radiusPx / viewYards
        local dxPx = dxYd * scale
        local dyPx = dyYd * scale
        if distYd > viewYards and distYd > 0 then
            dxPx = (dxYd / distYd) * radiusPx
            dyPx = (dyYd / distYd) * radiusPx
        end

        if mmPin.ClearAllPoints then mmPin:ClearAllPoints() end
        mmPin:SetPoint("CENTER", _G.Minimap or _G.UIParent, "CENTER", dxPx, dyPx)
        if mmPin.Show then mmPin:Show() end
    end
end

function Pointer:RefreshWorldMapPins()
    local viewedMapID = (_G.WorldMapFrame and _G.WorldMapFrame.GetMapID and _G.WorldMapFrame:GetMapID()) or nil
    for i, pin in ipairs(self.worldMapPins) do
        local wmPin = self.worldMapPinFrames[i]
        local mmPin = self.minimapPinFrames[i]
        if wmPin and not pin.managed then
            self:PositionPinFrames(pin, wmPin, mmPin)
            if not viewedMapID or not pin.map or viewedMapID == pin.map then
                wmPin:Show()
            else
                wmPin:Hide()
            end
        end
    end
end

local function attachPinTooltip(pinFrame, pinData)
    if not pinFrame or not pinFrame.SetScript then return end
    if pinFrame.EnableMouse then pinFrame:EnableMouse(true) end
    pinFrame:SetScript("OnEnter", function(f)
        if _G.GameTooltip and _G.GameTooltip.SetOwner then
            _G.GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
            _G.GameTooltip:SetText(pinData.title or "AzerothRoute")
            _G.GameTooltip:AddLine(string.format("%.1f, %.1f", (pinData.x or 0) * 100, (pinData.y or 0) * 100))
            _G.GameTooltip:Show()
        end
    end)
    pinFrame:SetScript("OnLeave", function()
        if _G.GameTooltip and _G.GameTooltip.Hide then
            _G.GameTooltip:Hide()
        end
    end)
end

-- HereBeDragons-Pins owns placement, map filtering, minimap zoom/rotation and edge floating when loaded.
function Pointer:GetPinsLib()
    return _G.LibStub and _G.LibStub("HereBeDragons-Pins-2.0", true) or nil
end

function Pointer:ClearLibraryPins()
    local lib = self:GetPinsLib()
    if lib then
        lib:RemoveAllWorldMapIcons(self)
        lib:RemoveAllMinimapIcons(self)
    end
end

-- Pin frames are pooled per index so repeated step changes never leak frames or duplicate global names.
function Pointer:AcquireWorldMapPin(i)
    self.worldMapPinPool = self.worldMapPinPool or {}
    local wmPin = self.worldMapPinPool[i]
    if wmPin then return wmPin end
    wmPin = _G.CreateFrame("Button", "AzerothRouteWorldMapPin" .. i, self:GetWorldMapCanvas())
    wmPin:SetSize(22, 22)
    if wmPin.CreateTexture then
        wmPin.ring = wmPin:CreateTexture(nil, "BACKGROUND")
        wmPin.ring:SetAllPoints(wmPin)
        wmPin.ring:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
        wmPin.tex = wmPin:CreateTexture(nil, "ARTWORK")
        wmPin.tex:SetSize(16, 16)
        wmPin.tex:SetPoint("CENTER", wmPin, "CENTER", 0, 0)
    end
    if wmPin.CreateFontString then
        wmPin.numLabel = wmPin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        wmPin.numLabel:SetPoint("BOTTOMRIGHT", wmPin, "BOTTOMRIGHT", 2, -2)
    end
    self.worldMapPinPool[i] = wmPin
    return wmPin
end

function Pointer:AcquireMinimapPin(i)
    self.minimapPinPool = self.minimapPinPool or {}
    local mmPin = self.minimapPinPool[i]
    if mmPin then return mmPin end
    mmPin = _G.CreateFrame("Button", "AzerothRouteMinimapPin" .. i, _G.Minimap or _G.UIParent)
    mmPin:SetSize(14, 14)
    if mmPin.SetFrameLevel then mmPin:SetFrameLevel(2500) end
    if mmPin.CreateTexture then
        mmPin.tex = mmPin:CreateTexture(nil, "OVERLAY")
        mmPin.tex:SetAllPoints(mmPin)
    end
    self.minimapPinPool[i] = mmPin
    return mmPin
end

-- Returns true when HereBeDragons-Pins accepted both icons; otherwise nothing stays registered for this pin.
function Pointer:RegisterLibraryPin(pin, wmPin, mmPin)
    local lib = self:GetPinsLib()
    if not lib or type(pin.x) ~= "number" or type(pin.y) ~= "number" then return false end
    local mapID = pin.map
    if not mapID and AR.Coords and AR.Coords.GetPlayerPosition then
        mapID = AR.Coords:GetPlayerPosition()
    end
    if type(mapID) ~= "number" then return false end

    local showFlag = _G.HBD_PINS_WORLDMAP_SHOW_CONTINENT or 2
    local wmOk = lib:AddWorldMapIconMap(self, wmPin, mapID, pin.x, pin.y, showFlag)
    local mmOk = lib:AddMinimapIconMap(self, mmPin, mapID, pin.x, pin.y, true, true)
    if wmOk and mmOk then
        pin.map = mapID
        return true
    end
    if lib.RemoveWorldMapIcon then lib:RemoveWorldMapIcon(self, wmPin) end
    if lib.RemoveMinimapIcon then lib:RemoveMinimapIcon(self, mmPin) end
    return false
end

function Pointer:PlaceStepPins(pinSpecs)
    self:EnsureWorldMapHook()
    self:ClearLibraryPins()
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

    local viewedMapID = (_G.WorldMapFrame and _G.WorldMapFrame.GetMapID and _G.WorldMapFrame:GetMapID()) or nil

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
            action = spec.action,
            objectiveIndex = spec.objectiveIndex or i,
            color = color,
        }
        table.insert(self.worldMapPins, pin)
        table.insert(self.minimapPins, pin)

        local wmPin = self:AcquireWorldMapPin(i)
        if wmPin.ring and wmPin.ring.SetVertexColor then
            wmPin.ring:SetVertexColor(colorEntry.r, colorEntry.g, colorEntry.b, 0.90)
        end
        applyActionPinTexture(wmPin.tex, spec.action)
        if wmPin.numLabel then wmPin.numLabel:SetText(tostring(spec.objectiveIndex or i)) end
        attachPinTooltip(wmPin, pin)

        local mmPin = self:AcquireMinimapPin(i)
        applyActionPinTexture(mmPin.tex, spec.action)
        attachPinTooltip(mmPin, pin)

        pin.managed = self:RegisterLibraryPin(pin, wmPin, mmPin)
        if not pin.managed then
            -- Native fallback: high-visibility canvas pin above all map tiles plus projected minimap radar pin.
            if wmPin.SetFrameStrata then wmPin:SetFrameStrata("HIGH") end
            if wmPin.SetFrameLevel then wmPin:SetFrameLevel(2500) end
            mmPin:Show()
            self:PositionPinFrames(pin, wmPin, mmPin)
            if not viewedMapID or not pin.map or viewedMapID == pin.map then
                wmPin:Show()
            else
                wmPin:Hide()
            end
        end

        table.insert(self.worldMapPinFrames, wmPin)
        table.insert(self.minimapPinFrames, mmPin)
    end

    -- A destination picked in Lookup/Dungeons wins over the step's pins until it is reached.
    if self.manualTarget then
        self.activeTarget = self.manualTarget
        return
    end

    if #self.worldMapPins > 0 then
        local first = self.worldMapPins[1]
        local previous = self.activeTarget
        local sameTarget = previous and previous.map == first.map and previous.x == first.x and previous.y == first.y
        self.activeTarget = {
            type = "waypoint",
            map = first.map,
            x = first.x,
            y = first.y,
            title = first.title,
            -- Keep the starting distance across refreshes so the distance color keeps its scale.
            initialDist = sameTarget and previous.initialDist or nil,
        }
    elseif self.activeTarget and self.activeTarget.type == "waypoint" then
        self.activeTarget = nil
        if self.arrowFrame then self.arrowFrame:Hide() end
    end
end

-- Points the arrow at a chosen place (Lookup, Dungeons) until the player arrives or clears it.
-- map is a uiMapID, x/y in 0..1.
function Pointer:SetManualTarget(map, x, y, title)
    if not map or not x or not y then
        self.manualTarget = nil
        return nil
    end
    self.manualTarget = { type = "manual", map = map, x = x, y = y, title = title or "Waypoint" }
    self.activeTarget = self.manualTarget
    if not self.arrowFrame then self:InitializeFrames() end
    self:UpdateArrow(0)
    return self.manualTarget
end

function Pointer:ClearManualTarget()
    self.manualTarget = nil
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
    if AR.db and AR.db.profile and AR.db.profile.corpsearrow == false then
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
                    title = (AR.L and AR.L:Get("UI_CORPSE")) or "Retrieve Your Corpse",
                }
                return true
            end
        end
    end
    return false
end

-- Arrow tint by heading error: green on course, gold when sideways, ember red when behind.
local BEARING_ON = { 0.22, 0.92, 0.48 }
local BEARING_SIDE = { 0.96, 0.77, 0.29 }
local BEARING_BACK = { 0.95, 0.25, 0.18 }

function Pointer:ComputeBearingColor(relAngleRad)
    local diff = math.abs(math.atan2(math.sin(relAngleRad or 0), math.cos(relAngleRad or 0)))
    local t = diff / math.pi
    local a, b, k = BEARING_ON, BEARING_SIDE, t * 2
    if t >= 0.5 then
        a, b, k = BEARING_SIDE, BEARING_BACK, (t - 0.5) * 2
    end
    return a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k
end

function Pointer:UpdateArrow(elapsed)
    self:CheckCorpseArrow()
    if _G.WorldMapFrame and _G.WorldMapFrame.IsShown and _G.WorldMapFrame:IsShown() then
        self:RefreshWorldMapPins()
    else
        for i, pin in ipairs(self.minimapPins) do
            if self.minimapPinFrames[i] and not pin.managed then
                self:PositionPinFrames(pin, nil, self.minimapPinFrames[i])
            end
        end
    end

    local suppressed = AR.MinimapButton and AR.MinimapButton.IsArrowSuppressed and AR.MinimapButton:IsArrowSuppressed()
    if not self.activeTarget or suppressed then
        if self.arrowFrame then self.arrowFrame:Hide() end
        return
    end
    if not self.arrowFrame then
        self:InitializeFrames()
    end
    local target = self.activeTarget
    -- A multi-leg journey steers the arrow to the end of its first leg (flight master, dock).
    local steer = (target.type ~= "corpse") and AR.Journey and AR.Journey.GetSteering
        and not (AR.db and AR.db.profile and AR.db.profile.journey == false)
        and AR.Journey:GetSteering(target) or nil
    self.steering = steer
    local aim = steer or target

    local angle = AR.Coords:GetBearingTo(aim.map, aim.x, aim.y)
    local facing = (_G.GetPlayerFacing and _G.GetPlayerFacing()) or 0
    -- GetBearingTo is clockwise from north; GetPlayerFacing and SetRotation are counter-clockwise.
    self.arrowBearing = -(angle or 0) - facing

    local af = self.arrowFrame
    if not af then return end
    af:Show()
    self:SampleSpeed(elapsed or 0)

    local dist = AR.Coords:GetDistanceTo(aim.map, aim.x, aim.y)
    if not steer and dist and not target.initialDist then target.initialDist = dist end
    local onTaxi = _G.UnitOnTaxi and _G.UnitOnTaxi("player")
    local arrived = not steer and dist and not onTaxi and dist <= self:GetArrivalRadius()

    if af.label then af.label:SetText(aim.title or "Waypoint") end
    if steer then
        if af.icon then self:ShowPointing() end
        if af.sublabel then
            af.sublabel:SetText(self:FormatSubLabel(dist, false))
            if af.sublabel.SetTextColor then af.sublabel:SetTextColor(1, 1, 1) end
        end
        if af.etaLabel and AR.Journey then
            af.etaLabel:SetText(string.format((AR.L and AR.L:Get("UI_JOURNEY_TOTAL_FMT")) or "%s total",
                AR.Journey:FormatDuration(steer.plan.seconds)))
        end
        return
    end
    if arrived and target.type == "manual" then
        -- Reached a chosen place: hand the arrow back to the guide's own waypoints.
        self.manualTarget = nil
    end
    if af.icon then
        if arrived then
            self:ShowArrived(elapsed or 0)
        else
            self:ShowPointing()
        end
    end
    if af.sublabel then
        af.sublabel:SetText(self:FormatSubLabel(dist, arrived))
        if dist and not arrived and af.sublabel.SetTextColor then
            af.sublabel:SetTextColor(self:ComputeDistanceColor(dist, target.initialDist))
        elseif af.sublabel.SetTextColor then
            af.sublabel:SetTextColor(1, 1, 1)
        end
    end
    if af.etaLabel then
        af.etaLabel:SetText(arrived and "" or self:FormatETA(dist))
    end
end

Pointer.ARRIVED_TEXTURE = "Interface\\RAIDFRAME\\ReadyCheck-Ready"
Pointer.ARRIVAL_RADIUS_GROUND = 8
Pointer.ARRIVAL_RADIUS_FLYING = 15
Pointer.SPEED_SAMPLE_INTERVAL = 0.2
Pointer.SPEED_SAMPLES_MAX = 30
Pointer.ETA_MAX_SECONDS = 7200

-- Zygor uses 8 yd on the ground and 15 yd while flying for the "you are here" state.
function Pointer:GetArrivalRadius()
    if _G.IsFlying and _G.IsFlying() then return self.ARRIVAL_RADIUS_FLYING end
    return self.ARRIVAL_RADIUS_GROUND
end

function Pointer:ShowPointing()
    local icon = self.arrowFrame.icon
    if self.arrowState ~= "pointing" then
        icon:SetTexture(self.ARROW_TEXTURE)
        if icon.ClearAllPoints then icon:ClearAllPoints() end
        icon:SetPoint("CENTER", self.arrowFrame, "CENTER", 0, 0)
        self.arrowState = "pointing"
    end
    if icon.SetRotation then icon:SetRotation(self.arrowBearing) end
    local shadow = self.arrowFrame.shadow
    if shadow then
        if shadow.SetRotation then shadow:SetRotation(self.arrowBearing) end
        shadow:Show()
    end
    if icon.SetVertexColor then
        local r, g, b = self:ComputeBearingColor(self.arrowBearing)
        icon:SetVertexColor(r, g, b, 1.0)
    end
end

-- Arrived: an unrotated check icon that bounces gently, like Zygor's "here" state.
function Pointer:ShowArrived(elapsed)
    local icon = self.arrowFrame.icon
    if self.arrowState ~= "arrived" then
        icon:SetTexture(self.ARRIVED_TEXTURE)
        self.arrowState = "arrived"
        self.bounceTime = 0
    end
    if icon.SetRotation then icon:SetRotation(0) end
    if icon.SetVertexColor then icon:SetVertexColor(1, 1, 1, 1) end
    if self.arrowFrame.shadow then self.arrowFrame.shadow:Hide() end
    self.bounceTime = (self.bounceTime or 0) + elapsed
    local offset = math.abs(math.sin(self.bounceTime * math.pi / 0.6)) * 6
    if icon.ClearAllPoints then icon:ClearAllPoints() end
    icon:SetPoint("CENTER", self.arrowFrame, "CENTER", 0, offset)
end

-- Rolling average of the player's movement speed, sampled every 0.2 s (up to 30 samples).
function Pointer:SampleSpeed(elapsed)
    self.speedSampleTimer = (self.speedSampleTimer or 0) + (elapsed or 0)
    if self.speedSampleTimer < self.SPEED_SAMPLE_INTERVAL then return end
    self.speedSampleTimer = 0
    -- GetUnitSpeed can be a secret value on Forever: such samples are skipped.
    local speed = _G.GetUnitSpeed and AR.Compat:Number(_G.GetUnitSpeed("player"))
    if not speed then return end
    table.insert(self.speedSamples, speed)
    if #self.speedSamples > self.SPEED_SAMPLES_MAX then table.remove(self.speedSamples, 1) end
end

function Pointer:GetETA(dist)
    if not dist or #self.speedSamples == 0 then return nil end
    local sum = 0
    local n = 0
    for _, s in ipairs(self.speedSamples) do
        if AR.Compat:Number(s) then sum, n = sum + s, n + 1 end
    end
    if n == 0 then return nil end
    local avg = sum / n
    if avg <= 0.1 then return nil end
    local eta = dist / avg
    if eta >= self.ETA_MAX_SECONDS then return nil end
    return eta
end

function Pointer:FormatSubLabel(dist, arrived)
    local L = AR.L
    if arrived then
        return (L and L:Get("UI_ARRIVED")) or "Arrived"
    end
    if not dist then
        local info = self.activeTarget.map and _G.C_Map and _G.C_Map.GetMapInfo and _G.C_Map.GetMapInfo(self.activeTarget.map)
        return (info and info.name) or ""
    end
    return string.format("%d yd", math.floor(dist + 0.5))
end

-- "m:ss" time to arrival from the rolling speed average, or "" while standing still.
function Pointer:FormatETA(dist)
    local eta = self:GetETA(dist)
    if not eta then return "" end
    local secs = math.floor(eta + 0.5)
    return string.format("%d:%02d", math.floor(secs / 60), secs % 60)
end

-- Distance text color: red far away, yellow midway, green close (relative to the starting distance).
function Pointer:ComputeDistanceColor(dist, initialDist)
    local span = math.max(100, math.min(initialDist or dist or 100, 500))
    local k = math.max(0, math.min(1, 1 - (dist or span) / span))
    if k < 0.5 then
        return 1.0, 0.25 + 1.5 * k * 0.95, 0.2
    end
    return 1.0 - (k - 0.5) * 2 * 0.7, 0.95, 0.2 + (k - 0.5) * 0.4
end

return Pointer
