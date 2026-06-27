local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Network = require(ReplicatedStorage.Shared.Network.Packets)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Sounds = require(script.Parent.GameplaySounds)
local WaveStatus = require(ReplicatedStorage.Shared.Network.WaveStatus)
local Style = require(script.Parent.GameplayStyle)

local e = React.createElement

local function getAnnouncementText(status, wave, seconds)
	if status == WaveStatus.Intermission then
		return `Next wave in {seconds}...`
	end

	if status == WaveStatus.Started then
		if wave == (GameConfig.BossWave or 8) then
			return `WAVE {wave}: STORM BRINGER`
		end

		return `Wave {wave}/{GameConfig.TotalWaves or 8} Has Started`
	end

	if status == WaveStatus.Ended then
		return `Wave {wave} Has Ended`
	end

	return ""
end

local function outlinedText(text, color, progress)
	local pop = math.sin(math.clamp(progress, 0, 1) * math.pi)
	local eased = 1 - ((1 - progress) * (1 - progress))
	local transparency = if text == "" then 1 else math.clamp(1 - (eased + (pop * 0.25)), 0, 1)

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.055 + (0.02 * eased)),
		Size = UDim2.new(0.72, 0, 0, 46),
	}, {
		Scale = e("UIScale", {
			Scale = 0.88 + (0.12 * eased) + (0.08 * pop),
		}),
		DropShadow = Style.text({
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(2, 3),
			Size = UDim2.fromScale(1, 1),
			Text = text,
			TextColor3 = Style.BLACK,
			TextScaled = true,
			TextStrokeTransparency = 1,
			TextTransparency = math.min(transparency + 0.25, 1),
			MaxTextSize = 34,
			MinTextSize = 16,
		}),

		Fill = Style.text({
			Font = Enum.Font.GothamBlack,
			Size = UDim2.fromScale(1, 1),
			Text = text,
			TextColor3 = color,
			TextScaled = true,
			TextStrokeTransparency = 0.12,
			TextTransparency = transparency,
			MaxTextSize = 34,
			MinTextSize = 16,
		}),
	})
end

local function WaveAnnouncement()
	local state, setState = React.useState({
		status = WaveStatus.Intermission,
		wave = 1,
		seconds = 0,
	})
	local token, setToken = React.useState(0)
	local progress, setProgress = React.useState(1)

	React.useEffect(function()
		Network.waveStatus.listen(function(data)
			setState({
				status = data.status,
				wave = data.wave,
				seconds = data.seconds,
			})
			if data.status == WaveStatus.Started then
				Sounds.play(if data.wave == (GameConfig.BossWave or 8) then "boss" else "wave")
			elseif data.status == WaveStatus.Ended then
				Sounds.play("success")
			end
			setToken(function(value)
				return value + 1
			end)
		end)
	end, {})

	React.useEffect(function()
		local cancelled = false
		setProgress(0)

		task.spawn(function()
			for frameIndex = 1, 18 do
				if cancelled then
					return
				end

				setProgress(frameIndex / 18)
				task.wait(0.025)
			end
		end)

		return function()
			cancelled = true
		end
	end, { token })

	local text = getAnnouncementText(state.status, state.wave, state.seconds)
	local color = if state.status == WaveStatus.Started
		then Style.RED
		else Style.WHITE

	return outlinedText(text, color, progress)
end

return WaveAnnouncement
