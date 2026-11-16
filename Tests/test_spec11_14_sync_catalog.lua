-- SPEC-11 & SPEC-14B: NotificationCenter, PartySync & Full Catalog E2E Tests
local MockWoW = require("Tests.mock_wow_api")
local T = require("Tests.run_tests")

T:Describe("SPEC-11 & SPEC-14B: NotificationCenter, PartySync (Magnetic Hold + Shared Tab) & Catalog E2E", function()
    T:It("queues prioritized toast alerts in NotificationCenter and enforces Magnetic Step Hold in PartySync", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.NotificationCenter:Reset()
        AR.PartySync:Reset()

        AR.NotificationCenter:Push("skills", "New Class Skills Available", { priority = 2 })
        AR.NotificationCenter:Push("gear", "Chest Upgrade (+14%)", { priority = 10 })

        local top = AR.NotificationCenter:GetTopToast()
        T:AssertEqual(top.category, "gear", "Higher priority gear notification (10) must appear ahead of skills (2)")

        -- PartySync Magnetic Hold
        AR.PartySync.magneticHold = true
        AR.PartySync:OnReceivePacket("Thrall", "GS:Leveling\\Tirisfal:1:0") -- Thrall is still incomplete (0) on step 1
        T:AssertFalse(AR.PartySync:CanPartyAdvanceStep(1), "Magnetic Hold must block advancing while party member Thrall is incomplete on step 1")

        AR.PartySync:OnReceivePacket("Thrall", "GS:Leveling\\Tirisfal:1:1") -- Thrall completed step 1 (1)
        T:AssertTrue(AR.PartySync:CanPartyAdvanceStep(1), "Magnetic Hold must release once all synced party members complete step 1")
    end)

    T:It("loads the default Data/Catalog.lua and Guides/Autoload.lua without errors", function()
        MockWoW:Reset()
        local AR = _G.AzerothRoute
        AR.Storage:Initialize()
        AR.Parser:Reset()
        AR.Catalog:LoadAll()
        AR.GuidesCatalog:LoadAll()

        local tirisfal = AR.Parser.guidesByTitle["Leveling\\Horde\\Tirisfal Glades (1-12)"]
        T:AssertTrue(tirisfal ~= nil, "Default Horde Tirisfal Glades (1-12) guide must be registered in catalog")
        local alchemy = AR.Parser.guidesByTitle["Professions\\Alchemy (1-300)"]
        T:AssertTrue(alchemy ~= nil, "Default Alchemy (1-300) guide must be registered in catalog")
    end)
end)
