-- AzerothRoute: Flight Master, Live TaxiMap Highlighter & Bilingual Node Tracker (SPEC-05 / SPEC-22)

local AR = _G.AzerothRoute
local TaxiTracker = {
    RACIAL_STARTERS = {
        Scourge = { "Undercity" },
        Undead = { "Undercity" },
        Orc = { "Orgrimmar" },
        Troll = { "Orgrimmar" },
        Tauren = { "Thunder Bluff" },
        BloodElf = { "Silvermoon City" },
        Human = { "Stormwind" },
        Dwarf = { "Ironforge" },
        Gnome = { "Ironforge" },
        NightElf = { "Rut'theran Village" },
        Draenei = { "The Exodar" },
    },
    NODE_NAMES_ES = {
        ["Brill"] = "Rémol",
        ["Undercity"] = "Entrañas",
        ["The Sepulcher"] = "El Sepulcro",
        ["Tarren Mill"] = "Molino Tarren",
        ["Orgrimmar"] = "Orgrimmar",
        ["Razor Hill"] = "Cerrotajo",
        ["Crossroads"] = "El Cruce",
        ["The Crossroads"] = "El Cruce",
        ["Ratchet"] = "Trinquete",
        ["Camp Taurajo"] = "Campamento Taurajo",
        ["Thunder Bluff"] = "Cima del Trueno",
        ["Sun Rock Retreat"] = "Refugio Roca del Sol",
        ["Freewind Post"] = "Poblado Viento Libre",
        ["Gadgetzan"] = "Gadgetzan",
        ["Grom'gol"] = "Campamento Grom'gol",
        ["Booty Bay"] = "Bahía del Botín",
        ["Stormwind"] = "Ventormenta",
        ["Sentinel Hill"] = "Colina del Centinela",
        ["Lakeshire"] = "Villa del Lago",
        ["Darkshire"] = "Villa Oscura",
        ["Ironforge"] = "Forjaz",
        ["Thelsamar"] = "Thelsamar",
        ["Menethil Harbor"] = "Puerto de Menethil",
        ["Auberdine"] = "Auberdine",
        ["Astranaar"] = "Astranaar",
        ["Rut'theran Village"] = "Aldea Rut'theran",
        ["Thorium Point"] = "Puesto del Torio",
        ["Everlook"] = "Vista Eterna",
        ["Light's Hope Chapel"] = "Capilla de la Esperanza de la Luz",
    },
    NODE_ALIASES_TO_CANON = {},
    highlightFrame = nil,
    _liveRegistered = false,
}
AR.TaxiTracker = TaxiTracker

for en, es in pairs(TaxiTracker.NODE_NAMES_ES) do
    TaxiTracker.NODE_ALIASES_TO_CANON[en:lower()] = en
    TaxiTracker.NODE_ALIASES_TO_CANON[es:lower()] = en
end

function TaxiTracker:CanonicalizeNodeName(rawName)
    if not rawName then return nil end
    local trimmed = tostring(rawName):match("^%s*(.-)%s*$")
    local base = trimmed:match("^(.-)%s*,") or trimmed
    return self.NODE_ALIASES_TO_CANON[base:lower()]
        or self.NODE_ALIASES_TO_CANON[trimmed:lower()]
        or base
end

function TaxiTracker:GetLocalizedNodeName(nodeName)
    if not nodeName then return "" end
    local canon = self:CanonicalizeNodeName(nodeName)
    if AR.L and AR.L:IsSpanish() then
        return self.NODE_NAMES_ES[canon] or self.NODE_NAMES_ES[nodeName] or nodeName
    end
    return canon or nodeName
end

function TaxiTracker:InitializeForRace(race)
    if not AR.db or not AR.db.char then return end
    AR.db.char.taxis = AR.db.char.taxis or {}
    local starters = self.RACIAL_STARTERS[race or "Scourge"] or {}
    for _, nodeName in ipairs(starters) do
        AR.db.char.taxis[nodeName] = true
    end
end

function TaxiTracker:KnowsTaxi(nodeName)
    if not nodeName or not AR.db or not AR.db.char or not AR.db.char.taxis then return false end
    if AR.db.char.taxis[nodeName] == true then return true end
    local canon = self:CanonicalizeNodeName(nodeName)
    return canon and AR.db.char.taxis[canon] == true or false
end

function TaxiTracker:LearnTaxi(nodeName, defaultTripSeconds)
    if not nodeName or not AR.db or not AR.db.char then return end
    local canon = self:CanonicalizeNodeName(nodeName) or nodeName
    AR.db.char.taxis[nodeName] = true
    AR.db.char.taxis[canon] = true
    if defaultTripSeconds and AR.db.global then
        AR.db.global.taxitimes[canon] = defaultTripSeconds
    end
end

function TaxiTracker:RecordTripTime(srcName, dstName, seconds)
    if not AR.db or not AR.db.global then return end
    local key = string.format("%s->%s", tostring(srcName), tostring(dstName))
    AR.db.global.taxitimes[key] = seconds
