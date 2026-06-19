local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local DisasterWeaponConfig = require(ReplicatedStorage.Shared.Weapons.DisasterWeaponConfig)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Network = require(ReplicatedStorage.Shared.Network.Packets)
local GearPlacementController = require(script.Parent.Parent.Parent:WaitForChild("GearPlacementController"))

local e = React.createElement
local localPlayer = Players.LocalPlayer
local COIN_IMAGE = "rbxassetid://12934632218"

local function stroke(color, thickness)
	return e("UIStroke", {
		Color = color or Color3.fromRGB(0, 0, 0),
		Thickness = thickness or 2,
	})
end

local function corner(radius)
	return e("UICorner", {
		CornerRadius = UDim.new(0, radius or 8),
	})
end

local function textStrokeLabel(props)
	local children = props.Children or {}
	children.SizeLimit = e("UITextSizeConstraint", {
		MaxTextSize = props.MaxTextSize or 28,
		MinTextSize = props.MinTextSize or 12,
	})

	return e("TextLabel", {
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = props.BackgroundTransparency or 1,
		Font = props.Font or Enum.Font.GothamBlack,
		Position = props.Position,
		Size = props.Size,
		Text = props.Text,
		TextColor3 = props.TextColor3 or Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		TextStrokeColor3 = props.TextStrokeColor3 or Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = props.TextStrokeTransparency or 0.08,
		TextTransparency = props.TextTransparency,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
		ZIndex = props.ZIndex,
	}, children)
end

local function coinImage(size, position, zIndex)
	return e("ImageLabel", {
		BackgroundTransparency = 1,
		Image = COIN_IMAGE,
		Position = position,
		ScaleType = Enum.ScaleType.Fit,
		Size = size,
		ZIndex = zIndex,
	})
end

local function coinCost(price)
	if price == nil then
		return nil
	end

	return e("Frame", {
		BackgroundColor3 = Color3.fromRGB(245, 196, 56),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(54, 22),
		ZIndex = 4,
	}, {
		Corner = corner(3),
		Stroke = stroke(Color3.fromRGB(92, 54, 8), 1),
		Icon = coinImage(UDim2.fromOffset(18, 18), UDim2.fromOffset(3, 2), 5),
		Price = textStrokeLabel({
			Position = UDim2.fromOffset(21, 1),
			Size = UDim2.fromOffset(30, 20),
			Text = tostring(price),
			MaxTextSize = 18,
			ZIndex = 5,
		}),
	})
end

local function card(props)
	local background = props.BackgroundColor3 or Color3.fromRGB(34, 39, 61)
	local instanceProps = {
		BackgroundColor3 = background,
		BackgroundTransparency = props.BackgroundTransparency or 0.08,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(112, 112),
		ZIndex = 2,
	}

	if not props.Disabled then
		instanceProps.Text = ""
		instanceProps[React.Event.Activated] = props.OnActivated
	end

	return e(if props.Disabled then "Frame" else "TextButton", instanceProps, {
		Corner = corner(9),
		Stroke = stroke(Color3.fromRGB(105, 104, 158), 2),
		Cost = coinCost(props.Cost),

		Art = e("Frame", {
			BackgroundColor3 = props.ArtColor or Color3.fromRGB(70, 220, 80),
			BackgroundTransparency = 0.05,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(14, 25),
			Size = UDim2.fromOffset(84, 50),
			ZIndex = 3,
		}, {
			Corner = corner(8),
			Stroke = stroke(Color3.fromRGB(230, 235, 255), 1),
			Glyph = textStrokeLabel({
				Size = UDim2.fromScale(1, 1),
				Text = props.Glyph,
				TextColor3 = props.GlyphColor or Color3.fromRGB(20, 20, 20),
				MaxTextSize = props.GlyphTextSize or 28,
				ZIndex = 4,
			}),
		}),

		Label = textStrokeLabel({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -5),
			Size = UDim2.new(1, -8, 0, 28),
			Text = props.Label,
			MaxTextSize = 16,
			ZIndex = 4,
		}),
	})
end

