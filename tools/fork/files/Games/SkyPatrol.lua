-- AzerothRoute: Sky Patrol, a flight game. A gryphon rider over the dusk sky holds off waves of bats and
-- harpies: they swoop in on curving paths, hang in loose rows, dive at the rider and drop stones. Each
-- cleared wave brings a faster, larger one. Sprites: Media/Arcade (tools/fork/make_arcade_art.lua).
-- Original AzerothRoute code (GPL-3.0-only).

local ADDON, ns = ...
local L = ns.L
local G = ns.Games
if not G then return end

local W, H = 300, 340
local PLAYER_Y = H - 28
local PLAYER_SPEED = 170
local BOLT_SPEED, BOLT_COOLDOWN, MAX_BOLTS = 380, 0.28, 3
local MAX_ENEMIES, MAX_STONES, MAX_CLOUDS, MAX_SPARKS = 32, 10, 5, 6
local LIVES, SHIELD = 3, 1.5
local ENTER_TIME, FLAP_TIME, BANNER_TIME = 1.7, 0.2, 1.8
local COL_GAP, ROW_GAP, TOP_ROW = 32, 30, 46

local KINDS = {
    bat = { hp = 1, points = 10, size = 26, hw = 11, hh = 8, color = { 0.66, 0.55, 0.82 } },
    harpy = { hp = 2, points = 25, size = 30, hw = 11, hh = 11, color = { 0.42, 0.86, 0.78 } },
}
local HURT = { 0.98, 0.56, 0.5 }
local RIDER = { 1, 0.9, 0.7 }
local BOLT = { 1, 0.92, 0.6 }
local STONE = { 0.75, 0.7, 0.64 }

local sin, abs, min, max, floor, random, pi = math.sin, math.abs, math.min, math.max, math.floor, math.random, math.pi

local Game = {}
Game.__index = Game

-- Centre of a texture at view point (x, y), y down.
local function place(t, parent, x, y)
    t:ClearAllPoints()
    t:SetPoint("CENTER", parent, "TOPLEFT", x, -y)
end

local function tint(t, c, a) t:SetVertexColor(c[1], c[2], c[3], a or 1) end

local function sprite(self, layer, sub, name, w, h)
    local t = self.canvas:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(self.host.Media(name))
    t:SetSize(w, h)
    t:Hide()
    return t
end

local function new(view, host)
    local self = setmetatable({ view = view, host = host, held = {} }, Game)
    -- Everything draws in a child frame, so the view clips it at its edges.
    local canvas = CreateFrame("Frame", nil, view)
    canvas:SetAllPoints(view)
    self.canvas = canvas
    self.art = {
        bat = { host.Media("bat"), host.Media("bat2") },
        harpy = { host.Media("harpy"), host.Media("harpy2") },
    }

    local sky = canvas:CreateTexture(nil, "BACKGROUND")
    sky:SetAllPoints(canvas)
    sky:SetTexture(host.Media("sky"))

    self.clouds, self.enemies, self.stones, self.bolts, self.sparks, self.lifeIcons = {}, {}, {}, {}, {}, {}
    for i = 1, MAX_CLOUDS do
        self.clouds[i] = { tex = sprite(self, "BORDER", 0, "cloud", 64, 32), x = 0, y = 0, speed = 0 }
    end
    for i = 1, MAX_ENEMIES do
        self.enemies[i] = { tex = sprite(self, "ARTWORK", 1, "bat", 26, 26), active = false, x = 0, y = 0, t = 0 }
    end
    for i = 1, MAX_STONES do
        local s = { tex = sprite(self, "ARTWORK", 2, "stone", 12, 12), active = false, x = 0, y = 0, vy = 0 }
        tint(s.tex, STONE)
        self.stones[i] = s
    end
    for i = 1, MAX_BOLTS do
        local b = { tex = sprite(self, "ARTWORK", 2, "bolt", 8, 16), active = false, x = 0, y = 0 }
        tint(b.tex, BOLT)
        self.bolts[i] = b
    end
    for i = 1, MAX_SPARKS do
        self.sparks[i] = { tex = sprite(self, "OVERLAY", 0, "spark", 16, 16), active = false, x = 0, y = 0, t = 0 }
    end
    self.player = { tex = sprite(self, "ARTWORK", 3, "gryphon", 32, 32), x = W / 2, y = PLAYER_Y }
    tint(self.player.tex, RIDER)
    local ar, ag, ab = host.Color("accent")
    for i = 1, LIVES do
        local t = sprite(self, "OVERLAY", 1, "life", 14, 14)
        t:SetVertexColor(ar or 1, ag or 1, ab or 1)
        place(t, canvas, 4 + i * 15, 12)
        self.lifeIcons[i] = t
    end

    local Wd = ns.Widgets
    local banner = Wd and Wd.Text and Wd.Text(canvas, "display", "accent")
        or canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    banner:SetPoint("CENTER", canvas, "CENTER", 0, 30)
    banner:SetJustifyH("CENTER")
    banner:Hide()
    self.banner = banner
    return self
