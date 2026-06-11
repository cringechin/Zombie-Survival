local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local DisasterWeaponConfig = require(ReplicatedStorage.Shared.Weapons.DisasterWeaponConfig)

local e = React.createElement
local localPlayer = Players.LocalPlayer

local MAX_SLOTS = 9
local KEYCODES = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

local function corner(radius)
	return e("UICorner", {
		CornerRadius = UDim.new(0, radius or 6),
	})
end

local function stroke(color, thickness, transparency)
	return e("UIStroke", {
		Color = color or Color3.fromRGB(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = transparency or 0,
	})
end

local function getCooldownDuration(tool)
	local attributeDuration = tool:GetAttribute("CooldownDuration")
	if typeof(attributeDuration) == "number" then
		return attributeDuration
	end

	local config = DisasterWeaponConfig[tool.Name]
	return config and config.Cooldown or 0
end

local function getToolCooldown(tool, now)
	local cooldownEndsAt = tool:GetAttribute("CooldownEndsAt")
	local duration = getCooldownDuration(tool)

	if typeof(cooldownEndsAt) ~= "number" or duration <= 0 then
		return 0, 0
	end

	local remaining = math.max(cooldownEndsAt - now, 0)
	return remaining, math.clamp(remaining / duration, 0, 1)
end

local function getTools()
	local tools = {}
	local seen = {}
	local seenNames = {}
	local order = {}
	local backpack = localPlayer:FindFirstChildOfClass("Backpack")
	local character = localPlayer.Character

	local function collect(container)
		if not container then
			return
		end

		for _, child in container:GetChildren() do
			if child:IsA("Tool") and not seen[child] and not seenNames[child.Name] then
				seen[child] = true
				seenNames[child.Name] = true
				order[child] = #tools + 1
				table.insert(tools, child)
			end
		end
	end

	collect(character)
	collect(backpack)

	table.sort(tools, function(left, right)
		if left.Name == right.Name then
			return order[left] < order[right]
		end

		return left.Name < right.Name
	end)

	return tools
end

local function getSelectedTool()
	local character = localPlayer.Character
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Tool")
end

local function equipTool(tool)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and tool then
		humanoid:EquipTool(tool)
	end
end

local function unequipTools()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end
end

local function toolAccent(tool)
	if tool.Name == "Lightning" then
		return Color3.fromRGB(71, 210, 255), "L"
	end

	return Color3.fromRGB(116, 224, 130), string.sub(tool.Name, 1, 1)
end

local function Slot(props)
	local tool = props.Tool
	local selected = props.Selected
	local remaining, cooldownRatio = getToolCooldown(tool, props.Now)
	local accentColor, glyph = toolAccent(tool)
	local isCoolingDown = remaining > 0

	return e("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = if selected then Color3.fromRGB(54, 61, 96) else Color3.fromRGB(31, 34, 52),
		BackgroundTransparency = if selected then 0.02 else 0.1,
		BorderSizePixel = 0,
		LayoutOrder = props.Index,
		Size = UDim2.fromOffset(72, 72),
		Text = "",
		ZIndex = 40,
		[React.Event.Activated] = props.OnActivated,
	}, {
		Corner = corner(8),
		Stroke = stroke(if selected then Color3.fromRGB(205, 220, 255) else Color3.fromRGB(95, 91, 145), 3, 0.1),

		Key = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(20, 22, 36),
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(5, 5),
			Size = UDim2.fromOffset(20, 20),
			ZIndex = 43,
		}, {
			Corner = corner(5),
			Text = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Size = UDim2.fromScale(1, 1),
				Text = tostring(props.Index),
				TextColor3 = Color3.fromRGB(240, 250, 255),
				TextScaled = true,
				TextStrokeTransparency = 0.65,
				ZIndex = 44,
			}, {
				Limit = e("UITextSizeConstraint", {
					MaxTextSize = 14,
					MinTextSize = 8,
				}),
			}),
		}),

		Icon = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = accentColor,
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 0, 17),
			Size = UDim2.fromOffset(34, 28),
			ZIndex = 42,
		}, {
			Corner = corner(7),
			Stroke = stroke(Color3.fromRGB(255, 255, 255), 1, 0.35),
			Glyph = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Size = UDim2.fromScale(1, 1),
				Text = glyph,
				TextColor3 = Color3.fromRGB(10, 28, 42),
				TextScaled = true,
				TextStrokeTransparency = 1,
				ZIndex = 43,
			}, {
				Limit = e("UITextSizeConstraint", {
					MaxTextSize = 21,
					MinTextSize = 10,
				}),
			}),
		}),

		Name = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(0.5, 0, 1, -5),
			Size = UDim2.new(1, -8, 0, 18),
			Text = tool.Name,
			TextColor3 = Color3.fromRGB(245, 250, 255),
			TextScaled = true,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.55,
			ZIndex = 44,
		}, {
			Limit = e("UITextSizeConstraint", {
				MaxTextSize = 13,
				MinTextSize = 8,
			}),
		}),

		Cooldown = isCoolingDown and e("Frame", {
			BackgroundColor3 = Color3.fromRGB(3, 8, 13),
			BackgroundTransparency = 0.28,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.fromScale(0, 1 - cooldownRatio),
			Size = UDim2.fromScale(1, cooldownRatio),
			ZIndex = 45,
		}, {
			Corner = corner(8),
			Label = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Size = UDim2.fromScale(1, 1),
				Text = string.format("%.1f", remaining),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0.2,
				ZIndex = 46,
			}, {
				Limit = e("UITextSizeConstraint", {
					MaxTextSize = 24,
					MinTextSize = 10,
				}),
			}),
		}) or nil,
	})
