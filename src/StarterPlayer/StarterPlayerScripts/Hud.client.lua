local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(packages:WaitForChild("React"))
local ReactRoblox = require(packages:WaitForChild("ReactRoblox"))

local HUDApp = require(script.Parent.UI.Components.HUDApp)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

task.spawn(function()
	while not pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) do
		task.wait(0.1)
	end
end)

local root = ReactRoblox.createRoot(playerGui)
root:render(React.createElement(HUDApp))
