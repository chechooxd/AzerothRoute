-- AzerothRoute: Characters mode of the Guide Center.
-- Each character keeps a snapshot in AR.db.global.characters["Name-Realm"]: level, class, race,
-- faction, gold, zone, the guide and step it is on, rested XP and when it was last played.
-- Snapshots refresh on login, level-up, money changes, step changes and logout.

local AR = _G.AzerothRoute
local Characters = { MODE = "characters", query = "", _registered = false }
AR.Characters = Characters

local function L(key, fallback)
    if AR.L then
        local v = AR.L:Get(key)
        if v and v ~= key then return v end
    end
    return fallback or key
end

local function store()
    if not AR.db or not AR.db.global then return {} end
    AR.db.global.characters = AR.db.global.characters or {}
    return AR.db.global.characters
end

function Characters:Reset()
    self.query = ""
    if self.panel and self.panel.side then
        self.panel.side:Hide()
        self.panel.main:Hide()
    end
    self.panel = nil
end

function Characters:CurrentKey()
    local name = _G.UnitName and _G.UnitName("player")
    local realm = _G.GetRealmName and _G.GetRealmName()
    if not name then return nil end
    return name .. "-" .. (realm or "?")
end

-- Records the logged-in character. Returns the snapshot.
function Characters:Snapshot()
    local key = self:CurrentKey()
    if not key then return nil end
    local P = AR.Progression
    local guide = P and P.currentGuide
    local map = AR.Coords and AR.Coords:GetPlayerPosition()
    local classFile = _G.UnitClass and select(2, _G.UnitClass("player"))
    local snap = {
        name = _G.UnitName("player"),
        realm = (_G.GetRealmName and _G.GetRealmName()) or "?",
        class = classFile,
        className = _G.UnitClass and _G.UnitClass("player") or classFile,
        race = _G.UnitRace and _G.UnitRace("player") or nil,
        faction = _G.UnitFactionGroup and _G.UnitFactionGroup("player") or nil,
        level = (_G.UnitLevel and _G.UnitLevel("player")) or 1,
        money = (_G.GetMoney and _G.GetMoney()) or 0,
        rested = (_G.GetXPExhaustion and _G.GetXPExhaustion()) or 0,
        xpMax = (_G.UnitXPMax and _G.UnitXPMax("player")) or 0,
        map = map,
        guide = guide and guide.title or nil,
        step = P and P.currentStep and P.currentStep.num or nil,
        steps = guide and guide.steps and #guide.steps or nil,
        updated = (_G.time and _G.time()) or os.time(),
    }
    store()[key] = snap
    return snap
end

function Characters:Forget(key)
    if key and key ~= self:CurrentKey() then store()[key] = nil return true end
    return false
end

function Characters:RegisterLiveEvents()
    if self._registered or not AR.Events then return end
    self._registered = true
    local function snap() self:Snapshot() end
    for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "PLAYER_MONEY", "PLAYER_LOGOUT", "ZONE_CHANGED_NEW_AREA" }) do
        AR.Events:RegisterEvent(ev, snap)
    end
    if AR.Events.RegisterMessage then AR.Events:RegisterMessage("AR_STEP_CHANGED", snap) end
end

-- Panel data ----------------------------------------------------------------------------------

function Characters:SetQuery(q)
    self.query = tostring(q or "")
    if self.panel then
        self.panel.page = 0
        self.panel:Render()
    end
end

function Characters:List(id)
    local q = (self.query or ""):lower()
    local me = store()[self:CurrentKey() or ""]
    local out = {}
    for key, c in pairs(store()) do
        local keep = id == "all" or (id == "faction" and me and c.faction == me.faction) or (id == "realm" and me and c.realm == me.realm)
        if keep and q ~= "" then keep = (c.name or ""):lower():find(q, 1, true) ~= nil end
        if keep then out[#out + 1] = { key = key, c = c } end
    end
    table.sort(out, function(a, b)
        if (a.c.level or 0) ~= (b.c.level or 0) then return (a.c.level or 0) > (b.c.level or 0) end
        return a.key < b.key
    end)
    return out
end

function Characters:GetCategories()
    return {
        { id = "all", label = L("UI_CHARACTERS", "Characters") },
        { id = "faction", label = L("UI_CHARS_FACTION", "This faction") },
        { id = "realm", label = L("UI_CHARS_REALM", "This realm") },
    }
end

function Characters:CountCategory(id) return #self:List(id) end

local function classColored(c)
    local colors = _G.RAID_CLASS_COLORS
    local col = colors and c.class and colors[c.class]
    if col and col.colorStr then return "|c" .. col.colorStr .. c.name .. "|r" end
    return c.name or "?"
end

function Characters:GetRows(id)
    local rows = {}
    local current = self:CurrentKey()
    for _, e in ipairs(self:List(id)) do
        local tag = tostring(e.c.level or "?")
        if e.key == current then tag = tag .. " · " .. L("UI_CHARS_YOU", "you") end
        rows[#rows + 1] = { text = classColored(e.c), tag = tag, data = e }
    end
    return rows
end

function Characters:HeaderTitle() return L("UI_CHARACTERS", "Characters") end

function Characters:HeaderSub(total)
    local gold = 0
    for _, c in pairs(store()) do gold = gold + (c.money or 0) end
    local money = AR.ClassSpells and AR.ClassSpells:FormatMoney(gold) or tostring(gold)
    return string.format(L("UI_CHARS_SUB_FMT", "%d characters · %s in total"), total or 0, money)
end

function Characters:Describe(row)
    local e = row and row.data
    if not e then return {} end
    local c = e.c
    local CS = AR.ClassSpells
    local zone = c.map and AR.Lookup and AR.Lookup.ZoneName(c.map) or "-"
    local info = {
        { L("UI_LK_LEVEL", "Level"), tostring(c.level or "?") },
        { L("UI_CHARS_CLASS", "Class"), (string.format("%s %s", c.race or "", c.className or c.class or ""):gsub("^%s+", "")) },
        { L("UI_LK_SIDE", "Faction"), c.faction or "-" },
        { L("UI_CHARS_GOLD", "Gold"), CS and CS:FormatMoney(c.money or 0) or tostring(c.money) },
        { L("UI_LK_ZONE", "Zone"), zone },
    }
    if c.guide then
        local short = c.guide:match("([^\\]+)$") or c.guide
        info[#info + 1] = { L("UI_GUIDES", "Guide"), string.format("%s · %d/%d", short, c.step or 1, c.steps or 1) }
    end
    if (c.rested or 0) > 0 and (c.xpMax or 0) > 0 then
        info[#info + 1] = { L("UI_CHARS_RESTED", "Rested"), string.format("%d%%", math.floor(c.rested / c.xpMax * 100 + 0.5)) }
    end
    local chips = { { text = L("UI_LK_LEVEL", "Level") .. " " .. tostring(c.level or "?"), accent = true }, { text = c.realm or "?" } }
    local isMe = e.key == self:CurrentKey()
    return {
        title = c.name,
        subtitle = string.format(L("UI_CHARS_PLAYED_FMT", "Last played %s"), AR.Rares and AR.Rares:Ago(c.updated) or ""),
        chips = chips,
        info = info,
        secondary = (not isMe) and { text = L("UI_CHARS_FORGET", "Forget this character"), onClick = function()
            self:Forget(e.key)
            if self.panel then self.panel:Render() end
        end } or nil,
    }
end

function Characters:Attach(frame)
    if self.panel then return self.panel end
    self:Snapshot()
    self.panel = AR.MenuPanel:New(self)
    self.panel:Attach(frame, "AzerothRouteCharacters")
    return self.panel
end

return Characters
