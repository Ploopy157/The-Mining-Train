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

	local RunService = game:GetService("RunService")

local TrainDistanceTrackers = {}
local DistanceUpdateInterval = 0.5
local MaximumValidDistancePerUpdate = 25
local DistanceElapsed = 0

local TrainInventoryService = require(
	ServerScriptService:WaitForChild(
		"TrainInventoryService"
	)
)

local function GetTrainTrackingPosition(Player)
	local Train = TrainService.GetPlayerTrain(Player)

	if not Train then
		return nil, nil
	end

	local Locomotive = TrainService.GetLocomotive(Train)

	if not Locomotive then
		return nil, Train
	end

	if Locomotive.PrimaryPart then
		return Locomotive.PrimaryPart.Position, Train
	end

	return Locomotive:GetPivot().Position, Train
end
local function UpdateTrainDistance(Player)
	local Position, Train = GetTrainTrackingPosition(Player)
	local Tracker = TrainDistanceTrackers[Player]

	if not Position or not Train then
		TrainDistanceTrackers[Player] = nil
		return
	end

	if not Tracker or Tracker.Train ~= Train then
		TrainDistanceTrackers[Player] = {
			Train = Train,
			Position = Position,
		}

		return
	end

	local Distance = (Position - Tracker.Position).Magnitude

	Tracker.Position = Position

	if Distance <= 0 or Distance > MaximumValidDistancePerUpdate then
		return
	end

	PlayerDataService.AddStat(
		Player,
		"TotalDistanceTraveled",
		Distance
	)
end

local TrainRemotes =
	ReplicatedStorage:WaitForChild(
		"TrainRemotes"
	)

local GetTrainOverview =
	TrainRemotes:WaitForChild(
		"GetTrainOverview"
	)
local TransferTrainOre =
	TrainRemotes:WaitForChild(
		"TransferTrainOre"
	)

GetTrainOverview.OnServerInvoke =
	function(Player)
		return TrainInventoryService.GetOverview(
			Player
		)
	end
TransferTrainOre.OnServerInvoke =
	function(
		Player,
		Direction,
		CarId,
		OreName,
		Quantity
	)
		return TrainInventoryService.Transfer(
			Player,
			Direction,
			CarId,
			OreName,
			Quantity
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

Players.PlayerRemoving:Connect(function(Player)
	TrainDistanceTrackers[Player] = nil
	TrainService.DestroyPlayerTrain(Player)
end)

for _, Player in Players:GetPlayers() do
	task.spawn(
		SpawnWhenReady,
		Player
	)
end

task.spawn(function()
	while true do
		task.wait(1)

		for _, Player in Players:GetPlayers() do
			UpdateTrainDistance(Player)
		end
	end
end)