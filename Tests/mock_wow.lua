-- AzerothRoute 2 headless checks: a permissive WoW API.
-- Known APIs get small working versions; any other global resolves to a stub namespace whose
-- functions return nil, and every frame accepts any method. It is enough to load the addon's files
-- and run its start-up events, which is what tells a broken rename (a missing module, global or
-- event handler) from working code. It does not check drawing or game data.

local M = { frames = {}, timers = {}, errors = {}, now = 1000, player = {}, saved = {} }
_G.MockWoW = M

M.player = { name = "Pato", realm = "Forever", race = "Orc", class = "PALADIN", className = "Paladin",
    faction = "Horde", level = 18, locale = "esMX", map = 1413 }

-- A stub is indexable (nested namespaces such as Enum.X.Y) and callable (returns nil).
local function stubNamespace(name)
    return setmetatable({}, {
        __index = function(t, k)
            local v = stubNamespace(tostring(name) .. "." .. tostring(k))
            rawset(t, k, v)
            return v
        end,
        __call = function() return nil end,
        __tostring = function() return "stub:" .. tostring(name) end,
    })
end

-- Frames --------------------------------------------------------------------------------------

local NUMERIC = {
    GetWidth = 100, GetHeight = 20, GetScale = 1, GetEffectiveScale = 1, GetAlpha = 1, GetFrameLevel = 1,
    GetLeft = 0, GetRight = 100, GetTop = 20, GetBottom = 0, GetValue = 0, GetNumPoints = 0,
    GetStringWidth = 40, GetStringHeight = 12, GetNumLines = 0, GetID = 0, GetDepth = 0,
    GetVerticalScroll = 0, GetHorizontalScroll = 0, GetVerticalScrollRange = 0, GetHorizontalScrollRange = 0,
    GetDuration = 0, GetProgress = 0, GetElapsed = 0, GetSmoothProgress = 0, GetNumChildren = 0,
    GetNumRegions = 0, GetFrameLevelOffset = 0, GetCursorPosition = 0, GetNumLetters = 0, GetMaxLetters = 0,
    GetTextHeight = 12, GetUnboundedStringWidth = 40, GetLineHeight = 12, GetSpacing = 0, GetNumber = 0,
}

local Frame = {}
local FrameMeta

