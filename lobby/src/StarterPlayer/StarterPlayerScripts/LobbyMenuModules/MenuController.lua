local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuiUtil = require(script.Parent.GuiUtil)
local StoreItems = require(script.Parent.StoreItems)
local UpdateLog = require(script.Parent.UpdateLog)
local Network = require(ReplicatedStorage.Shared.Network.Packets)

local MenuController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local currentStoreState = {
	coins = 0,
	meteorUnlocked = false,
	meteorEquipped = false,
	meteorCost = 150,
	tornadoUnlocked = false,
	tornadoEquipped = false,
	tornadoCost = 300,
	loadoutSlot1 = "Lightning",
	loadoutSlot2 = "",
	loadoutSlot3 = "",
}
local meteorStoreRefs = nil
local storeItemRefs = {}
local hotbarRefs = {}
local selectedLoadoutSlot = 1
local PURCHASE_STATE = {
	Meteor = {
		costKey = "meteorCost",
		unlockedKey = "meteorUnlocked",
	},
	Tornado = {
		costKey = "tornadoCost",
		unlockedKey = "tornadoUnlocked",
	},
}

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

	textObject.Text = if text == nil then "" else tostring(text)
	textObject.TextXAlignment = xAlignment or Enum.TextXAlignment.Left
	textObject.TextYAlignment = yAlignment or Enum.TextYAlignment.Top
	GuiUtil.styleText(textObject, maxTextSize, 10)
	return true
end

local function getStoreItemById(itemId)
	for _, item in StoreItems.Items do
		if item.Id == itemId then
			return item
		end
	end

	return nil
end

local function isPurchasableDisaster(item)
	return item and item.Id and PURCHASE_STATE[item.Id] ~= nil
end

local function isOwnedDisaster(item)
	if item.Id == "Lightning" then
		return true
	end

	local purchaseState = PURCHASE_STATE[item.Id]
	return purchaseState and currentStoreState[purchaseState.unlockedKey] == true
end

local function getDisasterCost(item)
	local purchaseState = PURCHASE_STATE[item.Id]
	if not purchaseState then
		return 0
	end

	return currentStoreState[purchaseState.costKey] or 0
end

local function getWeaponSlot(weaponName)
	for index = 1, 3 do
		if currentStoreState[`loadoutSlot{index}`] == weaponName then
			return index
		end
	end

	return nil
end

local function getDisasterPriceText(item)
	if not isOwnedDisaster(item) then
		return `{getDisasterCost(item)} CR`
	end

	local slot = getWeaponSlot(item.Id)
	return if slot then `SLOT {slot}` else "EQUIP"
end

local function getDisasterDescription(item)
	if item.Id == "Lightning" then
		return item.Description
	end

	if not isOwnedDisaster(item) then
		return item.Description
	end

	return item.Description
end

local function getStorePriceText(item)
	if item.Id == "Lightning" or isPurchasableDisaster(item) then
		return getDisasterPriceText(item)
	end

	return item.Price
end

local function getStoreDescription(item)
	if item.Id == "Lightning" or isPurchasableDisaster(item) then
		return getDisasterDescription(item)
	end

	return item.Description
end

local function getActionColor(item)
	if item.Id == "Lightning" then
		return Color3.fromRGB(54, 104, 128)
	end

	if isPurchasableDisaster(item) and isOwnedDisaster(item) then
		return Color3.fromRGB(74, 126, 86)
	end

	return Color3.fromRGB(132, 82, 45)
end

local function updateHotbar()
	for index = 1, 3 do
		local refs = hotbarRefs[index]
		if not refs then
			continue
		end

		local weaponName = currentStoreState[`loadoutSlot{index}`]
		refs.button.BackgroundColor3 = if selectedLoadoutSlot == index
			then Color3.fromRGB(176, 42, 52)
			else Color3.fromRGB(28, 32, 38)
		setExistingText(refs.numberText, tostring(index), 22, Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)
		setExistingText(refs.weaponText, if weaponName ~= "" then weaponName else "EMPTY", 13, Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)
	end
