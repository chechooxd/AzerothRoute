-- AzerothRoute: draws AzerothRoute's own brand textures (uncompressed 32-bit TGA, top-left origin,
-- the format of the Polestar textures they replace) into tools/fork/assets/AzerothRoute/Media/UI/.
--   luajit tools/fork/make_art.lua
-- The mark: a compass ring, a dashed route from a start dot to a map pin. Tinted textures (emblem,
-- watermark, wordmark, band-stars) are white shapes whose alpha the theme colours; logo is in colour.
-- Original AzerothRoute artwork (GPL-3.0-only).

local OUT = "tools/fork/assets/AzerothRoute/Media/UI/"

-- WoW Forever's blue and gold.
local GOLD = { 0.949, 0.757, 0.306 } -- #F2C14E
local BLUE = { 0.302, 0.706, 1 } -- #4DB4FF
local WHITE = { 1, 1, 1 }

local sqrt, max, min, abs, floor = math.sqrt, math.max, math.min, math.abs, math.floor

-- Canvas ---------------------------------------------------------------------------------------

local function canvas(w, h)
    local px = {}
    for i = 1, w * h * 4 do px[i] = 0 end
    return { w = w, h = h, px = px }
end

-- Paints colour c with coverage a (0..1) over pixel (x, y), source-over.
local function blend(cv, x, y, c, a)
    if a <= 0 or x < 0 or y < 0 or x >= cv.w or y >= cv.h then return end
    local i = (y * cv.w + x) * 4
    local p = cv.px
    local da = p[i + 4]
    local oa = a + da * (1 - a)
    if oa <= 0 then return end
    for k = 1, 3 do p[i + k] = (c[k] * a + p[i + k] * da * (1 - a)) / oa end
    p[i + 4] = oa
end

-- Clears coverage a at (x, y) (a hole).
local function erase(cv, x, y, a)
    if x < 0 or y < 0 or x >= cv.w or y >= cv.h then return end
    local i = (y * cv.w + x) * 4
    cv.px[i + 4] = cv.px[i + 4] * (1 - a)
end

-- Draws a shape given by a signed distance function in design units (sdf < 0 inside); `scale` maps
-- design units to pixels. 4x4 supersampling.
local function shape(cv, scale, sdf, c, hole, off)
    local S = 4
    off = off or 0
    for y = 0, cv.h - 1 do
        for x = 0, cv.w - 1 do
            local cov = 0
            for sy = 0, S - 1 do
                for sx = 0, S - 1 do
                    local u = (x + (sx + 0.5) / S - off) / scale
                    local v = (y + (sy + 0.5) / S - off) / scale
                    if sdf(u, v) <= 0 then cov = cov + 1 end
                end
            end
            cov = cov / (S * S)
            if cov > 0 then
                if hole then erase(cv, x, y, cov) else blend(cv, x, y, c, cov) end
            end
        end
    end
end