end

function TaxiTracker:GetTripTime(srcName, dstName)
    if AR.db and AR.db.global and AR.db.global.taxitimes then
        local key = string.format("%s->%s", tostring(srcName), tostring(dstName))
        if AR.db.global.taxitimes[key] then
            return AR.db.global.taxitimes[key]
        end
        if AR.db.global.taxitimes[dstName] then
            return AR.db.global.taxitimes[dstName]
        end
    end
    return 60
end

local function nodeNameMatches(rawBlizzName, targetName)
    if not rawBlizzName or not targetName then return false end
    local canonBlizz = TaxiTracker:CanonicalizeNodeName(rawBlizzName):lower()
    local canonTarget = TaxiTracker:CanonicalizeNodeName(targetName):lower()
    if canonBlizz == canonTarget or canonBlizz:find(canonTarget, 1, true) or canonTarget:find(canonBlizz, 1, true) then
        return true
    end
    local locTarget = TaxiTracker:GetLocalizedNodeName(targetName):lower()
    return rawBlizzName:lower():find(locTarget, 1, true) ~= nil
end

function TaxiTracker:HighlightTaxiDestination(targetNodeName)
    if not self.highlightFrame and _G.CreateFrame then
        local hf = _G.CreateFrame("Frame", "AzerothRouteTaxiHighlight", _G.TaxiFrame or _G.UIParent)
        hf:SetSize(36, 36)
        if hf.SetFrameStrata then hf:SetFrameStrata("HIGH") end
        if hf.SetFrameLevel then hf:SetFrameLevel(500) end
        if hf.CreateTexture then
            hf.tex = hf:CreateTexture(nil, "OVERLAY")
            hf.tex:SetAllPoints(hf)
            hf.tex:SetTexture("Interface\\Minimap\\Tracking\\FlightMaster")
            if hf.tex.SetVertexColor then
                hf.tex:SetVertexColor(1.0, 0.85, 0.10, 1.0)
            end
        end
        self.highlightFrame = hf
    end

    if self.highlightFrame then self.highlightFrame:Hide() end
    if not targetNodeName or not _G.NumTaxiNodes or not _G.TaxiNodeName then return nil end

    local count = _G.NumTaxiNodes() or 0
    for i = 1, count do
        local nType = _G.TaxiNodeGetType and _G.TaxiNodeGetType(i) or "REACHABLE"
        local nName = _G.TaxiNodeName(i)
        if nType ~= "NONE" and nodeNameMatches(nName, targetNodeName) then
            local btn = _G["TaxiButton" .. i]
            if btn and self.highlightFrame then
                if self.highlightFrame.SetParent then self.highlightFrame:SetParent(btn) end
                if self.highlightFrame.ClearAllPoints then self.highlightFrame:ClearAllPoints() end
                self.highlightFrame:SetPoint("CENTER", btn, "CENTER", 0, 0)
                self.highlightFrame:Show()
            end
            return i
        end
    end
    return nil
end

function TaxiTracker:OnTaxiMapOpened()
    local count = (_G.NumTaxiNodes and _G.NumTaxiNodes()) or 0
    for i = 1, count do
        local nType = _G.TaxiNodeGetType and _G.TaxiNodeGetType(i)
        local nName = _G.TaxiNodeName and _G.TaxiNodeName(i)
        if nName and (nType == "CURRENT" or nType == "REACHABLE") then
            self:LearnTaxi(nName)
        end
    end

    local destTarget = nil
    local shouldAutoFly = false
    if AR.Progression and AR.Progression.currentStep then
        for _, g in ipairs(AR.Progression.currentStep.goals or {}) do
            if g.action == "fpath" then
                g.visited = true
                if g.param then self:LearnTaxi(g.param) end
                destTarget = destTarget or g.param
            elseif g.action == "fly" and g.param then
                destTarget = g.param
                shouldAutoFly = true
            end
        end
    end

    local matchedSlot = destTarget and self:HighlightTaxiDestination(destTarget) or nil
    if shouldAutoFly and matchedSlot and _G.TakeTaxiNode and not (_G.IsAltKeyDown and _G.IsAltKeyDown()) then
        if not (AR.db and AR.db.global and AR.db.global.autotaxi == false) then
            if _G.GetNumRoutes then _G.GetNumRoutes(matchedSlot) end
            _G.TakeTaxiNode(matchedSlot)
        end
    end

    if AR.Progression and AR.Progression:TryToCompleteStep(false) and AR.ViewerFrame then
        AR.ViewerFrame:RefreshVisuals()
    end
end

function TaxiTracker:RegisterLiveEvents()
    if self._liveRegistered or not AR.Events then return end
    self._liveRegistered = true
    AR.Events:RegisterEvent("TAXIMAP_OPENED", function()
        self:OnTaxiMapOpened()
    end)
end

return TaxiTracker
