-- AzerothRoute: Guide DSL Compiler (SPEC-02)
-- Supports #include templates, leechsteps, guide headers, step directives, pipe goal chunks, and static |only pruning.

local AR = _G.AzerothRoute
local Parser = {
    includes = {},
    guidesByTitle = {},
}
AR.Parser = Parser

function Parser:Reset()
    self.includes = {}
    self.guidesByTitle = {}
end

local function trim(s)
    return (s and s:match("^%s*(.-)%s*$")) or ""
end

function Parser:RegisterInclude(name, bodyText)
    self.includes[name] = bodyText
end

function Parser:ExpandIncludes(rawText)
    local out = {}
    for line in (rawText .. "\n"):gmatch("(.-)\r?\n") do
        local trimmed = trim(line)
        local incName, rest = trimmed:match('^#include%s+"([^"]+)"(.*)$')
        if incName then
            local tpl = self.includes[incName]
            if not tpl then
                error("Missing #include template: " .. tostring(incName))
            end
            local params = {}
            for k, v in (rest or ""):gmatch('([%w_]+)="([^"]*)"') do
                params[k] = v
            end
            local expanded = tpl:gsub("%%([%w_]+)%%", function(key)
                return params[key] or ""
            end)
            table.insert(out, self:ExpandIncludes(expanded))
        else
            table.insert(out, line)
        end
    end
    return table.concat(out, "\n")
end

local function parseTargetAndId(argText)
    argText = trim(argText)
    local name, idStr = argText:match("^(.-)##([%d/]+)$")
    if name then
        local id, sub = idStr:match("^(%d+)/?(%d*)$")
        return trim(name), tonumber(id), tonumber(sub)
    end
    return argText, nil, nil
end

local function parseGotoArg(arg, fallbackMap)
    arg = trim(arg or "")
    local distOverride = nil
    local mainPart, dVal = arg:match("^(.-)%s*<%s*([%d%.]+)%s*$")
    if mainPart then
        arg = trim(mainPart)
        distOverride = tonumber(dVal)
    end

    -- Try numeric mapID or zone name before "x,y [dist]"
    local mapToken, xStr, yStr, tailDist = arg:match("^(.-)%s+([%d%.]+)%s*,%s*([%d%.]+)%s*([%d%.]*)$")
    local mapID = fallbackMap
    if mapToken and xStr and yStr then
        local resolved = (AR.Coords and AR.Coords:ResolveMapID(mapToken)) or tonumber(mapToken)
        if resolved then
            mapID = resolved
        end
    else
        xStr, yStr, tailDist = arg:match("^([%d%.]+)%s*,%s*([%d%.]+)%s*([%d%.]*)$")
    end

    local rx = tonumber(xStr)
    local ry = tonumber(yStr)
    if rx and rx > 1 then rx = rx / 100.0 end
    if ry and ry > 1 then ry = ry / 100.0 end
    local dist = distOverride or tonumber(tailDist) or 8
    return mapID, rx, ry, dist
end

