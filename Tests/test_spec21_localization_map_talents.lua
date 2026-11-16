-- SPEC-21: Spanish Localization (esMX/esES), WorldMap Canvas Pins, 27-Spec Talent Advisor UI & 55-Guide Catalog
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("SPEC-21: Localization, WorldMap Canvas Pins, Talent Advisor UI & 50+ Guide Catalog", function()
    T:It("adapts goals, quest/NPC/item names, ViewerFrame, and GuideMenu to esMX/esES while preserving enUS default", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        T:AssertEqual(AR.L:GetLocale(), "enUS", "MockWoW default locale must remain enUS for backward compatibility")

        -- Switch to Spanish client locale (esMX)
        MockWoW.locale = "esMX"
        AR.Storage:Initialize()
        AR.Localizers:Reset()
        AR.Parser:Reset()
        AR.GuidesCatalog:LoadAll()

        local guide = AR.Parser:ParseGuide("Test\\EsLoc", [[
            step One
                accept Rude Awakening##363
                turnin Kolkar Leaders##850
                kill Wretched Ghoul##1502 |q 364/2 |count 8
                get 15 Centaur Bracers##5010 |q 855/1
                buy 10 Empty Vial##3371
                talk Brother Malach##5675
                goto 1413 51.5,30.8
        ]])
        local goals = guide.steps[1].goals
        T:AssertEqual(goals[1]:GetText(), "Acepta Despertar abrupto", "accept goal must translate to Spanish")
        T:AssertEqual(goals[2]:GetText(), "Entrega Líderes Kolkar", "turnin goal must translate to Spanish")
        T:AssertEqual(goals[3]:GetText(), "Mata a 8 Necrófago desdichado", "kill goal must translate to Spanish")
        T:AssertEqual(goals[4]:GetText(), "Consigue 15 Brazales de centauro (0/15)", "get goal must translate to Spanish")
        T:AssertEqual(goals[5]:GetText(), "Compra 10 Vial vacío (0/10)", "buy goal must translate to Spanish")
        T:AssertEqual(goals[6]:GetText(), "Habla con Hermano Malach", "talk goal must translate to Spanish")
        T:AssertEqual(goals[7]:GetText(), "Ve a 51.5, 30.8", "goto goal must translate to Spanish")

        -- Verify ViewerFrame and GuideMenu UI labels adapt to Spanish
        AR.ViewerFrame:Initialize()
        local barrens = AR.Parser.guidesByTitle["Leveling\\Horde\\The Barrens (12-22)"]
        AR.Progression:LoadGuide(barrens, 1)
        AR.ViewerFrame:RefreshVisuals()
        T:AssertEqual(AR.ViewerFrame.menuButton.label:GetText(), "Guías", "ViewerFrame Guides button must translate to Guías in esMX")
        T:AssertEqual(AR.ViewerFrame.talentButton.label:GetText(), "Talentos", "ViewerFrame Talents button must translate to Talentos in esMX")
        T:AssertEqual(AR.ViewerFrame.titleText:GetText(), "Los Baldíos (12-22)", "ViewerFrame header title must display Spanish guide name")

        AR.GuideMenu:Reset()
        AR.GuideMenu:InitializeFrame()
        AR.GuideMenu:Show()
        T:AssertEqual(AR.GuideMenu.headerText:GetText(), "AzerothRoute — Centro de Guías", "GuideMenu title must be Spanish")
        T:AssertEqual(AR.GuideMenu.loadButton.label:GetText(), "Cargar Guía Seleccionada", "GuideMenu Load button must be Spanish")
    end)

    T:It("parses inline |goto <Zone Name> coords, parents WorldMap pins to Canvas at HIGH strata, and filters by MapID", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Parser:Reset()
        AR.Pointer:Reset()

        T:AssertEqual(AR.Coords:ResolveMapID("Tirisfal Glades"), 1420, "English zone name resolves to mapID 1420")
        T:AssertEqual(AR.Coords:ResolveMapID("Los Baldíos"), 1413, "Spanish zone name resolves to mapID 1413")
        T:AssertEqual(AR.Coords:ResolveMapID("Bosque de Elwynn"), 1429, "Spanish Elwynn resolves to mapID 1429")

        local guide = AR.Parser:ParseGuide("Test\\InlineGoto", [[
            step InlinePin
                accept A Putrid Task##404 |goto Tirisfal Glades 60.6,51.8
                kill Kobold##6 |goto Bosque de Elwynn 50.0,50.0
        ]])
        local g1 = guide.steps[1].goals[1]
        T:AssertEqual(g1.map, 1420, "Inline |goto Tirisfal Glades must resolve mapID 1420")
        T:AssertEqual(g1.x, 0.606, "Inline |goto X 60.6 must normalize to 0.606")
        T:AssertEqual(g1.y, 0.518, "Inline |goto Y 51.8 must normalize to 0.518")
        T:AssertEqual(guide.steps[1].goals[2].map, 1429, "Inline |goto Bosque de Elwynn must resolve mapID 1429")

        -- Place WorldMap pins on Tirisfal Glades (1420)
        _G.WorldMapFrame:SetMapID(1420)
        AR.Pointer:InitializeFrames()
        AR.Pointer:PlaceStepPins({
            { map = 1420, x = 0.606, y = 0.518, title = "Accept A Putrid Task", objectiveIndex = 1, action = "accept" },
        })

        local pin = AR.Pointer.worldMapPinFrames[1]
        T:AssertTrue(pin ~= nil, "WorldMap pin frame must exist")
        T:AssertEqual(pin:GetParent(), _G.WorldMapFrame:GetCanvas(), "WorldMap pin must be parented to WorldMapFrame:GetCanvas()")
        T:AssertEqual(pin:GetFrameStrata(), "HIGH", "WorldMap pin must render on HIGH strata above map tiles")
        T:AssertTrue(pin:GetFrameLevel() >= 2000, "WorldMap pin frameLevel must be >= 2000")
        T:AssertTrue(pin:IsShown(), "WorldMap pin must be visible when WorldMap displays matching mapID 1420")

        -- Filtering when viewing a different zone map (Durotar 1411)
        _G.WorldMapFrame:SetMapID(1411)
        AR.Pointer:RefreshWorldMapPins()
        T:AssertFalse(pin:IsShown(), "WorldMap pin on map 1420 must hide when viewing map 1411")

        _G.WorldMapFrame:SetMapID(1420)
        AR.Pointer:RefreshWorldMapPins()
        T:AssertTrue(pin:IsShown(), "WorldMap pin must reappear when returning to map 1420")

        -- Hover tooltip check
        local onEnter = pin:GetScript("OnEnter")
        T:AssertTrue(onEnter ~= nil, "WorldMap pin must provide OnEnter tooltip handler")
        onEnter(pin)
        T:AssertTrue(_G.GameTooltip:IsShown(), "Hovering WorldMap pin must open GameTooltip")
    end)

    T:It("loads all 9 classes x 3 specs (27 builds, 51 points) and opens interactive Talent Advisor UI", function()
        MockWoW:Reset()
        MockWoW.locale = "esMX"
        MockWoW.player.level = 15
        MockWoW.player.class = "PALADIN"
        local AR = _G.AzerothRoute
        AR.TalentAdvisor:Reset()
        AR.TalentAdvisor:LoadDefaultBuilds()

        local totalBuilds = 0
        for _, cls in ipairs(AR.TalentAdvisor.CLASS_ORDER) do
            local list = AR.TalentAdvisor:GetClassBuilds(cls)
            T:AssertEqual(#list, 3, "Class " .. cls .. " must have 3 specialization builds")
            for _, b in ipairs(list) do
                T:AssertEqual(#(b.orderedNames or {}), 51, "Build " .. b.ident .. " must cover 51 talent points (10-60)")
                totalBuilds = totalBuilds + 1
            end
        end
        T:AssertEqual(totalBuilds, 27, "TalentAdvisor must register all 27 builds")

        -- Toggle UI via /ar talents
        _G.SlashCmdList["AZEROTHROUTE"]("talents")
        T:AssertTrue(AR.TalentAdvisor.frame ~= nil and AR.TalentAdvisor.frame:IsShown(), "/ar talents must open TalentAdvisor frame")
        T:AssertEqual(AR.TalentAdvisor.selectedClass, "PALADIN", "TalentAdvisor must default to player class PALADIN")
        T:AssertEqual(#AR.TalentAdvisor.classButtons, 9, "Must render 9 class buttons")
        T:AssertEqual(#AR.TalentAdvisor.specTabs, 3, "Must render 3 spec tabs")
        T:AssertTrue(AR.TalentAdvisor.nextTalentText:GetText():find("Nivel", 1, true) ~= nil, "Next talent banner must be Spanish in esMX")

        -- Switch to Mage -> Frost/Fire/Arcane tabs and scroll down
        AR.TalentAdvisor:SelectClass("MAGE")
        T:AssertEqual(AR.TalentAdvisor.selectedClass, "MAGE", "Selecting Mage must update selectedClass")
        T:AssertEqual(#AR.TalentAdvisor:GetClassBuilds("MAGE"), 3, "Mage must expose 3 spec tabs")

        AR.TalentAdvisor.scrollDownBtn:Click("LeftButton")
        T:AssertTrue(AR.TalentAdvisor.scrollOffset > 0, "Clicking scroll down must advance roadmap rows")
    end)

    T:It("registers 50+ classic guides across all categories and supports GuideMenu pagination", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Parser:Reset()
        AR.GuidesCatalog:LoadAll()

        local count = 0
        local byType = {}
        for _, g in pairs(AR.Parser.guidesByTitle) do
            count = count + 1
            local t = (g.type or "OTHER"):upper()
            byType[t] = (byType[t] or 0) + 1
        end
        T:AssertTrue(count >= 50, "Catalog must register at least 50 guides (got " .. count .. ")")
        T:AssertTrue((byType.LEVELING or 0) >= 24, "Must include full Alliance & Horde 1-60 leveling zones")
        T:AssertTrue((byType.DUNGEONS or 0) >= 10, "Must include dungeon guide series")
        T:AssertTrue((byType.PROFESSIONS or 0) >= 10, "Must include all classic professions")
        T:AssertTrue((byType.GOLD or 0) >= 5, "Must include gold farming routes")

        AR.GuideMenu:Reset()
        AR.GuideMenu:InitializeFrame()
        AR.GuideMenu:Show()
        AR.GuideMenu:SelectCategory("ALL")

        local p1First = AR.GuideMenu.guideRowButtons[1]._guide.title
        T:AssertEqual(AR.GuideMenu.pageText:GetText(), "Page 1/4", "55 guides at 14/page must show Page 1/4")

        AR.GuideMenu:NextPage()
        local p2First = AR.GuideMenu.guideRowButtons[1]._guide.title
        T:AssertEqual(AR.GuideMenu.pageText:GetText(), "Page 2/4", "NextPage must advance to Page 2/4")
        T:AssertTrue(p1First ~= p2First, "Page 2 must show different guides from Page 1")

        AR.GuideMenu:PrevPage()
        T:AssertEqual(AR.GuideMenu.pageText:GetText(), "Page 1/4", "PrevPage must return to Page 1/4")
        T:AssertEqual(AR.GuideMenu.guideRowButtons[1]._guide.title, p1First, "Page 1 must restore original first row")
    end)
end)
