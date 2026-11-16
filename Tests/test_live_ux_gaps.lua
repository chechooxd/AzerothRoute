local T = require("Tests.run_tests")
local Mock = require("Tests.mock_wow_api")
T:Describe("Reported viewer gaps", function()
    T:It("saves viewer scalar anchors and restores them on profile changes", function()
        Mock:Reset()
        local AR = AzerothRoute
        AR.Storage:Initialize()
        AR.ViewerFrame:Initialize()
        local f = AR.ViewerFrame.frame
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 25, -80)
        f:GetScript("OnDragStop")(f)
        T:AssertEqual(AR.db.profile.viewer_pos.x, 25)
        AR.ViewerFrame:Initialize()
        local p, relative, rp, x, y = AR.ViewerFrame.frame:GetPoint()
        T:AssertEqual(p, "TOPLEFT"); T:AssertEqual(x,25); T:AssertEqual(y,-80)
        T:AssertEqual(relative, UIParent)
        AR.db.profile.viewer_pos = nil
        AR.Storage:OnProfileChanged()
        p = AR.ViewerFrame.frame:GetPoint()
        T:AssertEqual(p,"RIGHT")
    end)
    T:It("lets an explicit right click complete arrival without changing quest data", function()
        Mock:Reset()
        local AR = AzerothRoute
        AR.Storage:Initialize()
        local g = AR.Parser:ParseGuide("ManualArrival", [[
step First
    goto 1420 90,90
    accept Test##123
step Second
    goto 1420 95,95
]])
        AR.Progression:LoadGuide(g,1)
        AR.Progression.pause = true
        AR.ViewerFrame:RefreshVisuals()
        local goal = g:GetStep(1).goals[1]
        local row
        for _, r in ipairs(AR.ViewerFrame.lineRows) do if r._goal == goal then row=r end end
        row:GetScript("OnClick")(row,"RightButton")
        T:AssertEqual(goal:GetStatus(),"complete")
        T:AssertTrue(goal.visited)
        T:AssertEqual(Mock.quests.completed[123],nil)
        row:GetScript("OnClick")(row,"RightButton")
        T:AssertFalse(goal.visited)
        T:AssertTrue(goal:GetStatus() ~= "complete")
    end)
    T:It("clears old waypoint and pins when a step has no coordinates but preserves corpse navigation", function()
        Mock:Reset()
        local AR = AzerothRoute
        AR.Pointer:PlaceStepPins({{map=1420,x=.9,y=.9}})
        AR.Pointer:PlaceStepPins({})
        T:AssertEqual(#AR.Pointer.worldMapPins,0)
        T:AssertEqual(AR.Pointer.activeTarget,nil)
        AR.Pointer.activeTarget={type="corpse",map=1420,x=.8,y=.8}
        AR.Pointer:PlaceStepPins({})
        T:AssertEqual(AR.Pointer.activeTarget.type,"corpse")
    end)
    T:It("does not complete future preview arrivals", function()
        Mock:Reset()
        local AR = AzerothRoute
        AR.Storage:Initialize()
        local guide = AR.Parser:ParseGuide("PreviewArrival", [[
step First
    accept Other##123
step Second
    goto 1420 95,95
]])
        AR.Progression:LoadGuide(guide, 1)
        AR.Progression.pause = true
        AR.db.profile.previewsteps = 1
        AR.ViewerFrame:RefreshVisuals()
        local goal = guide:GetStep(2).goals[1]
        for _, row in ipairs(AR.ViewerFrame.lineRows) do
            if row._goal == goal and row:IsShown() then
                row:GetScript("OnClick")(row, "RightButton")
                T:AssertFalse(goal.visited)
                row:GetScript("OnClick")(row, "LeftButton")
            end
        end
        T:AssertFalse(goal.visited)
        T:AssertEqual(AR.Pointer.activeTarget.x, 0.95, "Preview navigation remains available")
    end)
end)