function Parser:ParseGoalLine(line, step)
    local chunks = {}
    for chunk in (line .. "|"):gmatch("(.-)|") do
        local c = trim(chunk)
        if c ~= "" then
            table.insert(chunks, c)
        end
    end
    if #chunks == 0 then return nil end

    -- Step-level condition if line begins with "|only" or "only"
    if #chunks == 1 then
        local onlyIfExpr = chunks[1]:match("^only%s+if%s+(.+)$") or chunks[1]:match("^if%s+(.+)$")
        if onlyIfExpr then
            step.condition_visible = AR.ConditionEnv:Compile(onlyIfExpr)
            return nil
        end
        local onlyStatic = chunks[1]:match("^only%s+(.+)$")
        if onlyStatic then
            step.requirement = onlyStatic
            return nil
        end
    end

    local goal = AR.Goal and AR.Goal:New({ parentStep = step }) or { parentStep = step }
    for idx, chunk in ipairs(chunks) do
        local cmd, arg = chunk:match("^(%S+)%s*(.-)$")
        cmd = cmd or chunk
        arg = trim(arg or "")

        if idx == 1 then
            if cmd:sub(1, 1) == "'" then
                goal.action = "text"
                goal.text = trim(chunk:sub(2))
            elseif cmd == "goto" or cmd == "at" then
                goal.action = "goto"
                local mapID, rx, ry, dist = parseGotoArg(arg, step.map)
                goal.map = mapID
                goal.x = rx
                goal.y = ry
                goal.dist = dist
            elseif cmd == "accept" or cmd == "turnin" then
                goal.action = cmd
                local name, qid = parseTargetAndId(arg)
                goal.quest = name
                goal.questid = qid
            elseif cmd == "kill" or cmd == "from" or cmd == "get" or cmd == "collect" or cmd == "buy" then
                goal.action = (cmd == "collect") and "get" or cmd
                local countPrefix, rest = arg:match("^(%d+)%s+(.+)$")
                if countPrefix then
                    goal.count = tonumber(countPrefix)
                    arg = rest
                end
                local name, tid = parseTargetAndId(arg)
                goal.target = name
                goal.targetid = tid
            elseif cmd == "talk" or cmd == "vendor" or cmd == "trainer" then
                goal.action = cmd
                local name, npcid = parseTargetAndId(arg)
                goal.target = name
                goal.npcid = npcid
            elseif cmd == "click" or cmd == "use" then
                goal.action = cmd
                local name, tid = parseTargetAndId(arg)
                goal.target = name
                goal.targetid = tid
            elseif cmd == "learn" or cmd == "learnspell" then
                goal.action = "learn"
                local name, spellid = parseTargetAndId(arg)
                goal.target = name
                goal.spellid = spellid
            elseif cmd == "create" or cmd == "craft" then
                goal.action = "create"
                local countPrefix, rest = arg:match("^(%d+)%s+(.+)$")
                if countPrefix then
                    goal.count = tonumber(countPrefix)
                    arg = rest
                end
                local name, recipeid = parseTargetAndId(arg)
                goal.target = name
                goal.recipeid = recipeid
            elseif cmd == "ding" then
                goal.action = "ding"
                goal.level = tonumber(arg)
            elseif cmd == "fpath" or cmd == "home" or cmd == "hearth" or cmd == "fly" then
                goal.action = cmd
                goal.param = arg
            elseif cmd == "tip" then
                if step and step.goals and #step.goals > 0 then
                    local prev = step.goals[#step.goals]
                    prev.tooltip = prev.tooltip and (prev.tooltip .. " " .. arg) or arg
                    return nil
                end
                goal.action = "tip"
                goal.text = arg
            else
                goal.action = cmd
                goal.param = arg
            end
        else
            -- Modifier flags after "|"
            if cmd == "q" or cmd == "quest" then
                local qid, obj = arg:match("^(%d+)/?(%d*)$")
                goal.questid = tonumber(qid)
                goal.objnum = tonumber(obj)
            elseif cmd == "count" then
                goal.count = tonumber(arg)
            elseif cmd == "only" then
                local condExpr = arg:match("^if%s+(.+)$")
                if condExpr then
                    goal.condition_visible = AR.ConditionEnv:Compile(condExpr)
                else
                    -- Compile-time static Race/Class pruning!
                    if not AR.ConditionEnv:RaceClassMatch(arg) then
                        return nil
                    end
                    goal.requirement = arg
                end
            elseif cmd == "if" then
                goal.condition_visible = AR.ConditionEnv:Compile(arg)
            elseif cmd == "complete" then
                goal.condition_complete = AR.ConditionEnv:Compile(arg)
            elseif cmd == "n" then
                goal.force_nocomplete = true
            elseif cmd == "c" then
                goal.force_complete = true
            elseif cmd == "h" or cmd == "hide" then
                goal.hidewhencomplete = true
            elseif cmd == "opt" or cmd == "optional" then
                goal.optional = true
            elseif cmd == "override" then
                goal.override = true
            elseif cmd == "future" then
                goal.future = true
            elseif cmd == "sticky" then
                goal.force_sticky = true
                if arg == "saved" then
                    goal.force_sticky_saved = true
                end
            elseif cmd == "or" then
                goal.orlogic = tonumber(arg) or 1
            elseif cmd == "confirm" then
                goal.action = goal.action or "confirm"
                goal.confirm = true
            elseif cmd == "next" then
                goal.next = arg:gsub('^"', ''):gsub('"$', '')
            elseif cmd == "tip" then
                goal.tooltip = arg
            elseif cmd == "noautoaccept" then
                goal.noautoaccept = true
            elseif cmd == "goto" or cmd == "at" then
                local mapID, rx, ry, dist = parseGotoArg(arg, goal.map or step.map)
                goal.map = mapID
                goal.x = rx
                goal.y = ry
                goal.dist = dist
            end
        end
    end

    return goal
end

function Parser:ParseGuide(title, rawText)
    local expanded = self:ExpandIncludes(rawText or "")
    local guide = AR.Guide and AR.Guide:New({ title = title, steps = {}, stepsByLabel = {} }) or {
        title = title,
        steps = {},
        stepsByLabel = {},
    }

    local currentStep = nil
    local activeStickyBlock = false

    for rawLine in (expanded .. "\n"):gmatch("(.-)\r?\n") do
        local line = trim(rawLine:gsub("//.*$", ""))
        if line ~= "" then
            local cmd, arg = line:match("^(%S+)%s*(.-)$")
            cmd = cmd or line
            arg = trim(arg or "")

            if cmd == "step" then
                currentStep = AR.Step and AR.Step:New({
                    num = #guide.steps + 1,
                    parentGuide = guide,
                    goals = {},
                    is_sticky = activeStickyBlock,
                }) or {
                    num = #guide.steps + 1,
                    parentGuide = guide,
                    goals = {},
                    is_sticky = activeStickyBlock,
                }
                if arg ~= "" then
                    currentStep.label = arg:gsub('^"', ''):gsub('"$', '')
                    guide.stepsByLabel[currentStep.label] = currentStep
                end
                table.insert(guide.steps, currentStep)
            elseif cmd == "stickystart" then
                activeStickyBlock = true
            elseif cmd == "stickystop" then
                activeStickyBlock = false
            elseif not currentStep then
                -- Guide header directives
                if cmd == "author" or cmd == "description" or cmd == "type" or cmd == "next" or cmd == "defaultfor" then
                    guide[cmd] = arg
                elseif cmd == "startlevel" or cmd == "endlevel" then
                    guide[cmd] = tonumber(arg)
                elseif cmd == "condition_suggested" or cmd == "condition_valid" or cmd == "condition_end" then
                    guide[cmd] = AR.ConditionEnv:Compile(arg)
                end
            else
                -- Inside a step
                if cmd == "label" then
                    currentStep.label = arg:gsub('^"', ''):gsub('"$', '')
                    guide.stepsByLabel[currentStep.label] = currentStep
                elseif cmd == "title" then
                    currentStep.title = arg
                elseif cmd == "map" then
                    currentStep.map = tonumber(arg)
                elseif cmd == "sticky" then
                    currentStep.is_sticky = true
                elseif cmd == "leechsteps" then
                    local srcGuideTitle = arg:match('^"([^"]+)"')
                    local srcGuide = self.guidesByTitle[srcGuideTitle]
                    if srcGuide then
                        for _, s in ipairs(srcGuide.steps) do
                            table.insert(guide.steps, s)
                        end
                    end
                else
                    local goal = self:ParseGoalLine(line, currentStep)
                    if goal then
                        goal.num = #currentStep.goals + 1
                        table.insert(currentStep.goals, goal)
                    end
                end
            end
        end
    end

    self.guidesByTitle[title] = guide
    return guide
end

return Parser
