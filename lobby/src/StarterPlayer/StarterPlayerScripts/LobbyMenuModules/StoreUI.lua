local GuiUtil = require(script.Parent.GuiUtil)
local StoreItems = require(script.Parent.StoreItems)

local StoreUI = {}

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

local TAB_COLORS = {
	active = Color3.fromRGB(72, 78, 92),
	inactive = Color3.fromRGB(42, 46, 56),
}

local LOADOUT_LIMIT = 3

local function create(className, props)
	local instance = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	return instance
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
	stroke.Transparency = transparency or 0.1
	return stroke
end

local function styleLabel(label, textSize)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.TextWrapped = true
	GuiUtil.styleText(label, textSize or 18, 10)
	return label
end

local function formatStatValue(value)
	if type(value) == "number" then
		if math.floor(value) == value then
			return tostring(value)
		end
		return string.format("%.2f", value)
	end
	return tostring(value)
end

local function isPurchasable(item)
	return item.Id ~= "Lightning" and PURCHASE_STATE[item.Id] ~= nil
end

local function canEquipItem(item)
	return item and (item.Id == "Lightning" or PURCHASE_STATE[item.Id] ~= nil)
end

local function isOwned(item, storeState)
	if item.Id == "Lightning" then
		return true
	end

	local purchaseState = PURCHASE_STATE[item.Id]
	return purchaseState and storeState[purchaseState.unlockedKey] == true
end

local function getCoinCost(item, storeState)
	if item.Id == "Lightning" then
		return 0
	end

	local purchaseState = PURCHASE_STATE[item.Id]
	if purchaseState then
		return storeState[purchaseState.costKey] or item.CoinCost
	end

	return item.CoinCost
end

local function getLoadoutWeapon(storeState, slot)
	local weaponName = storeState and storeState[`loadoutSlot{slot}`]
	return if type(weaponName) == "string" then weaponName else ""
end

local function getEquippedSlot(item, storeState)
	if not item then
		return nil
	end

	for slot = 1, LOADOUT_LIMIT do
		if getLoadoutWeapon(storeState, slot) == item.Id then
			return slot
		end
	end

	return nil
end

local function getPreferredSlot(item, storeState)
	local equippedSlot = getEquippedSlot(item, storeState)
	if equippedSlot then
		return equippedSlot
	end

	for slot = 1, LOADOUT_LIMIT do
		if getLoadoutWeapon(storeState, slot) == "" then
			return slot
		end
	end

	return 1
end

local function hideLegacyStoreContent(storePanel)
	for _, child in storePanel:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "X" and child.Name ~= "StoreRoot" then
			child.Visible = false
		end
	end
end

local function createTabButton(parent, name, layoutOrder, zIndex)
	local button = create("TextButton", {
		Name = name,
		AutoButtonColor = false,
		BackgroundColor3 = TAB_COLORS.inactive,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(150, 42),
		Text = "",
		ZIndex = zIndex,
		Parent = parent,
	})
	addCorner(button, 8)
	return button
end

local function createStarRow(parent, count, zIndex)
	local row = create("Frame", {
		Name = "Stars",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.18),
		ZIndex = zIndex,
		Parent = parent,
	})

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 2)
	layout.Parent = row

	for index = 1, 3 do
		local star = styleLabel(create("TextLabel", {
			Name = `Star{index}`,
			Size = UDim2.fromOffset(16, 16),
			Text = if index <= count then "★" else "",
			TextColor3 = Color3.fromRGB(255, 220, 90),
			ZIndex = zIndex + 1,
			Parent = row,
		}), 14)
		star.TextStrokeTransparency = 0.35
	end

	return row
end

