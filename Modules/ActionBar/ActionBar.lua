-- AzerothRoute: Pre-Allocated Secure ActionBar, Quest Item Bar & Safe Targeting (SPEC-10 / SPEC-16 / SPEC-24)

local AR = _G.AzerothRoute
local ActionBar = {
    NUM_BUTTONS = 5,
    BUTTON_SIZE = 32,
    BUTTON_GAP = 4,
    GRIP_WIDTH = 10,
    BAR_PAD = 4,
    ICON_TALK = "Interface\\GossipFrame\\GossipGossipIcon",
    ICON_KILL = "Interface\\Icons\\Ability_DualWield",
    ICON_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark",
    buttons = {},
    itemButtons = {},
    barFrame = nil,
    itemBarFrame = nil,
    pendingCombatUpdate = false,
}
AR.ActionBar = ActionBar

local targetActions = { talk = true, vendor = true, trainer = true, kill = true, from = true }
local itemActionsMap = { use = true, useany = true, equip = true, cast = true }

local function inCombat()
    return _G.InCombatLockdown and _G.InCombatLockdown()
end

local function safeName(name)
    if _G.issecretvalue and _G.issecretvalue(name) then return nil end
    if type(name) ~= "string" or name == "" or name:find("[%c%[%];]") then return nil end
    return name
end

local function resolveItemIcon(itemID, itemName)
    if itemID and _G.C_Item and _G.C_Item.GetItemIconByID then
        local tex = _G.C_Item.GetItemIconByID(itemID)
        if tex then return tex end
    end
    local key = itemID or itemName
    if key and _G.GetItemIcon then
        local tex = _G.GetItemIcon(key)
        if tex then return tex end
    end
    if key and _G.C_Item and _G.C_Item.GetItemInfoInstant then
        local _, _, _, _, icon = _G.C_Item.GetItemInfoInstant(key)
        if icon then return icon end
    end
    if key and _G.GetItemInfo then
        local _, _, _, _, _, _, _, _, _, icon = _G.GetItemInfo(key)
        if icon then return icon end
    end
    return ActionBar.ICON_FALLBACK
end

local function resolveSpellIcon(spellID, spellName)
    local key = spellID or spellName
    if key and AR.Compat and AR.Compat.GetSpellInfo then
        local info = AR.Compat:GetSpellInfo(key)
        if info and info.iconID then return info.iconID end
    end
    if key and _G.GetSpellTexture then
        local tex = _G.GetSpellTexture(key)
        if tex then return tex end
    end
    return ActionBar.ICON_FALLBACK
end

function ActionBar:CanUseAutoRaidMark()
    -- WoW Forever (16001) and Midnight+ (>= 120000) block addon calls to SetRaidTarget().
    -- On those clients, raid markers must only run from secure button macrotext (/tm).
    if _G.WOW_PROJECT_CAMELOT and _G.WOW_PROJECT_ID == _G.WOW_PROJECT_CAMELOT then
        return false
    end
    if _G.GetBuildInfo then
        local _, _, _, toc = _G.GetBuildInfo()
        toc = tonumber(toc) or 0
        if toc == 16001 or toc >= 120000 then
            return false
        end
    end
    return true
end

function ActionBar:GetTargetName(goal)
    local name = goal.target
    if targetActions[goal.action] and AR.Localizers then
        name = AR.Localizers:GetTranslatedNPC(goal.npcid or goal.targetid, name)
    end
    return safeName(name)
end

function ActionBar:SaveBarPosition(dbKey, frame)
    if not frame or not frame.GetPoint then return false end
    local point, _, relPoint, x, y = frame:GetPoint()
    if point and AR.db and AR.db.global then
        AR.db.global[dbKey] = {
            point = point,
            relPoint = relPoint or point,
            x = x or 0,
            y = y or 0,
        }
        return true
    end
    return false
end

function ActionBar:RestoreBarPosition(dbKey, frame, defaultPoint)
    if not frame then return end
    frame:ClearAllPoints()
    local saved = AR.db and AR.db.global and AR.db.global[dbKey]
    if type(saved) == "table" and saved.point then
        frame:SetPoint(saved.point, _G.UIParent, saved.relPoint or saved.point, saved.x or 0, saved.y or 0)
    else
        frame:SetPoint(defaultPoint[1], _G.UIParent, defaultPoint[2], defaultPoint[3], defaultPoint[4])
    end
