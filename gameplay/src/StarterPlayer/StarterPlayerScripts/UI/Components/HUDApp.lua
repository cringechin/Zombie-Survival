local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local BasicSurvivalHud = require(script.Parent.BasicSurvivalHud)
local BossHealthBar = require(script.Parent.BossHealthBar)
local DeathScreen = require(script.Parent.DeathScreen)
local Hotbar = require(script.Parent.Hotbar)
local SideBars = require(script.Parent.SideBars)
local VictoryScreen = require(script.Parent.VictoryScreen)

local e = React.createElement

local function HUDApp()
	return e("ScreenGui", {
		DisplayOrder = 20,
		IgnoreGuiInset = true,
		Name = "SurvivalHud",
		ResetOnSpawn = false,
	}, {
		BasicSurvivalHud = e(BasicSurvivalHud),
		BossHealthBar = e(BossHealthBar),
		SideBars = e(SideBars),
		Hotbar = e(Hotbar),
		DeathScreen = e(DeathScreen),
		VictoryScreen = e(VictoryScreen),
	})
end

return HUDApp
