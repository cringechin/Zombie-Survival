local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Style = require(script.Parent.GameplayStyle)

local e = React.createElement
local localPlayer = Players.LocalPlayer

local function getLeaderstatValue(player, statName)
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(statName)
	return if stat and stat:IsA("IntValue") then stat.Value else 0
end

local function buildRows()
	local rows = {}

	for _, player in Players:GetPlayers() do
		local runKills = player:GetAttribute("RunKills")
		local runCoins = player:GetAttribute("RunCoinsEarned")
		local totalCoins = getLeaderstatValue(player, GameConfig.LeaderstatNames.Coins)
		table.insert(rows, {
			Name = player.Name,
			Kills = if typeof(runKills) == "number" then runKills else getLeaderstatValue(player, GameConfig.LeaderstatNames.Kills),
			Money = if totalCoins > 0 then totalCoins else (if typeof(runCoins) == "number" then runCoins else 0),
			IsLocal = player == localPlayer,
		})
	end

	table.sort(rows, function(a, b)
		if a.Kills == b.Kills then
			return a.Money > b.Money
		end

		return a.Kills > b.Kills
	end)

	return rows
end

local function getSurvivorCount()
	local count = 0

	for _, player in Players:GetPlayers() do
		local isDowned = player:GetAttribute("IsDowned") == true
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not isDowned and humanoid and humanoid.Health > 0 then
			count += 1
		end
	end

	return count
end

local function statCard(layoutOrder, title, value, accentColor)
	return e("Frame", {
		BackgroundColor3 = Style.PANEL_SOFT,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(160, 64),
	}, {
		Corner = Style.corner(8),
		Stroke = e("UIStroke", {
			Color = accentColor,
			Thickness = 1.5,
			Transparency = 0.22,
		}),
		Title = Style.text({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(8, 6),
			Size = UDim2.new(1, -16, 0, 18),
			Text = title,
			TextColor3 = Color3.fromRGB(210, 220, 240),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 14,
			MinTextSize = 8,
			ZIndex = 121,
		}),
		Value = Style.text({
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(8, 24),
			Size = UDim2.new(1, -16, 0, 34),
			Text = tostring(value),
			TextColor3 = accentColor,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 28,
			MinTextSize = 12,
			ZIndex = 121,
		}),
	})
end

local function rowItem(entry, layoutOrder)
	return e("Frame", {
		BackgroundColor3 = if entry.IsLocal then Color3.fromRGB(38, 50, 78) else Style.PANEL,
		BackgroundTransparency = if entry.IsLocal then 0.04 else 0.12,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 32),
	}, {
		Corner = Style.corner(6),
		Name = Style.text({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(0.54, 0, 1, 0),
			Text = entry.Name,
			TextColor3 = Style.WHITE,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 16,
			MinTextSize = 10,
			ZIndex = 122,
		}),
		Kills = Style.text({
			Font = Enum.Font.GothamBlack,
			Position = UDim2.new(0.56, 0, 0, 0),
			Size = UDim2.new(0.2, 0, 1, 0),
			Text = tostring(entry.Kills),
			TextColor3 = Style.RED,
			TextScaled = true,
			MaxTextSize = 16,
			MinTextSize = 10,
			ZIndex = 122,
		}),
		Coins = Style.text({
			Font = Enum.Font.GothamBlack,
			Position = UDim2.new(0.78, 0, 0, 0),
			Size = UDim2.new(0.22, -10, 1, 0),
			Text = tostring(entry.Money),
			TextColor3 = Style.GOLD,
			TextScaled = true,
			MaxTextSize = 16,
			MinTextSize = 10,
			ZIndex = 122,
		}),
	})
end