end

local function updateStoreItems()
	for itemId, refs in storeItemRefs do
		local item = refs.item
		setExistingText(refs.descriptionText, getStoreDescription(item), 15, Enum.TextXAlignment.Left, Enum.TextYAlignment.Top)
		setExistingText(refs.priceText, getStorePriceText(item), 21, Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)

		if refs.buy then
			refs.buy.BackgroundColor3 = getActionColor(item)
		end
	end
end

local function updateMeteorStoreItem()
	if not meteorStoreRefs then
		return
	end

	local meteorItem = getStoreItemById("Meteor") or {
		Id = "Meteor",
		Name = "Meteor",
		Description = "",
	}

	setExistingText(
		meteorStoreRefs.descriptionText,
		getDisasterDescription(meteorItem),
		15,
		Enum.TextXAlignment.Left,
		Enum.TextYAlignment.Top
	)
	setExistingText(
		meteorStoreRefs.priceText,
		getDisasterPriceText(meteorItem),
		21,
		Enum.TextXAlignment.Center,
		Enum.TextYAlignment.Center
	)

	if meteorStoreRefs.buy then
		meteorStoreRefs.buy.BackgroundColor3 = getActionColor(meteorItem)
	end
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
	local storeList = storePanel:FindFirstChild("Store")

	if storeList and storeList:IsA("GuiObject") then
		for _, child in storeList:GetChildren() do
			if child:IsA("GuiObject") then
				table.insert(containers, child)
			end
		end

		table.sort(containers, function(left, right)
			if left.LayoutOrder == right.LayoutOrder then
				return left.Name < right.Name
			end

			return left.LayoutOrder < right.LayoutOrder
		end)

		if #containers > 0 then
			return containers
		end
	end

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

local function createStoreText(parent, name, position, size, textSize, xAlignment, yAlignment)
	local label = parent:FindFirstChild(name)
	if label and GuiUtil.isTextObject(label) then
		label.Position = position
		label.Size = size
	else
		label = Instance.new("TextLabel")
		label.Name = name
		label.Parent = parent
	end

	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.TextXAlignment = xAlignment or Enum.TextXAlignment.Left
	label.TextYAlignment = yAlignment or Enum.TextYAlignment.Center
	label.ZIndex = parent.ZIndex + 1
	GuiUtil.styleText(label, textSize, 10)
	return label
end

local function ensureStorePreview(slot, item)
	local preview = slot:FindFirstChild("DisasterPreview")
	if not preview or not preview:IsA("ImageLabel") then
		preview = Instance.new("ImageLabel")
		preview.Name = "DisasterPreview"
		preview.Parent = slot
	end

	preview.BackgroundColor3 = item.PreviewColor or Color3.fromRGB(48, 54, 64)
	preview.BackgroundTransparency = 0.08
	preview.BorderSizePixel = 0
	preview.Image = item.Image or ""
	preview.ImageColor3 = Color3.fromRGB(255, 255, 255)
	preview.Position = UDim2.fromScale(0.04, 0.16)
	preview.ScaleType = Enum.ScaleType.Fit
	preview.Size = UDim2.fromScale(0.22, 0.68)
	preview.ZIndex = slot.ZIndex + 2

	local corner = preview:FindFirstChildOfClass("UICorner")
	if not corner then
		corner = Instance.new("UICorner")
		corner.Parent = preview
	end
	corner.CornerRadius = UDim.new(0, 10)

	local stroke = preview:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = preview
	end
	stroke.Color = item.AccentColor or Color3.fromRGB(255, 224, 154)
	stroke.Thickness = 2
	stroke.Transparency = 0.18

	local previewText = createStoreText(
		preview,
		"PreviewText",
		UDim2.fromScale(0.08, 0.62),
		UDim2.fromScale(0.84, 0.26),
		13,
		Enum.TextXAlignment.Center,
		Enum.TextYAlignment.Center
	)
	setExistingText(previewText, item.PreviewText or item.Name, 13, Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)

	return preview
