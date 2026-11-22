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
    -- WoW Forever's blue and gold: gold #F2C14E accent, night blue #0A1A33 grounds, warm white
    -- #F5EFE0 text, Forever blue #4DB4FF for quests and the route.
    if not (r and math.abs(r - 0.949) < 1e-3 and math.abs(g - 0.757) < 1e-3 and math.abs(b - 0.306) < 1e-3) then fail("accent is not Forever gold #F2C14E: " .. tostring(r) .. "," .. tostring(g) .. "," .. tostring(b)) end
    local dusk = Th.SCHEMES and Th.SCHEMES.dusk
    if not (dusk and math.abs(dusk.bg[1] - 0.039) < 1e-6 and math.abs(dusk.bg[2] - 0.102) < 1e-6 and math.abs(dusk.bg[3] - 0.2) < 1e-6) then fail("default scheme ground is not Forever night blue #0A1A33") end
    if not (dusk and math.abs(dusk.text[1] - 0.961) < 1e-6 and math.abs(dusk.text[2] - 0.937) < 1e-6 and math.abs(dusk.text[3] - 0.878) < 1e-6) then fail("default scheme text is not warm white #F5EFE0") end
    local houseSrc = read(ROOT .. "/AzerothRoute/Theme/House.lua") or ""
    if not houseSrc:find("quest = { 0.302, 0.706, 1, 1 }", 1, true) then fail("quests and the route are not Forever blue #4DB4FF") end
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
    -- The special-thanks line is off (Thanks.HeaderLink returns early), so PlaceThanks is never set:
    -- every call must check for it first (0.5.1: resizing Options called it bare and errored).
    for _, file in ipairs({ "AzerothRoute_Options/UI/Options.lua", "AzerothRoute/UI/Picker.lua" }) do
        local n = 0
        for line in ((read(ROOT .. "/" .. file) or "") .. "\n"):gmatch("([^\n]*)\n") do
            n = n + 1
            if line:find("PlaceThanks()", 1, true) and not line:find("if [%w%.%(%)\", ]*PlaceThanks[\"%)]* then") then
                fail(string.format("%s:%d calls PlaceThanks without checking it exists", file, n))
            end
        end
    end
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

