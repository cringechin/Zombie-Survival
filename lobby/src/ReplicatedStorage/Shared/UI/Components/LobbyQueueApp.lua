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
		Accent = Color3.fromRGB(85, 216, 255),
		Dark = Color3.fromRGB(20, 42, 74),
		Fog = Color3.fromRGB(154, 243, 255),
		ImagePath = "Assets.MapImages.Lab",
		ImageTemplate = "rbxasset://textures/ui/GuiImagePlaceholder.png",
	},
	{
		Name = "Rotwood Crypt",
		Title = "ROTWOOD CRYPT",
		Threat = "HORDE | GRAVEBORN",
		Description = "BURIAL GROUNDS UNDER LOCKDOWN",
		Accent = Color3.fromRGB(115, 224, 93),
		Dark = Color3.fromRGB(30, 69, 42),
		Fog = Color3.fromRGB(170, 244, 137),
		ImageTemplate = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		Locked = true,
	},
	{
		Name = "Deadline Metro",
		Title = "DEADLINE METRO",
		Threat = "SWARM | TUNNEL DEAD",
		Description = "BLACKOUT TRANSIT HUB",
		Accent = Color3.fromRGB(255, 83, 68),
		Dark = Color3.fromRGB(79, 30, 37),
		Fog = Color3.fromRGB(255, 170, 126),
		ImageTemplate = "rbxasset://textures/ui/GuiImagePlaceholder.png",
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
		child:Destroy()
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
	end

	if not source then
		return
	end

	if source:IsA("GuiObject") then
		local clone = source:Clone()
		clone.Name = "MapPreviewClone"
		clone.AnchorPoint = Vector2.new(0, 0)
		clone.Position = UDim2.fromScale(0, 0)
		clone.Size = UDim2.fromScale(1, 1)
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
		Name = if map.ImagePath then "MapPreviewHost" else nil,
		Size = UDim2.fromScale(1, 1),
		ZIndex = zIndex,
	}, {
		Corner = corner(8),
		Stroke = stroke(Color3.fromRGB(0, 0, 0), 2, 0),
		Locked = if map.Locked then label({
			Font = Enum.Font.GothamBlack,
			Size = UDim2.fromScale(1, 1),
			Text = "COMING SOON",
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = zIndex + 3,
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
			Text = "▼",
			TextColor3 = Color3.fromRGB(20, 24, 32),
			TextSize = 14,
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = zIndex + 1,
		}),
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

local function getNextUnlockedMapIndex(currentIndex, direction)
	local count = #MAPS
	local index = currentIndex

	for _ = 1, count do
		index += direction

		if index > count then
			index = 1
		elseif index < 1 then
			index = count
		end

		if not MAPS[index].Locked then
			return index
		end
	end

	return currentIndex
end

local function LobbyQueueApp(props)
	local network = props.Network
	local bestWave, setBestWave = React.useState(0)
	local prompt, setPrompt = React.useState(nil)
	local selectedMapIndex, setSelectedMapIndex = React.useState(1)
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
		end)

		network.queueForceLeave.listen(function(data)
			setPrompt(nil)
			setStatus(data.message or "")
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
		if not selectedMap or not selectedMap.ImagePath then
			return
		end

		task.defer(function()
			mountMapPreview(selectedMap.ImagePath)
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

	local createScale = 1 + (if createHovered then 0.03 else 0) + bounceSince(clock, createClickTime, 0.32, 0.12)
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
					ZIndex = 4,
				}, {
					Dropdown = dropdownButton(selectedMap.Name, isCreator, function()
						setSelectedMapIndex(getNextUnlockedMapIndex(selectedMapIndex, 1))
					end, 5),
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
					AutoButtonColor = false,
					BackgroundColor3 = GREEN,
					BorderSizePixel = 0,
					Font = Enum.Font.GothamBlack,
					Position = UDim2.new(0.5, 0, 1, 0),
					Size = UDim2.new(1, -12, 0, 58),
					Text = "CREATE",
					TextColor3 = WHITE,
					TextSize = 28,
					TextStrokeTransparency = 0.08,
					ZIndex = 6,
					[React.Event.Activated] = function()
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
					end,
					[React.Event.MouseEnter] = function()
						setCreateHovered(true)
					end,
					[React.Event.MouseLeave] = function()
						setCreateHovered(false)
					end,
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
