local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local DisasterWeaponConfig = require(ReplicatedStorage.Shared.Weapons.DisasterWeaponConfig)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Network = require(ReplicatedStorage.Shared.Network.Packets)
local GearPlacementController = require(script.Parent.Parent.Parent:WaitForChild("GearPlacementController"))
local Sounds = require(script.Parent.GameplaySounds)
local Style = require(script.Parent.GameplayStyle)

local e = React.createElement
local localPlayer = Players.LocalPlayer
local COIN_IMAGE = "rbxassetid://12934632218"

local stroke = Style.stroke
local corner = Style.corner
local GLASS = Color3.fromRGB(8, 12, 18)
local SOFT_STROKE = Color3.fromRGB(210, 232, 245)
local MUTED_TEXT = Color3.fromRGB(170, 188, 198)

local function textStrokeLabel(props)
	return Style.text({
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = props.BackgroundTransparency or 1,
		Font = props.Font or Enum.Font.GothamBold,
		Position = props.Position,
		Size = props.Size,
		Text = props.Text,
		TextColor3 = props.TextColor3 or Style.WHITE,
		TextScaled = true,
		TextStrokeTransparency = props.TextStrokeTransparency or 1,
		TextTransparency = props.TextTransparency,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
		MaxTextSize = props.MaxTextSize or 18,
		MinTextSize = props.MinTextSize or 12,
		ZIndex = props.ZIndex,
		Children = props.Children,
	})
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
		BackgroundColor3 = GLASS,
		BackgroundTransparency = 0.34,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -48, 0, 6),
		Size = UDim2.fromOffset(42, 20),
		ZIndex = 4,
	}, {
		Corner = corner(6),
		Stroke = stroke(SOFT_STROKE, 1, 0.82),
		Price = textStrokeLabel({
			Size = UDim2.fromScale(1, 1),
			Text = tostring(price),
			TextColor3 = Style.GOLD,
			MaxTextSize = 13,
			ZIndex = 5,
		}),
	})
end

local function levelBar(props)
	local level = math.clamp(props.Level or 0, 0, props.MaxLevel or 1)
	local maxLevel = math.max(props.MaxLevel or 1, 1)
	local ratio = level / maxLevel

	return e("Frame", {
		BackgroundColor3 = Color3.fromRGB(32, 39, 48),
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Position = props.Position,
		Size = props.Size,
		ZIndex = props.ZIndex or 4,
	}, {
		Corner = corner(4),
		Fill = e("Frame", {
			BackgroundColor3 = props.Color or Style.LIGHTNING,
			BackgroundTransparency = if level <= 0 then 1 else 0.05,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(ratio, 1),
			ZIndex = (props.ZIndex or 4) + 1,
		}, {
			Corner = corner(4),
		}),
		Shine = ratio > 0 and e("Frame", {
			BackgroundColor3 = Style.WHITE,
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(1, 1),
			Size = UDim2.new(ratio, -2, 0, 1),
			ZIndex = (props.ZIndex or 4) + 2,
		}) or nil,
	})
end

