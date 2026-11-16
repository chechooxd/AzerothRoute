-- AzerothRoute: Options & Settings Schema Registry (SPEC-13)

local AR = _G.AzerothRoute
local Options = {
    groups = {},
}
AR.Options = Options

function Options:Reset()
    self.groups = {}
end

function Options:RegisterGroup(id, title, fields)
    self.groups[id] = {
        id = id,
        title = title,
        fields = fields or {},
    }
end

function Options:GetGroup(id)
    return self.groups[id]
end

return Options