local function sidePanel(title, side, items)
	local xScale = if side == "left" then 0 else 1
	local anchor = if side == "left" then Vector2.new(0, 0.5) else Vector2.new(1, 0.5)
	local position = if side == "left" then UDim2.new(0, 0, 0.5, -8) else UDim2.new(1, 0, 0.5, -8)

	local listChildren = {
		List = e("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = e("UIPadding", {
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 5),
			PaddingRight = UDim.new(0, 5),
			PaddingTop = UDim.new(0, 8),
		}),
		Stroke = stroke(Color3.fromRGB(0, 0, 0), 3),
	}

	for index, item in items do
		listChildren[`Item{index}`] = card(item)
	end

	return e("Frame", {
		AnchorPoint = anchor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = position,
		Size = UDim2.fromOffset(136, 402),
		ZIndex = 1,
	}, {
		Title = textStrokeLabel({
			AnchorPoint = Vector2.new(xScale, 0),
			Position = if side == "left" then UDim2.fromOffset(4, 0) else UDim2.new(1, -4, 0, 0),
			Size = UDim2.fromOffset(130, 34),
			Text = title,
			TextXAlignment = if side == "left" then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
			MaxTextSize = 28,
			ZIndex = 3,
		}),
		Panel = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(17, 20, 33),
			BackgroundTransparency = 0.18,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 42),
			Size = UDim2.fromOffset(122, 352),
			ZIndex = 1,
		}, {
			Corner = corner(10),
			Children = e(React.Fragment, nil, listChildren),
		}),
	})
end

local function currencyButton(text, layoutOrder)
	return e("Frame", {
		BackgroundColor3 = Color3.fromRGB(26, 210, 223),
		BackgroundTransparency = 0.22,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(130, 34),
		ZIndex = 2,
	}, {
		Corner = corner(8),
		Stroke = stroke(Color3.fromRGB(178, 255, 255), 1),
		Icon = coinImage(UDim2.fromOffset(28, 28), UDim2.fromOffset(3, 3), 3),
		Label = textStrokeLabel({
			Position = UDim2.fromOffset(32, 0),
			Size = UDim2.new(1, -34, 1, 0),
			Text = text,
			TextColor3 = Color3.fromRGB(72, 255, 245),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 22,
			ZIndex = 3,
		}),
	})
end

local function BottomCurrency()
	return e("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 4, 1, -176),
		Size = UDim2.fromOffset(150, 76),
		ZIndex = 2,
	}, {
		List = e("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
		}),
		Big = currencyButton("+10,000", 1),
		Small = currencyButton("+2,500", 2),
	})
end

local function SkipButton()
	return e("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(30, 44, 76),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -260, 0, 42),
		Size = UDim2.fromOffset(150, 52),
		ZIndex = 2,
	}, {
		Corner = corner(9),
		Stroke = stroke(Color3.fromRGB(109, 179, 255), 2),
		Label = textStrokeLabel({
			Size = UDim2.fromScale(1, 1),
			Text = "Skip to next\nwave: 0/1",
			MaxTextSize = 20,
			ZIndex = 3,
		}),
	})
end

local function HealthBar()
	return e("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(18, 20, 28),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -14, 0, 20),
		Size = UDim2.fromOffset(88, 10),
		ZIndex = 2,
	}, {
		Corner = corner(8),
		Stroke = stroke(Color3.fromRGB(8, 10, 14), 1),
		Fill = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(20, 235, 92),
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(0.88, 1),
			ZIndex = 3,
		}, {
			Corner = corner(8),
		}),
	})
end

local function CoinGain(props)
	local progress, setProgress = React.useState(1)

	React.useEffect(function()
		if props.Amount <= 0 then
			return
		end

		local cancelled = false
		setProgress(0)

		task.spawn(function()
			for frameIndex = 1, 14 do
				if cancelled then
					return
				end

				setProgress(frameIndex / 14)
				task.wait(0.04)
			end
		end)

		return function()
			cancelled = true
		end
	end, { props.Token })

	local easedProgress = 1 - ((1 - progress) * (1 - progress))

	return e("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 6, 1, -48 - (36 * easedProgress)),
		Size = UDim2.fromOffset(112, 28),
		ZIndex = 10,
	}, {
		Text = textStrokeLabel({
			Size = UDim2.fromScale(1, 1),
			Text = `+{props.Amount}`,
			TextColor3 = Color3.fromRGB(255, 221, 82),
			TextTransparency = easedProgress,
			TextStrokeTransparency = 0.1 + (0.9 * easedProgress),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 24,
			ZIndex = 10,
		}),
	})
