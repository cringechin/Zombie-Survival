local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuiUtil = require(script.Parent.GuiUtil)
local StoreUI = require(script.Parent.StoreUI)
local LoadoutUI = require(script.Parent.LoadOutUI)
local UpdateLog = require(script.Parent.UpdateLog)
local Network = require(ReplicatedStorage.Shared.Network.Packets)

local MenuController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local storeController = nil
local loadoutController = nil
local creditsAmountLabel = nil

local PANEL_NAMES = {
	Store = true,
	LoadOut = true,
	UpdateLog = true,
	Daily = true,
	Party = true,
	Quests = true,
}

local PANEL_NAME_ALIASES = {
	LoadOut = { "LoadOut", "Inventory" },
}

local BUTTON_NAME_ALIASES = {
	LoadOut = { "LoadOut", "Inventory" },
}

local function findLobbyGui()
	local mainUI = playerGui:FindFirstChild("MainUI")
	if mainUI and mainUI:IsA("ScreenGui") then
		return mainUI
	end

	local foundGui = nil
	local connection
	connection = playerGui.ChildAdded:Connect(function(child)
		if child.Name == "MainUI" and child:IsA("ScreenGui") then
			foundGui = child
			if connection then
				connection:Disconnect()
			end
		end
	end)

	local startedAt = os.clock()
	while not foundGui and os.clock() - startedAt < 10 do
		task.wait(0.1)
	end

	if connection then
		connection:Disconnect()
	end

	return foundGui
end

local function getMainFrame(gui)
	local frame = gui:FindFirstChild("Frame")
	if frame and frame:IsA("GuiObject") then
		return frame
	end

	return GuiUtil.findFirstDescendant(gui, function(descendant)
		return descendant:IsA("GuiObject") and descendant.Name == "Frame"
	end)
end

local function getLeftButtons(gui)
	local frame = getMainFrame(gui)
	local leftButtons = frame and frame:FindFirstChild("LeftButtons")

	if leftButtons and leftButtons:IsA("GuiObject") then
		return leftButtons
	end

	return GuiUtil.findFirstDescendant(gui, function(descendant)
		return descendant:IsA("GuiObject") and descendant.Name == "LeftButtons"
	end)
end

local function getNamedButton(leftButtons, name)
	local button = leftButtons and leftButtons:FindFirstChild(name)
	if button and GuiUtil.isButton(button) then
		return button
	end

	return nil
end

local function isPanelObject(instance)
	return instance and instance:IsA("GuiObject") and not GuiUtil.isButton(instance)
end

local function getButtonForPanel(leftButtons, panelName)
	local directButton = getNamedButton(leftButtons, panelName)
	if directButton then
		return directButton
	end

	local aliases = BUTTON_NAME_ALIASES[panelName]
	if not aliases then
		return nil
	end

	for _, alias in aliases do
		local aliasButton = getNamedButton(leftButtons, alias)
		if aliasButton then
			return aliasButton
		end
	end

	return nil
end

local function collectPanels(gui)
	local panels = {}
	local mainFrame = getMainFrame(gui)

	for panelName in PANEL_NAMES do
		local panel = nil
		local aliases = PANEL_NAME_ALIASES[panelName]

		if aliases then
			for _, alias in aliases do
				panel = mainFrame and mainFrame:FindFirstChild(alias)
				if not panel then
					panel = gui:FindFirstChild(alias, true)
				end

				if isPanelObject(panel) then
					break
				end
			end
		else
			panel = mainFrame and mainFrame:FindFirstChild(panelName)
			if not panel then
				panel = gui:FindFirstChild(panelName, true)
			end
		end

		if isPanelObject(panel) then
			panels[panelName] = panel
		end
	end

	return panels
end

