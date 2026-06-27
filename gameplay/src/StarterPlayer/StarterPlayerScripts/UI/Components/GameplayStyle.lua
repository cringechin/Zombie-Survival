local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local e = React.createElement

local GameplayStyle = {}

GameplayStyle.RED = Color3.fromRGB(240, 49, 68)
GameplayStyle.RED_DARK = Color3.fromRGB(102, 18, 34)
GameplayStyle.INK = Color3.fromRGB(7, 8, 15)
GameplayStyle.PANEL = Color3.fromRGB(14, 17, 25)
GameplayStyle.PANEL_SOFT = Color3.fromRGB(20, 24, 35)
GameplayStyle.WHITE = Color3.fromRGB(248, 248, 240)
GameplayStyle.BLACK = Color3.fromRGB(0, 0, 0)
GameplayStyle.GOLD = Color3.fromRGB(255, 205, 65)
GameplayStyle.GREEN = Color3.fromRGB(57, 230, 91)
GameplayStyle.LIGHTNING = Color3.fromRGB(122, 232, 255)
GameplayStyle.METEOR = Color3.fromRGB(255, 110, 61)

function GameplayStyle.corner(radius)
	return e("UICorner", {
		CornerRadius = UDim.new(0, radius or 6),
	})
end

function GameplayStyle.stroke(_color, thickness, transparency)
	return e("UIStroke", {
		Color = GameplayStyle.BLACK,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
	})
end

function GameplayStyle.text(props)
	local children = props.Children or {}

	if props.TextScaled then
		children.SizeLimit = e("UITextSizeConstraint", {
			MaxTextSize = props.MaxTextSize or 28,
			MinTextSize = props.MinTextSize or 8,
		})
	end

	return e("TextLabel", {
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = props.BackgroundTransparency or 1,
		Font = props.Font or Enum.Font.GothamBlack,
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Size = props.Size,
		Text = props.Text,
		TextColor3 = props.TextColor3 or GameplayStyle.WHITE,
		TextScaled = props.TextScaled,
		TextSize = props.TextSize,
		TextStrokeColor3 = GameplayStyle.BLACK,
		TextStrokeTransparency = props.TextStrokeTransparency or 0.08,
		TextTransparency = props.TextTransparency,
		TextWrapped = props.TextWrapped,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
		ZIndex = props.ZIndex,
	}, children)
end

return GameplayStyle
