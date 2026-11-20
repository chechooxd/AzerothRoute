-- AzerothRoute: Lookup mode of the Guide Center.
-- Searches guides plus the generated database (quests, NPCs, items, mounts, recipes, world objects)
-- with the Guide Center's search box, and points the arrow at where to get or find each result.

local AR = _G.AzerothRoute
local Lookup = { MODE = "lookup", query = "", cache = nil }
AR.Lookup = Lookup

local function L(key, fallback)
    if AR.L then
        local v = AR.L:Get(key)
        if v and v ~= key then return v end
    end
    return fallback or key
end

local CATEGORIES = {
    { id = "all", key = "UI_LK_EVERYTHING" },
    { id = "guide", key = "UI_LK_GUIDES" },
    { id = "quest", key = "UI_LK_QUESTS" },
    { id = "npc", key = "UI_LK_NPCS" },
    { id = "item", key = "UI_LK_ITEMS" },
    { id = "mount", key = "UI_LK_MOUNTS" },
    { id = "recipe", key = "UI_LK_RECIPES" },
    { id = "object", key = "UI_LK_OBJECTS" },
    { id = "rare", key = "UI_LK_RARES" },
}

local KIND_COLOR = { quest = "quest", npc = "npc", item = "item", mount = "item", recipe = "item", object = "place" }

local function zoneName(map)
    if not map or map == 0 then return L("UI_LK_UNKNOWN_ZONE") end
    local ok, info = pcall(function() return _G.C_Map and _G.C_Map.GetMapInfo and _G.C_Map.GetMapInfo(map) end)
    return (ok and info and info.name) or ("#" .. map)
end
Lookup.ZoneName = zoneName

local function sideLabel(side)
    if side == "A" then return L("UI_ALLIANCE") elseif side == "H" then return L("UI_HORDE") end
    return L("UI_BOTH")
end

function Lookup:Reset()
    self.query, self.cache = "", nil
    if self.panel and self.panel.side then
        self.panel.side:Hide()
        self.panel.main:Hide()
    end
    self.panel = nil
end

function Lookup:SetQuery(q)
    q = tostring(q or "")
    if q ~= self.query then
        self.query, self.cache = q, nil
    end
    if self.panel then
        self.panel.page = 0
        self.panel:Render()
    end
end

-- All results for the current query, bucketed by category.
function Lookup:Results()
    if self.cache then return self.cache end
    local buckets = { all = {} }
    for _, c in ipairs(CATEGORIES) do buckets[c.id] = buckets[c.id] or {} end
    local q = self.query or ""
    if #q >= 2 then
        for _, g in ipairs((AR.GuideMenu and AR.GuideMenu:Search(q)) or {}) do
            local r = { kind = "guide", guide = g, name = g.title }
            table.insert(buckets.guide, r)
            table.insert(buckets.all, r)
        end
        for _, r in ipairs((AR.DB and AR.DB.Search and AR.DB:Search(q)) or {}) do
            table.insert(buckets[r.kind], r)
            if r.kind == "npc" and ((AR.DB.Units[r.id] or ""):match("%^([%a]*)$") or ""):find("x", 1, true) then
                table.insert(buckets.rare, r)
            end
            table.insert(buckets.all, r)
        end
    end
    self.cache = buckets
    return buckets
end

