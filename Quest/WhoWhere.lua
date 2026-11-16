-- AzerothRoute: Nearest Service NPC Directory (WhoWhere) (SPEC-04)

local AR = _G.AzerothRoute
local WhoWhere = {
    npcs = {},
}
AR.WhoWhere = WhoWhere

function WhoWhere:Reset()
    self.npcs = {}
end

function WhoWhere:RegisterNPC(npcID, data)
    npcID = tonumber(npcID)
    if not npcID or not data then return end
    self.npcs[npcID] = {
        npcid = npcID,
        name = data.name or ("NPC_" .. tostring(npcID)),
        role = data.role,
        class = data.class,
        map = data.map,
        x = data.x,
        y = data.y,
    }
end

function WhoWhere:FindNearest(role, classFilter)
    local pMap = (_G.C_Map and _G.C_Map.GetBestMapForUnit and _G.C_Map.GetBestMapForUnit("player")) or 1420
    local pos = _G.C_Map and _G.C_Map.GetPlayerMapPosition and _G.C_Map.GetPlayerMapPosition(pMap, "player")
    local px, py = 0.5, 0.5
    if pos and pos.GetXY then
        px, py = pos:GetXY()
    end

    local best = nil
    local bestDistSq = math.huge

    for _, npc in pairs(self.npcs) do
        if (not role or npc.role == role) and (not classFilter or npc.class == classFilter) then
            if npc.map == pMap and npc.x and npc.y then
                local dx = npc.x - px
                local dy = npc.y - py
                local dSq = dx * dx + dy * dy
                if dSq < bestDistSq then
                    bestDistSq = dSq
                    best = npc
                end
            end
        end
    end

    return best
end

return WhoWhere
