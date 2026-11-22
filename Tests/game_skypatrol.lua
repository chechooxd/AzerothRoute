-- AzerothRoute: checks of Sky Patrol, the flight shooter, through the game window.
-- Called by Tests/load_check.lua as chunk(ns, fail, G). Original AzerothRoute code (GPL-3.0-only).

local ns, fail, G = ...
local L = ns.L

local def
for _, d in ipairs(G.List()) do if d.id == "skypatrol" then def = d end end
if not def then fail("sky patrol is not registered") return end
if def.name ~= L["Sky Patrol"] then fail("sky patrol has the wrong name: " .. tostring(def.name)) end

if not G.Open("skypatrol") then fail("sky patrol does not open") return end
local game = G.Game("skypatrol")
local win = G.Window()
local down, up = win:GetScript("OnKeyDown"), win:GetScript("OnKeyUp")
local function steps(n, dt) for _ = 1, n do G.Step(dt or 0.016) end end

if G.State() ~= "ready" then fail("sky patrol does not wait for Space: " .. tostring(G.State())) end
down(win, "SPACE")
up(win, "SPACE")
if G.State() ~= "run" then fail("Space does not start sky patrol") end
game:Seed(1)
game:Quiet() -- no waves, dives or stones: the checks place what they need

-- Holding Right moves the rider right; letting go stops it.
local p = game.player
local x0 = p.x
down(win, "RIGHT")
steps(4, 0.05)
local x1 = p.x
if not (x1 > x0 + 20) then fail("holding Right does not move the rider: " .. x0 .. " -> " .. x1) end
up(win, "RIGHT")
steps(4, 0.05)
if p.x ~= x1 then fail("the rider keeps moving after Right is let go") end

-- Space throws a bolt that flies up.
local function liveBolt()
    for _, b in ipairs(game.bolts) do if b.active then return b end end
end
down(win, "SPACE")
steps(1)
up(win, "SPACE")
local b = liveBolt()
if not b then fail("Space does not throw a bolt") else
    local y1 = b.y
    steps(2)
    if not (b.y < y1) then fail("a bolt does not fly up") end
end
steps(60) -- the bolt leaves the sky

-- A bolt that hits a bat takes it down and scores 10.
local bat = game:Place("bat", p.x, p.y - 80)
local before = game.score
down(win, "SPACE")
steps(1)
up(win, "SPACE")
steps(30)
if bat.active then fail("a bolt does not take a bat down") end
if game.score ~= before + 10 then fail("a bat does not score 10: " .. tostring(game.score - before)) end
local bar = win.Score and win.Score:GetText() or ""
if not tostring(bar):find("10", 1, true) then fail("the score bar does not show the bat: " .. tostring(bar)) end

-- A stone that hits the rider costs a life.
local lives = game.lives
game:Stone(p.x, p.y - 40)
steps(30)
if game.lives ~= lives - 1 then fail("a stone does not cost a life: " .. tostring(game.lives)) end

-- With no lives left the game is over and the host keeps the score.
for _ = 1, 5 do
    if G.State() ~= "run" then break end
    steps(100, 0.02) -- the blink of a hit wears off
    game:Stone(p.x, p.y - 40)
    steps(30)
end
if game.lives ~= 0 or G.State() ~= "over" then fail("sky patrol does not end at 0 lives: " .. tostring(G.State())) end
if G.Best("skypatrol") ~= game.score then fail("sky patrol's score does not reach the host: " .. tostring(G.Best("skypatrol"))) end

-- Play again: a real game with waves, dives and stones runs for a minute without an error.
down(win, "SPACE")
up(win, "SPACE")
if G.State() ~= "run" or game.lives ~= 3 or game.score ~= 0 then fail("Space after game over does not start sky patrol again") end
down(win, "SPACE")
for i = 1, 3000 do
    if i % 100 == 1 then
        local key = (i % 200 == 1) and "LEFT" or "RIGHT"
        up(win, key == "LEFT" and "RIGHT" or "LEFT")
        down(win, key)
    end
    if G.State() ~= "run" then break end
    G.Step(0.02)
end
up(win, "SPACE")
if game.wave < 1 then fail("no wave comes to sky patrol") end

-- Its sprites ship with the addon.
local f = io.open("tools/fork/assets/AzerothRoute/Media/Arcade/gryphon.tga", "rb")
local head = f and f:read(18)
if f then f:close() end
if not head or head:byte(3) ~= 2 or head:byte(13) ~= 32 or head:byte(17) ~= 32 or head:byte(18) ~= 40 then
    fail("the gryphon sprite is missing or not a 32 x 32 TGA")
end

G.Close()
print("sky patrol: checked")
