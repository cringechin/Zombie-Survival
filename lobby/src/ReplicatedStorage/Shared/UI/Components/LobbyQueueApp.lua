local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local e = React.createElement

local MAPS = {
	{
		Name = "STORM LAB",
		Title = "STORMBREAK LABS",
		Threat = "BOSS | LIGHTNING REVENANT",
		Description = "OVERRUN RESEARCH FACILITY",
		Accent = Color3.fromRGB(85, 216, 255),
		Dark = Color3.fromRGB(20, 42, 74),
		Fog = Color3.fromRGB(154, 243, 255),
		ImageTemplate = "rbxasset://textures/ui/GuiImagePlaceholder.png",
	},
	{
		Name = "CRYPT",
		Title = "ROTWOOD CRYPT",
		Threat = "HORDE | GRAVEBORN",
		Description = "BURIAL GROUNDS UNDER LOCKDOWN",
		Accent = Color3.fromRGB(115, 224, 93),
		Dark = Color3.fromRGB(30, 69, 42),
		Fog = Color3.fromRGB(170, 244, 137),
		ImageTemplate = "rbxasset://textures/ui/GuiImagePlaceholder.png",
	},
	{
		Name = "METRO",
		Title = "DEADLINE METRO",
		Threat = "SWARM | TUNNEL DEAD",
		Description = "BLACKOUT TRANSIT HUB",
		Accent = Color3.fromRGB(255, 83, 68),
		Dark = Color3.fromRGB(79, 30, 37),
		Fog = Color3.fromRGB(255, 170, 126),
		ImageTemplate = "rbxasset://textures/ui/GuiImagePlaceholder.png",
	},
}

local DIFFICULTIES = {
	{ Name = "NORMAL", Color = Color3.fromRGB(57, 230, 91) },
	{ Name = "HARD", Color = Color3.fromRGB(255, 190, 46) },
	{ Name = "NIGHTMARE", Color = Color3.fromRGB(255, 61, 84) },
}

local RED = Color3.fromRGB(240, 49, 68)
local RED_DARK = Color3.fromRGB(102, 18, 34)
local INK = Color3.fromRGB(7, 8, 15)
local PANEL = Color3.fromRGB(14, 17, 25)
local PANEL_SOFT = Color3.fromRGB(20, 24, 35)
local WHITE = Color3.fromRGB(248, 248, 240)
local LIGHTNING = Color3.fromRGB(122, 232, 255)

local function bounceSince(clock, timestamp, duration, strength)
	if not timestamp then
		return 0
	end

	local elapsed = clock - timestamp

	if elapsed < 0 or elapsed > duration then
		return 0
	end

	local progress = elapsed / duration
	return math.sin(progress * math.pi) * (1 - progress) * strength
end

local function corner(radius)
	return e("UICorner", {
		CornerRadius = UDim.new(0, radius or 0),
	})
end

local function stroke(_color, thickness, transparency)
	return e("UIStroke", {
		Color = Color3.fromRGB(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = transparency or 0,
	})
end

local function label(props)
	return e("TextLabel", {
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
		Font = props.Font or Enum.Font.GothamBlack,
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Size = props.Size,
		Text = props.Text,
		TextColor3 = WHITE,
		TextScaled = props.TextScaled,
		TextSize = props.TextSize or 18,
		TextStrokeColor3 = props.TextStrokeColor3 or Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = props.TextStrokeTransparency or 0.08,
		TextWrapped = props.TextWrapped,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
		ZIndex = props.ZIndex,
	}, props.Children)
end

local function redTab(textValue)
	return e("Frame", {
		BackgroundColor3 = RED,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, -29),
		Size = UDim2.fromOffset(112, 32),
		ZIndex = 7,
	}, {
		Corner = corner(5),
		Stroke = stroke(nil, 2, 0),
		Label = label({
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -18, 1, 0),
			Text = textValue,
			TextSize = 16,
			ZIndex = 8,
		}),
	})
end

