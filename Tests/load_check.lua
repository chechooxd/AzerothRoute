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

-- 7. Identity: AzerothRoute's colours, art and words
do
    local Th = ns.Theme
    local r, g, b = Th.Accent()
    if not (r and math.abs(r - 0.302) < 1e-3 and math.abs(b - 1) < 1e-3) then fail("accent is not Forever azure: " .. tostring(r) .. "," .. tostring(g) .. "," .. tostring(b)) end
    local dusk = Th.SCHEMES and Th.SCHEMES.dusk
    if not (dusk and math.abs(dusk.bg[3] - 0.2) < 1e-6) then fail("default scheme is not AzerothRoute blue") end
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
    local h3 = io.popen('find ' .. ROOT .. ' -name "*.toc"')
    for toc in h3:lines() do
        local v = (read(toc) or ""):match("## Version:%s*([^\r\n]+)")
        if v ~= "2.0.0" then fail(toc .. " version " .. tostring(v)) end
    end
    h3:close()
    local opts = read(ROOT .. "/AzerothRoute_Options/UI/Options.lua") or ""
    if opts:find('key = "thanks"', 1, true) then fail("Options still has the thanks page") end
    if opts:find('key = "recorder"', 1, true) then fail("Options still has the Recorder page") end
    if opts:find("Cinzel", 1, true) then fail("Options credits Polestar's wordmark font") end
    if (read(ROOT .. "/AzerothRoute/Core/Commands.lua") or ""):find('RegisterCommand("discord"', 1, true) then fail("/ar discord still registered") end
    local wn = read(ROOT .. "/AzerothRoute/UI/WhatsNew.lua") or ""
    if wn:find('version = "0.', 1, true) then fail("What's new still lists Polestar's releases") end
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
