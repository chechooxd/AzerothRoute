-- AzerothRoute: nearest services (vendor, repair, innkeeper, flight master, bank, auction house,
-- stable master, mailbox) from the generated database, for the player's faction and continent.

local AR = _G.AzerothRoute
local Nearby = {
    SERVICES = {
        { flag = "v", key = "UI_SV_V" },
        { flag = "r", key = "UI_SV_R" },
        { flag = "i", key = "UI_SV_I" },
        { flag = "f", key = "UI_SV_F" },
        { flag = "b", key = "UI_SV_B" },
        { flag = "a", key = "UI_SV_A" },
        { flag = "s", key = "UI_SV_S" },
        { flag = "m", key = "UI_SV_M", objects = true },
    },
    index = nil,
}
AR.Nearby = Nearby

function Nearby:Reset()
    self.index = nil
end

-- flag -> list of { kind = "npc"|"object", id = ... } with open-world coordinates (built once).
function Nearby:GetIndex()
    if self.index then return self.index end
    local idx = {}
    for _, s in ipairs(self.SERVICES) do idx[s.flag] = {} end
    for id, raw in pairs((AR.DB and AR.DB.Units) or {}) do
        local flags = raw:match("%^([%a]*)$") or ""
        if flags ~= "" and not raw:find("%^0%^0%^0%^") then
            for flag in flags:gmatch(".") do
                if idx[flag] then table.insert(idx[flag], { kind = "npc", id = id }) end
            end
        end
    end
    for id, raw in pairs((AR.DB and AR.DB.Objects) or {}) do
        if raw:sub(-2) == "^m" then table.insert(idx.m, { kind = "object", id = id }) end
    end
    self.index = idx
    return idx
end

-- Nearest service of `flag` reachable on foot (same continent) for the player's faction:
-- returns the decoded record plus its distance in yards, or nil.
function Nearby:FindNearest(flag)
    local DB = AR.DB
    if not DB or not AR.Coords then return nil end
    local best, bestDist
    for _, ref in ipairs(self:GetIndex()[flag] or {}) do
        local rec = ref.kind == "npc" and DB:GetUnit(ref.id) or DB:GetObject(ref.id)
        if rec and rec.map > 0 and (ref.kind == "object" or DB:IsForPlayer(rec.side)) then
            local d = AR.Coords:GetDistanceTo(rec.map, rec.x / 100, rec.y / 100)
            if d and (not bestDist or d < bestDist) then best, bestDist = rec, d end
        end
    end
    return best, bestDist
end

-- One entry per service type: { flag, label, record, distance } (record nil when none nearby).
function Nearby:List()
    local out = {}
    for _, s in ipairs(self.SERVICES) do
        local rec, dist = self:FindNearest(s.flag)
        out[#out + 1] = { flag = s.flag, label = (AR.L and AR.L:Get(s.key)) or s.key, record = rec, distance = dist }
    end
    return out
end

-- Points the arrow at the nearest service of `flag`; returns the record or nil.
function Nearby:GoTo(flag)
    local rec = self:FindNearest(flag)
    if not rec or not AR.Pointer then return nil end
    AR.Pointer:SetManualTarget(rec.map, rec.x / 100, rec.y / 100, rec.name)
    return rec
end

return Nearby
