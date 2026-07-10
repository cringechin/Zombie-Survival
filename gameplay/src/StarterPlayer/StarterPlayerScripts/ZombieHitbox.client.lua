local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Network = require(ReplicatedStorage.Shared.Network.Packets)

local localPlayer = Players.LocalPlayer
local zombiesFolder = Workspace:WaitForChild("Zombies")
local reportedAttackTokens = setmetatable({}, { __mode = "k" })

local function getCharacterState()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not character or not humanoid or not root or humanoid.Health <= 0 then
		return nil, nil, nil
	end

	return character, humanoid, root
end

local function getZombieRoot(zombie)
	return zombie.PrimaryPart or zombie:FindFirstChild("HumanoidRootPart")
end

local function pointInsideHitbox(zombieRootCFrame, position, depth, width, height, backPadding)
	local localPosition = zombieRootCFrame:PointToObjectSpace(position)
	local forwardDistance = -localPosition.Z

	return forwardDistance >= -backPadding
		and forwardDistance <= depth
		and math.abs(localPosition.X) <= (width / 2)
		and math.abs(localPosition.Y) <= (height / 2)
end

local function playerInsideZombieHitbox(zombie, zombieRoot, playerRoot)
	local depth = zombie:GetAttribute("ZombieAttackDepth")
	local width = zombie:GetAttribute("ZombieAttackWidth")
	local height = zombie:GetAttribute("ZombieAttackHeight")
	local backPadding = zombie:GetAttribute("ZombieAttackBackPadding")

	if
		typeof(depth) ~= "number"
		or typeof(width) ~= "number"
		or typeof(height) ~= "number"
		or typeof(backPadding) ~= "number"
	then
		return false
	end

	local rootPosition = playerRoot.Position
	local rightVector = playerRoot.CFrame.RightVector
	local samples = {
		rootPosition,
		rootPosition + (rightVector * 1.25),
		rootPosition - (rightVector * 1.25),
		rootPosition + Vector3.new(0, 2, 0),
		rootPosition - Vector3.new(0, 2, 0),
	}

	for _, position in samples do
		if pointInsideHitbox(zombieRoot.CFrame, position, depth, width, height, backPadding) then
			return true
		end
	end

	return false
end

RunService.Heartbeat:Connect(function()
	local _, _, playerRoot = getCharacterState()
	if not playerRoot then
		return
	end

	local now = Workspace:GetServerTimeNow()

	for _, zombie in zombiesFolder:GetChildren() do
		if not zombie:IsA("Model") then
			continue
		end

		local attackToken = zombie:GetAttribute("ZombieAttackToken")
		local windowStart = zombie:GetAttribute("ZombieAttackWindowStart")
		local windowEnd = zombie:GetAttribute("ZombieAttackWindowEnd")

		if
			typeof(attackToken) ~= "number"
			or attackToken <= 0
			or reportedAttackTokens[zombie] == attackToken
			or typeof(windowStart) ~= "number"
			or typeof(windowEnd) ~= "number"
			or now < (windowStart - 0.05)
			or now > windowEnd
		then
			continue
		end

		local zombieRoot = getZombieRoot(zombie)
		if not zombieRoot or not playerInsideZombieHitbox(zombie, zombieRoot, playerRoot) then
			continue
		end

		reportedAttackTokens[zombie] = attackToken
		Network.zombieHitReport.send({
			zombie = zombie,
			attackToken = attackToken,
			playerPosition = playerRoot.Position,
		})
	end
end)
