local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByteNet = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("ByteNet"))

return ByteNet.defineNamespace("survival", function()
	return {
		waveStatus = ByteNet.definePacket({
			value = ByteNet.struct({
				wave = ByteNet.uint16,
				status = ByteNet.uint8,
				seconds = ByteNet.uint8,
				zombiesRemaining = ByteNet.uint16,
				zombiesTotal = ByteNet.uint16,
				zombiesAlive = ByteNet.uint16,
			}),
		}),

		bossStatus = ByteNet.definePacket({
			value = ByteNet.struct({
				active = ByteNet.uint8,
				name = ByteNet.string,
				health = ByteNet.uint16,
				maxHealth = ByteNet.uint16,
			}),
		}),

		gameNotification = ByteNet.definePacket({
			value = ByteNet.struct({
				title = ByteNet.string,
				body = ByteNet.string,
				tone = ByteNet.string,
			}),
		}),

		disasterWeaponCast = ByteNet.definePacket({
			value = ByteNet.struct({
				weapon = ByteNet.string,
				direction = ByteNet.vec3,
				targetPosition = ByteNet.vec3,
			}),
		}),

		weaponUpgradeRequest = ByteNet.definePacket({
			value = ByteNet.struct({
				weapon = ByteNet.string,
			}),
		}),

		gearPurchaseRequest = ByteNet.definePacket({
			value = ByteNet.struct({
				gear = ByteNet.string,
				position = ByteNet.vec3,
			}),
		}),

		returnToLobbyRequest = ByteNet.definePacket({
			value = ByteNet.nothing,
		}),
	}
end)
