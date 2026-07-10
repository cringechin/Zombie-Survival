local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Network = require(ReplicatedStorage.Shared.Network.Packets)
local WaveStatus = require(ReplicatedStorage.Shared.Network.WaveStatus)

local e = React.createElement

local function formatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local remainingSeconds = seconds % 60
	return string.format("%02d:%02d", minutes, remainingSeconds)
end

local function getCurrentWave(state)
	if state.status == WaveStatus.Intermission then
		return math.max(state.wave - 1, 0)
	end

	return state.wave
end

local function shadowText(props)
	local text = props.Text or ""

	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(0, props.Width or 210, 0, props.Height or 30),
	}, {
		Shadow = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.fromScale(1, 1),
			Text = text,
			TextColor3 = Color3.new(0, 0, 0),
			TextSize = props.TextSize or 22,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 30,
		}),
		Text = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromScale(1, 1),
			Text = text,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = props.TextSize or 22,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 31,
		}),
	})
end

local function BasicSurvivalHud()
	local startedAt = React.useRef(Workspace:GetAttribute("RunStartedAt") or Workspace:GetServerTimeNow())
	local elapsed, setElapsed = React.useState(0)
	local waveState, setWaveState = React.useState({
		wave = 1,
		status = WaveStatus.Intermission,
		seconds = GameConfig.IntermissionSeconds or 0,
		zombiesRemaining = 0,
		zombiesTotal = 0,
		zombiesAlive = 0,
	})

	React.useEffect(function()
		local accumulator = 0
		local connection = RunService.RenderStepped:Connect(function(deltaTime)
			accumulator += deltaTime
			if accumulator < 0.2 then
				return
			end

			accumulator = 0
			local replicatedStart = Workspace:GetAttribute("RunStartedAt")
			if typeof(replicatedStart) == "number" then
				startedAt.current = replicatedStart
			end

			setElapsed(math.floor(Workspace:GetServerTimeNow() - startedAt.current))
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		return Network.waveStatus.listen(function(data)
			setWaveState({
				wave = data.wave,
				status = data.status,
				seconds = data.seconds,
				zombiesRemaining = data.zombiesRemaining or 0,
				zombiesTotal = data.zombiesTotal or 0,
				zombiesAlive = data.zombiesAlive or 0,
			})
		end)
	end, {})

	local currentWave = getCurrentWave(waveState)
	local zombiesText = tostring(waveState.zombiesRemaining)

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(500, 34),
		ZIndex = 30,
	}, {
		List = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 18),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Time = shadowText({
			LayoutOrder = 1,
			Text = `Time: {formatTime(elapsed)}`,
		}),
		CurrentWave = shadowText({
			LayoutOrder = 2,
			Width = 120,
			Text = `Wave: {currentWave}`,
		}),
		ZombiesLeft = shadowText({
			LayoutOrder = 3,
			Text = `Zombies Left: {zombiesText}`,
		}),
	})
end

return BasicSurvivalHud
