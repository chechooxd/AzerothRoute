-- AzerothRoute: Talents mode of the Guide Center (Polestar-style talents section).
-- The sidebar lists the player's class plans, one per spec; the list shows the plan pick by pick
-- (one talent point per level from 10), learned picks ticked and the next one marked; the details
-- pane explains the selected pick, where you stand, and offers "Follow this plan" and
-- "Apply talents". The talent engine (builds, Blizzard nodes, learning) stays in TalentAdvisor.

local AR = _G.AzerothRoute
local TalentsPanel = { MODE = "talents", query = "" }
AR.TalentsPanel = TalentsPanel

local FIRST_LEVEL = 10

local function L(key, fallback)
    if AR.L then
        local v = AR.L:Get(key)
        if v and v ~= key then return v end
    end
    return fallback or key
end

local function TA() return AR.TalentAdvisor end

function TalentsPanel:Reset()
    self.query = ""
    self.cache = nil
    if self.panel and self.panel.side then
        self.panel.side:Hide()
        self.panel.main:Hide()
    end
    self.panel = nil
end

function TalentsPanel:Class()
    return TA():GetActivePlayerClass()
end

function TalentsPanel:Builds()
    return TA():GetClassBuilds(self:Class())
end

function TalentsPanel:Build(ident)
    TA():LoadDefaultBuilds()
    return ident and TA().buildsByIdent[ident] or nil
end

-- The plan the player follows: the one chosen with "Follow this plan", else the suggested spec.
function TalentsPanel:FollowedIdent()
    local chosen = AR.db and AR.db.profile and AR.db.profile.talentplan
    local builds = self:Builds()
    for _, b in ipairs(builds) do if b.ident == chosen then return chosen end end
    for _, b in ipairs(builds) do if b.suggested then return b.ident end end
    return builds[1] and builds[1].ident
end

function TalentsPanel:Follow(ident)
    if not (AR.db and AR.db.profile and self:Build(ident)) then return false end
    AR.db.profile.talentplan = ident
    self.cache = nil
    if self.panel then self.panel:Render() end
    return true
end

function TalentsPanel:Spent()
    return TA():GetSpentPointsCount()
end

function TalentsPanel:Apply(ident)
    if not ident then return false end
    TA():LearnBuild(ident, math.max(1, self:Spent() + 1))
    if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
        _G.DEFAULT_CHAT_FRAME:AddMessage("|cfff4c54aAzerothRoute:|r " .. L("UI_TALENT_APPLY") .. " -> "
            .. TA():GetLocalizedBuildName(self:Build(ident)))
    end
    self.cache = nil
    if self.panel then self.panel:Render() end
    return true
end

-- Panel data ----------------------------------------------------------------------------------

function TalentsPanel:SetQuery(q)
    self.query = tostring(q or "")
    if self.panel then
        self.panel.page = 0
        self.panel._focused = nil
        self.panel:Render()
    end
end

