local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Queue = {}
Queue.__index = Queue

local REQUIRED_REFS = {
	"CamPos",
	"Enter",
	"EnterPos",
	"ExitPos",
	"UI",
}

local function getPlayerCount(folder)
	return #folder:GetChildren()
end

local function getPlayerFromQueueValue(value)
	return Players:GetPlayerByUserId(value.Value)
end

local function pivotPlayerTo(player, targetCFrame)
	local character = player.Character
	local primaryPart = character and character.PrimaryPart

	if primaryPart then
		primaryPart:PivotTo(targetCFrame)
	end
end

local function getCharacterRoot(player)
	local character = player.Character

	return character and character:FindFirstChild("HumanoidRootPart")
end

local function isPlayerInsidePart(player, part)
	local root = getCharacterRoot(player)

	if not root then
		return false
	end

	local localPosition = part.CFrame:PointToObjectSpace(root.Position)
	local halfSize = part.Size / 2

	return math.abs(localPosition.X) <= halfSize.X + 1
		and math.abs(localPosition.Y) <= math.max(halfSize.Y + 4, 5)
		and math.abs(localPosition.Z) <= halfSize.Z + 1
end

local function setupBillboard(billboard, playersUI, timerUI)
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(220, 90)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)

	playersUI.BackgroundTransparency = 1
	playersUI.Font = Enum.Font.GothamBold
	playersUI.Position = UDim2.fromScale(0, 0)
	playersUI.Size = UDim2.fromScale(1, 0.5)
	playersUI.TextColor3 = Color3.fromRGB(240, 248, 242)
	playersUI.TextScaled = true

	timerUI.BackgroundTransparency = 1
	timerUI.Font = Enum.Font.Gotham
	timerUI.Position = UDim2.fromScale(0, 0.5)
	timerUI.Size = UDim2.fromScale(1, 0.5)
	timerUI.TextColor3 = Color3.fromRGB(201, 218, 205)
	timerUI.TextScaled = true
end

local function findMissingPieces(room)
	local missing = {}
	local refs = room:FindFirstChild("Refs")

	if not room:FindFirstChild("InQueue") then
		table.insert(missing, "InQueue")
	end

	if not refs then
		table.insert(missing, "Refs")
		return missing
	end

	for _, refName in REQUIRED_REFS do
		if not refs:FindFirstChild(refName) then
			table.insert(missing, `Refs.{refName}`)
		end
	end

	local ui = refs:FindFirstChild("UI")
	local billboard = ui and ui:FindFirstChild("BillboardGui")

	if not billboard then
		table.insert(missing, "Refs.UI.BillboardGui")
	else
		if not billboard:FindFirstChild("Players") then
			table.insert(missing, "Refs.UI.BillboardGui.Players")
		end

		if not billboard:FindFirstChild("Time") then
			table.insert(missing, "Refs.UI.BillboardGui.Time")
		end
	end

	return missing
end

function Queue.canCreate(room)
	return #findMissingPieces(room) == 0
end

function Queue.getMissingPieces(room)
	return findMissingPieces(room)
end

function Queue.new(room, config, network)
	local missing = findMissingPieces(room)

	if #missing > 0 then
		error(`Queue room {room:GetFullName()} is missing {table.concat(missing, ", ")}`)
	end

	local self = setmetatable({}, Queue)

	self.room = room
	self.config = config
	self.network = network
	self.refs = room.Refs
	self.inQueue = room.InQueue
	self.connections = {}

	local billboard = self.refs.UI.BillboardGui
	self.playersUI = billboard.Players
	self.timerUI = billboard.Time
	setupBillboard(billboard, self.playersUI, self.timerUI)

	self.reservedServer = nil
	self.playerLimit = config.MaximumPlayers
	self.countDownTime = nil
	self.minimumPlayers = nil
	self.creator = nil
	self.friendsOnly = false
	self.map = nil
	self.difficulty = nil
	self.canQueue = true
	self.counting = false
	self.touchDebounce = false
	self.destroyed = false
	self.lastZoneCheck = 0

	self:ReserveNewServer()
	self:Reset()
	self:BindEvents()
	print(`Registered lobby queue: {room:GetFullName()}`)

	return self