end

function ActionBar:CreateMovableBar(frameName, dbKey, defaultPoint)
    local bar = _G.CreateFrame("Frame", frameName, _G.UIParent)
    bar:SetSize(
        self.GRIP_WIDTH + (self.BAR_PAD * 2) + self.BUTTON_SIZE,
        self.BUTTON_SIZE + (self.BAR_PAD * 2)
    )
    self:RestoreBarPosition(dbKey, bar, defaultPoint)
    if bar.SetMovable then bar:SetMovable(true) end
    if bar.EnableMouse then bar:EnableMouse(true) end
    if bar.SetClampedToScreen then bar:SetClampedToScreen(true) end
    if bar.RegisterForDrag then bar:RegisterForDrag("LeftButton") end

    if bar.CreateTexture then
        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints(bar)
        bar.bg:SetColorTexture(0.06, 0.07, 0.10, 0.88)

        bar.grip = bar:CreateTexture(nil, "ARTWORK")
        bar.grip:SetPoint("TOPLEFT", bar, "TOPLEFT", 2, -2)
        bar.grip:SetSize(self.GRIP_WIDTH - 2, self.BUTTON_SIZE + (self.BAR_PAD * 2) - 4)
        bar.grip:SetColorTexture(0.24, 0.28, 0.38, 0.90)
    end

    bar:SetScript("OnDragStart", function(f)
        if inCombat() then return end
        if f.StartMoving then f:StartMoving() end
    end)
    bar:SetScript("OnDragStop", function(f)
        if f.StopMovingOrSizing then f:StopMovingOrSizing() end
        self:SaveBarPosition(dbKey, f)
    end)
    bar:Hide()
    return bar
end

local function createIconButton(actionBar, parentBar, pool, index, namePrefix, dbKey, hintKey)
    local btn = _G.CreateFrame("Button", namePrefix .. index, parentBar, "SecureActionButtonTemplate")
    btn:SetSize(actionBar.BUTTON_SIZE, actionBar.BUTTON_SIZE)
    if index == 1 then
        btn:SetPoint("TOPLEFT", parentBar, "TOPLEFT", actionBar.GRIP_WIDTH + actionBar.BAR_PAD, -actionBar.BAR_PAD)
    else
        btn:SetPoint("LEFT", pool[index - 1], "RIGHT", actionBar.BUTTON_GAP, 0)
    end
    btn:RegisterForClicks("AnyUp", "AnyDown")
    if btn.RegisterForDrag then btn:RegisterForDrag("LeftButton") end

    btn.background = btn:CreateTexture(nil, "BACKGROUND")
    btn.background:SetAllPoints(btn)
    btn.background:SetColorTexture(0.10, 0.12, 0.16, 0.95)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(actionBar.BUTTON_SIZE - 4, actionBar.BUTTON_SIZE - 4)
    btn.icon:SetPoint("CENTER", btn, "CENTER", 0, 0)

    -- Hidden label keeps action title synced for MagicKey/accessibility without rendering long text on the compact icon.
    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.label:SetPoint("TOP", btn, "BOTTOM", 0, -2)
    btn.label:Hide()

    btn.countText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    btn.countText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    btn.countText:SetJustifyH("RIGHT")
    btn.countText:Hide()

    btn:SetScript("OnDragStart", function()
        if inCombat() then return end
        if parentBar.StartMoving then parentBar:StartMoving() end
    end)
    btn:SetScript("OnDragStop", function()
        if parentBar.StopMovingOrSizing then parentBar:StopMovingOrSizing() end
        actionBar:SaveBarPosition(dbKey, parentBar)
    end)

    btn:SetScript("OnEnter", function(button)
        if not _G.GameTooltip or not button.actionLabel then return end
        _G.GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        local shownItemTooltip = false
        if button.itemID and _G.GameTooltip.SetItemByID then
            _G.GameTooltip:SetItemByID(button.itemID)
            shownItemTooltip = true
        elseif button.itemID and _G.GameTooltip.SetHyperlink then
            _G.GameTooltip:SetHyperlink("item:" .. tostring(button.itemID))
            shownItemTooltip = true
        else
            _G.GameTooltip:SetText(button.actionLabel)
        end
        if AR.L then
            if shownItemTooltip and _G.GameTooltip.AddLine then
                _G.GameTooltip:AddLine(" ")
            end
            _G.GameTooltip:AddLine(AR.L:Get(hintKey), 1, 1, 1, true)
        end
        _G.GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        if _G.GameTooltip then _G.GameTooltip:Hide() end
    end)

    btn:Hide()
    table.insert(pool, btn)
    return btn
