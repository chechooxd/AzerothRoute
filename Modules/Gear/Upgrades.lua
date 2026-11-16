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

function Upgrades:EvaluateCandidate(itemLink)
    if self:IsBlacklisted(itemLink) then return nil end
    local meta = AR.ItemScore:GetItemMeta(itemLink)
    if not meta or not meta.slot then return nil end

    local newScore = AR.ItemScore:ScoreItem(itemLink)
    if newScore <= 0 then
        return { isUpgrade = false, delta = 0, slot = meta.slot }
    end

    local equippedLink = _G.MockWoW and _G.MockWoW.player and _G.MockWoW.player.equipped and _G.MockWoW.player.equipped[meta.slot]
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
