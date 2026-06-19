local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local NPC = require(ServerScriptService.Classes.NPC.NPC)
local NPCRegistry = require(ReplicatedStorage.Shared.NPC.NPCRegistry)

local LightningBoss = {}
LightningBoss.__index = LightningBoss
setmetatable(LightningBoss, NPC)

local BASE_CONFIG = NPCRegistry.LightningBoss

local function buildConfig(waveNumber)
	return {
		Class = BASE_CONFIG.Class,
		Subclass = BASE_CONFIG.Subclass,
		DisplayName = BASE_CONFIG.DisplayName,
		AssetPath = BASE_CONFIG.AssetPath,
		Damage = BASE_CONFIG.Damage + math.floor(waveNumber / 3),
		WalkSpeed = BASE_CONFIG.WalkSpeed,
		Health = 950 + (waveNumber * 95),
		AttackRange = BASE_CONFIG.AttackRange,
		AttackCooldown = BASE_CONFIG.AttackCooldown,
		AttackWindup = BASE_CONFIG.AttackWindup,
		AggroRange = BASE_CONFIG.AggroRange,
		SpawnAnimationId = BASE_CONFIG.SpawnAnimationId,
		SpawnAnimationDuration = BASE_CONFIG.SpawnAnimationDuration,
		IdleAnimationId = BASE_CONFIG.IdleAnimationId,
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
		ModelScale = BASE_CONFIG.ModelScale,
		SpecialAttacks = BASE_CONFIG.SpecialAttacks,
		VariantName = "Boss",
		VariantTintColor = Color3.fromRGB(45, 174, 255),
		VariantTintStrength = 0.72,
	}
end

function LightningBoss.new(waveNumber)
	local self = NPC.new(buildConfig(waveNumber))
	return setmetatable(self, LightningBoss)
end

return LightningBoss