function TalentsPanel:GetCategories()
    local out = {}
    local followed = self:FollowedIdent()
    for _, b in ipairs(self:Builds()) do
        local name = TA():GetLocalizedBuildName(b)
        out[#out + 1] = { id = b.ident, label = (b.ident == followed and "|cfff4c54a>|r " or "") .. name }
    end
    return out
end

function TalentsPanel:CountCategory(id)
    local b = self:Build(id)
    return b and #(b.orderedNames or {}) or 0
end

-- Rows are cached per plan, spent points and search so a selected row survives a re-render.
function TalentsPanel:GetRows(id)
    local b = self:Build(id)
    if not b then return {} end
    local spent, q = self:Spent(), (self.query or ""):lower()
    local key = table.concat({ id, spent, q, AR.L and AR.L:IsSpanish() and "es" or "en" }, "|")
    if self.cache and self.cache.key == key then return self.cache.rows end
    local rows = {}
    local seq = b.orderedNames or {}
    for i, name in ipairs(seq) do
        local loc = TA():GetLocalizedTalentName(name)
        if q == "" or loc:lower():find(q, 1, true) or name:lower():find(q, 1, true) then
            local done, isNext = i <= spent, i == spent + 1
            local icon = TA():GetTalentIcon(name, b.class)
            local level = FIRST_LEVEL - 1 + i
            local label = string.format(L("UI_TALENT_LEVEL_FMT", "Level %d: %s"), level, loc)
            if done then label = "|cff8a8f9a" .. label .. "|r"
            elseif isNext then label = "|cfff4c54a" .. label .. "|r" end
            local text = string.format("|T%s:16:16|t  %s", icon, label)
            rows[#rows + 1] = {
                text = text,
                tag = done and "|cff5fd17a" .. L("UI_TALENT_DONE_TAG", "OK") .. "|r"
                    or (isNext and L("UI_TALENT_NEXT_TAG", "Next") or ""),
                data = { build = b, index = i, name = name, level = level, done = done, isNext = isNext, icon = icon },
            }
        end
    end
    self.cache = { key = key, rows = rows }
    return rows
end

-- Opens a plan on its next pick (MenuPanel focus hook).
function TalentsPanel:FocusRow(rows)
    for i, r in ipairs(rows) do if r.data.isNext then return i end end
    return nil
end

function TalentsPanel:HeaderTitle() return L("UI_TALENTS", "Talents") end

function TalentsPanel:HeaderSub()
    local b = self.panel and self:Build(self.panel.category)
    local total = b and #(b.orderedNames or {}) or 0
    return string.format("%s · %s · %d / %d", TA():GetClassFullName(self:Class()),
        b and TA():GetLocalizedBuildName(b) or "", math.min(self:Spent(), total), total)
end

function TalentsPanel:Describe(row)
    local d = row and row.data
    if not d then return {} end
    local b = d.build
    local seq = b.orderedNames or {}
    local spent = self:Spent()
    local followed = self:FollowedIdent() == b.ident
    local chips = {}
    if d.done then chips[#chips + 1] = { text = L("UI_TALENT_LEARNED", "Learned") }
    elseif d.isNext then chips[#chips + 1] = { text = L("UI_TALENT_NEXT_TAG", "Next"), accent = true }
    else chips[#chips + 1] = { text = L("UI_TALENT_LATER", "Later") } end
    if followed then chips[#chips + 1] = { text = L("UI_TALENT_FOLLOWING", "Following"), accent = true } end
    if b.suggested then chips[#chips + 1] = { text = L("UI_TALENT_SUGGESTED", "Suggested") } end

    local nextText
    if spent >= #seq then
        nextText = L("UI_TALENT_COMPLETED", "Build complete")
    else
        nextText = string.format(L("UI_TALENT_LEVEL_FMT", "Level %d: %s"), FIRST_LEVEL + spent,
            TA():GetLocalizedTalentName(seq[spent + 1]))
    end
    return {
        title = TA():GetLocalizedTalentName(d.name),
        subtitle = string.format(L("UI_TALENT_PICK_FMT", "Pick %d of %d · level %d"), d.index, #seq, d.level),
        chips = chips,
        info = {
            { L("UI_TALENT_PLAN", "Plan"), TA():GetLocalizedBuildName(b) },
            { L("UI_TALENT_CLASS", "Class"), TA():GetClassFullName(b.class) },
            { L("UI_TALENT_PROGRESS", "Progress"), string.format("%d / %d", math.min(spent, #seq), #seq) },
            { L("UI_TALENT_NEXT_LABEL", "Next point"), nextText },
        },
        primary = { text = L("UI_TALENT_APPLY", "Apply talents"), onClick = function() self:Apply(b.ident) end },
        secondary = (not followed) and { text = L("UI_TALENT_FOLLOW", "Follow this plan"), onClick = function() self:Follow(b.ident) end } or nil,
    }
end

function TalentsPanel:Attach(frame)
    if self.panel then return self.panel end
    self.panel = AR.MenuPanel:New(self)
    self.panel:Attach(frame, "AzerothRouteTalents")
    -- Open on the followed plan.
    self.panel.category = self:FollowedIdent()
    return self.panel
end

return TalentsPanel