local function card(props)
	local disabled = props.Disabled == true
	local accent = props.ArtColor or Style.LIGHTNING
	local elementType = if disabled then "Frame" else "TextButton"
	local hasLevel = type(props.Level) == "number" and type(props.MaxLevel) == "number"
	local statPosition = if hasLevel then UDim2.fromOffset(48, 39) else UDim2.fromOffset(48, 28)
	local statSize = if hasLevel then UDim2.fromOffset(100, 14) else UDim2.fromOffset(100, 22)
	local instanceProps = {
		BackgroundColor3 = GLASS,
		BackgroundTransparency = if disabled then 0.78 else 0.48,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(156, 58),
		ZIndex = 2,
	}

	if not disabled then
		instanceProps.AutoButtonColor = false
		instanceProps.Text = ""
		instanceProps[React.Event.Activated] = function()
			Sounds.play("click")
			props.OnActivated()
		end
		instanceProps[React.Event.MouseEnter] = function()
			Sounds.play("hover")
		end
	end

	local iconText = props.Icon or string.sub(props.Label or "?", 1, 1)

	return e(elementType, instanceProps, {
		Corner = corner(7),
		Stroke = stroke(SOFT_STROKE, 1, if disabled then 0.9 else 0.72),
		Cost = coinCost(props.Cost),

		Accent = e("Frame", {
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 9),
			Size = UDim2.fromOffset(3, 40),
			ZIndex = 3,
		}, {
			Corner = corner(3),
		}),

		Icon = e("Frame", {
			BackgroundColor3 = accent,
			BackgroundTransparency = if disabled then 0.55 else 0.12,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(12, 14),
			Size = UDim2.fromOffset(30, 30),
			ZIndex = 3,
		}, {
			Corner = corner(7),
			Stroke = stroke(SOFT_STROKE, 1, 0.78),
			Text = textStrokeLabel({
				Font = Enum.Font.GothamBlack,
				Size = UDim2.fromScale(1, 1),
				Text = iconText,
				TextColor3 = GLASS,
				MaxTextSize = 17,
				ZIndex = 4,
			}),
		}),

		Label = textStrokeLabel({
			Position = UDim2.fromOffset(48, 7),
			Size = UDim2.fromOffset(58, 18),
			Text = props.Label,
			TextColor3 = if disabled then MUTED_TEXT else Style.WHITE,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 13,
			MinTextSize = 8,
			ZIndex = 4,
		}),

		Level = hasLevel and levelBar({
			Color = accent,
			Level = props.Level,
			MaxLevel = props.MaxLevel,
			Position = UDim2.fromOffset(48, 29),
			Size = UDim2.fromOffset(92, 5),
			ZIndex = 4,
		}) or nil,

		Stat = textStrokeLabel({
			Position = statPosition,
			Size = statSize,
			Text = props.Glyph,
			TextColor3 = if disabled then Color3.fromRGB(128, 141, 148) else MUTED_TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			MaxTextSize = if hasLevel then 10 else math.min(props.GlyphTextSize or 12, 12),
			MinTextSize = 8,
			ZIndex = 4,
		}),
	})
end

local function sidePanel(title, side, items)
	local xScale = if side == "left" then 0 else 1
	local anchor = if side == "left" then Vector2.new(0, 0.5) else Vector2.new(1, 0.5)
	local position = if side == "left" then UDim2.new(0, 12, 0.5, -8) else UDim2.new(1, -12, 0.5, -8)

	local listChildren = {
		List = e("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = e("UIPadding", {
			PaddingBottom = UDim.new(0, 0),
			PaddingLeft = UDim.new(0, 0),
			PaddingRight = UDim.new(0, 0),
			PaddingTop = UDim.new(0, 0),
		}),
	}

	for index, item in items do
		listChildren[`Item{index}`] = card(item)
	end

	return e("Frame", {
		AnchorPoint = anchor,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = position,
		Size = UDim2.fromOffset(166, 238),
		ZIndex = 1,
	}, {
		Title = textStrokeLabel({
			AnchorPoint = Vector2.new(xScale, 0),
			Position = if side == "left" then UDim2.fromOffset(1, 0) else UDim2.new(1, -1, 0, 0),
			Size = UDim2.fromOffset(160, 22),
			Text = title,
			TextColor3 = Color3.fromRGB(225, 240, 248),
			TextXAlignment = if side == "left" then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
			MaxTextSize = 16,
			ZIndex = 3,
		}),
		Panel = e("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 30),
			Size = UDim2.fromOffset(166, 204),
			ZIndex = 1,
		}, {
			Children = e(React.Fragment, nil, listChildren),
		}),
	})
end

local function currencyButton(text, layoutOrder)
	return e("Frame", {
		BackgroundColor3 = GLASS,
		BackgroundTransparency = 0.52,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(112, 30),
		ZIndex = 2,
	}, {
		Corner = corner(7),
		Stroke = stroke(SOFT_STROKE, 1, 0.8),
		Label = textStrokeLabel({
			Size = UDim2.fromScale(1, 1),
			Text = text,
			TextColor3 = Style.GOLD,
			MaxTextSize = 16,
			ZIndex = 3,
		}),
	})
