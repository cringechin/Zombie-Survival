local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")

local ZombieNavigator = {}
ZombieNavigator.__index = ZombieNavigator

local NEIGHBORS = {
	{ X = 1, Z = 0, Cost = 1 },
	{ X = -1, Z = 0, Cost = 1 },
	{ X = 0, Z = 1, Cost = 1 },
	{ X = 0, Z = -1, Cost = 1 },
	{ X = 1, Z = 1, Cost = 1.414 },
	{ X = 1, Z = -1, Cost = 1.414 },
	{ X = -1, Z = 1, Cost = 1.414 },
	{ X = -1, Z = -1, Cost = 1.414 },
}

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function unitOrZero(vector)
	if vector.Magnitude <= 0.001 then
		return Vector3.zero
	end

	return vector.Unit
end

local function rotate2D(vector, radians)
	local cosine = math.cos(radians)
	local sine = math.sin(radians)

	return Vector3.new((vector.X * cosine) - (vector.Z * sine), 0, (vector.X * sine) + (vector.Z * cosine))
end

local function getCharacters()
	local characters = {}

	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end

	return characters
end

function ZombieNavigator.new(npc, config)
	local self = setmetatable({}, ZombieNavigator)

	self.NPC = npc
	self.Config = config
	self._avoidDirection = Vector3.zero
	self._avoidUntil = 0
	self._lastStuckCheck = os.clock()
	self._lastPosition = npc.Root and npc.Root.Position or Vector3.zero
	self._path = {}
	self._pathIndex = 1
	self._nextRepathTime = 0
	self._lastDestination = nil
	self._blockedConnection = nil
	self._smoothedSeparation = Vector3.zero

	return self
end

function ZombieNavigator:_clearPathConnection()
	if self._blockedConnection then
		self._blockedConnection:Disconnect()
		self._blockedConnection = nil
	end
end

function ZombieNavigator:_getExclusions()
	local exclusions = {
		self.NPC.Model,
		Workspace:WaitForChild("Zombies"),
	}

	for _, character in getCharacters() do
		table.insert(exclusions, character)
	end

	return exclusions
end

function ZombieNavigator:_getRaycastParams()
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = self:_getExclusions()

	return raycastParams
end

function ZombieNavigator:_getOverlapParams()
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = self:_getExclusions()

	return overlapParams
end

function ZombieNavigator:_getGroundPosition(position)
	local origin = position + Vector3.new(0, 24, 0)
	local result = Workspace:Raycast(origin, Vector3.new(0, -140, 0), self:_getRaycastParams())

	return result and result.Position or position
end

function ZombieNavigator:_isPositionWalkable(position)
	local groundPosition = self:_getGroundPosition(position)
	local boxSize = Vector3.new(self.Config.GridSize * 0.72, 5, self.Config.GridSize * 0.72)
	local boxCFrame = CFrame.new(groundPosition + Vector3.new(0, boxSize.Y / 2 + 0.2, 0))
	local parts = Workspace:GetPartBoundsInBox(boxCFrame, boxSize, self:_getOverlapParams())

	for _, part in parts do
		if part.CanCollide and part.Transparency < 1 then
			return false
		end
	end

	return true
end

function ZombieNavigator:_hasLineOfSight(fromPosition, toPosition)
	local start = fromPosition + Vector3.new(0, 2, 0)
	local finish = toPosition + Vector3.new(0, 2, 0)
	local result = Workspace:Raycast(start, finish - start, self:_getRaycastParams())

	return result == nil
end

function ZombieNavigator:_hasWalkableLine(fromPosition, toPosition)
	if not self:_hasLineOfSight(fromPosition, toPosition) then
		return false
	end

	local delta = flat(toPosition - fromPosition)
	local distance = delta.Magnitude
	if distance <= 0.05 then
		return true
	end

	local steps = math.max(math.ceil(distance / (self.Config.GridSize * 0.5)), 1)
	local previousGround = self:_getGroundPosition(fromPosition)

	for step = 1, steps do
		local alpha = step / steps
		local samplePosition = fromPosition:Lerp(toPosition, alpha)
		local groundPosition = self:_getGroundPosition(samplePosition)

		if math.abs(groundPosition.Y - previousGround.Y) > self.Config.MaxGroundStepHeight then
			return false
		end

		if not self:_isPositionWalkable(groundPosition) then
			return false
		end

		previousGround = groundPosition
	end

	return true
end

function ZombieNavigator:_toCell(position)
	local gridSize = self.Config.GridSize

	return {
		X = math.floor((position.X / gridSize) + 0.5),
		Z = math.floor((position.Z / gridSize) + 0.5),
	}
end

function ZombieNavigator:_toWorld(cell, y)
	local gridSize = self.Config.GridSize
	local position = Vector3.new(cell.X * gridSize, y, cell.Z * gridSize)
	local ground = self:_getGroundPosition(position)

	return Vector3.new(position.X, ground.Y, position.Z)
end

local function cellKey(cell)
	return `{cell.X}:{cell.Z}`
