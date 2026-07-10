local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")

local ZombieNavigator = {}
ZombieNavigator.__index = ZombieNavigator

local ROUTE_CELL_SIZE = 28
local ROUTE_Y_CELL_SIZE = 10
local SHARED_REPATH_INTERVAL = 0.85
local FAILED_REPATH_INTERVAL = 0.45
local TARGET_REPATH_DISTANCE = 7
local ANCHOR_REPATH_DISTANCE = 9
local SEPARATION_REFRESH_INTERVAL = 0.12
local ROUTE_CACHE_TTL = 8
local MAX_ROUTE_CACHE_ENTRIES = 24
local FORCE_REPATH_COOLDOWN = 0.2

local routeCache = {}

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

local function getZombiesFolder()
	return Workspace:FindFirstChild("Zombies")
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

local function bucket(value, cellSize)
	return math.floor((value / cellSize) + 0.5)
end

local function getRouteKey(startPosition, targetPosition)
	return table.concat({
		bucket(startPosition.X, ROUTE_CELL_SIZE),
		bucket(startPosition.Y, ROUTE_Y_CELL_SIZE),
		bucket(startPosition.Z, ROUTE_CELL_SIZE),
		bucket(targetPosition.X, ROUTE_CELL_SIZE),
		bucket(targetPosition.Y, ROUTE_Y_CELL_SIZE),
		bucket(targetPosition.Z, ROUTE_CELL_SIZE),
	}, ":")
end

local function clearRouteConnection(route)
	if route.BlockedConnection then
		route.BlockedConnection:Disconnect()
		route.BlockedConnection = nil
	end
end

local function removeRoute(key)
	local route = routeCache[key]
	if not route then
		return
	end

	clearRouteConnection(route)
	routeCache[key] = nil
end

local function cleanupRouteCache(now)
	local count = 0
	local oldestKey = nil
	local oldestUsedAt = math.huge

	for key, route in routeCache do
		count += 1

		if now - route.LastUsedAt > ROUTE_CACHE_TTL then
			removeRoute(key)
		elseif route.LastUsedAt < oldestUsedAt then
			oldestKey = key
			oldestUsedAt = route.LastUsedAt
		end
	end

	if count > MAX_ROUTE_CACHE_ENTRIES and oldestKey then
		removeRoute(oldestKey)
	end
end

local function createRoute(key)
	local route = {
		Key = key,
		Id = 0,
		Points = {},
		Actions = {},
		TargetPosition = nil,
		AnchorPosition = nil,
		NextRefreshAt = 0,
		FailedUntil = 0,
		LastComputedAt = 0,
		LastForceAt = 0,
		LastUsedAt = os.clock(),
		Computing = false,
		BlockedConnection = nil,
		Path = nil,
	}

	routeCache[key] = route
	return route
end

local function shouldRefreshRoute(route, anchorPosition, targetPosition, force)
	if force or #route.Points == 0 then
		return true
	end

	local now = os.clock()
	if now < route.NextRefreshAt then
		return false
	end

	if not route.TargetPosition or not route.AnchorPosition then
		return true
	end

	local targetMoved = flat(targetPosition - route.TargetPosition).Magnitude >= TARGET_REPATH_DISTANCE
	local anchorMoved = flat(anchorPosition - route.AnchorPosition).Magnitude >= ANCHOR_REPATH_DISTANCE
	if targetMoved or anchorMoved then
		return true
	end

	route.NextRefreshAt = now + SHARED_REPATH_INTERVAL
	return false
end

local function buildRobloxPath(config, anchorPosition, targetPosition)
	local path = PathfindingService:CreatePath({
		AgentRadius = config.AgentRadius,
		AgentHeight = config.AgentHeight,
		AgentCanJump = false,
		AgentCanClimb = config.AgentCanClimb,
		WaypointSpacing = config.PathWaypointSpacing,
		Costs = config.PathCosts,
	})

	local success = pcall(function()
		path:ComputeAsync(anchorPosition, targetPosition)
	end)

	if not success or path.Status ~= Enum.PathStatus.Success then
		return nil, { targetPosition }, {}
	end

	local points = {}
	local actions = {}

	for index, waypoint in path:GetWaypoints() do
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			return nil, { targetPosition }, {}
		end

		if index > 1 then
			table.insert(points, waypoint.Position)
			table.insert(actions, waypoint.Action)
		end
	end

	if #points == 0 then
		table.insert(points, targetPosition)
	end

	return path, points, actions
end

