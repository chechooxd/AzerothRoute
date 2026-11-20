-- AzerothRoute changes applied on top of the renamed Polestar code by tools/fork_polestar.lua.
-- Each patch: file (relative to addon/), find (exact text after the rename) and replace, or
-- create = true with the whole file in replace; why says what it is for.
-- A patch that no longer finds its text is reported and fails the run.

local function read(rel)
    local root = (debug.getinfo(1, "S").source:match("^@(.*)[/\\]tools[/\\]fork[/\\]patches%.lua$")) or "."
    local f = assert(io.open(root .. "/tools/fork/files/" .. rel, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

return {
    {
        file = "AzerothRoute/README.txt", create = true, replace = read("README.txt"),
        why = "AzerothRoute's install notes and credits in place of Polestar's README",
    },
    -- HU-05: AzerothRoute 1's settings carry over once.
    {
        file = "AzerothRoute/Core/MigrateV1.lua", create = true, replace = read("Core/MigrateV1.lua"),
        why = "reads AzerothRoute 1's saved settings once (HU-05)",
    },
    {
        file = "AzerothRoute/Core/Core.xml",
        find = '\t<Script file="Perf.lua"/>\n',
        replace = '\t<Script file="Perf.lua"/>\n\t<Script file="MigrateV1.lua"/>\n',
        why = "loads the AzerothRoute 1 migration",
    },
    {
        file = "AzerothRoute/AzerothRoute.toc",
        find = "## SavedVariables: AzerothRouteDB\r\n",
        replace = "## SavedVariables: AzerothRouteDB, AzerothRouteSavedDB\r\n",
        why = "AzerothRoute 1's account settings (AzerothRouteSavedDB), read by Core/MigrateV1.lua",
    },
}