end

local function BottomCurrency()
	return e("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 12, 1, -112),
		Size = UDim2.fromOffset(124, 68),
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
		BackgroundColor3 = Style.RED_DARK,
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -260, 0, 42),
		Size = UDim2.fromOffset(150, 52),
		ZIndex = 2,
	}, {
		Corner = corner(9),
		Stroke = stroke(nil, 3),
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
		BackgroundColor3 = Style.INK,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -14, 0, 20),
		Size = UDim2.fromOffset(88, 10),
		ZIndex = 2,
	}, {
		Corner = corner(8),
		Stroke = stroke(nil, 1),
		Fill = e("Frame", {
			BackgroundColor3 = Style.GREEN,
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
			TextColor3 = Style.GOLD,
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
		BackgroundColor3 = GLASS,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(104, 34),
		ZIndex = 2,
	}, {
		Corner = corner(8),
		Stroke = stroke(SOFT_STROKE, 1, 0.78),
		Icon = coinImage(UDim2.fromOffset(24, 24), UDim2.fromOffset(5, 5), 3),
		Amount = textStrokeLabel({
			Position = UDim2.fromOffset(34, 2),
			Size = UDim2.fromOffset(64, 30),
			Text = tostring(props.Coins),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 21,
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
	local tornadoLevel, setTornadoLevel = React.useState(localPlayer:GetAttribute("TornadoLevel") or 0)
	local meteorUnlocked, setMeteorUnlocked = React.useState(localPlayer:GetAttribute("MeteorUnlocked") == true)
	local meteorEquipped, setMeteorEquipped = React.useState(localPlayer:GetAttribute("MeteorEquipped") == true)
	local tornadoUnlocked, setTornadoUnlocked = React.useState(localPlayer:GetAttribute("TornadoUnlocked") == true)
	local tornadoEquipped, setTornadoEquipped = React.useState(localPlayer:GetAttribute("TornadoEquipped") == true)
	local lightningConfig = DisasterWeaponConfig.Lightning
	local meteorConfig = DisasterWeaponConfig.Meteor
	local tornadoConfig = DisasterWeaponConfig.Tornado
	local turretConfig = GameConfig.Defenses.LightningTurret
	local turretCost, setTurretCost = React.useState(localPlayer:GetAttribute("LightningTurretNextCost") or turretConfig.Cost)
	local previousCoinsRef = React.useRef(nil)
	local nextLightningLevel = math.min(lightningLevel + 1, lightningConfig.MaxUpgradeLevel)
	local lightningCostValue = if lightningLevel >= lightningConfig.MaxUpgradeLevel
		then nil
		else lightningConfig.UpgradeCosts[nextLightningLevel]
	local lightningLabel = "Lightning"
	local lightningDamage = lightningConfig.Damage + (lightningLevel * lightningConfig.DamagePerUpgrade)
	local lightningChains = lightningLevel * lightningConfig.ChainTargetsPerUpgrade
	local nextMeteorLevel = math.min(meteorLevel + 1, meteorConfig.MaxUpgradeLevel)
	local meteorDisabled = not meteorUnlocked or not meteorEquipped
	local meteorCostValue = if meteorDisabled or meteorLevel >= meteorConfig.MaxUpgradeLevel
		then nil
		else meteorConfig.UpgradeCosts[nextMeteorLevel]
	local meteorLabel = "Meteor"
	local meteorStageConfig = meteorConfig.AirStrikeLevels[math.max(meteorLevel, 4)]
		or meteorConfig.HandCastLevels[math.max(meteorLevel, 1)]
	local meteorGlyph = if not meteorUnlocked or not meteorEquipped
		then "LOBBY\nSHOP"
		elseif meteorLevel >= 4
		then `DMG {meteorStageConfig.Damage}\nFIRE {meteorConfig.FireDamage}`
		else `DMG {meteorStageConfig.Damage}\nRAD {meteorStageConfig.Radius}`
	local nextTornadoLevel = math.min(tornadoLevel + 1, tornadoConfig.MaxUpgradeLevel)
	local tornadoDisabled = not tornadoUnlocked or not tornadoEquipped
	local tornadoCostValue = if tornadoDisabled or tornadoLevel >= tornadoConfig.MaxUpgradeLevel
		then nil
		else tornadoConfig.UpgradeCosts[nextTornadoLevel]
	local tornadoLabel = "Tornado"
	local tornadoDamage = tornadoConfig.Damage + (math.max(tornadoLevel - 1, 0) * tornadoConfig.DamagePerUpgrade)
	local tornadoGlyph = if not tornadoUnlocked or not tornadoEquipped
		then "LOBBY\nSHOP"
		elseif tornadoLevel >= 4
		then `DMG {tornadoDamage}\nTRACK`
		else `DMG {tornadoDamage}\nPULL`

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
			localPlayer:GetAttributeChangedSignal("TornadoLevel"):Connect(function()
				setTornadoLevel(localPlayer:GetAttribute("TornadoLevel") or 0)
			end)
		)
		table.insert(
			connections,
			localPlayer:GetAttributeChangedSignal("MeteorUnlocked"):Connect(function()
				setMeteorUnlocked(localPlayer:GetAttribute("MeteorUnlocked") == true)
			end)
		)
		table.insert(
			connections,
			localPlayer:GetAttributeChangedSignal("TornadoUnlocked"):Connect(function()
				setTornadoUnlocked(localPlayer:GetAttribute("TornadoUnlocked") == true)
			end)
		)
		table.insert(
			connections,
			localPlayer:GetAttributeChangedSignal("MeteorEquipped"):Connect(function()
				setMeteorEquipped(localPlayer:GetAttribute("MeteorEquipped") == true)
			end)
		)
		table.insert(
			connections,
			localPlayer:GetAttributeChangedSignal("TornadoEquipped"):Connect(function()
				setTornadoEquipped(localPlayer:GetAttribute("TornadoEquipped") == true)
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
				Icon = "L",
				GlyphTextSize = 18,
				ArtColor = Color3.fromRGB(48, 210, 255),
				GlyphColor = Color3.fromRGB(20, 80, 255),
				Level = lightningLevel,
				MaxLevel = lightningConfig.MaxUpgradeLevel,
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
				Icon = "M",
				GlyphTextSize = 18,
				ArtColor = Color3.fromRGB(255, 121, 49),
				GlyphColor = Color3.fromRGB(70, 22, 8),
				Level = meteorLevel,
				MaxLevel = meteorConfig.MaxUpgradeLevel,
				LayoutOrder = 2,
				Disabled = meteorDisabled,
				OnActivated = function()
					if not meteorDisabled and meteorLevel < meteorConfig.MaxUpgradeLevel then
						Network.weaponUpgradeRequest.send({
							weapon = "Meteor",
						})
					end
				end,
			},
			{
				Label = tornadoLabel,
				Cost = tornadoCostValue,
				Glyph = tornadoGlyph,
				Icon = "T",
				GlyphTextSize = 18,
				ArtColor = Color3.fromRGB(184, 229, 232),
				GlyphColor = Color3.fromRGB(24, 86, 92),
				Level = tornadoLevel,
				MaxLevel = tornadoConfig.MaxUpgradeLevel,
				LayoutOrder = 3,
				Disabled = tornadoDisabled,
				OnActivated = function()
					if not tornadoDisabled and tornadoLevel < tornadoConfig.MaxUpgradeLevel then
						Network.weaponUpgradeRequest.send({
							weapon = "Tornado",
						})
					end
				end,
			},
		}),

		Gears = sidePanel("Gears", "right", {
			{
				Label = "Lightning Turret",
				Cost = turretCost,
				Glyph = `DMG {turretConfig.Damage}\n+{turretConfig.CostIncreasePerTower} cost`,
				Icon = "L",
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
				Icon = "B",
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
				Icon = "M",
				GlyphTextSize = 22,
				ArtColor = Color3.fromRGB(188, 52, 45),
				GlyphColor = Color3.fromRGB(42, 10, 10),
				LayoutOrder = 3,
				Disabled = true,
			},
		}),

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