end

function ActionBar:Initialize()
    if inCombat() then
        self.pendingCombatUpdate = true
        return self.buttons
    end
    if #self.buttons == self.NUM_BUTTONS and #self.itemButtons == self.NUM_BUTTONS
        and self.barFrame and self.itemBarFrame then
        return self.buttons
    end

    -- Tests reset ActionBar.buttons = {} between cases; keep container/button pools in sync.
    if #self.buttons == 0 then
        self.itemButtons = {}
        self.barFrame = self:CreateMovableBar("AzerothRouteActionBar", "actionbar_pos", { "RIGHT", "RIGHT", -50, -70 })
        self.itemBarFrame = self:CreateMovableBar("AzerothRouteItemBar", "itembar_pos", { "RIGHT", "RIGHT", -50, -120 })
    else
        self.barFrame = self.barFrame or self:CreateMovableBar("AzerothRouteActionBar", "actionbar_pos", { "RIGHT", "RIGHT", -50, -70 })
        self.itemBarFrame = self.itemBarFrame or self:CreateMovableBar("AzerothRouteItemBar", "itembar_pos", { "RIGHT", "RIGHT", -50, -120 })
    end

    for i = #self.buttons + 1, self.NUM_BUTTONS do
        createIconButton(self, self.barFrame, self.buttons, i, "AzerothRouteAB", "actionbar_pos", "UI_TARGET_CLICK_HINT")
    end
    for i = #self.itemButtons + 1, self.NUM_BUTTONS do
        createIconButton(self, self.itemBarFrame, self.itemButtons, i, "AzerothRouteItemAB", "itembar_pos", "UI_ITEM_CLICK_HINT")
    end
    return self.buttons
end

function ActionBar:BuildMacroForGoal(goal)
    if not goal then return nil end
    if goal.action == "use" or goal.action == "useany" then
        if goal.targetid then
            return "/use item:" .. tostring(goal.targetid)
        elseif safeName(goal.target) then
            return "/use " .. goal.target
        end
    elseif goal.action == "cast" and safeName(goal.target) then
        return "/cast " .. goal.target
    elseif goal.action == "equip" then
        if goal.targetid then
            return "/equip item:" .. tostring(goal.targetid)
        elseif safeName(goal.target) then
            return "/equip " .. goal.target
        end
    elseif targetActions[goal.action] then
        local name = self:GetTargetName(goal)
        if not name then return nil end
        local enemy = goal.action == "kill" or goal.action == "from"
        -- Clear the previous target before searching: a failed lookup must not mark it.
        return "/cleartarget\n/targetexact " .. name
            .. (enemy and "\n/cleartarget [dead]\n/tm 8" or "\n/tm 1")
    end
    return nil
end

local function collectStepGoals(step)
    local goals = {}
    if step and step.goals then
        for _, g in ipairs(step.goals) do
            table.insert(goals, g)
        end
    end
    if AR.Progression and AR.Progression.GetActiveStickies then
        for _, sticky in ipairs(AR.Progression:GetActiveStickies() or {}) do
            for _, g in ipairs(sticky.goals or {}) do
                table.insert(goals, g)
            end
        end
    end
    return goals
end

local function addItemEntry(itemActions, seenItems, kind, name, id)
    if not name and not id then return end
    if name and not safeName(name) then return end
    local macro
    if kind == "equip" then
        macro = id and ("/equip item:" .. tostring(id)) or ("/equip " .. name)
    elseif kind == "cast" then
        macro = "/cast " .. name
    else
        macro = id and ("/use item:" .. tostring(id)) or ("/use " .. name)
    end
    if seenItems[macro] then return end
    seenItems[macro] = true

    local displayName = name
    local icon, count = nil, nil
    if kind == "cast" then
        icon = resolveSpellIcon(id, name)
    else
        if id and AR.Localizers and AR.Localizers.GetTranslatedItem then
            displayName = AR.Localizers:GetTranslatedItem(id, displayName)
        end
        icon = resolveItemIcon(id, displayName)
        if id and AR.Compat and AR.Compat.GetItemCount then
            count = AR.Compat:GetItemCount(id, false)
        end
    end
    local label = (AR.L and AR.L:Format("UI_QUEST_ITEM_LABEL", displayName or ("item:" .. tostring(id))))
        or ("Use " .. tostring(displayName or id))
    table.insert(itemActions, {
        macro = macro,
        label = label,
        icon = icon,
        itemID = (kind ~= "cast") and id or nil,
        count = count,
    })
