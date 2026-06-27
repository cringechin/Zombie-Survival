local SoundService = game:GetService("SoundService")

local GameplaySounds = {}

local MUSIC_SOUND_ID = "rbxassetid://136767646038064"

local SOUND_IDS = {
	click = "rbxassetid://12221967",
	hover = "rbxassetid://12222124",
	wave = "rbxassetid://12222253",
	boss = "rbxassetid://9125708087",
	success = "rbxassetid://12222225",
	danger = "rbxassetid://9125402735",
	info = "rbxassetid://12222140",
	lightning = "rbxassetid://95495457829413",
}

local VOLUMES = {
	click = 0.35,
	hover = 0.18,
	wave = 0.42,
	boss = 0.55,
	success = 0.4,
	danger = 0.5,
	info = 0.28,
	lightning = 0.32,
}

local function randomBetween(minValue, maxValue)
	return minValue + ((maxValue - minValue) * math.random())
end

function GameplaySounds.play(name, options)
	options = options or {}
	local soundId = SOUND_IDS[name] or SOUND_IDS.info
	local sound = Instance.new("Sound")
	sound.Name = `Temp_{name}Sound`
	sound.SoundId = soundId
	sound.Volume = options.Volume or VOLUMES[name] or 0.3
	sound.PlaybackSpeed = options.PlaybackSpeed or randomBetween(options.MinPitch or 0.96, options.MaxPitch or 1.04)
	sound.RollOffMaxDistance = 0
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)

	task.delay(5, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

function GameplaySounds.startMusic()
	local existing = SoundService:FindFirstChild("GameplayMusic")
	if existing and existing:IsA("Sound") then
		if not existing.IsPlaying then
			existing:Play()
		end
		return existing
	end

	local music = Instance.new("Sound")
	music.Name = "GameplayMusic"
	music.SoundId = MUSIC_SOUND_ID
	music.Volume = 0.22
	music.Looped = true
	music.RollOffMaxDistance = 0
	music.Parent = SoundService
	music:Play()

	return music
end

return GameplaySounds
