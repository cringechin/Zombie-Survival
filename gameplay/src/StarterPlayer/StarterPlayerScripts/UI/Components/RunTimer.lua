local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Style = require(script.Parent.GameplayStyle)

local e = React.createElement

local function formatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local remainingSeconds = seconds % 60
	return string.format("%02d:%02d", minutes, remainingSeconds)
end

local function RunTimer()
	local startedAt = React.useRef(Workspace:GetAttribute("RunStartedAt") or Workspace:GetServerTimeNow())
	local elapsed, setElapsed = React.useState(0)

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

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Style.PANEL,
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(174, 42),
		ZIndex = 45,
	}, {
		Corner = Style.corner(8),
		Stroke = Style.stroke(nil, 3, 0),
		Tab = e("Frame", {
			BackgroundColor3 = Style.RED,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(58, 42),
			ZIndex = 46,
		}, {
			Corner = Style.corner(8),
			Label = Style.text({
				Size = UDim2.fromScale(1, 1),
				Text = "TIME",
				TextScaled = true,
				MaxTextSize = 15,
				MinTextSize = 8,
				ZIndex = 47,
			}),
		}),
		Value = Style.text({
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(64, 0),
			Size = UDim2.new(1, -70, 1, 0),
			Text = formatTime(elapsed),
			TextScaled = true,
			MaxTextSize = 24,
			MinTextSize = 12,
			ZIndex = 47,
		}),
	})
end

return RunTimer
