local GameConfig = {}

GameConfig.IntermissionSeconds = 5
GameConfig.TotalWaves = 8
GameConfig.BossWave = 8
GameConfig.VictoryReturnDelay = 15
GameConfig.TimeBetweenSpawnGroups = 0.85
GameConfig.TimeBetweenZombiesInGroup = 0.18
GameConfig.MaxLiveZombies = 80
GameConfig.MaxLiveZombiesPerPlayer = 80
GameConfig.WaveSpawnDurationBase = 55
GameConfig.WaveSpawnDurationPerWave = 18
GameConfig.MinWaveSpawnInterval = 0.65
GameConfig.MaxWaveSpawnInterval = 2.4
GameConfig.LiveZombiePressureBase = 8
GameConfig.LiveZombiePressurePerPlayer = 7
GameConfig.LiveZombiePressurePerWave = 3
GameConfig.LiveZombiePressureMax = 55

GameConfig.StartingWaveSize = 25
GameConfig.WaveSizeMultiplier = 2
GameConfig.MinSpawnGroupSize = 1
GameConfig.MaxSpawnGroupSize = 2
GameConfig.PlayerSpawnMinDistance = 24
GameConfig.PlayerSpawnMaxDistance = 42
GameConfig.PlayerSpawnAttempts = 18

GameConfig.StressTestEnabled = false
GameConfig.StressTestZombieCount = 200
GameConfig.StressTestLiveCap = 220
GameConfig.StressTestSpawnGroupSize = 3
GameConfig.StressTestTimeBetweenSpawnGroups = 0.35
GameConfig.StressTestMaxLightning = true
GameConfig.TestUnlockTornado = false

GameConfig.LightweightZombieMovement = false
GameConfig.ZombieUpdatesPerFrame = 75
GameConfig.ZombieSeparationDistance = 3.5
GameConfig.ZombieSeparationWeight = 1.6
GameConfig.ZombieMaxGroundStepHeight = 2.5
GameConfig.ZombieClientHitboxDuration = 0.4
GameConfig.ZombieClientHitboxRangePadding = 1.45
GameConfig.ZombieClientHitboxWidth = 4.75
GameConfig.ZombieClientHitboxHeight = 6.25
GameConfig.ZombieClientHitboxBackPadding = 0.8
GameConfig.ZombieServerHitValidationPadding = 1.75
GameConfig.ZombieHitReportPositionSlack = 8
GameConfig.StartingCoins = 0
GameConfig.CreditsPerZombieKill = 5

GameConfig.Defenses = {
	LightningTurret = {
		Cost = 90,
		CostIncreasePerTower = 50,
		Health = 220,
		AttackRange = 36,
		Damage = 18,
		FireCooldown = 0.65,
		LifeTime = 0,
		SpawnOffset = 9,
		SpawnAttempts = 8,
		GridSize = 6,
		MaxPlacementDistance = 90,
		SearchRadiusCells = 4,
	},
}

GameConfig.ZombieSpawnWeights = {
	BasicZombie = 100,
	Sprinter = 36,
	Tank = 14,
}

GameConfig.LeaderstatNames = {
	Wave = "Wave",
	Kills = "Kills",
	BestWave = "Best Wave",
	Coins = "Coins",
}

return GameConfig
