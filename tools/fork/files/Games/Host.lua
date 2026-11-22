-- AzerothRoute: the game window for flights (Maps/Arcade.lua offers it on a long flight; /ar arcade and
-- the guide window's menu open it any time). It holds AzerothRoute's own light games, one at a time, with
-- a tab for each in its top bar, the score and best, pause and game over. While it is open it takes the
-- keyboard (Esc closes it, P pauses); closing it pauses the game, which goes on where it was when it opens
-- again. Original AzerothRoute code (GPL-3.0-only).
--
-- A game registers itself:
--   Games.Register({ id, name, blurb, keys, width, height, order, New = function(view, host) return game end })
--     view: the frame the game draws in (width x height, origin top left); host: see below.
--   game:Reset()          a new game in its start state, drawn (called before the first start and on play again)
--   game:Update(dt)       one frame while running (dt in seconds, at most 0.05)
--   game:Key(key, down)   a key went down (down = true) or up: WoW key names ("LEFT", "RIGHT", "UP", "DOWN",
--                         "SPACE", "A", "D", "W", "S", ...); true when the game used it
--   host.Score(n)         the score shown in the bar
--   host.Over(score)      the game is over: the host shows it and keeps the best
--   host.Best()           the best score of this game so far
--   host.Media(name)      the path of Media/Arcade/<name>
--   host.Color(name)      r, g, b of a theme colour ("accent", "text", "textDim", "danger", ...)
--
--   Games.Open(id)  Games.Close() -> closed   Games.IsOpen()   Games.Current() -> id   Games.List() -> defs
--   Games.State() -> "ready" | "run" | "pause" | "over" | nil

local ADDON, ns = ...
local L = ns.L

local Games = { defs = {}, order = {} }
ns.Games = Games

local PAD, BAR_H, FOOT_H = 12, 34, 24
local MAX_DT = 0.05
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Arcade\\"

local win -- the window
local slots = {} -- id -> { game, view, state, score }
local current -- id of the game shown

local function store()
    local db = _G.AzerothRouteDB
    if type(db) ~= "table" then return nil end
    db.arcade = type(db.arcade) == "table" and db.arcade or {}
    db.arcade.best = type(db.arcade.best) == "table" and db.arcade.best or {}
    return db.arcade
end

function Games.Register(def)
    if type(def) ~= "table" or type(def.id) ~= "string" or type(def.New) ~= "function" then return end
    if not Games.defs[def.id] then Games.order[#Games.order + 1] = def.id end
    Games.defs[def.id] = def
    table.sort(Games.order, function(a, b) return (Games.defs[a].order or 50) < (Games.defs[b].order or 50) end)
end

function Games.List()
    local out = {}
    for _, id in ipairs(Games.order) do out[#out + 1] = Games.defs[id] end
    return out
end

function Games.Best(id)
    local s = store()
    return s and tonumber(s.best[id]) or 0
end

local function setBest(id, score)
    local s = store()
    if s and score > (tonumber(s.best[id]) or 0) then s.best[id] = score return true end
    return false
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------

local paint, keyDown, keyUp

local function overlay(parent)
    local o = CreateFrame("Frame", nil, parent)
    o:SetAllPoints(parent)
    o:SetFrameLevel(parent:GetFrameLevel() + 20)
    o.Shade = o:CreateTexture(nil, "BACKGROUND")
    o.Shade:SetAllPoints(o)
    o.Shade:SetColorTexture(0, 0, 0, 0.62)
    local W = ns.Widgets
    o.Title = W.Text(o, "display", "accent")
    o.Title:SetPoint("CENTER", o, "CENTER", 0, 18)
    o.Title:SetJustifyH("CENTER")
    o.Line = W.Text(o, "body", "text")
    o.Line:SetPoint("TOP", o.Title, "BOTTOM", 0, -10)
    o.Line:SetJustifyH("CENTER")
    o.Hint = W.Text(o, "note", "textDim")
    o.Hint:SetPoint("TOP", o.Line, "BOTTOM", 0, -8)
    o.Hint:SetJustifyH("CENTER")
    return o
end

local function build()
    local W, Theme = ns.Widgets, ns.Theme
    if not (W and Theme) then return nil end
    local f = CreateFrame("Frame", "AzerothRouteGamesFrame", ns.UIParent or UIParent)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f.psLight = true
    Theme.Skin(f, "window")
    f:Hide()

    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    bar:SetHeight(BAR_H)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() f:StartMoving() end)
    bar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    f.Bar = bar
    f.Close = W.IconButton(bar, "close", 22, L["Close"], function() Games.Close() end)
    f.Close:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    f.Score = W.Text(bar, "number", "accent")
    f.Score:SetPoint("RIGHT", f.Close, "LEFT", -10, 0)
    f.Score:SetJustifyH("RIGHT")
    f.Tabs = {}

    f.Body = CreateFrame("Frame", nil, f)
    f.Body:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -BAR_H)
    f.BodyBack = f.Body:CreateTexture(nil, "BACKGROUND")
    f.BodyBack:SetAllPoints(f.Body)
    f.BodyBack:SetColorTexture(0.02, 0.05, 0.1, 1)

    f.Keys = W.Text(f, "note", "textDim")
    f.Keys:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, 7)
    f.Keys:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 7)

    f.Over = overlay(f.Body)

    f:EnableKeyboard(true)
    f:SetScript("OnKeyDown", function(_, key) keyDown(key) end)
    f:SetScript("OnKeyUp", function(_, key) keyUp(key) end)
    f:SetScript("OnUpdate", ns.Safe and ns.Safe(function(_, dt) Games.Step(dt) end) or function(_, dt) Games.Step(dt) end)
    f:SetScript("OnHide", function()
        local s = current and slots[current]
        if s and s.state == "run" then s.state = "pause" end
    end)
    if Theme.OnChanged then Theme.OnChanged(function() if f:IsShown() then paint() end end) end
    return f