end

local function getOrCreateBuyHotspot(buy)
	if GuiUtil.isButton(buy) then
		return buy
	end

	local hotspot = buy:FindFirstChild("ActionHotspot")
	if hotspot and GuiUtil.isButton(hotspot) then
		return hotspot
	end

	hotspot = Instance.new("TextButton")
	hotspot.Name = "ActionHotspot"
	hotspot.BackgroundTransparency = 1
	hotspot.BorderSizePixel = 0
	hotspot.Size = UDim2.fromScale(1, 1)
	hotspot.Text = ""
	hotspot.ZIndex = buy.ZIndex + 2
	hotspot.Parent = buy
	return hotspot
end

local function bindStoreActionButton(button, item)
	local attributeName = `StoreBound_{item.Id or item.Name}`
	if button:GetAttribute(attributeName) then
		return
	end

	button:SetAttribute(attributeName, true)
	button.Activated:Connect(function()
		if isPurchasableDisaster(item) then
			Network.disasterPurchaseRequest.send({
				weapon = item.Id,
				slot = selectedLoadoutSlot,
			})
		elseif item.Id == "Lightning" then
			Network.disasterEquipRequest.send({
				weapon = "Lightning",
				slot = selectedLoadoutSlot,
			})
		end
	end)
	GuiUtil.animateButton(button)
end

local function ensureLoadoutHotbar(storePanel)
	local hotbar = storePanel:FindFirstChild("DisasterHotbar")
	if not hotbar or not hotbar:IsA("Frame") then
		hotbar = Instance.new("Frame")
		hotbar.Name = "DisasterHotbar"
		hotbar.Parent = storePanel
	end

	hotbar.BackgroundColor3 = Color3.fromRGB(9, 10, 14)
	hotbar.BackgroundTransparency = 0.16
	hotbar.BorderSizePixel = 0
	hotbar.Position = UDim2.fromScale(0.53, 0.035)
	hotbar.Size = UDim2.fromScale(0.32, 0.105)
	hotbar.ZIndex = storePanel.ZIndex + 30

	local corner = hotbar:FindFirstChildOfClass("UICorner")
	if not corner then
		corner = Instance.new("UICorner")
		corner.Parent = hotbar
	end
	corner.CornerRadius = UDim.new(0, 9)

	local stroke = hotbar:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = hotbar
	end
	stroke.Color = Color3.fromRGB(255, 224, 154)
	stroke.Thickness = 2
	stroke.Transparency = 0.18

	local layout = hotbar:FindFirstChildOfClass("UIListLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.Parent = hotbar
	end
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center

	local padding = hotbar:FindFirstChildOfClass("UIPadding")
	if not padding then
		padding = Instance.new("UIPadding")
		padding.Parent = hotbar
	end
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 6)

	for index = 1, 3 do
		local button = hotbar:FindFirstChild(`Slot{index}`)
		if not button or not button:IsA("TextButton") then
			button = Instance.new("TextButton")
			button.Name = `Slot{index}`
			button.AutoButtonColor = false
			button.BorderSizePixel = 0
			button.Text = ""
			button.Parent = hotbar
		end

		button.LayoutOrder = index
		button.Size = UDim2.fromScale(0.3, 1)
		button.ZIndex = hotbar.ZIndex + 1

		local buttonCorner = button:FindFirstChildOfClass("UICorner")
		if not buttonCorner then
			buttonCorner = Instance.new("UICorner")
			buttonCorner.Parent = button
		end
		buttonCorner.CornerRadius = UDim.new(0, 7)

		local numberText = createStoreText(button, "Number", UDim2.fromScale(0.06, 0.08), UDim2.fromScale(0.26, 0.84), 22, Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)
		local weaponText = createStoreText(button, "Weapon", UDim2.fromScale(0.33, 0.1), UDim2.fromScale(0.61, 0.8), 13, Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)

		hotbarRefs[index] = {
			button = button,
			numberText = numberText,
			weaponText = weaponText,
		}

		if not button:GetAttribute("LoadoutSlotBound") then
			button:SetAttribute("LoadoutSlotBound", true)
			button.Activated:Connect(function()
				selectedLoadoutSlot = index
				updateHotbar()
				updateStoreItems()
			end)
			GuiUtil.animateButton(button)
		end
	end

	updateHotbar()
