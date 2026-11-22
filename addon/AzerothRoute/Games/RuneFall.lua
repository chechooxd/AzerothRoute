-- AzerothRoute: Rune Fall, a falling runestones puzzle for long flights. Pieces of three or four stones
-- fall into a 9 x 16 well; a full row of stones dissolves and the rows above fall. The pieces speed up
-- every 8 rows; the game ends when a new piece has no room at the top.
-- Original AzerothRoute code (GPL-3.0-only).

local ADDON, ns = ...
local L = ns.L
local G = ns.Games
if not G then return end

local COLS, ROWS, CELL = 9, 16, 18
local WIDTH, HEIGHT = COLS * CELL, ROWS * CELL
local REPEAT_DELAY, REPEAT_EVERY = 0.17, 0.05
local ROWS_PER_LEVEL = 8
local LINE_SCORE = { 100, 300, 500, 800 }
local KICK = { 0, -1, 1 } -- a turn against a wall or stone may shift one cell

-- The pieces: stones in a box (x right, y down from 0), turned clockwise inside the box.
local SHAPES = {
    { box = 3, cells = { 0, 1, 1, 1, 2, 1 } }, -- straight three
    { box = 2, cells = { 0, 0, 0, 1, 1, 1 } }, -- corner three
    { box = 4, cells = { 0, 1, 1, 1, 2, 1, 3, 1 } }, -- straight four
    { box = 2, cells = { 0, 0, 1, 0, 0, 1, 1, 1 } }, -- square
    { box = 3, cells = { 1, 0, 0, 1, 1, 1, 2, 1 } }, -- crest
    { box = 3, cells = { 2, 0, 0, 1, 1, 1, 2, 1 } }, -- bent four
    { box = 3, cells = { 1, 0, 2, 0, 0, 1, 1, 1 } }, -- step
}
local KINDS = #SHAPES

-- Stone colours, one per piece: sapphire, azure, ice, gold, violet, bronze, pearl.
local STONE = {
    { 0.16, 0.36, 0.80 },
    { 0.18, 0.60, 0.76 },
    { 0.52, 0.74, 0.95 },
    { 0.86, 0.67, 0.22 },
    { 0.44, 0.33, 0.80 },
    { 0.78, 0.48, 0.20 },
    { 0.80, 0.82, 0.88 },
}

-- Every turn of every piece, with the smallest x and y of its stones.
local ROT, MINX, MINY = {}, {}, {}
for k, shape in ipairs(SHAPES) do
    ROT[k], MINX[k], MINY[k] = {}, {}, {}
    local cur = shape.cells
    for r = 0, 3 do
        ROT[k][r] = cur
        local mx, my = 9, 9
        for i = 1, #cur, 2 do
            if cur[i] < mx then mx = cur[i] end
            if cur[i + 1] < my then my = cur[i + 1] end
        end
        MINX[k][r], MINY[k][r] = mx, my
        local nxt = {}
        for i = 1, #cur, 2 do
            nxt[i], nxt[i + 1] = shape.box - 1 - cur[i + 1], cur[i]
        end
        cur = nxt
    end
end

local function mix(c, t, f) return c + (t - c) * f end

