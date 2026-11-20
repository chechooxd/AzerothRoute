-- AzerothRoute guide audit.
-- Checks every accept / turn-in in the built-in guides against the quest database:
--   * the quest exists and belongs to the guide's faction;
--   * the place the guide sends the player to (the goal's own |goto, else the step's goto)
--     is where the quest giver / receiver actually stands (within TOLERANCE map percent).
-- Usage (repository root): luajit tools/audit_guides.lua [--fix]
--   --fix rewrites wrong or missing coordinates in Guides/Autoload.lua to the NPC's position.

package.path = "./?.lua;" .. package.path
local FIX = arg and arg[1] == "--fix"
local TOLERANCE = 1.0 -- map percent (~50 yd in a zone)

local T = require("Tests.run_tests")
T:BootstrapAddon()
local AR = _G.AzerothRoute
local DB = AR.DB

local function npcAt(refs)
    for _, r in ipairs(refs or {}) do
        if r.kind == "U" then
            local u = DB:GetUnit(r.id)
            if u and u.map > 0 then return u end
        end
    end
    return nil
end

local function guideSide(title)
    if title:find("Horde", 1, true) then return "H" end
    if title:find("Alliance", 1, true) then return "A" end
    return nil
end

local issues, fixes, checked = {}, {}, 0
local seenIssue, seenGoal = {}, {}
local titles = {}

-- Guides drop race/class-only lines when they are parsed, so every race and class is audited.
local RACES = { "Human", "Dwarf", "NightElf", "Gnome", "Orc", "Scourge", "Tauren", "Troll" }
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local HORDE = { Orc = true, Scourge = true, Tauren = true, Troll = true }

local function audit()
for title in pairs(AR.Parser.guidesByTitle) do
    if not seenGoal["title:" .. title] then
        seenGoal["title:" .. title] = true
        titles[#titles + 1] = title
    end
end
for _, title in pairs((function() local t = {} for k in pairs(AR.Parser.guidesByTitle) do t[#t + 1] = k end table.sort(t) return t end)()) do
    local guide = AR.Parser.guidesByTitle[title]
    local side = guideSide(title)
    for _, step in ipairs(guide.steps or {}) do
        local stepGoto
        for _, g in ipairs(step.goals or {}) do
            if g.action == "goto" and g.map then stepGoto = g end
            if g.action == "talk" and g.npcid then
                local npc = DB:GetUnit(g.npcid)
                local at = (g.map and g.x) and g or stepGoto
                if npc and npc.map > 0 then
                    local key = title .. "|talk|" .. g.npcid .. "|" .. step.num
                    if not seenGoal[key] then seenGoal[key] = true checked = checked + 1 end
                    local off
                    if not at then
                        off = "no coordinates"
                    elseif at.map ~= npc.map then
                        off = string.format("guide map %s, NPC map %s", tostring(at.map), tostring(npc.map))
                    else
                        local gx = (at.x <= 1) and at.x * 100 or at.x
                        local gy = (at.y <= 1) and at.y * 100 or at.y
                        local d = math.sqrt((gx - npc.x) ^ 2 + (gy - npc.y) ^ 2)
                        if d > TOLERANCE then off = string.format("%.1f%% away", d) end
                    end
                    if off then
                        local line = string.format("%s · step %d · talk %s##%d · NPC at %s %.1f,%.1f · guide %s",
                            title, step.num, npc.name, g.npcid, npc.map, npc.x, npc.y, off)
                        if not seenIssue[line] then
                            seenIssue[line] = true
                            issues[#issues + 1] = line
                            fixes[#fixes + 1] = { npcid = g.npcid, action = "talk", npc = npc, title = title }
                        end
                    end
                end
            end
            if (g.action == "accept" or g.action == "turnin") and g.questid then
                local goalKey = title .. "|" .. g.action .. "|" .. g.questid .. "|" .. step.num
                if not seenGoal[goalKey] then seenGoal[goalKey] = true checked = checked + 1 end
                local q = DB:GetQuest(g.questid)
                local where = string.format("%s · step %d · %s %s##%d", title, step.num, g.action, tostring(g.quest), g.questid)
                if not q then
                    if not seenIssue[where] then seenIssue[where] = true issues[#issues + 1] = where .. " · quest not in database" end
                else
                    if side and q.side ~= "B" and q.side ~= side then
                        local line = where .. " · quest is for the other faction (" .. q.side .. ")"
                        if not seenIssue[line] then seenIssue[line] = true issues[#issues + 1] = line end
                    end
                    local npc = npcAt(g.action == "accept" and q.starts or q.ends)
                    local at = (g.map and g.x) and g or stepGoto
                    if npc then
                        local gx = at and ((at.x <= 1) and at.x * 100 or at.x)
                        local gy = at and ((at.y <= 1) and at.y * 100 or at.y)
                        local off
                        if not at then
                            off = "no coordinates"
                        elseif at.map ~= npc.map then
                            off = string.format("guide map %s, NPC map %s", tostring(at.map), tostring(npc.map))
                        else
                            local d = math.sqrt((gx - npc.x) ^ 2 + (gy - npc.y) ^ 2)
                            if d > TOLERANCE then off = string.format("%.1f%% away", d) end
                        end
                        if off then
                            local line = string.format("%s · %s at %s %.1f,%.1f · guide %s", where, npc.name, npc.map, npc.x, npc.y, off)
                            if not seenIssue[line] then
                                seenIssue[line] = true
                                issues[#issues + 1] = line
                                fixes[#fixes + 1] = { questid = g.questid, action = g.action, npc = npc, title = title }
                            end
                        end
                    end
                end
            end
        end
    end
end
end

for _, race in ipairs(RACES) do
    for _, class in ipairs(CLASSES) do
        MockWoW.player.race, MockWoW.player.class = race, class
        MockWoW.player.faction = HORDE[race] and "Horde" or "Alliance"
        AR.Parser.guidesByTitle = {}
        AR.GuidesCatalog:LoadAll()
        audit()
    end
end

print(string.format("Checked %d accept/turn-in goals in %d guides: %d issues", checked, #titles, #issues))
for _, line in ipairs(issues) do print("  " .. line) end

if FIX and #fixes > 0 then
    -- Rewrite the goal lines in Guides/Autoload.lua: "<action> <name>##<id>" gets the NPC's |goto.
    local f = assert(io.open("Guides/Autoload.lua", "rb"))
    local src = f:read("*a")
    f:close()
    local zoneName = {}
    local n = 0
    for _, fx in ipairs(fixes) do
        local mapName = zoneName[fx.npc.map]
        if not mapName then
            mapName = tostring(fx.npc.map)
            zoneName[fx.npc.map] = mapName
        end
        local coord = string.format("|goto %s %.1f,%.1f", mapName, fx.npc.x, fx.npc.y)
        -- Matches the goal line with or without an existing |goto ... (up to the end of the line).
        local id = fx.questid or fx.npcid
        local pattern = "(" .. fx.action .. " [^\n|]-##" .. id .. ")([^\n%d][^\n]*)"
        local plain = "(" .. fx.action .. " [^\n|]-##" .. id .. ")(\n)"
        src = src:gsub(pattern, function(head, rest)
            local cleaned = rest:gsub("%s*|goto [^|]*", "")
            n = n + 1
            return head .. " " .. coord .. cleaned
        end)
        src = src:gsub(plain, function(head, nl)
            n = n + 1
            return head .. " " .. coord .. nl
        end)
    end
    f = assert(io.open("Guides/Autoload.lua", "wb"))
    f:write(src)
    f:close()
    print(string.format("Rewrote %d goal lines.", n))
end
