-- AzerothRoute: Party Synchronization & Magnetic Step Hold Engine (SPEC-11)

local AR = _G.AzerothRoute
local PartySync = {
    PREFIX = "ARSync1",
    magneticHold = false,
    peers = {}, -- { [sender] = { guide = ..., stepNum = ..., isComplete = ... } }
}
AR.PartySync = PartySync

function PartySync:Reset()
    self.magneticHold = false
    self.peers = {}
end

function PartySync:FormatStatusPacket(guideTitle, stepNum, isComplete)
    return string.format("GS:%s:%d:%d", tostring(guideTitle or ""), tonumber(stepNum) or 1, isComplete and 1 or 0)
end

function PartySync:OnReceivePacket(sender, packet)
    if not sender or not packet then return end
    local guideTitle, stepStr, doneStr = packet:match("^GS:(.-):(%d+):(%d+)$")
    if guideTitle then
        self.peers[sender] = {
            guide = guideTitle,
            stepNum = tonumber(stepStr) or 1,
            isComplete = (tonumber(doneStr) == 1),
        }
    end
end

function PartySync:CanPartyAdvanceStep(stepNum)
    if not self.magneticHold then
        return true
    end
    for _, state in pairs(self.peers) do
        if state.stepNum == stepNum and not state.isComplete then
            return false
        end
    end
    return true
end

return PartySync
