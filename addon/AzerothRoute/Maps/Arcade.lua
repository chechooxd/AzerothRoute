-- AzerothRoute: games on flights. AzerothRoute's own light games (Games/Host.lua and the games it holds)
-- to play while the flight timer counts down, in place of the game Polestar offered there
-- (Integrations > Flight games, maps.flightArcade). Built on Polestar's flight offer (GPL-3.0-only):
--
-- On a flight with the timer's ETA (Maps.GetFlight) at MIN_LEFT seconds or more, out of combat and
-- outside instances, with the game window closed: once per flight a card under the flight timer asks
-- "Long flight ahead. Play while you wait?" with a button for each game, Not now and Don't ask again
-- (the setting off); after it, a row with the games while the conditions hold. LANDING seconds before
-- arrival with the window open: the banner says so (Nav.alerts.ShowNotice) and the game is paused and
-- closed so the keys are the character's again. The landing itself (a loading screen ends a flight too)
-- and a fight on the way do the same; a chat line says how to go on. /ar arcade and the guide window's
-- menu open the games any time.
--
-- Cost: with the setting off nothing is made and nothing runs on a flight. On, a flight makes one hidden
-- driver frame (the first flight only), shown for the flight, ticking twice a second, and listens for a
-- fight while it lasts; the card is built on the first offer. Opening a game on a flight (the card's
-- buttons, the command) also starts the landing guard, the setting off or not.

local ADDON, ns = ...
local Maps = ns.Maps
local L = ns.L

local floor, max = math.floor, math.max

local MIN_LEFT = 60 -- seconds of flight left to offer the games
local LANDING = 10  -- seconds before arrival: the game is put away
local TICK = 0.5
local PROMPT_W, MAX_LINE, PAD, BTN_H = 320, 380, 12, 24

ns.RegisterDefaults("maps", { flightArcade = true })

local Arcade = { MIN_LEFT = MIN_LEFT, LANDING = LANDING }
ns.Arcade = Arcade

---------------------------------------------------------------------------
-- The games
---------------------------------------------------------------------------

local function games() return ns.Games end

-- The games are there (keyboard games: not with the gamepad interface).
function Arcade.Available()
    if ns.GamepadUI and ns.GamepadUI() then return false end
    local G = games()
    return G ~= nil and #G.order > 0
end

function Arcade.IsOpen()
    local G = games()
    return G ~= nil and G.IsOpen()
end

-- Opens a game (the last one played, else the first, when id is nil). -> open after
local function openGame(id)
    local G = games()
    if not (G and Arcade.Available()) then return false end
    return G.Open(id) and true or false
end

-- Pauses and closes it: closed, kept (the game goes on from where it was).
function Arcade.PutAway()
    local G = games()
    if not (G and G.IsOpen()) then return false, false end
    local closed = G.Close()
    return closed, closed
end

function Arcade.ResumeCommand() return "/ar arcade" end

ns.RegisterCommand("arcade", function() Arcade.Open() end, L["Play a game"])

---------------------------------------------------------------------------
-- The card under the flight timer
---------------------------------------------------------------------------

local card

local function timer() return _G.AzerothRouteFlightTimer end

-- One button per game in a row frame, laid left to right; returns the row's width.
local function gameButtons(parent, list, primary)
    local W = ns.Widgets
    parent.Buttons = parent.Buttons or {}
    local G = games()
    local x = 0
    for i, def in ipairs(G and G.List() or {}) do
        local b = parent.Buttons[i]
        if not b then
            b = W.Button(parent, def.name, nil, { primary = primary and i == 1, ghost = not primary, icon = "gamepad", height = BTN_H })
            parent.Buttons[i] = b
        end
        W.SetButtonText(b, def.name)
        b:SetScript("OnClick", function() Arcade.Play(def.id) end)
        b:ClearAllPoints()
        b:SetPoint("LEFT", parent, "LEFT", x, 0)
        b:Show()
        x = x + b:GetWidth() + 6
    end
    return max(0, x - 6)
end

