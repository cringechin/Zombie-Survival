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
	}
end)
