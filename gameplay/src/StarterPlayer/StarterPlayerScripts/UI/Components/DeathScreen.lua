local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local Network = require(ReplicatedStorage.Shared.Network.Packets)

local e = React.createElement
local localPlayer = Players.LocalPlayer

local function getHumanoid(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getAlivePlayers()
	local alivePlayers = {}

	for _, player in Players:GetPlayers() do
		if player ~= localPlayer and not player:GetAttribute("IsDowned") then
			local humanoid = getHumanoid(player)
			if humanoid and humanoid.Health > 0 then
				table.insert(alivePlayers, player)
			end
		end
	end

	return alivePlayers
end

local function shadowText(props)
	local zIndex = props.ZIndex or 203

	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = props.Size or UDim2.fromOffset(420, 62),
		ZIndex = zIndex,
	}, {
		Shadow = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = props.Font or Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.fromScale(1, 1),
			Text = props.Text,
			TextColor3 = Color3.new(0, 0, 0),
			TextSize = props.TextSize or 42,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = zIndex,
		}),
		Text = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = props.Font or Enum.Font.GothamBlack,
			Size = UDim2.fromScale(1, 1),
			Text = props.Text,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = props.TextSize or 42,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = zIndex + 1,
		}),
	})
end

local function button(props)
	local disabled = props.Disabled == true

	return e("TextButton", {
		Active = not disabled,
		AutoButtonColor = not disabled,
		BackgroundColor3 = if disabled then Color3.fromRGB(60, 60, 60) else Color3.fromRGB(18, 18, 18),
		BackgroundTransparency = if disabled then 0.35 else 0.08,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(210, 46),
		Text = if disabled then nil else "",
		ZIndex = 204,
		[React.Event.Activated] = if disabled then nil else props.OnActivated,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		Stroke = e("UIStroke", {
			Color = Color3.new(0, 0, 0),
			Thickness = 3,
		}),
		Label = shadowText({
			Text = props.Text,
			TextSize = 20,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 205,
		}),
	})
end

local function DeathScreen()
	local visible, setVisible = React.useState(localPlayer:GetAttribute("IsDowned") == true)
	local spectating, setSpectating = React.useState(false)
	local spectateName, setSpectateName = React.useState("")
	local aliveCount, setAliveCount = React.useState(#getAlivePlayers())
	local creditsEarned, setCreditsEarned = React.useState(localPlayer:GetAttribute("RunCreditsEarned") or 0)

	React.useEffect(function()
		local effect = Lighting:FindFirstChild("DeathScreenGrayscale")
		if not effect then
			effect = Instance.new("ColorCorrectionEffect")
			effect.Name = "DeathScreenGrayscale"
			effect.Enabled = false
			effect.Parent = Lighting
		end

		effect.Saturation = -1
		effect.Contrast = 0.08
		effect.Brightness = -0.04
		effect.Enabled = visible

		return function()
			if effect.Parent then
				effect.Enabled = false
			end
		end
	end, { visible })

	React.useEffect(function()
		local function restoreLocalCamera()
			local camera = Workspace.CurrentCamera
			local humanoid = getHumanoid(localPlayer)
			if camera and humanoid then
				camera.CameraType = Enum.CameraType.Custom
				camera.CameraSubject = humanoid
			end
		end

		local connections = {}

		table.insert(
			connections,
			localPlayer:GetAttributeChangedSignal("IsDowned"):Connect(function()
				local isDowned = localPlayer:GetAttribute("IsDowned") == true
				setVisible(isDowned)
				if not isDowned then
					setSpectating(false)
					setSpectateName("")
					restoreLocalCamera()
				end
			end)
		)

		table.insert(
			connections,
			localPlayer:GetAttributeChangedSignal("RunCreditsEarned"):Connect(function()
				setCreditsEarned(localPlayer:GetAttribute("RunCreditsEarned") or 0)
			end)
		)

		table.insert(
			connections,
			localPlayer.CharacterAdded:Connect(function()
				setVisible(false)
				setSpectating(false)
				setSpectateName("")
				task.defer(restoreLocalCamera)
			end)
		)

		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
			restoreLocalCamera()
		end
	end, {})

	React.useEffect(function()
		local accumulator = 0
		local connection = RunService.RenderStepped:Connect(function(deltaTime)
			accumulator += deltaTime
			if accumulator < 0.35 then
				return
			end

			accumulator = 0
			local alivePlayers = getAlivePlayers()
			setAliveCount(#alivePlayers)

			if spectating then
				local targetPlayer = nil
				for _, player in alivePlayers do
					if player.Name == spectateName then
						targetPlayer = player
						break
					end
				end

				targetPlayer = targetPlayer or alivePlayers[1]
				local humanoid = targetPlayer and getHumanoid(targetPlayer)
				local camera = Workspace.CurrentCamera
				if humanoid and camera then
					setSpectateName(targetPlayer.Name)
					camera.CameraType = Enum.CameraType.Custom
					camera.CameraSubject = humanoid
				else
					setSpectating(false)
					setSpectateName("")
				end
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, { spectating, spectateName })

	if not visible then
		return nil
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 200,
	}, {
		Center = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.48),
			Size = UDim2.fromOffset(520, 320),
			ZIndex = 201,
		}, {
			List = e("UIListLayout", {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Title = shadowText({
				LayoutOrder = 1,
				Text = "YOU DIED",
				TextSize = 54,
			}),
			Sub = shadowText({
				LayoutOrder = 2,
				Text = if spectating and spectateName ~= ""
					then `Spectating {spectateName}`
					elseif aliveCount <= 0 then "Everyone has died"
					else "Respawns on next wave",
				TextSize = 22,
				Size = UDim2.fromOffset(420, 34),
			}),
			Credits = shadowText({
				LayoutOrder = 3,
				Text = `CR Earned: {creditsEarned}`,
				TextSize = 26,
				Size = UDim2.fromOffset(420, 38),
			}),
			Buttons = e("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 4,
				Size = UDim2.fromOffset(452, 110),
				ZIndex = 204,
			}, {
				Grid = e("UIGridLayout", {
					CellPadding = UDim2.fromOffset(12, 12),
					CellSize = UDim2.fromOffset(220, 46),
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Return = button({
					LayoutOrder = 1,
					Text = "Return To Lobby",
					OnActivated = function()
						Network.returnToLobbyRequest.send()
					end,
				}),
				Revive = button({
					LayoutOrder = 2,
					Text = "Revive - 25 R$",
					Disabled = true,
				}),
				Spectate = button({
					LayoutOrder = 3,
					Text = if spectating then "Stop Spectating" else "Spectate",
					Disabled = aliveCount <= 0,
					OnActivated = function()
						local alivePlayers = getAlivePlayers()
						if spectating then
							setSpectating(false)
							setSpectateName("")
							return
						end

						if #alivePlayers > 0 then
							setSpectating(true)
							setSpectateName(alivePlayers[1].Name)
						end
					end,
				}),
			}),
		}),
	})
end

return DeathScreen
