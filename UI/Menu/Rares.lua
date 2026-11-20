-- AzerothRoute: Rares mode of the Guide Center, plus rare sightings.
-- Rares come from the database (pfQuest's rare list). A rare seen by nameplate, target or
-- mouse-over is logged (when, where, how often) in AR.db.global.rareSeen and announced once every
-- few minutes. The panel lists rares (all, in your zone, seen), with level, zone, drops and the
-- last sighting, and points the arrow at the spawn.

local AR = _G.AzerothRoute
local Rares = {
    MODE = "rares",
    query = "",
    ALERT_COOLDOWN = 300,
    _registered = false,
    _alerted = {},
}
AR.Rares = Rares

local function L(key, fallback)
    if AR.L then
        local v = AR.L:Get(key)
        if v and v ~= key then return v end
    end
    return fallback or key
end

local function now()
    return (_G.time and _G.time()) or os.time()
end

local function seenStore()
    if not AR.db or not AR.db.global then return {} end
    AR.db.global.rareSeen = AR.db.global.rareSeen or {}
    return AR.db.global.rareSeen
end

function Rares:Reset()
    self.query, self.list, self.dropIndex, self._alerted = "", nil, nil, {}
    if self.panel and self.panel.side then
        self.panel.side:Hide()
        self.panel.main:Hide()
    end
    self.panel = nil
end

-- Every rare in the database, decoded and sorted by level then name (built once).
function Rares:All()
    if self.list then return self.list end
    local out = {}
    for id, raw in pairs((AR.DB and AR.DB.Units) or {}) do
        local flags = raw:match("%^([%a]*)$") or ""
        if flags:find("x", 1, true) then
            local u = AR.DB:GetUnit(id)
            if u then
                u.levelNum = tonumber((u.level or ""):match("%d+")) or 0
                out[#out + 1] = u
            end
        end
    end
    table.sort(out, function(a, b)
        if a.levelNum ~= b.levelNum then return a.levelNum < b.levelNum end
        return a.name < b.name
    end)
    self.list = out
    return out
end

function Rares:IsRare(npcID)
    local raw = npcID and AR.DB and AR.DB.Units and AR.DB.Units[npcID]
    return raw ~= nil and ((raw:match("%^([%a]*)$") or ""):find("x", 1, true) ~= nil)
end

-- Items each rare drops (reverse of the item drop lists, built once): npcID -> { itemIDs }.
function Rares:Drops(npcID)
    if not self.dropIndex then
        local idx = {}
        for iid, raw in pairs((AR.DB and AR.DB.Items) or {}) do
            local drops = raw:match("^[^^]*%^([^^]*)") or ""
            for uid in drops:gmatch("%d+") do
                uid = tonumber(uid)
                idx[uid] = idx[uid] or {}
                table.insert(idx[uid], iid)
            end
        end
        self.dropIndex = idx
    end
    return self.dropIndex[npcID] or {}
end

-- Logs a sighting of `unit` when it is a rare; announces it unless announced recently.
function Rares:OnUnitSeen(unit)
    if not _G.UnitGUID or not AR.Trainers then return nil end
    local id = AR.Trainers:NpcIdFromGUID(_G.UnitGUID(unit))
    if not id or not self:IsRare(id) then return nil end
    local dead = _G.UnitIsDead and _G.UnitIsDead(unit)
    if dead ~= nil and not AR.Compat:IsSecret(dead) and dead then return nil end
    local store = seenStore()
    local rec = store[id] or { count = 0 }
    local t = now()
    local map, x, y
    if AR.Coords then map, x, y = AR.Coords:GetPlayerPosition() end
    -- Count a new sighting only after a quiet spell, so one encounter is one sighting.
    if not rec.last or t - rec.last > self.ALERT_COOLDOWN then rec.count = (rec.count or 0) + 1 end
    rec.first = rec.first or t
    rec.last, rec.map, rec.x, rec.y = t, map, x, y
    store[id] = rec
    if not self._alerted[id] or t - self._alerted[id] > self.ALERT_COOLDOWN then
        self._alerted[id] = t
        local name = (_G.UnitName and AR.Compat:String(_G.UnitName(unit))) or (AR.DB:GetUnit(id) or {}).name or "?"
        if AR.Print then AR:Print(string.format(L("UI_RARE_ALERT_FMT", "Rare nearby: %s"), name)) end
        if _G.PlaySound and _G.SOUNDKIT and _G.SOUNDKIT.RAID_WARNING then pcall(_G.PlaySound, _G.SOUNDKIT.RAID_WARNING) end
    end
    return rec
end

function Rares:RegisterLiveEvents()
    if self._registered or not AR.Events then return end
    self._registered = true
    AR.Events:RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, unit) self:OnUnitSeen(unit) end)
    AR.Events:RegisterEvent("PLAYER_TARGET_CHANGED", function() self:OnUnitSeen("target") end)
    AR.Events:RegisterEvent("UPDATE_MOUSEOVER_UNIT", function() self:OnUnitSeen("mouseover") end)