local function createFallbackCloseButton(panel)
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "X"
	closeButton.AutoButtonColor = false
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.BackgroundColor3 = Color3.fromRGB(86, 52, 58)
	closeButton.BorderSizePixel = 0
	closeButton.Position = UDim2.fromScale(0.985, 0.02)
	closeButton.Size = UDim2.fromOffset(42, 42)
	closeButton.Text = "X"
	closeButton.TextXAlignment = Enum.TextXAlignment.Center
	closeButton.TextYAlignment = Enum.TextYAlignment.Center
	closeButton.ZIndex = panel.ZIndex + 40
	closeButton.Parent = panel

	GuiUtil.styleText(closeButton, 20, 10)
	closeButton.TextColor3 = Color3.fromRGB(245, 233, 233)
	closeButton.TextStrokeTransparency = 0.35

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = closeButton

	return closeButton
end

local function ensureLoadoutPanel(gui, panels)
	if panels.LoadOut then
		return panels.LoadOut
	end

	local mainFrame = getMainFrame(gui)
	if not mainFrame then
		return nil
	end

	local template = panels.Store or panels.UpdateLog
	local panel = Instance.new("Frame")
	panel.Name = "LoadOut"
	panel.Visible = false
	panel.Parent = mainFrame

	if template then
		panel.AnchorPoint = template.AnchorPoint
		panel.Position = template.Position
		panel.Size = template.Size
		panel.BackgroundColor3 = template.BackgroundColor3
		panel.BackgroundTransparency = template.BackgroundTransparency
		panel.BorderColor3 = template.BorderColor3
		panel.BorderSizePixel = template.BorderSizePixel
		panel.ZIndex = template.ZIndex
	else
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.fromScale(0.6, 0.7)
		panel.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
		panel.BackgroundTransparency = 0.08
		panel.BorderSizePixel = 0
		panel.ZIndex = 20
	end

	local closeTemplate = if template then template:FindFirstChild("X", true) else nil
	if closeTemplate and GuiUtil.isButton(closeTemplate) then
		local closeButton = closeTemplate:Clone()
		closeButton.Visible = true
		closeButton.ZIndex = panel.ZIndex + 40
		closeButton.Parent = panel
	else
		createFallbackCloseButton(panel)
	end

	panels.LoadOut = panel
	return panel
end

local function showOnlyPanel(panels, panelName)
	for name, panel in panels do
		GuiUtil.tweenPanel(panel, name == panelName)
	end
end

local function findTextDescendant(root, names)
	if not root then
		return nil
	end

	for _, name in names do
		local descendant = root:FindFirstChild(name, true)
		if descendant and GuiUtil.isTextObject(descendant) then
			return descendant
		end
	end

	return GuiUtil.findFirstDescendant(root, function(descendant)
		return GuiUtil.isTextObject(descendant) and not GuiUtil.isButton(descendant)
	end)
end

local function setExistingText(textObject, text, maxTextSize, xAlignment, yAlignment)
	if not textObject then
		return false
	end

	textObject.Text = if text == nil then "" else tostring(text)
	textObject.TextXAlignment = xAlignment or Enum.TextXAlignment.Left
	textObject.TextYAlignment = yAlignment or Enum.TextYAlignment.Top
	GuiUtil.styleText(textObject, maxTextSize, 10)
	return true
end

local function addCorner(parent, radius)
	local corner = parent:FindFirstChildOfClass("UICorner")
	if not corner then
		corner = Instance.new("UICorner")
		corner.Parent = parent
	end
	corner.CornerRadius = UDim.new(0, radius)
	return corner
end

local function addStroke(parent, color, thickness, transparency)
	local stroke = parent:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = parent
	end
	stroke.Color = color
	stroke.Thickness = thickness or 2
	stroke.Transparency = transparency or 0
	return stroke
end

local function createText(parent, name, text, position, size, textSize, zIndex)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = zIndex
	label.Parent = parent
	GuiUtil.styleText(label, textSize, 10)
	return label
end

