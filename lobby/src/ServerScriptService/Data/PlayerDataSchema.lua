local PlayerDataSchema = {}

PlayerDataSchema.StoreName = "PlayerData_v2"

PlayerDataSchema.Template = {
	Stats = {
		Kills = 0,
		BestWave = 0,
	},

	Currency = {
		Coins = 0,
	},

	Weapons = {
		Lightning = true,
		Meteor = false,
		Tornado = false,
	},

	DisasterLoadout = {
		"Lightning",
		"",
		"",
	},
}

return PlayerDataSchema