end

local function applyButtonPool(barFrame, pool, entries, actionBar)
    local visible = 0
    for i = 1, actionBar.NUM_BUTTONS do
        local btn = pool[i]
        if btn then
            local entry = entries[i]
            local macro = entry and entry.macro or nil
            if btn:GetAttribute("macrotext1") ~= macro or btn:GetAttribute("macrotext") ~= macro then
                btn:SetAttribute("type", macro and "macro" or nil)
                btn:SetAttribute("macrotext", macro)
                btn:SetAttribute("macrotext1", macro)
            end
            if btn:GetAttribute("itemid") ~= (entry and entry.itemID or nil) then
                btn:SetAttribute("itemid", entry and entry.itemID or nil)
            end
            if entry then
                visible = visible + 1
                btn.itemID = entry.itemID
                if btn.actionLabel ~= entry.label then
                    btn.actionLabel = entry.label
                    btn.label:SetText(entry.label)
                end
                btn.label:Hide()
                btn.icon:SetTexture(entry.icon)
                if entry.count ~= nil then
                    if entry.count > 1 then
                        btn.countText:SetText(tostring(entry.count))
                        btn.countText:Show()
                    else
                        btn.countText:Hide()
                    end
                    if btn.SetAlpha then
                        btn:SetAlpha(entry.count == 0 and 0.45 or 1.0)
                    end
                else
                    btn.countText:Hide()
                    if btn.SetAlpha then btn:SetAlpha(1.0) end
                end
                if not btn:IsShown() then btn:Show() end
            else
                btn.itemID = nil
                btn.actionLabel = nil
                btn.countText:Hide()
                if not btn:IsShown() then
                    -- already hidden
                else
                    btn:Hide()
                end
            end
        end
    end

    if barFrame then
        if visible > 0 then
            local width = actionBar.GRIP_WIDTH
                + (actionBar.BAR_PAD * 2)
                + (visible * actionBar.BUTTON_SIZE)
                + (math.max(0, visible - 1) * actionBar.BUTTON_GAP)
            barFrame:SetSize(width, actionBar.BUTTON_SIZE + (actionBar.BAR_PAD * 2))
            if barFrame.grip then
                barFrame.grip:SetSize(actionBar.GRIP_WIDTH - 2, actionBar.BUTTON_SIZE + (actionBar.BAR_PAD * 2) - 4)
            end
            if not barFrame:IsShown() then barFrame:Show() end
        else
            if barFrame:IsShown() then barFrame:Hide() end
        end
    end
end

function ActionBar:UpdateFromCurrentStep()
    if inCombat() then
        self.pendingCombatUpdate = true
        return false
    end
    self.pendingCombatUpdate = false
    self:Initialize()

    local step = AR.Progression and AR.Progression.currentStep
    local targets, seenTargets = {}, {}
    local itemEntries, seenItems = {}, {}

    for _, g in ipairs(collectStepGoals(step)) do
        local status = g:GetStatus()
        if status ~= "complete" and status ~= "hidden" and status ~= "obsolete" then
            if targetActions[g.action] and #targets < self.NUM_BUTTONS then
                local m = self:BuildMacroForGoal(g)
                if m and not seenTargets[m] then
                    seenTargets[m] = true
                    local name = self:GetTargetName(g)
                    local enemy = g.action == "kill" or g.action == "from"
                    table.insert(targets, {
                        macro = m,
                        label = AR.L and AR.L:Format("UI_TARGET_NAME", name) or name,
                        icon = enemy and self.ICON_KILL or self.ICON_TALK,
                    })
                end
            elseif itemActionsMap[g.action] and #itemEntries < self.NUM_BUTTONS then
                addItemEntry(itemEntries, seenItems, g.action, g.target, g.targetid or g.spellid)
            end

            -- Capture inline |use, |equip, |cast modifiers attached to accept/kill/collect goals.
            if (g.useitem or g.useitemid) and #itemEntries < self.NUM_BUTTONS then
                addItemEntry(itemEntries, seenItems, "use", g.useitem, g.useitemid)
            end
            if (g.equipitem or g.equipitemid) and #itemEntries < self.NUM_BUTTONS then
                addItemEntry(itemEntries, seenItems, "equip", g.equipitem, g.equipitemid)
            end
            if (g.castspell or g.castspellid) and #itemEntries < self.NUM_BUTTONS then
                addItemEntry(itemEntries, seenItems, "cast", g.castspell, g.castspellid)
            end
        end
    end

    applyButtonPool(self.barFrame, self.buttons, targets, self)
    applyButtonPool(self.itemBarFrame, self.itemButtons, itemEntries, self)
    return true
