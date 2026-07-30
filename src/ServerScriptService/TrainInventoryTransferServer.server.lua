local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TrainInventoryService = require(ServerScriptService:WaitForChild("TrainInventoryService"))
local TransferTrainOre = ReplicatedStorage:WaitForChild("TrainRemotes"):WaitForChild("TransferTrainOre")

TransferTrainOre.OnServerInvoke = function(Player, Direction, CarId, OreName, Quantity)
	return TrainInventoryService.Transfer(
		Player,
		Direction,
		CarId,
		OreName,
		Quantity
	)
end
