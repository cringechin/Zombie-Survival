local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Network = require(ReplicatedStorage.Shared.Network.Packets)
local Sounds = require(script.Parent.GameplaySounds)
local Style = require(script.Parent.GameplayStyle)

local e = React.createElement

local TONE_COLORS = {
	info = Style.RED,
	wave = Style.RED,
	boss = Style.LIGHTNING,
	danger = Color3.fromRGB(255, 190, 46),
	success = Style.GREEN,
}

local function notificationCard(notification, index)
	local progress = notification.Progress
	local eased = 1 - ((1 - progress) * (1 - progress))
	local exiting = notification.Exiting == true
	local alpha = if exiting then eased else 1 - eased
	local xOffset = if exiting then 90 * eased else 90 * (1 - eased)
	local toneColor = TONE_COLORS[notification.Tone] or Style.RED

	return e("Frame", {
		BackgroundColor3 = Style.PANEL,
		BackgroundTransparency = 0.03 + (0.75 * alpha),
		BorderSizePixel = 0,
		LayoutOrder = index,
		Size = UDim2.fromOffset(310, 74),
		ZIndex = 80 - index,
	}, {
		Corner = Style.corner(8),
		Stroke = Style.stroke(nil, 3, alpha),
		Slide = e("UIScale", {
			Scale = if exiting then 1 - (0.04 * eased) else 0.92 + (0.08 * eased),
		}),
		Accent = e("Frame", {
			BackgroundColor3 = toneColor,
			BackgroundTransparency = 0.04 + (0.6 * alpha),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(10, 74),
			ZIndex = 81,
		}, {
			Corner = Style.corner(8),
		}),
		Offset = e("UIPadding", {
			PaddingLeft = UDim.new(0, 18 + xOffset),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 8),
		}),
		Title = Style.text({
			Font = Enum.Font.GothamBlack,
			Size = UDim2.new(1, -10, 0, 26),
			Text = notification.Title,
			TextScaled = true,
			TextTransparency = alpha,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 20,
			MinTextSize = 10,
			ZIndex = 82,
		}),
		Body = Style.text({
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.new(1, -10, 0, 28),
			Text = notification.Body,
			TextScaled = true,
			TextTransparency = alpha,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 14,
			MinTextSize = 8,
			ZIndex = 82,
		}),
	})
end

local function NotificationFeed()
	local notifications, setNotifications = React.useState({})

	React.useEffect(function()
		local nextId = 0

		Network.gameNotification.listen(function(data)
			nextId += 1
			local id = nextId
			local tone = data.tone or "info"
			Sounds.play(tone)

			setNotifications(function(current)
				local nextNotifications = table.clone(current)
				table.insert(nextNotifications, 1, {
					Id = id,
					Title = data.title,
					Body = data.body,
					Tone = tone,
					Progress = 0,
					Exiting = false,
				})

				while #nextNotifications > 4 do
					table.remove(nextNotifications)
				end

				return nextNotifications
			end)

			task.spawn(function()
				for frameIndex = 1, 12 do
					setNotifications(function(current)
						local nextNotifications = table.clone(current)
						for _, notification in nextNotifications do
							if notification.Id == id then
								notification = notification
							end
						end
						for index, notification in nextNotifications do
							if notification.Id == id then
								local updated = table.clone(notification)
								updated.Progress = frameIndex / 12
								nextNotifications[index] = updated
							end
						end
						return nextNotifications
					end)
					task.wait(0.025)
				end

				task.wait(3)
				for frameIndex = 1, 12 do
					setNotifications(function(current)
						local nextNotifications = table.clone(current)
						for index, notification in nextNotifications do
							if notification.Id == id then
								local updated = table.clone(notification)
								updated.Progress = frameIndex / 12
								updated.Exiting = true
								nextNotifications[index] = updated
							end
						end
						return nextNotifications
					end)
					task.wait(0.025)
				end

				setNotifications(function(current)
					local nextNotifications = {}
					for _, notification in current do
						if notification.Id ~= id then
							table.insert(nextNotifications, notification)
						end
					end
					return nextNotifications
				end)
			end)
		end)
	end, {})

	local children = {
		List = e("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, notification in notifications do
		children[`Notification{notification.Id}`] = notificationCard(notification, index)
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -18, 0, 112),
		Size = UDim2.fromOffset(310, 330),
		ZIndex = 79,
	}, children)
end

return NotificationFeed
