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
        local origSteer = AR.Journey.GetSteering
        AR.Journey.GetSteering = function() return nil end
        local ok, err = pcall(function()
            AR.Pointer:SetManualTarget(1436, 0.5, 0.5, "Here")
            T:AssertEqual(AR.Pointer.manualTarget, nil, "Arrival clears the manual target")
        end)
        AR.Coords.GetDistanceTo = origDist
        AR.Journey.GetSteering = origSteer
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

T:Describe("Rares", function()
    T:It("finds rares in Lookup and the nearest one in the map menu", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Nearby:Reset()
        AR.Lookup:SetQuery("Thuros")
        local rares = AR.Lookup:Results().rare
        T:AssertTrue(#rares >= 1 and rares[1].id == 61, "Thuros Lightfingers is a rare")
        AR.Lookup:SetQuery("Guard Thomas")
        T:AssertEqual(#AR.Lookup:Results().rare, 0, "Ordinary NPCs are not rares")
        local C = AR.Coords
        local savedPos, savedDist, savedSteer = C.GetPlayerPosition, C.GetDistanceTo, AR.Journey.GetSteering
        C.GetPlayerPosition = function() return 1429, 0.50, 0.80 end
        C.GetDistanceTo = function(_, map, x, y)
            if map ~= 1429 then return nil end
            return math.sqrt(((x - 0.5) * 1000) ^ 2 + ((y - 0.8) * 1000) ^ 2)
        end
        AR.Journey.GetSteering = function() return nil end
        local ok, err = pcall(function()
            local rec = AR.Nearby:FindNearest("x")
            T:AssertEqual(rec.name, "Thuros Lightfingers", "Nearest rare in Elwynn")
            AR.ViewerFrame:RefreshVisuals()
            local items = AR.ViewerFrame:BuildMapMenuItems()
            local found = false
            for _, it in ipairs(items) do
                if it.text and it.text:find(AR.L:Get("UI_SV_RARE") .. ": Thuros Lightfingers", 1, true) then found = true end
            end
            T:AssertTrue(found, "Map menu names the rare")
        end)
        C.GetPlayerPosition, C.GetDistanceTo, AR.Journey.GetSteering = savedPos, savedDist, savedSteer
        AR.Lookup:SetQuery("")
        AR.Nearby:Reset()
        if not ok then error(err, 0) end
    end)
end)

T:Describe("Quest-starting loot", function()
    T:It("puts a quest-starting item on the item bar with a glow until the quest is taken", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.QuestLoot:Reset()
        MockWoW.player.level = 10
        MockWoW.player.faction = "Alliance"
        MockWoW.player.bagSlots[0] = { { itemID = 1307, count = 1 } } -- starts "The Collector" (123)
        local g = AR.Parser:ParseGuide("LootGuide", "step One\n    talk Devrak##3615\n")
        AR.Progression:LoadGuide(g, 1)
        AR.QuestTracking:ScanQuestLog()
        local items = AR.QuestLoot:GetStartItems()
        T:AssertEqual(#items, 1)
        T:AssertEqual(items[1].questID, 123)
        AR.ActionBar:UpdateFromCurrentStep()
        local btn = AR.ActionBar.itemButtons[1]
        T:AssertTrue(btn:IsShown(), "On the item bar")
        T:AssertEqual(btn.itemID, 1307)
        T:AssertTrue(btn.glow ~= nil and btn.glow:IsShown(), "Glowing")
        T:AssertEqual(btn.questStart, items[1].quest, "Tooltip knows the quest")
        -- Taking the quest removes it from the bar.
        MockWoW.quests.inLog[123] = { title = "The Collector", isComplete = false, objectives = {} }
        AR.QuestTracking:ScanQuestLog()
        T:AssertEqual(#AR.QuestLoot:GetStartItems(), 0, "Quest in the log")
        AR.ActionBar:UpdateFromCurrentStep()
        T:AssertFalse(AR.ActionBar.itemButtons[1]:IsShown(), "Gone from the bar")
        -- Too low or the other faction: not offered.
        MockWoW.quests.inLog[123] = nil
        AR.QuestTracking:ScanQuestLog()
        MockWoW.player.level = 5
        T:AssertEqual(#AR.QuestLoot:GetStartItems(), 0, "Below the quest's minimum level")
        MockWoW.player.level, MockWoW.player.faction = 10, "Horde"
        T:AssertEqual(#AR.QuestLoot:GetStartItems(), 0, "Alliance-only quest")
        MockWoW.player.bagSlots[0] = nil
    end)
end)