end

function Queue:ReserveNewServer()
	if RunService:IsStudio() or self.config.GameplayPlaceId <= 0 then
		return
	end

	local ok, reservedServer = pcall(function()
		return TeleportService:ReserveServer(self.config.GameplayPlaceId)
	end)

	if ok then
		self.reservedServer = reservedServer
	else
		warn(`Failed to reserve gameplay server for {self.room.Name}: {reservedServer}`)
	end
end

function Queue:GetPlayerCount()
	return getPlayerCount(self.inQueue)
end

function Queue:HasPlayer(player)
	return self.inQueue:FindFirstChild(player.Name) ~= nil
end

function Queue:UpdateUI()
	local countSuffix = self.friendsOnly and " (Friends)" or ""

	self.playersUI.Text = if self.creator
		then `{self:GetPlayerCount()}/{self.playerLimit}{countSuffix}`
		else "Creating..."
end

function Queue:CancelThread(thread)
	if thread and coroutine.status(thread) ~= "dead" then
		task.cancel(thread)
	end
end

function Queue:ReleaseAllPlayers(message)
	for _, queuedPlayer in self.inQueue:GetChildren() do
		local player = getPlayerFromQueueValue(queuedPlayer)

		if player then
			pivotPlayerTo(player, self.refs.ExitPos.CFrame)
			self.network.queueForceLeave.sendTo({
				message = message or "",
			}, player)
		end

		queuedPlayer:Destroy()
	end
end

function Queue:Reset()
	self:CancelThread(self._creationCountdown)
	self:CancelThread(self._countdown)
	self:ReleaseAllPlayers()

	self._creationCountdown = nil
	self._countdown = nil
	self.canQueue = true
	self.counting = false
	self.playerLimit = self.config.MaximumPlayers
	self.friendsOnly = false
	self.countDownTime = nil
	self.minimumPlayers = nil
	self.creator = nil
	self.timerUI.Text = " "
	self.map = nil
	self.difficulty = nil
	self.playersUI.Text = `0/{self.config.MaximumPlayers}`
end

function Queue:StartCountdown()
	if self.counting or not self.creator then
		return
	end

	if self:GetPlayerCount() < self.minimumPlayers then
		self.timerUI.Text = "Waiting for players..."
		return
	end

	self.counting = true
	self._countdown = task.spawn(function()
		local secondsRemaining = self.countDownTime

		while not self.destroyed and self.minimumPlayers <= self:GetPlayerCount() do
			local isFull = self:GetPlayerCount() == self.playerLimit
			task.wait(isFull and 1 / self.config.FullQueueSpeedMultiplier or 1)

			secondsRemaining -= 1
			self.timerUI.Text = `{math.max(secondsRemaining, 0)} Seconds`
			self:UpdateUI()

			local shouldTeleport = secondsRemaining <= 0
				or (isFull and self.config.InstantTeleportWhenFull)

			if shouldTeleport then
				self.timerUI.Text = "Teleporting..."
				self.canQueue = false

				if not self:TeleportQueue() then
					task.wait(2)
					self:Reset()
					return
				end

				repeat
					task.wait()
				until self.destroyed or self:GetPlayerCount() == 0

				if not self.destroyed then
					self:ReserveNewServer()
					self:Reset()
				end

				return
			end
		end

		self.counting = false
		self.timerUI.Text = "Waiting for players..."
	end)
end

function Queue:TeleportQueue()
	if self.config.GameplayPlaceId <= 0 then
		self.timerUI.Text = "Set GameplayPlaceId"
		warn(`Set GameplayPlaceId before teleporting players from {self.room.Name}.`)
		return false
	end

	local party = {}

	for _, queuedPlayer in self.inQueue:GetChildren() do
		local player = getPlayerFromQueueValue(queuedPlayer)

		if player then
			table.insert(party, player)
		end
	end

	if #party == 0 then
		return false
	end

	local ok, err = pcall(function()
		if self.reservedServer then
			TeleportService:TeleportToPrivateServer(self.config.GameplayPlaceId, self.reservedServer, party, "")
		else
			TeleportService:TeleportAsync(self.config.GameplayPlaceId, party)
		end
	end)

	if ok then
		print(`Successfully initiated teleport for {#party} players from {self.room.Name}.`)
		return true
	end

	warn(`Teleport failed for {self.room.Name}: {err}`)
	self.timerUI.Text = "Teleport Failed!"
	return false
