local ServerScriptService = game:GetService("ServerScriptService")

local ServiceLoader = require(ServerScriptService.Runtime.ServiceLoader)

ServiceLoader.start(ServerScriptService.Services)
