local PlayerDataSchema = {}

PlayerDataSchema.StoreName = "PlayerData_v1"

PlayerDataSchema.Template = {
	Stats = {
		Kills = 0,
		BestWave = 0,
	},

	Currency = {
		Coins = 0,
	},
}

return PlayerDataSchema