end

local function setupStoreSlot(slot, item)
	slot.Visible = true
	ensureStorePreview(slot, item)

	local accent = item.AccentColor or Color3.fromRGB(255, 224, 154)
	local stroke = slot:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = slot
	end
	stroke.Color = accent
	stroke.Thickness = if item.Id == "Lightning" or isPurchasableDisaster(item) then 2 else 1
	stroke.Transparency = if item.Id == "Lightning" or isPurchasableDisaster(item) then 0.12 else 0.45

	local nameText = createStoreText(slot, "DisasterName", UDim2.fromScale(0.31, 0.12), UDim2.fromScale(0.38, 0.25), 24)
	local descriptionText = createStoreText(
		slot,
		"DisasterDescription",
		UDim2.fromScale(0.31, 0.42),
		UDim2.fromScale(0.34, 0.42),
		15,
		Enum.TextXAlignment.Left,
		Enum.TextYAlignment.Top
	)

	setExistingText(nameText, item.Name, 24, Enum.TextXAlignment.Left, Enum.TextYAlignment.Center)
	setExistingText(descriptionText, getStoreDescription(item), 15, Enum.TextXAlignment.Left, Enum.TextYAlignment.Top)

	local buy = slot:FindFirstChild("Buy", true)
	if buy and buy:IsA("GuiObject") then
		buy.Visible = true
		buy.Position = UDim2.fromScale(0.68, 0.18)
		buy.Size = UDim2.fromScale(0.29, 0.64)
		buy.ZIndex = slot.ZIndex + 3
		buy.BackgroundColor3 = getActionColor(item)
		buy.BackgroundTransparency = 0.05

		local priceText = findTextDescendant(buy, { "text", "Text", "Price", "Label" })
			or createStoreText(buy, "text", UDim2.fromScale(0.04, 0.08), UDim2.fromScale(0.92, 0.84), 21, Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)
		setExistingText(priceText, getStorePriceText(item), 21, Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)

		if item.Id == "Lightning" or isPurchasableDisaster(item) then
			storeItemRefs[item.Id] = {
				buy = buy,
				descriptionText = descriptionText,
				item = item,
				priceText = priceText,
			}
			bindStoreActionButton(getOrCreateBuyHotspot(buy), item)
		end

		if item.Id == "Meteor" then
			meteorStoreRefs = {
				buy = buy,
				descriptionText = descriptionText,
				priceText = priceText,
			}
			updateMeteorStoreItem()
		end
	end
end

local function setupStore(storePanel)
	if not storePanel then
		return
	end

	local titleText = findTextDescendant(storePanel:FindFirstChild("Header", true), { "Title", "Text", "Label" })
		or findTextDescendant(storePanel, { "Title", "StoreTitle", "Header" })
	setExistingText(titleText, "STORE", 34, Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)

	local generatedStoreList = storePanel:FindFirstChild("GeneratedStoreList")
	if generatedStoreList then
		generatedStoreList:Destroy()
	end
	ensureLoadoutHotbar(storePanel)

	local itemContainers = getStoreItemContainers(storePanel)

	for index, item in StoreItems.Items do
		local container = itemContainers[index]
		if not container then
			continue
		end

		setupStoreSlot(container, item)
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
	Network.storeState.listen(function(data)
		currentStoreState = data
		updateHotbar()
		updateStoreItems()
		updateMeteorStoreItem()
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
