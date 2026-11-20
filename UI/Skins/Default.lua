-- AzerothRoute: Skin & Style Registry (SPEC-12)
-- Night-sky look: navy panels, a single gold accent, and coloured subjects
-- (NPCs blue, quests gold, items violet) inside otherwise plain step text.

local AR = _G.AzerothRoute

-- Shared palette tokens; a style may override any of them.
local PALETTE = {
    panel = { r = 0.071, g = 0.086, b = 0.137, a = 0.96 },
    panelRaised = { r = 0.106, g = 0.125, b = 0.188, a = 0.98 },
    border = { r = 0.20, g = 0.24, b = 0.34, a = 1 },
    divider = { r = 0.18, g = 0.21, b = 0.30, a = 1 },
    accent = { r = 0.957, g = 0.773, b = 0.290 },
    text = { r = 0.93, g = 0.92, b = 0.88 },
    textMuted = { r = 0.58, g = 0.60, b = 0.66 },
    textDone = { r = 0.46, g = 0.48, b = 0.54 },
    hover = { r = 0.16, g = 0.19, b = 0.28, a = 0.90 },
    selected = { r = 0.17, g = 0.20, b = 0.29, a = 1 },
    whileHere = { r = 0.27, g = 0.24, b = 0.17, a = 0.92 },
    track = { r = 0.20, g = 0.22, b = 0.30, a = 1 },
    check = { r = 0.40, g = 0.82, b = 0.48 },
    warn = { r = 0.95, g = 0.55, b = 0.25 },
    npcColor = "ff8cc4f5",
    questColor = "fff4c54a",
    itemColor = "ffc8a2f5",
    placeColor = "ffe8e3d6",
}

local Skins = {
    PALETTE = PALETTE,
    styles = {
        default = {
            bg = { r = 0.071, g = 0.086, b = 0.137, a = 0.96 },
            goalIncomplete = { r = 0.45, g = 0.12, b = 0.12 },
            goalProgressing = { r = 0.48, g = 0.38, b = 0.10 },
            goalComplete = { r = 0.12, g = 0.42, b = 0.20 },
            goalImpossible = { r = 0.25, g = 0.25, b = 0.28 },
            goalWarning = { r = 0.55, g = 0.28, b = 0.08 },
            goalPassive = { r = 0.16, g = 0.20, b = 0.28 },
            stickySeparator = { r = 0.35, g = 0.38, b = 0.45, height = 1 },
            progressBarHeight = 4,
        },
        starlight = {
            bg = { r = 0.04, g = 0.05, b = 0.08, a = 0.96 },
            panel = { r = 0.04, g = 0.05, b = 0.08, a = 0.96 },
            panelRaised = { r = 0.07, g = 0.08, b = 0.12, a = 0.98 },
            goalIncomplete = { r = 0.40, g = 0.10, b = 0.15 },
            goalProgressing = { r = 0.45, g = 0.35, b = 0.12 },
            goalComplete = { r = 0.10, g = 0.40, b = 0.22 },
            goalImpossible = { r = 0.22, g = 0.22, b = 0.25 },
            goalWarning = { r = 0.52, g = 0.25, b = 0.08 },
            goalPassive = { r = 0.14, g = 0.17, b = 0.24 },
            stickySeparator = { r = 0.30, g = 0.35, b = 0.42, height = 1 },
            progressBarHeight = 4,
        },
    },
}
AR.Skins = Skins

-- One icon per goal action, shared by the guide window lines and the map/minimap pins.
Skins.ACTION_ICONS = {
    accept = "Interface\\GossipFrame\\AvailableQuestIcon",
    turnin = "Interface\\GossipFrame\\ActiveQuestIcon",
    kill = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
    from = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
    fpath = "Interface\\Minimap\\Tracking\\FlightMaster",
    fly = "Interface\\Minimap\\Tracking\\FlightMaster",
    vendor = "Interface\\GossipFrame\\VendorGossipIcon",
    buy = "Interface\\GossipFrame\\VendorGossipIcon",
    trainer = "Interface\\GossipFrame\\TrainerGossipIcon",
    learn = "Interface\\GossipFrame\\TrainerGossipIcon",
    home = "Interface\\Minimap\\Tracking\\Innkeeper",
    hearth = "Interface\\Minimap\\Tracking\\Innkeeper",
    get = "Interface\\GossipFrame\\BankerGossipIcon",
    collect = "Interface\\GossipFrame\\BankerGossipIcon",
    create = "Interface\\GossipFrame\\BankerGossipIcon",
    talk = "Interface\\GossipFrame\\GossipGossipIcon",
    ["goto"] = "Interface\\Icons\\INV_Misc_Map_01",
}
Skins.DEFAULT_ACTION_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"
Skins.CHECK_ICON = "Interface\\RAIDFRAME\\ReadyCheck-Ready"
Skins.CHECKBOX_ICON = "Interface\\Buttons\\UI-CheckBox-Up"
Skins.CHECKBOX_CHECK_ICON = "Interface\\Buttons\\UI-CheckBox-Check"

function Skins:GetActionIcon(action)
    return self.ACTION_ICONS[action or ""] or self.DEFAULT_ACTION_ICON
end

function Skins:GetProp(key)
    local styleName = (AR.db and AR.db.profile and AR.db.profile.style) or "default"
    local style = self.styles[styleName] or self.styles.default
    if style[key] ~= nil then return style[key] end
    return PALETTE[key]
end

-- Colour token as (r, g, b, a) for SetColorTexture / SetTextColor.
function Skins:RGBA(key, alpha)
    local c = self:GetProp(key)
    if type(c) ~= "table" then c = PALETTE.text end
    return c.r, c.g, c.b, alpha or c.a or 1
end

-- Fills `tex` with the palette colour `key`.
function Skins:Paint(tex, key, alpha)
    if tex and tex.SetColorTexture then tex:SetColorTexture(self:RGBA(key, alpha)) end
end

-- Wraps text in the escape colour of its subject kind ("npc", "quest", "item", "place").
function Skins:Colorize(text, kind)
    local hex = kind and self:GetProp(kind .. "Color")
    if type(hex) ~= "string" or not text or text == "" then return text end
    return "|c" .. hex .. text .. "|r"
end

-- Draws a 1px border (four edge textures) around `frame` in palette colour `key`.
function Skins:AddBorder(frame, key)
    if not frame or not frame.CreateTexture then return nil end
    local edges = {}
    local function edge(p1, p2, w, h)
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetPoint(p1, frame, p1, 0, 0)
        t:SetPoint(p2, frame, p2, 0, 0)
        if w and t.SetWidth then t:SetWidth(w) end
        if h and t.SetHeight then t:SetHeight(h) end
        self:Paint(t, key or "border")
        table.insert(edges, t)
    end
    edge("TOPLEFT", "TOPRIGHT", nil, 1)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
    edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
    frame.borderEdges = edges
    return edges
end

return Skins
