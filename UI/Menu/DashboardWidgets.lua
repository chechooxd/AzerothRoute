-- AzerothRoute: 6-Column Tile-Grid Dashboard Engine (SPEC-13)

local AR = _G.AzerothRoute
local DashboardWidgets = {
    GRID_COLS = 6,
    tiles = {},
}
AR.DashboardWidgets = DashboardWidgets

function DashboardWidgets:Reset()
    self.tiles = {}
end

function DashboardWidgets:RegisterTile(id, spec)
    table.insert(self.tiles, {
        id = id,
        col = math.max(1, math.min(self.GRID_COLS, spec.col or 1)),
        row = math.max(1, spec.row or 1),
        widthCols = math.max(1, math.min(self.GRID_COLS, spec.widthCols or 2)),
        heightRows = math.max(1, spec.heightRows or 1),
    })
end

function DashboardWidgets:GetLayout()
    return self.tiles
end

return DashboardWidgets
