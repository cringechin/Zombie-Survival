local TweenService = game:GetService("TweenService")

local GuiUtil = {}

local BUTTON_CLASSES = {
	ImageButton = true,
	TextButton = true,
}

local TEXT_CLASSES = {
	TextBox = true,
	TextButton = true,
	TextLabel = true,
}

function GuiUtil.normalize(text)
	return string.lower((text or ""):gsub("%s+", ""))
end

function GuiUtil.isButton(instance)
	if not instance then
		return false
	end

	return BUTTON_CLASSES[instance.ClassName] == true
end

function GuiUtil.isTextObject(instance)
	if not instance then
		return false
	end

	return TEXT_CLASSES[instance.ClassName] == true
end

function GuiUtil.matches(instance, patterns)
	local text = if GuiUtil.isTextObject(instance) then instance.Text else ""
	local haystack = GuiUtil.normalize(instance.Name .. " " .. text)

	for _, pattern in patterns do
		if string.find(haystack, pattern, 1, true) then
			return true
		end
	end

	return false
end

function GuiUtil.findFirstDescendant(root, predicate)
	if not root then
		return nil
	end

	for _, descendant in root:GetDescendants() do
		if predicate(descendant) then
			return descendant
		end
	end

	return nil
end

function GuiUtil.findAllDescendants(root, predicate)
	local results = {}

	if not root then
		return results
	end

	for _, descendant in root:GetDescendants() do
		if predicate(descendant) then
			table.insert(results, descendant)
		end
	end

	return results
end

function GuiUtil.ensureScale(guiObject)
	local scale = guiObject:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = guiObject
	end

	return scale
end

function GuiUtil.animateButton(button)
	if button:GetAttribute("LobbyMenuAnimated") then
		return
	end

	button:SetAttribute("LobbyMenuAnimated", true)
	button.AutoButtonColor = false
	local scale = GuiUtil.ensureScale(button)
	local baseRotation = button.Rotation
	local pressToken = 0

	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1.08,
		}):Play()
		TweenService:Create(button, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Rotation = baseRotation + 2,
		}):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
		TweenService:Create(button, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Rotation = baseRotation,
		}):Play()
	end)

	button.Activated:Connect(function()
		pressToken += 1
		local token = pressToken

		TweenService:Create(scale, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 0.92,
		}):Play()

		task.delay(0.07, function()
			if token ~= pressToken or not scale.Parent then
				return
			end

			TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1.08,
			}):Play()
		end)
	end)
end

function GuiUtil.tweenPanel(panel, visible)
	if not panel or not panel:IsA("GuiObject") then
		return
	end

	local scale = GuiUtil.ensureScale(panel)
	local token = (panel:GetAttribute("VisibilityTweenToken") or 0) + 1
	panel:SetAttribute("VisibilityTweenToken", token)

	if visible then
		panel.Visible = true
		scale.Scale = 0.94
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	else
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 0.94,
		}):Play()

		task.delay(0.12, function()
			if panel and panel.Parent and panel:GetAttribute("VisibilityTweenToken") == token then
				panel.Visible = false
			end
		end)
	end
end

function GuiUtil.styleText(textObject, maxTextSize, minTextSize)
	textObject.Font = Enum.Font.GothamBlack
	textObject.TextColor3 = Color3.fromRGB(248, 248, 240)
	textObject.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	textObject.TextStrokeTransparency = 0.08
	textObject.TextWrapped = true

	if textObject:IsA("TextLabel") or textObject:IsA("TextButton") or textObject:IsA("TextBox") then
		textObject.TextScaled = true
	end
end

return GuiUtil
