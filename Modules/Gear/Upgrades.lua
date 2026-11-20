-- AzerothRoute: Bag Upgrade Detector & Queue Manager (SPEC-08)

local AR = _G.AzerothRoute
local Upgrades = {
    upgradeQueue = {},
}
AR.Upgrades = Upgrades

function Upgrades:Reset()
    self.upgradeQueue = {}
end

function Upgrades:IsBlacklisted(itemLink)
    return (AR.db and AR.db.char and AR.db.char.bad_upgrades and AR.db.char.bad_upgrades[itemLink] == true) or false
end

function Upgrades:RejectUpgrade(itemLink)
    if AR.db and AR.db.char then
        AR.db.char.bad_upgrades = AR.db.char.bad_upgrades or {}
        AR.db.char.bad_upgrades[itemLink] = true
    end
end

-- Inventory slot ids for an item's equip location (rings and trinkets have two slots).
Upgrades.SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 },
    INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 },
    INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}

-- The equipped item an item of `equipLoc` would replace: the weaker of a pair (empty slot first).
-- Returns the item link, or nil for an empty slot.
function Upgrades:EquippedLinkFor(equipLoc)
    local mock = _G.MockWoW and _G.MockWoW.player and _G.MockWoW.player.equipped
    if mock then return mock[equipLoc] end
    local slots = self.SLOTS[equipLoc or ""]
    if not slots or not _G.GetInventoryItemLink then return nil end
    local weakest, weakestScore
    for _, slotId in ipairs(slots) do
        local link = _G.GetInventoryItemLink("player", slotId)
        if not link then return nil end
        local score = AR.ItemScore:ScoreItem(link)
        if not weakestScore or score < weakestScore then weakest, weakestScore = link, score end
    end
    return weakest
end

function Upgrades:EvaluateCandidate(itemLink)
    if self:IsBlacklisted(itemLink) then return nil end
    local meta = AR.ItemScore:GetItemMeta(itemLink)
    if not meta or not meta.slot then return nil end

    local newScore = AR.ItemScore:ScoreItem(itemLink)
    if newScore <= 0 then
        return { isUpgrade = false, delta = 0, slot = meta.slot }
    end

    local equippedLink = self:EquippedLinkFor(meta.slot)
    local currentScore = equippedLink and AR.ItemScore:ScoreItem(equippedLink) or 0

    if newScore > currentScore then
        local result = {
            isUpgrade = true,
            itemLink = itemLink,
            slot = meta.slot,
            newScore = newScore,
            oldScore = currentScore,
            delta = newScore - currentScore,
        }
        self.upgradeQueue[meta.slot] = result
        return result
    end

    return { isUpgrade = false, delta = newScore - currentScore, slot = meta.slot }
end

return Upgrades