local function setupCreditsHud(gui)
	local existing = gui:FindFirstChild("CreditsHud")
	if existing then
		local existingAmount = existing:FindFirstChild("Amount", true)
		if existingAmount and existingAmount:IsA("TextLabel") then
			return existingAmount
		end

		existing:Destroy()
	end

	local root = Instance.new("Frame")
	root.Name = "CreditsHud"
	root.AnchorPoint = Vector2.new(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
	root.BackgroundTransparency = 0.08
	root.BorderSizePixel = 0
	root.Position = UDim2.new(1, -24, 1, -24)
	root.Size = UDim2.fromOffset(190, 56)
	root.ZIndex = 80
	root.Parent = gui
	addCorner(root, 12)
	addStroke(root, Color3.fromRGB(255, 214, 86), 2, 0.12)

	local icon = Instance.new("Frame")
	icon.Name = "DollarIcon"
	icon.BackgroundColor3 = Color3.fromRGB(255, 214, 86)
	icon.BorderSizePixel = 0
	icon.Position = UDim2.fromOffset(10, 8)
	icon.Size = UDim2.fromOffset(40, 40)
	icon.ZIndex = root.ZIndex + 1
	icon.Parent = root
	addCorner(icon, 20)

	local dollar = createText(icon, "Dollar", "$", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 28, icon.ZIndex + 1)
	dollar.TextColor3 = Color3.fromRGB(22, 26, 34)
	dollar.TextStrokeTransparency = 1
	dollar.TextXAlignment = Enum.TextXAlignment.Center

	local title =
		createText(root, "Title", "CREDITS", UDim2.fromOffset(60, 7), UDim2.fromOffset(118, 18), 12, root.ZIndex + 1)
	title.TextColor3 = Color3.fromRGB(190, 199, 214)
	title.TextStrokeTransparency = 0.75

	local amount =
		createText(root, "Amount", "0", UDim2.fromOffset(60, 24), UDim2.fromOffset(118, 26), 25, root.ZIndex + 1)
	amount.TextColor3 = Color3.fromRGB(255, 246, 190)
	amount.TextStrokeTransparency = 0.18
	return amount
end

local function setCreditsAmount(amount)
	if not creditsAmountLabel then
		return
	end

	creditsAmountLabel.Text = tostring(math.max(math.floor(tonumber(amount) or 0), 0))
end

local function getOrCreateUpdateListText(updateList)
	if not updateList or not updateList:IsA("GuiObject") then
		return nil
	end

	local existingText = findTextDescendant(updateList, {
		"AlphaUpdateText",
		"UpdatesList",
		"UpdateText",
		"UpdateLabel",
		"ListText",
		"Body",
		"Description",
		"Text",
		"Label",
		"Content",
	})

	if existingText then
		return existingText
	end

	local label = Instance.new("TextLabel")
	label.Name = "AlphaUpdateText"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(18, 16)
	label.Size = UDim2.new(1, -36, 1, -32)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.ZIndex = updateList.ZIndex + 1
	label.Parent = updateList
	return label
end

local function describeChildren(root)
	if not root then
		return "nil"
	end

	local descriptions = {}
	for _, descendant in root:GetDescendants() do
		table.insert(descriptions, `{descendant:GetFullName()} [{descendant.ClassName}]`)
	end

	return if #descriptions > 0 then table.concat(descriptions, ", ") else "no descendants"
end

local function setupUpdateLog(updatePanel)
	if not updatePanel then
		return
	end

	local headerContainer = updatePanel:FindFirstChild("Header", true)
	local headerText = if GuiUtil.isTextObject(headerContainer)
		then headerContainer
		else findTextDescendant(headerContainer, { "Title", "Text", "Label", "HeaderText" })

	if not setExistingText(headerText, UpdateLog.Title, 42, Enum.TextXAlignment.Center, Enum.TextYAlignment.Center) then
		warn("UpdateLog.Header has no existing text object to populate.")
	end

	local updatesContainer = updatePanel:FindFirstChild("UpdateList", true)
	local updatesText = if GuiUtil.isTextObject(updatesContainer) then updatesContainer else nil

	if not updatesText then
		updatesText = getOrCreateUpdateListText(updatesContainer)
	end

	if not setExistingText(updatesText, UpdateLog.Body, 18, Enum.TextXAlignment.Left, Enum.TextYAlignment.Top) then
		warn(
			`UpdateLog.UpdateList is {if updatesContainer then updatesContainer.ClassName else "missing"}, but it has no existing TextLabel/TextButton/TextBox to populate. Found: {describeChildren(
				updatesContainer
			)}`
		)
	end

	local eventButtons = {}
	for _, descendant in updatePanel:GetDescendants() do
		if GuiUtil.isButton(descendant) and descendant.Name == "Event" then
			table.insert(eventButtons, descendant)
		end
	end

	for _, button in eventButtons do
		button.Visible = false
	end
end

local function setupStore(storePanel)
	if not storePanel then
		return
	end

	local legacyHotbar = storePanel:FindFirstChild("DisasterHotbar")
	if legacyHotbar then
		legacyHotbar:Destroy()
	end

	storeController = StoreUI.setup(storePanel, {
		onPurchase = function(item)
			Network.disasterPurchaseRequest.send({
				weapon = item.Id,
			})
		end,
	})
end

local function setupLoadout(loadoutPanel)
	if not loadoutPanel then
		return
	end

	loadoutController = LoadoutUI.setup(loadoutPanel, {
		onEquip = function(item, slot)
			Network.loadoutEquipRequest.send({
				weapon = item.Id,
				slot = slot,
			})
		end,
	})
end

local function bindButtons(gui, leftButtons, panels)
	for _, button in GuiUtil.findAllDescendants(gui, GuiUtil.isButton) do
		GuiUtil.animateButton(button)
	end

	local playButton = getNamedButton(leftButtons, "Play")
	if playButton then
		playButton.Activated:Connect(function()
			Network.lobbyPlayRequest.send()
		end)
	end

	for panelName in panels do
		local button = getButtonForPanel(leftButtons, panelName)
		if button then
			button.Activated:Connect(function()
				showOnlyPanel(panels, panelName)
			end)
		end
	end

	for _, button in GuiUtil.findAllDescendants(gui, GuiUtil.isButton) do
		if GuiUtil.matches(button, { "close", "back", "exit", "x" }) then
			button.Activated:Connect(function()
				if button.Name == "X" then
					showOnlyPanel(panels, nil)
				else
					showOnlyPanel(panels, "UpdateLog")
				end
			end)
		end
	end
end

function MenuController.start()
	local gui = findLobbyGui()
	if not gui then
		warn("MainUI was not found in PlayerGui. Lobby menu controller did not start.")
		return
	end

	local leftButtons = getLeftButtons(gui)
	local panels = collectPanels(gui)
	ensureLoadoutPanel(gui, panels)

	if not panels.UpdateLog then
		warn("MainUI.Frame.UpdateLog was not found. Update log panel could not be shown.")
	end

	if not panels.Store then
		warn("MainUI.Frame.Store was not found. Store panel could not be opened.")
	end

	if not panels.LoadOut then
		warn("MainUI.Frame.LoadOut (or Inventory) was not found. Loadout panel could not be opened.")
	end

	gui.Enabled = true
	creditsAmountLabel = setupCreditsHud(gui)
	setCreditsAmount(0)
	Network.storeState.listen(function(data)
		if storeController then
			storeController.setStoreState(data)
		end
		if loadoutController then
			loadoutController.setStoreState(data)
		end
		setCreditsAmount(data and data.coins)
	end)

	setupUpdateLog(panels.UpdateLog)
	setupStore(panels.Store)
	setupLoadout(panels.LoadOut)
	Network.storeStateRequest.send()
	showOnlyPanel(panels, "UpdateLog")

	Network.queuePrompt.listen(function()
		gui.Enabled = true
		showOnlyPanel(panels, nil)
	end)

	Network.queueForceLeave.listen(function()
		gui.Enabled = true
		showOnlyPanel(panels, nil)
	end)

	if leftButtons then
		bindButtons(gui, leftButtons, panels)
	else
		warn("MainUI.Frame.LeftButtons was not found. Lobby buttons were not bound.")
	end
end

return MenuController
