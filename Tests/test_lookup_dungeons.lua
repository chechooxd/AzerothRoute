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

T:Describe("Rares mode", function()
    T:It("logs rare sightings, lists them and shows drops and the last sighting", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.db.global.rareSeen = {}
        AR.Rares:Reset()
        local saved = { _G.UnitGUID, _G.UnitName, _G.UnitIsDead, AR.Coords.GetPlayerPosition, AR.Print }
        local printed = {}
        _G.UnitGUID = function() return "Creature-0-1-0-1-61-0000AB" end
        _G.UnitName = function() return "Thuros Lightfingers" end
        _G.UnitIsDead = function() return false end
        AR.Coords.GetPlayerPosition = function() return 1429, 0.5, 0.83 end
        AR.Print = function(_, msg) printed[#printed + 1] = msg end
        local ok, err = pcall(function()
            local rec = AR.Rares:OnUnitSeen("nameplate1")
            T:AssertEqual(rec.count, 1, "First sighting")
            T:AssertEqual(#printed, 1, "Announced")
            AR.Rares:OnUnitSeen("target")
            T:AssertEqual(#printed, 1, "Not announced twice in a row")
            T:AssertEqual(AR.db.global.rareSeen[61].count, 1, "Same encounter, one sighting")
            _G.UnitGUID = function() return "Creature-0-1-0-1-3615-0000AC" end
            T:AssertEqual(AR.Rares:OnUnitSeen("target"), nil, "Ordinary NPCs are ignored")

            AR.GuideMenu:Reset()
            AR.GuideMenu:Show("rares")
            local panel = AR.Rares.panel
            T:AssertTrue(panel.main:IsShown(), "Rares tab open")
            T:AssertTrue(AR.Rares:CountCategory("all") > 300, "Every rare listed")
            T:AssertTrue(AR.Rares:CountCategory("zone") >= 1, "Rares of the current zone")
            panel:SelectCategory("seen")
            T:AssertEqual(#panel.lastRows, 1, "One rare seen")
            T:AssertEqual(panel.main.title:GetText(), "Thuros Lightfingers")
            local seenLine = false
            for _, r in ipairs(panel.info) do if r.key:GetText() == AR.L:Get("UI_RARES_SEEN") then seenLine = true end end
            T:AssertTrue(seenLine, "Last sighting shown")
            panel.primary:Click("LeftButton")
            T:AssertEqual(AR.Pointer.manualTarget and AR.Pointer.manualTarget.map or AR.Pointer.activeTarget.map, 1429, "Waypoint to the spawn")
        end)
        _G.UnitGUID, _G.UnitName, _G.UnitIsDead, AR.Coords.GetPlayerPosition, AR.Print = saved[1], saved[2], saved[3], saved[4], saved[5]
        AR.Pointer:Reset()
        AR.GuideMenu:Reset()
        if not ok then error(err, 0) end
    end)
end)

T:Describe("Characters mode", function()
    T:It("keeps a snapshot per character and lists them with gold, guide and rested XP", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.db.global.characters = {
            ["Altie-Realm"] = { name = "Altie", realm = "Realm", class = "MAGE", className = "Mage", level = 22,
                faction = "Alliance", money = 15000, updated = 0 },
        }
        local saved = { _G.UnitName, _G.GetRealmName, _G.GetMoney, _G.GetXPExhaustion }
        _G.UnitName = function() return "Mainie" end
        _G.GetRealmName = function() return "Realm" end
        _G.GetMoney = function() return 25000 end
        _G.GetXPExhaustion = function() return 300 end
        MockWoW.player.faction, MockWoW.player.level, MockWoW.player.maxXp = "Alliance", 30, 1000
        local ok, err = pcall(function()
            local g = AR.Parser:ParseGuide("CharGuide", "step One\n    talk Devrak##3615\n")
            AR.Progression:LoadGuide(g, 1)
            local snap = AR.Characters:Snapshot()
            T:AssertEqual(snap.level, 30)
            T:AssertEqual(snap.guide, "CharGuide")
            AR.GuideMenu:Reset()
            AR.GuideMenu:Show("characters")
            local panel = AR.Characters.panel
            T:AssertEqual(#panel.lastRows, 2, "Both characters")
            T:AssertTrue(panel.lastRows[1].tag:find(AR.L:Get("UI_CHARS_YOU"), 1, true) ~= nil, "Highest level first, marked as you")
            T:AssertTrue(AR.GuideMenu.headerSub:GetText():find("4g", 1, true) ~= nil, "Total gold of all characters")
            panel:SelectRow(panel.lastRows[1])
            local rested = false
            for _, r in ipairs(panel.info) do if r.value:GetText() == "30%" then rested = true end end
            T:AssertTrue(rested, "Rested XP shown")
            T:AssertFalse(panel.secondary:IsShown(), "The current character cannot be forgotten")
            panel:SelectRow(panel.lastRows[2])
            panel.secondary:Click("LeftButton")
            T:AssertEqual(AR.db.global.characters["Altie-Realm"], nil, "Alt forgotten")
        end)
        _G.UnitName, _G.GetRealmName, _G.GetMoney, _G.GetXPExhaustion = saved[1], saved[2], saved[3], saved[4]
        AR.GuideMenu:Reset()
        AR.db.global.characters = {}
        if not ok then error(err, 0) end
    end)
end)

T:Describe("Options mode", function()
    T:It("sets every kind of control in place and repaints the guide window", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.db.profile.accent, AR.db.profile.bgalpha, AR.db.profile.viewerscale, AR.db.profile.scheme = nil, nil, nil, nil
        AR.ViewerFrame:RefreshVisuals()
        AR.GuideMenu:Reset()
        AR.GuideMenu:Show("options")
        local panel = AR.OptionsPanel.panel
        T:AssertTrue(panel.main:IsShown(), "Options tab open")
        T:AssertEqual(#panel.lastRows, 5, "Five appearance settings")

        -- Accent: colour swatches, the chosen one ringed.
        local accent = panel:RowFor("accent")
        T:AssertTrue(accent.swatches[1]:IsShown() and accent.swatches[5]:IsShown(), "One swatch per colour")
        T:AssertTrue(not accent.dropdown:IsShown() and not accent.check:IsShown(), "Only its own control")
        T:AssertEqual(accent.value:GetText(), AR.L:Get("OPT_ACCENT_GOLD"), "Gold by default")
        accent.swatches[2]:Click("LeftButton")
        T:AssertEqual(AR.db.profile.accent, "sky", "Picked by clicking its swatch")
        local c = AR.Skins:GetProp("accent")
        T:AssertEqual(c.b, AR.OptionsPanel.ACCENTS.sky.b, "Skins use the chosen accent")
        T:AssertEqual(AR.ViewerFrame.frame.tabUnderline:GetColorTexture().b, c.b, "Guide window repainted")
        T:AssertTrue(panel:RowFor("accent").swatches[2]._selected, "Chosen swatch marked")

        -- Scheme: a drop-down list with every scheme, the current one checked.
        local scheme = panel:RowFor("scheme")
        T:AssertTrue(scheme.dropdown:IsShown(), "Drop-down")
        scheme.dropdown:Click("LeftButton")
        T:AssertTrue(AR.UI.menu:IsShown(), "List opened")
        T:AssertTrue(AR.UI:FindMenuItem(AR.L:Get("OPT_SCHEME_DUSK"))._item.checked, "Current scheme checked")
        AR.UI:FindMenuItem(AR.L:Get("OPT_SCHEME_SLATE")):Click("LeftButton")
        T:AssertEqual(AR.db.profile.scheme, "slate", "Picked from the list")
        T:AssertEqual(panel:RowFor("scheme").dropdown.label:GetText(), AR.L:Get("OPT_SCHEME_SLATE"))

        -- Opacity: a slider, snapped to its step and clamped.
        local alpha = panel:RowFor("bgalpha")
        T:AssertTrue(alpha.slider:IsShown(), "Slider")
        alpha.slider._scripts.OnValueChanged(alpha.slider, 0.7123, true)
        T:AssertEqual(AR.db.profile.bgalpha, 0.7, "Snapped to 5%")
        T:AssertEqual(AR.ViewerFrame.frame.bg:GetColorTexture().a, 0.7, "Background opacity applied")
        T:AssertEqual(panel:RowFor("bgalpha").value:GetText(), "70%")
        alpha.slider._scripts.OnValueChanged(alpha.slider, 0.05, true)
        T:AssertEqual(AR.db.profile.bgalpha, 0.3, "Never below 30%")
        alpha.slider._scripts.OnMouseWheel(alpha.slider, 1)
        T:AssertEqual(AR.db.profile.bgalpha, 0.35, "Mouse wheel steps it")

        -- Right-click resets a setting to its default.
        panel:RowFor("bgalpha"):Click("RightButton")
        T:AssertEqual(AR.db.profile.bgalpha, 0.96, "Reset by right-click")

        -- Switches: a check box, and the row toggles it too.
        panel:SelectCategory("travel")
        local journey = panel:RowFor("journey")
        T:AssertTrue(journey.check:IsShown() and journey.check._on, "Checked")
        journey.check:Click("LeftButton")
        T:AssertEqual(AR.db.profile.journey, false, "Unchecked")
        T:AssertTrue(not panel:RowFor("journey").check._on)
        panel:RowFor("journey"):Click("LeftButton")
        T:AssertEqual(AR.db.profile.journey, true, "Row click toggles back")
        AR.db.profile.journey = false
        panel.primary:Click("LeftButton")
        T:AssertEqual(AR.db.profile.journey, true, "Reset group")

        AR.GuideMenu:SetSearch("opac")
        T:AssertEqual(#panel.lastRows, 1, "Search finds settings by name")
        AR.db.profile.accent, AR.db.profile.bgalpha, AR.db.profile.scheme = nil, nil, nil
        AR.UI:HideMenu()
        AR.GuideMenu:Reset()
        AR.ViewerFrame:RefreshVisuals()
    end)
end)

T:Describe("Import guides", function()
    local TEXT = table.concat({
        "guide My Barrens Loop",
        "type LEVELING",
        "startlevel 12",
        "endlevel 15",
        "description A short loop.",
        "step Start",
        "    talk Devrak##3615",
        "step Next",
        "    talk Gazlowe##3391",
    }, "\n")

    T:It("imports pasted guide text, lists it, keeps it across reloads and deletes it", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.db.global.importedGuides = {}
        AR.GuideMenu:Reset()
        AR.ImportWindow:Reset()
        AR.GuideMenu:Show("guides")
        AR.GuideMenu.importButton:Click("LeftButton")
        T:AssertTrue(AR.ImportWindow.frame:IsShown(), "+ Import opens the window")
        local guide = AR.ImportWindow:Submit(TEXT, "")
        T:AssertTrue(guide ~= nil, "Imported")
        T:AssertEqual(guide.displayTitleEN, "My Barrens Loop", "Name from the first line")
        T:AssertEqual(#guide.steps, 2)
        T:AssertEqual(guide.startlevel, 12, "Header lines read")
        T:AssertFalse(AR.ImportWindow.frame:IsShown(), "Window closes")
        T:AssertEqual(AR.GuideMenu.selectedGuide, guide, "Selected in the Guide Center")
        T:AssertTrue(AR.GuideMenu.deleteButton:IsShown(), "Imported guides can be deleted")
        T:AssertTrue(AR.db.global.importedGuides["My Barrens Loop"] ~= nil, "Saved")

        -- Next login: parsed again from the saved text.
        AR.Parser.guidesByTitle[guide.title] = nil
        T:AssertEqual(AR.GuideImport:LoadSaved(), 1, "Restored at login")
        local again = AR.Parser.guidesByTitle[AR.GuideImport.PREFIX .. "My Barrens Loop"]
        T:AssertTrue(again ~= nil and again.imported, "Back in the list")

        AR.GuideMenu:SelectGuide(again)
        AR.GuideMenu.deleteButton:Click("LeftButton")
        T:AssertEqual(AR.Parser.guidesByTitle[AR.GuideImport.PREFIX .. "My Barrens Loop"], nil, "Deleted")
        T:AssertEqual(AR.db.global.importedGuides["My Barrens Loop"], nil, "Removed from saved imports")
        AR.GuideMenu:Reset()
    end)

    T:It("explains what is wrong instead of importing broken text", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.db.global.importedGuides = {}
        AR.ImportWindow:Reset()
        AR.ImportWindow:Show()
        T:AssertEqual(AR.ImportWindow:Submit("step One\n    talk Devrak##3615\n", ""), nil, "No name")
        T:AssertEqual(AR.ImportWindow.status:GetText(), AR.L:Get("UI_IMPORT_ERR_TITLE"))
        T:AssertEqual(AR.ImportWindow:Submit("type LEVELING\n", "Empty"), nil, "No steps")
        T:AssertEqual(AR.ImportWindow.status:GetText(), AR.L:Get("UI_IMPORT_ERR_EMPTY"))
        T:AssertEqual(AR.Parser.guidesByTitle[AR.GuideImport.PREFIX .. "Empty"], nil, "Nothing left behind")
        local g = AR.GuideImport:Import("step One\n    talk Devrak##3615\n", "Named Here")
        T:AssertEqual(g.displayTitleEN, "Named Here", "Name field used without a guide line")
        T:AssertTrue(AR.Parser.guidesByTitle["Named Here"] == nil, "Never replaces a built-in title")
        AR.GuideImport:Delete(g)
        AR.ImportWindow:Reset()
    end)
end)

T:Describe("Dungeon pick-up route", function()
    T:It("builds a nearest-first route of quest givers and opens it in a tab", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.db.char.tabguides = {}
        MockWoW.player.level, MockWoW.player.faction = 18, "Alliance"
        local dm
        for _, d in ipairs(AR.DB:GetDungeons()) do if d.key == "DM" then dm = d end end
        local text, givers = AR.DungeonRoute:BuildText(dm)
        T:AssertTrue(givers >= 1, "At least one quest giver")
        T:AssertTrue(text:find("accept The Defias Brotherhood##166", 1, true) ~= nil, "Accept line for VanCleef's quest")
        T:AssertTrue(text:find("goto 1436 56.3,47.5", 1, true) ~= nil, "Goes to Gryan Stoutmantle")
        T:AssertEqual(AR.DB:QuestObjective(166), "Kill Edwin VanCleef and bring his head to Gryan Stoutmantle.", "Objective text")

        AR.GuideMenu:Reset()
        AR.GuideMenu:Show("dungeons")
        local panel = AR.Dungeons.panel
        panel:SelectCategory("all")
        for _, r in ipairs(panel.lastRows) do if r.data.key == "DM" then panel:SelectRow(r) end end
        T:AssertEqual(panel.primary.label:GetText(), AR.L:Get("UI_DG_PICKUP"))
        panel.primary:Click("LeftButton")
        local g = AR.Progression.currentGuide
        T:AssertEqual(g.title, AR.DungeonRoute.PREFIX .. "DM", "Route guide loaded")
        T:AssertEqual(g.displayTitleEN, AR.L:Format("UI_DG_ROUTE_FMT", AR.DB:DungeonName(dm)))
        T:AssertTrue(#AR.Tabs:GetTabs() >= 1, "Opened as a tab")
        T:AssertFalse(AR.GuideMenu.frame:IsShown(), "Guide Center closes")

        MockWoW.quests.inLog[166] = { title = "The Defias Brotherhood", isComplete = false, objectives = {} }
        AR.QuestTracking:ScanQuestLog()
        local after = AR.DungeonRoute:BuildText(dm)
        T:AssertTrue(after == nil or after:find("##166", 1, true) == nil, "Quests already taken are left out")
        AR.GuideMenu:Reset()
        AR.db.char.tabguides = {}
    end)
end)

T:Describe("Colour schemes", function()
    T:It("switches the panel colours and repaints the guide window background", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.db.profile.scheme, AR.db.profile.bgalpha = nil, nil
        local dusk = AR.Skins:GetProp("panel")
        AR.db.profile.scheme = "midnight"
        local mid = AR.Skins:GetProp("panel")
        T:AssertTrue(mid.r < dusk.r, "Midnight is darker than Dusk")
        T:AssertEqual(AR.Skins:GetProp("accent").r, AR.Skins.PALETTE.accent.r, "Accent untouched by schemes")
        AR.ViewerFrame:RefreshVisuals()
        T:AssertEqual(AR.ViewerFrame.frame.bg:GetColorTexture().r, AR.OptionsPanel.SCHEMES.midnight.bg.r, "Guide window repainted")
        AR.db.profile.scheme = nil
        AR.ViewerFrame:RefreshVisuals()
    end)
end)
