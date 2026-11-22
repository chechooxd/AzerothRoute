-- AzerothRoute: Gem Bazaar, a match-three flight game. Swap two neighbouring gems to line up three or more
-- of a kind; they shatter, the gems above fall and new ones drop in, and every cascade counts more. Four in
-- a line leave a flare gem (it clears its row and column when it shatters), five or more a prism (swapped
-- with a gem, every gem of that kind shatters). Each level has a target score and a number of moves; reach
-- the target to go on, run out of moves before it and the game is over.
-- Original AzerothRoute code (GPL-3.0-only).

local ADDON, ns = ...
local L = ns.L
local G = ns.Games
if not G then return end

local COLS, ROWS, CELL, HEAD = 8, 8, 34, 24
local WIDTH, HEIGHT = COLS * CELL, ROWS * CELL + HEAD
local KINDS = 6
local PRISM = KINDS + 1 -- the prism's kind: it never lines up
local NONE, FLARE, PRIZE = 0, 1, 2 -- specials (PRIZE: the prism)
local SWAP_T, CLEAR_T, FALL_SPEED, FALL_ACCEL = 0.14, 0.2, 260, 1400
local HINT_AFTER = 7
local GEM_POINTS = 10
local FIRST_MOVES, FIRST_TARGET, TARGET_STEP = 20, 1200, 900

