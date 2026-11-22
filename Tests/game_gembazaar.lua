-- AzerothRoute: checks of Gem Bazaar, the match-three flight game, through the game window.
-- Called by Tests/load_check.lua as chunk(ns, fail, G). Original AzerothRoute code (GPL-3.0-only).

local ns, fail, G = ...
local L = ns.L

local def = G.defs and G.defs.gembazaar
if not def then fail("gem bazaar: not registered") return end
if def.name ~= L["Gem Bazaar"] then fail("gem bazaar: wrong name " .. tostring(def.name)) end
if def.width ~= 8 * 34 or def.height ~= 8 * 34 + 24 then fail("gem bazaar: wrong size") end

if not G.Open("gembazaar") then fail("gem bazaar: does not open") return end
local game = G.Game("gembazaar")
if not game then fail("gem bazaar: no game") return end
local win = G.Window()
local down = win:GetScript("OnKeyDown")
if G.State() ~= "ready" then fail("gem bazaar: does not wait for Space") end
down(win, "SPACE")
if G.State() ~= "run" then fail("gem bazaar: Space does not start it") end

-- A fresh board: nothing lined up, a move to make.
if game:Lined() then fail("gem bazaar: a fresh board has gems lined up") end
if not game:FindMove() then fail("gem bazaar: a fresh board has no move") end

-- A board with no line: kinds by place, never three alike in a row or column (also for the new gems).
local function kindAt(c, r) return (c + 2 * r) % 6 + 1 end
game:SetRandom(kindAt)
local function lay()
    for r = 1, 8 do for c = 1, 8 do game:SetCell(c, r, kindAt(c, r)) end end
    game:SetMoves(20)
    game:SetTarget(100000)
end
local function settled() if not game:Settle() then fail("gem bazaar: the board never settles") end end

-- A swap that lines up three: they shatter (10 points each), the moves go down by one.
lay()
local k = kindAt(1, 8)
game:SetCell(2, 7, k) game:SetCell(3, 8, k) -- (1,8) k, (2,7) k, (3,8) k: swapping (2,7) down lines up row 8
game:SetCell(2, 8, 5 == k and 6 or 5)
local before, moves = game:Score(), game:Moves()
game:Click(2, 7)
game:Click(2, 8)
settled()
if game:Moves() ~= moves - 1 then fail("gem bazaar: a swap does not use a move") end
if game:Score() < before + 30 then fail("gem bazaar: three in a row do not score 30: " .. (game:Score() - before)) end
if game:Lined() then fail("gem bazaar: gems stay lined up after the cascade") end
for r = 1, 8 do for c = 1, 8 do if game:Cell(c, r) == 0 then fail("gem bazaar: an empty cell after the fall") end end end

-- A swap that lines nothing up goes back and uses no move.
lay()
moves = game:Moves()
local k1, k2 = game:Cell(1, 1), game:Cell(2, 1)
game:Click(1, 1)
game:Click(2, 1)
settled()
if game:Moves() ~= moves or game:Cell(1, 1) ~= k1 or game:Cell(2, 1) ~= k2 then fail("gem bazaar: a swap with no line does not go back") end

-- The keyboard: arrows move the cursor, Space picks, an arrow then swaps.
lay()
game:Click(5, 5) game:Click(5, 5) -- cursor on (5,5), nothing picked
down(win, "LEFT")
local c, r, picked = game:Cursor()
if c ~= 4 or r ~= 5 or picked then fail("gem bazaar: LEFT does not move the cursor") end
down(win, "SPACE")
_, _, picked = game:Cursor()
if not picked then fail("gem bazaar: Space does not pick the gem") end
k1, k2 = game:Cell(4, 5), game:Cell(4, 6)
down(win, "DOWN")
for _ = 1, 10 do G.Step(0.05) end
-- No line: back they went, but the swap played.
if game:Cell(4, 5) ~= k1 or game:Cell(4, 6) ~= k2 then fail("gem bazaar: the keyboard swap left the gems swapped") end
if game:Phase() ~= "idle" then fail("gem bazaar: the keyboard swap did not finish") end

