-- AzerothRoute: Mount & Companion Pet Guide Detector (CreatureDetector) (SPEC-10)

local AR = _G.AzerothRoute
local CreatureDetector = {
    mountGuidesBySpell = {},
    petGuidesByNpc = {},
}
AR.CreatureDetector = CreatureDetector

function CreatureDetector:Reset()
    self.mountGuidesBySpell = {}
    self.petGuidesByNpc = {}
end

function CreatureDetector:RegisterMountGuide(spellID, guideTitle)
    self.mountGuidesBySpell[spellID] = guideTitle
end

function CreatureDetector:RegisterPetGuide(npcID, guideTitle)
    self.petGuidesByNpc[npcID] = guideTitle
end

function CreatureDetector:InspectMountSpell(spellID)
    return self.mountGuidesBySpell[spellID]
end

function CreatureDetector:InspectPetNPC(npcID)
    return self.petGuidesByNpc[npcID]
end

return CreatureDetector
