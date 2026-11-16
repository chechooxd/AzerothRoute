-- AzerothRoute: Party Synchronization & Native C_ChatInfo AddonComm Engine (SPEC-11 / SPEC-18)

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

function PartySync:BroadcastStepStatus(guideTitle, stepNum, isComplete, channel)
    local payload = self:FormatStatusPacket(guideTitle, stepNum, isComplete)
    if _G.C_ChatInfo and _G.C_ChatInfo.SendAddonMessage then
        _G.C_ChatInfo.SendAddonMessage(self.PREFIX, payload, channel or "PARTY")
        return true
    end
    return false
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

function PartySync:RegisterLiveEvents()
    if _G.C_ChatInfo and _G.C_ChatInfo.RegisterAddonMessagePrefix then
        _G.C_ChatInfo.RegisterAddonMessagePrefix(self.PREFIX)
    end
    if not AR.Events then return end
    AR.Events:RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, message, _, sender)
        if prefix == self.PREFIX and sender and message then
            self:OnReceivePacket(sender, message)
        end
    end)
    AR.Events:RegisterMessage("AR_STEP_CHANGED", function(_, stepNum, step)
        if AR.Progression and AR.Progression.currentGuide then
            local isDone = step and step:IsComplete() or false
            self:BroadcastStepStatus(AR.Progression.currentGuide.title, stepNum, isDone, "PARTY")
        end
    end)
end

return PartySync
