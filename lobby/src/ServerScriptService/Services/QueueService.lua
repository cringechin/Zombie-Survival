local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Queue = require(ServerScriptService.Classes.Queue)
local QueueConfig = require(ServerScriptService.Services.QueueConfig)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local Network = require(ReplicatedStorage.Shared.Network.Packets)

local QueueService = {}
QueueService.Order = 10

local ACTIVE_MAP_TITLE = "STORMBREAK LABS"
local queuesFolder = workspace:WaitForChild("Queues")
local activeQueuesByRoom = {}
local started = false

local function findQueueForPlayer(player)
	for _, queue in activeQueuesByRoom do
		if queue:HasPlayer(player) then
			return queue
		end
	end

	return nil
end

local function findJoinableQueue()
	for _, queue in activeQueuesByRoom do
		if queue.canQueue and (not queue.creator or queue:GetPlayerCount() < queue.playerLimit) then
			return queue
		end
	end

	return nil
end

local function registerRoom(room)
	if activeQueuesByRoom[room] or not room:IsA("Folder") then
		return
	end

	local missing = Queue.getMissingPieces(room)

	if #missing > 0 then
		warn(`Skipping queue room {room:GetFullName()} because it is missing: {table.concat(missing, ", ")}`)
		return
	end

	local ok, queueOrErr = pcall(function()
		return Queue.new(room, QueueConfig.forRoom(room), Network)
	end)

	if ok then
		activeQueuesByRoom[room] = queueOrErr
	else
		warn(queueOrErr)
	end
end

local function unregisterRoom(room)
	local queue = activeQueuesByRoom[room]

	if not queue then
		return
	end

	queue:Destroy()
	activeQueuesByRoom[room] = nil
end

function QueueService.start()
	if started then
		return
	end

	started = true

	for _, room in queuesFolder:GetChildren() do
		registerRoom(room)
	end

	if next(activeQueuesByRoom) == nil then
		warn("QueueService started, but no valid queue rooms were found under Workspace.Queues.")
	end

	queuesFolder.ChildAdded:Connect(registerRoom)
	queuesFolder.ChildRemoved:Connect(unregisterRoom)

	Network.queueCreate.listen(function(data, player)
		local queue = findQueueForPlayer(player)

		if not queue or queue.creator then
			return
		end

		if typeof(data) ~= "table" or data.map ~= ACTIVE_MAP_TITLE then
			Network.queueForceLeave.sendTo({
				message = "That map is still WIP.",
			}, player)
			return
		end

		if not PlayerDataService.hasEquippedDisaster(player) then
			queue:LeavePlayer(player)
			Network.queueForceLeave.sendTo({
				message = "Equip at least 1 disaster before playing.",
			}, player)
			return
		end

		queue.playerLimit = math.clamp(math.floor(data.maxPlayers), 1, queue.config.MaximumPlayers)
		queue.minimumPlayers = queue.config.MinimumPlayers
		queue.countDownTime = math.floor(queue.config.CountdownTime * (1 + (queue.playerLimit - 1) * queue.config.CountdownScalePerPlayer))
		queue.creator = player
		queue.canQueue = true
		queue.map = data.map
		queue.difficulty = data.difficulty
		queue.friendsOnly = false

		queue.timerUI.Text = `{queue.countDownTime} Seconds`
		queue:UpdateUI()
		queue:StartCountdown()
	end)

	Network.queueLeave.listen(function(_, player)
		local queue = findQueueForPlayer(player)

		if queue then
			queue:LeavePlayer(player)
		end
	end)

	Network.lobbyPlayRequest.listen(function(_, player)
		if findQueueForPlayer(player) then
			return
		end

		if not PlayerDataService.hasEquippedDisaster(player) then
			Network.queueForceLeave.sendTo({
				message = "Equip at least 1 disaster before playing.",
			}, player)
			return
		end

		local queue = findJoinableQueue()
		if queue then
			queue:AddPlayer(player)
		else
			Network.queueForceLeave.sendTo({
				message = "No queue is available right now.",
			}, player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for _, queue in activeQueuesByRoom do
			queue:LeavePlayer(player)
		end
	end)
end

return QueueService
