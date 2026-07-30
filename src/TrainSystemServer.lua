local Players =
	game:GetService("Players")

local ServerScriptService =
	game:GetService("ServerScriptService")

local PlayerDataService = require(
	ServerScriptService:WaitForChild(
		"PlayerDataService"
	)
)

local TrainService = require(
	ServerScriptService:WaitForChild(
		"TrainService"
	)
)
local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local ServerScriptService =
	game:GetService("ServerScriptService")

local TrainInventoryService = require(
	ServerScriptService:WaitForChild(
		"TrainInventoryService"
	)
)

local TrainRemotes =
	ReplicatedStorage:WaitForChild(
		"TrainRemotes"
	)

local GetTrainOverview =
	TrainRemotes:WaitForChild(
		"GetTrainOverview"
	)

GetTrainOverview.OnServerInvoke =
	function(Player)
		return TrainInventoryService.GetOverview(
			Player
		)
	end

local function SpawnWhenReady(
	Player
)
	for Attempt = 1, 100 do
		if not Player.Parent then
			return
		end

		if PlayerDataService.GetData(
			Player
			) then
			break
		end

		task.wait(0.1)
	end

	if not PlayerDataService.GetData(
		Player
		) then
		warn(
			"Data did not load in time for",
			Player.Name
		)

		return
	end

	local Spawned,
		TrainOrError =
		TrainService.SpawnPlayerTrain(
			Player
		)

	if not Spawned then
		warn(
			"Could not spawn train for",
			Player.Name,
			TrainOrError
		)
	end
end

Players.PlayerAdded:Connect(
	function(Player)
		task.spawn(
			SpawnWhenReady,
			Player
		)
	end
)

for _, Player in Players:GetPlayers() do
	task.spawn(
		SpawnWhenReady,
		Player
	)
end