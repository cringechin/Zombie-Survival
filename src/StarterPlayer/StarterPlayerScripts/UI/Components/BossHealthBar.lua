local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Network = require(ReplicatedStorage.Shared.Network.Packets)

local e = React.createElement

local function corner(radius)
	return e("UICorner", {
		CornerRadius = UDim.new(0, radius or 6),
	})
end

local function BossHealthBar()
	local boss, setBoss = React.useState({
		active = false,
		name = "",
		health = 0,
		maxHealth = 1,
	})
	local displayedRatio, setDisplayedRatio = React.useState(0)
	local damageRatio, setDamageRatio = React.useState(0)
	local pulse, setPulse = React.useState(0)
	local shimmer, setShimmer = React.useState(0)

	React.useEffect(function()
		Network.bossStatus.listen(function(data)
			setBoss({
				active = data.active == 1,
				name = data.name,
				health = data.health,
				maxHealth = math.max(data.maxHealth, 1),
			})
		end)
	end, {})

	local ratio = if boss.active then math.clamp(boss.health / boss.maxHealth, 0, 1) else 0

	React.useEffect(function()
		if not boss.active then
			setDisplayedRatio(0)
			setDamageRatio(0)
			return
		end

		local cancelled = false
		local startDisplay = displayedRatio
		local startDamage = math.max(damageRatio, ratio)
		setPulse(0)

		task.spawn(function()
			for frameIndex = 1, 18 do
				if cancelled then
					return
				end

				local alpha = frameIndex / 18
				local eased = 1 - ((1 - alpha) * (1 - alpha))
				setDisplayedRatio(startDisplay + ((ratio - startDisplay) * eased))
				setPulse(alpha)
				task.wait(0.018)
			end

			task.wait(0.16)
			for frameIndex = 1, 16 do
				if cancelled then
					return
				end

				local alpha = frameIndex / 16
				local eased = 1 - ((1 - alpha) * (1 - alpha))
				setDamageRatio(startDamage + ((ratio - startDamage) * eased))
				task.wait(0.022)
			end
		end)

		return function()
			cancelled = true
		end
	end, { boss.health, boss.maxHealth, boss.active })

	React.useEffect(function()
		local connection = RunService.RenderStepped:Connect(function(deltaTime)
			setShimmer(function(value)
				return (value + (deltaTime * 0.42)) % 1
			end)
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	if not boss.active then
		return nil
	end

	local pulseScale = 1 + (math.sin(pulse * math.pi) * 0.035)
	local glowTransparency = 0.42 - (math.sin(pulse * math.pi) * 0.18)

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 0, 78),
		Size = UDim2.new(0.62, 0, 0, 72),
		ZIndex = 70,
	}, {
		Scale = e("UIScale", {
			Scale = pulseScale,
		}),

		Name = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, 0, 0, 30),
			Text = `STORM // {string.upper(boss.name)} // STORM`,
			TextColor3 = Color3.fromRGB(215, 250, 255),
			TextScaled = true,
			TextStrokeColor3 = Color3.fromRGB(3, 8, 24),
			TextStrokeTransparency = 0.02,
			ZIndex = 72,
		}, {
			Limit = e("UITextSizeConstraint", {
				MaxTextSize = 28,
				MinTextSize = 12,
			}),
		}),

		Glow = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(34, 176, 255),
			BackgroundTransparency = glowTransparency,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(-8, 29),
			Size = UDim2.new(1, 16, 0, 28),
			ZIndex = 69,
		}, {
			Corner = corner(10),
		}),

		Back = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(5, 9, 22),
			BackgroundTransparency = 0.02,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(0, 34),
			Size = UDim2.new(1, 0, 0, 22),
			ZIndex = 71,
		}, {
			Corner = corner(8),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(184, 246, 255),
				Thickness = 3,
				Transparency = 0.04,
			}),
			DamageFill = e("Frame", {
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(math.clamp(damageRatio, 0, 1), 1),
				ZIndex = 72,
			}, {
				Corner = corner(8),
			}),
			Fill = e("Frame", {
				BackgroundColor3 = Color3.fromRGB(52, 194, 255),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(math.clamp(displayedRatio, 0, 1), 1),
				ZIndex = 73,
			}, {
				Corner = corner(8),
				Glow = e("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 58, 255)),
						ColorSequenceKeypoint.new(0.45, Color3.fromRGB(84, 228, 255)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(242, 255, 255)),
					}),
				}),
			}),
			Shimmer = e("Frame", {
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 0.68,
				BorderSizePixel = 0,
				Position = UDim2.new(shimmer, -34, 0, 0),
				Size = UDim2.fromOffset(30, 22),
				ZIndex = 74,
			}, {
				Gradient = e("UIGradient", {
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.5, 0),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
			}),
			Marker1 = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.new(0.25, -15, 0, -3),
				Size = UDim2.fromOffset(30, 28),
				Text = "ZAP",
				TextColor3 = Color3.fromRGB(245, 255, 255),
				TextScaled = true,
				TextStrokeTransparency = 0.2,
				ZIndex = 75,
			}),
			Marker2 = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.new(0.5, -15, 0, -3),
				Size = UDim2.fromOffset(30, 28),
				Text = "ZAP",
				TextColor3 = Color3.fromRGB(245, 255, 255),
				TextScaled = true,
				TextStrokeTransparency = 0.2,
				ZIndex = 75,
			}),
			Marker3 = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.new(0.75, -15, 0, -3),
				Size = UDim2.fromOffset(30, 28),
				Text = "ZAP",
				TextColor3 = Color3.fromRGB(245, 255, 255),
				TextScaled = true,
				TextStrokeTransparency = 0.2,
				ZIndex = 75,
			}),
		}),

		Value = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(0, 58),
			Size = UDim2.new(1, 0, 0, 14),
			Text = `{boss.health} / {boss.maxHealth}`,
			TextColor3 = Color3.fromRGB(203, 242, 255),
			TextScaled = true,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.35,
			ZIndex = 73,
		}, {
			Limit = e("UITextSizeConstraint", {
				MaxTextSize = 13,
				MinTextSize = 8,
			}),
		}),
	})
end

return BossHealthBar