-- The gems: the game's own gem icons over a tint of their colour (the tint alone if an icon is missing).
local GEMS = {
    { icon = "Interface\\Icons\\INV_Misc_Gem_Ruby_02", color = { 0.86, 0.18, 0.2 } },
    { icon = "Interface\\Icons\\INV_Misc_Gem_Emerald_02", color = { 0.2, 0.74, 0.32 } },
    { icon = "Interface\\Icons\\INV_Misc_Gem_Sapphire_02", color = { 0.22, 0.42, 0.9 } },
    { icon = "Interface\\Icons\\INV_Misc_Gem_Topaz_02", color = { 0.95, 0.62, 0.16 } },
    { icon = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02", color = { 0.62, 0.3, 0.86 } },
    { icon = "Interface\\Icons\\INV_Misc_Gem_Opal_01", color = { 0.86, 0.88, 0.92 } },
    { icon = "Interface\\Icons\\INV_Misc_Gem_Diamond_01", color = { 1, 1, 1 } }, -- the prism
}

local floor, min, max, abs, sin, random = math.floor, math.min, math.max, math.abs, math.sin, math.random

local function idx(c, r) return (r - 1) * COLS + c end
local function colOf(i) return (i - 1) % COLS + 1 end
local function rowOf(i) return floor((i - 1) / COLS) + 1 end

local function New(view, host)
    local game = {}
    local kind, spec = {}, {} -- per cell: gem kind (0 empty) and special
    local offY, offX = {}, {} -- per cell: how far its gem is drawn from its place (pixels; y up)
    local speed = {} -- per cell: falling speed
    local phase, phaseT = "idle", 0
    local swapA, swapB, swapBack
    local clearing = {} -- cells shattering now
    local chain = 0
    local score, level, moves, target = 0, 1, FIRST_MOVES, FIRST_TARGET
    local curC, curR, pickI = 4, 4, nil
    local idleT, hintA, hintB = 0, nil, nil
    local clock = 0
    local rand = function() return random(KINDS) end
    local over = false

    ---------------------------------------------------------------------------
    -- Drawing
    ---------------------------------------------------------------------------
    local back = view:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints(view)
    back:SetColorTexture(0.03, 0.06, 0.12, 1)
    local ar, ag, ab = host.Color("accent")
    -- The board's chequer.
    for r = 1, ROWS do
        for c = 1, COLS do
            if (r + c) % 2 == 0 then
                local t = view:CreateTexture(nil, "BACKGROUND", nil, 1)
                t:SetColorTexture(ar, ag, ab, 0.06)
                t:SetSize(CELL, CELL)
                t:SetPoint("TOPLEFT", view, "TOPLEFT", (c - 1) * CELL, -HEAD - (r - 1) * CELL)
            end
        end
    end
    local headBack = view:CreateTexture(nil, "BACKGROUND", nil, 2)
    headBack:SetPoint("TOPLEFT", view, "TOPLEFT", 0, 0)
    headBack:SetSize(WIDTH, HEAD)
    headBack:SetColorTexture(0, 0, 0, 0.35)

    -- The gems draw in a frame of their own under the header, so a gem dropping in is clipped at the top.
    local board = CreateFrame("Frame", nil, view)
    board:SetPoint("TOPLEFT", view, "TOPLEFT", 0, -HEAD)
    board:SetSize(WIDTH, ROWS * CELL)
    if board.SetClipsChildren then board:SetClipsChildren(true) end

    local headText, banner
    if ns.Widgets and ns.Widgets.Text then
        headText = ns.Widgets.Text(view, "note", "text")
        headText:SetPoint("LEFT", view, "TOPLEFT", 6, -HEAD / 2)
        banner = ns.Widgets.Text(board, "display", "accent")
        banner:SetPoint("CENTER", board, "CENTER", 0, 0)
        if banner.SetDrawLayer then banner:SetDrawLayer("OVERLAY", 7) end
        banner:Hide()
    end
    local bannerT = 0

    -- One button per cell: the gem's tint, its icon, the flare's cross and a glow for the prism.
    local cells = {}
    for r = 1, ROWS do
        for c = 1, COLS do
            local i = idx(c, r)
            local b = CreateFrame("Button", nil, board)
            b:SetSize(CELL, CELL)
            b.Tint = b:CreateTexture(nil, "ARTWORK", nil, 1)
            b.Tint:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
            b.Tint:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
            b.Icon = b:CreateTexture(nil, "ARTWORK", nil, 2)
            b.Icon:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -4)
            b.Icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4, 4)
            b.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            b.FlareH = b:CreateTexture(nil, "OVERLAY", nil, 1)
            b.FlareH:SetSize(CELL - 6, 4)
            b.FlareH:SetPoint("CENTER", b, "CENTER")
            b.FlareV = b:CreateTexture(nil, "OVERLAY", nil, 1)
            b.FlareV:SetSize(4, CELL - 6)
            b.FlareV:SetPoint("CENTER", b, "CENTER")
            b.FlareH:SetColorTexture(1, 0.95, 0.7, 0.85)
            b.FlareV:SetColorTexture(1, 0.95, 0.7, 0.85)
            b:SetScript("OnClick", function() game:Click(c, r) end)
            cells[i] = b
            kind[i], spec[i], offX[i], offY[i], speed[i] = 0, NONE, 0, 0, 0
        end
    end

    -- A square outline of four bars (the keyboard cursor and the picked gem).
    local function outline(r, g, bl, a, size)
        local f = CreateFrame("Frame", nil, board)
        f:SetSize(CELL, CELL)
        if f.SetFrameLevel and board.GetFrameLevel then f:SetFrameLevel((board:GetFrameLevel() or 1) + 5) end
        local function bar(p1, p2, w, h)
            local t = f:CreateTexture(nil, "OVERLAY", nil, 5)
            t:SetColorTexture(r, g, bl, a)
            t:SetPoint(p1, f, p1)
            t:SetPoint(p2, f, p2)
            if w then t:SetWidth(w) else t:SetHeight(h) end
        end
        bar("TOPLEFT", "TOPRIGHT", nil, size)
        bar("BOTTOMLEFT", "BOTTOMRIGHT", nil, size)
        bar("TOPLEFT", "BOTTOMLEFT", size, nil)
        bar("TOPRIGHT", "BOTTOMRIGHT", size, nil)
        f:Hide()
        return f
    end
    local cursor = outline(1, 1, 1, 0.55, 1)
    local pick = outline(ar, ag, ab, 1, 2)

    local function at(f, c, r)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", board, "TOPLEFT", (c - 1) * CELL, -(r - 1) * CELL)
    end

    local function placeCell(i)
        local b = cells[i]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", board, "TOPLEFT", (colOf(i) - 1) * CELL + offX[i], -(rowOf(i) - 1) * CELL + offY[i])
    end

    local function paintCell(i)
        local b, k = cells[i], kind[i]
        placeCell(i)
        if k == 0 then b:Hide() return end
        local gem = GEMS[k]
        b.Tint:SetColorTexture(gem.color[1] * 0.5, gem.color[2] * 0.5, gem.color[3] * 0.5, 0.55)
        b.Icon:SetTexture(gem.icon)
        b.Icon:SetVertexColor(1, 1, 1, 1)
        b:SetAlpha(1)
        b.FlareH:SetShown(spec[i] == FLARE)
        b.FlareV:SetShown(spec[i] == FLARE)
        b:Show()
    end

    local function paintAll()
        for i = 1, COLS * ROWS do paintCell(i) end
    end

    local function paintHead()
        if headText then
            headText:SetText(L["Level %d   Target %d   Moves %d"]:format(level, target, moves))
        end
        host.Score(score)
    end

    local function paintMarks()
        if curC then at(cursor, curC, curR) cursor:Show() else cursor:Hide() end
        if pickI then at(pick, colOf(pickI), rowOf(pickI)) pick:Show() else pick:Hide() end
    end

    local function showBanner(text)
        if not banner then return end
        banner:SetText(text)
        banner:Show()
        bannerT = 1.2
    end

    ---------------------------------------------------------------------------
    -- Rules
    ---------------------------------------------------------------------------
    local function lines(k) return k > 0 and k <= KINDS end

    -- The groups of three or more in a line: { cells = { i, ... }, kind }, runs crossing in an L or a T
    -- joined into one group.
    local function findGroups()
        local marked = {}
        local any = false
        for r = 1, ROWS do
            local c = 1
            while c <= COLS do
                local k = kind[idx(c, r)]
                local e = c
                while e < COLS and lines(k) and kind[idx(e + 1, r)] == k do e = e + 1 end
                if lines(k) and e - c >= 2 then
                    for x = c, e do marked[idx(x, r)] = true end
                    any = true
                end
                c = e + 1
            end
        end
        for c = 1, COLS do
            local r = 1
            while r <= ROWS do
                local k = kind[idx(c, r)]
                local e = r
                while e < ROWS and lines(k) and kind[idx(c, e + 1)] == k do e = e + 1 end
                if lines(k) and e - r >= 2 then
                    for y = r, e do marked[idx(c, y)] = true end
                    any = true
                end
                r = e + 1
            end
        end
        if not any then return nil end
        local groups, seen = {}, {}
        for i = 1, COLS * ROWS do
            if marked[i] and not seen[i] then
                local k, list, stack = kind[i], {}, { i }
                seen[i] = true
                while #stack > 0 do
                    local j = table.remove(stack)
                    list[#list + 1] = j
                    local c, r = colOf(j), rowOf(j)
                    local near = { c > 1 and j - 1, c < COLS and j + 1, r > 1 and j - COLS, r < ROWS and j + COLS }
                    for n = 1, 4 do
                        local m = near[n]
                        if m and marked[m] and not seen[m] and kind[m] == k then
                            seen[m] = true
                            stack[#stack + 1] = m
                        end
                    end
                end
                table.sort(list)
                groups[#groups + 1] = { cells = list, kind = k }
            end
        end
        return groups
    end

    local function wouldLine(a, b)
        kind[a], kind[b] = kind[b], kind[a]
        local ok = findGroups() ~= nil
        kind[a], kind[b] = kind[b], kind[a]
        return ok
    end

    -- A swap that does something: a, b (cells) or nil.
    local function findMove()
        for i = 1, COLS * ROWS do
            if kind[i] == PRISM then
                local c = colOf(i)
                return i, c < COLS and i + 1 or i - 1
            end
        end
        for i = 1, COLS * ROWS do
            local c, r = colOf(i), rowOf(i)
            if c < COLS and wouldLine(i, i + 1) then return i, i + 1 end
            if r < ROWS and wouldLine(i, i + COLS) then return i, i + COLS end
        end
        return nil
    end

    local function mostCommon()
        local n, best, bestN = {}, 1, -1
        for i = 1, COLS * ROWS do
            local k = kind[i]
            if lines(k) then n[k] = (n[k] or 0) + 1 end
        end
        for k = 1, KINDS do
            if (n[k] or 0) > bestN then best, bestN = k, n[k] or 0 end
        end
        return best
    end

    -- Adds what the specials in the set take with them: a flare its row and column, a prism every gem
    -- of the board's most common kind.
    local function spread(set)
        local queue = {}
        for i in pairs(set) do queue[#queue + 1] = i end
        local done = {}
        while #queue > 0 do
            local i = table.remove(queue)
            if not done[i] then
                done[i] = true
                local add
                if spec[i] == FLARE then
                    add = {}
                    local c, r = colOf(i), rowOf(i)
                    for x = 1, COLS do add[#add + 1] = idx(x, r) end
                    for y = 1, ROWS do add[#add + 1] = idx(c, y) end
                elseif spec[i] == PRIZE then
                    add = {}
                    local k = mostCommon()
                    for j = 1, COLS * ROWS do if kind[j] == k then add[#add + 1] = j end end
                end
                for _, j in ipairs(add or {}) do
                    if kind[j] ~= 0 and not set[j] then
                        set[j] = true
                        queue[#queue + 1] = j
                    end
                end
            end
        end
    end

    local function count(set)
        local n = 0
        for _ in pairs(set) do n = n + 1 end
        return n
    end

    -- Shatters the set (with what its specials take): the score, then the flash.
    local function shatter(set, makes)
        spread(set)
        chain = chain + 1
        local n = count(set)
        score = score + n * GEM_POINTS * chain
        for i in pairs(clearing) do clearing[i] = nil end
        for i in pairs(set) do clearing[i] = true end
        clearing.makes = makes
        phase, phaseT = "clear", 0
        local special = false
        for i in pairs(set) do if spec[i] ~= NONE then special = true end end
        host.Sound((special or chain >= 3 or n >= 6) and "big" or "clear")
        if chain >= 3 then showBanner(L["Cascade x%d"]:format(chain)) end
        paintHead()
    end

    -- The lines on the board shatter; a four leaves a flare, a five or more a prism, on the swapped cell
    -- when it is part of the group. -> whether anything lined up.
    local function resolve(a, b)
        local groups = findGroups()
        if not groups then return false end
        local set, makes = {}, {}
        for _, g in ipairs(groups) do
            local size = #g.cells
            local keep
            if size >= 4 then
                for _, i in ipairs(g.cells) do if i == a or i == b then keep = i end end
                keep = keep or g.cells[floor((size + 1) / 2)]
                makes[#makes + 1] = { i = keep, kind = size >= 5 and PRISM or g.kind, spec = size >= 5 and PRIZE or FLARE }
            end
            for _, i in ipairs(g.cells) do if i ~= keep then set[i] = true end end
            -- A special in the group goes off even where the new one is made.
            if keep and spec[keep] ~= NONE then set[keep] = true end
        end
        shatter(set, makes)
        return true
    end

    -- The shattered cells empty, new specials appear, the gems above fall and new ones drop in.
    local function collapse()
        for i in pairs(clearing) do
            if type(i) == "number" then kind[i], spec[i] = 0, NONE end
        end
        for _, m in ipairs(clearing.makes or {}) do kind[m.i], spec[m.i] = m.kind, m.spec end
        for c = 1, COLS do
            local w = ROWS
            for r = ROWS, 1, -1 do
                local i = idx(c, r)
                if kind[i] ~= 0 then
                    if w ~= r then
                        local j = idx(c, w)
                        kind[j], spec[j] = kind[i], spec[i]
                        kind[i], spec[i] = 0, NONE
                        offY[j], speed[j] = (w - r) * CELL, 0
                    end
                    w = w - 1
                end
            end
            for r = w, 1, -1 do
                local j = idx(c, r)
                kind[j], spec[j] = rand(c, r), NONE
                offY[j], speed[j] = w * CELL, 0
            end
        end
        for i in pairs(clearing) do clearing[i] = nil end
        phase, phaseT = "fall", 0
        paintAll()
    end

    -- A new board with nothing lined up and a move to make (rand's kinds, changed where they would line up).
    local function fillFresh()
        local pickKind = rand
        for _ = 1, 50 do
            for r = 1, ROWS do
                for c = 1, COLS do
                    local i = idx(c, r)
                    spec[i] = NONE
                    local k = pickKind(c, r)
                    for _ = 1, KINDS do
                        local h = c > 2 and kind[i - 1] == k and kind[i - 2] == k
                        local v = r > 2 and kind[i - COLS] == k and kind[i - 2 * COLS] == k
                        if not (h or v) then break end
                        k = k % KINDS + 1
                    end
                    kind[i] = k
                end
            end
            if findMove() then return end
            pickKind = function() return random(KINDS) end
        end
    end

    -- The hint's gems stop pulsing (the player moved, or a turn ended).
    local function quiet()
        if hintA then cells[hintA]:SetAlpha(1) end
        if hintB then cells[hintB]:SetAlpha(1) end
        idleT, hintA, hintB = 0, nil, nil
    end

    -- No move left: the gems are dealt again (dropping in from the top).
    local function shuffle()
        fillFresh()
        for i = 1, COLS * ROWS do offY[i], speed[i] = ROWS * CELL, 0 end
        phase, phaseT = "fall", 0
        showBanner(L["No moves: new gems"])
        paintAll()
    end

    -- The turn is over: the level's target, the moves left, a move to make.
    local function settle()
        chain = 0
        if score >= target then
            level = level + 1
            target = score + FIRST_TARGET + TARGET_STEP * (level - 1)
            moves = FIRST_MOVES
            host.Sound("levelup")
            showBanner(L["Level %d"]:format(level))
        elseif moves <= 0 then
            phase = "idle"
            paintHead()
            over = true
            host.Over(score)
            return
        end
        paintHead()
        phase = "idle"
        quiet()
        if not findMove() then shuffle() end
    end

    local function adjacent(a, b)
        local d = abs(a - b)
        return (d == 1 and rowOf(a) == rowOf(b)) or d == COLS
    end

    -- Swaps the gems of cells a and b (the animation first).
    local function trySwap(a, b)
        if phase ~= "idle" or over or not adjacent(a, b) or kind[a] == 0 or kind[b] == 0 then return false end
        pickI = nil
        quiet()
        swapA, swapB, swapBack = a, b, false
        phase, phaseT = "swap", 0
        host.Sound("turn")
        paintMarks()
        return true
    end

    -- The swap has played: a prism takes its kind, a line shatters, nothing sends the gems back.
    local function afterSwap()
        local a, b = swapA, swapB
        offX[a], offY[a], offX[b], offY[b] = 0, 0, 0, 0
        if swapBack then
            phase = "idle"
            paintCell(a) paintCell(b)
            return
        end
        kind[a], kind[b] = kind[b], kind[a]
        spec[a], spec[b] = spec[b], spec[a]
        paintCell(a) paintCell(b)
        if kind[a] == PRISM or kind[b] == PRISM then
            moves = moves - 1
            local set = {}
            if kind[a] == PRISM and kind[b] == PRISM then
                for i = 1, COLS * ROWS do set[i] = true end
            else
                local p = kind[a] == PRISM and a or b
                local k = kind[p == a and b or a]
                set[p] = true
                for i = 1, COLS * ROWS do if kind[i] == k then set[i] = true end end
                spec[p] = NONE -- the prism has spent itself on that kind
            end
            shatter(set)
            return
        end
        if resolve(a, b) then
            moves = moves - 1
            paintHead()
            return
        end
        -- Nothing lines up: back they go.
        kind[a], kind[b] = kind[b], kind[a]
        spec[a], spec[b] = spec[b], spec[a]
        paintCell(a) paintCell(b)
        swapBack = true
        phase, phaseT = "swap", 0
        host.Sound("slam")
    end

    ---------------------------------------------------------------------------
    -- Input and frames
    ---------------------------------------------------------------------------
    function game:Click(c, r)
        if phase ~= "idle" or over then return false end
        local i = idx(c, r)
        curC, curR = c, r
        quiet()
        if pickI and pickI ~= i and adjacent(pickI, i) then
            return trySwap(pickI, i)
        end
        pickI = pickI ~= i and i or nil
        paintMarks()
        return true
    end

    local DIRS = { LEFT = { -1, 0 }, A = { -1, 0 }, RIGHT = { 1, 0 }, D = { 1, 0 }, UP = { 0, -1 }, W = { 0, -1 }, DOWN = { 0, 1 }, S = { 0, 1 } }

    function game:Key(key, down)
        if not down then return DIRS[key] ~= nil or key == "SPACE" or key == "ENTER" end
        local d = DIRS[key]
        if d then
            quiet()
            local c, r = curC + d[1], curR + d[2]
            if c < 1 or c > COLS or r < 1 or r > ROWS then return true end
            if pickI then
                trySwap(pickI, idx(c, r))
                curC, curR = c, r
            else
                curC, curR = c, r
            end
            paintMarks()
            return true
        end
        if key == "SPACE" or key == "ENTER" then
            if phase == "idle" then
                local i = idx(curC, curR)
                pickI = pickI ~= i and i or nil
                paintMarks()
            end
            return true
        end
        return false
    end

    function game:Update(dt)
        clock = clock + dt
        if bannerT > 0 then
            bannerT = bannerT - dt
            if bannerT <= 0 and banner then banner:Hide() end
        end
        if phase == "swap" then
            phaseT = phaseT + dt
            local f = min(1, phaseT / SWAP_T)
            if swapBack then f = 1 - f end
            local a, b = swapA, swapB
            local dx = (colOf(b) - colOf(a)) * CELL * f
            local dy = -(rowOf(b) - rowOf(a)) * CELL * f
            offX[a], offY[a], offX[b], offY[b] = dx, dy, -dx, -dy
            placeCell(a) placeCell(b)
            if phaseT >= SWAP_T then afterSwap() end
        elseif phase == "clear" then
            phaseT = phaseT + dt
            local a = 1 - min(1, phaseT / CLEAR_T)
            for i in pairs(clearing) do
                if type(i) == "number" then cells[i]:SetAlpha(0.25 + 0.75 * a * (0.6 + 0.4 * sin(phaseT * 60))) end
            end
            if phaseT >= CLEAR_T then collapse() end
        elseif phase == "fall" then
            local moving = false
            for i = 1, COLS * ROWS do
                if offY[i] > 0 then
                    speed[i] = speed[i] + FALL_ACCEL * dt
                    offY[i] = max(0, offY[i] - (FALL_SPEED + speed[i]) * dt)
                    placeCell(i)
                    moving = true
                end
            end
            if not moving then
                if not resolve() then settle() end
            end
        elseif phase == "idle" then
            idleT = idleT + dt
            if idleT >= HINT_AFTER then
                if not hintA then hintA, hintB = findMove() end
                local a = 0.55 + 0.45 * sin(clock * 6)
                if hintA then cells[hintA]:SetAlpha(a) end
                if hintB then cells[hintB]:SetAlpha(a) end
            end
        end
        -- The prisms shimmer.
        for i = 1, COLS * ROWS do
            if kind[i] == PRISM and phase ~= "clear" then
                local t = clock * 2 + i
                cells[i].Tint:SetColorTexture(0.5 + 0.5 * sin(t), 0.5 + 0.5 * sin(t + 2.1), 0.5 + 0.5 * sin(t + 4.2), 0.7)
            end
        end
    end

    function game:Reset()
        score, level, moves, target, chain = 0, 1, FIRST_MOVES, FIRST_TARGET, 0
        phase, phaseT, pickI, over = "idle", 0, nil, false
        curC, curR = 4, 4
        idleT, hintA, hintB = 0, nil, nil
        for i in pairs(clearing) do clearing[i] = nil end
        for i = 1, COLS * ROWS do offX[i], offY[i], speed[i] = 0, 0, 0 end
        fillFresh()
        if banner then banner:Hide() end
        bannerT = 0
        paintAll()
        paintHead()
        paintMarks()
    end

    -- For the checks (Tests/game_gembazaar.lua).
    function game:SetRandom(fn) rand = fn end
    function game:SetCell(c, r, k, s) local i = idx(c, r) kind[i], spec[i] = k, s or NONE paintCell(i) end
    function game:Cell(c, r) local i = idx(c, r) return kind[i], spec[i] end
    function game:Settle()
        for _ = 1, 2000 do
            if phase == "idle" or over then return true end
            game:Update(0.05)
        end
        return false
    end
    function game:Phase() return phase end
    function game:Score() return score end
    function game:Moves() return moves end
    function game:SetMoves(n) moves = n paintHead() end
    function game:Level() return level end
    function game:Target() return target end
    function game:SetTarget(n) target = n paintHead() end
    function game:Lined() return findGroups() ~= nil end
    function game:FindMove() return findMove() end
    function game:Cursor() return curC, curR, pickI end
    function game:Cells() return cells end
    game.PRISM, game.FLARE, game.PRIZE, game.KINDS = PRISM, FLARE, PRIZE, KINDS

    return game
end

G.Register({
    id = "gembazaar",
    name = L["Gem Bazaar"],
    blurb = L["Swap neighbouring gems to line up three or more. Reach the level's target before your moves run out."],
    keys = L["Click two gems, or arrows or WASD and Space: pick, then an arrow swaps"],
    width = WIDTH,
    height = HEIGHT,
    order = 3,
    New = New,
})
