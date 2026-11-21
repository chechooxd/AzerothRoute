-- AzerothRoute: turns Icy Veins' WoW Forever leveling talent builds (tools/fork/icyveins/leveling.txt)
-- and talent trees (tools/fork/icyveins/trees.txt) into AzerothRoute/Talents/IcyVeins.lua, the
-- talent plans AzerothRoute shows in place of Polestar's.
--
-- Every talent of a class's current tree is matched to the addon's talent snapshot (Talents/Builds.lua)
-- by spell ID, else by name: a match whose rank count or name changed since the snapshot is corrected
-- (so the game's tree still matches it), a talent the snapshot lacks becomes a node of its own.
-- Called by tools/fork_polestar.lua after the patches: dofile("tools/fork/icyveins.lua").run(outDir, repoRoot).
-- Returns the number of plans, or nil and the errors when a plan breaks a rule: one point a level
-- from 10 to 60, ranks in order and within the talent's maximum, every talent in the class's tree.

local CLASS = {
    druid = "DRUID", hunter = "HUNTER", mage = "MAGE", paladin = "PALADIN", priest = "PRIEST",
    rogue = "ROGUE", shaman = "SHAMAN", warlock = "WARLOCK", warrior = "WARRIOR",
}
local ORDER = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }
local GUIDE = "https://www.icy-veins.com/wow-forever/%s-leveling"
local FIRST_LEVEL, LAST_LEVEL = 10, 60

