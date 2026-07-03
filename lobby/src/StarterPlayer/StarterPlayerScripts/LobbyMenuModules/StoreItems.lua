local StoreItems = {}

StoreItems.Items = {
	{
		Id = "Lightning",
		Name = "Lightning",
		Price = "EQUIPPED",
		Description = "A jolt of lightning.",
		Image = "rbxasset://textures/particles/sparkles_main.dds",
		PreviewText = "BOLT",
		PreviewColor = Color3.fromRGB(40, 130, 170),
		AccentColor = Color3.fromRGB(128, 224, 255),
	},
	{
		Id = "Meteor",
		Name = "Meteor",
		Price = "150 CR",
		Description = "A blazing meteor crashing into the horde.",
		Image = "rbxasset://textures/particles/fire_main.dds",
		PreviewText = "METEOR",
		PreviewColor = Color3.fromRGB(150, 64, 34),
		AccentColor = Color3.fromRGB(255, 178, 84),
	},
	{
		Id = "Tornado",
		Name = "Tornado",
		Price = "300 CR",
		Description = "A fierce tornado sending smaller zombies away.",
		Image = "rbxasset://textures/particles/smoke_main.dds",
		PreviewText = "TWIST",
		PreviewColor = Color3.fromRGB(74, 92, 105),
		AccentColor = Color3.fromRGB(184, 229, 232),
	},
}

return StoreItems
