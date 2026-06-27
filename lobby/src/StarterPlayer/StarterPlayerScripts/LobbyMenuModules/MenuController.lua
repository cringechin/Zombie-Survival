local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuiUtil = require(script.Parent.GuiUtil)
local StoreItems = require(script.Parent.StoreItems)
local UpdateLog = require(script.Parent.UpdateLog)
local Network = require(ReplicatedStorage.Shared.Network.Packets)

local MenuController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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

local function findAllTextObjects(root)
	return GuiUtil.findAllDescendants(root, function(descendant)
		return GuiUtil.isTextObject(descendant)
	end)
end

local function setExistingText(textObject, text, maxTextSize, xAlignment, yAlignment)
	if not textObject then
		return false
	end

	textObject.Text = text
	textObject.TextXAlignment = xAlignment or Enum.TextXAlignment.Left
	textObject.TextYAlignment = yAlignment or Enum.TextYAlignment.Top
	GuiUtil.styleText(textObject, maxTextSize, 10)
	return true
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
		warn(`UpdateLog.UpdateList is {if updatesContainer then updatesContainer.ClassName else "missing"}, but it has no existing TextLabel/TextButton/TextBox to populate. Found: {describeChildren(updatesContainer)}`)
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

local function getStoreItemContainers(storePanel)
	local containers = {}

	for _, descendant in storePanel:GetDescendants() do
		if descendant:IsA("GuiObject") and descendant ~= storePanel then
			local name = GuiUtil.normalize(descendant.Name)
			local hasText = findTextDescendant(descendant, { "Name", "Title", "Price", "Description", "Text", "Label" }) ~= nil
			if hasText and (string.find(name, "item", 1, true) or string.find(name, "slot", 1, true) or string.find(name, "product", 1, true)) then
				table.insert(containers, descendant)
			end
		end
	end

	if #containers == 0 then
		for _, child in storePanel:GetChildren() do
			if child:IsA("GuiObject") and child.Name ~= "X" and child.Name ~= "Header" then
				if #findAllTextObjects(child) > 0 then
					table.insert(containers, child)
				end
			end
		end
	end

	return containers
end

local function setupStore(storePanel)
	if not storePanel then
		return
	end

	local titleText = findTextDescendant(storePanel:FindFirstChild("Header", true), { "Title", "Text", "Label" })
		or findTextDescendant(storePanel, { "Title", "StoreTitle", "Header" })
	setExistingText(titleText, "STORE", 34, Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)

	local itemContainers = getStoreItemContainers(storePanel)

	for index, item in StoreItems.Items do
		local container = itemContainers[index]
		if not container then
			continue
		end

		local nameText = findTextDescendant(container, { "Name", "Title", "ItemName" })
		local descriptionText = findTextDescendant(container, { "Description", "Desc", "Body" })
		local priceText = findTextDescendant(container, { "Price", "Cost" })
		local allText = findAllTextObjects(container)

		nameText = nameText or allText[1]
		descriptionText = descriptionText or allText[2]
		priceText = priceText or allText[3]

		setExistingText(nameText, item.Name, 22, Enum.TextXAlignment.Left, Enum.TextYAlignment.Center)
		setExistingText(descriptionText, item.Description, 15, Enum.TextXAlignment.Left, Enum.TextYAlignment.Top)
		setExistingText(priceText, item.Price, 18, Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)

		if GuiUtil.isButton(container) then
			GuiUtil.animateButton(container)
		end
	end

	if #itemContainers == 0 then
		warn("MainUI.Frame.Store has no existing item containers/text objects to populate.")
	end
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
	setupUpdateLog(panels.UpdateLog)
	setupStore(panels.Store)
	showOnlyPanel(panels, "UpdateLog")

	Network.queuePrompt.listen(function()
		gui.Enabled = false
	end)

	Network.queueForceLeave.listen(function()
		gui.Enabled = true
		showOnlyPanel(panels, "UpdateLog")
	end)

	if leftButtons then
		bindButtons(gui, leftButtons, panels)
	else
		warn("MainUI.Frame.LeftButtons was not found. Lobby buttons were not bound.")
	end
end

return MenuController
