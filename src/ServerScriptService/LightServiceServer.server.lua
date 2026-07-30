local ServerScriptService =
	game:GetService("ServerScriptService")

local LightService = require(
	ServerScriptService:WaitForChild(
		"LightService"
	)
)

LightService.Start()
