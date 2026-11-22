-- AzerothRoute: draws the sprites of Sky Patrol, the flight shooter (uncompressed 32-bit TGA, top-left
-- origin) into tools/fork/assets/AzerothRoute/Media/Arcade/:
--   sky (128 x 128, the dusk sky behind the game), cloud (64 x 32), gryphon (the rider, 32 x 32),
--   bat and bat2, harpy and harpy2 (two wing beats each, 32 x 32), bolt (8 x 16), stone (16 x 16),
--   spark (16 x 16, a hit) and life (16 x 16).
--   luajit tools/fork/make_arcade_art.lua
-- The creatures are light grey shapes the game tints with SetVertexColor; every shape is drawn from
-- signed distance functions with 4 x 4 supersampling. Original AzerothRoute artwork (GPL-3.0-only).

local ROOT = (debug.getinfo(1, "S").source:match("^@(.*)[/\\]tools[/\\]fork[/\\]make_arcade_art%.lua$")) or "."
local OUT = ROOT .. "/tools/fork/assets/AzerothRoute/Media/Arcade/"

local sqrt, max, min, abs, floor = math.sqrt, math.max, math.min, math.abs, math.floor

local SAPPHIRE = { 0.075, 0.157, 0.353 } -- #13285A
local NIGHT = { 0.039, 0.102, 0.2 } -- #0A1A33

-- Shapes (pixels, y down; a shape is f(u, v) -> signed distance, < 0 inside) -------------------

local function circle(cx, cy, r)
    return function(u, v) return sqrt((u - cx) ^ 2 + (v - cy) ^ 2) - r end
end

local function ellipse(cx, cy, a, b)
    local k = min(a, b)
    return function(u, v)
        local x, y = (u - cx) / a, (v - cy) / b
        return (sqrt(x * x + y * y) - 1) * k
    end
end

-- Rounded box: centre, half sizes, corner radius.
local function box(cx, cy, hw, hh, r)
    r = r or 0
    return function(u, v)
        local qx, qy = abs(u - cx) - hw + r, abs(v - cy) - hh + r
        return sqrt(max(qx, 0) ^ 2 + max(qy, 0) ^ 2) + min(max(qx, qy), 0) - r
    end
end