end

local function heuristic(a, b)
	local dx = a.X - b.X
	local dz = a.Z - b.Z

	return math.sqrt((dx * dx) + (dz * dz))
end

local function popBest(open)
	local bestIndex = 1
	local bestScore = open[1].F

	for index = 2, #open do
		if open[index].F < bestScore then
			bestScore = open[index].F
			bestIndex = index
		end
	end

	local node = open[bestIndex]
	table.remove(open, bestIndex)

	return node
end

function ZombieNavigator:_reconstructPath(nodes, goalKey, y)
	local points = {}
	local currentKey = goalKey

	while currentKey do
		local node = nodes[currentKey]
		table.insert(points, 1, self:_toWorld(node.Cell, y))
		currentKey = node.Parent
	end

	return points
end

function ZombieNavigator:_smoothPath(points)
	if #points <= 2 then
		return points
	end

	local smoothed = { points[1] }
	local anchorIndex = 1

	while anchorIndex < #points do
		local nextIndex = #points

		while nextIndex > anchorIndex + 1 do
			if self:_hasWalkableLine(points[anchorIndex], points[nextIndex]) then
				break
			end

			nextIndex -= 1
		end

		table.insert(smoothed, points[nextIndex])
		anchorIndex = nextIndex
	end

	return smoothed
end

function ZombieNavigator:_findPath(startPosition, destination)
	local startCell = self:_toCell(startPosition)
	local goalCell = self:_toCell(destination)
	local startKey = cellKey(startCell)
	local goalKey = cellKey(goalCell)
	local nodes = {
		[startKey] = {
			Cell = startCell,
			G = 0,
			F = heuristic(startCell, goalCell),
			Parent = nil,
		},
	}
	local open = { nodes[startKey] }
	local closed = {}
	local searched = 0
	local bestKey = startKey
	local bestHeuristic = heuristic(startCell, goalCell)

	while #open > 0 and searched < self.Config.MaxPathNodes do
		searched += 1
		local current = popBest(open)
		local currentKey = cellKey(current.Cell)
		local currentHeuristic = heuristic(current.Cell, goalCell)

		if currentHeuristic < bestHeuristic then
			bestKey = currentKey
			bestHeuristic = currentHeuristic
		end

		if currentKey == goalKey or currentHeuristic <= 1 then
			return self:_smoothPath(self:_reconstructPath(nodes, currentKey, destination.Y))
		end

		closed[currentKey] = true

		for _, neighbor in NEIGHBORS do
			local neighborCell = {
				X = current.Cell.X + neighbor.X,
				Z = current.Cell.Z + neighbor.Z,
			}
			local neighborKey = cellKey(neighborCell)

			if not closed[neighborKey] then
				local worldPosition = self:_toWorld(neighborCell, destination.Y)
				local diagonal = neighbor.X ~= 0 and neighbor.Z ~= 0
				local canWalk = self:_isPositionWalkable(worldPosition)

				if diagonal then
					canWalk = canWalk
						and self:_isPositionWalkable(
							self:_toWorld({ X = current.Cell.X + neighbor.X, Z = current.Cell.Z }, destination.Y)
						)
						and self:_isPositionWalkable(
							self:_toWorld({ X = current.Cell.X, Z = current.Cell.Z + neighbor.Z }, destination.Y)
						)
				end

				if canWalk then
					local gScore = current.G + neighbor.Cost
					local existing = nodes[neighborKey]

					if not existing or gScore < existing.G then
						local node = existing or { Cell = neighborCell }
						node.G = gScore
						node.F = gScore + heuristic(neighborCell, goalCell)
						node.Parent = currentKey
						nodes[neighborKey] = node

						if not existing then
							table.insert(open, node)
						end
					end
				end
			end
		end
	end

	if bestKey ~= startKey then
		return self:_smoothPath(self:_reconstructPath(nodes, bestKey, destination.Y))
	end

	return {}
end

