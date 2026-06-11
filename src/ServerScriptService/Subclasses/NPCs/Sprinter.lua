local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local NPC = require(ServerScriptService.Classes.NPC.NPC)
local NPCRegistry = require(ReplicatedStorage.Shared.NPC.NPCRegistry)

local Sprinter = {}
Sprinter.__index = Sprinter
setmetatable(Sprinter, NPC)

local BASE_CONFIG = NPCRegistry.Sprinter
local RARE_VARIANT_CHANCE = 0.14

local function getRegularZombieHealth(waveNumber)
	return 75 + (waveNumber * 8)
end

local function getVariantData()
	if math.random() <= RARE_VARIANT_CHANCE then
		return "Rare", Color3.fromRGB(108, 244, 126), 0.48
	end

	return "Default", nil, nil
end

local function buildConfig(waveNumber)
	local variantName, variantTintColor, variantTintStrength = getVariantData()

	return {
		Class = BASE_CONFIG.Class,
		Subclass = BASE_CONFIG.Subclass,
		DisplayName = if variantName == "Rare" then "Rare Sprinter" else BASE_CONFIG.DisplayName,
		AssetPath = BASE_CONFIG.AssetPath,
		Damage = BASE_CONFIG.Damage + math.floor(waveNumber / 5),
		WalkSpeed = BASE_CONFIG.WalkSpeed + math.min(waveNumber * 0.12, 4.8),
		Health = math.max(math.floor(getRegularZombieHealth(waveNumber) * 0.5), 1),
		AttackRange = BASE_CONFIG.AttackRange,
		AttackCooldown = BASE_CONFIG.AttackCooldown,
		AttackWindup = BASE_CONFIG.AttackWindup,
		AggroRange = BASE_CONFIG.AggroRange,
		SpawnAnimationId = BASE_CONFIG.SpawnAnimationId,
		SpawnAnimationDuration = BASE_CONFIG.SpawnAnimationDuration,
		FacingResponsiveness = BASE_CONFIG.FacingResponsiveness,
		SurroundRadius = BASE_CONFIG.SurroundRadius,
		MovementTick = BASE_CONFIG.MovementTick,
		MoveLookaheadDistance = BASE_CONFIG.MoveLookaheadDistance,
		GridSize = BASE_CONFIG.GridSize,
		RepathInterval = BASE_CONFIG.RepathInterval,
		MaxPathNodes = BASE_CONFIG.MaxPathNodes,
		PathNodeReachDistance = BASE_CONFIG.PathNodeReachDistance,
		MaxGroundStepHeight = BASE_CONFIG.MaxGroundStepHeight,
		ObstacleFeelerDistance = BASE_CONFIG.ObstacleFeelerDistance,
		ObstacleAvoidanceWeight = BASE_CONFIG.ObstacleAvoidanceWeight,
		ObstacleCommitTime = BASE_CONFIG.ObstacleCommitTime,
		SeparationRadius = BASE_CONFIG.SeparationRadius,
		SeparationWeight = BASE_CONFIG.SeparationWeight,
		StuckCheckInterval = BASE_CONFIG.StuckCheckInterval,
		StuckDistance = BASE_CONFIG.StuckDistance,
		StuckAvoidanceTime = BASE_CONFIG.StuckAvoidanceTime,
		Appearance = BASE_CONFIG.Appearance,
		SpecialAttacks = BASE_CONFIG.SpecialAttacks,
		VariantName = variantName,
		VariantTintColor = variantTintColor,
		VariantTintStrength = variantTintStrength,
	}
end

function Sprinter.new(waveNumber)
	local self = NPC.new(buildConfig(waveNumber))
	return setmetatable(self, Sprinter)
end

return Sprinter
