-- AzerothRoute: guides imported by the player.
-- Format: the same guide language as the built-in guides (header lines such as `type`, `startlevel`,
-- `endlevel`, `description`, then `step` blocks). An optional first line `guide <Title>` names it;
-- otherwise the title typed in the import window is used.
-- Imported guides are kept in AR.db.global.importedGuides[title] = text and parsed again at login,
-- before the last guide is resumed. They live under the "Imported\" title prefix, so they never
-- replace a built-in guide.

local AR = _G.AzerothRoute
local GuideImport = { PREFIX = "Imported\\", MAX_CHARS = 200000 }
AR.GuideImport = GuideImport

local function store()
    if not AR.db or not AR.db.global then return nil end
    AR.db.global.importedGuides = AR.db.global.importedGuides or {}
    return AR.db.global.importedGuides
end

local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- Splits an optional `guide <Title>` first line off the text: returns title (or nil) and body.
function GuideImport:SplitHeader(text)
    text = tostring(text or ""):gsub("^\239\187\191", "") -- strip a UTF-8 BOM
    local first, rest = text:match("^%s*([^\r\n]*)\r?\n?(.*)$")
    local title = first and first:match("^guide%s+(.+)$")
    if title then
        title = trim(title):gsub('^"(.*)"$', "%1")
        return title, rest
    end
    return nil, text
end

-- Parses and registers one guide. Returns the guide, or nil and an error message key.
function GuideImport:Register(title, body)
    if not AR.Parser then return nil, "UI_IMPORT_ERR_PARSER" end
    title = trim(title)
    if title == "" then return nil, "UI_IMPORT_ERR_TITLE" end
    if #body > self.MAX_CHARS then return nil, "UI_IMPORT_ERR_SIZE" end
    local key = self.PREFIX .. title
    local ok, guide = pcall(AR.Parser.ParseGuide, AR.Parser, key, body)
    if not ok or not guide then return nil, "UI_IMPORT_ERR_PARSE" end
    if not guide.steps or #guide.steps == 0 then
        AR.Parser.guidesByTitle[key] = nil
        return nil, "UI_IMPORT_ERR_EMPTY"
    end
    guide.displayTitleEN, guide.displayTitleES = title, title
    guide.imported = true
    guide.type = guide.type or "LEVELING"
    return guide
end

-- Imports pasted text; `title` is used when the text has no `guide <Title>` line.
-- Returns the guide, or nil and an error message key.
function GuideImport:Import(text, title)
    local fromText, body = self:SplitHeader(text)
    title = fromText or title
    local guide, err = self:Register(title or "", body or "")
    if not guide then return nil, err end
    local db = store()
    if db then db[trim(title)] = body end
    return guide
end

-- Parses every saved import (at login, before the last guide is resumed). Returns the count.
function GuideImport:LoadSaved()
    local n = 0
    for title, body in pairs(store() or {}) do
        if self:Register(title, body) then n = n + 1 end
    end
    return n
end

function GuideImport:IsImported(guide)
    return type(guide) == "table" and guide.imported == true
end

-- Removes an imported guide (from the list and the saved imports); closes its tab.
function GuideImport:Delete(guide)
    if not self:IsImported(guide) then return false end
    local title = guide.displayTitleEN
    local db = store()
    if db then db[title] = nil end
    if AR.Parser and AR.Parser.guidesByTitle then AR.Parser.guidesByTitle[guide.title] = nil end
    if AR.Tabs then AR.Tabs:RemoveTab(guide.title) end
    return true
end

return GuideImport
