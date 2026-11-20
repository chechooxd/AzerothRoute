-- AzerothRoute 2: builds AzerothRoute's addon folders from a Polestar release.
--
--   luajit tools/fork_polestar.lua <Polestar addons dir> [<output dir, default addon>]
--
-- Polestar (https://github.com/fitzforge/polestar) is GPL-3.0-only, Copyright (c) 2026 The Polestar
-- authors; AzerothRoute is a modified version of it under the same licence. This tool:
--   1. copies every Polestar addon folder that AzerothRoute ships, renamed Polestar_X -> AzerothRoute_X;
--   2. renames the brand in code and text (identifiers, addon/frame/global names, SavedVariables,
--      slash commands, bindings, visible text) and leaves comments, licence files, URLs and the
--      phrases about Polestar as a project (its Discord, Recorder, founder, authorship) untouched;
--   3. applies AzerothRoute's own changes (tools/fork/patches.lua) and reports any that no longer apply;
--   4. adds a notice to each folder saying it was modified from Polestar.
-- Rerunning it on the same Polestar release reproduces the committed folders (HU-02).

local SRC = arg[1] or error("usage: luajit tools/fork_polestar.lua <Polestar addons dir> [<output dir>]")
local OUT = arg[2] or "addon"
local ROOT = (arg[0]:gsub("[/\\]?tools[/\\]fork_polestar%.lua$", ""))
if ROOT == "" then ROOT = "." end

-- Folders AzerothRoute leaves out (see THIRD_PARTY.md and odd/tasks/azerothroute-2-polestar-base.md).
local EXCLUDE = {
    Polestar_Arcade = "Doom mini-game",
    Polestar_Guides_Dwarf = "Legs.lua only (Leffe's maps, permission given to Polestar's author)",
    Polestar_Guides_Gnome = "Legs.lua only",
    Polestar_Guides_Human = "Legs.lua only",
    Polestar_Guides_NightElf = "Legs.lua only",
    Polestar_Guides_Orc = "Legs.lua only",
    Polestar_Guides_Scourge = "Legs.lua only",
    Polestar_Guides_Skyborne = "Legs.lua only",
    Polestar_Guides_Tauren = "Legs.lua only",
    Polestar_Guides_Troll = "Legs.lua only",
}
-- Decision D2 (2026-11-20): the QuestDB, Codex and Experimental packs ship as Polestar ships them,
-- QuestieDB-derived facts included. --without-questie leaves them out (on a rights holder's request).
for _, a in ipairs(arg) do
    if a == "--without-questie" then
        EXCLUDE.Polestar_QuestDB = "QuestieDB-derived facts (--without-questie)"
        EXCLUDE.Polestar_Codex = "QuestieDB-derived facts (--without-questie)"
        EXCLUDE.Polestar_Experimental = "QuestieDB-derived facts (--without-questie)"
    end
end

local SITE = "https://github.com/chechooxd/AzerothRoute"

-- Polestar files AzerothRoute replaces with its own (tools/fork/patches.lua creates them).
local SKIP_FILES = { ["Polestar/README.txt"] = true }

-- Text the rename never touches: Polestar as a project, its people and its channels.
local PROTECT = {
    "Discord", "Recorder", "founder", "GitHub", "Fitz", "XrayAlpha",
    "Polestar's words", "Polestar's source", "Polestar's own tools", "not part of Polestar",
    "not Polestar's", "not to Polestar", "Polestar's author", "Polestar authors",
}

local function protected(s)
    for _, p in ipairs(PROTECT) do
        if s:find(p, 1, true) then return true end
    end
    return false
end

-- Brand rename inside a string literal or a line of text.
local function renameText(s)
    -- Keep URLs whole.
    local urls = {}
    s = s:gsub("https?://[%w%._%-/#%?=&]+", function(u)
        urls[#urls + 1] = u
        return "\1" .. #urls .. "\2"
    end)
    s = s:gsub("discord%.gg/[%w_%-]+", function(u)
        urls[#urls + 1] = u
        return "\1" .. #urls .. "\2"
    end)
    s = s:gsub("PolestarCharDB", "AzerothRouteCharData")
    s = s:gsub("Polestar", "AzerothRoute")
    s = s:gsub("POLESTAR", "AZEROTHROUTE")
    s = s:gsub("/polestar", "/ar")
    s = s:gsub("/pole%f[^%w]", "/ar")
    s = s:gsub("\1(%d+)\2", function(i) return urls[tonumber(i)] end)
    return s
end

-- Whole string literals with their own replacement (slash commands).
local EXACT = {
    ['"/ar"'] = '"/azerothroute"', -- "/polestar" after renameText
    ['"/pole"'] = '"/ar"',
    ['"/ps"'] = '"/azr"',
}

local function renameString(raw, keyProtected)
    if keyProtected or protected(raw) then return raw end
    local out = renameText(raw)
    -- The first slash name, "/polestar", becomes the long name; "/pole" takes "/ar".
    if raw == '"/polestar"' then return '"/azerothroute"' end
    if EXACT[raw] and raw ~= '"/ar"' then return EXACT[raw] end
    return out
end

-- Code regions hold no strings or comments: the brand is renamed anywhere in an identifier, as in
-- strings, so SLASH_POLESTAR1 still pairs with SlashCmdList["POLESTAR"] and BINDING_NAME_POLESTAR_X
-- with the binding names in Bindings.xml.
local function renameCode(code)
    code = code:gsub("PolestarCharDB", "AzerothRouteCharData")
    code = code:gsub("Polestar", "AzerothRoute")
    code = code:gsub("POLESTAR", "AZEROTHROUTE")
    return code
end

-- Splits Lua source into code, string and comment regions and renames code and strings.
local function renameLua(src)
    local out, pos, n = {}, 1, #src
    local protectNext = nil -- position of a value string whose key is protected
    while pos <= n do
        local s = src:find("[\"'%-%[]", pos)
        if not s then
            out[#out + 1] = renameCode(src:sub(pos))
            break
        end
        local c = src:sub(s, s)
        local kind, e
        if c == "-" then
            if src:sub(s + 1, s + 1) == "-" then
                local eq = src:match("^%[(=*)%[", s + 2)
                if eq then
                    local _, ce = src:find("%]" .. eq .. "%]", s + 2)
                    e = ce or n
                else
                    local nl = src:find("\n", s + 2, true)
                    e = nl and nl - 1 or n
                end
                kind = "comment"
            end
        elseif c == "[" then
            local eq = src:match("^%[(=*)%[", s)
            if eq then
                local _, ce = src:find("%]" .. eq .. "%]", s + 2)
                e = ce or n
                kind = "string"
            end
        else -- quote
            local i = s + 1
            while i <= n do
                local ch = src:sub(i, i)
                if ch == "\\" then i = i + 2
                elseif ch == c then break
                elseif ch == "\n" then break
                else i = i + 1 end
            end
            e = math.min(i, n)
            kind = "string"
        end
        if not kind then
            -- A lone "-" or "[" in code: keep scanning.
            out[#out + 1] = renameCode(src:sub(pos, s))
            pos = s + 1
        else
            out[#out + 1] = renameCode(src:sub(pos, s - 1))
            local raw = src:sub(s, e)
            if kind == "comment" then
                out[#out + 1] = raw
            else
                local keyProtected = (protectNext == s)
                out[#out + 1] = renameString(raw, keyProtected)
                -- `["key"] = "value"`: a protected key keeps its value too.
                if not keyProtected and protected(raw) then
                    local _, ve = src:find("^%s*%]%s*=%s*", e + 1)
                    if ve then protectNext = ve + 1 end
                end
            end
            pos = e + 1
        end
    end
    return table.concat(out)
end

-- Text files of the addon (toc, xml): line rules.
local function renameToc(src)
    local lines = {}
    for line in (src:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do
        if line:match("^## Author:") then
            line = "## Author: AzerothRoute (modified from Polestar by The Polestar authors)"
        elseif line:match("^## X%-Website:") then
            line = "## X-Website: " .. SITE
        elseif line:match("^## Title:") and not line:match("_") then
            line = renameText(line)
        else
            line = renameText(line)
        end
        lines[#lines + 1] = line
    end
    while lines[#lines] == "" do lines[#lines] = nil end
    return table.concat(lines, "\r\n") .. "\r\n"
end

local function renameXml(src)
    return renameText(src)
end

-- Files ---------------------------------------------------------------------------------------

local function read(p)
    local f = assert(io.open(p, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

local WINDOWS = package.config:sub(1, 1) == "\\"
local made = {}

local function mkdirs(dir)
    if made[dir] then return end
    if WINDOWS then
        os.execute('if not exist "' .. dir:gsub("/", "\\") .. '" mkdir "' .. dir:gsub("/", "\\") .. '"')
    else
        os.execute('mkdir -p "' .. dir .. '"')
    end
    made[dir] = true
end

local function rmtree(dir)
    if WINDOWS then
        os.execute('if exist "' .. dir:gsub("/", "\\") .. '" rmdir /s /q "' .. dir:gsub("/", "\\") .. '"')
    else
        os.execute('rm -rf "' .. dir .. '"')
    end
end

local function write(p, s)
    local dir = p:match("^(.*)/[^/]+$")
    if dir then mkdirs(dir) end
    local f = assert(io.open(p, "wb"))
    f:write(s)
    f:close()
end

local function listFiles(dir)
    local files = {}
    local h = io.popen('cd "' .. dir .. '" && find . -type f | sort')
    for line in h:lines() do files[#files + 1] = line:gsub("^%./", "") end
    h:close()
    return files
end

local function listFolders(dir)
    local out = {}
    local h = io.popen('cd "' .. dir .. '" && find . -mindepth 1 -maxdepth 1 -type d | sort')
    for line in h:lines() do out[#out + 1] = line:gsub("^%./", "") end
    h:close()
    return out
end

local KEEP_VERBATIM = { LICENSE = true }

local function transform(rel, data)
    local ext = rel:match("%.([%w]+)$")
    local base = rel:match("([^/]+)$")
    if KEEP_VERBATIM[base] or (ext == "txt" and base:find("LICENSE", 1, true)) or base == "CREDITS.md"
        or base:match("OFL") then
        return data
    end
    if ext == "lua" then
        if not (data:find("Polestar", 1, true) or data:find("POLESTAR", 1, true) or data:find("/polestar", 1, true)) then
            return data
        end
        return renameLua(data)
    elseif ext == "toc" then
        return renameToc(data)
    elseif ext == "xml" then
        return renameXml(data)
    elseif ext == "json" or ext == "md" then
        return renameText(data)
    end
    return data
end

-- Patches -------------------------------------------------------------------------------------

local function applyPatches(outDir)
    local ok, patches = pcall(dofile, ROOT .. "/tools/fork/patches.lua")
    if not ok then
        print("patches: " .. tostring(patches))
        return 0, 0
    end
    local applied, missed = 0, 0
    for _, p in ipairs(patches) do
        local path = outDir .. "/" .. p.file
        local f = io.open(path, "rb")
        local s = f and f:read("*a")
        if f then f:close() end
        local i, j
        if s then i, j = s:find(p.find, 1, true) end
        if not s then
            if p.create then
                write(path, p.replace)
                applied = applied + 1
            else
                missed = missed + 1
                print("patch missed (no file): " .. p.file .. " - " .. (p.why or ""))
            end
        elseif not i then
            missed = missed + 1
            print("patch missed: " .. p.file .. " - " .. (p.why or ""))
        else
            s = s:sub(1, i - 1) .. p.replace .. s:sub(j + 1)
            write(path, s)
            applied = applied + 1
        end
    end
    return applied, missed
end

local NOTICE = [[
This folder is part of AzerothRoute, a modified version of Polestar.

Polestar: Copyright (c) 2026 The Polestar authors, https://github.com/fitzforge/polestar,
licensed under the GNU General Public License, version 3 only (see LICENSE in the AzerothRoute
folder, and this folder's own LICENSE or LICENSE-DATA.txt where it has one).

AzerothRoute renamed the addon, its folders, globals, saved variables, commands and visible name,
and changed the files listed by tools/fork/patches.lua in AzerothRoute's repository
(%s). Generated from Polestar %s by tools/fork_polestar.lua.
]]

-- Run -----------------------------------------------------------------------------------------

local version = read(SRC .. "/Polestar/Polestar.toc"):match("## Version:%s*([%w%.%-]+)") or "?"
rmtree(OUT)
local folders, files, renamed = 0, 0, 0
for _, folder in ipairs(listFolders(SRC)) do
    if folder:match("^Polestar") then
        if EXCLUDE[folder] then
            print(string.format("skip  %-28s %s", folder, EXCLUDE[folder]))
        else
            local target = folder:gsub("^Polestar", "AzerothRoute")
            folders = folders + 1
            for _, rel in ipairs(listFiles(SRC .. "/" .. folder)) do
              if not SKIP_FILES[folder .. "/" .. rel] then
                local data = read(SRC .. "/" .. folder .. "/" .. rel)
                local outRel = rel:gsub("Polestar", "AzerothRoute")
                local outData = transform(rel, data)
                if outData ~= data then renamed = renamed + 1 end
                write(OUT .. "/" .. target .. "/" .. outRel, outData)
                files = files + 1
              end
            end
            write(OUT .. "/" .. target .. "/NOTICE.txt", string.format(NOTICE, SITE, version))
        end
    end
end
local applied, missed = applyPatches(OUT)
-- AzerothRoute's own art (tools/fork/assets, drawn by tools/fork/make_art.lua) over Polestar's.
local art = 0
local assets = ROOT .. "/tools/fork/assets"
if io.open(assets .. "/AzerothRoute/Media/UI/emblem.tga", "rb") then
    for _, rel in ipairs(listFiles(assets)) do
        write(OUT .. "/" .. rel, read(assets .. "/" .. rel))
        art = art + 1
    end
end
print(string.format("%d art files", art))
print(string.format("%d folders, %d files (%d renamed), %d patches applied, %d missed; from Polestar %s",
    folders, files, renamed, applied, missed, version))
os.exit(missed == 0 and 0 or 1)