local function imageTemplate(map, zIndex)
	return e("ImageLabel", {
		BackgroundColor3 = map.Dark,
		BorderSizePixel = 0,
		Image = map.ImageTemplate,
		ImageColor3 = Color3.fromRGB(255, 255, 255),
		ImageTransparency = 0.08,
		Name = "ImageTemplate",
		Position = UDim2.fromOffset(-4, -4),
		ScaleType = Enum.ScaleType.Crop,
		Size = UDim2.new(1, 8, 1, 8),
		ZIndex = zIndex,
	}, {
		Corner = corner(8),
		ColorWash = e("Frame", {
			BackgroundColor3 = map.Accent,
			BackgroundTransparency = 0.78,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = zIndex + 1,
		}, {
			Corner = corner(8),
		}),
	})
end

local function mapBackdrop(map, zIndex)
	return e("Frame", {
		BackgroundColor3 = map.Dark,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = zIndex,
	}, {
		Corner = corner(8),
		ImageTemplate = imageTemplate(map, zIndex + 1),
		Vignette = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.52,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = zIndex + 1,
		}, {
			Corner = corner(8),
		}),
		Shade = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 0.62),
			Size = UDim2.new(1, 0, 0.38, 0),
			ZIndex = zIndex + 2,
		}, {
			Corner = corner(8),
		}),
		AccentLine = e("Frame", {
			BackgroundColor3 = map.Accent,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 0, 4),
			ZIndex = zIndex + 3,
		}),
		Fog = e("Frame", {
			BackgroundColor3 = map.Fog or map.Accent,
			BackgroundTransparency = 0.83,
			BorderSizePixel = 0,
			Position = UDim2.new(0, -20, 0.2, 0),
			Rotation = -8,
			Size = UDim2.new(1, 40, 0, 34),
			ZIndex = zIndex + 3,
		}, {
			Corner = corner(10),
		}),
	})
end

local function mapCard(map, selected, hovered, clickTime, onActivated, onHover, layoutOrder, clock)
	local pulse = if selected then (math.sin(clock * 8) + 1) / 2 else 0
	local strokeThickness = if selected then 3 + pulse else 2
	local glowTransparency = if selected or hovered then 0.45 - (pulse * 0.22) else 1
	local bounce = bounceSince(clock, clickTime, 0.34, 0.18)
	local scale = 1 + (if hovered then 0.055 else 0) + bounce + (if selected then pulse * 0.018 else 0)

	return e("TextButton", {
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(0, 142, 0, 96),
		Text = "",
		ZIndex = 6,
		[React.Event.Activated] = onActivated,
		[React.Event.MouseEnter] = function()
			onHover(true)
		end,
		[React.Event.MouseLeave] = function()
			onHover(false)
		end,
	}, {
		Corner = corner(6),
		Stroke = stroke(nil, strokeThickness, 0),
		Scale = e("UIScale", {
			Scale = scale,
		}),
		Glow = e("Frame", {
			BackgroundColor3 = RED,
			BackgroundTransparency = glowTransparency,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(-3, -3),
			Size = UDim2.new(1, 6, 1, 6),
			ZIndex = 5,
		}, {
			Corner = corner(8),
		}),
		Preview = e("Frame", {
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 0, 60),
			ZIndex = 7,
		}, {
			Corner = corner(5),
			Backdrop = mapBackdrop(map, 7),
			NamePlate = e("Frame", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 0.24,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 0, 1, -26),
				Size = UDim2.new(1, 0, 0, 26),
				ZIndex = 11,
			}, {
				Corner = corner(4),
			}),
			Name = label({
				Font = Enum.Font.GothamBlack,
				Position = UDim2.new(0, 8, 1, -26),
				Size = UDim2.new(1, -16, 0, 16),
				Text = map.Name,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 12,
			}),
			Threat = label({
				Font = Enum.Font.GothamBlack,
				Position = UDim2.new(0, 8, 1, -12),
				Size = UDim2.new(1, -16, 0, 10),
				Text = map.Threat,
				TextSize = 8,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 12,
			}),
		}),
		Votes = e("Frame", {
			BackgroundColor3 = RED,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 1, -28),
			Size = UDim2.new(1, 0, 0, 28),
			ZIndex = 8,
		}, {
			Corner = corner(4),
			Text = label({
				Font = Enum.Font.GothamBlack,
				Size = UDim2.fromScale(1, 1),
				Text = if selected then "SELECTED" else "0 VOTES",
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 9,
			}),
		}),
	})