function ZombieNavigator:_refreshPath(destination)
	if os.clock() < self._nextRepathTime then
		return
	end

	self._nextRepathTime = os.clock() + self.Config.RepathInterval
	self._lastDestination = destination

	if self:_hasWalkableLine(self.NPC.Root.Position, destination) then
		self:_clearPathConnection()
		self._path = {}
		self._pathIndex = 1
		return
	end

	local path = PathfindingService:CreatePath({
		AgentRadius = self.Config.AgentRadius,
		AgentHeight = self.Config.AgentHeight,
		AgentCanJump = false,
		AgentCanClimb = self.Config.AgentCanClimb,
		WaypointSpacing = self.Config.PathWaypointSpacing,
		Costs = self.Config.PathCosts,
	})

	local success = pcall(function()
		path:ComputeAsync(self.NPC.Root.Position, destination)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		local points = {}

		for index, waypoint in waypoints do
			if index > 1 and waypoint.Action ~= Enum.PathWaypointAction.Jump then
				table.insert(points, self:_getGroundPosition(waypoint.Position))
			end
		end

		self:_clearPathConnection()
		self._blockedConnection = path.Blocked:Connect(function(blockedWaypointIndex)
			if blockedWaypointIndex >= self._pathIndex then
				self:ForceRepath()
			end
		end)

		self._path = self:_smoothPath(points)
		self._pathIndex = 1
		return
	end

	self:_clearPathConnection()
	self._path = self:_findPath(self.NPC.Root.Position, destination)
	self._pathIndex = math.min(2, #self._path)
end

function ZombieNavigator:_getPathTarget(destination)
	self:_refreshPath(destination)

	local point = self._path[self._pathIndex]
	if point and (self.NPC.Root.Position - point).Magnitude <= self.Config.PathNodeReachDistance then
		self._pathIndex += 1
		point = self._path[self._pathIndex]
	end

	return point or destination
end

function ZombieNavigator:_isBlocked(direction, distance)
	local root = self.NPC.Root
	if not root then
		return false
	end

	local origin = root.Position + Vector3.new(0, 1.8, 0)
	local result = Workspace:Raycast(origin, unitOrZero(direction) * distance, self:_getRaycastParams())

	return result ~= nil
end

function ZombieNavigator:_getObstacleAvoidance(direction)
	local feelerDistance = self.Config.ObstacleFeelerDistance

	if not self:_isBlocked(direction, feelerDistance) then
		return Vector3.zero
	end

	local left = rotate2D(direction, math.rad(58))
	local right = rotate2D(direction, math.rad(-58))
	local leftBlocked = self:_isBlocked(left, feelerDistance * 0.85)
	local rightBlocked = self:_isBlocked(right, feelerDistance * 0.85)

	if leftBlocked and not rightBlocked then
		self._avoidDirection = right
	elseif rightBlocked and not leftBlocked then
		self._avoidDirection = left
	else
		self._avoidDirection = if math.random() < 0.5 then left else right
	end

	self._avoidUntil = os.clock() + self.Config.ObstacleCommitTime
	return self._avoidDirection
end

function ZombieNavigator:_getSeparation()
	local root = self.NPC.Root
	if not root then
		return Vector3.zero
	end

	local zombiesFolder = Workspace:WaitForChild("Zombies")
	local separation = Vector3.zero

	for _, model in zombiesFolder:GetChildren() do
		if model ~= self.NPC.Model and model:IsA("Model") then
			local otherRoot = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
			if otherRoot then
				local away = flat(root.Position - otherRoot.Position)
				local distance = away.Magnitude

				if distance > 0.05 and distance < self.Config.SeparationRadius then
					separation += away.Unit * ((self.Config.SeparationRadius - distance) / self.Config.SeparationRadius)
				end
			end
		end
	end

	self._smoothedSeparation = self._smoothedSeparation:Lerp(separation, 0.18)
	return self._smoothedSeparation
end

function ZombieNavigator:GetMovePosition(destination)
	local root = self.NPC.Root
	if not root then
		return destination
	end

	if os.clock() - self._lastStuckCheck >= self.Config.StuckCheckInterval then
		local movedDistance = flat(root.Position - self._lastPosition).Magnitude

		if movedDistance < self.Config.StuckDistance then
			local toDestination = unitOrZero(flat(destination - root.Position))
			self._avoidDirection = rotate2D(toDestination, if math.random() < 0.5 then math.rad(90) else math.rad(-90))
			self._avoidUntil = os.clock() + self.Config.StuckAvoidanceTime
			self._nextRepathTime = 0
		end

		self._lastPosition = root.Position
		self._lastStuckCheck = os.clock()
	end

	local pathTarget = self:_getPathTarget(destination)
	local toPathTarget = flat(pathTarget - root.Position)
	local desiredDirection = unitOrZero(toPathTarget)

	if desiredDirection == Vector3.zero then
		return pathTarget
	end

	local hasPath = #self._path > 0
	local avoidance = Vector3.zero

	if hasPath then
		if self:_isBlocked(desiredDirection, self.Config.ObstacleFeelerDistance * 0.75) then
			self:ForceRepath()
		end
	elseif os.clock() < self._avoidUntil then
		avoidance = self._avoidDirection
	else
		avoidance = self:_getObstacleAvoidance(desiredDirection)
	end

	local separation = self:_getSeparation()
	local steeringDirection = desiredDirection
		+ (unitOrZero(avoidance) * self.Config.ObstacleAvoidanceWeight)
		+ (unitOrZero(separation) * self.Config.SeparationWeight)

	if steeringDirection.Magnitude <= 0.001 then
		steeringDirection = desiredDirection
	end

	local stepDistance = math.min(self.Config.MoveLookaheadDistance, math.max(toPathTarget.Magnitude, 2))
	local movePosition = root.Position + (steeringDirection.Unit * stepDistance)

	return Vector3.new(movePosition.X, pathTarget.Y, movePosition.Z)
end

function ZombieNavigator:ForceRepath()
	self._nextRepathTime = 0
end

return ZombieNavigator
