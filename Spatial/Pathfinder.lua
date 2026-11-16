-- AzerothRoute: Multi-Hop Coroutine Dijkstra Pathfinder (SPEC-05)
-- Uses a binary min-heap over walk, fly, border, taxi, inn, portal, ship, zeppelin, tram, and hearth edges.

local AR = _G.AzerothRoute
local Pathfinder = {
    nodes = {},
    edges = {},
    bakedCache = {},
    COST_UNKNOWN_TAXI = 100000,
    COSTMOD_WALK = 1.2,
}
AR.Pathfinder = Pathfinder

-- Binary Min-Heap implementation
local MinHeap = {}
MinHeap.__index = MinHeap

function MinHeap:New()
    return setmetatable({ items = {} }, MinHeap)
end

function MinHeap:Push(nodeID, cost)
    local items = self.items
    table.insert(items, { id = nodeID, cost = cost })
    local idx = #items
    while idx > 1 do
        local parent = math.floor(idx / 2)
        if items[idx].cost < items[parent].cost then
            items[idx], items[parent] = items[parent], items[idx]
            idx = parent
        else
            break
        end
    end
end

function MinHeap:Pop()
    local items = self.items
    if #items == 0 then return nil end
    local top = items[1]
    items[1] = items[#items]
    table.remove(items)
    local idx = 1
    local count = #items
    while true do
        local left = idx * 2
        local right = left + 1
        local smallest = idx
        if left <= count and items[left].cost < items[smallest].cost then
            smallest = left
        end
        if right <= count and items[right].cost < items[smallest].cost then
            smallest = right
        end
        if smallest ~= idx then
            items[idx], items[smallest] = items[smallest], items[idx]
            idx = smallest
        else
            break
        end
    end
    return top
end

function MinHeap:IsEmpty()
    return #self.items == 0
end

function Pathfinder:Reset()
    self.nodes = {}
    self.edges = {}
    self.bakedCache = {}
end

function Pathfinder:AddNode(node)
    if not node or not node.id then return nil end
    self.nodes[node.id] = node
    self.edges[node.id] = self.edges[node.id] or {}
    return node
end

function Pathfinder:AddEdge(fromID, toID, mode, baseSeconds)
    self.edges[fromID] = self.edges[fromID] or {}
    table.insert(self.edges[fromID], {
        to = toID,
        mode = mode or "walk",
        baseSeconds = baseSeconds or 10,
    })
end

function Pathfinder:ComputeEdgeCost(fromNode, toNode, edge)
    local cost = edge.baseSeconds or 10
    if edge.mode == "walk" then
        cost = cost * self.COSTMOD_WALK
    elseif edge.mode == "taxi" then
        local srcKnown = not fromNode.taxiName or (AR.TaxiTracker and AR.TaxiTracker:KnowsTaxi(fromNode.taxiName))
        local dstKnown = not toNode.taxiName or (AR.TaxiTracker and AR.TaxiTracker:KnowsTaxi(toNode.taxiName))
        if not srcKnown or not dstKnown then
            return self.COST_UNKNOWN_TAXI
        end
    elseif edge.mode == "ship" or edge.mode == "zeppelin" then
        cost = edge.baseSeconds or 240
    elseif edge.mode == "tram" then
        cost = edge.baseSeconds or 300
    elseif edge.mode == "portal" then
        cost = edge.baseSeconds or 10
    end
    return cost
end

function Pathfinder:FindPath(startID, goalID)
    if not self.nodes[startID] or not self.nodes[goalID] then
        return { status = "failure", nodes = {} }
    end

    local dist = {}
    local prev = {}
    local prevMode = {}
    local visited = {}
    local heap = MinHeap:New()

    for id in pairs(self.nodes) do
        dist[id] = math.huge
    end
    dist[startID] = 0
    heap:Push(startID, 0)

    while not heap:IsEmpty() do
        local current = heap:Pop()
        local u = current.id
        if u == goalID then
            break
        end
        if not visited[u] then
            visited[u] = true
            local uNode = self.nodes[u]
            for _, edge in ipairs(self.edges[u] or {}) do
                local v = edge.to
                local vNode = self.nodes[v]
                if vNode and not visited[v] then
                    local weight = self:ComputeEdgeCost(uNode, vNode, edge)
                    local alt = dist[u] + weight
                    if alt < dist[v] then
                        dist[v] = alt
                        prev[v] = u
                        prevMode[v] = edge.mode
                        heap:Push(v, alt)
                    end
                end
            end
        end
        if AR.Scheduler then
            AR.Scheduler:YieldIfNeeded()
        end
    end

    if dist[goalID] == math.huge then
        return { status = "failure", nodes = {} }
    end

    local path = {}
    local curr = goalID
    while curr do
        local n = self.nodes[curr]
        table.insert(path, 1, {
            id = curr,
            type = n.type,
            mode = prevMode[curr] or "start",
            map = n.map,
            x = n.x,
            y = n.y,
            taxiName = n.taxiName,
        })
        curr = prev[curr]
    end

    return {
        status = "success",
        totalCost = dist[goalID],
        nodes = path,
    }
end

return Pathfinder