local function createStatRow(parent, stat, layoutOrder, zIndex)
	local row = create("Frame", {
		Name = stat.Label,
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 28),
		ZIndex = zIndex,
		Parent = parent,
	})

	local label = styleLabel(create("TextLabel", {
		Name = "Label",
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(0.34, 1),
		Text = stat.Label,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = zIndex + 1,
		Parent = row,
	}), 16)

	local current = styleLabel(create("TextLabel", {
		Name = "Current",
		Position = UDim2.fromScale(0.34, 0),
		Size = UDim2.fromScale(0.24, 1),
		Text = formatStatValue(stat.Current),
		TextColor3 = stat.CurrentColor,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = zIndex + 1,
		Parent = row,
	}), 16)

	local arrow = styleLabel(create("TextLabel", {
		Name = "Arrow",
		Position = UDim2.fromScale(0.58, 0),
		Size = UDim2.fromScale(0.08, 1),
		Text = ">>",
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = zIndex + 1,
		Parent = row,
	}), 14)

	local upgraded = styleLabel(create("TextLabel", {
		Name = "Upgraded",
		Position = UDim2.fromScale(0.66, 0),
		Size = UDim2.fromScale(0.34, 1),
		Text = formatStatValue(stat.Upgraded),
		TextColor3 = stat.UpgradedColor,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = zIndex + 1,
		Parent = row,
	}), 16)

	return {
		row = row,
		label = label,
		current = current,
		arrow = arrow,
		upgraded = upgraded,
	}
end

