-- AzerothRoute: zone art bands.
-- Paints a zone's world-map painting from the player's own client (C_Map.GetMapArtLayers and
-- C_Map.GetMapArtLayerTextures): the layer's tiles scaled to the band's width, cropped around a
-- point, with a fade into the panel colour at the bottom so text over it stays readable.
-- No art ships with the addon; without the API (or for an unknown map) the band stays empty.

local AR = _G.AzerothRoute
local ZoneArt = {}
AR.ZoneArt = ZoneArt

-- A band of `width` x `height` inside `parent` (the caller anchors it).
function ZoneArt:Create(parent, width, height, name)
    local band = AR.UI:Create("Frame", parent, name)
    band:SetSize(width, height)
    if band.SetClipsChildren then band:SetClipsChildren(true) end
    band._w, band._h = width, height
    band.tiles = {}
    band.fade = band:CreateTexture(nil, "OVERLAY")
    band.fade:SetPoint("BOTTOMLEFT", band, "BOTTOMLEFT", 0, 0)
    band.fade:SetSize(width, math.floor(height * 0.7))
    band.fade:SetTexture("Interface\\Buttons\\WHITE8X8")
    local r, g, b = AR.Skins:RGBA("panelRaised")
    if band.fade.SetGradientAlpha then
        band.fade:SetGradientAlpha("VERTICAL", r, g, b, 1, r, g, b, 0)
    elseif band.fade.SetGradient and _G.CreateColor then
        band.fade:SetGradient("VERTICAL", _G.CreateColor(r, g, b, 1), _G.CreateColor(r, g, b, 0))
    else
        band.fade:SetColorTexture(r, g, b, 0.5)
    end
    band.fade:Hide()
    band.over = AR.UI:Create("Frame", band, name and (name .. "Over") or nil)
    band.over:SetPoint("TOPLEFT", band, "TOPLEFT", 0, 0)
    band.over:SetSize(width, height)
    if band.over.SetFrameLevel and band.GetFrameLevel then band.over:SetFrameLevel((band:GetFrameLevel() or 1) + 2) end
    return band
end

-- Tile layout of a map's first art layer: { cols, rows, tileW, tileH, layerW, layerH, textures } or nil.
function ZoneArt:Layout(uiMapID)
    local M = _G.C_Map
    if type(uiMapID) ~= "number" or uiMapID <= 0 or not M or not M.GetMapArtLayers or not M.GetMapArtLayerTextures then
        return nil
    end
    local ok, layers = pcall(M.GetMapArtLayers, uiMapID)
    local info = ok and type(layers) == "table" and layers[1]
    if not info or (info.layerWidth or 0) <= 0 or (info.tileWidth or 0) <= 0 or (info.tileHeight or 0) <= 0 then return nil end
    local ok2, textures = pcall(M.GetMapArtLayerTextures, uiMapID, 1)
    if not ok2 or type(textures) ~= "table" or #textures == 0 then return nil end
    return {
        cols = math.ceil(info.layerWidth / info.tileWidth),
        rows = math.ceil(info.layerHeight / info.tileHeight),
        tileW = info.tileWidth, tileH = info.tileHeight,
        layerW = info.layerWidth, layerH = info.layerHeight,
        textures = textures,
    }
end

-- Paints `uiMapID` into `band`, centred on focusY (0..1 of the map height, default 0.5).
-- Returns true when painted; hides the band otherwise.
function ZoneArt:Paint(band, uiMapID, focusY)
    if not band then return false end
    local lay = self:Layout(uiMapID)
    for _, t in ipairs(band.tiles) do t:Hide() end
    if not lay then
        band.fade:Hide()
        band.mapID = nil
        return false
    end
    local scale = band._w / lay.layerW
    local fullH = lay.layerH * scale
    local offset = math.max(0, math.min(fullH - band._h, fullH * (focusY or 0.5) - band._h / 2))
    local i = 0
    for row = 0, lay.rows - 1 do
        for col = 0, lay.cols - 1 do
            i = i + 1
            local fileID = lay.textures[i]
            if fileID then
                local t = band.tiles[i]
                if not t then
                    t = band:CreateTexture(nil, "BACKGROUND")
                    band.tiles[i] = t
                end
                t:SetTexture(fileID)
                t:SetSize(lay.tileW * scale, lay.tileH * scale)
                t:SetPoint("TOPLEFT", band, "TOPLEFT", col * lay.tileW * scale, -(row * lay.tileH * scale - offset))
                t:Show()
            end
        end
    end
    band.fade:Show()
    band.mapID = uiMapID
    return true
end

function ZoneArt:Lift(band, fontString)
    if band and band.over and fontString and fontString.SetParent then fontString:SetParent(band.over) end
end

-- The map a guide is about: its first step map or first coordinate goal.
function ZoneArt:GuideMap(guide)
    for _, st in ipairs((guide and guide.steps) or {}) do
        if st.map then return st.map end
        for _, g in ipairs(st.goals or {}) do
            if g.map then return g.map end
        end
    end
    return nil
end

return ZoneArt