local function read(p)
    local f = assert(io.open(p, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

-- leveling.txt -> { { slug, class, updated, talents = { [i] = { name, spell } }, seq = { i... } } }
local function parsePlans(text)
    local specs, cur = {}, nil
    for line in text:gmatch("[^\r\n]+") do
        local slug, updated = line:match("^SPEC (%S+) | (.+)$")
        if slug then
            local cls = CLASS[slug:match("%-(%a+)$") or ""]
            assert(cls, "unknown class in " .. slug)
            cur = { slug = slug, class = cls, updated = updated, talents = {}, seq = {} }
            specs[#specs + 1] = cur
        end
        local i, name, spell = line:match("^T (%d+) [^|]+|([^|]+)|(%d+)$")
        if i then cur.talents[tonumber(i)] = { name = name, spell = tonumber(spell) } end
        local seq = line:match("^S ([%d%.]+)$")
        if seq then for n in seq:gmatch("%d+") do cur.seq[#cur.seq + 1] = tonumber(n) end end
    end
    return specs
end

-- trees.txt -> [class] = { [spell] = { spell, tree, max, row, col, name } }
local function parseTrees(text)
    local out, cls = {}, nil
    for line in text:gmatch("[^\r\n]+") do
        local c = line:match("^CLASS (%a+)$")
        if c then cls = CLASS[c]; out[cls] = {} end
        local spell, tree, max, row, col, name = line:match("^N|(%d+)|(%d)|(%d+)|(%d+)|(%d+)|(.+)$")
        if spell then
            spell = tonumber(spell)
            out[cls][spell] = { spell = spell, tree = tonumber(tree), max = tonumber(max), row = tonumber(row), col = tonumber(col), name = name }
        end
    end
    return out
end

-- Builds.lua -> [class] = { nodes[id], bySpell, byName, keys[spec] = plan key }
local function parseSnapshot(text)
    local out, cls = {}, nil
    for line in text:gmatch("[^\r\n]+") do
        local c = line:match('^%s*class = "(%u+)"')
        if c then cls = c; out[c] = { nodes = {}, keys = {}, bySpell = {}, byName = {} } end
        local id, max, spell, spec, name = line:match('^%s*%[(%d+)%] = { %d+, (%d+), (%d+), (%d+), %d+, %d+, "([^"]+)" },')
        if id and cls then
            local n = { id = tonumber(id), max = tonumber(max), spell = tonumber(spell), spec = tonumber(spec), name = name }
            local t = out[cls]
            t.nodes[n.id] = n
            t.bySpell[n.spell] = t.bySpell[n.spell] == nil and n or false
            t.byName[n.name] = t.byName[n.name] == nil and n or false
        end
        local key, spec2 = line:match('^%s*key = "(%a+)", spec = (%d+),')
        if key and cls then out[cls].keys[tonumber(spec2)] = key end
    end
    return out
end

local function q(s) return string.format("%q", s) end

-- The plans as IcyVeins.lua's text from the three files' texts: text, plan count; or nil, errors.
local function build(plansText, treesText, buildsText)
    local plans = parsePlans(plansText)
    local trees = parseTrees(treesText)
    local snap = parseSnapshot(buildsText)
    local errors = {}
    local function fail(fmt, ...) errors[#errors + 1] = string.format(fmt, ...) end

    -- Each class's current talents on snapshot nodes: [class] = { node[spell], fixes[id], extras[id] }
    local perClass = {}
    for _, cls in ipairs(ORDER) do
        local t, tree = snap[cls], trees[cls]
        local pc = { node = {}, fixes = {}, extras = {}, builds = {}, used = {} }
        perClass[cls] = pc
        for spell, tal in pairs(tree or {}) do
            local n = t.bySpell[spell] or t.byName[tal.name]
            if n then
                if n.max ~= tal.max or n.name ~= tal.name or n.spell ~= spell then
                    pc.fixes[n.id] = { max = tal.max, spell = spell, name = tal.name }
                end
                pc.node[spell] = { id = n.id, max = tal.max, spec = n.spec, name = tal.name }
            else
                local id = -spell
                pc.extras[id] = { max = tal.max, spell = spell, spec = tal.tree, row = tal.row, col = tal.col, name = tal.name }
                pc.node[spell] = { id = id, max = tal.max, spec = tal.tree, name = tal.name }
            end
        end
    end

    for _, s in ipairs(plans) do
        local pc = perClass[s.class]
        if #s.seq ~= LAST_LEVEL - FIRST_LEVEL + 1 then
            fail("%s: %d points, not one a level from %d to %d", s.slug, #s.seq, FIRST_LEVEL, LAST_LEVEL)
        end
        local ranks, per, picks = {}, { 0, 0, 0 }, {}
        for _, i in ipairs(s.seq) do
            local tal = s.talents[i]
            local n = tal and pc.node[tal.spell]
            if not n then
                fail("%s: %s (%s) is not in the class's talent tree", s.slug, tal and tal.name or "?", tal and tal.spell or "?")
            else
                local r = (ranks[n.id] or 0) + 1
                if r > n.max then fail("%s: %s rank %d of %d", s.slug, n.name, r, n.max) end
                ranks[n.id] = r
                per[n.spec] = per[n.spec] + 1
                picks[#picks + 1] = { n.id, r }
            end
        end
        local main = 1
        for k = 2, 3 do if per[k] > per[main] then main = k end end
        local key = snap[s.class].keys[main]
        if not key then fail("%s: no plan key for spec %d", s.slug, main) end
        if pc.used[main] then fail("%s: a second plan for spec %d", s.slug, main) end
        pc.used[main] = true
        pc.builds[#pc.builds + 1] = {
            key = key, spec = main, split = table.concat(per, "/"), picks = picks,
            link = string.format(GUIDE, s.slug), updated = s.updated,
        }
    end
    if #errors > 0 then return nil, errors end

    local out = {
        "-- Generated by tools/fork/icyveins.lua from tools/fork/icyveins/leveling.txt and trees.txt: Icy Veins'",
        "-- WoW Forever leveling talent builds (https://www.icy-veins.com/wow-forever/leveling-guides), one",
        "-- point a level from 10 to 60. Do not edit: change the source files and regenerate.",
        "",
        "local ADDON, ns = ...",
        "local T = ns.Talents",
        "if not (T and T.UseSource) then return end",
        "",
    }
    local function sortedIds(t)
        local ids = {}
        for id in pairs(t) do ids[#ids + 1] = id end
        table.sort(ids)
        return ids
    end
    local count = 0
    for _, cls in ipairs(ORDER) do
        local pc = perClass[cls]
        if #pc.builds > 0 then
            table.sort(pc.builds, function(a, b) return a.spec < b.spec end)
            out[#out + 1] = "T.UseSource({"
            out[#out + 1] = string.format("\tclass = %q,", cls)
            out[#out + 1] = "\t-- snapshot talents whose ranks or name changed since: id = { max ranks, spell, name }"
            out[#out + 1] = "\tfixes = {"
            for _, id in ipairs(sortedIds(pc.fixes)) do
                local f = pc.fixes[id]
                out[#out + 1] = string.format("\t\t[%d] = { %d, %d, %s },", id, f.max, f.spell, q(f.name))
            end
            out[#out + 1] = "\t},"
            out[#out + 1] = "\t-- talents the snapshot lacks: id = { max ranks, spell, spec column, row, column, name }"
            out[#out + 1] = "\tnodes = {"
            for _, id in ipairs(sortedIds(pc.extras)) do
                local n = pc.extras[id]
                out[#out + 1] = string.format("\t\t[%d] = { %d, %d, %d, %d, %d, %s },", id, n.max, n.spell, n.spec, n.row, n.col, q(n.name))
            end
            out[#out + 1] = "\t},"
            out[#out + 1] = "\tbuilds = {"
            for _, b in ipairs(pc.builds) do
                out[#out + 1] = string.format("\t\t{ key = %q, spec = %d, split = %q, link = %q, updated = %q,", b.key, b.spec, b.split, b.link, b.updated)
                out[#out + 1] = "\t\t\t-- in order, one point a level from 10: { node, rank }"
                out[#out + 1] = "\t\t\tpicks = {"
                local row = {}
                for i, p in ipairs(b.picks) do
                    row[#row + 1] = string.format("{ %d, %d }", p[1], p[2])
                    if #row == 6 or i == #b.picks then
                        out[#out + 1] = "\t\t\t\t" .. table.concat(row, ", ") .. ","
                        row = {}
                    end
                end
                out[#out + 1] = "\t\t\t},"
                out[#out + 1] = "\t\t},"
                count = count + 1
            end
            out[#out + 1] = "\t},"
            out[#out + 1] = "})"
            out[#out + 1] = ""
        end
    end
    return table.concat(out, "\n"), count
end

-- Writes <outDir>/AzerothRoute/Talents/IcyVeins.lua: plan count, or nil, errors.
local function run(outDir, repo)
    repo = repo or "."
    local root = outDir .. "/AzerothRoute/Talents/"
    local text, count = build(read(repo .. "/tools/fork/icyveins/leveling.txt"),
        read(repo .. "/tools/fork/icyveins/trees.txt"), read(root .. "Builds.lua"))
    if not text then return nil, count end
    local f = assert(io.open(root .. "IcyVeins.lua", "wb"))
    f:write(text)
    f:close()
    return count
end

return { build = build, run = run }