local function VictoryScreen()
	local visible, setVisible = React.useState(Workspace:GetAttribute("VictoryActive") == true)
	local countdown, setCountdown = React.useState(0)
	local rows, setRows = React.useState({})
	local summary, setSummary = React.useState({
		Wave = 0,
		Duration = 0,
		TeamKills = 0,
		Survivors = 0,
		TeamMoney = 0,
		LocalReward = 0,
	})

	React.useEffect(function()
		local function refreshVisible()
			setVisible(Workspace:GetAttribute("VictoryActive") == true)
		end

		refreshVisible()
		local connection = Workspace:GetAttributeChangedSignal("VictoryActive"):Connect(refreshVisible)
		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		if not visible then
			return
		end

		local accumulator = 0
		local connection = RunService.RenderStepped:Connect(function(deltaTime)
			accumulator += deltaTime
			if accumulator < 0.25 then
				return
			end
			accumulator = 0

			local runRows = buildRows()
			local teamKills = 0
			local teamMoney = 0

			for _, row in runRows do
				teamKills += row.Kills
				teamMoney += row.Money
			end

			local returnAt = Workspace:GetAttribute("VictoryReturnAt")
			local remaining = 0
			if typeof(returnAt) == "number" and returnAt > 0 then
				remaining = math.max(0, math.ceil(returnAt - Workspace:GetServerTimeNow()))
			end

			setCountdown(remaining)
			setRows(runRows)
			setSummary({
				Wave = Workspace:GetAttribute("VictoryWave") or 0,
				Duration = Workspace:GetAttribute("VictoryDuration") or 0,
				TeamKills = teamKills,
				Survivors = getSurvivorCount(),
				TeamMoney = teamMoney,
				LocalReward = localPlayer:GetAttribute("RunCoinsEarned") or 0,
			})
		end)

		return function()
			connection:Disconnect()
		end
	end, { visible })

	if not visible then
		return nil
	end

	local rowChildren = {
		List = e("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, entry in rows do
		rowChildren[`Row{index}`] = rowItem(entry, index)
	end

	return e("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 110,
	}, {
		Panel = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Style.PANEL,
			BackgroundTransparency = 0.06,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(720, 430),
			ZIndex = 120,
		}, {
			Corner = Style.corner(12),
			Stroke = e("UIStroke", {
				Color = Style.GOLD,
				Thickness = 3,
				Transparency = 0.08,
			}),
			Title = Style.text({
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(0, 14),
				Size = UDim2.new(1, 0, 0, 54),
				Text = "VICTORY",
				TextColor3 = Style.GOLD,
				TextScaled = true,
				TextStrokeTransparency = 0.02,
				MaxTextSize = 46,
				MinTextSize = 20,
				ZIndex = 121,
			}),
			Sub = Style.text({
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromOffset(0, 66),
				Size = UDim2.new(1, 0, 0, 24),
				Text = "Storm Bringer defeated. Run complete.",
				TextColor3 = Style.WHITE,
				TextScaled = true,
				MaxTextSize = 18,
				MinTextSize = 10,
				ZIndex = 121,
			}),
			Stats = e("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(20, 102),
				Size = UDim2.new(1, -40, 0, 70),
				ZIndex = 121,
			}, {
				List = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Wave = statCard(1, "Wave Cleared", summary.Wave, Style.RED),
				Duration = statCard(2, "Run Time (s)", summary.Duration, Style.WHITE),
				Kills = statCard(3, "Team Kills", summary.TeamKills, Style.LIGHTNING),
				Reward = statCard(4, "Your Reward", summary.LocalReward, Style.GOLD),
			}),
			Header = e("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(20, 184),
				Size = UDim2.new(1, -40, 0, 24),
				ZIndex = 121,
			}, {
				Player = Style.text({
					Font = Enum.Font.GothamBlack,
					Position = UDim2.fromOffset(10, 0),
					Size = UDim2.new(0.54, 0, 1, 0),
					Text = "Player",
					TextColor3 = Style.WHITE,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					MaxTextSize = 15,
					MinTextSize = 8,
					ZIndex = 121,
				}),
				Kills = Style.text({
					Font = Enum.Font.GothamBlack,
					Position = UDim2.new(0.56, 0, 0, 0),
					Size = UDim2.new(0.2, 0, 1, 0),
					Text = "Kills",
					TextColor3 = Style.RED,
					TextScaled = true,
					MaxTextSize = 15,
					MinTextSize = 8,
					ZIndex = 121,
				}),
				Coins = Style.text({
					Font = Enum.Font.GothamBlack,
					Position = UDim2.new(0.78, 0, 0, 0),
					Size = UDim2.new(0.22, -10, 1, 0),
					Text = "Money",
					TextColor3 = Style.GOLD,
					TextScaled = true,
					MaxTextSize = 15,
					MinTextSize = 8,
					ZIndex = 121,
				}),
			}),
			Rows = e("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(20, 208),
				Size = UDim2.new(1, -40, 0, 172),
				ZIndex = 121,
			}, rowChildren),
			Return = Style.text({
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(0, 390),
				Size = UDim2.new(1, 0, 0, 26),
				Text = `Survivors: {summary.Survivors} | Team Money: {summary.TeamMoney} | Returning in {countdown}s`,
				TextColor3 = Style.LIGHTNING,
				TextScaled = true,
				MaxTextSize = 20,
				MinTextSize = 10,
				ZIndex = 121,
			}),
		}),
	})
end

return VictoryScreen
