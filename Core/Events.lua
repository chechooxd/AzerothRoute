-- AzerothRoute: Event & Message Multiplexer + UpdateCentral (SPEC-01)

local AR = _G.AzerothRoute
local Events = {
    eventHandlers = {},
    messageHandlers = {},
    updateSubscribers = {},
    frame = nil,
}
AR.Events = Events

function Events:EnsureFrame()
    if self.frame then return self.frame end
    local f = _G.CreateFrame("Frame", "AzerothRouteEventFrame")
    f:SetScript("OnEvent", function(_, event, ...)
        Events:DispatchEvent(event, ...)
    end)
    f:SetScript("OnUpdate", function(_, elapsed)
        Events:DispatchUpdate(elapsed or 0.016)
    end)
    self.frame = f
    return f
end

function Events:Reset()
    self.eventHandlers = {}
    self.messageHandlers = {}
    self.updateSubscribers = {}
    self.frame = nil
    self:EnsureFrame()
end

function Events:RegisterEvent(event, handler)
    local f = self:EnsureFrame()
    if not self.eventHandlers[event] then
        self.eventHandlers[event] = {}
        f:RegisterEvent(event)
    end
    table.insert(self.eventHandlers[event], handler)
end

function Events:DispatchEvent(event, ...)
    local list = self.eventHandlers[event]
    if not list then return end
    for i = 1, #list do
        local h = list[i]
        if type(h) == "function" then
            h(event, ...)
        elseif type(h) == "table" and h.obj and h.method then
            h.obj[h.method](h.obj, event, ...)
        end
    end
end

function Events:RegisterMessage(msg, handler)
    if not self.messageHandlers[msg] then
        self.messageHandlers[msg] = {}
    end
    table.insert(self.messageHandlers[msg], handler)
end

function Events:SendMessage(msg, ...)
    local list = self.messageHandlers[msg]
    if not list then return end
    for i = 1, #list do
        local h = list[i]
        if type(h) == "function" then
            h(msg, ...)
        elseif type(h) == "table" and h.obj and h.method then
            h.obj[h.method](h.obj, msg, ...)
        end
    end
end

function Events:SubscribeUpdate(name, intervalSec, callback)
    self:EnsureFrame()
    self.updateSubscribers[name] = {
        interval = intervalSec or 0,
        elapsed = 0,
        callback = callback,
    }
end

function Events:UnsubscribeUpdate(name)
    self.updateSubscribers[name] = nil
end

function Events:DispatchUpdate(elapsed)
    for _, sub in pairs(self.updateSubscribers) do
        sub.elapsed = sub.elapsed + elapsed
        if sub.elapsed >= sub.interval then
            local dt = sub.elapsed
            sub.elapsed = 0
            sub.callback(dt)
        end
    end
end

return Events