local function newFrame(kind, name, parent)
    local f = setmetatable({ _kind = kind, _name = name, _parent = parent, _scripts = {}, _events = {},
        _attrs = {}, _shown = true, _text = "", _points = {} }, FrameMeta)
    if name and name ~= "" then _G[name] = f end
    M.frames[#M.frames + 1] = f
    return f
end

function Frame:GetName() return self._name end
function Frame:GetParent() return self._parent end
function Frame:GetObjectType() return self._kind end
function Frame:IsObjectType(t) return self._kind == t end
function Frame:SetScript(k, fn) self._scripts[k] = fn end
function Frame:GetScript(k) return self._scripts[k] end
function Frame:HasScript() return true end
function Frame:HookScript(k, fn)
    local prev = self._scripts[k]
    self._scripts[k] = function(...)
        if prev then prev(...) end
        return fn(...)
    end
end
function Frame:RegisterEvent(e) self._events[e] = true return true end
function Frame:RegisterUnitEvent(e) self._events[e] = true return true end
function Frame:UnregisterEvent(e) self._events[e] = nil end
function Frame:UnregisterAllEvents() self._events = {} end
function Frame:IsEventRegistered(e) return self._events[e] == true end
function Frame:Show() self._shown = true end
function Frame:Hide() self._shown = false end
function Frame:SetShown(v) self._shown = v and true or false end
function Frame:IsShown() return self._shown end
function Frame:IsVisible() return self._shown end
function Frame:SetText(t) self._text = t end
function Frame:GetText() return self._text end
function Frame:SetFormattedText(fmt, ...) self._text = string.format(fmt, ...) end
function Frame:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function Frame:GetTextColor() return 1, 1, 1, 1 end
function Frame:SetVertexColor(r, g, b, a) self._vc = { r, g, b, a or 1 } end
function Frame:GetVertexColor() local c = self._vc if c then return c[1], c[2], c[3], c[4] end return 1, 1, 1, 1 end
function Frame:SetAlpha(a) self._alpha = a end
function Frame:GetAlpha() return self._alpha or 1 end
function Frame:GetPoint() return nil end
function Frame:GetSize() return 100, 20 end
function Frame:GetCenter() return 50, 10 end
function Frame:GetRect() return 0, 0, 100, 20 end
function Frame:GetRegions() return end
function Frame:GetChildren() return end
function Frame:GetAttribute(k) return self._attrs[k] end
function Frame:SetAttribute(k, v) self._attrs[k] = v end
function Frame:GetTexture() return self._texture end
function Frame:SetTexture(t) self._texture = t return true end
function Frame:GetAtlas() return nil end
function Frame:GetTexCoord() return 0, 1, 0, 1 end
function Frame:GetMinMaxValues() return 0, 1 end
function Frame:GetCursorPosition() return 0 end
function Frame:GetLoopState() return "NONE" end
function Frame:GetStatusBarTexture() return newFrame("Texture") end
function Frame:GetFontString() return self._fs or newFrame("FontString") end
function Frame:GetNormalTexture() return newFrame("Texture") end
function Frame:GetHighlightTexture() return newFrame("Texture") end
function Frame:GetPushedTexture() return newFrame("Texture") end
function Frame:GetDisabledTexture() return newFrame("Texture") end
function Frame:GetCheckedTexture() return newFrame("Texture") end
function Frame:GetScrollChild() return self._child end
function Frame:SetScrollChild(c) self._child = c end
function Frame:Click(button)
    local fn = self._scripts.OnClick
    if fn then fn(self, button or "LeftButton", false) end
end
for _, ctor in ipairs({ "CreateTexture", "CreateFontString", "CreateMaskTexture", "CreateLine",
    "CreateAnimationGroup", "CreateAnimation" }) do
    Frame[ctor] = function(self, name) return newFrame(ctor:sub(7), name, self) end
end

FrameMeta = {
    __index = function(t, k)
        local m = Frame[k]
        if m then return m end
        if NUMERIC[k] then
            local v = NUMERIC[k]
            return function() return v end
        end
        if type(k) ~= "string" then return nil end
        -- A field the addon keeps on a frame (lower case) is data: nil until set.
        if not k:match("^%u") then return nil end
        if k:match("^Is") or k:match("^Has") or k:match("^Can") then
            return function() return false end
        end
        return function() return nil end
    end,
}

_G.CreateFrame = function(kind, name, parent) return newFrame(kind or "Frame", name, parent) end
-- A font object (an edit box gets its own, Theme.OwnFont).
_G.CreateFont = function(name) return newFrame("Font", name) end

function M:Fire(event, ...)
    local errs = 0
    for _, f in ipairs(self.frames) do
        if f._events[event] and f._scripts.OnEvent then
            local ok, err = pcall(f._scripts.OnEvent, f, event, ...)
            if not ok then
                errs = errs + 1
                self.errors[#self.errors + 1] = event .. ": " .. tostring(err)
            end
        end
    end
    return errs
end

function M:RunTimers(rounds)
    for _ = 1, rounds or 3 do
        local list = self.timers
        self.timers = {}
        for _, fn in ipairs(list) do
            local ok, err = pcall(fn)
            if not ok then self.errors[#self.errors + 1] = "timer: " .. tostring(err) end
        end
    end
end

-- APIs ----------------------------------------------------------------------------------------

local P = M.player
_G.UIParent = newFrame("Frame", "UIParent")
_G.WorldFrame = newFrame("Frame", "WorldFrame")
_G.Minimap = newFrame("Minimap", "Minimap")
_G.WorldMapFrame = newFrame("Frame", "WorldMapFrame")
_G.GameTooltip = newFrame("GameTooltip", "GameTooltip")
_G.ItemRefTooltip = newFrame("GameTooltip", "ItemRefTooltip")
_G.DEFAULT_CHAT_FRAME = newFrame("ScrollingMessageFrame", "DEFAULT_CHAT_FRAME")

_G.GetLocale = function() return P.locale end
_G.date, _G.time = os.date, os.time
_G.GetTime = function() return M.now end
_G.GetServerTime = function() return 1763600000 end
_G.GetBuildInfo = function() return "1.60.1", "70888", "Nov 1 2026", 16001 end
_G.UnitName = function() return P.name, P.realm end
_G.UnitRace = function() return P.race, P.race, 2 end
_G.UnitClass = function() return P.className, P.class, 2 end
_G.UnitFactionGroup = function() return P.faction, P.faction end
_G.UnitLevel = function() return P.level end
_G.UnitGUID = function() return "Player-1-0000001" end
_G.UnitSex = function() return 2 end
_G.UnitExists = function(u) return u == "player" end
_G.UnitIsDeadOrGhost = function() return false end
_G.UnitXP = function() return 0 end
_G.UnitXPMax = function() return 1000 end
_G.GetRealmName = function() return P.realm end
_G.GetMoney = function() return 0 end
_G.InCombatLockdown = function() return false end
_G.IsLoggedIn = function() return true end
_G.GetCVar = function() return nil end
_G.GetCVarBool = function() return false end
_G.SetCVar = function() end
_G.IsShiftKeyDown = function() return false end
_G.IsControlKeyDown = function() return false end
_G.IsAltKeyDown = function() return false end
_G.GetScreenWidth = function() return 1920 end
_G.GetScreenHeight = function() return 1080 end
_G.GetCursorPosition = function() return 0, 0 end
_G.GetFramerate = function() return 60 end
_G.debugprofilestop = function() return M.now * 1000 end
_G.GetNumAddOns = function() return 0 end
_G.hooksecurefunc = function(t, name, fn)
    if type(t) == "string" then t, name, fn = _G, t, name end
    local orig = t[name]
    if type(orig) ~= "function" and not (type(orig) == "table" and getmetatable(orig)) then return end
    t[name] = function(...)
        local r = { orig(...) }
        fn(...)
        return unpack(r)
    end
end
_G.securecall = function(fn, ...) if type(fn) == "function" then return fn(...) end end
_G.geterrorhandler = function() return function(e) M.errors[#M.errors + 1] = "handler: " .. tostring(e) end end
_G.seterrorhandler = function() end
_G.issecretvalue = function() return false end
_G.C_Timer = {
    After = function(_, fn) M.timers[#M.timers + 1] = fn end,
    NewTimer = function(_, fn) M.timers[#M.timers + 1] = fn return { Cancel = function() end, IsCancelled = function() return false end } end,
    NewTicker = function(_, fn) M.timers[#M.timers + 1] = fn return { Cancel = function() end, IsCancelled = function() return false end } end,
}
_G.C_AddOns = {
    IsAddOnLoaded = function(name) return name == "AzerothRoute" end,
    GetAddOnMetadata = function(name, field)
        if field == "Version" then return "0.4.1.1" end
        return nil
    end,
    GetAddOnInfo = function(name) return name, name, "", true, nil, nil, false end,
    GetAddOnEnableState = function() return 2 end,
    LoadAddOn = function() return false, "MISSING" end,
    GetNumAddOns = function() return 0 end,
    DoesAddOnExist = function(name) return name == "AzerothRoute" end,
}
_G.IsAddOnLoaded = _G.C_AddOns.IsAddOnLoaded
_G.GetAddOnMetadata = _G.C_AddOns.GetAddOnMetadata
_G.LoadAddOn = _G.C_AddOns.LoadAddOn
_G.SlashCmdList = {}
_G.StaticPopupDialogs = {}
_G.UISpecialFrames = {}
_G.RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1, colorStr = "ffffffff" } end })

-- Lua helpers WoW adds.
_G.strsplit = function(sep, s, limit)
    local out, start = {}, 1
    while true do
        if limit and #out == limit - 1 then out[#out + 1] = s:sub(start) break end
        local i, j = s:find(sep, start, true)
        if not i then out[#out + 1] = s:sub(start) break end
        out[#out + 1] = s:sub(start, i - 1)
        start = j + 1
    end
    return unpack(out)
end
_G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
_G.strjoin = function(sep, ...) return table.concat({ ... }, sep) end
_G.strlower, _G.strupper, _G.strlen, _G.strsub, _G.strfind = string.lower, string.upper, string.len, string.sub, string.find
_G.strmatch, _G.gsub, _G.format, _G.strrep, _G.strbyte, _G.strchar = string.match, string.gsub, string.format, string.rep, string.byte, string.char
_G.tinsert, _G.tremove, _G.tconcat, _G.sort = table.insert, table.remove, table.concat, table.sort
_G.floor, _G.ceil, _G.abs, _G.min, _G.max, _G.sqrt, _G.random = math.floor, math.ceil, math.abs, math.min, math.max, math.sqrt, math.random
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.tContains = function(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
_G.CopyTable = function(t)
    local function copy(x) if type(x) ~= "table" then return x end local o = {} for k, v in pairs(x) do o[k] = copy(v) end return o end
    return copy(t)
end
_G.Mixin = function(o, ...) for _, m in ipairs({ ... }) do for k, v in pairs(m) do o[k] = v end end return o end
_G.CreateFromMixins = function(...) return _G.Mixin({}, ...) end
_G.bit = _G.bit or require("bit")

-- Any other global: a stub namespace.
setmetatable(_G, {
    __index = function(t, k)
        if type(k) ~= "string" then return nil end
        -- Lua's own optional names, lower-case names and CONSTANTS stay nil: code reads them as
        -- "X or default".
        if M.saved[k] then return nil end
        if k == "jit" or k == "arg" or k:match("^_") or not k:match("^%u") or k:match("^[%u%d_]+$") then return nil end
        local v = stubNamespace(k)
        rawset(t, k, v)
        return v
    end,
})

return M