-- Four in a row leave a flare on the swapped cell.
lay()
k = kindAt(1, 8)
game:SetCell(2, 8, k) game:SetCell(4, 8, k) game:SetCell(3, 7, k)
game:SetCell(3, 8, k == 5 and 6 or 5)
game:SetCell(1, 8, k)
game:Click(3, 7)
game:Click(3, 8)
-- Up to the fall: the flare appears where the swap went.
for _ = 1, 8 do if game:Phase() ~= "fall" then G.Step(0.05) end end
local fk, fs = game:Cell(3, 8)
if fs ~= game.FLARE or fk ~= k then fail("gem bazaar: four in a row leave no flare (" .. tostring(fk) .. "," .. tostring(fs) .. ")") end
settled()

-- A flare that shatters takes its row and column with it.
lay()
k = kindAt(1, 1)
game:SetCell(5, 5, 1, game.FLARE)
game:SetCell(4, 5, 1) game:SetCell(6, 5, 2) game:SetCell(6, 4, 1)
before = game:Score()
game:Click(6, 4)
game:Click(6, 5)
settled()
-- 3 lined + the rest of row 5 (5 more) + column 5 (7 more) = 15 gems at least.
if game:Score() - before < 150 then fail("gem bazaar: a flare does not clear its row and column: " .. (game:Score() - before)) end

-- Five in a row leave a prism; a prism swapped with a gem shatters every gem of that kind.
lay()
k = kindAt(1, 8)
for x = 1, 5 do if x ~= 3 then game:SetCell(x, 8, k) end end
game:SetCell(3, 8, k == 5 and 6 or 5)
game:SetCell(3, 7, k)
game:Click(3, 7)
game:Click(3, 8)
for _ = 1, 8 do if game:Phase() ~= "fall" then G.Step(0.05) end end
local pk, ps = game:Cell(3, 8)
if pk ~= game.PRISM or ps ~= game.PRIZE then fail("gem bazaar: five in a row leave no prism") end
settled()

lay()
game:SetCell(1, 1, game.PRISM, game.PRIZE)
local target = game:Cell(2, 1)
local n = 0
for y = 1, 8 do for x = 1, 8 do if game:Cell(x, y) == target then n = n + 1 end end end
before = game:Score()
game:Click(1, 1)
game:Click(2, 1)
settled()
if game:Score() - before < (n + 1) * 10 then fail("gem bazaar: the prism does not shatter its kind: " .. (game:Score() - before)) end

-- Cascades count more: a second wave of the same swap scores twice a gem.
-- Reaching the target goes to the next level with the moves back.
lay()
game:SetTarget(game:Score() + 1)
k = kindAt(1, 8)
game:SetCell(2, 7, k) game:SetCell(3, 8, k)
game:SetCell(2, 8, k == 5 and 6 or 5)
game:Click(2, 7)
game:Click(2, 8)
settled()
if game:Level() ~= 2 or game:Moves() ~= 20 then fail("gem bazaar: the target does not bring the next level") end

-- Out of moves below the target: game over.
lay()
game:SetMoves(1)
k = kindAt(1, 8)
game:SetCell(2, 7, k) game:SetCell(3, 8, k)
game:SetCell(2, 8, k == 5 and 6 or 5)
game:Click(2, 7)
game:Click(2, 8)
settled()
if G.State() ~= "over" then fail("gem bazaar: no moves left does not end the game: " .. tostring(G.State())) end

-- Play again: a fresh board and score.
down(win, "SPACE")
if G.State() ~= "run" or game:Score() ~= 0 or game:Level() ~= 1 then fail("gem bazaar: play again is not a fresh game") end
for _ = 1, 20 do G.Step(0.05) end
print("gem bazaar: checked")
