-- Lookup and Dungeons: generated database (DB/*.lua) and their Guide Center panels.
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

local function withMaps(fn)
    local orig = _G.C_Map.GetMapInfo
    _G.C_Map.GetMapInfo = function(id)
        local names = { [1436] = "Westfall", [1413] = "The Barrens", [1453] = "Stormwind City" }
        return names[id] and { name = names[id] } or nil
    end
    local ok, err = pcall(fn)
    _G.C_Map.GetMapInfo = orig
    if not ok then error(err, 0) end
end

T:Describe("Database", function()
    T:It("decodes quests, NPCs and items from the generated tables", function()
        MockWoW:Reset()
        local DB = _G.AzerothRoute.DB
        local q = DB:GetQuest(166)
        T:AssertEqual(q.name, "The Defias Brotherhood")
        T:AssertEqual(q.level, 22)
        T:AssertEqual(q.starts[1].kind, "U")
        T:AssertEqual(q.starts[1].id, 234)
        local u = DB:GetUnit(234)
        T:AssertEqual(u.name, "Gryan Stoutmantle")
        T:AssertEqual(u.map, 1436)
        local loc = DB:LocationOf(q)
        T:AssertEqual(loc.map, 1436, "Quest location is its giver")
        T:AssertTrue(math.abs(loc.x - 0.563) < 1e-9, "Coordinates scaled to 0..1")
        local mount = DB:GetItem(18786)
        T:AssertEqual(mount.kind, "mount")
        T:AssertEqual(mount.vendors[1], 1261, "Sold by its vendor")
        T:AssertEqual(DB:GetItem(2598).kind, "recipe")
    end)

    T:It("searches every table, prefix matches first", function()
        MockWoW:Reset()
        local DB = _G.AzerothRoute.DB
        local res = DB:Search("defias brotherhood")
        T:AssertTrue(#res > 0, "Has results")
        local has166 = false
        for _, r in ipairs(res) do if r.kind == "quest" and r.id == 166 then has166 = true end end
        T:AssertTrue(has166, "The chain's quest 166 is found")
        local swift = DB:Search("swift")
        T:AssertTrue(swift[1].name:lower():find("^swift") ~= nil, "Prefix matches lead: " .. swift[1].name)
        local mounts = DB:Search("swift", { mount = true })
        T:AssertTrue(#mounts > 3, "Several swift mounts")
        for _, r in ipairs(mounts) do T:AssertEqual(r.kind, "mount") end
        T:AssertEqual(#DB:Search("x"), 0, "One letter is not searched")
    end)

    T:It("knows every classic dungeon and raid with quests attached", function()
        MockWoW:Reset()
        local DB = _G.AzerothRoute.DB
        local list = DB:GetDungeons()
        T:AssertEqual(#list, 26, "19 dungeons + 7 raids")
        local dm
        for _, d in ipairs(list) do if d.key == "DM" then dm = d end end
        local found = false
        for _, qid in ipairs(dm.quests) do if qid == 166 then found = true end end
        T:AssertTrue(found, "The Defias Brotherhood belongs to the Deadmines")
    end)
end)

T:Describe("Lookup panel", function()
    T:It("lists results by category and points the arrow at the quest giver", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        withMaps(function()
            AR.Storage:Initialize()
            AR.Pointer:Reset()
            AR.GuideMenu:Reset()
            AR.GuideMenu:Show()
            AR.GuideMenu:SetMode("lookup")
            T:AssertEqual(AR.GuideMenu.mode, "lookup")
            AR.GuideMenu:SetSearch("defias brotherhood")
            local panel = AR.Lookup.panel
            T:AssertTrue(panel.main:IsShown(), "Lookup panel shown")
            T:AssertTrue(AR.Lookup:CountCategory("quest") >= 1, "Quest bucket")
            T:AssertTrue(AR.GuideMenu.headerSub:GetText():find("defias brotherhood", 1, true) ~= nil, "Header names the query")
            panel:SelectCategory("quest")
            local row166
            for _, r in ipairs(panel.lastRows) do if r.data.id == 166 then row166 = r end end
            T:AssertTrue(row166 ~= nil, "Quest 166 listed")
            panel:SelectRow(row166)
            T:AssertEqual(panel.main.title:GetText(), "The Defias Brotherhood")
            T:AssertEqual(panel.info[1].value:GetText(), "22", "Level line")
            panel.primary:Click("LeftButton")
            T:AssertEqual(AR.Pointer.manualTarget.map, 1436, "Arrow on Westfall")
            AR.Pointer:PlaceStepPins({ { map = 1413, x = 0.5, y = 0.5 } })
            T:AssertEqual(AR.Pointer.activeTarget.map, 1436, "A guide refresh keeps the chosen place")
            AR.GuideMenu:SetMode("guides")
            T:AssertFalse(panel.main:IsShown(), "Back to the guide list")
            AR.Pointer:Reset()
            AR.GuideMenu:Reset()
        end)
    end)

    T:It("lets the arrow go back to the guide once the chosen place is reached", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Pointer:Reset()
        local origDist = AR.Coords.GetDistanceTo
        AR.Coords.GetDistanceTo = function() return 3 end
        local ok, err = pcall(function()
            AR.Pointer:SetManualTarget(1436, 0.5, 0.5, "Here")
            T:AssertEqual(AR.Pointer.manualTarget, nil, "Arrival clears the manual target")
        end)
        AR.Coords.GetDistanceTo = origDist
        AR.Pointer:Reset()
        if not ok then error(err, 0) end
    end)
end)

T:Describe("Dungeons panel", function()
    T:It("shows dungeons for your level and their quests for your faction", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        withMaps(function()
            AR.Storage:Initialize()
            MockWoW.player.level = 20
            MockWoW.player.faction = "Alliance"
            AR.GuideMenu:Reset()
            AR.GuideMenu:Show()
            AR.GuideMenu:SetMode("dungeons")
            local panel = AR.Dungeons.panel
            T:AssertTrue(panel.main:IsShown(), "Dungeons panel shown")
            local names = {}
            for _, r in ipairs(AR.Dungeons:GetRows("yours")) do names[r.data.key] = true end
            T:AssertTrue(names.DM and names.WC, "Deadmines and Wailing Caverns fit level 20")
            T:AssertFalse(names.BRD, "Blackrock Depths does not")
            T:AssertEqual(AR.Dungeons:CountCategory("raids"), 7)
            panel:SelectCategory("all")
            local dmRow
            for _, r in ipairs(panel.lastRows) do if r.data.key == "DM" then dmRow = r end end
            panel:SelectRow(dmRow)
            T:AssertEqual(panel.main.subtitle:GetText(), "Westfall")
            local listed = false
            for _, b in ipairs(panel.list) do
                if b:IsShown() and b.label:GetText():find("The Defias Brotherhood", 1, true) then listed = b end
            end
            T:AssertTrue(listed ~= false, "Quest listed")
            listed:Click("LeftButton")
            T:AssertEqual(AR.Pointer.manualTarget.map, 1436, "Arrow to the quest giver")
            AR.GuideMenu:SetSearch("dead")
            T:AssertEqual(#panel.lastRows, 1, "Search filters dungeons by name")
            AR.Pointer:Reset()
            AR.GuideMenu:Reset()
        end)
    end)
end)

T:Describe("Lookup and Dungeons entry points", function()
    T:It("opens each mode from the guide window menu and remembers it", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.GuideMenu:Reset()
        AR.ViewerFrame:RefreshVisuals()
        AR.ViewerFrame:ShowMoreMenu()
        AR.UI:FindMenuItem(AR.L:Get("UI_DUNGEONS")):Click("LeftButton")
        T:AssertEqual(AR.GuideMenu.mode, "dungeons")
        T:AssertTrue(AR.GuideMenu.frame:IsShown() and AR.Dungeons.panel.main:IsShown(), "Dungeons open")
        T:AssertEqual(AR.GuideMenu.headerText:GetText(), AR.L:Get("UI_DUNGEONS"), "Header follows the mode")
        AR.GuideMenu.frame:Hide()
        AR.GuideMenu:Show()
        T:AssertEqual(AR.GuideMenu.mode, "dungeons", "Reopening keeps the last mode")
        AR.MinimapButton:ShowMenu()
        AR.UI:FindMenuItem(AR.L:Get("UI_LOOKUP")):Click("LeftButton")
        T:AssertEqual(AR.GuideMenu.mode, "lookup")
        AR.GuideMenu:Reset()
    end)
end)