end

-- "7 h ago" style age.
function Rares:Ago(t)
    local d = math.max(0, now() - (t or now()))
    if d < 60 then return string.format(L("UI_AGO_S", "%d s ago"), d) end
    if d < 3600 then return string.format(L("UI_AGO_M", "%d min ago"), math.floor(d / 60)) end
    if d < 86400 then return string.format(L("UI_AGO_H", "%d h ago"), math.floor(d / 3600)) end
    return string.format(L("UI_AGO_D", "%d days ago"), math.floor(d / 86400))
end

-- Panel data ----------------------------------------------------------------------------------

function Rares:SetQuery(q)
    self.query = tostring(q or "")
    if self.panel then
        self.panel.page = 0
        self.panel:Render()
    end
end

function Rares:List(id)
    local q = (self.query or ""):lower()
    local pMap = AR.Coords and AR.Coords:GetPlayerPosition()
    local seen = seenStore()
    local out = {}
    for _, u in ipairs(self:All()) do
        local keep = id == "all" or (id == "zone" and u.map == pMap) or (id == "seen" and seen[u.id] ~= nil)
        if keep and q ~= "" then keep = u.name:lower():find(q, 1, true) ~= nil end
        if keep then out[#out + 1] = u end
    end
    if id == "seen" then
        table.sort(out, function(a, b) return (seen[a.id].last or 0) > (seen[b.id].last or 0) end)
    end
    return out
end

function Rares:GetCategories()
    return {
        { id = "all", label = L("UI_LK_RARES", "Rares") },
        { id = "zone", label = L("UI_RARES_ZONE", "In this zone") },
        { id = "seen", label = L("UI_RARES_SEEN", "Seen") },
    }
end

function Rares:CountCategory(id) return #self:List(id) end

function Rares:GetRows(id)
    local rows = {}
    for _, u in ipairs(self:List(id)) do
        rows[#rows + 1] = { text = "|cffff8a4c" .. u.name .. "|r", tag = u.level ~= "" and u.level or "?", data = u }
    end
    return rows
end

function Rares:HeaderTitle() return L("UI_LK_RARES", "Rares") end

function Rares:HeaderSub()
    local n, zones, seenN = #self:All(), {}, 0
    for _, u in ipairs(self:All()) do zones[u.map] = true end
    local z = 0
    for _ in pairs(zones) do z = z + 1 end
    for _ in pairs(seenStore()) do seenN = seenN + 1 end
    return string.format(L("UI_RARES_SUB_FMT", "%d rares · %d zones · %d seen"), n, z, seenN)
end

function Rares:Describe(row)
    local u = row and row.data
    if not u then return {} end
    local zone = (AR.Lookup and AR.Lookup.ZoneName(u.map)) or tostring(u.map)
    local seen = seenStore()[u.id]
    local info = {
        { L("UI_LK_LEVEL", "Level"), u.level ~= "" and u.level or "?" },
        { L("UI_LK_ZONE", "Zone"), zone },
    }
    if u.map > 0 then info[#info + 1] = { "", string.format("%.1f, %.1f", u.x, u.y) } end
    if seen then
        info[#info + 1] = { L("UI_RARES_SEEN", "Seen"), Rares:Ago(seen.last) }
        info[#info + 1] = { "", string.format(L("UI_RARES_TIMES_FMT", "%d times"), seen.count or 1) }
    end
    local list = {}
    for _, iid in ipairs(self:Drops(u.id)) do
        local it = AR.DB:GetItem(iid)
        if it then
            list[#list + 1] = { text = AR.Skins:Colorize(it.name, "item"), tag = L("UI_LK_DROP", "Drop"),
                onClick = function()
                    if AR.GuideMenu then AR.GuideMenu:SetMode("lookup"); AR.GuideMenu:SetSearch(it.name) end
                end }
        end
    end
    local loc = AR.DB:LocationOf(u)
    return {
        title = u.name,
        subtitle = zone,
        art = u.map > 0 and u.map or nil,
        artFocus = u.map > 0 and u.y / 100 or nil,
        chips = { { text = L("UI_SV_RARE", "Rare"), accent = true } },
        info = info,
        list = list,
        primary = loc and { text = L("UI_RARES_WAYPOINT", "Set waypoint"), onClick = function()
            if AR.Lookup then AR.Lookup:Navigate(loc) end
        end } or nil,
        secondary = { text = L("UI_LOOKUP", "Lookup"), onClick = function()
            if AR.GuideMenu then AR.GuideMenu:SetMode("lookup"); AR.GuideMenu:SetSearch(u.name) end
        end },
    }
end

function Rares:Attach(frame)
    if self.panel then return self.panel end
    self.panel = AR.MenuPanel:New(self)
    self.panel:Attach(frame, "AzerothRouteRares")
    return self.panel
end

return Rares
