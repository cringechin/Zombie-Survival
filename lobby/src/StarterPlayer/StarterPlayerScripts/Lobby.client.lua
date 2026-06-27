local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(packages:WaitForChild("React"))
local ReactRoblox = require(packages:WaitForChild("ReactRoblox"))

local Network = require(ReplicatedStorage.Shared.Network.Packets)
local uiFolder = ReplicatedStorage.Shared:WaitForChild("UI")
local componentsFolder = uiFolder:WaitForChild("Components")
local LobbyQueueApp = require(componentsFolder:WaitForChild("LobbyQueueApp"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local root = ReactRoblox.createRoot(playerGui)
root:render(React.createElement(LobbyQueueApp, {
	Network = Network,
}))
