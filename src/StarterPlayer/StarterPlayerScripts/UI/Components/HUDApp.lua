local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local Hotbar = require(script.Parent.Hotbar)
local SideBars = require(script.Parent.SideBars)
local WaveAnnouncement = require(script.Parent.WaveAnnouncement)

local e = React.createElement

local function HUDApp()
	return e("ScreenGui", {
		DisplayOrder = 20,
		IgnoreGuiInset = true,
		Name = "SurvivalHud",
		ResetOnSpawn = false,
	}, {
		WaveAnnouncement = e(WaveAnnouncement),
		SideBars = e(SideBars),
		Hotbar = e(Hotbar),
	})
end

return HUDApp
