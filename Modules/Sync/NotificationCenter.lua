-- AzerothRoute: Prioritized Toast & History Notification Center (SPEC-11)

local AR = _G.AzerothRoute
local NotificationCenter = {
    queue = {},
    history = {},
}
AR.NotificationCenter = NotificationCenter

function NotificationCenter:Reset()
    self.queue = {}
    self.history = {}
end

function NotificationCenter:Push(category, message, opts)
    opts = opts or {}
    local item = {
        category = category,
        message = message,
        priority = opts.priority or 1,
        action = opts.action,
        timestamp = (_G.GetTime and _G.GetTime()) or 0,
    }
    table.insert(self.queue, item)
    table.insert(self.history, item)
    table.sort(self.queue, function(a, b)
        return a.priority > b.priority
    end)
    return item
end

function NotificationCenter:GetTopToast()
    return self.queue[1]
end

function NotificationCenter:DismissTop()
    if #self.queue > 0 then
        return table.remove(self.queue, 1)
    end
    return nil
end

return NotificationCenter