end

---------------------------------------------------------------------------
-- The game
---------------------------------------------------------------------------

local function off(o)
    o.active = false
    o.tex:Hide()
end

function Game:Reset()
    for _, pool in ipairs({ self.enemies, self.stones, self.bolts, self.sparks }) do
        for _, o in ipairs(pool) do off(o) end
    end
    for k in pairs(self.held) do self.held[k] = nil end
    self.score, self.lives, self.wave, self.speed = 0, LIVES, 0, 1
    self.cool, self.shield, self.time, self.flapT, self.flap = 0, 0, 0, 0, 1
    self.next = 0.4 -- seconds to the first wave
    self.diveIn, self.dropIn, self.bannerT = 3, 2, 0
    self.cols, self.drift, self.bob, self.alive = 5, 0, 0, 0
    self.over, self.quiet = false, false
    local p = self.player
    p.x = W / 2
    p.tex:SetAlpha(1)
    p.tex:Show()
    place(p.tex, self.canvas, p.x, p.y)
    for i, c in ipairs(self.clouds) do
        c.x, c.y, c.speed = random(30, W - 30), (i - 1) * (H + 40) / MAX_CLOUDS - 20, 12 + random() * 10
        c.tex:SetAlpha(0.14 + random() * 0.12)
        c.tex:Show()
        place(c.tex, self.canvas, c.x, c.y)
    end
    self:Lives()
    self.banner:Hide()
end

function Game:Key(key, down)
    if key == "LEFT" or key == "RIGHT" or key == "A" or key == "D" or key == "SPACE" then
        self.held[key] = down or nil
        return true
    end
    return false
end

function Game:Update(dt)
    if self.over then return end
    self.time = self.time + dt
    self:Clouds(dt)
    self:Rider(dt)
    self:Enemies(dt)
    self:Bolts(dt)
    self:Stones(dt)
    self:Sparks(dt)
    self:Waves(dt)
    if self.bannerT > 0 then
        self.bannerT = self.bannerT - dt
        if self.bannerT <= 0 then self.banner:Hide() else self.banner:SetAlpha(min(1, self.bannerT / 0.4)) end
    end
end

function Game:Lives()
    for i, t in ipairs(self.lifeIcons) do t:SetShown(i <= self.lives) end
end

function Game:Clouds(dt)
    for _, c in ipairs(self.clouds) do
        c.y = c.y + c.speed * dt
        if c.y > H + 20 then c.y, c.x = -20, random(30, W - 30) end
        place(c.tex, self.canvas, c.x, c.y)
    end
end

function Game:Rider(dt)
    local p, held = self.player, self.held
    local dir = 0
    if held.LEFT or held.A then dir = dir - 1 end
    if held.RIGHT or held.D then dir = dir + 1 end
    p.x = min(W - 18, max(18, p.x + dir * PLAYER_SPEED * dt))
    self.cool = max(0, self.cool - dt)
    if held.SPACE and self.cool <= 0 then self:Fire() end
    if self.shield > 0 then
        self.shield = self.shield - dt
        p.tex:SetAlpha((self.shield > 0 and floor(self.shield * 10) % 2 == 0) and 0.25 or 1)
    end
    place(p.tex, self.canvas, p.x, p.y)
end

function Game:Fire()
    for _, b in ipairs(self.bolts) do
        if not b.active then
            b.active, b.x, b.y = true, self.player.x, self.player.y - 18
            b.tex:Show()
            place(b.tex, self.canvas, b.x, b.y)
            self.cool = BOLT_COOLDOWN
            self.host.Sound("throw")
            return
        end
    end
end

function Game:Spark(x, y)
    for _, s in ipairs(self.sparks) do
        if not s.active then
            s.active, s.x, s.y, s.t = true, x, y, 0
            s.tex:Show()
            place(s.tex, self.canvas, x, y)
            return
        end
    end
end

function Game:Sparks(dt)
    for _, s in ipairs(self.sparks) do
        if s.active then
            s.t = s.t + dt
            if s.t >= 0.3 then off(s) else
                local k = s.t / 0.3
                s.tex:SetSize(14 + 18 * k, 14 + 18 * k)
                s.tex:SetAlpha(1 - k)
            end
        end
    end
end