end

-- One tab per game in the bar, left of the score.
local function tabs()
    local W = ns.Widgets
    local x = PAD
    for i, id in ipairs(Games.order) do
        local def = Games.defs[id]
        local t = win.Tabs[i]
        if not t then
            t = W.Button(win.Bar, def.name, nil, { ghost = true, height = 24 })
            win.Tabs[i] = t
        end
        W.SetButtonText(t, def.name)
        t:SetScript("OnClick", function() Games.Open(id) end)
        t:ClearAllPoints()
        t:SetPoint("LEFT", win.Bar, "LEFT", x, 0)
        if W.SetActive then W.SetActive(t, id == current) elseif t.Label then W.Color(t.Label, id == current and "accent" or "textDim") end
        t:Show()
        x = x + t:GetWidth() + 4
    end
end

local function slot(id)
    local s = slots[id]
    if s then return s end
    local def = Games.defs[id]
    local view = CreateFrame("Frame", nil, win.Body)
    view:SetPoint("TOPLEFT", win.Body, "TOPLEFT", 0, 0)
    view:SetSize(def.width, def.height)
    if view.SetClipsChildren then view:SetClipsChildren(true) end
    s = { view = view, state = "ready", score = 0 }
    local host = {
        Score = function(n) s.score = n or 0 if current == id then paint() end end,
        Over = function(score)
            s.score = score or s.score
            s.newBest = setBest(id, s.score)
            s.state = "over"
            if current == id then paint() end
        end,
        Best = function() return Games.Best(id) end,
        Media = function(name) return MEDIA .. name end,
        Color = function(name)
            local T = ns.Theme
            if T and T.Color then return T.Color(name) end
            return 1, 1, 1
        end,
    }
    slots[id] = s
    s.game = def.New(view, host)
    if s.game and s.game.Reset then s.game:Reset() end
    return s
