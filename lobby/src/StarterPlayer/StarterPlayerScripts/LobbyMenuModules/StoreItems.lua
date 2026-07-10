local StoreItems = {}

StoreItems.Items = {
	{
		Id = "Lightning",
		Name = "Lightning",
		Rarity = "Common",
		RarityColor = Color3.fromRGB(196, 196, 196),
		Stars = 1,
		CoinCost = 0,
		RobuxCost = 0,
		Description = "Call down a bolt of lightning on the horde.",
		Image = "rbxasset://textures/particles/sparkles_main.dds",
		PreviewColor = Color3.fromRGB(40, 130, 170),
		AccentColor = Color3.fromRGB(128, 224, 255),
		Stats = {
			{ Label = "DMG/sec", Current = 57, Upgraded = 71, CurrentColor = Color3.fromRGB(255, 170, 72), UpgradedColor = Color3.fromRGB(120, 220, 120) },
			{ Label = "Damage", Current = 20, Upgraded = 30, CurrentColor = Color3.fromRGB(255, 120, 120), UpgradedColor = Color3.fromRGB(120, 220, 120) },
			{ Label = "Fire Rate", Current = "0.35s", Upgraded = "0.35s", CurrentColor = Color3.fromRGB(120, 220, 255), UpgradedColor = Color3.fromRGB(120, 220, 120) },
		},
	},
	{
		Id = "Meteor",
		Name = "Meteor",
		Rarity = "Rare",
		RarityColor = Color3.fromRGB(120, 190, 255),
		Stars = 2,
		CoinCost = 150,
		RobuxCost = 49,
		Description = "Launch a meteor that crashes into zombies.",
		Image = "rbxasset://textures/particles/fire_main.dds",
		PreviewColor = Color3.fromRGB(150, 64, 34),
		AccentColor = Color3.fromRGB(255, 178, 84),
		Stats = {
			{ Label = "DMG/sec", Current = 8, Upgraded = 12, CurrentColor = Color3.fromRGB(255, 170, 72), UpgradedColor = Color3.fromRGB(120, 220, 120) },
			{ Label = "Damage", Current = 40, Upgraded = 60, CurrentColor = Color3.fromRGB(255, 120, 120), UpgradedColor = Color3.fromRGB(120, 220, 120) },
			{ Label = "Fire Rate", Current = "5.0s", Upgraded = "5.0s", CurrentColor = Color3.fromRGB(120, 220, 255), UpgradedColor = Color3.fromRGB(120, 220, 120) },
		},
	},
	{
		Id = "Tornado",
		Name = "Tornado",
		Rarity = "Epic",
		RarityColor = Color3.fromRGB(170, 120, 255),
		Stars = 3,
		CoinCost = 300,
		RobuxCost = 79,
		Description = "Summon a tornado that pulls and tosses zombies.",
		Image = "rbxasset://textures/particles/smoke_main.dds",
		PreviewColor = Color3.fromRGB(74, 92, 105),
		AccentColor = Color3.fromRGB(184, 229, 232),
		Stats = {
			{ Label = "DMG/sec", Current = 29, Upgraded = 38, CurrentColor = Color3.fromRGB(255, 170, 72), UpgradedColor = Color3.fromRGB(120, 220, 120) },
			{ Label = "Damage", Current = 10, Upgraded = 13, CurrentColor = Color3.fromRGB(255, 120, 120), UpgradedColor = Color3.fromRGB(120, 220, 120) },
			{ Label = "Fire Rate", Current = "7.0s", Upgraded = "7.0s", CurrentColor = Color3.fromRGB(120, 220, 255), UpgradedColor = Color3.fromRGB(120, 220, 120) },
		},
	},
}

return StoreItems