-- The rider is hit: a life lost, a blink of safety, or the end.
function Game:Hurt()
    self.lives = self.lives - 1
    self.host.Sound("hurt")
    self:Lives()
    self:Spark(self.player.x, self.player.y)
    if self.lives <= 0 then
        self.over = true
        self.player.tex:Hide()
        self.host.Over(self.score)
    else
        self.shield = SHIELD
    end
end

function Game:Points(n)
    self.score = self.score + n
    self.host.Score(self.score)
end

---------------------------------------------------------------------------
-- Waves, rows and dives
---------------------------------------------------------------------------

local function homeX(self, col) return W / 2 + (col - (self.cols + 1) / 2) * COL_GAP + self.drift end
local function homeY(self, row) return TOP_ROW + (row - 1) * ROW_GAP + self.bob end

local function look(self, e)
    local k = KINDS[e.kind]
    e.tex:SetTexture(self.art[e.kind][self.flap])
    e.tex:SetSize(k.size, k.size)
    tint(e.tex, e.hp < k.hp and HURT or k.color)
end

function Game:Wave(n)
    self.wave = n
    self.speed = 1 + (n - 1) * 0.1
    local cols = min(8, 5 + floor((n - 1) / 2))
    local rows = min(4, 2 + floor(n / 2))
    local harpyRows = n >= 3 and 2 or 1
    self.cols = cols
    local i = 0
    for r = 1, rows do
        for c = 1, cols do
            i = i + 1
            local e = self.enemies[i]
            e.kind = r <= harpyRows and "harpy" or "bat"
            e.hp, e.active, e.col, e.row = KINDS[e.kind].hp, true, c, r
            e.mode, e.t = "wait", -(i - 1) * 0.11 / self.speed
            e.side = r % 2 == 1 and 1 or -1
            e.sx, e.sy = e.side == 1 and 40 or W - 40, -24
            e.x, e.y = e.sx, e.sy
            look(self, e)
            e.tex:Hide()
        end
    end
    self.diveIn, self.dropIn = 3.5, 2.5
    self.banner:SetText(L["Wave %d"]:format(n))
    if n > 1 then self.host.Sound("wave") end
    self.banner:SetAlpha(1)
    self.banner:Show()
    self.bannerT = BANNER_TIME
end

function Game:Waves(dt)
    if self.quiet then return end
    if self.next then
        self.next = self.next - dt
        if self.next <= 0 then
            self.next = nil
            self:Wave(self.wave + 1)
        end
        return
    end
    if self.alive == 0 then self.next = 1.2 return end
    self.diveIn = self.diveIn - dt
    if self.diveIn <= 0 then
        self.diveIn = max(0.9, 3.2 - 0.25 * self.wave) * (0.7 + 0.6 * random())
        self:Dive()
    end
    self.dropIn = self.dropIn - dt
    if self.dropIn <= 0 then
        self.dropIn = max(0.4, 1.5 - 0.12 * self.wave) * (0.6 + 0.8 * random())
        self:Drop()
    end
end

-- One enemy in the rows (or on screen, for stones) at random; nil when there is none.
local function pick(self, any)
    local n = 0
    for _, e in ipairs(self.enemies) do
        if e.active and (e.mode == "row" or (any and e.mode == "dive" and e.y > 0)) then n = n + 1 end
    end
    if n == 0 then return nil end
    local k = random(n)
    for _, e in ipairs(self.enemies) do
        if e.active and (e.mode == "row" or (any and e.mode == "dive" and e.y > 0)) then
            k = k - 1
            if k == 0 then return e end
        end
    end
end

function Game:Dive()
    local e = pick(self, false)
    if not e then return end
    e.mode, e.t = "dive", 0
    e.dx, e.dy = e.x, e.y
    e.tx = min(W - 20, max(20, self.player.x))
    e.vy = (115 + 9 * self.wave)
    e.side = random() < 0.5 and -1 or 1
end

function Game:Drop()
    local limit, live = min(MAX_STONES, 2 + self.wave), 0
    for _, s in ipairs(self.stones) do if s.active then live = live + 1 end end
    if live >= limit then return end
    local e = pick(self, true)
    if e then self:Stone(e.x, e.y + 10) end
end

