local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuiUtil = require(script.Parent.GuiUtil)
local StoreUI = require(script.Parent.StoreUI)
local UpdateLog = require(script.Parent.UpdateLog)
local Network = require(ReplicatedStorage.Shared.Network.Packets)

local MenuController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local storeController = nil
local creditsAmountLabel = nil

local PANEL_NAMES = {
	Store = true,
	UpdateLog = true,
	Daily = true,
	Party = true,
	Quests = true,
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

local function collectPanels(gui)
	local panels = {}
	local mainFrame = getMainFrame(gui)

	for panelName in PANEL_NAMES do
		local panel = mainFrame and mainFrame:FindFirstChild(panelName)
		if not panel then
			panel = gui:FindFirstChild(panelName, true)
		end

		if panel and panel:IsA("GuiObject") then
			panels[panelName] = panel
		end
	end

	return panels
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
		onPurchase = function(item, slot)
			Network.disasterPurchaseRequest.send({
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
		local button = getNamedButton(leftButtons, panelName)
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

	if not panels.UpdateLog then
		warn("MainUI.Frame.UpdateLog was not found. Update log panel could not be shown.")
	end

	if not panels.Store then
		warn("MainUI.Frame.Store was not found. Store panel could not be opened.")
	end

	gui.Enabled = true
	creditsAmountLabel = setupCreditsHud(gui)
	setCreditsAmount(0)
	Network.storeState.listen(function(data)
		if storeController then
			storeController.setStoreState(data)
		end
		setCreditsAmount(data and data.coins)
	end)

	setupUpdateLog(panels.UpdateLog)
	setupStore(panels.Store)
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