end

function ActionBar:OnCombatEnd()
    if self.pendingCombatUpdate then
        self:UpdateFromCurrentStep()
    end
end

local function parseUnitNpcID(unit)
    local guid = _G.UnitGUID and _G.UnitGUID(unit)
    if type(guid) ~= "string" then return nil end
    return tonumber(guid:match("Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
        or tonumber(guid:match("%-(%d+)%-[^%-]+$"))
end

function ActionBar:MarkMatchingUnit(unit)
    if not unit then return false end
    if not self:CanUseAutoRaidMark() then return false end
    if AR.db and AR.db.global and AR.db.global.automark == false then return false end
    if _G.IsInGroup and _G.IsInGroup() then
        local canMark = (_G.UnitIsGroupLeader and _G.UnitIsGroupLeader("player"))
            or (_G.UnitIsGroupAssistant and _G.UnitIsGroupAssistant("player"))
        if not canMark then return false end
    end
    if _G.UnitIsDead and _G.UnitIsDead(unit) then return false end
    if _G.GetRaidTargetIndex and _G.GetRaidTargetIndex(unit) then return false end

    local unitName = _G.UnitName and _G.UnitName(unit)
    if type(unitName) ~= "string" or unitName == "" or unitName == "Unknown" then return false end
    local unitNpcID = parseUnitNpcID(unit)

    local goals = collectStepGoals(AR.Progression and AR.Progression.currentStep)
    local lowerUnit = unitName:lower()
    for _, g in ipairs(goals) do
        local status = g:GetStatus()
        if status ~= "complete" and status ~= "hidden" and targetActions[g.action] then
            local goalNpcID = g.npcid or g.targetid
            local targetName = self:GetTargetName(g)
            local rawName = safeName(g.target)
            local matched = (goalNpcID and unitNpcID and goalNpcID == unitNpcID)
                or (targetName and lowerUnit == targetName:lower())
                or (rawName and lowerUnit == rawName:lower())
            if matched then
                if _G.SetRaidTarget then
                    local enemy = g.action == "kill" or g.action == "from"
                    _G.SetRaidTarget(unit, enemy and 8 or 1)
                end
                return true
            end
        end
    end
    return false
end

function ActionBar:RegisterLiveEvents()
    if not AR.Events then return end
    -- Events:Reset replaces the handler tables in the headless harness.
    if self._eventHandlers == AR.Events.eventHandlers then return end
    self._eventHandlers = AR.Events.eventHandlers
    AR.Events:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        self:OnCombatEnd()
    end)
    AR.Events:RegisterEvent("BAG_UPDATE_DELAYED", function()
        self:UpdateFromCurrentStep()
    end)
    AR.Events:RegisterEvent("BAG_UPDATE", function()
        self:UpdateFromCurrentStep()
    end)
    AR.Events:RegisterEvent("PLAYER_TARGET_CHANGED", function()
        self:MarkMatchingUnit("target")
    end)
    AR.Events:RegisterEvent("UPDATE_MOUSEOVER_UNIT", function()
        self:MarkMatchingUnit("mouseover")
    end)
    AR.Events:RegisterMessage("AR_STEP_CHANGED", function()
        self:UpdateFromCurrentStep()
    end)
    -- Goal status and NPC cache changes can occur without a step transition.
    -- Polling avoids reentrant updates when name resolution broadcasts a message.
    AR.Events:SubscribeUpdate("actionbar_refresh", 0.2, function()
        self:UpdateFromCurrentStep()
    end)
end

return ActionBar