end

local function Hotbar()
	local tools, setTools = React.useState(getTools())
	local selectedTool, setSelectedTool = React.useState(getSelectedTool())
	local now, setNow = React.useState(os.clock())
	local toolsRef = React.useRef(tools)
	local selectedToolRef = React.useRef(selectedTool)

	toolsRef.current = tools
	selectedToolRef.current = selectedTool

	local function refreshTools()
		setTools(getTools())
		setSelectedTool(getSelectedTool())
	end

	React.useEffect(function()
		local connections = {}
		local cancelled = false

		local function connectContainer(container)
			if not container then
				return
			end

			table.insert(connections, container.ChildAdded:Connect(refreshTools))
			table.insert(connections, container.ChildRemoved:Connect(refreshTools))
		end

		local function bindCharacter(character)
			connectContainer(character)
			refreshTools()
		end

		connectContainer(localPlayer:FindFirstChildOfClass("Backpack"))
		if localPlayer.Character then
			bindCharacter(localPlayer.Character)
		end

		table.insert(connections, localPlayer.CharacterAdded:Connect(bindCharacter))
		table.insert(
			connections,
			localPlayer.ChildAdded:Connect(function(child)
				if child:IsA("Backpack") then
					connectContainer(child)
					refreshTools()
				end
			end)
		)

		table.insert(
			connections,
			UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if gameProcessed then
					return
				end

				for index, keyCode in KEYCODES do
					if input.KeyCode == keyCode then
						local tool = toolsRef.current[index]
						if tool then
							if selectedToolRef.current == tool then
								unequipTools()
							else
								equipTool(tool)
							end
							refreshTools()
						end
						break
					end
				end
			end)
		)

		local renderConnection = RunService.RenderStepped:Connect(function()
			if not cancelled then
				setNow(os.clock())
			end
		end)
		table.insert(connections, renderConnection)

		return function()
			cancelled = true
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, {})

	local children = {
		List = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Padding = e("UIPadding", {
			PaddingBottom = UDim.new(0, 7),
			PaddingLeft = UDim.new(0, 9),
			PaddingRight = UDim.new(0, 9),
			PaddingTop = UDim.new(0, 7),
		}),
		Corner = corner(12),
		Stroke = stroke(Color3.fromRGB(86, 181, 255), 2, 0.35),
	}

	for index, tool in tools do
		if index > MAX_SLOTS then
			break
		end

		children[`Slot{index}`] = e(Slot, {
			Index = index,
			Now = now,
			OnActivated = function()
				if selectedTool == tool then
					unequipTools()
				else
					equipTool(tool)
				end
				refreshTools()
			end,
			Selected = selectedTool == tool,
			Tool = tool,
		})
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.fromRGB(22, 25, 40),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(math.max(92, (#tools * 80) + 18), 86),
		ZIndex = 39,
	}, children)
end

return Hotbar