function StoreUI.setup(storePanel, callbacks)
	if not storePanel then
		return nil
	end

	hideLegacyStoreContent(storePanel)

	local existingRoot = storePanel:FindFirstChild("StoreRoot")
	if existingRoot then
		existingRoot:Destroy()
	end

	local closeButton = storePanel:FindFirstChild("X", true)
	if closeButton and closeButton:IsA("GuiObject") then
		closeButton.Visible = true
		closeButton.ZIndex = storePanel.ZIndex + 40
	end

	local root = create("Frame", {
		Name = "StoreRoot",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.03, 0.1),
		Size = UDim2.fromScale(0.94, 0.84),
		ZIndex = storePanel.ZIndex + 1,
		Parent = storePanel,
	})

	local tabBar = create("Frame", {
		Name = "TabBar",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(0.42, 0.1),
		ZIndex = root.ZIndex + 1,
		Parent = root,
	})

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 10)
	tabLayout.Parent = tabBar

	local weaponsTab = createTabButton(tabBar, "WeaponsTab", 1, tabBar.ZIndex + 1)
	local gearsTab = createTabButton(tabBar, "GearsTab", 2, tabBar.ZIndex + 1)

	local weaponsTabText = styleLabel(create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "Weapons",
		ZIndex = weaponsTab.ZIndex + 1,
		Parent = weaponsTab,
	}), 18)

	local gearsTabText = styleLabel(create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "Gears",
		ZIndex = gearsTab.ZIndex + 1,
		Parent = gearsTab,
	}), 18)

	local content = create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.12),
		Size = UDim2.fromScale(1, 0.88),
		ZIndex = root.ZIndex + 1,
		Parent = root,
	})

	local weaponsView = create("Frame", {
		Name = "WeaponsView",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = content.ZIndex + 1,
		Parent = content,
	})

	local grid = create("ScrollingFrame", {
		Name = "ItemGrid",
		BackgroundColor3 = Color3.fromRGB(18, 20, 24),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 0),
		Position = UDim2.fromScale(0, 0),
		ScrollBarThickness = 6,
		Size = UDim2.fromScale(0.56, 1),
		ZIndex = weaponsView.ZIndex + 1,
		Parent = weaponsView,
	})
	addCorner(grid, 10)
	addStroke(grid, Color3.fromRGB(90, 96, 110), 2, 0.2)

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellPadding = UDim2.fromOffset(12, 12)
	gridLayout.CellSize = UDim2.fromOffset(108, 108)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingBottom = UDim.new(0, 12)
	gridPadding.PaddingLeft = UDim.new(0, 12)
	gridPadding.PaddingRight = UDim.new(0, 12)
	gridPadding.PaddingTop = UDim.new(0, 12)
	gridPadding.Parent = grid

	local detailPanel = create("Frame", {
		Name = "DetailPanel",
		BackgroundColor3 = Color3.fromRGB(18, 20, 24),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.59, 0),
		Size = UDim2.fromScale(0.41, 1),
		ZIndex = weaponsView.ZIndex + 1,
		Parent = weaponsView,
	})
	addCorner(detailPanel, 10)
	addStroke(detailPanel, Color3.fromRGB(90, 96, 110), 2, 0.2)

	local detailPadding = Instance.new("UIPadding")
	detailPadding.PaddingBottom = UDim.new(0, 16)
	detailPadding.PaddingLeft = UDim.new(0, 16)
	detailPadding.PaddingRight = UDim.new(0, 16)
	detailPadding.PaddingTop = UDim.new(0, 16)
	detailPadding.Parent = detailPanel

	local detailName = styleLabel(create("TextLabel", {
		Name = "WeaponName",
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 0.1),
		Text = "Select a weapon",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = detailPanel.ZIndex + 2,
		Parent = detailPanel,
	}), 28)

	local detailRarity = styleLabel(create("TextLabel", {
		Name = "Rarity",
		Position = UDim2.fromScale(0, 0.1),
		Size = UDim2.fromScale(1, 0.06),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = detailPanel.ZIndex + 2,
		Parent = detailPanel,
	}), 18)

	local previewFrame = create("Frame", {
		Name = "PreviewFrame",
		BackgroundColor3 = Color3.fromRGB(28, 32, 40),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0.16),
		Size = UDim2.fromScale(1, 0.3),
		ZIndex = detailPanel.ZIndex + 2,
		Parent = detailPanel,
	})
	addCorner(previewFrame, 10)
	addStroke(previewFrame, Color3.fromRGB(120, 190, 255), 2, 0.15)

	local previewImage = create("ImageLabel", {
		Name = "PreviewImage",
		BackgroundTransparency = 1,
		Image = "",
		Position = UDim2.fromScale(0.08, 0.08),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(0.84, 0.84),
		ZIndex = previewFrame.ZIndex + 1,
		Parent = previewFrame,
	})

	local statsFrame = create("Frame", {
		Name = "Stats",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.49),
		Size = UDim2.fromScale(1, 0.18),
		ZIndex = detailPanel.ZIndex + 2,
		Parent = detailPanel,
	})

	local statsLayout = Instance.new("UIListLayout")
	statsLayout.Padding = UDim.new(0, 6)
	statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statsLayout.Parent = statsFrame

	local loadoutTitle = styleLabel(create("TextLabel", {
		Name = "LoadoutTitle",
		Position = UDim2.fromScale(0, 0.7),
		Size = UDim2.fromScale(1, 0.06),
		Text = "Loadout Slot",
		TextColor3 = Color3.fromRGB(205, 214, 225),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = detailPanel.ZIndex + 2,
		Parent = detailPanel,
	}), 15)
	loadoutTitle.TextStrokeTransparency = 0.35

	local loadoutRow = create("Frame", {
		Name = "LoadoutRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.76),
		Size = UDim2.fromScale(1, 0.1),
		ZIndex = detailPanel.ZIndex + 2,
		Parent = detailPanel,
	})

	local loadoutLayout = Instance.new("UIListLayout")
	loadoutLayout.FillDirection = Enum.FillDirection.Horizontal
	loadoutLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	loadoutLayout.Padding = UDim.new(0, 8)
	loadoutLayout.Parent = loadoutRow

	local purchaseRow = create("Frame", {
		Name = "PurchaseRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.88),
		Size = UDim2.fromScale(1, 0.12),
		ZIndex = detailPanel.ZIndex + 2,
		Parent = detailPanel,
	})

	local purchaseLayout = Instance.new("UIListLayout")
	purchaseLayout.FillDirection = Enum.FillDirection.Horizontal
	purchaseLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	purchaseLayout.Padding = UDim.new(0, 10)
	purchaseLayout.Parent = purchaseRow

	local coinButton = create("TextButton", {
		Name = "CoinPurchase",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(58, 118, 196),
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Size = UDim2.fromOffset(190, 46),
		Text = "",
		ZIndex = purchaseRow.ZIndex + 1,
		Parent = purchaseRow,
	})
	addCorner(coinButton, 8)

	local coinText = styleLabel(create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "0 CR",
		ZIndex = coinButton.ZIndex + 1,
		Parent = coinButton,
	}), 18)

	local robuxButton = create("TextButton", {
		Name = "RobuxPurchase",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(72, 168, 88),
		BorderSizePixel = 0,
		LayoutOrder = 2,
		Size = UDim2.fromOffset(110, 46),
		Text = "",
		Visible = false,
		ZIndex = purchaseRow.ZIndex + 1,
		Parent = purchaseRow,
	})
	addCorner(robuxButton, 8)

	local robuxText = styleLabel(create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "R$ 0",
		ZIndex = robuxButton.ZIndex + 1,
		Parent = robuxButton,
	}), 18)

	local gearsView = create("Frame", {
		Name = "GearsView",
		BackgroundColor3 = Color3.fromRGB(18, 20, 24),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = content.ZIndex + 1,
		Parent = content,
	})
	addCorner(gearsView, 10)

	local gearsPlaceholder = styleLabel(create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.1, 0.4),
		Size = UDim2.fromScale(0.8, 0.2),
		Text = "Gears coming soon.",
		ZIndex = gearsView.ZIndex + 1,
		Parent = gearsView,
	}), 24)

	local controller = {
		selectedItem = StoreItems.Items[1],
		selectedSlot = 1,
		storeState = {},
		gridTiles = {},
		purchaseActionEnabled = false,
		slotButtons = {},
		statRows = {},
	}

	for slot = 1, LOADOUT_LIMIT do
		local slotButton = create("TextButton", {
			Name = `LoadoutSlot{slot}`,
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(34, 38, 46),
			BorderSizePixel = 0,
			LayoutOrder = slot,
			Size = UDim2.new(1 / LOADOUT_LIMIT, -6, 1, 0),
			Text = "",
			ZIndex = loadoutRow.ZIndex + 1,
			Parent = loadoutRow,
		})
		addCorner(slotButton, 7)
		local slotStroke = addStroke(slotButton, Color3.fromRGB(78, 86, 102), 2, 0.25)

		local slotNumber = styleLabel(create("TextLabel", {
			Name = "SlotNumber",
			Position = UDim2.fromScale(0, 0.08),
			Size = UDim2.fromScale(0.3, 0.84),
			Text = tostring(slot),
			TextColor3 = Color3.fromRGB(164, 181, 204),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = slotButton.ZIndex + 1,
			Parent = slotButton,
		}), 14)
		slotNumber.TextStrokeTransparency = 0.45

		local slotWeapon = styleLabel(create("TextLabel", {
			Name = "Weapon",
			Position = UDim2.fromScale(0.3, 0.08),
			Size = UDim2.fromScale(0.66, 0.84),
			Text = "Empty",
			TextColor3 = Color3.fromRGB(220, 226, 235),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = slotButton.ZIndex + 1,
			Parent = slotButton,
		}), 13)
		slotWeapon.TextStrokeTransparency = 0.45

		controller.slotButtons[slot] = {
			button = slotButton,
			number = slotNumber,
			stroke = slotStroke,
			weapon = slotWeapon,
		}
	end

	local function setActiveTab(tabName)
		local weaponsActive = tabName == "Weapons"
		weaponsTab.BackgroundColor3 = if weaponsActive then TAB_COLORS.active else TAB_COLORS.inactive
		gearsTab.BackgroundColor3 = if weaponsActive then TAB_COLORS.inactive else TAB_COLORS.active
		weaponsView.Visible = weaponsActive
		gearsView.Visible = not weaponsActive
	end

	local function updateLoadoutSlots()
		for slot, refs in controller.slotButtons do
			local weaponName = getLoadoutWeapon(controller.storeState, slot)
			local selected = controller.selectedSlot == slot
			local selectedWeaponInSlot = controller.selectedItem and controller.selectedItem.Id == weaponName
			local accent = if selectedWeaponInSlot and controller.selectedItem
				then controller.selectedItem.AccentColor or Color3.fromRGB(120, 190, 255)
				else Color3.fromRGB(92, 102, 122)

			refs.button.BackgroundColor3 = if selected
				then Color3.fromRGB(52, 62, 82)
				elseif weaponName ~= "" then Color3.fromRGB(34, 39, 50)
				else Color3.fromRGB(24, 27, 34)
			refs.number.TextColor3 = if selected then Color3.fromRGB(255, 226, 117) else Color3.fromRGB(164, 181, 204)
			refs.stroke.Color = if selected then Color3.fromRGB(255, 226, 117) else accent
			refs.stroke.Thickness = if selected then 3 else 2
			refs.weapon.Text = if weaponName ~= "" then weaponName else "Empty"
			refs.weapon.TextColor3 = if weaponName ~= "" then Color3.fromRGB(226, 233, 242) else Color3.fromRGB(130, 140, 154)
		end
	end

	local function updateGridTile(tileRefs, item, selected)
		local owned = isOwned(item, controller.storeState)
		local accent = item.AccentColor or Color3.fromRGB(255, 224, 154)
		local equippedSlot = getEquippedSlot(item, controller.storeState)

		tileRefs.button.BackgroundColor3 = if selected
			then Color3.fromRGB(48, 58, 78)
			elseif owned then Color3.fromRGB(34, 38, 46)
			else Color3.fromRGB(24, 26, 30)

		tileRefs.preview.Image = item.Image or ""
		tileRefs.preview.ImageColor3 = if owned then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(120, 120, 120)
		tileRefs.preview.BackgroundColor3 = item.PreviewColor or Color3.fromRGB(48, 54, 64)
		tileRefs.notOwned.Visible = not owned and isPurchasable(item)
		tileRefs.equipped.Visible = equippedSlot ~= nil
		tileRefs.equipped.Text = if equippedSlot then `SLOT {equippedSlot}` else ""
		tileRefs.stroke.Color = if selected then accent else Color3.fromRGB(90, 96, 110)
		tileRefs.stroke.Thickness = if selected then 3 else 2
	end

	local function updateDetailPanel()
		local item = controller.selectedItem
		if not item then
			return
		end

		local owned = isOwned(item, controller.storeState)
		local coinCost = getCoinCost(item, controller.storeState)
		local equippedSlot = getEquippedSlot(item, controller.storeState)
		local selectedSlot = controller.selectedSlot or getPreferredSlot(item, controller.storeState)
		local coins = controller.storeState.coins or 0
		local canAfford = coins >= coinCost

		detailName.Text = item.Name
		detailRarity.Text = item.Rarity or ""
		detailRarity.TextColor3 = item.RarityColor or Color3.fromRGB(196, 196, 196)
		previewFrame.BackgroundColor3 = item.PreviewColor or Color3.fromRGB(28, 32, 40)
		previewImage.Image = item.Image or ""
		addStroke(previewFrame, item.AccentColor or Color3.fromRGB(120, 190, 255), 2, 0.15)

		for index, stat in item.Stats or {} do
			local rowRefs = controller.statRows[index]
			if rowRefs then
				rowRefs.current.Text = formatStatValue(stat.Current)
				rowRefs.current.TextColor3 = stat.CurrentColor
				rowRefs.upgraded.Text = formatStatValue(stat.Upgraded)
				rowRefs.upgraded.TextColor3 = stat.UpgradedColor
			end
		end

		controller.purchaseActionEnabled = false

		if not canEquipItem(item) then
			coinButton.BackgroundColor3 = Color3.fromRGB(76, 82, 94)
			coinText.Text = "UNAVAILABLE"
		elseif owned then
			if equippedSlot == selectedSlot then
				coinButton.BackgroundColor3 = Color3.fromRGB(58, 92, 72)
				coinText.Text = `EQUIPPED S{selectedSlot}`
			else
				coinButton.BackgroundColor3 = if equippedSlot then Color3.fromRGB(88, 106, 156) else Color3.fromRGB(58, 118, 196)
				coinText.Text = if equippedSlot then `MOVE TO S{selectedSlot}` else `EQUIP S{selectedSlot}`
				controller.purchaseActionEnabled = true
			end
		elseif canAfford then
			coinButton.BackgroundColor3 = Color3.fromRGB(58, 118, 196)
			coinText.Text = `BUY S{selectedSlot} | {coinCost} CR`
			controller.purchaseActionEnabled = true
		else
			coinButton.BackgroundColor3 = Color3.fromRGB(98, 56, 62)
			coinText.Text = `NEED {coinCost - coins} CR`
		end

		coinButton.Active = controller.purchaseActionEnabled
		coinButton.AutoButtonColor = false

		if item.RobuxCost and item.RobuxCost > 0 and not owned and isPurchasable(item) then
			robuxButton.Visible = true
			robuxText.Text = `R$ {item.RobuxCost}`
			robuxButton.Active = false
			robuxButton.BackgroundColor3 = Color3.fromRGB(52, 120, 64)
		else
			robuxButton.Visible = false
		end
	end

	function controller.setStoreState(storeState)
		controller.storeState = storeState or {}
		if controller.selectedItem then
			controller.selectedSlot = getPreferredSlot(controller.selectedItem, controller.storeState)
		end

		for itemId, tileRefs in controller.gridTiles do
			local item = tileRefs.item
			updateGridTile(tileRefs, item, controller.selectedItem and controller.selectedItem.Id == itemId)
		end
		updateLoadoutSlots()
		updateDetailPanel()
	end

	function controller.selectItem(item)
		controller.selectedItem = item
		controller.selectedSlot = getPreferredSlot(item, controller.storeState)
		for itemId, tileRefs in controller.gridTiles do
			updateGridTile(tileRefs, tileRefs.item, item and item.Id == itemId)
		end
		updateLoadoutSlots()
		updateDetailPanel()
	end

	function controller.selectSlot(slot)
		controller.selectedSlot = math.clamp(math.floor(slot), 1, LOADOUT_LIMIT)
		updateLoadoutSlots()
		updateDetailPanel()
	end

	for slot, refs in controller.slotButtons do
		refs.button.Activated:Connect(function()
			controller.selectSlot(slot)
		end)
		GuiUtil.animateButton(refs.button)
	end

	for index, item in StoreItems.Items do
		local tileButton = create("TextButton", {
			Name = `{item.Id}Tile`,
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(34, 38, 46),
			BorderSizePixel = 0,
			LayoutOrder = index,
			Text = "",
			ZIndex = grid.ZIndex + 1,
			Parent = grid,
		})
		addCorner(tileButton, 8)
		local stroke = addStroke(tileButton, Color3.fromRGB(90, 96, 110), 2, 0.2)

		local preview = create("ImageLabel", {
			Name = "Preview",
			BackgroundColor3 = item.PreviewColor or Color3.fromRGB(48, 54, 64),
			BackgroundTransparency = 0.05,
			BorderSizePixel = 0,
			Image = item.Image or "",
			Position = UDim2.fromScale(0.08, 0.08),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.84, 0.58),
			ZIndex = tileButton.ZIndex + 1,
			Parent = tileButton,
		})
		addCorner(preview, 6)

		local stars = createStarRow(tileButton, item.Stars or 1, tileButton.ZIndex + 2)
		stars.Position = UDim2.fromScale(0, 0.72)
		stars.Size = UDim2.fromScale(1, 0.2)

		local notOwned = styleLabel(create("TextLabel", {
			Name = "NotOwned",
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.35,
			Position = UDim2.fromScale(0.05, 0.28),
			Size = UDim2.fromScale(0.9, 0.4),
			Text = "NOT OWNED",
			TextColor3 = Color3.fromRGB(220, 220, 220),
			ZIndex = tileButton.ZIndex + 3,
			Parent = tileButton,
		}), 12)
		addCorner(notOwned, 6)

		local equipped = styleLabel(create("TextLabel", {
			Name = "Equipped",
			BackgroundColor3 = Color3.fromRGB(64, 132, 86),
			BackgroundTransparency = 0.05,
			Position = UDim2.fromScale(0.08, 0.08),
			Size = UDim2.fromScale(0.44, 0.2),
			Text = "",
			TextColor3 = Color3.fromRGB(240, 255, 244),
			TextXAlignment = Enum.TextXAlignment.Center,
			Visible = false,
			ZIndex = tileButton.ZIndex + 4,
			Parent = tileButton,
		}), 11)
		addCorner(equipped, 5)

		controller.gridTiles[item.Id] = {
			button = tileButton,
			equipped = equipped,
			item = item,
			notOwned = notOwned,
			preview = preview,
			stroke = stroke,
		}

		tileButton.Activated:Connect(function()
			controller.selectItem(item)
		end)
		GuiUtil.animateButton(tileButton)
	end

	for index, stat in controller.selectedItem.Stats or {} do
		controller.statRows[index] = createStatRow(statsFrame, stat, index, statsFrame.ZIndex + 1)
	end

	gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		grid.CanvasSize = UDim2.fromOffset(0, gridLayout.AbsoluteContentSize.Y + 24)
	end)
	grid.CanvasSize = UDim2.fromOffset(0, gridLayout.AbsoluteContentSize.Y + 24)

	weaponsTab.Activated:Connect(function()
		setActiveTab("Weapons")
	end)
	gearsTab.Activated:Connect(function()
		setActiveTab("Gears")
	end)
	GuiUtil.animateButton(weaponsTab)
	GuiUtil.animateButton(gearsTab)

	coinButton.Activated:Connect(function()
		local item = controller.selectedItem
		if not item or not canEquipItem(item) or not controller.purchaseActionEnabled then
			return
		end

		if callbacks.onPurchase then
			callbacks.onPurchase(item, controller.selectedSlot)
		end
	end)
	GuiUtil.animateButton(coinButton)

	setActiveTab("Weapons")
	controller.selectItem(StoreItems.Items[1])

	return controller
end

return StoreUI
