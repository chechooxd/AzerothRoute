-- AzerothRoute: Dungeons mode of the Guide Center.
-- Lists every Classic dungeon and raid (DB/DungeonDefs.lua) with level range, zone and the quests
-- that lead into it (DB/DungeonData.lua); clicking a quest points the arrow at its giver.

local AR = _G.AzerothRoute
local Dungeons = { MODE = "dungeons", query = "" }
AR.Dungeons = Dungeons

local function L(key, fallback)
    if AR.L then
        local v = AR.L:Get(key)
        if v and v ~= key then return v end
    end
    return fallback or key
end

local BANDS = {
    { id = "b10", min = 10, max = 29, label = "10-30" },
    { id = "b30", min = 30, max = 44, label = "30-45" },
    { id = "b45", min = 45, max = 59, label = "45-60" },
}

local function playerLevel() return (_G.UnitLevel and _G.UnitLevel("player")) or 1 end

function Dungeons:Reset()
    self.query = ""
    if self.panel and self.panel.side then
        self.panel.side:Hide()
        self.panel.main:Hide()
    end
    self.panel = nil
end

function Dungeons:SetQuery(q)
    self.query = tostring(q or "")
    if self.panel then
        self.panel.page = 0
        self.panel:Render()
    end
end

function Dungeons:IsForLevel(d, level)
    level = level or playerLevel()
    return level >= d.min - 2 and level <= d.max
end

-- Dungeons in a category, filtered by the search box text (name in either language).
function Dungeons:List(id)
    local q = (self.query or ""):lower()
    local out = {}
    for _, d in ipairs((AR.DB and AR.DB.GetDungeons and AR.DB:GetDungeons()) or {}) do
        local keep
        if id == "yours" then keep = not d.raid and self:IsForLevel(d)
        elseif id == "raids" then keep = d.raid == true
        elseif id == "all" then keep = true
        else
            for _, b in ipairs(BANDS) do
                if b.id == id then keep = not d.raid and d.min >= b.min and d.min <= b.max end
            end
        end
        if keep and q ~= "" then
            keep = d.name:lower():find(q, 1, true) ~= nil or (d.nameES or ""):lower():find(q, 1, true) ~= nil
        end
        if keep then out[#out + 1] = d end
    end
    return out
end

function Dungeons:GetCategories()
    local out = {
        { id = "yours", label = L("UI_DG_YOURLEVEL") },
        { id = "all", label = L("UI_DG_ALL") },
    }
    for _, b in ipairs(BANDS) do out[#out + 1] = { id = b.id, label = b.label } end
    out[#out + 1] = { id = "raids", label = L("UI_DG_RAIDS") }
    return out
end

function Dungeons:CountCategory(id) return #self:List(id) end

-- Quests of a dungeon the player's faction can take, sorted by level.
function Dungeons:QuestsFor(d)
    local DB, out = AR.DB, {}
    for _, qid in ipairs(d.quests or {}) do
        local q = DB:GetQuest(qid)
        if q and DB:IsForPlayer(q.side) then out[#out + 1] = q end
    end
    table.sort(out, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.name < b.name
    end)
    return out
end

function Dungeons:GetRows(id)
    local rows = {}
    for _, d in ipairs(self:List(id)) do
        local tag = d.min == d.max and tostring(d.min) or string.format("%d-%d", d.min, d.max)
        rows[#rows + 1] = { text = AR.DB:DungeonName(d), tag = tag, data = d }
    end
    return rows
end

function Dungeons:HeaderTitle() return L("UI_DUNGEONS", "Dungeons") end

function Dungeons:HeaderSub()
    return string.format(L("UI_DG_SUB_FMT"), #((AR.DB and AR.DB.Dungeons) or {}))
end

function Dungeons:Describe(row)
    local d = row and row.data
    if not d then return {} end
    local zone = AR.Lookup and AR.Lookup.ZoneName(d.zone) or tostring(d.zone)
    local quests = self:QuestsFor(d)
    local chips = { { text = string.format(L("UI_LEVELS_FMT", "Levels %d-%d"), d.min, d.max), accent = true } }
    if not d.raid and self:IsForLevel(d) then chips[#chips + 1] = { text = L("UI_YOUR_LEVEL"), accent = true } end
    if d.raid then chips[#chips + 1] = { text = L("UI_DG_RAID") } end
    local list = {}
    for _, q in ipairs(quests) do
        list[#list + 1] = {
            text = AR.Skins:Colorize(q.name, "quest"),
            tag = tostring(q.level),
            onClick = function()
                local loc = AR.DB:LocationOf(q)
                if loc and AR.Lookup then AR.Lookup:Navigate(loc) end
            end,
        }
    end
    return {
        title = AR.DB:DungeonName(d),
        subtitle = zone,
        chips = chips,
        info = {
            { L("UI_LK_ZONE"), zone },
            { L("UI_DG_QUESTS"), #quests > 0 and string.format(L("UI_DG_QUESTS_FMT"), #quests) or L("UI_DG_NOQUESTS") },
        },
        list = list,
        primary = { text = L("UI_LK_SHOW_MAP"), onClick = function()
            local wm = _G.WorldMapFrame
            if wm and not (wm.IsShown and wm:IsShown()) then
                if _G.ToggleWorldMap then _G.ToggleWorldMap() elseif wm.Show then wm:Show() end
            end
            if wm and wm.SetMapID then wm:SetMapID(d.zone) end
        end },
    }
end

function Dungeons:Attach(frame)
    if self.panel then return self.panel end
    self.panel = AR.MenuPanel:New(self)
    self.panel:Attach(frame, "AzerothRouteDungeons")
    return self.panel
end

return Dungeons
