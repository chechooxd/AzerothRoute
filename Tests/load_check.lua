-- AzerothRoute 2 headless check:
--   luajit Tests/load_check.lua
-- 1. every Lua file under addon/ compiles;
-- 2. every file a .toc or .xml names exists;
-- 3. the main addon's files load in .toc order with Tests/mock_wow.lua and its start-up events
--    (ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD and the timers they start) run;
-- 4. the slash commands and key bindings carry AzerothRoute's names.
-- Exit code 0 when every check passes.

package.path = "./?.lua;" .. package.path
local ROOT = "addon"
local failures = 0
local function fail(msg)
    failures = failures + 1
    print("FAIL " .. msg)
end

local function read(p)
    local f = io.open(p, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

-- 1. compile
local count = 0
local h = io.popen('find ' .. ROOT .. ' -name "*.lua"')
for p in h:lines() do
    count = count + 1
    local ok, err = loadfile(p)
    if not ok then fail("compile " .. err) end
end
h:close()
print(string.format("compile: %d Lua files", count))

-- 2. references, and the load order of the main addon
local function refsOf(path)
    local s = read(path) or ""
    local dir = path:match("^(.*)/[^/]+$")
    local out = {}
    if path:match("%.toc$") then
        for line in s:gmatch("[^\r\n]+") do
            if not line:match("^#") and line:match("%S") then out[#out + 1] = dir .. "/" .. line:gsub("%s+$", ""):gsub("\\", "/") end
        end
    else
        for tag, f in s:gmatch('<(%a+) file="([^"]+)"') do
            if tag == "Script" or tag == "Include" then out[#out + 1] = dir .. "/" .. f:gsub("\\", "/") end
        end
    end
    return out
end

local missing = 0
local h2 = io.popen('find ' .. ROOT .. ' -name "*.toc" -o -name "*.xml"')
for p in h2:lines() do
    for _, r in ipairs(refsOf(p)) do
        if not read(r) then missing = missing + 1 fail("missing " .. r .. " (named in " .. p .. ")") end
    end
end
h2:close()
print(string.format("references: %d missing", missing))

local function loadOrder(path, out)
    out = out or {}
    for _, r in ipairs(refsOf(path)) do
        if r:match("%.lua$") then out[#out + 1] = r
        elseif r:match("%.xml$") then loadOrder(r, out) end
    end
    return out
end

-- 3. load and start up
local M = require("Tests.mock_wow")
-- SavedVariables start nil, as on a fresh install.
for _, toc in ipairs({ ROOT .. "/AzerothRoute/AzerothRoute.toc" }) do
    for list in (read(toc) or ""):gmatch("## SavedVariables[%w]*:%s*([^\r\n]+)") do
        for name in list:gmatch("[%w_]+") do M.saved[name] = true end
    end
end
-- AzerothRoute 1's settings, as an updating player has them.
rawset(_G, "AzerothRouteSavedDB", {
    profileKeys = { ["Pato - Forever"] = "Default" },
    profiles = { Default = { autoaccept = false, autoturnin = true, targetmacro = false } },
    global = { minimap = { hide = true } },
})
local ns = {}
local order = loadOrder(ROOT .. "/AzerothRoute/AzerothRoute.toc")
local loadErrors = 0
for _, file in ipairs(order) do
    local chunk, err = loadfile(file)
    if chunk then
        local ok, e = pcall(chunk, "AzerothRoute", ns)
        if not ok then loadErrors = loadErrors + 1 fail("load " .. file .. ": " .. tostring(e)) end
    end
end
print(string.format("load: %d files, %d errors", #order, loadErrors))

local function fire(event, ...)
    local before = #M.errors
    M:Fire(event, ...)
    M:RunTimers(3)
    for i = before + 1, #M.errors do fail(M.errors[i]) end
end
fire("ADDON_LOADED", "AzerothRoute")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD", true, false)
print(string.format("start-up: %d errors", #M.errors))

-- 3b. load-on-demand packs, each with its own addon table, as the game loads them later
local PACKS = { "AzerothRoute_Guides", "AzerothRoute_Guides_Horde", "AzerothRoute_Guides_Alliance",
    "AzerothRoute_QuestDB", "AzerothRoute_Codex", "AzerothRoute_Experimental", "AzerothRoute_ItemDB",
    "AzerothRoute_Options", "AzerothRoute_Nav", "AzerothRoute_esMX" }
local packErrors, packFiles = 0, 0
for _, name in ipairs(PACKS) do
    local files = loadOrder(ROOT .. "/" .. name .. "/" .. name .. ".toc")
    if #files == 0 then fail("pack " .. name .. " has no files") end
    local packNs = {}
    for _, file in ipairs(files) do
        packFiles = packFiles + 1
        local chunk = loadfile(file)
        if chunk then
            local ok, e = pcall(chunk, name, packNs)
            if not ok then packErrors = packErrors + 1 fail("load " .. file .. ": " .. tostring(e)) end
        end
    end
end
M:RunTimers(3)
print(string.format("packs: %d packs, %d files, %d errors", #PACKS, packFiles, packErrors))

-- 5. AzerothRoute 1 settings carried over once
local function expect(path, want)
    local got = ns.Get(path)
    if got ~= want then fail(string.format("migration %s: expected %s, got %s", path, tostring(want), tostring(got))) end
end
expect("behavior.autoAccept", false)
expect("behavior.autoTurnin", true)
expect("qol.targetButton", false)
expect("maps.minimapButton", false)
if not _G.AzerothRouteSavedDB.migratedToV2 then fail("AzerothRoute 1 settings not marked as migrated") end
ns.Set("behavior.autoAccept", true)
if ns.MigrateV1() ~= 0 or ns.Get("behavior.autoAccept") ~= true then fail("migration ran twice") end
print("migration: checked")

-- 6. Talents: the plans are on and Apply talents spends the next picks in order
do
    local T = ns.Talents
    local data = T and T.Data("PALADIN")
    if T.SOON then fail("talent plans still 'coming soon'") end
    if not data or #data.builds ~= 3 then fail("no Paladin talent plans") else
        local build = data.builds[1]
        local function liveWith(taken, granted)
            local nodes = {}
            for id, nd in pairs(data.nodes) do nodes[id] = { active = 0, current = 0, max = nd.max, spell = nd.spell, name = nd.name } end
            for i = 1, taken do local pk = build.picks[i]; nodes[pk.node].active, nodes[pk.node].current = pk.rank, pk.rank end
            return { config = 7, nodes = nodes, granted = granted }
        end
        local function current(live)
            local valid = T.Validate(data, live)
            local ranks = {}
            for id, l in pairs(valid.map) do ranks[id] = live.nodes[l].current end
            return { data = data, build = build, live = live, valid = valid, staged = T.State(build, ranks, 15, live.granted) }
        end
        local c = current(liveWith(3, 5))
        local picks = T.Apply.Picks(c)
        if #picks ~= 2 then fail("Apply picks: expected 2, got " .. #picks)
        elseif picks[1].node ~= build.picks[4].node or picks[2].node ~= build.picks[5].node then fail("Apply picks out of plan order") end

        local bought, commits = {}, 0
        rawset(_G, "C_Traits", {
            GetNodeInfo = function() return { entryIDs = { 1 } } end,
            PurchaseRank = function(config, node) bought[#bought + 1] = node return config == 7 end,
        })
        rawset(_G, "C_ClassTalents", { CommitConfig = function() commits = commits + 1 return true end })
        local refresh = T.Refresh
        T.Refresh = function() return c end
        local n = T.Apply.Run()
        if n ~= 2 or #bought ~= 2 or commits ~= 1 then fail(string.format("Apply run: bought %d (%d calls), %d commits", n, #bought, commits)) end
        if bought[1] ~= c.valid.map[build.picks[4].node] then fail("Apply bought the wrong node") end
        -- Never in combat, never on a plan the character has left.
        rawset(_G, "InCombatLockdown", function() return true end)
        if T.Apply.Run() ~= 0 then fail("Apply ran in combat") end
        rawset(_G, "InCombatLockdown", function() return false end)
        local off = liveWith(3, 5)
        for id, nd in pairs(off.nodes) do
            local planned = false
            for _, pk in ipairs(build.picks) do if pk.node == id then planned = true end end
            if not planned then nd.active, nd.current = 1, 1 break end
        end
        c = current(off)
        if select(2, T.Apply.Picks(c)) ~= "offplan" then fail("Apply would spend on a plan the character left") end
        T.Refresh = refresh
        print("talents: checked")
    end
end

-- 6b. Talent plans from Icy Veins' WoW Forever leveling guides: one point a level 10-60 for every
-- spec, the talents Forever added or changed on the live tree, and the generator's own rules.
do
    local T = ns.Talents
    local data = T and T.Data("PALADIN")
    local gen = read(ROOT .. "/AzerothRoute/Talents/IcyVeins.lua") or ""
    local plans = 0
    for _ in gen:gmatch('\n\t\t{ key = "') do plans = plans + 1 end
    if plans ~= 27 then fail("Icy Veins plans: expected 27 (3 per class), got " .. plans) end
    if not (data and data.url == "https://www.icy-veins.com/wow-forever/leveling-guides" and data.source:find("Icy Veins", 1, true)) then fail("Paladin plans are not from Icy Veins") end
    local want = { holy = "holy-paladin", protection = "protection-paladin", retribution = "retribution-paladin" }
    for _, b in ipairs(data and data.builds or {}) do
        if #b.picks ~= 51 then fail(b.key .. ": " .. #b.picks .. " picks, not one a level 10-60") end
        if b.link ~= "https://www.icy-veins.com/wow-forever/" .. tostring(want[b.key]) .. "-leveling" then fail(b.key .. " links " .. tostring(b.link)) end
        if not (b.updated and b.updated:match("%d%d%d%d")) then fail(b.key .. " has no guide date") end
        local ranks = {}
        for _, p in ipairs(b.picks) do
            local n = data.nodes[p.node]
            ranks[p.node] = (ranks[p.node] or 0) + 1
            if not n then fail(b.key .. ": pick on a node not in the tree")
            elseif p.rank ~= ranks[p.node] or p.rank > n.max then fail(string.format("%s: %s rank %d of %d", b.key, n.name, p.rank, n.max)) end
        end
    end
    -- New in Forever: Shieldsworn, in the Protection plan, found on the game's tree by its spell.
    local sw = data and data.nodes[-1328544]
    if not (sw and sw.name == "Shieldsworn" and sw.max == 1 and sw.spec == 2) then fail("Shieldsworn missing from the Paladin tree") end
    -- Changed in Forever: Champion of the Light now has 5 ranks.
    local champ
    for _, n in pairs(data and data.nodes or {}) do if n.spell == 1311084 then champ = n end end
    if not (champ and champ.max == 5) then fail("Champion of the Light keeps the snapshot's rank count") end
    if data then
        local nodes = {}
        for id, n in pairs(data.nodes) do nodes[id > 0 and id or 900000 - id] = { active = 0, current = 0, max = n.max, spell = n.spell, name = n.name } end
        local v = T.Validate(data, { nodes = nodes })
        if not v.ok then fail("Icy Veins plans do not match the game's tree: " .. table.concat(v.missing, ", ")) end
        if v.map[-1328544] ~= 900000 + 1328544 then fail("Shieldsworn not matched to the game's node") end
    end
    -- The generator refuses a plan that breaks the rules.
    local gen = dofile("tools/fork/icyveins.lua")
    local trees, snapshot = read("tools/fork/icyveins/trees.txt"), read(ROOT .. "/AzerothRoute/Talents/Builds.lua")
    local function generate(source)
        local text, n = gen.build(source, trees, snapshot)
        if text then return n end
        return nil, n
    end
    local source = read("tools/fork/icyveins/leveling.txt")
    local holy = source:match("SPEC holy%-paladin.-\nS [%d%.]+\n")
    local ok = generate(holy)
    if ok ~= 1 then fail("generator: one valid plan gave " .. tostring(ok)) end
    local n, errs = generate((holy:gsub("\nS ([%d%.]+)", function(s) return "\nS " .. s:gsub("%.%d+$", "") end)))
    if n or not (errs and errs[1]:find("50 points", 1, true)) then fail("generator took a plan one point short") end
    n, errs = generate((holy:gsub("\nS ([%d%.]+)", function(s) return "\nS " .. s:gsub("^%d+", "13") end)))
    if n or not (errs and errs[1]:find("Divine Favor rank 2 of 1", 1, true)) then fail("generator took a rank beyond the maximum") end
    n, errs = generate((holy:gsub("|1311606\n", "|999\n")))
    if n or not (errs and errs[1]:find("not in the class's talent tree", 1, true)) then fail("generator took a talent outside the tree") end
    print(string.format("icy veins: %d plans checked", plans))
end

-- 7. Identity: AzerothRoute's colours, art and words
do
    local Th = ns.Theme
    local r, g, b = Th.Accent()
    -- #FF5A12 ember, #13285A sapphire, #ECE6DC pearl.
    if not (r and math.abs(r - 1) < 1e-3 and math.abs(g - 0.353) < 1e-3 and math.abs(b - 0.071) < 1e-3) then fail("accent is not ember orange #FF5A12: " .. tostring(r) .. "," .. tostring(g) .. "," .. tostring(b)) end
    local dusk = Th.SCHEMES and Th.SCHEMES.dusk
    if not (dusk and math.abs(dusk.bg[1] - 0.075) < 1e-6 and math.abs(dusk.bg[2] - 0.157) < 1e-6 and math.abs(dusk.bg[3] - 0.353) < 1e-6) then fail("default scheme ground is not sapphire #13285A") end
    if not (dusk and math.abs(dusk.text[1] - 0.925) < 1e-6 and math.abs(dusk.text[2] - 0.902) < 1e-6 and math.abs(dusk.text[3] - 0.863) < 1e-6) then fail("default scheme text is not pearl white #ECE6DC") end
    for _, name in ipairs({ "emblem", "logo", "wordmark", "wordmark-small", "watermark", "band-stars", "emblem-hot" }) do
        local mine = read("tools/fork/assets/AzerothRoute/Media/UI/" .. name .. ".tga")
        local shipped = read(ROOT .. "/AzerothRoute/Media/UI/" .. name .. ".tga")
        if not mine or mine ~= shipped then fail("texture " .. name .. " is not AzerothRoute's") end
    end
    if ns.L["Your route through Azeroth"] ~= "Tu camino por Azeroth" then fail("tagline not in Spanish: " .. tostring(ns.L["Your route through Azeroth"])) end
    print("identity: checked")
end

-- 8. No trace of Polestar in what the game shows: every Lua string naming it (comments skipped)
-- must be the one legal notice, "Based on Polestar by The Polestar authors" (and its Spanish).
do
    local ALLOWED = { ['"Based on Polestar by The Polestar authors"'] = true, ['"Basado en Polestar, de los autores de Polestar"'] = true }
    local stray = {}
    local hh = io.popen('find ' .. ROOT .. ' -name "*.lua"')
    for path in hh:lines() do
        local src = read(path)
        if src and src:find("Polestar", 1, true) then
            local pos, n = 1, #src
            while pos <= n do
                local st = src:find("[\"'%-%[]", pos)
                if not st then break end
                local c, e, kind = src:sub(st, st), nil, nil
                if c == "-" then
                    if src:sub(st + 1, st + 1) == "-" then
                        local eq = src:match("^%[(=*)%[", st + 2)
                        if eq then local _, ce = src:find("%]" .. eq .. "%]", st + 2) e = ce or n
                        else local nl = src:find("\n", st + 2, true) e = nl and nl - 1 or n end
                        kind = "comment"
                    end
                elseif c == "[" then
                    local eq = src:match("^%[(=*)%[", st)
                    if eq then local _, ce = src:find("%]" .. eq .. "%]", st + 2) e = ce or n kind = "string" end
                else
                    local i = st + 1
                    while i <= n do
                        local ch = src:sub(i, i)
                        if ch == "\\" then i = i + 2 elseif ch == c or ch == "\n" then break else i = i + 1 end
                    end
                    e, kind = math.min(i, n), "string"
                end
                if not kind then pos = st + 1 else
                    if kind == "string" then
                        local lit = src:sub(st, e)
                        if lit:find("Polestar", 1, true) and not ALLOWED[lit] then stray[#stray + 1] = path .. ": " .. lit:sub(1, 80) end
                    end
                    pos = e + 1
                end
            end
        end
    end
    hh:close()
    for i = 1, math.min(#stray, 10) do fail("Polestar shown: " .. stray[i]) end
    print(string.format("brand: %d stray Polestar strings", #stray))
end

-- 9. No Polestar community or history: version, thanks, recorder, Discord, release notes
do
    -- Every folder carries the version in VERSION (semantic versioning, from 0.1.0).
    local want = (read("VERSION") or ""):match("^%s*(%d+%.%d+%.%d+)%s*$")
    if not want then fail("VERSION is not MAJOR.MINOR.PATCH") end
    local h3 = io.popen('find ' .. ROOT .. ' -name "*.toc"')
    for toc in h3:lines() do
        local v = (read(toc) or ""):match("## Version:%s*([^\r\n]+)")
        if v ~= want then fail(toc .. " version " .. tostring(v) .. ", VERSION says " .. tostring(want)) end
    end
    h3:close()
    local wn = read(ROOT .. "/AzerothRoute/UI/WhatsNew.lua") or ""
    if wn:match('version = "([^"]+)"') ~= want then fail("What's new does not open on " .. tostring(want)) end
    local log = read("CHANGELOG.md") or ""
    if not log:find("## [" .. tostring(want) .. "]", 1, true) then fail("CHANGELOG.md has no entry for " .. tostring(want)) end
    local opts = read(ROOT .. "/AzerothRoute_Options/UI/Options.lua") or ""
    if opts:find('key = "thanks"', 1, true) then fail("Options still has the thanks page") end
    if opts:find('key = "recorder"', 1, true) then fail("Options still has the Recorder page") end
    if opts:find("Cinzel", 1, true) then fail("Options credits Polestar's wordmark font") end
    if (read(ROOT .. "/AzerothRoute/Core/Commands.lua") or ""):find('RegisterCommand("discord"', 1, true) then fail("/ar discord still registered") end
    local wn = read(ROOT .. "/AzerothRoute/UI/WhatsNew.lua") or ""
    -- Only AzerothRoute's releases: every version the card lists has its CHANGELOG.md entry.
    local changelog = read("CHANGELOG.md") or ""
    for v in wn:gmatch('version = "([^"]+)"') do
        if not changelog:find("## [" .. v .. "]", 1, true) then fail("What's new lists a release AzerothRoute never had: " .. v) end
    end
    print("community: checked")
end

-- 10. Talent trees: every talent of the class drawn at its row and column, with its plan rank
do
    local TV = ns.UI and ns.UI.TalentsSection
    local data = ns.Talents and ns.Talents.Data("PALADIN")
    if not (TV and TV.DrawTree and data) then fail("no talent tree view") else
        local before = #M.frames
        local parent = CreateFrame("Frame")
        local h = TV.DrawTree(parent, 0, 0, 600, data.builds[1], nil)
        local nodes = 0
        for _ in pairs(data.nodes) do nodes = nodes + 1 end
        local made, withTip, ranked = 0, 0, 0
        for i = before + 1, #M.frames do
            local fr = M.frames[i]
            if fr._kind == "Frame" and fr._scripts.OnEnter and fr.Icon then
                made = made + 1
                if fr.psPlan and fr.psPlan > 0 then ranked = ranked + 1 end
                local ok = pcall(fr._scripts.OnEnter, fr)
                if ok then withTip = withTip + 1 end
            end
        end
        if not (h and h > 0) then fail("tree has no height") end
        if made ~= nodes then fail(string.format("tree drew %d talents of %d", made, nodes)) end
        if withTip ~= made then fail("a talent tooltip failed") end
        if ranked == 0 then fail("no talent carries the plan's ranks") end
        print(string.format("tree: %d talents, %d in the plan", made, ranked))
    end
end

-- 11. Talent trees from the game's own tree (C_Traits): positions, learned ranks, arrows
do
    local TV = ns.UI and ns.UI.TalentsSection
    local T = ns.Talents
    local data = T and T.Data("PALADIN")
    if TV and TV.TreeLayout and data then
        local build = data.builds[1]
        -- A live tree: the plan's first pick node, one talent the plan never names, in three
        -- trees 3000 apart; rows by posY, an arrow from the first to the second.
        local p1 = data.nodes[build.picks[1].node]
        local live = {
            [9001] = { x = 1000, y = 1000, spell = p1.spell, max = p1.max, rank = 2, edge = 9002 },
            [9002] = { x = 1600, y = 1600, spell = 4242, max = 1, rank = 0 },
            [9003] = { x = 4000, y = 1000, spell = 4343, max = 3, rank = 0 },
            [9004] = { x = 7000, y = 2200, spell = 4444, max = 2, rank = 0 },
        }
        rawset(_G, "C_Traits", {
            GetTreeNodes = function() return { 9001, 9002, 9003, 9004 } end,
            GetNodeInfo = function(_, id)
                local n = live[id]
                return { ID = id, posX = n.x, posY = n.y, maxRanks = n.max, activeRank = n.rank, isVisible = true,
                    entryIDs = { id * 10 }, visibleEdges = n.edge and { { targetNode = n.edge } } or {} }
            end,
            GetEntryInfo = function(_, e) return { definitionID = e } end,
            GetDefinitionInfo = function(d) local n = live[d / 10] return { spellID = n.spell } end,
        })
        T.Client.ConfigID = function() return 7 end
        rawset(_G, "C_Spell", { GetSpellName = function(id) return "Talent " .. id end, GetSpellTexture = function() return 1 end })
        local valid = { map = { [build.picks[1].node] = 9001 } }
        local lay, source = TV.TreeLayout(build, { valid = valid }, true)
        if source ~= "live" then fail("tree did not read the game's tree: " .. tostring(source)) else
            local byKey = {}
            for _, n in ipairs(lay.nodes) do byKey[n.key] = n end
            if #lay.nodes ~= 4 then fail("live tree has " .. #lay.nodes .. " talents, not 4") end
            if byKey[9001].tree ~= 1 or byKey[9003].tree ~= 2 or byKey[9004].tree ~= 3 then fail("live tree split wrong") end
            if byKey[9001].row ~= 1 or byKey[9002].row ~= 2 or byKey[9004].row ~= 3 then fail("live tree rows wrong") end
            if byKey[9002].col ~= 2 then fail("live tree columns wrong") end
            if (byKey[9001].planned or 0) < 1 or byKey[9001].have ~= 2 then fail("plan or learned ranks not on the live talent") end
            if (byKey[9002].planned or 0) ~= 0 then fail("a talent the plan never names carries plan ranks") end
            if #lay.edges ~= 1 then fail("live arrows not read") end
            print("live tree: checked")
        end
    end
    if not (read(ROOT .. "/AzerothRoute/UI/Thanks.lua") or ""):find("function T.HeaderLink(f)\n\tdo return end", 1, true) then
        fail("the special-thanks line is still on")
    end
end

-- 12. Talent plans imported from an Icy Veins calculator link pasted in the game: the link's exact
-- order, refusals that save nothing, saved per character, a tab of their own, removed again.
do
    local T = ns.Talents
    local I = T and T.Import
    local data = T and T.Data("PALADIN")
    local UIT = ns.UI and ns.UI.TalentsSection
    if not (I and data and data.calc) then fail("talent import missing") else
        local holy = T.BuildByKey(data, "holy")
        local letterOf = {}
        for letter, id in pairs(data.calc) do letterOf[id] = letter end
        local code = {}
        for i, p in ipairs(holy.picks) do code[i] = letterOf[p.node] or "?" end
        local link = "https://www.icy-veins.com/wow-forever/paladin-talent-calculator#tc-" .. table.concat(code) .. "~70755-d1899b7d"
        -- S1: the link's order, pick by pick.
        local plan, why = I.Decode(data, link)
        if not plan then fail("decode refused the Holy plan's link: " .. tostring(why)) else
            if #plan.picks ~= #holy.picks or plan.spec ~= holy.spec or plan.split ~= holy.split then fail("decoded plan differs from the Holy plan") end
            for i, p in ipairs(plan.picks) do
                if p.node ~= holy.picks[i].node or p.rank ~= holy.picks[i].rank or p.order ~= i then fail("decoded pick " .. i .. " out of order") break end
            end
        end
        local partial = I.Decode(data, "tc-" .. table.concat(code, "", 1, 5))
        if not (partial and #partial.picks == 5) then fail("a link with 5 points did not give 5 picks") end
        -- S4: refusals, each with its reason and a sentence.
        local unused
        for c in ("ZYXWVUTSR"):gmatch(".") do if not data.calc[c] then unused = c break end end
        local single
        for letter, id in pairs(data.calc) do if data.nodes[id].max == 1 then single = letter break end end
        local cases = {
            { "", "empty" },
            { "https://www.icy-veins.com/wow-forever/mage-talent-calculator#tc-00", "class" },
            { "tc-" .. tostring(unused), "letter" },
            { "tc-" .. single .. single, "rank" },
            { "tc-" .. table.concat(code) .. code[#code], "points" },
        }
        for _, case in ipairs(cases) do
            local p, reason, a, b = I.Decode(data, case[1])
            if p or reason ~= case[2] then fail(string.format("decode %q: expected %s, got %s", case[1]:sub(1, 40), case[2], tostring(reason))) end
            local text = I.Message(reason, a, b)
            if type(text) ~= "string" or text == "" then fail("no message for " .. case[2]) end
        end
        if not I.Message("class", "MAGE", "PALADIN"):find("Paladin", 1, true) and not I.Message("class", "MAGE", "PALADIN"):find("PALADIN", 1, true) then fail("class refusal does not name the class") end
        local before = #I.List()
        if I.Add("tc-" .. single .. single, "x") then fail("a refused link was saved") end
        if #I.List() ~= before then fail("a refused link changed the saved imports") end
        -- S2: saved per character, named, kept across a reload of the plans.
        local b = I.Add(link, "  My holy  ")
        if not (b and b.imported and b.specName == "My holy" and #b.picks == 51) then fail("import did not add a named plan") else
            local key = b.key
            local saved = AzerothRouteCharData and AzerothRouteCharData.talents and AzerothRouteCharData.talents.imports
            if not (saved and saved[#saved].link == link and saved[#saved].name == "My holy") then fail("import not saved on the character") end
            if #data.builds ~= 4 then fail("imported plan not listed after the class's 3") end
            -- An update reloads the class's plans: the import comes back at the next refresh.
            local base = {}
            for _, x in ipairs(data.builds) do if not x.imported then base[#base + 1] = x end end
            data.builds = base
            T.Refresh()
            if not T.BuildByKey(data, key) then fail("imported plan lost after the plans reloaded") end
            -- S3: followed like any plan, with its own tab.
            T.Choose(key)
            if T.ActiveBuild(data) ~= T.BuildByKey(data, key) then fail("imported plan cannot be followed") end
            if UIT then
                local nav = UIT.Nav()
                local keys = {}
                for _, n in ipairs(nav) do keys[n.key] = n.label end
                if keys[key] ~= "My holy" then fail("imported plan has no tab") end
                if not (keys.holy and keys.protection and keys.retribution) then fail("spec tabs not keyed by plan") end
                if not keys.import then fail("no Import tab") end
            end
            -- The view: the Import tab shows the page, a bad link a reason, the plan's page Remove.
            if UIT then
                if not UIT.Shown then fail("no view state") end
                UIT.Build(CreateFrame("Frame"), nil)
                UIT.SetTab("import")
                UIT.Render()
                if UIT.Shown().page ~= "import" then fail("Import tab does not show the import page") end
                local nb, reason = UIT.ImportFromBoxes("tc-" .. single .. single, "")
                if nb or reason ~= "rank" or not UIT.Shown().importError then fail("view import did not show the refusal") end
                UIT.SetTab(key)
                UIT.Render()
                if not (UIT.Shown().spec == "My holy" and UIT.Shown().removable) then fail("imported plan page has no Remove") end
            end
            -- Removed: gone from the list and the saved imports, back to following the spec.
            if not I.Remove(key) then fail("remove did not find the plan") end
            if T.BuildByKey(data, key) or #I.List() ~= before then fail("removed plan still there") end
            if T.Choice() ~= "auto" then fail("removing the followed plan left it chosen") end
        end
        print("talent import: checked")
    end
end

-- 4. names
if _G.AzerothRoute ~= ns then fail("global AzerothRoute is not the addon table") end
if rawget(_G, "Polestar") ~= nil then fail("a global named Polestar exists") end
local slashes = {}
for k, v in pairs(_G) do
    if type(k) == "string" and k:match("^SLASH_") and type(v) == "string" then slashes[v] = k end
end
for _, cmd in ipairs({ "/ar", "/azerothroute" }) do
    if not slashes[cmd] then fail("slash command " .. cmd .. " not registered")
    elseif not _G.SlashCmdList[slashes[cmd]:match("^SLASH_(.-)%d+$")] then fail("no handler for " .. cmd) end
end
local bindings = read(ROOT .. "/AzerothRoute/Bindings.xml") or ""
for name in bindings:gmatch('<Binding name="([%w_]+)"') do
    if not name:match("^AZEROTHROUTE_") then fail("binding " .. name) end
end

print(failures == 0 and "OK" or (failures .. " failure(s)"))
os.exit(failures == 0 and 0 or 1)