-- 13. The talent point card: on a level-up with a point waiting, a card names the plan's next talent
-- with Apply and View plan; the setting turns it off; nothing shows with no point to spend.
do
    local T = ns.Talents
    local TT = T and T.Toast
    local data = T and T.Data("PALADIN")
    if not (TT and data) then fail("no talent point card") else
        local build = T.BuildByKey(data, "holy")
        local valid = { names = {}, map = {}, back = {}, ok = true, missing = {} }
        local function state(unspent, status)
            local s = { status = status, unspent = unspent, next = build.picks[4], done = 3, total = #build.picks }
            return { data = data, build = build, valid = valid, state = s, staged = s }
        end
        local c = state(2, "behind")
        ns.Set("talents.toast", true)
        if not TT.Notify(c) then fail("card did not show for 2 waiting points") end
        local f = TT.frame
        if not (f and f:IsShown()) then fail("card frame not shown") else
            local want = T.PickText(data, build.picks[4], valid)
            if not (f.Text:GetText() or ""):find(want, 1, true) then fail("card does not name the next talent: " .. tostring(f.Text:GetText())) end
            if not (f.Title:GetText() or ""):find("2", 1, true) then fail("card does not count the waiting points") end
            local applied, shown = 0, 0
            local run, show = T.Apply.Run, T.Show
            T.Apply.Run = function() applied = applied + 1 return 2 end
            T.Show = function() shown = shown + 1 end
            f.Apply:Click()
            f.View:Click()
            T.Apply.Run, T.Show = run, show
            if applied ~= 1 then fail("card's Apply did not apply the plan") end
            if shown ~= 1 then fail("card's View plan did not open the plan") end
            if f:IsShown() then fail("card stayed open after View plan") end
        end
        TT.Hide()
        if TT.Notify(state(0, "onplan")) then fail("card showed with no point to spend") end
        ns.Set("talents.toast", false)
        if TT.Notify(c) then fail("card showed with the setting off") end
        ns.Set("talents.toast", true)
        print("talent card: checked")
    end
end

-- 14. Leveling pace: time to the level cap from the XP left and the rate (the tracker's, else the
-- levels already played), every finished level as a bar, and a page that says when the tracker is off.
do
    local P = ns.UI and ns.UI.Pace
    if not (P and P.Estimate and P.Levels) then fail("no leveling pace page") else
        local levelXP = { [20] = 500, [21] = 2000, [22] = 3000 }
        local splits = { [18] = { seconds = 1800, xp = 3000, kills = 10, quests = 4 }, [19] = { seconds = 1800, xp = 3000, kills = 8, quests = 5, partial = true } }
        local st = { level = 20, remaining = 1000, rate = 6000, maxed = false, splits = splits }
        local e = P.Estimate(st, levelXP, 23)
        if not (e and e.xp == 6000 and math.abs(e.seconds - 3600) < 1e-6 and e.rate == 6000) then fail("time to the cap: " .. tostring(e and e.xp) .. " XP, " .. tostring(e and e.seconds) .. " s") end
        st.rate = 0
        e = P.Estimate(st, levelXP, 23)
        if not (e and e.fromSplits and e.rate == 6000 and math.abs(e.seconds - 3600) < 1e-6) then fail("time to the cap without a live rate should use the levels played") end
        if P.Estimate({ level = 20, remaining = 1000, rate = 0, splits = {} }, levelXP, 23) then fail("an estimate with no rate at all") end
        local maxed = P.Estimate({ level = 23, maxed = true, rate = 0, splits = splits }, levelXP, 23)
        if not (maxed and maxed.maxed and maxed.seconds == 0) then fail("at the cap the estimate is not done") end
        local lv = P.Levels(splits)
        if not (#lv == 2 and lv[1].level == 18 and lv[2].level == 19 and lv[2].partial and lv.total == 3600 and lv.longest == 1800) then fail("level bars wrong") end
        -- The page, with the tracker's numbers and with the tracker off.
        local QoL = ns.QoL
        local get = QoL.GetXPStats
        QoL.GetXPStats = function() return { level = 20, xp = 100, xpMax = 1100, remaining = 1000, percent = 9.1, rate = 6000, maxed = false, timeToLevel = 600, rested = 0, splits = splits } end
        P.Build(CreateFrame("Frame"), nil)
        P.Render()
        local sh = P.Shown()
        if not (sh.bars == 2 and sh.tiles == 3 and sh.toCap and not sh.off) then fail(string.format("pace page: %s bars, %s tiles", tostring(sh.bars), tostring(sh.tiles))) end
        QoL.GetXPStats = function() return nil end
        P.Render()
        if not P.Shown().off then fail("pace page does not say the tracker is off") end
        QoL.GetXPStats = get
        print("pace: checked")
    end
end

-- 15. Racing your best: every character's level times kept for the account, each level compared with
-- the fastest other character's (partly measured levels never count), and the page showing it.
do
    local P = ns.UI and ns.UI.Pace
    if not (P and P.Compare and P.Record) then fail("no comparison with your best character") else
        local store = { chars = {
            ["Thrall-Forever"] = { name = "Thrall", class = "SHAMAN", splits = { [10] = { seconds = 1200 }, [11] = { seconds = 1500 }, [12] = { seconds = 900, partial = true } } },
            ["Jaina-Forever"] = { name = "Jaina", class = "MAGE", splits = { [10] = { seconds = 1000 }, [11] = { seconds = 1800 } } },
            ["Me-Forever"] = { name = "Me", class = "PALADIN", splits = { [10] = { seconds = 1 } } },
        } }
        local mine = { [10] = { seconds = 1100 }, [11] = { seconds = 1400 }, [12] = { seconds = 1000 }, [13] = { seconds = 500, partial = true } }
        local cmp = P.Compare(mine, store, "Me-Forever")
        local b10, b11 = cmp.levels[10], cmp.levels[11]
        if not (b10 and b10.name == "Jaina" and b10.best == 1000 and b10.delta == 100) then fail("level 10 not against Jaina's 1000 s") end
        if not (b11 and b11.name == "Thrall" and b11.best == 1500 and b11.delta == -100) then fail("level 11 not against Thrall's 1500 s") end
        if cmp.levels[12] then fail("a partly measured best counted") end
        if cmp.levels[13] then fail("a partly measured level of mine counted") end
        if not (cmp.n == 2 and cmp.delta == 0) then fail(string.format("total against the best: %s levels, %s s", tostring(cmp.n), tostring(cmp.delta))) end
        if next(P.Compare(mine, { chars = {} }, "Me-Forever").levels) then fail("a comparison with no other character") end
        -- Recording this character into the account store.
        local db = ns.DB()
        db.pace = nil
        local Alts = ns.Alts
        local key = Alts and Alts.Key and Alts.Key()
        if not P.Record({ level = 14, splits = mine }) then fail("level times not recorded") end
        local rec = db.pace and db.pace.chars and key and db.pace.chars[key]
        if not (rec and rec.splits[10].seconds == 1100 and rec.splits[13].partial and rec.class) then fail("recorded entry wrong for " .. tostring(key)) end
        -- The page marks levels against the best.
        db.pace.chars["Jaina-Forever"] = store.chars["Jaina-Forever"]
        local QoL = ns.QoL
        local get = QoL.GetXPStats
        QoL.GetXPStats = function() return { level = 14, xp = 0, xpMax = 1000, remaining = 1000, rate = 5000, maxed = false, timeToLevel = 720, rested = 0, splits = mine } end
        P.Render()
        local sh = P.Shown()
        if not (sh.compared == 2 and sh.versus) then fail("pace page does not compare levels with your best: " .. tostring(sh.compared)) end
        QoL.GetXPStats = get
        db.pace = nil
        print("pace vs best: checked")
    end
end

-- 16. The milestone card: every 10 levels (20 to 60) a card sums up the last ten levels (time, kills,
-- quests, deaths) against your best other character's same ten; deaths are counted per level.
do
    local Ms = ns.UI and ns.UI.Milestone
    if not (Ms and Ms.Summary and Ms.Best and Ms.Notify) then fail("no milestone card") else
        -- Deaths at this level, from the game's PLAYER_DEAD.
        local xp = ns.QoL.State().xp
        local before = xp and xp.levelDeaths or 0
        fire("PLAYER_DEAD")
        xp = ns.QoL.State().xp
        if not (xp and (xp.levelDeaths or 0) == before + 1) then fail("a death was not counted at this level") end
        local mine = {}
        for l = 20, 29 do mine[l] = { seconds = 600, kills = 40, quests = 10, deaths = (l == 25) and 2 or 0 } end
        local sum = Ms.Summary(mine, 20, 30)
        if not (sum.seconds == 6000 and sum.kills == 400 and sum.quests == 100 and sum.deaths == 2 and sum.levels == 10 and sum.complete) then fail("milestone sums wrong") end
        mine[22] = nil
        sum = Ms.Summary(mine, 20, 30)
        if sum.complete or sum.levels ~= 9 then fail("a missing level should make the ten partly measured") end
        mine[22] = { seconds = 600, kills = 40, quests = 10, deaths = 0 }
        local store = { chars = {
            ["Jaina-Forever"] = { name = "Jaina", splits = {} },
            ["Thrall-Forever"] = { name = "Thrall", splits = {} },
            ["Me-Forever"] = { name = "Me", splits = {} },
        } }
        for l = 20, 29 do
            store.chars["Jaina-Forever"].splits[l] = { seconds = 500 }
            store.chars["Thrall-Forever"].splits[l] = { seconds = 400, partial = (l == 21) or nil }
            store.chars["Me-Forever"].splits[l] = { seconds = 1 }
        end
        local best = Ms.Best(store, "Me-Forever", 20, 30)
        if not (best and best.name == "Jaina" and best.seconds == 5000) then fail("best ten levels not Jaina's 5000 s (Thrall's has a partial level)") end
        if Ms.Best({ chars = {} }, "Me-Forever", 20, 30) then fail("a best with no other character") end
        -- The card: at 30, not at 25, not with the setting off.
        ns.Set("qol.milestoneCard", true)
        local stats = { level = 30, splits = mine }
        if not Ms.Notify(30, stats) then fail("no card at level 30") end
        local f = Ms.frame
        if not (f and f:IsShown() and (f.Title:GetText() or ""):find("30", 1, true)) then fail("milestone card not shown for 30") end
        if not (f.Text:GetText() or ""):find("2", 1, true) then fail("milestone card does not count the deaths") end
        Ms.Hide()
        if Ms.Notify(25, stats) then fail("a card at level 25") end
        ns.Set("qol.milestoneCard", false)
        if Ms.Notify(30, stats) then fail("a card with the setting off") end
        ns.Set("qol.milestoneCard", true)
        -- At 60: the whole measured run.
        local run = {}
        for l = 10, 59 do run[l] = { seconds = 100, kills = 1, quests = 1, deaths = 0 } end
        if not Ms.Notify(60, { level = 60, splits = run }) then fail("no card at 60") end
        if not (Ms.frame.Title:GetText() or ""):find("60", 1, true) then fail("no level 60 card") end
        Ms.Hide()
        print("milestone: checked")
    end
end

-- 17. Self-found: a self-found character (C_PlayerInfo.IsSelfFoundActive) gets no auction house buys
-- (card, reminder, list), whatever the setting; anyone else follows qol.auctionBuys.
do
    local AB, Mat = ns.AuctionBuys, ns.Materials
    if not (AB and AB.On and Mat and Mat.SelfFound) then fail("no auction house buys module") else
        local PI = rawget(_G, "C_PlayerInfo")
        local saved = PI and rawget(PI, "IsSelfFoundActive")
        if not PI then PI = {} rawset(_G, "C_PlayerInfo", PI) end
        local selfFound = false
        rawset(PI, "IsSelfFoundActive", function() return selfFound end)
        ns.Set("qol.auctionBuys", true)
        if not AB.On() then fail("auction house buys off for a character who can trade") end
        selfFound = true
        if AB.On() then fail("auction house buys offered to a self-found character") end
        local list = AB.List("all")
        if list and #list > 0 then fail("a self-found character got auction house items") end
        selfFound = false
        ns.Set("qol.auctionBuys", false)
        if AB.On() then fail("auction house buys on with the setting off") end
        ns.Set("qol.auctionBuys", true)
        rawset(PI, "IsSelfFoundActive", saved)
        print("self-found: checked")
    end
end

-- 18. Gathering routes: node spawn spots per zone, the kinds that still teach the skill, the zones with
-- most spots, the spots as one closed loop, and the arrow held on each spot in turn.
do
    local G, R = ns.Gather, ns.Routes
    if not (G and G.Spots and R and R.Order and R.KindsFor and R.Candidates and R.Build and R.Advance and R.Start) then fail("no gathering routes") else
        -- Spots of one zone, decoded from the generated data.
        local spots = G.Spots(1440)
        local ok = #spots > 20
        for _, s in ipairs(spots) do if not (s.k and s.x >= 0 and s.x <= 100 and s.y >= 0 and s.y <= 100 and s.f == "e") then ok = false break end end
        if not ok then fail("Ashenvale spots not decoded: " .. #spots) end
        -- The kinds that still teach Mining at 120: ores needing 21-120, none above.
        local kinds = R.KindsFor(186, 120)
        if #kinds == 0 then fail("no ores for Mining 120") end
        for _, k in ipairs(kinds) do
            local kind = G.Kind(k)
            if not (kind.line == 186 and kind.skill <= 120 and kind.skill > 20) then fail("ore " .. kind.name .. " (" .. kind.skill .. ") is not for Mining 120") end
        end
        if #R.KindsFor(182, 0) ~= 0 then fail("herbs for a skill of 0") end
        -- A square's corners, shuffled, come back as its perimeter.
        local pts = { { wx = 0, wy = 0 }, { wx = 100, wy = 100 }, { wx = 100, wy = 0 }, { wx = 0, wy = 100 } }
        local order, len = R.Order(pts)
        if #order ~= 4 or math.abs(len - 400) > 1e-6 then fail("square loop: " .. #order .. " points, " .. tostring(len) .. " yards") end
        -- A grid of 25 points: every point once, no longer than the snake through it plus the way back.
        local grid = {}
        for i = 0, 4 do for j = 0, 4 do grid[#grid + 1] = { wx = i * 50 + (j % 2) * 3, wy = j * 50 } end end
        local go, glen = R.Order(grid)
        local seen = {}
        for _, p in ipairs(go) do seen[p] = true end
        local n = 0
        for _ in pairs(seen) do n = n + 1 end
        if n ~= 25 then fail("grid loop visits " .. n .. " of 25") end
        if glen > 25 * 50 + 300 then fail("grid loop too long: " .. glen) end
        -- Candidates: zones with spots of those kinds, the most first, none far above the level.
        local cands = R.Candidates(186, 120, 25)
        if #cands == 0 then fail("no zone for Mining 120") else
            for i = 2, #cands do if cands[i].count > cands[i - 1].count then fail("zones not by spot count") break end end
            for _, c in ipairs(cands) do
                local lo = ns.Maps and ns.Maps.GetZoneLevels and ns.Maps.GetZoneLevels(c.map)
                if lo and lo > 25 + R.LEVEL_SLACK then fail("zone " .. c.map .. " (level " .. lo .. ") above level 25") end
            end
            -- Every zone offered, for any skill, makes a route.
            for _, case in ipairs({ { 182, 40, 12 }, { 182, 140, 28 }, { 186, 70, 18 }, { 186, 180, 38 }, { 186, 260, 55 }, { 182, 290, 60 } }) do
                for _, c in ipairs(R.Candidates(case[1], case[2], case[3])) do
                    if not R.Build(c.map, c.kinds, case[1]) then fail(string.format("zone %d offered for skill %d makes no route", c.map, case[2])) end
                end
            end
            local route = R.Build(cands[1].map, cands[1].kinds, 186)
            if not (route and #route.points == cands[1].count and route.length > 0) then fail("route not built from the best zone") end
            -- Following: the arrow holds the nearest spot, moves on within reach, and lets go on Stop.
            local held, unheld = {}, 0
            local Nav = ns.Nav
            local hold, unhold = Nav.Hold, Nav.Unhold
            Nav.Hold = function(map, x, y, label) held[#held + 1] = { map = map, x = x, y = y, label = label } end
            Nav.Unhold = function() unheld = unheld + 1 end
            local p1 = route.points[1]
            if R.Advance(route, 1, p1.wx + 5, p1.wy) ~= 2 then fail("not moved on within reach") end
            if R.Advance(route, 1, p1.wx + 500, p1.wy) ~= 1 then fail("moved on while far away") end
            if R.Advance(route, #route.points, route.points[#route.points].wx, route.points[#route.points].wy) ~= 1 then fail("the loop does not wrap") end
            R.Start(route, 1)
            if not (R.Active() == route and #held == 1 and held[1].map == route.map and held[1].label) then fail("start did not hold the first spot") end
            R.Skip()
            if #held ~= 2 or held[2].x ~= route.points[2].x then fail("skip did not hold the next spot") end
            R.Stop()
            if R.Active() or unheld ~= 1 then fail("stop did not let go of the arrow") end
            Nav.Hold, Nav.Unhold = hold, unhold
        end
        print("routes: checked")
    end
end

-- 19. The Gathering routes page: a route per zone for each gathering skill the character has, Start
-- follows one, and the page then shows it with Skip and Stop; no skill, a note saying so.
do
    local RV, R = ns.UI and ns.UI.Routes, ns.Routes
    if not (RV and RV.Build and RV.Render and RV.Shown) then fail("no gathering routes page") else
        local C = ns.Compat
        local rank = C.GetSkillRank
        local Nav = ns.Nav
        local hold, unhold = Nav.Hold, Nav.Unhold
        Nav.Hold, Nav.Unhold = function() end, function() end
        C.GetSkillRank = function(line) if line == 186 then return 180, 225 end return nil end
        RV.Build(CreateFrame("Frame"), nil)
        RV.Render()
        local sh = RV.Shown()
        if not (sh.skills == 1 and sh.rows and sh.rows > 0) then fail(string.format("routes page: %s skills, %s rows", tostring(sh.skills), tostring(sh.rows))) end
        RV.StartRow(1)
        if not R.Active() then fail("Start did not follow the route") end
        RV.Render()
        if not RV.Shown().active then fail("the page does not show the route being followed") end
        RV.StopActive()
        if R.Active() then fail("Stop on the page did not stop the route") end
        C.GetSkillRank = function() return nil end
        RV.Render()
        if not RV.Shown().none then fail("no note for a character without gathering skills") end
        C.GetSkillRank = rank
        Nav.Hold, Nav.Unhold = hold, unhold
        print("routes page: checked")
    end
end

-- 20. The Battle.net look: rounded surfaces (nine-slice art), flat headers with no night band, haze or
-- gold rim (kept), and primary buttons in the theme's accent.
do
    local Theme, W = ns.Theme, ns.Widgets
    local B = Theme and Theme.Battlenet
    if not B then fail("no Battle.net look") else
        for _, name in ipairs({ "round-8", "round-8-ring" }) do
            if not read("tools/fork/assets/AzerothRoute/Media/UI/" .. name .. ".tga") then fail("missing art " .. name) end
        end
        local function isRound(tex) return tex and type(tex:GetTexture()) == "string" and tex:GetTexture():find("round%-8") end
        for _, kind in ipairs({ "panel", "button", "dropdown", "tile", "editbox" }) do
            local f = CreateFrame(kind == "button" and "Button" or "Frame", nil, UIParent)
            Theme.Skin(f, kind)
            local d = f.psSkin
            if not (d and isRound(d.bg)) then fail(kind .. " ground is not rounded") end
            if not (d and d.ring and d.ring:IsShown() and isRound(d.ring)) then fail(kind .. " has no rounded edge") end
            if f.psBorder then for i = 1, 4 do if f.psBorder[i]:IsShown() then fail(kind .. " keeps its square border") break end end end
        end
        -- The hub's shell: flat header.
        local shell = W.Shell("AzerothRouteBnetProbe", { rail = true, title = "Probe" })
        if not (shell.Band:GetAlpha() == 0 and shell.Haze:GetAlpha() == 0) then fail("the night band or haze still shows") end
        local rim = rawget(shell, "psRim") or rawget(shell, "Rim")
        if rim and rim:GetAlpha() == 0 then fail("the gold rim is hidden") end
        if not isRound(shell.psSkin and shell.psSkin.bg) then fail("the window is not rounded") end
        -- Primary button: the theme's accent (it follows the scheme and accent the player picks), no lit top line, no edge.
        local p = W.Button(UIParent, "Continue", nil, { primary = true })
        local r, g, b = p.psSkin.bg:GetVertexColor()
        local br, bg2, bb = Theme.Accent()
        if not (math.abs(r - br) < 1e-3 and math.abs(g - bg2) < 1e-3 and math.abs(b - bb) < 1e-3) then fail(string.format("primary button is %.2f,%.2f,%.2f, not the theme's accent", r, g, b)) end
        local hi = rawget(p, "psTopHi")
        if hi and hi:IsShown() then fail("primary button keeps the lit top line") end
        if p.psSkin.ring and p.psSkin.ring:IsShown() then fail("primary button has an edge") end
        print("battle.net look: checked")
    end
end

-- 21. The Battle.net hub: rounded selection blocks (no accent bar) in the side list and the icon rail,
-- and a big blue "Continue guide" button at the foot of the side column that opens the guide window.
do
    local Theme, W = ns.Theme, ns.Widgets
    local B = Theme and Theme.Battlenet
    if not (B and B.Continue) then fail("no Battle.net hub") else
        local function isRound(tex) return tex and type(tex:GetTexture()) == "string" and tex:GetTexture():find("round%-8") end
        local hub = W.Shell("AzerothRouteBnetHub", { rail = true, title = "Hub" })
        W.ShellNav(hub, { { key = "a", label = "Elwynn" }, { key = "b", label = "Westfall" } }, "a", function() end)
        local nb = hub.navButtons[1]
        if not (nb and isRound(nb.Selected)) then fail("side list selection is not a rounded block") end
        if nb and nb.Bar:GetAlpha() ~= 0 then fail("side list keeps the accent bar") end
        -- The hub's rail is a top bar of tabs now (section 22).
        local c = rawget(hub, "Continue")
        if not (c and c.psPrimary) then fail("no Continue guide button on the hub") else
            local shown = 0
            ns.On("SHOW_FRAME", function() shown = shown + 1 end)
            hub:Show()
            c:Click()
            if shown ~= 1 then fail("Continue guide did not open the guide window") end
            if hub:IsShown() then fail("the hub stayed open after Continue guide") end
        end
        local plain = W.Shell("AzerothRouteBnetPlain", { title = "Options" })
        if rawget(plain, "Continue") then fail("a window without the rail got the Continue guide button") end
        -- Settings switches keep the theme's own colours (no fixed blue).
        if B.PRIMARY then fail("a fixed Battle.net blue still overrides the theme") end
        -- Only AzerothRoute's own design: one theme offered, any other saved choice drawn as it.
        local choices = Theme.SkinChoices()
        if not (#choices == 1 and choices[1].value == "polestar") then fail("other looks still offered: " .. #choices) end
        local saved = ns.Get("ui.skin")
        ns.Set("ui.skin", "halo")
        if Theme.SkinId() ~= "polestar" then fail("a saved Polestar look is still drawn: " .. tostring(Theme.SkinId())) end
        ns.Set("ui.skin", saved)
        -- The target list: a common mob in the accent gold (not red), elites in quest blue, NPCs green.
        local Bt = ns.QoL and ns.QoL.Buttons
        if not (Bt and Bt.TargetLook) then fail("no target button looks") else
            local _, mob = Bt.TargetLook("kill", "Bristleback Hunter")
            local _, elite = Bt.TargetLook("kill", "Boss", nil, true)
            local _, npc = Bt.TargetLook("talk", "Innkeeper")
            if mob ~= "accent" then fail("a common mob is drawn in " .. tostring(mob) .. ", not the accent gold") end
            if elite ~= "quest" then fail("an elite is drawn in " .. tostring(elite)) end
            if npc ~= "success" then fail("an NPC is drawn in " .. tostring(npc)) end
            local src = read(ROOT .. "/AzerothRoute/QoL/Buttons.lua") or ""
            if src:find('or "danger"\n', 1, true) or src:find('"textDim" or "danger"))', 1, true) then fail("the target list still paints mobs red") end
        end
        print("battle.net hub: checked")
    end
end

-- 22. The hub's top bar: the rail becomes a bar across the top with the logo, the sections as tabs and
-- the search; the side column starts at the top with the list; the header is short.
do
    local Theme, W = ns.Theme, ns.Widgets
    local B = Theme and Theme.Battlenet
    if not (B and B.TOP) then fail("no top bar") else
        local hub = W.Shell("AzerothRouteBnetTop", { rail = true, title = "Hub", scalePath = "ui.menuScale" })
        if hub.psTopBar ~= B.TOP then fail("the hub has no top bar") end
        -- The window's tools in the bar: the search, the menu scale and a close button anyone finds.
        if hub.Search:GetParent() ~= hub.Rail then fail("the hub's search is not in the top bar") end
        if hub.psNavTop ~= 12 then fail("the side list does not start at the top: " .. tostring(hub.psNavTop)) end
        local bc = rawget(hub, "BarClose")
        if not (bc and bc:GetParent() == hub.Rail) then fail("the hub has no close button in the top bar") else
            hub:Show()
            bc:Click()
            if hub:IsShown() then fail("the top bar's close button did not close the hub") end
        end
        if hub.Close:GetAlpha() ~= 0 then fail("the old close button over the map still shows") end
        if not (hub.HeaderTools and hub.HeaderTools:GetParent() == hub.Rail and hub.HeaderTools:IsShown()) then fail("the hub's menu scale is not in the top bar") end
        hub.HeaderTools.Place()
        if hub.HeaderTools:GetParent() ~= hub.Rail or hub.Search:GetParent() ~= hub.Rail then fail("the hub's tools left the top bar when placed again") end
        if not (hub.Emblem:IsShown() and hub.Wordmark:IsShown()) then fail("the logo or the name is hidden in the top bar") end
        if not rawget(hub.Rail, "Band") then fail("the top bar has no theme band") end
        local rim = rawget(hub, "psRim") or rawget(hub, "Rim")
        if rim and rim:GetAlpha() == 0 then fail("the gold rim is hidden") end
        if B.TabLabel({ key = "Routes", label = "Gathering routes" }) == "Gathering routes" then fail("Gathering routes has no short tab name") end
        if hub.Wordmark:GetParent() ~= hub.Rail then fail("the name is not in the top bar") end
        if Theme.Metric("shellHeader", 112) ~= B.HEADER or W.SHELL.header ~= B.HEADER then fail("the header is still tall") end
        local picked
        local items = { { key = "Guides", label = "Guides", icon = "guides" }, { key = "Talents", label = "Talents", icon = "icon-learn" } }
        local foot = { { key = "Options", label = "Options", icon = "sliders" } }
        local n = W.ShellRail(hub, items, foot, "Talents", function(k) picked = k end)
        if n ~= 2 then fail("top bar shows " .. tostring(n) .. " of 2 sections") end
        if #hub.railButtons < 3 then fail("top bar buttons missing") else
            for _, b in ipairs(hub.railButtons) do if b:GetParent() ~= hub.Rail then fail("a section button is not in the top bar") break end end
            hub.railButtons[1]:Click()
            if picked ~= "Guides" then fail("a top bar tab does not open its section") end
            if not hub.railButtons[2].Under:IsShown() or hub.railButtons[1].Under:IsShown() then fail("the active tab is not marked") end
            -- The bar's search is the global one: no Lookup tab beside it.
            W.ShellRail(hub, { { key = "Guides", label = "Guides", icon = "guides" }, { key = "Lookup", label = "Lookup", icon = "search" } }, foot, "Guides", function() end)
            for _, b in ipairs(hub.railButtons) do if b:IsShown() and b.psKey == "Lookup" then fail("the Lookup tab is still in the top bar") end end
            W.ShellRail(hub, items, foot, "Talents", function(k) picked = k end)
            -- Too narrow for every name (the mock's window is 100 wide): the active tab keeps its name.
            if (hub.railButtons[2].Label:GetText() or "") == "" then fail("the active tab lost its name") end
            if (hub.railButtons[1].Label:GetText() or "") ~= "" then fail("an inactive tab kept its name in a narrow bar") end
        end
        local plain = W.Shell("AzerothRouteBnetTopPlain", { title = "Options" })
        if rawget(plain, "psTopBar") then fail("a window without the rail got the top bar") end
        -- 23. The settings: groups as tabs in a top bar, the side list holds the active group's pages.
        local opt = W.Shell("AzerothRouteOptions", { title = "Settings", headerSearch = true, scalePath = "ui.menuScale" })
        if opt.psTopBar ~= B.TOP or not rawget(opt, "GroupBar") then fail("the settings have no top bar") else
            if not (opt.Emblem:IsShown() and opt.Wordmark:IsShown() and opt.Status:IsShown()) then fail("the settings lost their logo, name or version") end
            if not rawget(opt.GroupBar, "Band") then fail("the settings' top bar has no theme band") end
            -- Folded, the real settings window keeps its top bar only (the title goes with the rest).
            local O = ns.UI and ns.UI.Options
            if O and O.Fold and ns.UI.ShowOptions then
                pcall(ns.UI.ShowOptions)
                local win = rawget(_G, "AzerothRouteOptions")
                if win and rawget(win, "psTopBar") then
                    local setH = win.SetHeight
                    local lastH
                    win.SetHeight = function(self, h) lastH = h return setH(self, h) end
                    O.Fold(true)
                    if lastH ~= win.psTopBar + 2 then fail("folded settings are " .. tostring(lastH) .. " tall, not the top bar's " .. (win.psTopBar + 2)) end
                    if win.Header:IsShown() then fail("folded settings keep the header (its title hangs below the bar)") end
                    O.Fold(false)
                    if not win.Header:IsShown() then fail("unfolded settings lost the header") end
                    win.SetHeight = setH
                    win:Hide()
                else
                    fail("the real settings window has no top bar")
                end
            end
            -- The window's tools (search, scale, close) sit in the top bar, over everything, and stay there.
            for _, again in ipairs({ false, true }) do
                if again and opt.HeaderTools then opt.HeaderTools.Place() end
                if opt.Close:GetParent() ~= opt.GroupBar then fail("the settings' close button is not in the top bar") end
                if not (opt.HeaderTools and opt.HeaderTools:GetParent() == opt.GroupBar and opt.HeaderTools:IsShown()) then fail("the menu scale is not in the top bar") end
                if opt.Search:GetParent() ~= opt.GroupBar then fail("the settings search is not in the top bar") end
            end
            local chosen
            local items = {
                { group = true, key = "#guided", label = "Guided" },
                { key = "guide", label = "Guide", indent = true }, { key = "map", label = "Map", indent = true },
                { group = true, key = "#look", label = "Look" },
                { key = "appearance", label = "Appearance", indent = true }, { key = "arrow", label = "Arrow", indent = true }, { key = "buttons", label = "Buttons", indent = true },
            }
            W.ShellNav(opt, items, "arrow", function(k) chosen = k end)
            local shown = {}
            for _, b in ipairs(opt.navButtons) do if b:IsShown() then shown[#shown + 1] = b.psKey or b.Label:GetText() end end
            if #shown ~= 3 then fail("the side list shows " .. #shown .. " rows, not the Look group's 3 pages") end
            local tabs = opt.groupButtons or {}
            local live = 0
            for _, t in ipairs(tabs) do if t:IsShown() then live = live + 1 end end
            if live ~= 2 then fail("the top bar shows " .. live .. " groups, not 2") end
            if tabs[2] and not tabs[2].Under:IsShown() then fail("the open page's group is not marked") end
            if tabs[1] then tabs[1]:Click() end
            if chosen ~= "guide" then fail("a group tab does not open its first page: " .. tostring(chosen)) end
            -- A search's results (no groups) stay as they are.
            W.ShellNav(opt, { { key = "arrow", label = "Arrow" }, { key = "map", label = "Map" } }, nil, function() end)
            local n = 0
            for _, b in ipairs(opt.navButtons) do if b:IsShown() then n = n + 1 end end
            if n ~= 2 then fail("search results were filtered: " .. n) end
        end
    end
end

-- 24. The hub's search is global: typed in a section without its own search (Talents), it opens Lookup
-- with the text; in a section with its own search it stays there.
do
    local P = ns.UI and ns.UI.Picker
    if not (P and ns.UI.ShowPicker and P.ShowSection) then fail("no hub to search from") else
        pcall(ns.UI.ShowPicker)
        local win = P.frame
        local box = win and win.Search
        local changed = box and box._scripts and box._scripts.OnTextChanged
        if not changed then fail("the hub's search box has no text handler") else
            P.ShowSection("Talents")
            if not box:IsShown() then fail("the global search is hidden in Talents") end
            box:SetText("Peacebloom")
            changed(box, true)
            M:RunTimers(3)
            if P.Section() ~= "Lookup" then fail("typing in Talents did not open the global search: " .. tostring(P.Section())) end
            box:SetText("")
            pcall(changed, box, true)
            pcall(M.RunTimers, M, 3)
        end
        if win then win:Hide() end
    end
end

-- 25. Lookup's preview: a mount as the mount collection shows it (its creature display), gear tried on
-- the player as the appearances collection does, an NPC as itself; nothing for a quest or a zone.
do
    local PV = ns.UI and ns.UI.LookupPreview
    if not (PV and PV.Show and PV.Hide) then fail("no Lookup preview") else
        local d = CreateFrame("Frame", nil, UIParent)
        local MJ = rawget(_G, "C_MountJournal")
        rawset(_G, "C_MountJournal", {
            GetMountFromItem = function(id) return id == 100 and 7 or nil end,
            GetMountFromSpell = function() return nil end,
            GetMountInfoExtraByID = function(m) return m == 7 and 4321 or nil end,
        })
        local calls = {}
        local h = PV.Show(d, "mount", 100, 10, 300)
        local m = PV.Models and PV.Models.creature
        if not (h and h > 0 and m and m:IsShown()) then fail("a mount got no model") end
        if m then
            m.SetDisplayInfo = function(_, id) calls.display = id end
            m.SetCreature = function(_, id) calls.creature = id end
            PV.Show(d, "mount", 100, 10, 300)
            if calls.display ~= 4321 then fail("the mount model is not its creature display: " .. tostring(calls.display)) end
            PV.Show(d, "npc", 299, 10, 300)
            if calls.creature ~= 299 then fail("the NPC model is not the NPC") end
        end
        local IE = rawget(_G, "C_Item")
        rawset(_G, "C_Item", setmetatable({ IsEquippableItem = function(id) return id == 200 end }, { __index = IE }))
        local dh = PV.Show(d, "item", 200, 10, 300)
        local dm = PV.Models and PV.Models.dress
        if dm then
            dm.TryOn = function(_, link) calls.tryOn = link end
            PV.Show(d, "item", 200, 10, 300)
        end
        if not (dh and dh > 0 and calls.tryOn and tostring(calls.tryOn):find("200", 1, true)) then fail("gear is not tried on the player") end
        if (PV.Show(d, "item", 201, 10, 300) or 0) ~= 0 then fail("a preview for an item nobody wears") end
        if (PV.Show(d, "quest", 5, 10, 300) or 0) ~= 0 or (PV.Show(d, "zone", 12, 10, 300) or 0) ~= 0 then fail("a preview for a quest or a zone") end
        if m and m:IsShown() then fail("the model stayed for a quest") end
        rawset(_G, "C_MountJournal", MJ)
        rawset(_G, "C_Item", IE)
        print("lookup preview: checked")
    end
end

-- 26. Quest icons on enemy nameplates: on by default, the sword when the quest needs the mob killed,
-- the bag when it needs an item it drops (the sword when it needs both), as the target list shows them.
do
    local Q = ns.QuestDB
    if not (Q and Q.NameplateLook) then fail("no nameplate kill/loot icon") else
        if ns.Get("qol.nameplateIcons") ~= true then fail("nameplate quest icons are off by default") end
        local get = Q.ObjectivesForNpc
        local lists = {
            [1] = { { kind = 1, done = false, entry = {} } },
            [2] = { { kind = 2, done = false, entry = {} } },
            [3] = { { kind = 2, done = false, entry = {} }, { kind = 1, done = false, entry = {} } },
            [4] = { { kind = 1, done = true, entry = {} }, { kind = 2, done = false, entry = {} } },
        }
        Q.ObjectivesForNpc = function(id) return lists[id] end
        local function look(id) return (Q.NameplateLook(id)) end
        if look(1) ~= "icon-kill" then fail("a mob to kill does not get the sword: " .. tostring(look(1))) end
        if look(2) ~= "icon-collect" then fail("a mob to loot does not get the bag: " .. tostring(look(2))) end
        if look(3) ~= "icon-kill" then fail("a mob to kill and loot does not get the sword") end
        if look(4) ~= "icon-collect" then fail("a mob already killed enough still gets the sword") end
        Q.ObjectivesForNpc = get
        print("nameplate icons: checked")
    end
end

-- 27. Polestar's looks and skin folders are not shipped, and nothing asks for them.
do
    for _, name in ipairs({ "AzerothRoute_Looks", "AzerothRoute_SkinAPI", "AzerothRoute_Skin_Hairline", "AzerothRoute_Skin_Waymark" }) do
        if read(ROOT .. "/" .. name .. "/" .. name .. ".toc") then fail(name .. " is still shipped") end
    end
    local data = read(ROOT .. "/AzerothRoute/Core/Data.lua") or ""
    local packs = read(ROOT .. "/AzerothRoute/UI/Packs.lua") or ""
    if data:find('AzerothRoute_Looks = true', 1, true) or data:find('"AzerothRoute_Looks"', 1, true) then fail("the looks folder is still a companion") end
    if packs:find('AzerothRoute_Looks = true', 1, true) then fail("the looks folder is still turned back on") end
    print("unused folders: checked")
end

-- 28. Every guide step and map icon is AzerothRoute's own drawing (tools/fork/make_icons.lua), flight a
-- winged boot: the shipped file is the drawn one, byte for byte.
do
    local own, list = 0, io.popen('find ' .. ROOT .. '/AzerothRoute/Media/UI ' .. ROOT .. '/AzerothRoute/Media/Map -name "icon-*.tga"')
    for p in list:lines() do
        local rel = p:sub(#ROOT + 2)
        local drawn = read("tools/fork/assets/" .. rel)
        if not drawn then fail("not drawn by AzerothRoute: " .. rel)
        elseif drawn ~= read(p) then fail("not the drawn icon: " .. rel)
        else own = own + 1 end
    end
    list:close()
    if own < 70 then fail("too few icons drawn: " .. own) end
    if not read("tools/fork/assets/AzerothRoute/Media/Map/medallion-polestar.tga") then fail("the medallion is not drawn") end
    print("own icons: " .. own)
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