end

function paint()
    if not (win and current) then return end
    local def, s = Games.defs[current], slots[current]
    win:SetSize(def.width + 2 * PAD, def.height + BAR_H + FOOT_H + 6)
    win.Body:SetSize(def.width, def.height)
    for id, other in pairs(slots) do other.view:SetShown(id == current) end
    tabs()
    win.Score:SetText(L["Score %d   Best %d"]:format(s.score or 0, math.max(Games.Best(current), s.score or 0)))
    win.Keys:SetText((def.keys or "") .. "   " .. L["P: pause   Esc: close"])
    local o = win.Over
    if s.state == "run" then
        o:Hide()
    else
        o:Show()
        if s.state == "ready" then
            o.Title:SetText(def.name)
            o.Line:SetText(def.blurb or "")
            o.Hint:SetText(L["Space to start"])
        elseif s.state == "pause" then
            o.Title:SetText(L["Paused"])
            o.Line:SetText(L["Score %d"]:format(s.score or 0))
            o.Hint:SetText(L["Space or P to go on"])
        else
            o.Title:SetText(L["Game over"])
            o.Line:SetText(s.newBest and L["New best: %d"]:format(s.score or 0) or L["Score %d   Best %d"]:format(s.score or 0, Games.Best(current)))
            o.Hint:SetText(L["Space to play again"])
        end
    end
end

-- The keyboard is ours while the window is open (never set in combat: it is protected there).
local function takeKeys(on)
    if not win or not win.SetPropagateKeyboardInput then return end
    if InCombatLockdown and InCombatLockdown() then return end
    pcall(win.SetPropagateKeyboardInput, win, not on)
end

local START = { SPACE = true, ENTER = true }

function keyDown(key)
    local s = current and slots[current]
    if not s then return end
    if key == "ESCAPE" then Games.Close() return end
    if key == "P" and (s.state == "run" or s.state == "pause") then
        s.state = s.state == "run" and "pause" or "run"
        paint()
        return
    end
    if s.state ~= "run" then
        if START[key] then
            if s.state == "over" then
                s.score, s.newBest = 0, nil
                if s.game.Reset then s.game:Reset() end
            end
            s.state = "run"
            paint()
        end
        return
    end
    if s.game.Key then s.game:Key(key, true) end
end

-- A key going up always reaches the game, paused or not, so it never keeps a key held that was let go.
function keyUp(key)
    local s = current and slots[current]
    if s and s.game.Key then s.game:Key(key, false) end
end

-- One frame: the shown game moves while it runs.
function Games.Step(dt)
    local s = current and slots[current]
    if not (s and s.state == "run" and s.game.Update) then return end
    s.game:Update(math.min(dt or 0, MAX_DT))
end

function Games.Open(id)
    if ns.Compat and ns.Compat.InCombat and ns.Compat.InCombat() then
        ns.Print(L["The games open after the fight."])
        return false
    end
    id = id or current or Games.order[1]
    if not (id and Games.defs[id]) then return false end
    if not win then win = build() end
    if not win then return false end
    local prev = current and slots[current]
    if prev and prev.state == "run" and current ~= id then prev.state = "pause" end
    current = id
    slot(id)
    paint()
    if not win:IsShown() then
        win:ClearAllPoints()
        win:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        win:Show()
    end
    takeKeys(true)
    Games.last = id
    return true
end

-- Closes the window; a running game is paused (it goes on from there). -> whether it was open.
function Games.Close()
    if not (win and win:IsShown()) then return false end
    local s = current and slots[current]
    if s and s.state == "run" then s.state = "pause" end
    takeKeys(false)
    win:Hide()
    return true
end

function Games.IsOpen() return win ~= nil and win:IsShown() end
function Games.Current() return current end
function Games.State() local s = current and slots[current] return s and s.state or nil end
function Games.Window() return win end
function Games.Game(id) local s = slots[id or current] return s and s.game end