local function build()
    local W, Theme = ns.Widgets, ns.Theme
    local parent = timer()
    if not (W and Theme and parent) then return nil end
    -- A window of its own on AzerothRoute's layer, under the timer at the timer's scale, going when the
    -- timer goes.
    local f = CreateFrame("Frame", "AzerothRouteArcadeOffer", ns.UIParent)
    f:SetFrameStrata(parent:GetFrameStrata())
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    parent:HookScript("OnHide", function() f:Hide() end)
    f.psLight = true
    Theme.Skin(f, "window")
    f:Hide()

    -- The question.
    local q = CreateFrame("Frame", nil, f)
    q:SetAllPoints(f)
    f.Ask = q
    q.Icon = W.Tex(q, "ARTWORK", "gamepad", "accent")
    q.Icon:SetSize(16, 16)
    q.Icon:SetPoint("TOPLEFT", q, "TOPLEFT", PAD, -PAD)
    q.Title = W.Text(q, "body", "text")
    q.Title:SetPoint("TOPLEFT", q.Icon, "TOPRIGHT", 8, 1)
    q.Title:SetPoint("RIGHT", q, "RIGHT", -PAD, 0)
    q.Title:SetJustifyH("LEFT")
    q.Title:SetWordWrap(true)
    q.By = W.Text(q, "note", "textDim")
    q.By:SetPoint("TOPLEFT", q.Title, "BOTTOMLEFT", 0, -3)
    q.By:SetPoint("RIGHT", q, "RIGHT", -PAD, 0)
    q.By:SetJustifyH("LEFT")
    q.Picks = CreateFrame("Frame", nil, q)
    q.Picks:SetHeight(BTN_H)
    q.Later = W.Button(q, L["Not now"], function() Arcade.NotNow() end, { height = BTN_H })
    q.Later:SetPoint("BOTTOMRIGHT", q, "BOTTOMRIGHT", -PAD, PAD)
    q.Never = W.Checkbox(q)
    q.Never:SetPoint("BOTTOMLEFT", q, "BOTTOMLEFT", PAD, PAD + (BTN_H - 18) / 2)
    q.NeverText = W.Text(q, "note", "textDim")
    q.NeverText:SetPoint("LEFT", q.Never, "RIGHT", 6, 0)
    q.NeverText:SetPoint("RIGHT", q.Later, "LEFT", -8, 0)
    q.NeverText:SetJustifyH("LEFT")
    q.NeverText:SetWordWrap(false)

    -- The row: a button for each game.
    local row = CreateFrame("Frame", nil, f)
    row:SetHeight(BTN_H)
    f.Row = row

    -- Sized to its words in the look's type: the card to the widest of its lines, the question wrapping
    -- past MAX_LINE.
    function f.Layout(self)
        local mode = self.mode
        self:SetScale(parent:GetScale())
        self:ClearAllPoints()
        self:SetPoint("TOP", parent, "BOTTOM", 0, -6)
        q:SetShown(mode == "ask")
        row:SetShown(mode == "row")
        local pw = floor(parent:GetWidth() + 0.5)
        if mode == "ask" then
            q.Title:SetText(L["Long flight ahead. Play while you wait?"])
            q.By:SetText(L["Light games of AzerothRoute's own. Esc closes them, and they wait for you."])
            q.NeverText:SetText(L["Don't ask again"])
            W.SetButtonText(q.Later, L["Not now"])
            local picks = gameButtons(q.Picks, nil, true)
            q.Picks:SetWidth(picks)
            local foot = PAD + 18 + 6 + q.NeverText:GetStringWidth() + 12 + q.Later:GetWidth() + PAD
            local head = PAD + 24 + max(q.By:GetStringWidth(), math.min(q.Title:GetStringWidth(), MAX_LINE)) + PAD
            local w = math.ceil(max(PROMPT_W, pw, foot, head, picks + 2 * PAD))
            self:SetWidth(w)
            q.Title:SetWidth(w - 2 * PAD - 24)
            q.By:SetWidth(w - 2 * PAD - 24)
            q.Picks:ClearAllPoints()
            q.Picks:SetPoint("BOTTOMLEFT", q, "BOTTOMLEFT", PAD, PAD + BTN_H + 8)
            local h = PAD + q.Title:GetStringHeight() + 3 + q.By:GetStringHeight() + 12 + BTN_H + 8 + max(BTN_H, q.Later:GetHeight()) + PAD
            self:SetHeight(math.ceil(h))
        else
            local picks = gameButtons(row, nil, false)
            row:SetWidth(picks)
            row:ClearAllPoints()
            row:SetPoint("CENTER", self, "CENTER", 0, 0)
            self:SetWidth(max(pw, picks + 8))
            self:SetHeight(BTN_H + 6)
        end
    end
    if Theme.OnChanged then Theme.OnChanged(function() if f:IsShown() then f:Layout() end end) end
    return f
end

local function show(mode)
    if not card then card = build() end
    if not card then return end
    card.mode = mode
    if mode == "ask" then card.Ask.Never:SetChecked(false) end
    card:Layout()
    card:Show()