end

local function CoinBadge(props)
	return e("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromRGB(29, 41, 70),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 4, 1, -4),
		Size = UDim2.fromOffset(128, 42),
		ZIndex = 2,
	}, {
		Corner = corner(9),
		Stroke = stroke(Color3.fromRGB(97, 169, 255), 2),
		Icon = coinImage(UDim2.fromOffset(34, 34), UDim2.fromOffset(4, 4), 3),
		Amount = textStrokeLabel({
			Position = UDim2.fromOffset(44, 2),
			Size = UDim2.fromOffset(78, 38),
			Text = tostring(props.Coins),
			MaxTextSize = 28,
			ZIndex = 3,
		}),
		Gain = props.Gain > 0 and e(CoinGain, {
			Amount = props.Gain,
			Token = props.GainToken,
		}) or nil,
	})
end

local function SideBars()
	local coins, setCoins = React.useState(0)
	local coinGain, setCoinGain = React.useState(0)
	local gainToken, setGainToken = React.useState(0)
	local lightningLevel, setLightningLevel = React.useState(localPlayer:GetAttribute("LightningLevel") or 0)
	local meteorLevel, setMeteorLevel = React.useState(localPlayer:GetAttribute("MeteorLevel") or 0)
	local lightningConfig = DisasterWeaponConfig.Lightning
	local meteorConfig = DisasterWeaponConfig.Meteor
	local turretConfig = GameConfig.Defenses.LightningTurret
	local turretCost, setTurretCost = React.useState(localPlayer:GetAttribute("LightningTurretNextCost") or turretConfig.Cost)
	local previousCoinsRef = React.useRef(nil)
	local nextLightningLevel = math.min(lightningLevel + 1, lightningConfig.MaxUpgradeLevel)
	local lightningCostValue = if lightningLevel >= lightningConfig.MaxUpgradeLevel
		then nil
		else lightningConfig.UpgradeCosts[nextLightningLevel]
	local lightningLabel = if lightningLevel >= lightningConfig.MaxUpgradeLevel
		then "Lightning: MAX"
		else `Lightning Lv {lightningLevel}/5`
	local lightningDamage = lightningConfig.Damage + (lightningLevel * lightningConfig.DamagePerUpgrade)
	local lightningChains = lightningLevel * lightningConfig.ChainTargetsPerUpgrade
	local nextMeteorLevel = math.min(meteorLevel + 1, meteorConfig.MaxUpgradeLevel)
	local meteorCostValue = if meteorLevel >= meteorConfig.MaxUpgradeLevel
		then nil
		else meteorConfig.UpgradeCosts[nextMeteorLevel]
	local meteorLabel = if meteorLevel >= meteorConfig.MaxUpgradeLevel
		then "Meteor: MAX"
		elseif meteorLevel <= 0 then "Buy Meteor"
		else `Meteor Lv {meteorLevel}/5`
	local meteorStageConfig = meteorConfig.AirStrikeLevels[math.max(meteorLevel, 4)]
		or meteorConfig.HandCastLevels[math.max(meteorLevel, 1)]
	local meteorGlyph = if meteorLevel >= 4
		then `DMG {meteorStageConfig.Damage}\nFIRE {meteorConfig.FireDamage}`
		else `DMG {meteorStageConfig.Damage}\nRAD {meteorStageConfig.Radius}`

	React.useEffect(function()
		local connections = {}

		local function updateCoins(value)
			local previousCoins = previousCoinsRef.current
			previousCoinsRef.current = value
			setCoins(value)

			if previousCoins ~= nil and value > previousCoins then
				setCoinGain(value - previousCoins)
				setGainToken(function(token)
					return token + 1
				end)
			end
		end

		local function bindLeaderstats()
			local leaderstats = localPlayer:FindFirstChild("leaderstats")
			local coinValue = leaderstats and leaderstats:FindFirstChild("Coins")
			if coinValue then
				updateCoins(coinValue.Value)
				table.insert(connections, coinValue.Changed:Connect(updateCoins))
			end
		end

		bindLeaderstats()
		table.insert(
			connections,
			localPlayer.ChildAdded:Connect(function(child)
				if child.Name == "leaderstats" then
					bindLeaderstats()
				end
			end)
		)

		table.insert(
			connections,
			localPlayer:GetAttributeChangedSignal("LightningLevel"):Connect(function()
				setLightningLevel(localPlayer:GetAttribute("LightningLevel") or 0)
			end)
		)
		table.insert(
			connections,
			localPlayer:GetAttributeChangedSignal("MeteorLevel"):Connect(function()
				setMeteorLevel(localPlayer:GetAttribute("MeteorLevel") or 0)
			end)
		)
		table.insert(
			connections,
			localPlayer:GetAttributeChangedSignal("LightningTurretNextCost"):Connect(function()
				setTurretCost(localPlayer:GetAttribute("LightningTurretNextCost") or turretConfig.Cost)
			end)
		)

		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, {})

	return e(React.Fragment, nil, {
		Upgrades = sidePanel("Upgrades", "left", {
			{
				Label = lightningLabel,
				Cost = lightningCostValue,
				Glyph = `DMG {lightningDamage}\nChain {lightningChains}`,
				GlyphTextSize = 18,
				ArtColor = Color3.fromRGB(48, 210, 255),
				GlyphColor = Color3.fromRGB(20, 80, 255),
				LayoutOrder = 1,
				OnActivated = function()
					if lightningLevel < lightningConfig.MaxUpgradeLevel then
						Network.weaponUpgradeRequest.send({
							weapon = "Lightning",
						})
					end
				end,
			},
			{
				Label = meteorLabel,
				Cost = meteorCostValue,
				Glyph = meteorGlyph,
				GlyphTextSize = 18,
				ArtColor = Color3.fromRGB(255, 121, 49),
				GlyphColor = Color3.fromRGB(70, 22, 8),
				LayoutOrder = 2,
				OnActivated = function()
					if meteorLevel < meteorConfig.MaxUpgradeLevel then
						Network.weaponUpgradeRequest.send({
							weapon = "Meteor",
						})
					end
				end,
			},
		}),

		Gears = sidePanel("Gears:", "right", {
			{
				Label = "Lightning Turret",
				Cost = turretCost,
				Glyph = `DMG {turretConfig.Damage}\n+{turretConfig.CostIncreasePerTower} cost`,
				GlyphTextSize = 17,
				ArtColor = Color3.fromRGB(70, 190, 255),
				GlyphColor = Color3.fromRGB(20, 42, 99),
				LayoutOrder = 1,
				OnActivated = function()
					GearPlacementController.beginGearPlacement("LightningTurret")
				end,
			},
			{
				Label = "Barricade",
				Cost = 50,
				Glyph = "Wall",
				GlyphTextSize = 22,
				ArtColor = Color3.fromRGB(155, 135, 96),
				GlyphColor = Color3.fromRGB(38, 28, 18),
				LayoutOrder = 2,
				Disabled = true,
			},
			{
				Label = "Landmine",
				Cost = 50,
				Glyph = "Mine",
				GlyphTextSize = 22,
				ArtColor = Color3.fromRGB(188, 52, 45),
				GlyphColor = Color3.fromRGB(42, 10, 10),
				LayoutOrder = 3,
				Disabled = true,
			},
		}),

		Skip = e(SkipButton),
		Health = e(HealthBar),
		Currency = e(BottomCurrency),
		Coins = e(CoinBadge, {
			Coins = coins,
			Gain = coinGain,
			GainToken = gainToken,
		}),
	})
end

return SideBars
