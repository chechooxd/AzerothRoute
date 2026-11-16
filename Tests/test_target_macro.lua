-- RXP-style account macro "ARTargeting": rebuilt out of combat from the current step's NPC/enemy targets.
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

local GUIDE = [[
step HubSetup
    goto 1413 51.5,30.4
    talk Devrak##3615
    kill Plainstrider##3244
    fpath Crossroads
]]

local EMPTY_GUIDE = [[
step Travel
    goto 1413 51.5,30.4
    fpath Crossroads
]]

-- Minimal account-macro API with call recording.
local function installMacroApi(state)
    local saved = {}
    for _, n in ipairs({ "GetMacroInfo", "CreateMacro", "EditMacro", "GetNumMacros", "InCombatLockdown" }) do
        saved[n] = _G[n]
    end
    _G.GetMacroInfo = function(name)
        local m = state.macros[name]
        if m then return name, m.icon, m.body end
    end
    _G.CreateMacro = function(name, icon, body)
        state.created = state.created + 1
        state.macros[name] = { icon = icon, body = body }
        return 1
    end
    _G.EditMacro = function(name, newName, icon, body)
        state.edits = state.edits + 1
        state.macros[newName or name].body = body
        return 1
    end
    _G.GetNumMacros = function() return state.count, 0 end
    _G.InCombatLockdown = function() return state.combat end
    return function()
        for n, f in pairs(saved) do _G[n] = f end
    end
end

local function newState()
    return { macros = {}, created = 0, edits = 0, count = 3, combat = false }
end

local function load(AR, text)
    AR.Progression:LoadGuide(AR.Parser:ParseGuide("Test_Macro", text))
end

T:Describe("ARTargeting account macro", function()
    T:It("creates the macro with exact-target lines for the step's NPCs and enemies", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local state = newState()
        local restore = installMacroApi(state)
        local ok, err = pcall(function()
            AR.Storage:Initialize()
            AR.TargetMacro:Reset()
            load(AR, GUIDE)
            T:AssertEqual(AR.TargetMacro:Update(), true, "Updated out of combat")
            local m = state.macros[AR.TargetMacro.NAME]
            T:AssertTrue(m ~= nil, "Macro created")
            T:AssertEqual(state.created, 1, "Created once")
            T:AssertTrue(m.body:find("/targetexact Devrak", 1, true) ~= nil, "Friendly NPC line: " .. m.body)
            T:AssertTrue(m.body:find("/targetexact Plainstrider", 1, true) ~= nil, "Enemy line: " .. m.body)
            T:AssertTrue(m.body:find("Devrak", 1, true) < m.body:find("Plainstrider", 1, true),
                "Enemies come last so a nearby enemy wins the target")
            T:AssertTrue(m.body:find("/tm [harm,nodead] !8", 1, true) ~= nil, "Skull on enemies without toggling (Forever)")
            T:AssertTrue(m.body:find("/tm [help,nodead] 1", 1, true) ~= nil, "Star on friendly NPCs")
            T:AssertTrue(#m.body <= 255, "Fits the macro size limit")

            T:AssertEqual(AR.TargetMacro:Update(), true)
            T:AssertEqual(state.edits, 0, "Unchanged content is not rewritten")
        end)
        restore()
        if not ok then error(err, 0) end
    end)

    T:It("defers the update during combat and applies it when combat ends", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local state = newState()
        local restore = installMacroApi(state)
        local ok, err = pcall(function()
            AR.Storage:Initialize()
            AR.TargetMacro:Reset()
            load(AR, GUIDE)
            state.combat = true
            T:AssertEqual(AR.TargetMacro:Update(), false, "Not touched in combat")
            T:AssertEqual(state.created, 0, "No macro API calls in combat")
            T:AssertTrue(AR.TargetMacro.pending, "Marked pending")
            state.combat = false
            AR.TargetMacro:OnCombatEnd()
            T:AssertTrue(state.macros[AR.TargetMacro.NAME] ~= nil, "Applied after combat")
            T:AssertTrue(not AR.TargetMacro.pending, "Pending cleared")
        end)
        restore()
        if not ok then error(err, 0) end
    end)

    T:It("writes a comment when the step has no targets and never creates past the macro limit", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local state = newState()
        local restore = installMacroApi(state)
        local ok, err = pcall(function()
            AR.Storage:Initialize()
            AR.TargetMacro:Reset()
            load(AR, EMPTY_GUIDE)
            AR.TargetMacro:Update()
            local body = state.macros[AR.TargetMacro.NAME].body
            T:AssertTrue(body:sub(1, 2) == "//", "Comment-only macro when nothing to target: " .. body)

            local full = newState()
            full.count = 120
            restore()
            restore = installMacroApi(full)
            AR.TargetMacro:Reset()
            load(AR, GUIDE)
            T:AssertEqual(AR.TargetMacro:Update(), false, "Account macro slots full")
            T:AssertEqual(full.created, 0, "Never creates past the limit")
        end)
        restore()
        if not ok then error(err, 0) end
    end)

    T:It("trims the oldest lines to stay within 255 characters", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local state = newState()
        local restore = installMacroApi(state)
        local ok, err = pcall(function()
            AR.Storage:Initialize()
            AR.TargetMacro:Reset()
            local lines = { "step Many" }
            for i = 1, 20 do
                table.insert(lines, string.format("    kill Very Long Enemy Name Number %02d##%d", i, 1000 + i))
            end
            load(AR, table.concat(lines, "\n"))
            AR.TargetMacro:Update()
            local body = state.macros[AR.TargetMacro.NAME].body
            T:AssertTrue(#body <= 255, "Within limit, got " .. #body)
            T:AssertTrue(body:find("Number 20", 1, true) ~= nil, "Keeps the last (highest priority) target")
            T:AssertTrue(body:find("/tm [harm,nodead] !8", 1, true) ~= nil, "Marker line kept")
        end)
        restore()
        if not ok then error(err, 0) end
    end)

    T:It("is rebuilt whenever the action bar refreshes and can be disabled", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        local state = newState()
        local restore = installMacroApi(state)
        local ok, err = pcall(function()
            AR.Storage:Initialize()
            AR.TargetMacro:Reset()
            load(AR, GUIDE)
            AR.ActionBar:UpdateFromCurrentStep()
            T:AssertTrue(state.macros[AR.TargetMacro.NAME] ~= nil, "Action bar refresh builds the macro")

            local s2 = newState()
            restore()
            restore = installMacroApi(s2)
            AR.TargetMacro:Reset()
            AR.db.global.targetmacro = false
            AR.ActionBar:UpdateFromCurrentStep()
            T:AssertEqual(s2.created, 0, "Disabled setting leaves macros alone")
        end)
        AR.db.global.targetmacro = true
        restore()
        if not ok then error(err, 0) end
    end)
end)