function Lookup:GetCategories()
    local out = {}
    for _, c in ipairs(CATEGORIES) do out[#out + 1] = { id = c.id, label = L(c.key) } end
    return out
end

function Lookup:CountCategory(id)
    return #(self:Results()[id] or {})
end

local function guideTitle(g)
    if AR.L and AR.L:IsSpanish() and g.displayTitleES then return g.displayTitleES end
    return g.displayTitleEN or (g.title and g.title:match("([^\\]+)$")) or g.title or "?"
end

-- Short right-hand tag for a result row.
function Lookup:TagFor(r)
    local DB = AR.DB
    if r.kind == "guide" then
        local g = r.guide
        return g.startlevel and string.format("%d-%d", g.startlevel, g.endlevel or g.startlevel) or L("UI_LK_GUIDE")
    elseif r.kind == "quest" then
        local q = DB:GetQuest(r.id)
        return q and (L("UI_LK_LEVEL") .. " " .. q.level) or ""
    elseif r.kind == "npc" then
        local u = DB:GetUnit(r.id)
        return u and zoneName(u.map) or ""
    elseif r.kind == "object" then
        local o = DB:GetObject(r.id)
        return o and zoneName(o.map) or ""
    else
        local it = DB:GetItem(r.id)
        if not it then return "" end
        if #it.vendors > 0 then return L("UI_LK_VENDOR") end
        if #it.drops > 0 then return L("UI_LK_DROP") end
        if #it.objects > 0 then return L("UI_LK_OBJECT") end
        return ""
    end
end

function Lookup:GetRows(id)
    local out = {}
    for _, r in ipairs(self:Results()[id] or {}) do
        local name = r.kind == "guide" and guideTitle(r.guide) or r.name
        local colored = KIND_COLOR[r.kind] and AR.Skins:Colorize(name, KIND_COLOR[r.kind]) or name
        out[#out + 1] = { text = colored, plain = name, tag = self:TagFor(r), data = r }
    end
    return out
end

function Lookup:HeaderTitle() return L("UI_LOOKUP", "Lookup") end

function Lookup:HeaderSub(total)
    if #(self.query or "") < 2 then return L("UI_LK_TYPE_HINT") end
    return string.format(L("UI_LK_RESULTS_FMT", "%d results for \"%s\""), #(self:Results().all or {}), self.query)
end

-- Points the arrow (and the open world map) at a place; returns true when it had coordinates.
function Lookup:Navigate(loc)
    if not loc or not AR.Pointer or not AR.Pointer.SetManualTarget then return false end
    AR.Pointer:SetManualTarget(loc.map, loc.x, loc.y, loc.name)
    local wm = _G.WorldMapFrame
    if wm and wm.IsShown and wm:IsShown() and wm.SetMapID then wm:SetMapID(loc.map) end
    return true
end

local function unitLine(self, uid, tagKey)
    local u = AR.DB:GetUnit(uid)
    if not u then return nil end
    return {
        text = AR.Skins:Colorize(u.name, "npc"),
        tag = tagKey and L(tagKey) or zoneName(u.map),
        onClick = function() self:Navigate(AR.DB:LocationOf(u)) end,
    }
end

local SERVICE_KEYS = { v = "UI_SV_V", r = "UI_SV_R", i = "UI_SV_I", f = "UI_SV_F", b = "UI_SV_B", a = "UI_SV_A", s = "UI_SV_S" }

function Lookup:Describe(row)
    local r = row and row.data
    if not r then return {} end
    local DB = AR.DB
    local showMap = function(rec)
        local loc = DB:LocationOf(rec)
        if not loc then return nil end
        return { text = L("UI_LK_SHOW_MAP"), onClick = function() self:Navigate(loc) end }
    end

    if r.kind == "guide" then
        local g = r.guide
        return {
            title = guideTitle(g), subtitle = L("UI_LK_GUIDE"),
            info = { { L("UI_STAT_STEPS"), tostring(g.steps and #g.steps or 0) } },
            primary = { text = L("UI_LOAD_GUIDE"), onClick = function()
                if AR.GuideMenu then AR.GuideMenu:SetMode("guides"); AR.GuideMenu:SelectGuide(g) end
            end },
        }
    elseif r.kind == "quest" then
        local q = DB:GetQuest(r.id)
        if not q then return {} end
        local info, list = {
            { L("UI_LK_LEVEL"), tostring(q.level) },
            { L("UI_LK_MINLEVEL"), tostring(q.minLevel) },
            { L("UI_LK_SIDE"), sideLabel(q.side) },
        }, {}
        for _, ref in ipairs(q.starts) do
            if ref.kind == "U" then
                local line = unitLine(self, ref.id, "UI_LK_STARTS")
                if line then list[#list + 1] = line end
            end
        end
        for _, ref in ipairs(q.ends) do
            if ref.kind == "U" then
                local line = unitLine(self, ref.id, "UI_LK_ENDS")
                if line then list[#list + 1] = line end
            end
        end
        local loc = DB:LocationOf(q)
        if loc then info[#info + 1] = { L("UI_LK_ZONE"), zoneName(loc.map) } end
        return {
            title = q.name, subtitle = L("UI_LK_QUEST"),
            chips = { { text = L("UI_LK_LEVEL") .. " " .. q.level, accent = true }, { text = sideLabel(q.side) } },
            info = info, list = list, primary = showMap(q),
            secondary = { text = L("UI_LK_FIND_GUIDES"), onClick = function()
                if AR.GuideMenu then
                    AR.GuideMenu:SetMode("guides")
                    AR.GuideMenu:SetSearch("quest:" .. q.id)
                end
            end },
        }
    elseif r.kind == "npc" then
        local u = DB:GetUnit(r.id)
        if not u then return {} end
        local services = {}
        for flag in (u.flags or ""):gmatch(".") do
            if SERVICE_KEYS[flag] then services[#services + 1] = L(SERVICE_KEYS[flag]) end
        end
        local info = {
            { L("UI_LK_LEVEL"), u.level ~= "" and u.level or "?" },
            { L("UI_LK_ZONE"), zoneName(u.map) },
            { L("UI_LK_SIDE"), sideLabel(u.side) },
        }
        if #services > 0 then info[#info + 1] = { L("UI_LK_SERVICES"), table.concat(services, ", ") } end
        if u.map > 0 then info[#info + 1] = { "", string.format("%.1f, %.1f", u.x, u.y) } end
        return { title = u.name, subtitle = L("UI_LK_NPC"), chips = { { text = sideLabel(u.side) } },
            info = info, primary = showMap(u) }
    elseif r.kind == "object" then
        local o = DB:GetObject(r.id)
        if not o then return {} end
        return { title = o.name, subtitle = L("UI_LK_OBJECT"),
            info = { { L("UI_LK_ZONE"), zoneName(o.map) }, { "", string.format("%.1f, %.1f", o.x, o.y) } },
            primary = showMap(o) }
    else
        local it = DB:GetItem(r.id)
        if not it then return {} end
        local list = {}
        for _, uid in ipairs(it.vendors) do
            local line = unitLine(self, uid, "UI_LK_VENDOR")
            if line then list[#list + 1] = line end
        end
        for _, uid in ipairs(it.drops) do
            local line = unitLine(self, uid, "UI_LK_DROP")
            if line then list[#list + 1] = line end
        end
        for _, oid in ipairs(it.objects) do
            local o = DB:GetObject(oid)
            if o then
                list[#list + 1] = { text = AR.Skins:Colorize(o.name, "place"), tag = L("UI_LK_OBJECT"),
                    onClick = function() self:Navigate(DB:LocationOf(o)) end }
            end
        end
        local kindLabel = ({ mount = "UI_LK_MOUNT", recipe = "UI_LK_RECIPE" })[it.kind] or "UI_LK_ITEM"
        return { title = it.name, subtitle = L(kindLabel),
            info = { { L("UI_LK_SOURCES"), tostring(#list) } }, list = list, primary = showMap(it) }
    end
end

-- Builds the panel inside the Guide Center frame on first use.
function Lookup:Attach(frame)
    if self.panel then return self.panel end
    self.panel = AR.MenuPanel:New(self)
    self.panel:Attach(frame, "AzerothRouteLookup")
    return self.panel
end

return Lookup
