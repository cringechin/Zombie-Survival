local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByteNet = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("ByteNet"))

return ByteNet.defineNamespace("survival", function()
	return {
		waveStatus = ByteNet.definePacket({
			value = ByteNet.struct({
				wave = ByteNet.uint16,
				status = ByteNet.uint8,
				seconds = ByteNet.uint8,
			}),
		}),

		disasterWeaponCast = ByteNet.definePacket({
			value = ByteNet.struct({
				weapon = ByteNet.string,
				direction = ByteNet.vec3,
			}),
		}),

		weaponUpgradeRequest = ByteNet.definePacket({
			value = ByteNet.struct({
				weapon = ByteNet.string,
			}),
		}),
	}
end)
