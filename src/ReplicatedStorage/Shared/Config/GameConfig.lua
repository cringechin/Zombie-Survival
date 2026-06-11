local GameConfig = {}

GameConfig.IntermissionSeconds = 5
GameConfig.TimeBetweenSpawnGroups = 1.1
GameConfig.MaxLiveZombies = 140
GameConfig.MaxLiveZombiesPerPlayer = 36

GameConfig.StartingWaveSize = 14
GameConfig.ZombiesPerWave = 6
GameConfig.WaveGrowthExponent = 1.18
GameConfig.WavePlayerScale = 0.35
GameConfig.MinSpawnGroupSize = 1
GameConfig.MaxSpawnGroupSize = 3
GameConfig.PlayerSpawnMinDistance = 24
GameConfig.PlayerSpawnMaxDistance = 42
GameConfig.PlayerSpawnAttempts = 18

GameConfig.StressTestEnabled = false
GameConfig.StressTestZombieCount = 200
GameConfig.StressTestLiveCap = 220
GameConfig.StressTestSpawnGroupSize = 3
GameConfig.StressTestTimeBetweenSpawnGroups = 0.35
GameConfig.StressTestMaxLightning = true

GameConfig.LightweightZombieMovement = false
GameConfig.ZombieUpdatesPerFrame = 75
GameConfig.ZombieSeparationDistance = 3.5
GameConfig.ZombieSeparationWeight = 1.6
GameConfig.ZombieMaxGroundStepHeight = 2.5

GameConfig.LeaderstatNames = {
	Wave = "Wave",
	Kills = "Kills",
	BestWave = "Best Wave",
	Coins = "Coins",
}

return GameConfig
