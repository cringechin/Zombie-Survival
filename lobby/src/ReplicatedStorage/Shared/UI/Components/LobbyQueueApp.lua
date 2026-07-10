local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local e = React.createElement

local MAPS = {
	{
		Name = "Lab",
		Title = "STORMBREAK LABS",
		Threat = "BOSS | LIGHTNING REVENANT",
		Description = "OVERRUN RESEARCH FACILITY",
		Status = "LIVE",
		Accent = Color3.fromRGB(85, 216, 255),
		Dark = Color3.fromRGB(20, 42, 74),
		Fog = Color3.fromRGB(154, 243, 255),
		ImagePath = "Assets.MapImages.LabIcon",
		ImageTemplate = "rbxasset://textures/ui/GuiImagePlaceholder.png",
	},
	{
		Name = "Volcano",
		Title = "VOLCANO",
		Threat = "DISASTER | LAVA SURGE",
		Description = "MOLTEN FACILITY BREACH",
		Status = "WIP",
		Accent = Color3.fromRGB(255, 106, 52),
		Dark = Color3.fromRGB(64, 28, 25),
		Fog = Color3.fromRGB(255, 174, 92),
		Locked = true,
	},
	{
		Name = "Tornado",
		Title = "TORNADO",
		Threat = "DISASTER | CYCLONE FIELD",
		Description = "WIND-SHEAR CONTAINMENT",
		Status = "WIP",
		Accent = Color3.fromRGB(139, 226, 218),
		Dark = Color3.fromRGB(29, 47, 58),
		Fog = Color3.fromRGB(190, 245, 240),
		Locked = true,
	},
}

local DIFFICULTIES = {
	{
		Name = "NORMAL",
		Display = "Normal",
		Color = Color3.fromRGB(57, 230, 91),
		CreditsPerKill = 5,
		Modifier = "1% Galactic zombie chance",
		ModifierColor = Color3.fromRGB(170, 140, 255),
	},
	{
		Name = "HARD",
		Display = "Hard",
		Color = Color3.fromRGB(255, 190, 46),
		CreditsPerKill = 8,
		Modifier = "3% Galactic zombie chance",
		ModifierColor = Color3.fromRGB(170, 140, 255),
	},
	{
		Name = "NIGHTMARE",
		Display = "Nightmare",
		Color = Color3.fromRGB(255, 61, 84),
		CreditsPerKill = 12,
		Modifier = "6% Galactic zombie chance",
		ModifierColor = Color3.fromRGB(170, 140, 255),
	},
}

local PANEL = Color3.fromRGB(24, 26, 32)
local PANEL_DARK = Color3.fromRGB(16, 18, 24)
local DROPDOWN = Color3.fromRGB(168, 210, 236)
local GREEN = Color3.fromRGB(72, 196, 84)
local GREEN_BRIGHT = Color3.fromRGB(88, 220, 96)
local GREY = Color3.fromRGB(176, 182, 194)
local WHITE = Color3.fromRGB(248, 248, 240)
local RED = Color3.fromRGB(220, 52, 58)

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

