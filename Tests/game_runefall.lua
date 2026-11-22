-- Rune Fall checks, run by Tests/load_check.lua as chunk(ns, fail, G) once the game window works.
-- They go through the window's keys and G.Step; game:Spawn, game:SetCell, game:Cell, game:Piece and
-- game:Score are small helpers the game keeps for these checks.
local ns, fail, G = ...
local L = ns.L

local def = G.defs and G.defs.runefall
if not def then fail("rune fall: not registered") return end
if def.name ~= L["Rune Fall"] then fail("rune fall: wrong name " .. tostring(def.name)) end
if def.width ~= 9 * 22 or def.height ~= 16 * 22 then fail("rune fall: wrong size") end

if not G.Open("runefall") then fail("rune fall: does not open") return end
local game = G.Game("runefall")
if not game then fail("rune fall: no game") return end
if G.State() ~= "ready" then fail("rune fall: does not wait for Space: " .. tostring(G.State())) end
local win = G.Window()
local down, up = win:GetScript("OnKeyDown"), win:GetScript("OnKeyUp")
down(win, "SPACE")
if G.State() ~= "run" then fail("rune fall: Space does not start it") end

-- No piece is ever drawn from the classic set of seven: the set has 3-stone pieces too.
local three = 0
for kind = 1, game:Kinds() do if game:Size(kind) == 3 then three = three + 1 end end
if three < 2 then fail("rune fall: the set has no 3-stone pieces") end

-- Moving and turning (piece 6 is the bent four, which changes when turned).
game:Spawn(6)
local kind, col, row, rot = game:Piece()
if kind ~= 6 or row ~= 1 then fail("rune fall: spawn is not at the top") end
down(win, "LEFT") up(win, "LEFT")
local _, c2 = game:Piece()
if c2 ~= col - 1 then fail("rune fall: LEFT does not move the piece") end
down(win, "D") up(win, "D")
local _, c3 = game:Piece()
if c3 ~= col then fail("rune fall: D does not move the piece back") end
down(win, "UP")
local _, _, _, r2 = game:Piece()
if r2 == rot then fail("rune fall: UP does not turn the piece") end
-- A held key repeats after a short delay.
down(win, "A")
for _ = 1, 10 do G.Step(0.03) end
up(win, "A")
local _, c4 = game:Piece()
if c4 > col - 3 then fail("rune fall: a held key does not repeat (" .. tostring(c4) .. ")") end

-- A hard drop settles the piece at the bottom and brings the next one.
game:Spawn(1)
local before = game:Score()
down(win, "SPACE")
local settled = 0
for c = 1, 9 do if game:Cell(c, 16) ~= 0 then settled = settled + 1 end end
if settled ~= 3 then fail("rune fall: the hard drop did not settle the piece: " .. settled) end
local _, _, nrow = game:Piece()
if nrow ~= 1 then fail("rune fall: no new piece after the drop") end
if game:Score() ~= before + 2 * 15 then fail("rune fall: a hard drop is not 2 points a row: " .. (game:Score() - before)) end

-- A full row dissolves: 100 points (times level 1) plus the hard drop, and the stones above fall.
game:Spawn(1)
local _, pc = game:Piece()
for c = 1, 9 do game:SetCell(c, 16, 0) game:SetCell(c, 15, 0) end
for c = 1, 9 do if c < pc or c > pc + 2 then game:SetCell(c, 16, 4) end end
game:SetCell(1, 15, 7)
before = game:Score()
down(win, "SPACE")
if game:Score() ~= before + 100 + 2 * 15 then fail("rune fall: a full row does not score 100: " .. (game:Score() - before)) end
if game:Cell(1, 16) ~= 7 or game:Cell(2, 16) ~= 0 or game:Cell(1, 15) ~= 0 then fail("rune fall: the row did not dissolve") end

-- Stacking to the top ends the game.
for _ = 1, 200 do
    if G.State() ~= "run" then break end
    down(win, "SPACE")
end
if G.State() ~= "over" then fail("rune fall: the stack at the top does not end the game") end

-- Play again starts on an empty board.
down(win, "SPACE")
local empty = true
for c = 1, 9 do for r = 1, 16 do if game:Cell(c, r) ~= 0 then empty = false end end end
if G.State() ~= "run" or not empty or game:Score() ~= 0 then fail("rune fall: play again is not a fresh board") end
for _ = 1, 40 do G.Step(0.05) end
local _, _, frow = game:Piece()
if frow < 2 then fail("rune fall: the piece does not fall on its own") end

G.Close()
print("rune fall: checked")
