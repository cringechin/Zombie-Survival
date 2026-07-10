local GuiUtil = require(script.Parent.GuiUtil)
local StoreItems = require(script.Parent.StoreItems)

local LoadoutUI = {}

local LOADOUT_LIMIT = 3
local PURCHASE_STATE = {
	Meteor = {
		unlockedKey = "meteorUnlocked",
	},
	Tornado = {
		unlockedKey = "tornadoUnlocked",
	},
}

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

local function isOwned(item, storeState)
	if item.Id == "Lightning" then
		return true
	end

	local purchaseState = PURCHASE_STATE[item.Id]
	return purchaseState and storeState[purchaseState.unlockedKey] == true
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

local function getFirstOwnedItem(storeState)
	for _, item in StoreItems.Items do
		if isOwned(item, storeState) then
			return item
		end
	end

	return StoreItems.Items[1]
end

local function hideLegacyLoadoutContent(loadoutPanel)
	for _, child in loadoutPanel:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "X" and child.Name ~= "LoadoutRoot" then
			child.Visible = false
		end
	end
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

local function createStatRow(parent, layoutOrder, zIndex)
	local row = create("Frame", {
		Name = `Stat{layoutOrder}`,
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 28),
		ZIndex = zIndex,
		Parent = parent,
	})

	local label = styleLabel(create("TextLabel", {
		Name = "Label",
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(0.42, 1),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = zIndex + 1,
		Parent = row,
	}), 15)

	local current = styleLabel(create("TextLabel", {
		Name = "Current",
		Position = UDim2.fromScale(0.42, 0),
		Size = UDim2.fromScale(0.24, 1),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 170, 72),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = zIndex + 1,
		Parent = row,
	}), 15)

	local arrow = styleLabel(create("TextLabel", {
		Name = "Arrow",
		Position = UDim2.fromScale(0.66, 0),
		Size = UDim2.fromScale(0.08, 1),
		Text = ">>",
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = zIndex + 1,
		Parent = row,
	}), 13)

	local upgraded = styleLabel(create("TextLabel", {
		Name = "Upgraded",
		Position = UDim2.fromScale(0.74, 0),
		Size = UDim2.fromScale(0.26, 1),
		Text = "",
		TextColor3 = Color3.fromRGB(120, 220, 120),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = zIndex + 1,
		Parent = row,
	}), 15)

	return {
		label = label,
		current = current,
		arrow = arrow,
		upgraded = upgraded,
	}
end