local function stroke(color, thickness, transparency)
	return e("UIStroke", {
		Color = color or Color3.fromRGB(0, 0, 0),
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
		TextColor3 = props.TextColor3 or WHITE,
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

local function findMapAsset(imagePath)
	local node = ReplicatedStorage
	local segments = string.split(imagePath, ".")

	for index, segment in segments do
		if index == #segments then
			node = node:WaitForChild(segment, 10)
		else
			node = node:FindFirstChild(segment)
		end

		if not node then
			return nil
		end
	end

	return node
end

local function mountMapPreview(imagePath)
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local host = playerGui and playerGui:FindFirstChild("MapPreviewHost", true)
	if not host or not host:IsA("GuiObject") then
		return
	end

	for _, child in host:GetChildren() do
		if child.Name == "MapPreviewClone" then
			child:Destroy()
		end
	end

	if not imagePath then
		return
	end

	local source = findMapAsset(imagePath)
	if not source then
		return
	end

	if source:IsA("Folder") then
		source = source:FindFirstChildWhichIsA("ImageLabel", true)
			or source:FindFirstChildWhichIsA("ImageButton", true)
			or source:FindFirstChildWhichIsA("Decal", true)
			or source:FindFirstChildWhichIsA("Texture", true)
			or source:FindFirstChildWhichIsA("StringValue", true)
	end

	if not source then
		return
	end

	if source:IsA("GuiObject") then
		local clone = source:Clone()
		clone.Name = "MapPreviewClone"
		clone.AnchorPoint = Vector2.new(0, 0)
		clone.BackgroundTransparency = 1
		clone.Position = UDim2.fromScale(0, 0)
		clone.Size = UDim2.fromScale(1, 1)
		if clone:IsA("ImageLabel") or clone:IsA("ImageButton") then
			clone.ScaleType = Enum.ScaleType.Crop
		end
		clone.Visible = true
		clone.ZIndex = host.ZIndex + 1
		clone.Parent = host
		return
	end

	local preview = Instance.new("ImageLabel")
	preview.Name = "MapPreviewClone"
	preview.BackgroundTransparency = 1
	preview.Position = UDim2.fromScale(0, 0)
	preview.Size = UDim2.fromScale(1, 1)
	preview.ScaleType = Enum.ScaleType.Crop
	preview.ZIndex = host.ZIndex + 1
	preview.Parent = host

	if source:IsA("Decal") or source:IsA("Texture") then
		preview.Image = source.Texture
	elseif source:IsA("ImageLabel") or source:IsA("ImageButton") then
		preview.Image = source.Image
	elseif source:IsA("StringValue") then
		preview.Image = source.Value
	else
		local assigned = pcall(function()
			preview.Image = source
		end)

		if not assigned then
			preview.Image = source:GetAttribute("Image") or ""
		end
	end
end

local function mapPreview(map, zIndex)
	return e("Frame", {
		BackgroundColor3 = map.Dark,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = zIndex,
	}, {
		Corner = corner(8),
		Stroke = stroke(map.Accent, 1, 0.35),
		ImageMount = e("Frame", {
			BackgroundColor3 = map.Dark,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Name = "MapPreviewHost",
			Size = UDim2.fromScale(1, 1),
			ZIndex = zIndex + 1,
		}, {
			Placeholder = if not map.ImagePath then e("Frame", {
				BackgroundColor3 = map.Dark,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = zIndex + 1,
			}, {
				Glow = e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = map.Accent,
					BackgroundTransparency = 0.72,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.5, 0.42),
					Size = UDim2.fromOffset(132, 132),
					ZIndex = zIndex + 2,
				}, {
					Corner = corner(66),
				}),
				Initial = label({
					AnchorPoint = Vector2.new(0.5, 0.5),
					Font = Enum.Font.GothamBlack,
					Position = UDim2.fromScale(0.5, 0.42),
					Size = UDim2.fromOffset(154, 42),
					Text = map.Name,
					TextColor3 = map.Fog,
					TextSize = 24,
					TextStrokeTransparency = 0.18,
					TextXAlignment = Enum.TextXAlignment.Center,
					ZIndex = zIndex + 3,
				}),
			}) else nil,
		}),
		Tint = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = if map.ImagePath then 0.54 else 0.68,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 0.58),
			Size = UDim2.fromScale(1, 0.42),
			ZIndex = zIndex + 4,
		}),
		Badge = e("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = if map.Locked then Color3.fromRGB(56, 61, 72) else map.Accent,
			BackgroundTransparency = if map.Locked then 0.08 else 0,
			BorderSizePixel = 0,
			Position = UDim2.new(1, -10, 0, 10),
			Size = UDim2.fromOffset(if map.Locked then 46 else 42, 22),
			ZIndex = zIndex + 6,
		}, {
			Corner = corner(6),
			Text = label({
				Font = Enum.Font.GothamBlack,
				Size = UDim2.fromScale(1, 1),
				Text = map.Status or (if map.Locked then "WIP" else "LIVE"),
				TextColor3 = if map.Locked then Color3.fromRGB(218, 224, 232) else Color3.fromRGB(12, 20, 28),
				TextSize = 12,
				TextStrokeTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = zIndex + 7,
			}),
		}),
		Title = label({
			Font = Enum.Font.GothamBlack,
			Position = UDim2.new(0, 14, 1, -76),
			Size = UDim2.new(1, -28, 0, 26),
			Text = map.Title,
			TextColor3 = WHITE,
			TextSize = 21,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = zIndex + 6,
		}),
		Threat = label({
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(0, 14, 1, -48),
			Size = UDim2.new(1, -28, 0, 18),
			Text = map.Threat,
			TextColor3 = map.Accent,
			TextSize = 13,
			TextStrokeTransparency = 0.35,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = zIndex + 6,
		}),
		Description = label({
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(0, 14, 1, -28),
			Size = UDim2.new(1, -28, 0, 18),
			Text = map.Description,
			TextColor3 = Color3.fromRGB(211, 222, 232),
			TextSize = 12,
			TextStrokeTransparency = 0.45,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = zIndex + 6,
		}),
		Locked = if map.Locked then e("Frame", {
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = zIndex + 5,
		}) else nil,
	})