local function segDist(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local t = ((px - ax) * dx + (py - ay) * dy) / max(1e-9, dx * dx + dy * dy)
    t = max(0, min(1, t))
    return sqrt((px - ax - t * dx) ^ 2 + (py - ay - t * dy) ^ 2)
end

-- A stroke of width w along a polyline { { x, y }, ... } with round ends.
local function line(pts, w)
    return function(u, v)
        local d = 1e9
        for i = 1, #pts - 1 do
            local a, b = pts[i], pts[i + 1]
            d = min(d, segDist(u, v, a[1], a[2], b[1], b[2]))
        end
        return d - w / 2
    end
end

-- A filled polygon { { x, y }, ... }.
local function poly(pts)
    local n = #pts
    return function(u, v)
        local d = (u - pts[1][1]) ^ 2 + (v - pts[1][2]) ^ 2
        local s = 1
        local j = n
        for i = 1, n do
            local ax, ay, bx, by = pts[i][1], pts[i][2], pts[j][1], pts[j][2]
            local ex, ey = bx - ax, by - ay
            local wx, wy = u - ax, v - ay
            local t = max(0, min(1, (wx * ex + wy * ey) / max(1e-9, ex * ex + ey * ey)))
            local qx, qy = wx - ex * t, wy - ey * t
            d = min(d, qx * qx + qy * qy)
            local c1, c2, c3 = v >= ay, v < by, ex * wy > ey * wx
            if (c1 and c2 and c3) or (not c1 and not c2 and not c3) then s = -s end
            j = i
        end
        return s * sqrt(d)
    end
end

local function U(...)
    local fs = { ... }
    return function(u, v)
        local d = 1e9
        for i = 1, #fs do d = min(d, fs[i](u, v)) end
        return d
    end
end

-- a minus the rest.
local function D(a, ...)
    local cut = U(...)
    return function(u, v) return max(a(u, v), -cut(u, v)) end
end

local function grow(f, r) return function(u, v) return f(u, v) - r end end

-- A shape and its mirror image about the vertical line x = cx.
local function pair(make, cx)
    local mirrored = {}
    return function(pts)
        for i, p in ipairs(pts) do mirrored[i] = { 2 * cx - p[1], p[2] } end
        return U(make(pts), make(mirrored))
    end
end

-- Scaled by k about (cx, cy), then moved by (dx, dy).
local function fit(f, cx, cy, k, dx, dy)
    return function(u, v) return f(cx + (u - cx - dx) / k, cy + (v - cy - dy) / k) * k end
end

-- Rendering ------------------------------------------------------------------------------------

local SS = 4 -- supersampling per axis

local function canvas(w, h)
    local px = {}
    for i = 1, w * h * 4 do px[i] = 0 end
    return { w = w, h = h, px = px }
end

local function blend(cv, x, y, c, a)
    if a <= 0 then return end
    local i = (y * cv.w + x) * 4
    local p = cv.px
    local da = p[i + 4]
    local oa = a + da * (1 - a)
    if oa <= 0 then return end
    for k = 1, 3 do p[i + k] = (c[k] * a + p[i + k] * da * (1 - a)) / oa end
    p[i + 4] = oa
end

-- Coverage of f <= edge over pixel (x, y).
local function cover(f, x, y, edge)
    local n = 0
    for sy = 0, SS - 1 do
        for sx = 0, SS - 1 do
            if f(x + (sx + 0.5) / SS, y + (sy + 0.5) / SS) <= (edge or 0) then n = n + 1 end
        end
    end
    return n / (SS * SS)
end

-- Layers { shape, grey, alpha } drawn in order, after a dark outline round the first `outline` shape.
local function sprite(w, h, layers, outline)
    local cv = canvas(w, h)
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            if outline then blend(cv, x, y, NIGHT, cover(outline, x, y, 1.1) * 0.55) end
            for _, l in ipairs(layers) do
                local g = l[2]
                blend(cv, x, y, { g, g, g }, cover(l[1], x, y) * (l[3] or 1))
            end
        end
    end
    return cv
end

local function writeTGA(cv, name)
    local out = { string.char(0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        cv.w % 256, floor(cv.w / 256), cv.h % 256, floor(cv.h / 256), 32, 40) }
    local p, row = cv.px, {}
    local function q(v) return floor(max(0, min(1, v)) * 255 + 0.5) end
    for i = 0, cv.w * cv.h - 1 do
        local b = i * 4
        row[#row + 1] = string.char(q(p[b + 3]), q(p[b + 2]), q(p[b + 1]), q(p[b + 4]))
        if #row >= 4096 then out[#out + 1] = table.concat(row) row = {} end
    end
    out[#out + 1] = table.concat(row)
    local f = assert(io.open(OUT .. name .. ".tga", "wb"))
    f:write(table.concat(out))
    f:close()
end

-- The gryphon rider, seen from above flying up: spread feathered wings, a beaked head, a fanned tail
-- and the rider on its back.
local function gryphonShape()
    local wings = pair(poly, 16)({ { 13.5, 12 }, { 7, 9.5 }, { 1.5, 9 }, { 2.5, 12 }, { 1, 14.5 }, { 4, 15.5 },
        { 2.5, 18 }, { 6.5, 18 }, { 6, 21 }, { 10, 19.5 }, { 13.5, 20 } })
    local body = ellipse(16, 17, 4.2, 8)
    local head = circle(16, 7.5, 3.6)
    local beak = poly({ { 16, 1.2 }, { 14.2, 5.2 }, { 17.8, 5.2 } })
    local tail = poly({ { 14.5, 23 }, { 11.5, 30.5 }, { 16, 28.5 }, { 20.5, 30.5 }, { 17.5, 23 } })
    return wings, body, head, beak, tail
end

local function gryphon()
    local wings, body, head, beak, tail = gryphonShape()
    local feathers = U(line({ { 12, 14 }, { 4, 12.5 } }, 0.8), line({ { 12, 16.5 }, { 5, 16.5 } }, 0.8),
        line({ { 20, 14 }, { 28, 12.5 } }, 0.8), line({ { 20, 16.5 }, { 27, 16.5 } }, 0.8))
    local rider = U(circle(16, 13, 2.4), box(16, 16.5, 2.2, 2.4, 1))
    local all = U(wings, body, head, beak, tail)
    return sprite(32, 32, {
        { wings, 0.86 }, { feathers, 0.6, 0.7 }, { tail, 0.8 }, { body, 1 }, { head, 1 }, { beak, 0.7 },
        { rider, 0.42 },
    }, all)
end

-- A bat facing down, wings out (up = true: the wings raised).
local function bat(up)
    local lift = up and -4 or 0
    local wing = pair(poly, 16)({ { 13, 13 }, { 8, 9 + lift }, { 1.5, 8 + lift * 1.5 }, { 3, 13 + lift },
        { 1.5, 17 + lift * 0.5 }, { 6, 15.5 }, { 7.5, 21 }, { 10.5, 17 }, { 13.5, 18 } })
    local scallops = U(circle(4.5, 19.5 + lift * 0.5, 2.6), circle(9, 21.5, 2.2), circle(27.5, 19.5 + lift * 0.5, 2.6),
        circle(23, 21.5, 2.2))
    wing = D(wing, scallops)
    local body = ellipse(16, 16, 3.6, 5.2)
    local ears = pair(poly, 16)({ { 13.2, 12 }, { 13.2, 7.5 }, { 15.4, 11 } })
    local eyes = U(circle(14.6, 15, 0.9), circle(17.4, 15, 0.9))
    local all = U(wing, body, ears)
    return sprite(32, 32, { { wing, 0.78 }, { ears, 0.95 }, { body, 1 }, { eyes, 0.15 } }, all)
end

-- A harpy facing down: a woman's head with flowing hair, feathered wings, a feathered body and talons.
local function harpy(up)
    local lift = up and -4 or 0
    local wing = pair(poly, 16)({ { 13, 11 }, { 8, 6 + lift }, { 2, 2 + lift * 1.5 }, { 3.5, 7 + lift }, { 0.8, 9.5 + lift },
        { 4, 11.5 }, { 1, 15 }, { 5, 15.5 }, { 2.5, 19.5 }, { 7.5, 18.5 }, { 8, 22 }, { 12.5, 18 } })
    local quills = U(line({ { 11, 12 }, { 4, 8 + lift } }, 0.8), line({ { 11, 15 }, { 4.5, 13.5 } }, 0.8),
        line({ { 21, 12 }, { 28, 8 + lift } }, 0.8), line({ { 21, 15 }, { 27.5, 13.5 } }, 0.8))
    local hair = U(ellipse(16, 8, 4.8, 5), poly({ { 11.5, 8 }, { 20.5, 8 }, { 19.5, 15 }, { 16, 13 }, { 12.5, 15 } }))
    local face = ellipse(16, 9.5, 2.8, 3.3)
    local body = U(ellipse(16, 17.5, 3.6, 5.5), poly({ { 13, 20 }, { 19, 20 }, { 16, 26 } }))
    local legs = U(line({ { 14.5, 22 }, { 13, 27 }, { 11.5, 29 } }, 1.4), line({ { 13, 27 }, { 14, 29.5 } }, 1.1),
        line({ { 17.5, 22 }, { 19, 27 }, { 20.5, 29 } }, 1.4), line({ { 19, 27 }, { 18, 29.5 } }, 1.1))
    local eyes = U(circle(14.8, 9.6, 0.75), circle(17.2, 9.6, 0.75))
    local all = U(wing, hair, body, legs)
    return sprite(32, 32, {
        { wing, 0.8 }, { quills, 0.55, 0.7 }, { legs, 0.6 }, { body, 0.92 }, { hair, 0.7 }, { face, 1 }, { eyes, 0.15 },
    }, all)
end

-- A thrown bolt: a bright lance in a soft glow.
local function bolt()
    local cv = canvas(8, 16)
    local core = grow(poly({ { 4, 0.8 }, { 5.4, 5 }, { 4.6, 15 }, { 3.4, 15 }, { 2.6, 5 } }), 0.2)
    for y = 0, 15 do
        for x = 0, 7 do
            local d = core(x + 0.5, y + 0.5)
            if d > 0 then blend(cv, x, y, { 1, 0.95, 0.75 }, max(0, 1 - d / 2.6) * 0.55) end
            blend(cv, x, y, { 1, 1, 1 }, cover(core, x, y))
        end
    end
    return cv
end

-- A falling stone: a lumpy rock, lit from the top left.
local function stone()
    local rock = grow(poly({ { 4, 3 }, { 9, 2 }, { 13, 5 }, { 13.5, 10 }, { 10, 13.5 }, { 5, 13 }, { 2.5, 9 } }), 0.4)
    local light = poly({ { 4.5, 4 }, { 9, 3.2 }, { 11, 5 }, { 6, 8 }, { 3.6, 8 } })
    local crack = line({ { 8, 7 }, { 10, 9.5 }, { 9.5, 11.5 } }, 0.8)
    return sprite(16, 16, { { rock, 0.62 }, { light, 0.9, 0.8 }, { crack, 0.3, 0.8 } }, rock)
end

-- A hit: a four-pointed flash with a soft halo.
local function spark()
    local cv = canvas(16, 16)
    local burst = U(poly({ { 8, 0.5 }, { 9.3, 6.7 }, { 15.5, 8 }, { 9.3, 9.3 }, { 8, 15.5 }, { 6.7, 9.3 }, { 0.5, 8 }, { 6.7, 6.7 } }))
    local halo = circle(8, 8, 3)
    for y = 0, 15 do
        for x = 0, 15 do
            local d = halo(x + 0.5, y + 0.5)
            blend(cv, x, y, { 1, 1, 1 }, max(0, 1 - max(0, d) / 4) * 0.45)
            blend(cv, x, y, { 1, 1, 1 }, cover(burst, x, y))
        end
    end
    return cv
end

-- A life: the gryphon at half size.
local function life()
    local wings, body, head, beak, tail = gryphonShape()
    local all = fit(U(wings, body, head, beak, tail), 16, 16, 0.5, -8, -8)
    return sprite(16, 16, { { all, 1 } }, all)
end

-- A soft cloud: overlapping puffs with a feathered edge.
local function cloud()
    local cv = canvas(64, 32)
    local puffs = U(ellipse(32, 20, 26, 8), circle(22, 15, 8), circle(35, 12, 9.5), circle(46, 16, 7))
    for y = 0, 31 do
        for x = 0, 63 do
            local d = puffs(x + 0.5, y + 0.5)
            local a = max(0, min(1, -d / 5))
            if a > 0 then
                local g = 0.82 + 0.18 * (1 - y / 32)
                blend(cv, x, y, { g, g, g + 0.04 }, a * 0.9)
            end
        end
    end
    return cv
end

-- The dusk sky: sapphire deepening to night, a few faint stars high up.
local function sky()
    local cv = canvas(128, 128)
    for y = 0, 127 do
        local t = y / 127
        local c = { SAPPHIRE[1] + (NIGHT[1] - SAPPHIRE[1]) * t, SAPPHIRE[2] + (NIGHT[2] - SAPPHIRE[2]) * t,
            SAPPHIRE[3] + (NIGHT[3] - SAPPHIRE[3]) * t }
        for x = 0, 127 do blend(cv, x, y, c, 1) end
    end
    local seed = 7
    local function rnd()
        seed = (seed * 1103515245 + 12345) % 2147483648
        return seed / 2147483648
    end
    for _ = 1, 22 do
        local sx, sy, r = rnd() * 124 + 2, rnd() * 80 + 2, 0.5 + rnd() * 0.5
        local star = circle(sx, sy, r)
        local glow = 0.25 + rnd() * 0.4
        for y = floor(sy) - 2, floor(sy) + 2 do
            for x = floor(sx) - 2, floor(sx) + 2 do
                if x >= 0 and x < 128 and y >= 0 and y < 128 then
                    blend(cv, x, y, { 0.92, 0.9, 1 }, cover(star, x, y) * glow)
                end
            end
        end
    end
    return cv
end

local art = {
    sky = sky(), cloud = cloud(), gryphon = gryphon(), bat = bat(false), bat2 = bat(true),
    harpy = harpy(false), harpy2 = harpy(true), bolt = bolt(), stone = stone(), spark = spark(), life = life(),
}
local names = {}
for name in pairs(art) do names[#names + 1] = name end
table.sort(names)
for _, name in ipairs(names) do writeTGA(art[name], name) end
print(string.format("%d sprites", #names))