function Game:Enemies(dt)
    self.drift = sin(self.time * 0.7 * self.speed) * min(30, W / 2 - ((self.cols - 1) * COL_GAP / 2 + 14) - 4)
    self.bob = sin(self.time * 1.6) * 3
    self.flapT = self.flapT + dt
    local flapped = false
    if self.flapT >= FLAP_TIME then
        self.flapT, self.flap, flapped = 0, 3 - self.flap, true
    end
    local p = self.player
    local alive = 0
    for _, e in ipairs(self.enemies) do
        if e.active then
            alive = alive + 1
            local mode = e.mode
            if mode == "wait" then
                e.t = e.t + dt
                if e.t >= 0 then
                    e.mode, e.t = "enter", 0
                    e.tex:Show()
                end
            elseif mode == "enter" then
                e.t = e.t + dt * self.speed
                local s = min(1, e.t / ENTER_TIME)
                local k = s * s * (3 - 2 * s)
                e.x = e.sx + (homeX(self, e.col) - e.sx) * k + sin(s * pi * 2) * 50 * (1 - s) * e.side
                e.y = e.sy + (homeY(self, e.row) - e.sy) * k
                if s >= 1 then e.mode = "row" end
            elseif mode == "row" then
                e.x, e.y = homeX(self, e.col), homeY(self, e.row)
            elseif mode == "dive" then
                e.t = e.t + dt
                e.y = e.y + e.vy * dt
                local s = min(1, (e.y - e.dy) / max(1, PLAYER_Y - e.dy))
                e.x = min(W - 10, max(10, e.dx + (e.tx - e.dx) * s + sin(e.t * 3.2) * 38 * e.side))
                if e.y > H + 20 then
                    -- Out through the bottom, back in from the top to its place.
                    e.mode, e.t = "enter", 0
                    e.sx, e.sy = random(30, W - 30), -24
                end
            end
            if e.mode ~= "wait" then
                if flapped then e.tex:SetTexture(self.art[e.kind][self.flap]) end
                place(e.tex, self.canvas, e.x, e.y)
                -- A diver that reaches the rider is lost with the life it takes.
                if self.shield <= 0 and not self.over and abs(e.x - p.x) < 16 and abs(e.y - p.y) < 14 then
                    self:Spark(e.x, e.y)
                    off(e)
                    alive = alive - 1
                    self:Hurt()
                end
            end
        end
    end
    self.alive = alive
end

function Game:Bolts(dt)
    for _, b in ipairs(self.bolts) do
        if b.active then
            b.y = b.y - BOLT_SPEED * dt
            if b.y < -10 then off(b) else
                place(b.tex, self.canvas, b.x, b.y)
                for _, e in ipairs(self.enemies) do
                    if e.active and e.mode ~= "wait" then
                        local k = KINDS[e.kind]
                        if abs(b.x - e.x) < k.hw + 3 and abs(b.y - e.y) < k.hh + 7 then
                            off(b)
                            e.hp = e.hp - 1
                            if e.hp <= 0 then
                                self.host.Sound("kill")
                                self:Spark(e.x, e.y)
                                off(e)
                                self:Points(k.points * (e.mode == "dive" and 2 or 1))
                            else
                                self.host.Sound("hit")
                                tint(e.tex, HURT)
                            end
                            break
                        end
                    end
                end
            end
        end
    end
end

function Game:Stones(dt)
    local p = self.player
    for _, s in ipairs(self.stones) do
        if s.active then
            s.y = s.y + s.vy * dt
            if s.y > H + 10 then off(s) else
                place(s.tex, self.canvas, s.x, s.y)
                if self.shield <= 0 and not self.over and abs(s.x - p.x) < 12 and abs(s.y - p.y) < 12 then
                    off(s)
                    self:Hurt()
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- For the tests: a fixed random seed, a still sky, and enemies and stones placed by hand.
---------------------------------------------------------------------------

function Game:Seed(n) math.randomseed(n or 1) end

-- No more waves, dives or stones; the sky is emptied.
function Game:Quiet()
    self.quiet, self.next = true, nil
    for _, pool in ipairs({ self.enemies, self.stones, self.bolts }) do
        for _, o in ipairs(pool) do off(o) end
    end
end

-- An enemy holding still at (x, y). -> the enemy
function Game:Place(kind, x, y)
    for _, e in ipairs(self.enemies) do
        if not e.active then
            e.kind, e.active, e.mode, e.t = kind, true, "still", 0
            e.hp, e.x, e.y, e.col, e.row, e.side = KINDS[kind].hp, x, y, 1, 1, 1
            look(self, e)
            e.tex:Show()
            place(e.tex, self.canvas, x, y)
            return e
        end
    end
end

-- A stone falling from (x, y) (also how the enemies drop them). -> the stone
function Game:Stone(x, y)
    for _, s in ipairs(self.stones) do
        if not s.active then
            s.active, s.x, s.y, s.vy = true, x, y, 130 + 10 * self.wave
            s.tex:Show()
            place(s.tex, self.canvas, x, y)
            return s
        end
    end
end

G.Register({
    id = "skypatrol",
    name = L["Sky Patrol"],
    blurb = L["Hold off the bats and harpies from your gryphon."],
    keys = L["Arrows or A/D: fly   Space: throw"],
    width = W,
    height = H,
    order = 2,
    New = new,
})