end

local function dropdownButton(textValue, enabled, onActivated, zIndex)
	return e("TextButton", {
		AutoButtonColor = enabled,
		BackgroundColor3 = if enabled then DROPDOWN else Color3.fromRGB(120, 124, 132),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Size = UDim2.new(1, 0, 0, 38),
		Text = "",
		ZIndex = zIndex,
		[React.Event.Activated] = if enabled then onActivated else nil,
	}, {
		Corner = corner(6),
		Stroke = stroke(Color3.fromRGB(0, 0, 0), 2, 0),
		Value = label({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -36, 1, 0),
			Text = textValue,
			TextColor3 = Color3.fromRGB(20, 24, 32),
			TextSize = 18,
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = zIndex + 1,
		}),
		Arrow = label({
			AnchorPoint = Vector2.new(1, 0.5),
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
			Text = "v",
			TextColor3 = Color3.fromRGB(20, 24, 32),
			TextSize = 14,
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = zIndex + 1,
		}),
	})
end

local function mapDropdownItem(map, selected, enabled, onActivated, layoutOrder, zIndex)
	local textColor = if enabled then WHITE else Color3.fromRGB(168, 176, 188)

	return e("TextButton", {
		AutoButtonColor = enabled,
		BackgroundColor3 = if selected then Color3.fromRGB(44, 50, 62) else Color3.fromRGB(27, 30, 38),
		BackgroundTransparency = if enabled then 0 else 0.12,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 38),
		Text = "",
		ZIndex = zIndex,
		[React.Event.Activated] = if enabled then onActivated else nil,
	}, {
		Corner = corner(5),
		Accent = e("Frame", {
			BackgroundColor3 = if enabled then map.Accent else Color3.fromRGB(75, 82, 94),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(0, 3, 1, -16),
			ZIndex = zIndex + 1,
		}, {
			Corner = corner(3),
		}),
		Name = label({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(18, 0),
			Size = UDim2.new(1, -72, 1, 0),
			Text = map.Name,
			TextColor3 = textColor,
			TextSize = 15,
			TextStrokeTransparency = if enabled then 0.45 else 0.8,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = zIndex + 2,
		}),
		Status = if map.Locked then e("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = Color3.fromRGB(58, 63, 74),
			BorderSizePixel = 0,
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(42, 22),
			ZIndex = zIndex + 2,
		}, {
			Corner = corner(5),
			Text = label({
				Font = Enum.Font.GothamBlack,
				Size = UDim2.fromScale(1, 1),
				Text = "WIP",
				TextColor3 = Color3.fromRGB(219, 225, 233),
				TextSize = 12,
				TextStrokeTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = zIndex + 3,
			}),
		}) else nil,
	})
end

local function partySizeButton(count, selected, enabled, onActivated, layoutOrder, zIndex)
	return e("TextButton", {
		AutoButtonColor = enabled,
		BackgroundColor3 = if selected then GREEN_BRIGHT else GREY,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBlack,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(72, 72),
		Text = tostring(count),
		TextColor3 = if selected then WHITE else Color3.fromRGB(36, 40, 48),
		TextSize = 34,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = if selected then 0.08 else 1,
		ZIndex = zIndex,
		[React.Event.Activated] = if enabled then onActivated else nil,
	}, {
		Corner = corner(8),
		Stroke = stroke(Color3.fromRGB(0, 0, 0), 2, 0),
	})