local function writeTGA(cv, name)
    local out = { string.char(0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        cv.w % 256, floor(cv.w / 256), cv.h % 256, floor(cv.h / 256), 32, 40) }
    local p, row = cv.px, {}
    for i = 0, cv.w * cv.h - 1 do
        local b = i * 4
        local function q(v) return floor(max(0, min(1, v)) * 255 + 0.5) end
        row[#row + 1] = string.char(q(p[b + 3]), q(p[b + 2]), q(p[b + 1]), q(p[b + 4]))
        if #row >= 4096 then out[#out + 1] = table.concat(row) row = {} end
    end
    out[#out + 1] = table.concat(row)
    local f = assert(io.open(OUT .. name .. ".tga", "wb"))
    f:write(table.concat(out))
    f:close()
    print(string.format("%-16s %dx%d", name, cv.w, cv.h))
end

-- Geometry (design box 120 x 120) --------------------------------------------------------------

local function ring(cx, cy, r, w)
    return function(u, v) return abs(sqrt((u - cx) ^ 2 + (v - cy) ^ 2) - r) - w / 2 end
end

local function disc(cx, cy, r)
    return function(u, v) return sqrt((u - cx) ^ 2 + (v - cy) ^ 2) - r end
end

local function segDist(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local t = ((px - ax) * dx + (py - ay) * dy) / max(1e-9, dx * dx + dy * dy)
    t = max(0, min(1, t))
    return sqrt((px - ax - t * dx) ^ 2 + (py - ay - t * dy) ^ 2)
end

-- Capsules along a polyline: dashed when dash/gap are given.
local function stroke(points, w, dash, gap)
    local segs, acc = {}, 0
    for i = 1, #points - 1 do
        local a, b = points[i], points[i + 1]
        local len = sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
        local on = true
        if dash then on = (acc % (dash + gap)) < dash end
        if on then segs[#segs + 1] = { a[1], a[2], b[1], b[2] } end
        acc = acc + len
    end
    return function(u, v)
        local d = 1e9
        for _, s in ipairs(segs) do d = min(d, segDist(u, v, s[1], s[2], s[3], s[4])) end
        return d - w / 2
    end
end

local function cubic(p0, p1, p2, p3, n, out)
    out = out or {}
    for i = (#out == 0 and 0 or 1), n do
        local t = i / n
        local a, b, c, d = (1 - t) ^ 3, 3 * (1 - t) ^ 2 * t, 3 * (1 - t) * t ^ 2, t ^ 3
        out[#out + 1] = { a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1], a * p0[2] + b * p1[2] + c * p2[2] + d * p3[2] }
    end
    return out
end

-- The route: from the start dot (34, 88) to the pin's tip (82, 36).
local ROUTE = cubic({ 34, 88 }, { 40, 70 }, { 62, 78 }, { 58, 60 }, 40)
cubic({ 58, 60 }, { 54, 42 }, { 70, 40 }, { 82, 36 }, 40, ROUTE)

-- The map pin: a round head and a point.
local function pin(cx, cy, r, tipY)
    return function(u, v)
        local head = sqrt((u - cx) ^ 2 + (v - cy) ^ 2) - r
        -- The point: the region between two lines from the tip tangent-ish to the head.
        if v > cy and v <= tipY then
            local half = r * (tipY - v) / (tipY - cy)
            local body = abs(u - cx) - half
            return min(head, body)
        end
        return head
    end
end

local function ticks(cx, cy, r1, r2, w)
    return function(u, v)
        local d = 1e9
        d = min(d, segDist(u, v, cx, cy - r1, cx, cy - r2))
        d = min(d, segDist(u, v, cx, cy + r1, cx, cy + r2))
        d = min(d, segDist(u, v, cx - r1, cy, cx - r2, cy))
        d = min(d, segDist(u, v, cx + r1, cy, cx + r2, cy))
        return d - w / 2
    end
end

-- inset: the share of the texture the mark's ink spans (Polestar's emblem slots expect about 0.73).
local function mark(cv, size, colors, inset)
    inset = inset or 0.97
    local scale = size * inset / 120
    local off = size * (1 - inset) / 2
    shape(cv, scale, ring(60, 60, 52, 5), colors.ring, false, off)
    shape(cv, scale, ticks(60, 60, 56, 47, 5), colors.ring, false, off)
    shape(cv, scale, stroke(ROUTE, 6, 9, 7), colors.route, false, off)
    shape(cv, scale, disc(34, 88, 7), colors.dot, false, off)
    shape(cv, scale, pin(82, 31, 12, 50), colors.pin, false, off)
    shape(cv, scale, disc(82, 31, 5), nil, true, off)
end

-- Textures -------------------------------------------------------------------------------------

-- logo (minimap button, launcher, update card, AddOns list icon) is not drawn here: it is the painted
-- AzerothRoute emblem (gold compass "A" with a blue route), scaled to 64 x 64 in the same TGA format.
-- emblem-color (setup pages, Options) is the same painting at 128 x 128, in colour and never tinted.

-- emblem: white, tinted by the accent.
do
    local cv = canvas(128, 128)
    mark(cv, 128, { ring = WHITE, route = WHITE, dot = WHITE, pin = WHITE }, 0.73)
    writeTGA(cv, "emblem")
end

-- emblem-hot: a bright core on the pin, laid over the emblem.
do
    local cv = canvas(128, 128)
    local s, off = 128 * 0.73 / 120, 128 * 0.27 / 2
    for r = 14, 4, -2 do
        shape(cv, s, disc(82, 31, r), { 1, 1, 1 }, false, off)
    end
    -- Soften: scale alpha down so it reads as a glow.
    for i = 4, #cv.px, 4 do cv.px[i] = cv.px[i] * 0.45 end
    shape(cv, s, disc(82, 31, 5), nil, true, off)
    writeTGA(cv, "emblem-hot")
end

-- watermark: the mark, large, for faint backgrounds.
do
    local cv = canvas(256, 256)
    mark(cv, 256, { ring = WHITE, route = WHITE, dot = WHITE, pin = WHITE }, 0.85)
    writeTGA(cv, "watermark")
end

-- band-stars: the header band's pattern, map contour lines instead of stars.
do
    local cv = canvas(1024, 128)
    for k = 0, 6 do
        local pts = {}
        local base = 10 + k * 18
        for x = 0, 1024, 8 do
            pts[#pts + 1] = { x, base + 7 * math.sin(x / 70 + k * 1.3) + 4 * math.sin(x / 23 + k) }
        end
        local f = stroke(pts, 1.2)
        local strength = 0.35 + 0.1 * (k % 3)
        local tmp = canvas(1024, 128)
        shape(tmp, 1, f, WHITE)
        for i = 4, #tmp.px, 4 do
            if tmp.px[i] > 0 then
                local idx = (i - 4) / 4
                blend(cv, idx % 1024, floor(idx / 1024), WHITE, tmp.px[i] * strength)
            end
        end
    end
    writeTGA(cv, "band-stars")
end

-- wordmark: AZEROTHROUTE in stroke capitals (256 x 32), tinted by the text colour.
local GLYPHS = {
    A = { { { 0, 1 }, { 0.5, 0 }, { 1, 1 } }, { { 0.22, 0.6 }, { 0.78, 0.6 } } },
    Z = { { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } },
    E = { { { 1, 0 }, { 0, 0 }, { 0, 1 }, { 1, 1 } }, { { 0, 0.5 }, { 0.8, 0.5 } } },
    R = { { { 0, 1 }, { 0, 0 }, { 0.7, 0 }, { 0.95, 0.12 }, { 0.95, 0.38 }, { 0.7, 0.5 }, { 0, 0.5 } }, { { 0.45, 0.5 }, { 1, 1 } } },
    O = { { { 0.3, 0 }, { 0.7, 0 }, { 1, 0.3 }, { 1, 0.7 }, { 0.7, 1 }, { 0.3, 1 }, { 0, 0.7 }, { 0, 0.3 }, { 0.3, 0 } } },
    T = { { { 0, 0 }, { 1, 0 } }, { { 0.5, 0 }, { 0.5, 1 } } },
    H = { { { 0, 0 }, { 0, 1 } }, { { 1, 0 }, { 1, 1 } }, { { 0, 0.5 }, { 1, 0.5 } } },
    U = { { { 0, 0 }, { 0, 0.7 }, { 0.3, 1 }, { 0.7, 1 }, { 1, 0.7 }, { 1, 0 } } },
}

local function wordmark(name, text, gw, gh, gap, w)
    local cv = canvas(256, 32)
    local total = #text * gw + (#text - 1) * gap
    -- Left-aligned: the guide menu places the word's ink 2 px from the texture's edge (Widgets WORD_INK).
    local x0, y0 = 2 + w / 2, (32 - gh) / 2
    for i = 1, #text do
        local g = GLYPHS[text:sub(i, i)]
        local ox = x0 + (i - 1) * (gw + gap)
        for _, line in ipairs(g) do
            local pts = {}
            for _, p in ipairs(line) do pts[#pts + 1] = { ox + p[1] * gw, y0 + p[2] * gh } end
            shape(cv, 1, stroke(pts, w), WHITE)
        end
    end
    writeTGA(cv, name)
end

-- Ink widths match Polestar's (181 and 125 px): the menus size their columns to them.
wordmark("wordmark", "AZEROTHROUTE", 11, 17, 4.1, 2.1)
wordmark("wordmark-small", "AZEROTHROUTE", 7.4, 12, 3, 1.6)

-- round-8 and round-8-ring: a white rounded rectangle (32 x 32, corners of radius 8) and its 1px edge,
-- drawn as nine-slice textures (slice margins 8) for the Battle.net look's surfaces (Theme/Battlenet.lua).
local function roundRect(x0, y0, x1, y1, r)
    return function(u, v)
        local qx = max(x0 + r - u, 0, u - (x1 - r))
        local qy = max(y0 + r - v, 0, v - (y1 - r))
        return sqrt(qx * qx + qy * qy) - r
    end
end
do
    local cv = canvas(32, 32)
    shape(cv, 1, roundRect(0, 0, 32, 32, 8), WHITE)
    writeTGA(cv, "round-8")
    local ring = canvas(32, 32)
    shape(ring, 1, roundRect(0, 0, 32, 32, 8), WHITE)
    shape(ring, 1, roundRect(1.2, 1.2, 30.8, 30.8, 6.8), nil, true)
    writeTGA(ring, "round-8-ring")
end