end

local function selectorButton(textValue, selected, hovered, clickTime, color, onActivated, onHover, layoutOrder, clock)
	local pulse = if selected then (math.sin(clock * 9) + 1) / 2 else 0
	local bounce = bounceSince(clock, clickTime, 0.28, 0.16)
	local scale = 1 + (if hovered then 0.045 else 0) + bounce + (if selected then pulse * 0.012 else 0)
	local shineTransparency = if hovered or selected then 0.86 - (pulse * 0.1) else 1

	return e("TextButton", {
		BackgroundColor3 = if selected then color else Color3.fromRGB(20, 24, 35),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 36),
		Text = textValue,
		TextColor3 = WHITE,
		TextSize = 15,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.08,
		ZIndex = 8,
		[React.Event.Activated] = onActivated,
		[React.Event.MouseEnter] = function()
			onHover(true)
		end,
		[React.Event.MouseLeave] = function()
			onHover(false)
		end,
	}, {
		Corner = corner(6),
		Stroke = stroke(if selected then WHITE else Color3.fromRGB(118, 43, 57), if selected then 2 else 1, if selected then 0 else 0.05),
		Scale = e("UIScale", {
			Scale = scale,
		}),
		Shine = e("Frame", {
			BackgroundColor3 = WHITE,
			BackgroundTransparency = shineTransparency,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 8, 0, 4),
			Size = UDim2.new(1, -16, 0, 5),
			ZIndex = 9,
		}, {
			Corner = corner(4),
		}),
	})
end

local function playerSlot(index, active)
	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, 23),
		ZIndex = 7,
	}, {
		Hex = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(13, 17, 24),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 1),
			Size = UDim2.fromOffset(20, 20),
			ZIndex = 8,
		}, {
			Corner = corner(4),
			Stroke = stroke(if active then Color3.fromRGB(0, 255, 60) else Color3.fromRGB(115, 124, 130), 2, 0),
		}),
		Name = label({
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(30, -1),
			Size = UDim2.new(1, -30, 0, 14),
			Text = if active then `PLAYER {index}` else "EMPTY SLOT",
			TextSize = 12,
			ZIndex = 9,
		}),
		Status = label({
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(30, 11),
			Size = UDim2.new(1, -30, 0, 11),
			Text = if active then "STATUS | READY" else "STATUS | OPEN",
			TextSize = 8,
			ZIndex = 9,
		}),
	})
end

