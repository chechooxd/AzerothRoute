-- AzerothRoute: "Pick up the quests" for a dungeon.
-- Builds a guide on the fly from the database: one step per quest giver (go there, talk, accept),
-- ordered nearest-first from where the player stands, with only the quests this character can take.
-- The guide opens in its own tab like any other.

local AR = _G.AzerothRoute
local DungeonRoute = { PREFIX = "Dungeon\\" }
AR.DungeonRoute = DungeonRoute

local function L(key, fallback)
    if AR.L then
        local v = AR.L:Get(key)
        if v and v ~= key then return v end
    end
    return fallback or key
end

-- Quest givers with the quests to accept from each: { { unit, quests = { quest } } }.
function DungeonRoute:Givers(dungeon)
    local byGiver, order = {}, {}
    local QT = AR.QuestTracking
    local level = (_G.UnitLevel and _G.UnitLevel("player")) or 1
    for _, q in ipairs((AR.Dungeons and AR.Dungeons:QuestsFor(dungeon)) or {}) do
        local taken = QT and (QT:IsCompleted(q.id) or QT:IsInLog(q.id))
        if not taken and level >= (q.minLevel or 0) then
            for _, ref in ipairs(q.starts) do
                if ref.kind == "U" then
                    local u = AR.DB:GetUnit(ref.id)
                    if u and u.map > 0 then
                        if not byGiver[u.id] then
                            byGiver[u.id] = { unit = u, quests = {} }
                            order[#order + 1] = byGiver[u.id]
                        end
                        table.insert(byGiver[u.id].quests, q)
                        break
                    end
                end
            end
        end
    end
    return order
end

-- Greedy nearest-first order from the player's position (unreachable givers keep their order at the end).
function DungeonRoute:Order(givers)
    if not AR.Coords then return givers end
    local pMap, px, py = AR.Coords:GetPlayerPosition()
    local left, out = {}, {}
    for i, g in ipairs(givers) do left[i] = g end
    local cur = pMap and { map = pMap, x = px, y = py } or nil
    while #left > 0 do
        local bestI, bestD
        for i, g in ipairs(left) do
            local d = cur and AR.Coords:GetDistanceBetween(cur.map, cur.x, cur.y, g.unit.map, g.unit.x / 100, g.unit.y / 100)
            if d and (not bestD or d < bestD) then bestI, bestD = i, d end
        end
        bestI = bestI or 1
        local g = table.remove(left, bestI)
        out[#out + 1] = g
        cur = { map = g.unit.map, x = g.unit.x / 100, y = g.unit.y / 100 }
    end
    return out
end

-- Guide text in the addon's guide language.
function DungeonRoute:BuildText(dungeon)
    local givers = self:Order(self:Givers(dungeon))
    if #givers == 0 then return nil end
    local lines = {
        "type DUNGEONS",
        string.format("startlevel %d", dungeon.min),
        string.format("endlevel %d", dungeon.max),
    }
    for _, g in ipairs(givers) do
        local u = g.unit
        lines[#lines + 1] = "step " .. u.name
        lines[#lines + 1] = string.format("    goto %d %.1f,%.1f", u.map, u.x, u.y)
        lines[#lines + 1] = string.format("    talk %s##%d", u.name, u.id)
        for _, q in ipairs(g.quests) do
            lines[#lines + 1] = string.format("    accept %s##%d", q.name, q.id)
        end
    end
    return table.concat(lines, "\n"), #givers
end

-- Builds, registers and opens the route guide. Returns the guide, or nil when nothing is left to take.
function DungeonRoute:Open(dungeon)
    local text = self:BuildText(dungeon)
    if not text or not AR.Parser then return nil end
    local name = AR.DB:DungeonName(dungeon)
    local guide = AR.Parser:ParseGuide(self.PREFIX .. dungeon.key, text)
    if not guide or not guide.steps or #guide.steps == 0 then return nil end
    local title = string.format(L("UI_DG_ROUTE_FMT", "%s: quests"), name)
    guide.displayTitleEN, guide.displayTitleES = title, title
    if AR.ViewerFrame and AR.ViewerFrame.RememberCurrentTab then AR.ViewerFrame:RememberCurrentTab() end
    AR.Progression:LoadGuide(guide, 1)
    if AR.Tabs then AR.Tabs:AddTab(guide.title) end
    if AR.ViewerFrame then
        if not AR.ViewerFrame.frame then AR.ViewerFrame:Initialize() end
        AR.ViewerFrame.frame:Show()
        AR.ViewerFrame:RefreshVisuals()
    end
    if AR.GuideMenu and AR.GuideMenu.frame then AR.GuideMenu.frame:Hide() end
    return guide
end

return DungeonRoute