end

local function hide()
    if card then card:Hide() end
end

-- Builds and shows the card on the live timer for a preview or a render: mode "ask" | "row".
function Arcade.ShowCard(mode) show(mode) end
function Arcade.Card() return card end

---------------------------------------------------------------------------
-- The flight
---------------------------------------------------------------------------

local trip -- this flight: { asked, warned, closedByUs }
local driver, acc

local function enabled()
    return ns.Get("maps.flightArcade") and Arcade.Available()
end

-- May the games be offered now, with `left` seconds of flight to go?
local function offerable(left)
    if not (left and left >= MIN_LEFT and enabled()) then return false end
    if ns.Compat.InCombat() or ns.Compat.IsInInstance() then return false end
    local t = timer()
    return t ~= nil and t:IsShown() and not Arcade.IsOpen()
end

local stopTrip

-- A fight on the way: the game is paused and closed.
local function onFight()
    if not trip then return end
    hide()
    if Arcade.IsOpen() and Arcade.PutAway() then
        ns.Print(L["Your game is paused for the fight: type %s to go on."]:format(Arcade.ResumeCommand()))
    end
end

function Arcade.Tick()
    if not trip then return end
    -- Off with nothing of ours to put away: the flight is none of our business.
    if not ns.Get("maps.flightArcade") and not trip.closedByUs and not Arcade.IsOpen() then
        stopTrip()
        return
    end
    local _, left = Maps.GetFlight()
    if left and left <= LANDING then
        hide()
        if not trip.warned then
            trip.warned = true
            if Arcade.IsOpen() then
                local closed = Arcade.PutAway()
                trip.closedByUs = closed
                local A = ns.Nav and ns.Nav.alerts
                if A and A.ShowNotice then
                    A.ShowNotice(L["Landing in 10 seconds"], L["Your game is paused."], LANDING)
                end
            end
        end
        return
    end
    if not offerable(left) then
        hide()
        return
    end
    if not trip.asked then
        trip.asked = true
        show("ask")
    elseif not (card and card:IsShown() and card.mode == "ask") then
        show("row")
    end
end

local function startTrip(asked)
    trip = { asked = asked or false, warned = false, closedByUs = false }
    if not driver then
        driver = CreateFrame("Frame")
        driver:SetScript("OnUpdate", ns.Safe(function(_, dt)
            acc = acc + dt
            if acc < TICK then return end
            acc = 0
            Arcade.Tick()
        end))
    end
    acc = TICK
    driver:Show()
    ns.RegisterEvent("PLAYER_REGEN_DISABLED", onFight)
end

function stopTrip()
    trip = nil
    if driver then driver:Hide() end
    ns.UnregisterEvent("PLAYER_REGEN_DISABLED", onFight)
    hide()
end

-- Opens a game (never closes it): true when it is open after. Opened on a flight (whatever opened it),
-- the landing guard runs for it.
function Arcade.Open(id)
    local ok = openGame(id)
    if ok and not trip and Maps.GetFlight() then startTrip(true) end
    return ok
end

function Arcade.Play(id)
    hide()
    if card and card.mode == "ask" and card.Ask.Never:GetChecked() then ns.Set("maps.flightArcade", false) end
    Arcade.Open(id)
end

function Arcade.NotNow()
    if card and card.Ask.Never:GetChecked() then
        ns.Set("maps.flightArcade", false)
        hide()
        return
    end
    if card then card.mode = "row" end
    show("row")
end

ns.On("FLIGHT_STARTED", function()
    if ns.Get("maps.flightArcade") then startTrip(false) end
end)

-- Landed (or a loading screen ended the flight): a game still open is put away, whenever it was opened.
ns.On("FLIGHT_ENDED", function()
    if not trip then return end
    local closedByUs = trip.closedByUs
    if Arcade.IsOpen() then closedByUs = Arcade.PutAway() or closedByUs end
    stopTrip()
    if closedByUs then
        ns.Print(L["Landed. Your game is paused: type %s to go on."]:format(Arcade.ResumeCommand()))
    end
end)

ns.On("SETTING_CHANGED", function(path)
    if not (path == "maps.flightArcade" or path == "maps" or path == "") then return end
    if trip then
        Arcade.Tick()
    elseif ns.Get("maps.flightArcade") and Maps.GetFlight() then
        startTrip(false)
    end
end)

-- For the tests: this flight's state.
function Arcade.Trip() return trip end
