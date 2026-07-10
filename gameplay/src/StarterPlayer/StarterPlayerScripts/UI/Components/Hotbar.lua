local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local DisasterWeaponConfig = require(ReplicatedStorage.Shared.Weapons.DisasterWeaponConfig)
local Sounds = require(script.Parent.GameplaySounds)
local Style = require(script.Parent.GameplayStyle)

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

local corner = Style.corner
local stroke = Style.stroke
local GLASS = Color3.fromRGB(8, 12, 18)
local SOFT_STROKE = Color3.fromRGB(210, 232, 245)
local MUTED_TEXT = Color3.fromRGB(176, 196, 206)

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
		local leftSlot = left:GetAttribute("LoadoutSlot")
		local rightSlot = right:GetAttribute("LoadoutSlot")
		if typeof(leftSlot) == "number" and typeof(rightSlot) == "number" and leftSlot ~= rightSlot then
			return leftSlot < rightSlot
		end

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

local function isLocalPlayerAlive()
	if localPlayer:GetAttribute("IsDowned") == true then
		return false
	end

	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")

	return humanoid ~= nil and root ~= nil and humanoid.Health > 0
end

local function equipTool(tool)
	if not isLocalPlayerAlive() then
		return
	end

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

	if tool.Name == "Meteor" then
		return Color3.fromRGB(255, 118, 48), "M"
	end

	if tool.Name == "Tornado" then
		return Color3.fromRGB(184, 229, 232), "T"
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
		BackgroundColor3 = if selected then accentColor else GLASS,
		BackgroundTransparency = if selected then 0.28 else 0.52,
		BorderSizePixel = 0,
		LayoutOrder = props.Index,
		Size = UDim2.fromOffset(60, 60),
		Text = "",
		ZIndex = 40,
		[React.Event.Activated] = props.OnActivated,
		[React.Event.MouseEnter] = function()
			Sounds.play("hover")
		end,
	}, {
		Corner = corner(8),
		Stroke = stroke(if selected then accentColor else SOFT_STROKE, 1, if selected then 0.08 else 0.76),

		Key = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.fromOffset(16, 16),
			ZIndex = 43,
		}, {
			Text = Style.text({
				Font = Enum.Font.GothamBold,
				Size = UDim2.fromScale(1, 1),
				Text = tostring(props.Index),
				TextColor3 = if selected then Style.WHITE else MUTED_TEXT,
				TextScaled = true,
				TextStrokeTransparency = 1,
				MaxTextSize = 12,
				MinTextSize = 8,
				ZIndex = 44,
			}),
		}),

		Icon = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = accentColor,
			BackgroundTransparency = if selected then 0.05 else 0.16,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 0, 18),
			Size = UDim2.fromOffset(28, 24),
			ZIndex = 42,
		}, {
			Corner = corner(6),
			Glyph = Style.text({
				Font = Enum.Font.GothamBlack,
				Size = UDim2.fromScale(1, 1),
				Text = glyph,
				TextColor3 = GLASS,
				TextScaled = true,
				TextStrokeTransparency = 1,
				MaxTextSize = 18,
				MinTextSize = 10,
				ZIndex = 43,
			}),
		}),

		Name = Style.text({
			AnchorPoint = Vector2.new(0.5, 1),
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.new(1, -8, 0, 14),
			Text = tool.Name,
			TextColor3 = if selected then Style.WHITE else MUTED_TEXT,
			TextScaled = true,
			TextStrokeTransparency = 1,
			MaxTextSize = 11,
			MinTextSize = 8,
			ZIndex = 44,
		}),

		Cooldown = isCoolingDown and e("Frame", {
			BackgroundColor3 = GLASS,
			BackgroundTransparency = 0.18,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.fromScale(0, 1 - cooldownRatio),
			Size = UDim2.fromScale(1, cooldownRatio),
			ZIndex = 45,
		}, {
			Corner = corner(8),
			Label = Style.text({
				Font = Enum.Font.GothamBlack,
				Size = UDim2.fromScale(1, 1),
				Text = string.format("%.1f", remaining),
				TextColor3 = Style.WHITE,
				TextScaled = true,
				TextStrokeTransparency = 1,
				MaxTextSize = 20,
				MinTextSize = 10,
				ZIndex = 46,
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
						if not isLocalPlayerAlive() then
							unequipTools()
							refreshTools()
							break
						end

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
		table.insert(
			connections,
			localPlayer:GetAttributeChangedSignal("IsDowned"):Connect(function()
				if localPlayer:GetAttribute("IsDowned") == true then
					unequipTools()
					refreshTools()
				end
			end)
		)

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
			PaddingBottom = UDim.new(0, 0),
			PaddingLeft = UDim.new(0, 0),
			PaddingRight = UDim.new(0, 0),
			PaddingTop = UDim.new(0, 0),
		}),
	}

	for index, tool in tools do
		if index > MAX_SLOTS then
			break
		end

		children[`Slot{index}`] = e(Slot, {
			Index = index,
			Now = now,
			OnActivated = function()
				Sounds.play("click")
				if not isLocalPlayerAlive() then
					unequipTools()
					refreshTools()
					return
				end

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
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(math.max(60, (#tools * 68) - 8), 60),
		ZIndex = 39,
	}, children)
end

return Hotbar