local function LobbyQueueApp(props)
	local network = props.Network
	local prompt, setPrompt = React.useState(nil)
	local selectedMapIndex, setSelectedMapIndex = React.useState(1)
	local selectedDifficulty, setSelectedDifficulty = React.useState(DIFFICULTIES[1].Name)
	local selectedPlayers, setSelectedPlayers = React.useState(1)
	local status, setStatus = React.useState("")
	local clock, setClock = React.useState(0)
	local hoveredMapIndex, setHoveredMapIndex = React.useState(nil)
	local hoveredDifficulty, setHoveredDifficulty = React.useState(nil)
	local hoveredPlayers, setHoveredPlayers = React.useState(nil)
	local createHovered, setCreateHovered = React.useState(false)
	local leaveHovered, setLeaveHovered = React.useState(false)
	local mapClickTimes, setMapClickTimes = React.useState({})
	local difficultyClickTimes, setDifficultyClickTimes = React.useState({})
	local playerClickTimes, setPlayerClickTimes = React.useState({})
	local createClickTime, setCreateClickTime = React.useState(nil)
	local leaveClickTime, setLeaveClickTime = React.useState(nil)

	React.useEffect(function()
		local alive = true
		local accumulator = 0
		local heartbeat = RunService.Heartbeat:Connect(function(deltaTime)
			accumulator += deltaTime

			if accumulator >= 1 / 30 then
				accumulator = 0

				if alive then
					setClock(os.clock())
				end
			end
		end)

		network.queuePrompt.listen(function(data)
			setPrompt(data)
			setStatus(if data.isCreator then "CONFIGURE THE MISSION" else "WAITING FOR PARTY LEADER")
			setSelectedPlayers(math.clamp(selectedPlayers, 1, data.maxPlayers))
		end)

		network.queueForceLeave.listen(function(data)
			setPrompt(nil)
			setStatus(data.message or "")
		end)

		return function()
			alive = false
			heartbeat:Disconnect()
		end
	end, {})

	local visible = prompt ~= nil
	local isCreator = visible and prompt.isCreator
	local maxPlayers = if visible then prompt.maxPlayers else 4
	local selectedMap = MAPS[selectedMapIndex]

	local mapCards = {
		List = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, map in MAPS do
		mapCards[`Map{index}`] = mapCard(map, selectedMapIndex == index, hoveredMapIndex == index, mapClickTimes[index], function()
			local nextTimes = table.clone(mapClickTimes)
			nextTimes[index] = os.clock()
			setMapClickTimes(nextTimes)
			setSelectedMapIndex(index)
		end, function(isHovered)
			setHoveredMapIndex(if isHovered then index else nil)
		end, index, clock)
	end

	local difficultyChildren = {
		List = e("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, difficulty in DIFFICULTIES do
		difficultyChildren[`Difficulty{index}`] = selectorButton(difficulty.Name, selectedDifficulty == difficulty.Name, hoveredDifficulty == difficulty.Name, difficultyClickTimes[difficulty.Name], difficulty.Color, function()
			local nextTimes = table.clone(difficultyClickTimes)
			nextTimes[difficulty.Name] = os.clock()
			setDifficultyClickTimes(nextTimes)
			setSelectedDifficulty(difficulty.Name)
		end, function(isHovered)
			setHoveredDifficulty(if isHovered then difficulty.Name else nil)
		end, index, clock)
	end

	local playerButtons = {
		Grid = e("UIGridLayout", {
			CellPadding = UDim2.fromOffset(8, 8),
			CellSize = UDim2.new(0.5, -4, 0, 36),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for count = 1, maxPlayers do
		playerButtons[`PlayerCount{count}`] = selectorButton(tostring(count), selectedPlayers == count, hoveredPlayers == count, playerClickTimes[count], RED, function()
			local nextTimes = table.clone(playerClickTimes)
			nextTimes[count] = os.clock()
			setPlayerClickTimes(nextTimes)
			setSelectedPlayers(count)
		end, function(isHovered)
			setHoveredPlayers(if isHovered then count else nil)
		end, count, clock)
	end

	local rosterChildren = {
		List = e("UIListLayout", {
			Padding = UDim.new(0, 3),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index = 1, 4 do
		rosterChildren[`Slot{index}`] = playerSlot(index, index <= selectedPlayers)
	end

	local createShine = (math.sin(clock * 7) + 1) / 2
	local accentFlash = (math.sin(clock * 10) + 1) / 2
	local createScale = 1 + (if createHovered then 0.04 else 0) + bounceSince(clock, createClickTime, 0.32, 0.14)
	local leaveScale = 1 + (if leaveHovered then 0.035 else 0) + bounceSince(clock, leaveClickTime, 0.26, 0.12)

	return e("ScreenGui", {
		DisplayOrder = 40,
		Enabled = visible,
		IgnoreGuiInset = true,
		Name = "LobbyQueueGui",
		ResetOnSpawn = false,
	}, {
		Dim = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.36,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
		}),

		Main = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromOffset(770, 455),
			ZIndex = 2,
		}, {
			Left = e("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(440, 455),
				ZIndex = 3,
			}, {
				Featured = e("Frame", {
					BackgroundColor3 = RED,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(0, 42),
					Size = UDim2.fromOffset(440, 246),
					ZIndex = 4,
				}, {
					Corner = corner(8),
					Stroke = stroke(nil, 3, 0),
					Tab = redTab("LOBBY"),
					Inner = e("Frame", {
						BackgroundColor3 = INK,
						BorderSizePixel = 0,
						ClipsDescendants = true,
						Position = UDim2.fromOffset(4, 4),
						Size = UDim2.new(1, -8, 1, -24),
						ZIndex = 5,
					}, {
						Corner = corner(7),
						Backdrop = mapBackdrop(selectedMap, 5),
		TopFlash = e("Frame", {
			BackgroundColor3 = if selectedMap.Name == "STORM LAB" then LIGHTNING else WHITE,
			BackgroundTransparency = 0.88 - (accentFlash * 0.08),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 0),
							Size = UDim2.new(1, 0, 0, 6),
							ZIndex = 13,
						}, {
							Corner = corner(6),
						}),
						Shade = e("Frame", {
							BackgroundColor3 = Color3.fromRGB(0, 0, 0),
							BackgroundTransparency = 0.18,
							BorderSizePixel = 0,
							Position = UDim2.new(0, 0, 1, -82),
							Size = UDim2.new(1, 0, 0, 82),
							ZIndex = 12,
						}, {
							Corner = corner(7),
						}),
						Title = label({
							Font = Enum.Font.GothamBlack,
							Position = UDim2.new(0, 14, 1, -77),
							Size = UDim2.new(1, -28, 0, 34),
							Text = selectedMap.Title,
							TextSize = 25,
							ZIndex = 13,
						}),
		Meta = label({
			Font = Enum.Font.GothamBlack,
			Position = UDim2.new(0, 14, 1, -43),
			Size = UDim2.new(1, -28, 0, 16),
			Text = `DIFFICULTY | {selectedDifficulty}`,
			TextSize = 15,
			ZIndex = 13,
		}),
		Threat = label({
			Font = Enum.Font.GothamBlack,
			Position = UDim2.new(0, 14, 1, -24),
			Size = UDim2.new(1, -28, 0, 14),
			Text = selectedMap.Threat,
			TextSize = 12,
			ZIndex = 13,
		}),
	}),
}),

				MapCards = if isCreator then e("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, 312),
					Size = UDim2.fromOffset(440, 96),
					ZIndex = 4,
				}, mapCards) else nil,

				Waiting = if not isCreator then e("Frame", {
					BackgroundColor3 = RED,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(0, 312),
					Size = UDim2.fromOffset(440, 72),
					ZIndex = 4,
				}, {
					Corner = corner(8),
					Stroke = stroke(nil, 2, 0),
					Message = label({
						Font = Enum.Font.GothamBlack,
						Size = UDim2.fromScale(1, 1),
						Text = "WAITING FOR MATCH START",
						TextSize = 22,
						TextXAlignment = Enum.TextXAlignment.Center,
						ZIndex = 5,
					}),
				}) else nil,
			}),

			Right = e("Frame", {
				BackgroundColor3 = PANEL,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(470, 42),
				Size = UDim2.fromOffset(300, 430),
				ZIndex = 4,
			}, {
				Corner = corner(8),
				Stroke = stroke(RED, 3, 0),
				Header = e("Frame", {
					BackgroundColor3 = RED_DARK,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 70),
					ZIndex = 5,
				}, {
					Corner = corner(7),
					Title = label({
						Font = Enum.Font.GothamBlack,
						Position = UDim2.fromOffset(12, 7),
						Size = UDim2.new(1, -24, 0, 32),
						Text = if isCreator then "MISSION SETUP" else "SQUAD STATUS",
						TextSize = 24,
						ZIndex = 6,
					}),
					Status = label({
						Font = Enum.Font.GothamBlack,
						Position = UDim2.fromOffset(13, 40),
						Size = UDim2.new(1, -26, 0, 20),
						Text = status,
						TextSize = 13,
						ZIndex = 6,
					}),
				}),

				Difficulty = if isCreator then e("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(14, 88),
					Size = UDim2.fromOffset(128, 130),
					ZIndex = 6,
				}, {
					Title = label({
						Position = UDim2.fromOffset(0, -25),
						Size = UDim2.fromOffset(130, 22),
						Text = "DIFFICULTY",
						TextSize = 15,
						ZIndex = 7,
					}),
					List = e("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 7,
					}, difficultyChildren),
				}) else nil,

				Players = if isCreator then e("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(158, 88),
					Size = UDim2.fromOffset(128, 80),
					ZIndex = 6,
				}, {
					Title = label({
						Position = UDim2.fromOffset(0, -25),
						Size = UDim2.fromOffset(130, 22),
						Text = "PLAYERS",
						TextSize = 15,
						ZIndex = 7,
					}),
					Grid = e("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 7,
					}, playerButtons),
				}) else nil,

				Roster = e("Frame", {
					BackgroundColor3 = PANEL_SOFT,
					BackgroundTransparency = 0.25,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(14, if isCreator then 236 else 92),
					Size = UDim2.fromOffset(272, if isCreator then 112 else 220),
					ZIndex = 6,
				}, {
					Corner = corner(7),
					Padding = e("UIPadding", {
						PaddingLeft = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 8),
						PaddingTop = UDim.new(0, 7),
					}),
					Stroke = stroke(Color3.fromRGB(92, 38, 51), 1, 0.18),
					Slots = e("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, -8, 1, -6),
						ZIndex = 7,
					}, rosterChildren),
				}),

				Create = if isCreator then e("TextButton", {
					BackgroundColor3 = RED,
					BorderSizePixel = 0,
					Font = Enum.Font.GothamBlack,
					Position = UDim2.new(0, 14, 1, -48),
					Size = UDim2.new(1, -28, 0, 36),
					Text = "CREATE",
					TextColor3 = WHITE,
					TextSize = 20,
					TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
					TextStrokeTransparency = 0.08,
					ZIndex = 8,
					[React.Event.Activated] = function()
						setCreateClickTime(os.clock())
						network.queueCreate.send({
							map = selectedMap.Title,
							difficulty = selectedDifficulty,
							maxPlayers = selectedPlayers,
						})

						setStatus("WAITING FOR PLAYERS")
						setPrompt({
							isCreator = false,
							maxPlayers = maxPlayers,
						})
					end,
					[React.Event.MouseEnter] = function()
						setCreateHovered(true)
					end,
					[React.Event.MouseLeave] = function()
						setCreateHovered(false)
					end,
				}, {
					Corner = corner(6),
					Stroke = stroke(WHITE, 2, 0.05),
					Scale = e("UIScale", {
						Scale = createScale,
					}),
					Shine = e("Frame", {
						BackgroundColor3 = WHITE,
						BackgroundTransparency = if createHovered then 0.78 - (createShine * 0.18) else 0.9 - (createShine * 0.1),
						BorderSizePixel = 0,
						Position = UDim2.new(createShine, -70, 0, 0),
						Rotation = 12,
						Size = UDim2.fromOffset(44, 46),
						ZIndex = 9,
					}, {
						Corner = corner(5),
					}),
				}) else nil,

				Leave = e("TextButton", {
					BackgroundColor3 = Color3.fromRGB(31, 35, 48),
					BorderSizePixel = 0,
					Font = Enum.Font.GothamBlack,
					Position = UDim2.new(0, 14, 1, if isCreator then -88 else -52),
					Size = UDim2.new(1, -28, 0, 30),
					Text = "LEAVE QUEUE",
					TextColor3 = WHITE,
					TextSize = 14,
					TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
					TextStrokeTransparency = 0.08,
					ZIndex = 8,
					[React.Event.Activated] = function()
						setLeaveClickTime(os.clock())
						network.queueLeave.send()
						setPrompt(nil)
					end,
					[React.Event.MouseEnter] = function()
						setLeaveHovered(true)
					end,
					[React.Event.MouseLeave] = function()
						setLeaveHovered(false)
					end,
				}, {
					Corner = corner(6),
					Stroke = stroke(RED, 2, 0.1),
					Scale = e("UIScale", {
						Scale = leaveScale,
					}),
				}),
			}),
		}),
	})
end

return LobbyQueueApp