function LoadoutUI.setup(loadoutPanel, callbacks)
	if not loadoutPanel then
		return nil
	end

	hideLegacyLoadoutContent(loadoutPanel)

	local existingRoot = loadoutPanel:FindFirstChild("LoadoutRoot")
	if existingRoot then
		existingRoot:Destroy()
	end

	local closeButton = loadoutPanel:FindFirstChild("X", true)
	if closeButton and closeButton:IsA("GuiObject") then
		closeButton.Visible = true
		closeButton.ZIndex = loadoutPanel.ZIndex + 40
	end

	local root = create("Frame", {
		Name = "LoadoutRoot",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.03, 0.08),
		Size = UDim2.fromScale(0.94, 0.86),
		ZIndex = loadoutPanel.ZIndex + 1,
		Parent = loadoutPanel,
	})

	local title = styleLabel(create("TextLabel", {
		Name = "Title",
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 0.1),
		Text = "LOADOUT",
		TextColor3 = Color3.fromRGB(244, 238, 215),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = root.ZIndex + 1,
		Parent = root,
	}), 30)
	title.TextStrokeTransparency = 0.2

	local subtitle = styleLabel(create("TextLabel", {
		Name = "Subtitle",
		Position = UDim2.fromScale(0, 0.08),
		Size = UDim2.fromScale(1, 0.06),
		Text = "Choose a slot, then equip owned disasters.",
		TextColor3 = Color3.fromRGB(186, 197, 214),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = root.ZIndex + 1,
		Parent = root,
	}), 14)
	subtitle.TextStrokeTransparency = 0.62

	local slotsPanel = create("Frame", {
		Name = "SlotsPanel",
		BackgroundColor3 = Color3.fromRGB(18, 20, 24),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0.16),
		Size = UDim2.fromScale(1, 0.16),
		ZIndex = root.ZIndex + 1,
		Parent = root,
	})
	addCorner(slotsPanel, 10)
	addStroke(slotsPanel, Color3.fromRGB(90, 96, 110), 2, 0.2)

	local slotsLayout = Instance.new("UIListLayout")
	slotsLayout.FillDirection = Enum.FillDirection.Horizontal
	slotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	slotsLayout.Padding = UDim.new(0, 10)
	slotsLayout.Parent = slotsPanel

	local slotsPadding = Instance.new("UIPadding")
	slotsPadding.PaddingTop = UDim.new(0, 12)
	slotsPadding.PaddingBottom = UDim.new(0, 12)
	slotsPadding.PaddingLeft = UDim.new(0, 12)
	slotsPadding.PaddingRight = UDim.new(0, 12)
	slotsPadding.Parent = slotsPanel

	local content = create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.35),
		Size = UDim2.fromScale(1, 0.65),
		ZIndex = root.ZIndex + 1,
		Parent = root,
	})

	local grid = create("ScrollingFrame", {
		Name = "OwnedWeaponsGrid",
		BackgroundColor3 = Color3.fromRGB(18, 20, 24),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 0),
		Position = UDim2.fromScale(0, 0),
		ScrollBarThickness = 6,
		Size = UDim2.fromScale(0.56, 1),
		ZIndex = content.ZIndex + 1,
		Parent = content,
	})
	addCorner(grid, 10)
	addStroke(grid, Color3.fromRGB(90, 96, 110), 2, 0.2)

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellPadding = UDim2.fromOffset(12, 12)
	gridLayout.CellSize = UDim2.fromOffset(108, 108)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingTop = UDim.new(0, 12)
	gridPadding.PaddingBottom = UDim.new(0, 12)
	gridPadding.PaddingLeft = UDim.new(0, 12)
	gridPadding.PaddingRight = UDim.new(0, 12)
	gridPadding.Parent = grid

	local detailPanel = create("Frame", {
		Name = "DetailPanel",
		BackgroundColor3 = Color3.fromRGB(18, 20, 24),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.59, 0),
		Size = UDim2.fromScale(0.41, 1),
		ZIndex = content.ZIndex + 1,
		Parent = content,
	})
	addCorner(detailPanel, 10)
	addStroke(detailPanel, Color3.fromRGB(90, 96, 110), 2, 0.2)

	local detailPadding = Instance.new("UIPadding")
	detailPadding.PaddingTop = UDim.new(0, 16)
	detailPadding.PaddingBottom = UDim.new(0, 16)
	detailPadding.PaddingLeft = UDim.new(0, 16)
	detailPadding.PaddingRight = UDim.new(0, 16)
	detailPadding.Parent = detailPanel

	local detailName = styleLabel(create("TextLabel", {
		Name = "WeaponName",
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 0.1),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = detailPanel.ZIndex + 2,
		Parent = detailPanel,
	}), 26)

	local detailRarity = styleLabel(create("TextLabel", {
		Name = "Rarity",
		Position = UDim2.fromScale(0, 0.1),
		Size = UDim2.fromScale(1, 0.06),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = detailPanel.ZIndex + 2,
		Parent = detailPanel,
	}), 17)

	local detailInfo = styleLabel(create("TextLabel", {
		Name = "Info",
		Position = UDim2.fromScale(0, 0.16),
		Size = UDim2.fromScale(1, 0.06),
		Text = "",
		TextColor3 = Color3.fromRGB(186, 197, 214),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = detailPanel.ZIndex + 2,
		Parent = detailPanel,
	}), 13)
	detailInfo.TextStrokeTransparency = 0.6

	local previewFrame = create("Frame", {
		Name = "PreviewFrame",
		BackgroundColor3 = Color3.fromRGB(28, 32, 40),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0.24),
		Size = UDim2.fromScale(1, 0.28),
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
		Position = UDim2.fromScale(0, 0.55),
		Size = UDim2.fromScale(1, 0.23),
		ZIndex = detailPanel.ZIndex + 2,
		Parent = detailPanel,
	})

	local statsLayout = Instance.new("UIListLayout")
	statsLayout.Padding = UDim.new(0, 6)
	statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statsLayout.Parent = statsFrame

	local equipButton = create("TextButton", {
		Name = "EquipButton",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(58, 118, 196),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0.82),
		Size = UDim2.fromScale(1, 0.18),
		Text = "",
		ZIndex = detailPanel.ZIndex + 2,
		Parent = detailPanel,
	})
	addCorner(equipButton, 8)

	local equipText = styleLabel(create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = equipButton.ZIndex + 1,
		Parent = equipButton,
	}), 18)

	local controller = {
		selectedItem = StoreItems.Items[1],
		selectedSlot = 1,
		storeState = {},
		gridTiles = {},
		slotButtons = {},
		statRows = {},
		equipActionEnabled = false,
	}

	for slot = 1, LOADOUT_LIMIT do
		local slotButton = create("TextButton", {
			Name = `LoadoutSlot{slot}`,
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(34, 38, 46),
			BorderSizePixel = 0,
			LayoutOrder = slot,
			Size = UDim2.new(1 / LOADOUT_LIMIT, -8, 1, 0),
			Text = "",
			ZIndex = slotsPanel.ZIndex + 1,
			Parent = slotsPanel,
		})
		addCorner(slotButton, 8)
		local slotStroke = addStroke(slotButton, Color3.fromRGB(78, 86, 102), 2, 0.25)

		local slotNumber = styleLabel(create("TextLabel", {
			Name = "SlotNumber",
			Position = UDim2.fromScale(0, 0.08),
			Size = UDim2.fromScale(0.28, 0.84),
			Text = tostring(slot),
			TextColor3 = Color3.fromRGB(164, 181, 204),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = slotButton.ZIndex + 1,
			Parent = slotButton,
		}), 14)
		slotNumber.TextStrokeTransparency = 0.45

		local slotWeapon = styleLabel(create("TextLabel", {
			Name = "Weapon",
			Position = UDim2.fromScale(0.28, 0.08),
			Size = UDim2.fromScale(0.68, 0.84),
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

	local function updateSlotButtons()
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
		local equippedSlot = getEquippedSlot(item, controller.storeState)
		local accent = item.AccentColor or Color3.fromRGB(255, 224, 154)

		tileRefs.button.BackgroundColor3 = if selected
			then Color3.fromRGB(48, 58, 78)
			elseif owned then Color3.fromRGB(34, 38, 46)
			else Color3.fromRGB(24, 26, 30)

		tileRefs.preview.Image = item.Image or ""
		tileRefs.preview.ImageColor3 = if owned then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(120, 120, 120)
		tileRefs.preview.BackgroundColor3 = item.PreviewColor or Color3.fromRGB(48, 54, 64)
		tileRefs.locked.Visible = not owned
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
		local equippedSlot = getEquippedSlot(item, controller.storeState)
		local selectedSlot = controller.selectedSlot

		detailName.Text = item.Name
		detailRarity.Text = item.Rarity or ""
		detailRarity.TextColor3 = item.RarityColor or Color3.fromRGB(196, 196, 196)
		previewFrame.BackgroundColor3 = item.PreviewColor or Color3.fromRGB(28, 32, 40)
		previewImage.Image = item.Image or ""
		addStroke(previewFrame, item.AccentColor or Color3.fromRGB(120, 190, 255), 2, 0.15)

		for index, stat in item.Stats or {} do
			local rowRefs = controller.statRows[index]
			if rowRefs then
				rowRefs.label.Text = stat.Label
				rowRefs.current.Text = formatStatValue(stat.Current)
				rowRefs.current.TextColor3 = stat.CurrentColor
				rowRefs.upgraded.Text = formatStatValue(stat.Upgraded)
				rowRefs.upgraded.TextColor3 = stat.UpgradedColor
			end
		end

		controller.equipActionEnabled = false

		if not owned then
			detailInfo.Text = "Unlock this disaster in Store first."
			equipButton.BackgroundColor3 = Color3.fromRGB(76, 82, 94)
			equipText.Text = "UNLOCK IN STORE"
		elseif equippedSlot == selectedSlot then
			detailInfo.Text = `Already equipped in slot {selectedSlot}.`
			equipButton.BackgroundColor3 = Color3.fromRGB(58, 92, 72)
			equipText.Text = `EQUIPPED S{selectedSlot}`
		else
			detailInfo.Text = if equippedSlot
				then `Currently in slot {equippedSlot}.`
				else "Not equipped yet."
			equipButton.BackgroundColor3 = if equippedSlot then Color3.fromRGB(88, 106, 156) else Color3.fromRGB(58, 118, 196)
			equipText.Text = `EQUIP TO S{selectedSlot}`
			controller.equipActionEnabled = true
		end

		equipButton.Active = controller.equipActionEnabled
		equipButton.AutoButtonColor = false
	end

	function controller.setStoreState(storeState)
		controller.storeState = storeState or {}

		if not controller.selectedItem or not isOwned(controller.selectedItem, controller.storeState) then
			controller.selectedItem = getFirstOwnedItem(controller.storeState)
		end

		for itemId, tileRefs in controller.gridTiles do
			local item = tileRefs.item
			updateGridTile(tileRefs, item, controller.selectedItem and controller.selectedItem.Id == itemId)
		end

		updateSlotButtons()
		updateDetailPanel()
	end

	function controller.selectItem(item)
		controller.selectedItem = item
		for itemId, tileRefs in controller.gridTiles do
			updateGridTile(tileRefs, tileRefs.item, item and item.Id == itemId)
		end
		updateSlotButtons()
		updateDetailPanel()
	end

	function controller.selectSlot(slot)
		controller.selectedSlot = math.clamp(math.floor(slot), 1, LOADOUT_LIMIT)
		updateSlotButtons()
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

		local locked = styleLabel(create("TextLabel", {
			Name = "Locked",
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.35,
			Position = UDim2.fromScale(0.05, 0.28),
			Size = UDim2.fromScale(0.9, 0.4),
			Text = "LOCKED",
			TextColor3 = Color3.fromRGB(220, 220, 220),
			ZIndex = tileButton.ZIndex + 3,
			Parent = tileButton,
		}), 12)
		addCorner(locked, 6)

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
			locked = locked,
			preview = preview,
			stroke = stroke,
		}

		tileButton.Activated:Connect(function()
			controller.selectItem(item)
		end)
		GuiUtil.animateButton(tileButton)
	end

	local statCount = if controller.selectedItem and controller.selectedItem.Stats then #controller.selectedItem.Stats else 3
	for index = 1, statCount do
		controller.statRows[index] = createStatRow(statsFrame, index, statsFrame.ZIndex + 1)
	end

	gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		grid.CanvasSize = UDim2.fromOffset(0, gridLayout.AbsoluteContentSize.Y + 24)
	end)
	grid.CanvasSize = UDim2.fromOffset(0, gridLayout.AbsoluteContentSize.Y + 24)

	equipButton.Activated:Connect(function()
		local item = controller.selectedItem
		if not item or not controller.equipActionEnabled then
			return
		end

		if callbacks.onEquip then
			callbacks.onEquip(item, controller.selectedSlot)
		end
	end)
	GuiUtil.animateButton(equipButton)

	controller.setStoreState({})

	return controller
end

return LoadoutUI
