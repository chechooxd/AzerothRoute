-- AzerothRoute: draws AzerothRoute's own guide step and map icons (uncompressed 32-bit TGA, top-left
-- origin, the format and names of the Polestar textures they replace) into
-- tools/fork/assets/AzerothRoute/Media/UI/ (icon-<step>, 32 x 32, white: the theme tints them) and
-- tools/fork/assets/AzerothRoute/Media/Map/ (icon-<mark>, 64 x 64: a pearl glyph with a night rim and a
-- soft shadow, tinted by the pin colour, and the medallion under them).
--   luajit tools/fork/make_icons.lua
-- Every glyph is drawn here from signed distance functions in a 32 x 32 design box; flight is a winged
-- boot. Original AzerothRoute artwork (GPL-3.0-only).

local ROOT = (debug.getinfo(1, "S").source:match("^@(.*)[/\\]tools[/\\]fork[/\\]make_icons%.lua$")) or "."
local OUT = ROOT .. "/tools/fork/assets/AzerothRoute/Media/"

local sqrt, max, min, abs, floor = math.sqrt, math.max, math.min, math.abs, math.floor
local cos, sin, rad, pi = math.cos, math.sin, math.rad, math.pi

local GOLD = { 0.949, 0.757, 0.306 } -- #F2C14E
local WHITE = { 1, 1, 1 }
local PEARL = { 0.925, 0.902, 0.863 } -- #ECE6DC
local NIGHT = { 0.039, 0.102, 0.2 } -- #0A1A33
local SAPPHIRE = { 0.075, 0.157, 0.353 } -- #13285A

-- Shapes (design units, y down; a shape is f(u, v) -> signed distance, < 0 inside) -----------

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

local function seg(ax, ay, bx, by, w) return line({ { ax, ay }, { bx, by } }, w) end