local function New(view, host)
    local game = {}
    local board, want, drawn = {}, {}, {}
    local bag, bagAt = {}, KINDS + 1
    local kind, rot, px, py = 1, 0, 1, 1
    local nextKind = 1
    local score, lines, level = 0, 0, 1
    local fallT = 0
    local dirty = true
    local held = { left = false, right = false, down = false }
    local heldKey = { left = nil, right = nil, down = nil }
    local heldT = { left = 0, right = 0, down = 0 }

    -- Drawing: every texture is made here, once.
    local back = view:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints(view)
    back:SetColorTexture(0.03, 0.06, 0.12, 1)
    local ar, ag, ab = host.Color("accent")
    for c = 1, COLS - 1 do
        local t = view:CreateTexture(nil, "BACKGROUND", nil, 1)
        t:SetColorTexture(ar, ag, ab, 0.07)
        t:SetSize(1, HEIGHT)
        t:SetPoint("TOPLEFT", view, "TOPLEFT", c * CELL, 0)
    end
    for r = 1, ROWS - 1 do
        local t = view:CreateTexture(nil, "BACKGROUND", nil, 1)
        t:SetColorTexture(ar, ag, ab, 0.07)
        t:SetSize(WIDTH, 1)
        t:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -r * CELL)
    end

    -- A stone: dark lower right edge, light upper left edge, the face and a faint rune mark.
    local dark, light, face, mark = {}, {}, {}, {}
    for r = 1, ROWS do
        for c = 1, COLS do
            local i = (r - 1) * COLS + c
            local x, y = (c - 1) * CELL, -(r - 1) * CELL
            dark[i] = view:CreateTexture(nil, "ARTWORK", nil, 1)
            dark[i]:SetSize(CELL - 2, CELL - 2)
            dark[i]:SetPoint("TOPLEFT", view, "TOPLEFT", x + 1, y - 1)
            light[i] = view:CreateTexture(nil, "ARTWORK", nil, 2)
            light[i]:SetSize(CELL - 2, CELL - 2)
            light[i]:SetPoint("TOPLEFT", view, "TOPLEFT", x, y)
            face[i] = view:CreateTexture(nil, "ARTWORK", nil, 3)
            face[i]:SetSize(CELL - 3, CELL - 3)
            face[i]:SetPoint("TOPLEFT", view, "TOPLEFT", x + 1, y - 1)
            mark[i] = view:CreateTexture(nil, "ARTWORK", nil, 4)
            mark[i]:SetSize(3, 7)
            mark[i]:SetPoint("TOPLEFT", view, "TOPLEFT", x + 7, y - 5)
            dark[i]:Hide() light[i]:Hide() face[i]:Hide() mark[i]:Hide()
            board[i], want[i], drawn[i] = 0, 0, 0
        end
    end

    -- The next piece, small and see-through in the top right corner.
    local NEXT_CELL = 7
    local nextBack = view:CreateTexture(nil, "OVERLAY", nil, 1)
    nextBack:SetSize(4 * NEXT_CELL + 6, 4 * NEXT_CELL + 6)
    nextBack:SetPoint("TOPRIGHT", view, "TOPRIGHT", -3, -3)
    nextBack:SetColorTexture(0, 0, 0, 0.35)
    local nextCells = {}
    for i = 1, 4 do
        local t = view:CreateTexture(nil, "OVERLAY", nil, 2)
        t:SetSize(NEXT_CELL - 1, NEXT_CELL - 1)
        nextCells[i] = t
    end

    local levelText
    if ns.Widgets and ns.Widgets.Text then
        levelText = ns.Widgets.Text(view, "note", "textDim")
        levelText:SetPoint("TOPLEFT", view, "TOPLEFT", 4, -3)
        if levelText.SetDrawLayer then levelText:SetDrawLayer("OVERLAY", 3) end
    end

    -- want/drawn hold kind * 4 + style per cell (style 1 a stone, 2 the landing shadow; 0 empty).
    local function paintCell(i, v)
        if v == 0 then
            dark[i]:Hide() light[i]:Hide() face[i]:Hide() mark[i]:Hide()
            return
        end
        local k, style = math.floor(v / 4), v % 4
        local s = STONE[k]
        if style == 2 then
            dark[i]:Hide() light[i]:Hide() mark[i]:Hide()
            face[i]:SetColorTexture(s[1], s[2], s[3], 0.18)
            face[i]:Show()
            return
        end
        dark[i]:SetColorTexture(s[1] * 0.45, s[2] * 0.45, s[3] * 0.45, 1)
        light[i]:SetColorTexture(mix(s[1], 1, 0.45), mix(s[2], 1, 0.45), mix(s[3], 1, 0.45), 1)
        face[i]:SetColorTexture(s[1], s[2], s[3], 1)
        mark[i]:SetColorTexture(mix(s[1], 1, 0.6), mix(s[2], 1, 0.6), mix(s[3], 1, 0.6), 0.35)
        dark[i]:Show() light[i]:Show() face[i]:Show() mark[i]:Show()
    end

    local function paintNext()
        local cells, mx, my = ROT[nextKind][0], MINX[nextKind][0], MINY[nextKind][0]
        local s = STONE[nextKind]
        for n = 1, 4 do
            local t = nextCells[n]
            local x, y = cells[n * 2 - 1], cells[n * 2]
            if x then
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", nextBack, "TOPLEFT", 3 + (x - mx) * NEXT_CELL, -3 - (y - my) * NEXT_CELL)
                t:SetColorTexture(s[1], s[2], s[3], 0.6)
                t:Show()
            else
                t:Hide()
            end
        end
    end

    local function fits(k, r, x0, y0)
        local cells = ROT[k][r]
        for n = 1, #cells, 2 do
            local c, row = x0 + cells[n], y0 + cells[n + 1]
            if c < 1 or c > COLS or row < 1 or row > ROWS then return false end
            if board[(row - 1) * COLS + c] ~= 0 then return false end
        end
        return true
    end

    local function draw()
        for i = 1, COLS * ROWS do
            local b = board[i]
            want[i] = b ~= 0 and b * 4 + 1 or 0
        end
        if kind > 0 then
            local cells = ROT[kind][rot]
            local gy = py
            while fits(kind, rot, px, gy + 1) do gy = gy + 1 end
            for n = 1, #cells, 2 do
                local i = (gy + cells[n + 1] - 1) * COLS + px + cells[n]
                if want[i] == 0 then want[i] = kind * 4 + 2 end
            end
            for n = 1, #cells, 2 do
                want[(py + cells[n + 1] - 1) * COLS + px + cells[n]] = kind * 4 + 1
            end
        end
        for i = 1, COLS * ROWS do
            if want[i] ~= drawn[i] then
                paintCell(i, want[i])
                drawn[i] = want[i]
            end
        end
        dirty = false
    end

    local function fromBag()
        if bagAt > KINDS then
            for k = 1, KINDS do bag[k] = k end
            for k = KINDS, 2, -1 do
                local j = math.random(k)
                bag[k], bag[j] = bag[j], bag[k]
            end
            bagAt = 1
        end
        local k = bag[bagAt]
        bagAt = bagAt + 1
        return k
    end

    local function place(k)
        kind, rot = k, 0
        px = math.floor((COLS - SHAPES[k].box) / 2) + 1
        py = 1 - MINY[k][0]
        fallT = 0
        dirty = true
        return fits(kind, rot, px, py)
    end

    local function gravity()
        local g = 0.8 * 0.88 ^ (level - 1)
        return g < 0.08 and 0.08 or g
    end

    local function setLevel()
        level = 1 + math.floor(lines / ROWS_PER_LEVEL)
        if levelText then levelText:SetText(L["Level %d"]:format(level)) end
    end

    -- Dissolves the full rows; the rows above fall. -> how many.
    local function clearRows()
        local w, cleared = ROWS, 0
        for r = ROWS, 1, -1 do
            local full = true
            local base = (r - 1) * COLS
            for c = 1, COLS do
                if board[base + c] == 0 then full = false break end
            end
            if full then
                cleared = cleared + 1
            else
                if w ~= r then
                    local wb = (w - 1) * COLS
                    for c = 1, COLS do board[wb + c] = board[base + c] end
                end
                w = w - 1
            end
        end
        for i = 1, w * COLS do board[i] = 0 end
        return cleared
    end

    -- The piece becomes part of the well; full rows go; the next piece comes in or the game ends.
    local function lock()
        local cells = ROT[kind][rot]
        for n = 1, #cells, 2 do
            board[(py + cells[n + 1] - 1) * COLS + px + cells[n]] = kind
        end
        local cleared = clearRows()
        if cleared > 0 then
            score = score + LINE_SCORE[cleared > 4 and 4 or cleared] * level
            lines = lines + cleared
            setLevel()
        end
        host.Score(score)
        local k = nextKind
        nextKind = fromBag()
        paintNext()
        if not place(k) then
            kind = 0
            draw()
            host.Over(score)
            return false
        end
        draw()
        return true
    end

    local function move(dx)
        if kind > 0 and fits(kind, rot, px + dx, py) then
            px = px + dx
            dirty = true
            return true
        end
        return false
    end

    local function softDrop()
        if kind > 0 and fits(kind, rot, px, py + 1) then
            py = py + 1
            fallT = 0
            score = score + 1
            host.Score(score)
            dirty = true
            return true
        end
        return false
    end

    local function turn()
        if kind == 0 then return false end
        local r = (rot + 1) % 4
        for _, dx in ipairs(KICK) do
            if fits(kind, r, px + dx, py) then
                rot, px = r, px + dx
                dirty = true
                return true
            end
        end
        return false
    end

    local function hardDrop()
        if kind == 0 then return false end
        local d = 0
        while fits(kind, rot, px, py + 1) do py, d = py + 1, d + 1 end
        score = score + 2 * d
        lock()
        return true
    end

    local ACT = { left = function() return move(-1) end, right = function() return move(1) end, down = softDrop }
    local HOLD = { LEFT = "left", A = "left", RIGHT = "right", D = "right", DOWN = "down", S = "down" }

    function game:Reset()
        for i = 1, COLS * ROWS do board[i] = 0 end
        score, lines, fallT = 0, 0, 0
        setLevel()
        for a in pairs(held) do held[a], heldKey[a], heldT[a] = false, nil, 0 end
        bagAt = KINDS + 1
        nextKind = fromBag()
        place(fromBag())
        paintNext()
        draw()
    end

    function game:Key(key, down)
        local a = HOLD[key]
        if a then
            if down then
                held[a], heldKey[a], heldT[a] = true, key, REPEAT_DELAY
                ACT[a]()
            elseif heldKey[a] == key then
                held[a], heldKey[a] = false, nil
            end
            if dirty then draw() end
            return true
        end
        if not down then return key == "UP" or key == "W" or key == "SPACE" end
        if key == "UP" or key == "W" then
            turn()
        elseif key == "SPACE" then
            hardDrop()
        else
            return false
        end
        if dirty then draw() end
        return true
    end

    local isKeyDown = type(IsKeyDown) == "function" and IsKeyDown or nil

    function game:Update(dt)
        if kind == 0 then return end
        -- Held keys repeat; a key let go while the game was paused stops here.
        for a, on in pairs(held) do
            if on then
                if isKeyDown and isKeyDown(heldKey[a]) == false then
                    held[a], heldKey[a] = false, nil
                else
                    heldT[a] = heldT[a] - dt
                    while held[a] and heldT[a] <= 0 do
                        heldT[a] = heldT[a] + REPEAT_EVERY
                        if not ACT[a]() then break end
                    end
                    if heldT[a] <= 0 then heldT[a] = REPEAT_EVERY end
                end
            end
        end
        if kind == 0 then return end
        fallT = fallT + dt
        local g = gravity()
        while fallT >= g do
            fallT = fallT - g
            if fits(kind, rot, px, py + 1) then
                py = py + 1
                dirty = true
            else
                lock()
                return
            end
        end
        if dirty then draw() end
    end

    -- For the checks (Tests/game_runefall.lua).
    function game:Kinds() return KINDS end
    function game:Size(k) return #SHAPES[k].cells / 2 end
    function game:Spawn(k) place(k) draw() end
    function game:SetCell(c, r, k) board[(r - 1) * COLS + c] = k or 0 dirty = true draw() end
    function game:Cell(c, r) return board[(r - 1) * COLS + c] end
    function game:Score() return score end
    function game:Piece()
        if kind == 0 then return 0 end
        return kind, px + MINX[kind][rot], py + MINY[kind][rot], rot
    end

    return game
end

G.Register({
    id = "runefall",
    name = L["Rune Fall"],
    blurb = L["Fit the falling runestones into full rows to dissolve them."],
    keys = L["Arrows or WASD: move, turn (up), drop (down)   Space: slam"],
    width = WIDTH,
    height = HEIGHT,
    order = 1,
    New = New,
})
