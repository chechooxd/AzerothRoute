-- The Target button: the addon's own secure button, set out of combat from the current step's targets.
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

-- Account-macro API that records every call, to prove the button leaves macros alone.
local function installMacroApi(state)
    local saved = {}
    for _, n in ipairs({ "GetMacroInfo", "CreateMacro", "EditMacro", "GetNumMacros" }) do
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
    _G.GetNumMacros = function() return 3, 0 end
    return function()
        for n, f in pairs(saved) do _G[n] = f end
        MockWoW.inCombat = false
    end
end

local function newState()
    return { macros = {}, created = 0, edits = 0 }
end

local function load(AR, text)
    AR.Progression:LoadGuide(AR.Parser:ParseGuide("Test_Macro", text))
end

local function run(fn)
    MockWoW:Reset()
    local AR = _G.AzerothRoute
    local state = newState()
    local restore = installMacroApi(state)
    local ok, err = pcall(function()
        AR.Storage:Initialize()
        AR.TargetMacro:Reset()
        fn(AR, state)
    end)
    restore()
    if not ok then error(err, 0) end
end

T:Describe("Target button", function()
    T:It("targets the step's enemies first, then its NPCs, from its own secure button", function()
        run(function(AR, state)
            load(AR, GUIDE)
            T:AssertEqual(AR.TargetMacro:Update(), true, "Updated out of combat")
            local b = _G[AR.TargetMacro.BUTTON_NAME]
            T:AssertTrue(b ~= nil and b == AR.TargetMacro.button, "Named secure button")
            T:AssertEqual(b._template, "SecureActionButtonTemplate")
            T:AssertEqual(b:GetAttribute("type"), "macro")
            local body = b:GetAttribute("macrotext")
            T:AssertTrue(body:find("^/cleartarget %[nocombat%]\n/targetexact Plainstrider\n/cleartarget %[dead%]\n") ~= nil,
                "Enemy first from no target: " .. body)
            T:AssertTrue(body:find("/targetexact [noexists] Devrak", 1, true) ~= nil, "NPC only while nothing is targeted")
            T:AssertTrue(body:find("/tm [harm,nodead] !8", 1, true) ~= nil, "Skull on enemies without toggling (Forever)")
            T:AssertTrue(body:find("/tm [help,nodead] 1", 1, true) ~= nil, "Star on friendly NPCs")
            T:AssertTrue(b:IsShown(), "Shown while there is something to target")
            T:AssertEqual(b.nameText:GetText(), "Plainstrider", "Names the next target")
            T:AssertEqual(state.created + state.edits, 0, "No account macro is created or edited")
        end)
    end)

    T:It("waits out combat before touching the button and applies the change after it", function()
        run(function(AR)
            load(AR, EMPTY_GUIDE)
            AR.TargetMacro:Update()
            load(AR, GUIDE)
            MockWoW.inCombat = true
            T:AssertEqual(AR.TargetMacro:Update(), false, "Deferred in combat (no blocked attribute change)")
            T:AssertTrue(AR.TargetMacro.pending, "Marked pending")
            T:AssertTrue(AR.TargetMacro.button:GetAttribute("macrotext") == nil, "Untouched in combat")
            MockWoW.inCombat = false
            AR.TargetMacro:OnCombatEnd()
            T:AssertTrue(AR.TargetMacro.button:GetAttribute("macrotext") ~= nil, "Applied after combat")
            T:AssertTrue(not AR.TargetMacro.pending, "Pending cleared")
        end)
    end)

    T:It("hides with nothing to target and when turned off", function()
        run(function(AR)
            load(AR, EMPTY_GUIDE)
            AR.TargetMacro:Update()
            local b = AR.TargetMacro.button
            T:AssertTrue(not b:IsShown(), "Hidden on a step with no targets")
            T:AssertTrue(b:GetAttribute("macrotext") == nil and b:GetAttribute("type") == nil, "Does nothing when pressed")

            load(AR, GUIDE)
            AR.db.profile.targetmacro = false
            AR.ActionBar:UpdateFromCurrentStep()
            T:AssertTrue(not b:IsShown(), "Hidden when the setting is off")
            AR.db.profile.targetmacro = true
            AR.ActionBar:UpdateFromCurrentStep()
            T:AssertTrue(b:IsShown(), "Action bar refresh brings it back")
        end)
    end)

    T:It("drops the lowest-priority names to stay within the macro text limit", function()
        run(function(AR)
            local lines = { "step Many", "    talk Somebody##3615" }
            for i = 1, 40 do
                table.insert(lines, string.format("    kill Very Long Enemy Name Number %02d##%d", i, 1000 + i))
            end
            load(AR, table.concat(lines, "\n"))
            AR.TargetMacro:Update()
            local body = AR.TargetMacro.button:GetAttribute("macrotext")
            T:AssertTrue(#body <= AR.TargetMacro.MAX_BODY, "Within limit, got " .. #body)
            T:AssertTrue(body:find("Number 01", 1, true) ~= nil, "Keeps the first (highest priority) target")
            T:AssertTrue(body:find("Somebody", 1, true) == nil, "NPC after the enemies is the first to go")
            T:AssertTrue(body:find("/tm [harm,nodead] !8", 1, true) ~= nil, "Marker line kept")
        end)
    end)

    T:It("rewrites the old ARTargeting macro once to a note and never edits it again", function()
        run(function(AR, state)
            state.macros.ARTargeting = { icon = 1, body = "/targetexact Old" }
            load(AR, GUIDE)
            AR.TargetMacro:Update()
            T:AssertEqual(state.edits, 1, "Rewritten once")
            T:AssertTrue(state.macros.ARTargeting.body:sub(1, 2) == "//", "Now a note: " .. state.macros.ARTargeting.body)
            load(AR, EMPTY_GUIDE)
            AR.TargetMacro:Update()
            load(AR, GUIDE)
            AR.TargetMacro:Update()
            T:AssertEqual(state.edits, 1, "Step changes never edit a macro")
            T:AssertEqual(state.created, 0, "Never creates one")
        end)
    end)
end)