local function getRoute(config, root, destination, force)
	if not root or not destination then
		return nil
	end

	local now = os.clock()
	cleanupRouteCache(now)

	local key = getRouteKey(root.Position, destination)
	local route = routeCache[key] or createRoute(key)
	route.LastUsedAt = now

	if now < route.FailedUntil and not force then
		return route
	end

	if route.Computing or not shouldRefreshRoute(route, root.Position, destination, force) then
		return route
	end

	route.Computing = true
	route.NextRefreshAt = now + SHARED_REPATH_INTERVAL

	local path, points, actions = buildRobloxPath(config, root.Position, destination)

	clearRouteConnection(route)
	route.Id += 1
	route.Path = path
	route.Points = points
	route.Actions = actions
	route.TargetPosition = destination
	route.AnchorPosition = root.Position
	route.FailedUntil = if path then 0 else now + FAILED_REPATH_INTERVAL
	route.LastComputedAt = os.clock()

	if path then
		route.BlockedConnection = path.Blocked:Connect(function()
			route.NextRefreshAt = 0
		end)
	end

	route.Computing = false
	return route
end

local function findNearestWaypointIndex(points, position, reachDistance)
	local bestIndex = 1
	local bestDistance = math.huge

	for index, point in points do
		local distance = flat(point - position).Magnitude
		if distance < bestDistance then
			bestIndex = index
			bestDistance = distance
		end
	end

	if bestIndex < #points and bestDistance <= reachDistance * 1.35 then
		bestIndex += 1
	end

	return bestIndex
end

function ZombieNavigator.new(npc, config)
	local self = setmetatable({}, ZombieNavigator)

	self.NPC = npc
	self.Config = config
	self._routeKey = nil
	self._routeId = 0
	self._pathIndex = 1
	self._avoidDirection = Vector3.zero
	self._avoidUntil = 0
	self._lastStuckCheck = os.clock()
	self._lastPosition = npc.Root and npc.Root.Position or Vector3.zero
	self._nextSeparationAt = 0
	self._smoothedSeparation = Vector3.zero

	return self
end

function ZombieNavigator:_getExclusions()
	local exclusions = {
		self.NPC.Model,
	}

	local zombiesFolder = getZombiesFolder()
	if zombiesFolder then
		table.insert(exclusions, zombiesFolder)
	end

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

	local now = os.clock()
	if now < self._nextSeparationAt then
		return self._smoothedSeparation
	end

	self._nextSeparationAt = now + SEPARATION_REFRESH_INTERVAL

	local zombiesFolder = getZombiesFolder()
	if not zombiesFolder then
		return Vector3.zero
	end

	local separation = Vector3.zero
	for _, model in zombiesFolder:GetChildren() do
		if model ~= self.NPC.Model and model:IsA("Model") then
			local otherRoot = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
			if otherRoot then
				local away = flat(root.Position - otherRoot.Position)
				local distance = away.Magnitude

				if distance > 0.05 and distance < self.Config.SeparationRadius then
					local strength = (self.Config.SeparationRadius - distance) / self.Config.SeparationRadius
					separation += away.Unit * strength * strength
				end
			end
		end
	end

	self._smoothedSeparation = self._smoothedSeparation:Lerp(separation, 0.28)
	return self._smoothedSeparation
end

function ZombieNavigator:_getRoutePathTarget(destination)
	local root = self.NPC.Root
	if not root then
		return destination, false
	end

	local route = getRoute(self.Config, root, destination, false)
	if not route or #route.Points == 0 then
		return destination, false
	end

	if self._routeKey ~= route.Key or self._routeId ~= route.Id then
		self._routeKey = route.Key
		self._routeId = route.Id
		self._pathIndex = findNearestWaypointIndex(route.Points, root.Position, self.Config.PathNodeReachDistance)
	end

	while self._pathIndex < #route.Points
		and flat(route.Points[self._pathIndex] - root.Position).Magnitude <= self.Config.PathNodeReachDistance
	do
		self._pathIndex += 1
	end

	if self._pathIndex >= #route.Points then
		return destination, route.Path ~= nil
	end

	return route.Points[self._pathIndex] or destination, route.Path ~= nil
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
			self:ForceRepath()
		end

		self._lastPosition = root.Position
		self._lastStuckCheck = os.clock()
	end

	local pathTarget, hasRobloxPath = self:_getRoutePathTarget(destination)
	local toPathTarget = flat(pathTarget - root.Position)
	local desiredDirection = unitOrZero(toPathTarget)

	if desiredDirection == Vector3.zero then
		return pathTarget
	end

	local avoidance = Vector3.zero
	if os.clock() < self._avoidUntil then
		avoidance = self._avoidDirection
	elseif self:_isBlocked(desiredDirection, self.Config.ObstacleFeelerDistance * 0.75) then
		self:ForceRepath()
		if not hasRobloxPath then
			avoidance = self:_getObstacleAvoidance(desiredDirection)
		end
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
	self._routeId = 0

	local route = if self._routeKey then routeCache[self._routeKey] else nil
	if not route then
		return
	end

	local now = os.clock()
	if now - route.LastForceAt < FORCE_REPATH_COOLDOWN then
		return
	end

	route.LastForceAt = now
	if now - route.LastComputedAt >= FORCE_REPATH_COOLDOWN then
		route.NextRefreshAt = 0
	else
		route.NextRefreshAt = math.min(route.NextRefreshAt, route.LastComputedAt + FORCE_REPATH_COOLDOWN)
	end
end

return ZombieNavigator