-- Points on a circle from angle a0 to a1 (degrees; 0 right, 90 down).
local function arc(cx, cy, r, a0, a1, n)
    local pts = {}
    n = n or 24
    for i = 0, n do
        local a = rad(a0 + (a1 - a0) * i / n)
        pts[#pts + 1] = { cx + r * cos(a), cy + r * sin(a) }
    end
    return pts
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

-- A four-pointed star; `waist` is the inner points' share of r.
local function star4(cx, cy, r, waist)
    local k = r * (waist or 0.3)
    return poly({ { cx, cy - r }, { cx + k, cy - k }, { cx + r, cy }, { cx + k, cy + k },
        { cx, cy + r }, { cx - k, cy + k }, { cx - r, cy }, { cx - k, cy - k } })
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

local function I(a, b) return function(u, v) return max(a(u, v), b(u, v)) end end
local function grow(f, r) return function(u, v) return f(u, v) - r end end
local function rim(f, w) return function(u, v) return abs(f(u, v)) - w / 2 end end
local function move(f, dx, dy) return function(u, v) return f(u - dx, v - dy) end end

-- Turned `deg` degrees clockwise about (cx, cy).
local function rot(f, cx, cy, deg)
    local c, s = cos(rad(deg)), sin(rad(deg))
    return function(u, v)
        local x, y = u - cx, v - cy
        return f(cx + x * c + y * s, cy - x * s + y * c)
    end
end

-- Scaled by k about (cx, cy).
local function scale(f, cx, cy, k)
    return function(u, v) return f(cx + (u - cx) / k, cy + (v - cy) / k) * k end
end

-- Glyphs (32 x 32) -------------------------------------------------------------------------------

local G = {}

G.exclaim = U(grow(poly({ { 12.8, 3.5 }, { 19.2, 3.5 }, { 17.6, 19.5 }, { 14.4, 19.5 } }), 1), circle(16, 26.2, 3.1))

G.question = U(line((function()
    local p = arc(16, 11, 6.2, 195, 400, 28)
    p[#p + 1] = { 16.2, 18 }
    p[#p + 1] = { 16.2, 19.8 }
    return p
end)(), 4.2), circle(16.2, 26.4, 2.9))

G.trophy = U(
    I(circle(16, 5.5, 10), box(16, 9, 8.2, 6.2)),
    line(arc(8.2, 8.5, 4.2, 90, 270), 2.2),
    line(arc(23.8, 8.5, 4.2, -90, 90), 2.2),
    box(16, 18.5, 1.8, 3.5),
    box(16, 22.6, 4, 1.2, 0.6),
    box(16, 26.5, 7, 2.2, 1))

G.boat = U(
    grow(poly({ { 4, 20.5 }, { 28, 20.5 }, { 24, 26.5 }, { 8, 26.5 } }), 0.8),
    seg(16, 3.5, 16, 20, 2),
    poly({ { 18, 4.5 }, { 18, 18.5 }, { 28, 18.5 } }),
    poly({ { 14, 8.5 }, { 14, 18.5 }, { 6.5, 18.5 } }),
    line(arc(16, 31.5, 15, 235, 305, 12), 1.6))

G.bridge = U(
    D(box(16, 19.5, 13.5, 6.5, 1), circle(16, 28, 8.2)),
    box(16, 10.5, 14.5, 1.5, 0.75),
    box(4, 12, 1.2, 2.5), box(10, 12, 1.2, 2.5), box(16, 12, 1.2, 2.5), box(22, 12, 1.2, 2.5), box(28, 12, 1.2, 2.5))

G.cart = U(
    D(grow(poly({ { 7, 8 }, { 27.5, 8 }, { 24.5, 19.5 }, { 9.5, 19.5 } }), 0.6), box(17.3, 11.8, 7.5, 0.8), box(17, 15.6, 6.4, 0.8)),
    line({ { 2.5, 4 }, { 5.5, 4 }, { 7.6, 9 } }, 2.4),
    seg(9.5, 22.5, 25, 22.5, 1.6),
    circle(11.5, 26, 2.8), circle(22.5, 26, 2.8))

-- A cave: a rocky hill with a dark mouth.
G.cave = D(grow(poly({ { 1.5, 28.5 }, { 6, 15 }, { 9.5, 16.5 }, { 15, 5 }, { 19.5, 11.5 }, { 23, 9.5 }, { 30.5, 28.5 } }), 0.6),
    U(box(16, 25.5, 5, 4), circle(16, 21.5, 5)))

G.bag = D(
    U(I(ellipse(16, 21, 11.5, 9), box(16, 21, 12, 8)),
        poly({ { 11, 12.5 }, { 21, 12.5 }, { 18.4, 9 }, { 13.6, 9 } }),
        grow(poly({ { 9.5, 3.5 }, { 13.6, 5.6 }, { 16, 3.8 }, { 18.4, 5.6 }, { 22.5, 3.5 }, { 19.8, 8.5 }, { 12.2, 8.5 } }), 0.4)),
    box(16, 9.4, 6, 0.8),
    line({ { 10, 18 }, { 12.5, 15.5 } }, 1.2))

G.flag = U(
    seg(7.2, 5, 7.2, 29, 2.4),
    circle(7.2, 4, 2),
    poly({ { 8.4, 6 }, { 27.5, 6 }, { 22.5, 11.5 }, { 27.5, 17 }, { 8.4, 17 } }))

G.anvil = grow(poly({ { 3, 9.5 }, { 27, 9.5 }, { 27, 13.5 }, { 21, 15 }, { 19, 17.5 }, { 22, 20.5 }, { 23.5, 24.5 },
    { 8.5, 24.5 }, { 10, 20.5 }, { 13, 17.5 }, { 11.5, 15 }, { 8, 13.5 }, { 3, 11 } }), 0.6)
G.craft = U(move(G.anvil, 0, 3.5), star4(24, 4.5, 4.2), circle(18, 3.5, 1.1), circle(29, 9, 1.1))

G.dungeon = U(
    D(I(U(box(16, 21, 11.5, 8.5), circle(16, 13, 11.5)), box(16, 16, 12, 14)), U(box(16, 22.5, 7.2, 7.5), circle(16, 15, 7.2))),
    box(16, 27.6, 7.2, 1.4), box(17.6, 24.2, 5.6, 1.1), box(19.2, 21, 4, 1))

G.skull = D(
    U(circle(16, 13.5, 10), box(16, 22, 6.2, 5.5, 2)),
    circle(12, 14, 3), circle(20, 14, 3),
    poly({ { 16, 17.6 }, { 14.2, 21 }, { 17.8, 21 } }),
    box(13.6, 26, 0.7, 2.6), box(18.4, 26, 0.7, 2.6))
G.elite = U(scale(move(G.skull, 0, 2), 16, 18, 0.88),
    grow(poly({ { 8.5, 11 }, { 3, 2.5 }, { 12.5, 7.5 } }), 0.4),
    grow(poly({ { 23.5, 11 }, { 29, 2.5 }, { 19.5, 7.5 } }), 0.4))

G.compass = D(U(star4(16, 16, 14.5, 0.24), rot(star4(16, 16, 8.5, 0.32), 16, 16, 45), rim(circle(16, 16, 10), 1.6)), circle(16, 16, 2))

-- Points on a quadratic curve from a to c bending toward b.
local function curve(a, b, c, n)
    local pts = {}
    n = n or 12
    for i = 0, n do
        local t = i / n
        local p, q, r = (1 - t) ^ 2, 2 * (1 - t) * t, t ^ 2
        pts[#pts + 1] = { p * a[1] + q * b[1] + r * c[1], p * a[2] + q * b[2] + r * c[2] }
    end
    return pts
end

-- Flight: a winged boot facing right, the wing at the back of the shaft.
-- A stroke along a polyline whose width runs from w0 at the first point to w1 at the last.
local function taper(pts, w0, w1)
    local lens, total = {}, 0
    for i = 1, #pts - 1 do
        local a, b = pts[i], pts[i + 1]
        lens[i] = sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
        total = total + lens[i]
    end
    return function(u, v)
        local best, acc = 1e9, 0
        for i = 1, #pts - 1 do
            local a, b = pts[i], pts[i + 1]
            local dx, dy = b[1] - a[1], b[2] - a[2]
            local t = max(0, min(1, ((u - a[1]) * dx + (v - a[2]) * dy) / max(1e-9, dx * dx + dy * dy)))
            local d = sqrt((u - a[1] - t * dx) ^ 2 + (v - a[2] - t * dy) ^ 2)
            local k = (acc + t * lens[i]) / total
            best = min(best, d - (w0 + (w1 - w0) * k) / 2)
            acc = acc + lens[i]
        end
        return best
    end
end

-- The boot: a folded cuff, a heel, a toe that curls up.
local bootShape = U(
    grow(poly({ { 15, 12 }, { 22.5, 12 }, { 22.5, 18.5 }, { 25.5, 20.5 }, { 28.5, 21.5 }, { 30.5, 20.5 }, { 31.2, 22.5 },
        { 30, 26 }, { 27.5, 28.2 }, { 14, 28.2 }, { 13.6, 22 } }), 0.6),
    grow(poly({ { 13.6, 7.5 }, { 23.6, 7.5 }, { 24.2, 12 }, { 13, 12 } }), 0.7))
local boot = D(bootShape, box(18.6, 12.8, 6, 0.55), box(19.4, 26.8, 0.55, 1.6))
-- The wing: four layered feathers sweeping back from the ankle and curling up at their tips, each lower
-- one shorter and set apart from the one above it, their roots under a rounded shoulder.
local feathers = {
    taper(curve({ 14, 10 }, { 6.5, 9.5 }, { 3, 1.8 }, 16), 4.4, 2.6),
    taper(curve({ 14, 13.2 }, { 6.5, 13.5 }, { 1.8, 7.6 }, 16), 4.2, 2.4),
    taper(curve({ 14, 16.4 }, { 7.5, 17 }, { 2.4, 13.4 }, 16), 3.9, 2.2),
    taper(curve({ 14, 19.4 }, { 9, 20.2 }, { 5, 18.6 }, 16), 3.6, 2),
}
local layered = { feathers[1] }
for k = 2, #feathers do layered[k] = D(feathers[k], grow(feathers[k - 1], 0.9)) end
local shoulder = ellipse(14.2, 13.5, 3.2, 6.5)
local wing = U(D(U(unpack(layered)), grow(shoulder, 0.9)), shoulder)
G.wingboot = U(D(wing, grow(bootShape, 1.3)), boot)
G.getfp = U(move(scale(G.wingboot, 16, 30, 0.86), 0, 0.5), box(26.5, 5.5, 4.6, 1.3, 0.6), box(26.5, 5.5, 1.3, 4.6, 0.6))

G.gate = U(
    D(U(box(16, 18.5, 13, 10.5), box(5.5, 5.5, 2.5, 2.5), box(16, 5.5, 2.5, 2.5), box(26.5, 5.5, 2.5, 2.5)),
        U(box(16, 25, 6.5, 5), circle(16, 19.5, 6.5))),
    I(U(box(13, 23, 0.9, 9), box(16, 23, 0.9, 9), box(19, 23, 0.9, 9), box(16, 21, 7, 0.8)), U(box(16, 25, 6.5, 5), circle(16, 19.5, 6.5))))

local function brandPin(cx, cy, r, tipY)
    return U(circle(cx, cy, r), poly({ { cx - r * 0.86, cy + r * 0.5 }, { cx + r * 0.86, cy + r * 0.5 }, { cx, tipY } }))
end
G.goto = U(D(brandPin(20, 10.5, 7.2, 27), circle(20, 10.5, 2.8)), circle(5, 25.5, 2.3), circle(11.2, 28.5, 2))
G.pinSolid = brandPin(16, 11, 8.4, 30)
G.pin = D(G.pinSolid, circle(16, 11, 3.2))
G.pinRing = U(D(G.pinSolid, circle(16, 11, 4.6)), circle(16, 11, 2.2))
G.pinStar = D(G.pinSolid, star4(16, 11, 5.2, 0.34))

G.hearth = D(rot(ellipse(16, 16.5, 10.5, 13), 16, 16.5, 20),
    poly({ { 16, 9.5 }, { 22, 15 }, { 20.2, 15 }, { 20.2, 22.5 }, { 11.8, 22.5 }, { 11.8, 15 }, { 10, 15 } }))

G.interact = U(
    grow(poly({ { 12.5, 10.5 }, { 12.5, 28.5 }, { 16.6, 24.4 }, { 19.6, 30.2 }, { 22.4, 28.8 }, { 19.6, 23 }, { 25.4, 23 } }), 0.5),
    seg(12.5, 6.5, 12.5, 2.5, 2.2), seg(9.2, 7.8, 6.2, 4.8, 2.2), seg(8.2, 11, 4.2, 11, 2.2), seg(15.8, 7.8, 18.8, 4.8, 2.2))

local swordUp = U(
    D(poly({ { 16, 1.5 }, { 18.8, 5 }, { 18.8, 20 }, { 13.2, 20 }, { 13.2, 5 } }), box(16, 12, 0.6, 6.5)),
    box(16, 21.4, 7, 1.4, 0.7), box(16, 25.4, 1.5, 3), circle(16, 29.6, 2.1))
G.sword = rot(scale(swordUp, 16, 16, 1.02), 16, 16, 45)

G.scroll = D(U(box(16, 16, 10.5, 8), box(4.8, 16, 2.8, 10.5, 2.8), box(27.2, 16, 2.8, 10.5, 2.8)),
    box(16, 12.6, 6, 0.8), box(16, 16, 6, 0.8), box(15, 19.4, 5, 0.8))

G.level = U(grow(poly({ { 16, 3 }, { 27, 14 }, { 20, 14 }, { 20, 23.5 }, { 12, 23.5 }, { 12, 14 }, { 5, 14 } }), 0.5), box(16, 28, 10.5, 1.7, 0.85))

local liftArrows = U(
    grow(poly({ { 10, 3.5 }, { 15.5, 10 }, { 12.2, 10 }, { 12.2, 22 }, { 7.8, 22 }, { 7.8, 10 }, { 4.5, 10 } }), 0.4),
    grow(poly({ { 22, 28.5 }, { 27.5, 22 }, { 24.2, 22 }, { 24.2, 10 }, { 19.8, 10 }, { 19.8, 22 }, { 16.5, 22 } }), 0.4))
G.lift = liftArrows
G.elevator = D(box(16, 16, 12, 14.5, 3.5), scale(liftArrows, 16, 16, 0.72))

G.horseshoe = D(
    U(line(arc(16, 15, 9.5, 155, 385, 30), 5.6),
        box(16 + 9.5 * cos(rad(155)), 15 + 9.5 * sin(rad(155)) + 1.2, 3.4, 1.6, 0.8),
        box(16 + 9.5 * cos(rad(385)), 15 + 9.5 * sin(rad(385)) + 1.2, 3.4, 1.6, 0.8)),
    circle(16 + 9.5 * cos(rad(200)), 15 + 9.5 * sin(rad(200)), 0.95),
    circle(16 + 9.5 * cos(rad(240)), 15 + 9.5 * sin(rad(240)), 0.95),
    circle(16 + 9.5 * cos(rad(300)), 15 + 9.5 * sin(rad(300)), 0.95),
    circle(16 + 9.5 * cos(rad(340)), 15 + 9.5 * sin(rad(340)), 0.95))

G.note = U(
    D(grow(poly({ { 7.5, 3.5 }, { 19.5, 3.5 }, { 25.5, 9.5 }, { 25.5, 28.5 }, { 7.5, 28.5 } }), 0.6),
        poly({ { 18.5, 2 }, { 18.5, 10.5 }, { 27, 10.5 } }),
        box(16, 15, 5.5, 0.9), box(16, 19, 5.5, 0.9), box(14.5, 23, 4, 0.9)),
    grow(poly({ { 20.3, 4.5 }, { 20.3, 8.7 }, { 24.5, 8.7 } }), 0.3))

G.pass = D(grow(poly({ { 2, 27.5 }, { 11, 9 }, { 16, 17 }, { 21.5, 6.5 }, { 30, 27.5 } }), 0.5),
    line({ { 12.5, 29 }, { 15, 25 }, { 17.2, 22.2 }, { 16.2, 19.5 } }, 1.7))

local heart = U(circle(13.4, 12.8, 3.1), circle(18.6, 12.8, 3.1), poly({ { 10.5, 14.1 }, { 21.5, 14.1 }, { 16, 20.2 } }))
G.rep = D(grow(poly({ { 6.5, 4 }, { 25.5, 4 }, { 25.5, 14 }, { 23.5, 21 }, { 16, 28.5 }, { 8.5, 21 }, { 6.5, 14 } }), 1), heart)

local wrench = U(seg(6.5, 25.5, 19.5, 12.5, 3.6),
    D(circle(22.2, 9.8, 5.3), rot(box(22.2, 4.6, 1.9, 4.2), 22.2, 9.8, 45)))
local hammer = U(seg(25.5, 25.5, 12.5, 12.5, 3.2), rot(box(10.6, 10.6, 6.4, 2.8, 0.8), 10.6, 10.6, -45))
G.repair = U(wrench, hammer)

-- Sell: a price tag.
G.sell = D(rot(grow(poly({ { 16, 2.5 }, { 22, 8.5 }, { 22, 29 }, { 10, 29 }, { 10, 8.5 } }), 0.8), 16, 16, 40),
    rot(circle(16, 9.5, 2.2), 16, 16, 40), rot(box(16, 18.5, 3, 0.8), 16, 16, 40), rot(box(16, 22, 3, 0.8), 16, 16, 40))

G.house = D(U(poly({ { 16, 3 }, { 29.5, 15.5 }, { 26, 15.5 }, { 26, 28.5 }, { 6, 28.5 }, { 6, 15.5 }, { 2.5, 15.5 } }), box(23, 7.5, 1.9, 4.5)),
    U(box(16, 25, 3.2, 3.6), circle(16, 21.4, 3.2)))
G.tankard = D(U(box(13.5, 19, 8, 10, 2), line(arc(21.5, 18.5, 5.2, -80, 80), 3),
    circle(8.5, 8.5, 3.6), circle(13.5, 7.2, 4.2), circle(18.5, 8.5, 3.6)), box(10.8, 20, 0.9, 6), box(16.2, 20, 0.9, 6))

G.skill = U(box(7, 23, 3, 6, 1.5), box(16, 18.5, 3, 10.5, 1.5), box(25, 16, 3, 13, 1.5), star4(7.5, 7.5, 5, 0.28))

G.talk = D(U(box(17, 13, 12.5, 9.5, 4), poly({ { 8, 19 }, { 5.5, 28.5 }, { 15.5, 21.5 } })), box(17, 10.5, 7, 1.1), box(15, 15.5, 5, 1.1))

G.book = U(D(box(17.5, 16, 10, 13.5, 1.5), star4(17.5, 14.5, 5.5, 0.32), box(17.5, 27, 7.5, 0.8)), box(5.6, 16, 2, 13.5, 1))

G.chest = U(
    D(U(I(ellipse(16, 13.5, 13.5, 8.5), box(16, 9.5, 13.5, 4)), box(16, 21.5, 13.5, 7, 1.5)),
        box(16, 15.5, 4.2, 4.8, 1.5), box(16, 13.9, 14, 0.6), box(6.5, 21.5, 0.8, 7), box(25.5, 21.5, 0.8, 7)),
    D(box(16, 15.5, 3, 3.6, 1), circle(16, 15, 1.1)))

G.potion = D(U(circle(16, 20.5, 9.5), box(16, 8.5, 3.2, 4), box(16, 6, 4.6, 1, 0.5), box(16, 3.4, 3.8, 1.8, 0.8)),
    box(16, 16, 9.5, 0.7), circle(12.8, 21.5, 1.9), circle(19.2, 23.8, 1.3))

local function coinEdge(y)
    return I(rim(ellipse(16, y, 11, 4.5), 1.1), box(16, y + 3, 12, 3))
end
G.coins = D(U(ellipse(16, 8, 11, 4.5), box(16, 16, 11, 8), ellipse(16, 24, 11, 4.5)),
    rim(ellipse(16, 8, 6.5, 2.2), 1.1), coinEdge(12.3), coinEdge(16.6), coinEdge(20.9))

G.ankh = U(rim(ellipse(16, 8.5, 4.8, 6), 3.2), box(16, 16.8, 10, 1.8, 0.9), poly({ { 14, 16 }, { 18, 16 }, { 19.6, 29.5 }, { 12.4, 29.5 } }))

G.gavel = U(seg(14, 14, 27, 27, 3), rot(U(box(11.5, 11.5, 3.6, 7, 1), box(11.5, 11.5, 4.6, 1.2, 0.6)), 11.5, 11.5, 45), box(9, 28, 7, 1.8, 0.9))

G.vault = U(D(box(16, 15, 13, 12, 2.5), rim(circle(13.5, 15, 6), 2), box(24.5, 15, 0.9, 4.5)), circle(13.5, 15, 1.6),
    box(8, 28.6, 2.2, 1.6, 0.6), box(24, 28.6, 2.2, 1.6, 0.6))

G.ghost = D(U(circle(16, 13, 10), box(16, 20, 10, 7.5)),
    circle(11, 28.5, 2.7), circle(21, 28.5, 2.7), ellipse(12.5, 13, 1.8, 2.6), ellipse(19.5, 13, 1.8, 2.6))

-- Mail: an envelope closed with a wax seal.
G.mailbox = U(D(box(16, 16, 13.5, 9.5, 1.5), line({ { 3.5, 8 }, { 16, 17.5 }, { 28.5, 8 } }, 1.6), circle(16, 17.5, 4.6)), circle(16, 17.5, 3.2))

G.portal = U(rim(ellipse(16, 16, 9.5, 13.5), 3.2), rim(ellipse(16, 16, 4.8, 7.6), 2), star4(16, 16, 3.6))

G.castle = D(U(box(6, 17.5, 4, 11.5), box(26, 17.5, 4, 11.5), box(16, 20.5, 7, 8.5),
        box(3.6, 4.6, 1.6, 2), box(8.4, 4.6, 1.6, 2), box(23.6, 4.6, 1.6, 2), box(28.4, 4.6, 1.6, 2),
        box(12, 10.4, 1.6, 1.6), box(20, 10.4, 1.6, 1.6),
        seg(16, 3, 16, 12, 1.6), poly({ { 16.8, 2.5 }, { 22.5, 4.8 }, { 16.8, 7 } })),
    U(box(16, 26, 3.2, 3.2), circle(16, 22.8, 3.2)), box(6, 15, 1, 2.2), box(26, 15, 1, 2.2))

G.gem = D(poly({ { 9, 5 }, { 23, 5 }, { 29.5, 12 }, { 16, 29.5 }, { 2.5, 12 } }),
    seg(2, 12, 30, 12, 1.2), seg(9.5, 5, 12.4, 12, 1.1), seg(22.5, 5, 19.6, 12, 1.1), seg(12.4, 12, 16, 27, 1.1), seg(19.6, 12, 16, 27, 1.1))

G.pickaxe = rot(U(line(arc(16, 21, 13, 218, 322, 20), 3.8), seg(16, 8, 16, 29.5, 3)), 16, 16, 30)

local shieldShape = grow(poly({ { 10.5, 9.5 }, { 21.5, 9.5 }, { 21.5, 16 }, { 20.5, 19.5 }, { 16, 24 }, { 11.5, 19.5 }, { 10.5, 16 } }), 0.8)
local shield = D(shieldShape, box(16, 16.5, 0.8, 5), box(16, 14, 4, 0.8))
local weaponSword = rot(swordUp, 16, 16, 45)
G.swordShield = U(D(weaponSword, grow(shieldShape, 1.4)), shield)

G.tram = U(D(box(16, 14, 12.5, 8, 3), box(10.5, 12, 3.6, 3, 1), box(21.5, 12, 3.6, 3, 1), box(16, 19, 9, 0.7)),
    circle(9.5, 25, 3), circle(22.5, 25, 3), box(16, 29.6, 14.5, 1),
    seg(16, 6, 12.8, 2.5, 1.6), seg(12.8, 2.5, 20, 2.5, 1.6))

G.tunic = D(grow(poly({ { 10, 4 }, { 13.5, 4 }, { 16, 7.5 }, { 18.5, 4 }, { 22, 4 }, { 29, 10.5 }, { 26, 15.5 }, { 23, 13 }, { 23, 28.5 },
    { 9, 28.5 }, { 9, 13 }, { 6, 15.5 }, { 3, 10.5 } }), 0.5), box(16, 20, 7.5, 0.9))

G.zeppelin = U(D(ellipse(17, 12, 13, 7.5), box(18, 12, 0.7, 8), box(10, 12, 0.7, 8)),
    grow(poly({ { 5.5, 12 }, { 1.5, 5 }, { 8, 8.5 } }), 0.3), grow(poly({ { 5.5, 12 }, { 1.5, 19 }, { 8, 15.5 } }), 0.3),
    box(17.5, 24.5, 5, 2.2, 1), seg(13.5, 19, 14.5, 22.5, 1.2), seg(21.5, 19, 20.5, 22.5, 1.2))

-- The ∞ for Forever's new quests (32 x 16, gold).
G.infinity = line((function()
    local p = {}
    for i = 0, 64 do
        local t = 2 * pi * i / 64
        local d = 1 + sin(t) ^ 2
        p[#p + 1] = { 16 + 13 * cos(t) / d, 8 + 13 * sin(t) * cos(t) / d }
    end
    return p
end)(), 3)

-- Which glyph each texture takes ---------------------------------------------------------------

local UI_ICONS = {
    accept = "exclaim", achieve = "trophy", boat = "boat", bridge = "bridge", buy = "cart", cave = "cave",
    collect = "bag", complete = "flag", craft = "craft", dungeon = "dungeon", elite = "elite", explore = "compass",
    fly = "wingboot", gate = "gate", getfp = "getfp", ["goto"] = "goto", hearth = "hearth", interact = "interact",
    kill = "sword", learn = "scroll", level = "level", lift = "lift", mount = "horseshoe", note = "note",
    pass = "pass", rep = "rep", repair = "repair", sell = "sell", sethome = "house", skill = "skill", talk = "talk",
    train = "book", treasure = "chest", turnin = "question", use = "potion", vendor = "coins",
}

local MAP_ICONS = {
    ankh = "ankh", auction = "gavel", bank = "vault", battlemaster = "flag", boat = "boat", bridge = "bridge",
    cave = "cave", corpse = "ghost", dungeon = "dungeon", elevator = "elevator", explore = "compass",
    flightmaster = "wingboot", inn = "tankard", kill = "sword", loot = "bag", mailbox = "mailbox", pass = "pass",
    ["pin-small"] = "pinSolid", pin = "pin", portal = "portal", ["quest-available"] = "exclaim",
    ["quest-turnin"] = "question", raid = "castle", rare = "gem", repair = "repair", stable = "horseshoe",
    stop = "pinRing", target = "pinStar", ["trainer-class"] = "book", ["trainer-profession"] = "pickaxe",
    ["trainer-weapon"] = "swordShield", tram = "tram", transmog = "tunic", treasure = "chest", use = "potion",
    vendor = "coins", zeppelin = "zeppelin",
}

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

-- Coverage of `f` <= `edge` over pixel (x, y), design unit = `k` pixels, origin at `off` pixels.
local function cover(f, x, y, k, off, edge, dv)
    local n = 0
    for sy = 0, SS - 1 do
        for sx = 0, SS - 1 do
            local u = (x + (sx + 0.5) / SS - off) / k
            local v = (y + (sy + 0.5) / SS - off) / k - (dv or 0)
            if f(u, v) <= edge then n = n + 1 end
        end
    end
    return n / (SS * SS)
end

local function writeTGA(cv, rel)
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
    local f = assert(io.open(OUT .. rel .. ".tga", "wb"))
    f:write(table.concat(out))
    f:close()
end

-- A step icon: the glyph in flat colour, 1 design unit a pixel.
local function flat(f, w, h, c)
    local cv = canvas(w, h)
    for y = 0, h - 1 do
        for x = 0, w - 1 do blend(cv, x, y, c, cover(f, x, y, 1, 0, 0)) end
    end
    return cv
end

-- A map mark (64 x 64): a soft shadow, a night rim and the glyph in white fading to pearl.
local MAP_K, MAP_OFF = 1.6, 6.4
local RIM, SHADOW_DROP = 1.4, 0.9 -- design units
local function marked(f)
    local cv = canvas(64, 64)
    for y = 0, 63 do
        for x = 0, 63 do
            local s = cover(f, x, y, MAP_K, MAP_OFF, RIM + 0.6, SHADOW_DROP)
            if s > 0 then blend(cv, x, y, { 0, 0, 0 }, s * 0.35) end
            local r = cover(f, x, y, MAP_K, MAP_OFF, RIM)
            if r > 0 then blend(cv, x, y, NIGHT, r * 0.95) end
            local c = cover(f, x, y, MAP_K, MAP_OFF, 0)
            if c > 0 then
                local t = max(0, min(1, ((y + 0.5 - MAP_OFF) / MAP_K - 3) / 26))
                local col = { WHITE[1] + (PEARL[1] - WHITE[1]) * t * 1.6, WHITE[2] + (PEARL[2] - WHITE[2]) * t * 1.6, WHITE[3] + (PEARL[3] - WHITE[3]) * t * 1.6 }
                blend(cv, x, y, col, c)
            end
        end
    end
    return cv
end

-- The medallion under every map mark: a sapphire disc deepening to night, a gold rim.
local function medallion()
    local cv = canvas(64, 64)
    for y = 0, 63 do
        for x = 0, 63 do
            local d = sqrt((x + 0.5 - 32) ^ 2 + (y + 0.5 - 32) ^ 2)
            local body = max(0, min(1, 29.5 - d))
            if body > 0 then
                local t = min(1, d / 29)
                local col = { SAPPHIRE[1] + (NIGHT[1] - SAPPHIRE[1]) * t, SAPPHIRE[2] + (NIGHT[2] - SAPPHIRE[2]) * t, SAPPHIRE[3] + (NIGHT[3] - SAPPHIRE[3]) * t }
                blend(cv, x, y, col, body)
            end
            local ring = max(0, min(1, 1.5 - abs(d - 28.2)))
            if ring > 0 then blend(cv, x, y, GOLD, ring) end
            local inner = max(0, min(1, 0.6 - abs(d - 25.2)))
            if inner > 0 then blend(cv, x, y, GOLD, inner * 0.35) end
        end
    end
    return cv
end

-- The point marker on the map and minimap (Media/Nav/pin, 64 x 64, white: tinted, laid over the coloured
-- disc of Media/Nav/pin-fill, radius 21): a ring round the disc and a compass needle, north solid, south
-- faint, east and west ticks.
local function navPin()
    local cv = canvas(64, 64)
    local ring = rim(circle(32, 32, 23.6), 5.2)
    local north = grow(poly({ { 32, 13.5 }, { 37.2, 32 }, { 26.8, 32 } }), 0.4)
    local south = grow(poly({ { 26.8, 32 }, { 37.2, 32 }, { 32, 50.5 } }), 0.4)
    local ticks = U(box(16.4, 32, 2.6, 1.2, 0.6), box(47.6, 32, 2.6, 1.2, 0.6))
    local hub = circle(32, 32, 2.4)
    for y = 0, 63 do
        for x = 0, 63 do
            blend(cv, x, y, WHITE, cover(ring, x, y, 1, 0, 0))
            blend(cv, x, y, WHITE, cover(ticks, x, y, 1, 0, 0) * 0.8)
            blend(cv, x, y, WHITE, cover(D(south, hub), x, y, 1, 0, 0) * 0.5)
            blend(cv, x, y, WHITE, cover(D(north, hub), x, y, 1, 0, 0))
        end
    end
    return cv
end

local function sorted(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

local count = 0
for _, name in ipairs(sorted(UI_ICONS)) do
    writeTGA(flat(assert(G[UI_ICONS[name]], UI_ICONS[name]), 32, 32, WHITE), "UI/icon-" .. name)
    count = count + 1
end
writeTGA(flat(G.infinity, 32, 16, GOLD), "UI/icon-forever")
count = count + 1
for _, name in ipairs(sorted(MAP_ICONS)) do
    writeTGA(marked(assert(G[MAP_ICONS[name]], MAP_ICONS[name])), "Map/icon-" .. name)
    count = count + 1
end
writeTGA(medallion(), "Map/medallion-polestar")
writeTGA(navPin(), "Nav/pin")
count = count + 2
print(string.format("%d icons", count))
