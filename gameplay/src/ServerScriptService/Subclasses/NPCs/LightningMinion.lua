local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local NPC = require(ServerScriptService.Classes.NPC.NPC)
local NPCRegistry = require(ReplicatedStorage.Shared.NPC.NPCRegistry)

local LightningMinion = {}
LightningMinion.__index = LightningMinion
setmetatable(LightningMinion, NPC)

local BASE_CONFIG = NPCRegistry.LightningMinion

local function buildConfig(waveNumber)
	return {
		Class = BASE_CONFIG.Class,
		Subclass = BASE_CONFIG.Subclass,
		DisplayName = BASE_CONFIG.DisplayName,
		AssetPath = BASE_CONFIG.AssetPath,
		Damage = BASE_CONFIG.Damage + math.floor(waveNumber / 5),
		WalkSpeed = BASE_CONFIG.WalkSpeed + math.min(waveNumber * 0.08, 2.5),
		Health = 45 + (waveNumber * 7),
		AttackRange = BASE_CONFIG.AttackRange,
		AttackCooldown = BASE_CONFIG.AttackCooldown,
		AttackWindup = BASE_CONFIG.AttackWindup,
		AggroRange = BASE_CONFIG.AggroRange,
		WalkAnimationId = BASE_CONFIG.WalkAnimationId,
		EnableR6Ragdoll = BASE_CONFIG.EnableR6Ragdoll,
		DeathKnockbackMultiplier = BASE_CONFIG.DeathKnockbackMultiplier,
		DeathKnockbackUpwardMultiplier = BASE_CONFIG.DeathKnockbackUpwardMultiplier,
		SpawnAnimationId = BASE_CONFIG.SpawnAnimationId,
		SpawnAnimationDuration = BASE_CONFIG.SpawnAnimationDuration,
		SpawnAnimationAnchoredRoot = BASE_CONFIG.SpawnAnimationAnchoredRoot,
		SpawnAnimationSkipGroundSnap = BASE_CONFIG.SpawnAnimationSkipGroundSnap,
		SpawnAnimationPivotOffset = BASE_CONFIG.SpawnAnimationPivotOffset,
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
		VariantName = "Lightning",
		VariantTintColor = Color3.fromRGB(56, 202, 255),
		VariantTintStrength = 0.62,
	}
end

function LightningMinion.new(waveNumber)
	local self = NPC.new(buildConfig(waveNumber))
	return setmetatable(self, LightningMinion)
end

return LightningMinion