end

local function getDifficultyInfo(name)
	for _, difficulty in DIFFICULTIES do
		if difficulty.Name == name then
			return difficulty
		end
	end

	return DIFFICULTIES[1]
end

local function LobbyQueueApp(props)
	local network = props.Network
	local bestWave, setBestWave = React.useState(0)
	local prompt, setPrompt = React.useState(nil)
	local selectedMapIndex, setSelectedMapIndex = React.useState(1)
	local mapDropdownOpen, setMapDropdownOpen = React.useState(false)
	local selectedDifficulty, setSelectedDifficulty = React.useState(DIFFICULTIES[1].Name)
	local selectedPlayers, setSelectedPlayers = React.useState(1)
	local status, setStatus = React.useState("")
	local clock, setClock = React.useState(0)
	local createHovered, setCreateHovered = React.useState(false)
	local closeHovered, setCloseHovered = React.useState(false)
	local createClickTime, setCreateClickTime = React.useState(nil)
	local closeClickTime, setCloseClickTime = React.useState(nil)

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
			setStatus(if data.isCreator then "" else "Waiting for party leader...")
			setSelectedPlayers(math.clamp(selectedPlayers, 1, data.maxPlayers))
			setMapDropdownOpen(false)
		end)

		network.queueForceLeave.listen(function(data)
			setPrompt(nil)
			setStatus(data.message or "")
			setMapDropdownOpen(false)
		end)

		network.storeState.listen(function(data)
			setBestWave(data.bestWave or 0)
		end)
		network.storeStateRequest.send()

		return function()
			alive = false
			heartbeat:Disconnect()
		end
	end, {})

	React.useEffect(function()
		if not prompt then
			return
		end

		local selectedMap = MAPS[selectedMapIndex]
		local imagePath = if selectedMap then selectedMap.ImagePath else nil

		task.defer(function()
			mountMapPreview(imagePath)
		end)

		return function()
			mountMapPreview(nil)
		end
	end, { prompt, selectedMapIndex })

	local visible = prompt ~= nil
	local isCreator = visible and prompt.isCreator
	local maxPlayers = if visible then prompt.maxPlayers else 4
	local selectedMap = MAPS[selectedMapIndex]
	local difficultyInfo = getDifficultyInfo(selectedDifficulty)
	local canCreateQueue = isCreator and selectedMap and not selectedMap.Locked

	local partyButtons = {
		Row = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for count = 1, maxPlayers do
		partyButtons[`Size{count}`] = partySizeButton(count, selectedPlayers == count, isCreator, function()
			setSelectedPlayers(count)
		end, count, 8)
	end

	local mapOptions = {
		Padding = e("UIPadding", {
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 6),
		}),
		List = e("UIListLayout", {
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, map in MAPS do
		local optionIndex = index
		local optionEnabled = isCreator and not map.Locked
		mapOptions[`Map{index}`] = mapDropdownItem(map, selectedMapIndex == optionIndex, optionEnabled, function()
			setSelectedMapIndex(optionIndex)
			setMapDropdownOpen(false)
		end, index, 32)
	end

	local createScale = 1
	if canCreateQueue then
		createScale += (if createHovered then 0.03 else 0) + bounceSince(clock, createClickTime, 0.32, 0.12)
	end
	local closeScale = 1 + (if closeHovered then 0.05 else 0) + bounceSince(clock, closeClickTime, 0.26, 0.1)

	return e("ScreenGui", {
		DisplayOrder = 40,
		Enabled = true,
		IgnoreGuiInset = true,
		Name = "LobbyQueueGui",
		ResetOnSpawn = false,
	}, {
		Dim = if visible then e("Frame", {
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.42,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
		}) else nil,

		Main = if visible then e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = PANEL,
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(860, 430),
			ZIndex = 2,
		}, {
			Corner = corner(12),
			Stroke = stroke(Color3.fromRGB(0, 0, 0), 3, 0),

			Close = e("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				AutoButtonColor = false,
				BackgroundColor3 = RED,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.new(1, -14, 0, 14),
				Size = UDim2.fromOffset(52, 52),
				Text = "X",
				TextColor3 = WHITE,
				TextSize = 28,
				TextStrokeTransparency = 0.1,
				ZIndex = 20,
				[React.Event.Activated] = function()
					setCloseClickTime(os.clock())
					network.queueLeave.send()
					setPrompt(nil)
					setMapDropdownOpen(false)
				end,
				[React.Event.MouseEnter] = function()
					setCloseHovered(true)
				end,
				[React.Event.MouseLeave] = function()
					setCloseHovered(false)
				end,
			}, {
				Corner = corner(8),
				Stroke = stroke(Color3.fromRGB(0, 0, 0), 2, 0),
				Scale = e("UIScale", {
					Scale = closeScale,
				}),
			}),

			MapColumn = e("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(24, 28),
				Size = UDim2.fromOffset(220, 374),
				ZIndex = 3,
			}, {
				Title = label({
					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.new(1, 0, 0, 28),
					Text = "Map:",
					TextSize = 22,
					ZIndex = 4,
				}),
				DropdownFrame = e("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, 34),
					Size = UDim2.new(1, 0, 0, 38),
					ZIndex = 28,
				}, {
					Dropdown = dropdownButton(selectedMap.Name, isCreator, function()
						setMapDropdownOpen(not mapDropdownOpen)
					end, 29),
					Options = if mapDropdownOpen then e("Frame", {
						BackgroundColor3 = Color3.fromRGB(18, 20, 26),
						BackgroundTransparency = 0.02,
						BorderSizePixel = 0,
						Position = UDim2.fromOffset(0, 44),
						Size = UDim2.new(1, 0, 0, 142),
						ZIndex = 30,
					}, {
						Corner = corner(7),
						Stroke = stroke(Color3.fromRGB(0, 0, 0), 2, 0.05),
						Items = e("Frame", {
							BackgroundTransparency = 1,
							Size = UDim2.fromScale(1, 1),
							ZIndex = 31,
						}, mapOptions),
					}) else nil,
				}),
				Preview = e("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, 84),
					Size = UDim2.new(1, 0, 1, -84),
					ZIndex = 4,
				}, {
					PreviewImage = mapPreview(selectedMap, 5),
				}),
			}),

			PartyColumn = e("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(268, 28),
				Size = UDim2.fromOffset(300, 374),
				ZIndex = 3,
			}, {
				Title = label({
					Position = UDim2.fromOffset(0, 8),
					Size = UDim2.new(1, 0, 0, 48),
					Text = "Party Size",
					TextSize = 34,
					TextXAlignment = Enum.TextXAlignment.Center,
					ZIndex = 4,
				}),
				Buttons = e("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, 88),
					Size = UDim2.new(1, 0, 0, 80),
					ZIndex = 4,
				}, partyButtons),
				Status = if not isCreator then label({
					Position = UDim2.fromOffset(0, 188),
					Size = UDim2.new(1, 0, 0, 28),
					Text = status,
					TextColor3 = Color3.fromRGB(200, 205, 214),
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Center,
					ZIndex = 4,
				}) else nil,
				Create = if isCreator then e("TextButton", {
					AnchorPoint = Vector2.new(0.5, 1),
					AutoButtonColor = canCreateQueue,
					BackgroundColor3 = if canCreateQueue then GREEN else Color3.fromRGB(77, 84, 96),
					BorderSizePixel = 0,
					Font = Enum.Font.GothamBlack,
					Position = UDim2.new(0.5, 0, 1, 0),
					Size = UDim2.new(1, -12, 0, 58),
					Text = if canCreateQueue then "CREATE" else "MAP WIP",
					TextColor3 = if canCreateQueue then WHITE else Color3.fromRGB(215, 221, 230),
					TextSize = 28,
					TextStrokeTransparency = if canCreateQueue then 0.08 else 0.35,
					ZIndex = 6,
					[React.Event.Activated] = if canCreateQueue then function()
						setCreateClickTime(os.clock())
						network.queueCreate.send({
							map = selectedMap.Title,
							difficulty = selectedDifficulty,
							maxPlayers = selectedPlayers,
						})

						setStatus("Waiting for players...")
						setPrompt({
							isCreator = false,
							maxPlayers = maxPlayers,
						})
						setMapDropdownOpen(false)
					end else nil,
					[React.Event.MouseEnter] = if canCreateQueue then function()
						setCreateHovered(true)
					end else nil,
					[React.Event.MouseLeave] = if canCreateQueue then function()
						setCreateHovered(false)
					end else nil,
				}, {
					Corner = corner(8),
					Stroke = stroke(Color3.fromRGB(0, 0, 0), 2, 0),
					Scale = e("UIScale", {
						Scale = createScale,
					}),
				}) else label({
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, 0),
					Size = UDim2.new(1, -12, 0, 58),
					Text = "WAITING FOR LEADER",
					TextColor3 = Color3.fromRGB(200, 205, 214),
					TextSize = 20,
					TextXAlignment = Enum.TextXAlignment.Center,
					ZIndex = 4,
				}),
			}),

			DifficultyColumn = e("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(592, 28),
				Size = UDim2.fromOffset(244, 374),
				ZIndex = 3,
			}, {
				Title = label({
					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.new(1, 0, 0, 28),
					Text = "Difficulty:",
					TextSize = 22,
					ZIndex = 4,
				}),
				DropdownFrame = e("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, 34),
					Size = UDim2.new(1, 0, 0, 38),
					ZIndex = 4,
				}, {
					Dropdown = dropdownButton(difficultyInfo.Display, isCreator, function()
						local currentIndex = 1
						for index, difficulty in DIFFICULTIES do
							if difficulty.Name == selectedDifficulty then
								currentIndex = index
								break
							end
						end

						local nextIndex = currentIndex % #DIFFICULTIES + 1
						setSelectedDifficulty(DIFFICULTIES[nextIndex].Name)
					end, 5),
				}),
				Stats = e("Frame", {
					BackgroundColor3 = PANEL_DARK,
					BackgroundTransparency = 0.05,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(0, 84),
					Size = UDim2.new(1, 0, 1, -84),
					ZIndex = 4,
				}, {
					Corner = corner(8),
					Stroke = stroke(Color3.fromRGB(0, 0, 0), 2, 0),
					Padding = e("UIPadding", {
						PaddingBottom = UDim.new(0, 12),
						PaddingLeft = UDim.new(0, 12),
						PaddingRight = UDim.new(0, 12),
						PaddingTop = UDim.new(0, 12),
					}),
					TopWave = e("Frame", {
						BackgroundColor3 = Color3.fromRGB(34, 38, 46),
						BorderSizePixel = 0,
						Size = UDim2.new(1, 0, 0, 42),
						ZIndex = 5,
					}, {
						Corner = corner(6),
						Label = label({
							Size = UDim2.fromScale(1, 1),
							Text = `PERSONAL TOP WAVE: {bestWave}`,
							TextSize = 15,
							TextXAlignment = Enum.TextXAlignment.Center,
							ZIndex = 6,
						}),
					}),
					Credits = label({
						Position = UDim2.fromOffset(0, 58),
						Size = UDim2.new(1, 0, 0, 28),
						Text = `{difficultyInfo.CreditsPerKill} Credits per kill`,
						TextColor3 = GREEN_BRIGHT,
						TextSize = 18,
						TextXAlignment = Enum.TextXAlignment.Center,
						ZIndex = 5,
					}),
					Modifier = label({
						Position = UDim2.fromOffset(0, 92),
						Size = UDim2.new(1, 0, 0, 28),
						Text = difficultyInfo.Modifier,
						TextColor3 = difficultyInfo.ModifierColor,
						TextSize = 16,
						TextXAlignment = Enum.TextXAlignment.Center,
						ZIndex = 5,
					}),
				}),
			}),
		}) else nil,
	})
end

return LobbyQueueApp
