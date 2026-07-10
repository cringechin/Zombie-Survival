local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByteNet = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("ByteNet"))

return ByteNet.defineNamespace("lobby", function()
	return {
		queuePrompt = ByteNet.definePacket({
			value = ByteNet.struct({
				cameraCFrame = ByteNet.cframe,
				isCreator = ByteNet.bool,
				maxPlayers = ByteNet.uint8,
			}),
		}),

		queueCreate = ByteNet.definePacket({
			value = ByteNet.struct({
				map = ByteNet.string,
				difficulty = ByteNet.string,
				maxPlayers = ByteNet.uint8,
			}),
		}),

		queueLeave = ByteNet.definePacket({
			value = ByteNet.nothing,
		}),

		queueForceLeave = ByteNet.definePacket({
			value = ByteNet.struct({
				message = ByteNet.string,
			}),
		}),

		lobbyPlayRequest = ByteNet.definePacket({
			value = ByteNet.nothing,
		}),

		meteorStoreRequest = ByteNet.definePacket({
			value = ByteNet.nothing,
		}),

		disasterPurchaseRequest = ByteNet.definePacket({
			value = ByteNet.struct({
				weapon = ByteNet.string,
				slot = ByteNet.optional(ByteNet.uint8),
			}),
		}),

		storeStateRequest = ByteNet.definePacket({
			value = ByteNet.nothing,
		}),

		storeState = ByteNet.definePacket({
			value = ByteNet.struct({
				coins = ByteNet.uint32,
				bestWave = ByteNet.uint32,
				meteorUnlocked = ByteNet.bool,
				meteorEquipped = ByteNet.bool,
				meteorCost = ByteNet.uint32,
				tornadoUnlocked = ByteNet.bool,
				tornadoEquipped = ByteNet.bool,
				tornadoCost = ByteNet.uint32,
				loadoutSlot1 = ByteNet.string,
				loadoutSlot2 = ByteNet.string,
				loadoutSlot3 = ByteNet.string,
			}),
		}),
	}
end)
