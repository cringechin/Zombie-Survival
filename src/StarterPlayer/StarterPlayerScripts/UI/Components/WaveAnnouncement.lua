local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Network = require(ReplicatedStorage.Shared.Network.Packets)
local WaveStatus = require(ReplicatedStorage.Shared.Network.WaveStatus)

local e = React.createElement

local function getAnnouncementText(status, wave, seconds)
	if status == WaveStatus.Intermission then
		return `Next wave in {seconds}...`
	end

	if status == WaveStatus.Started then
		return `Wave {wave} Has Started`
	end

	if status == WaveStatus.Ended then
		return `Wave {wave} Has Ended`
	end

	return ""
end

local function outlinedText(text, color)
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.075),
		Size = UDim2.new(0.72, 0, 0, 46),
	}, {
		DropShadow = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(2, 3),
			Size = UDim2.fromScale(1, 1),
			Text = text,
			TextColor3 = Color3.fromRGB(20, 10, 0),
			TextScaled = true,
			TextStrokeTransparency = 1,
			TextTransparency = 0.25,
		}, {
			SizeLimit = e("UITextSizeConstraint", {
				MaxTextSize = 34,
				MinTextSize = 16,
			}),
		}),

		Fill = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Size = UDim2.fromScale(1, 1),
			Text = text,
			TextColor3 = color,
			TextScaled = true,
			TextStrokeTransparency = 0.12,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		}, {
			SizeLimit = e("UITextSizeConstraint", {
				MaxTextSize = 34,
				MinTextSize = 16,
			}),
		}),
	})
end

local function WaveAnnouncement()
	local state, setState = React.useState({
		status = WaveStatus.Intermission,
		wave = 1,
		seconds = 0,
	})

	React.useEffect(function()
		Network.waveStatus.listen(function(data)
			setState({
				status = data.status,
				wave = data.wave,
				seconds = data.seconds,
			})
		end)
	end, {})

	local text = getAnnouncementText(state.status, state.wave, state.seconds)
	local color = if state.status == WaveStatus.Started
		then Color3.fromRGB(255, 58, 13)
		else Color3.fromRGB(255, 143, 0)

	return outlinedText(text, color)
end

return WaveAnnouncement