end

function Queue:LeavePlayer(player)
	local queuedPlayer = self.inQueue:FindFirstChild(player.Name)

	if not queuedPlayer then
		return false
	end

	queuedPlayer:Destroy()
	pivotPlayerTo(player, self.refs.ExitPos.CFrame)
	self.network.queueForceLeave.sendTo({
		message = "",
	}, player)

	if self.creator == player then
		self:Reset()
	elseif self:GetPlayerCount() == 0 then
		self:Reset()
	else
		self:UpdateUI()
		self:StartCountdown()
	end

	return true
end

function Queue:IsPlayerFriendsWithCreator(character)
	local player = Players:GetPlayerFromCharacter(character)

	if not player or not self.creator then
		return false
	end

	local ok, result = pcall(function()
		return player:IsFriendsWith(self.creator.UserId)
	end)

	if ok then
		return result
	end

	warn(`Failed to check friendship status: {result}`)
	return false
end

function Queue:AddPlayer(player)
	if not player or not player.Character then
		return
	end

	if self:HasPlayer(player) then
		return
	end

	if self.creator and self:GetPlayerCount() >= self.playerLimit then
		return
	end

	if self.creator and self.friendsOnly and not self:IsPlayerFriendsWithCreator(player.Character) then
		return
	end

	pivotPlayerTo(player, self.refs.EnterPos.CFrame)

	local newPlayer = Instance.new("IntValue")
	newPlayer.Name = player.Name
	newPlayer.Value = player.UserId
	newPlayer.Parent = self.inQueue

	if not self.creator then
		self.canQueue = false
		self.playersUI.Text = "Setting Up..."
		self.timerUI.Text = "Choose mission"
		self.network.queuePrompt.sendTo({
			cameraCFrame = self.refs.CamPos.CFrame,
			isCreator = true,
			maxPlayers = self.config.MaximumPlayers,
		}, player)
	else
		self:UpdateUI()
		self.network.queuePrompt.sendTo({
			cameraCFrame = self.refs.CamPos.CFrame,
			isCreator = false,
			maxPlayers = self.playerLimit,
		}, player)
		self:StartCountdown()
	end
end

function Queue:BindEvents()
	self.refs.Enter.CanTouch = true

	table.insert(self.connections, self.refs.Enter.Touched:Connect(function(other)
		if not self.canQueue or self.touchDebounce then
			return
		end

		local character = other.Parent

		if not character or not character:FindFirstChild("Humanoid") then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)

		if not player then
			return
		end

		self.touchDebounce = true
		self:AddPlayer(player)
		task.wait(0.5)
		self.touchDebounce = false
	end))

	table.insert(self.connections, RunService.Heartbeat:Connect(function()
		if not self.canQueue or self.touchDebounce then
			return
		end

		local now = os.clock()

		if now - self.lastZoneCheck < 0.2 then
			return
		end

		self.lastZoneCheck = now

		for _, player in Players:GetPlayers() do
			if not self:HasPlayer(player) and isPlayerInsidePart(player, self.refs.Enter) then
				self.touchDebounce = true
				self:AddPlayer(player)
				task.delay(0.5, function()
					if not self.destroyed then
						self.touchDebounce = false
					end
				end)
				return
			end
		end
	end))
end

function Queue:Destroy()
	self.destroyed = true
	self:CancelThread(self._creationCountdown)
	self:CancelThread(self._countdown)
	self:ReleaseAllPlayers()

	for _, connection in self.connections do
		connection:Disconnect()
	end

	table.clear(self.connections)
end

return Queue
