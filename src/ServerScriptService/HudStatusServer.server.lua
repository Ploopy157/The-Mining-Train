local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local ServerScriptService =
	game:GetService("ServerScriptService")

local PlayerDataService = require(
	ServerScriptService:WaitForChild(
		"PlayerDataService"
	)
)

local TrainInventoryService = require(
	ServerScriptService:WaitForChild(
		"TrainInventoryService"
	)
)

local HudStatusRemotes =
	ReplicatedStorage:WaitForChild(
		"HudStatusRemotes"
	)

local GetHudStatus =
	HudStatusRemotes:WaitForChild(
		"GetHudStatus"
	)

local function GetInventoryLoad(Inventory)
	if typeof(Inventory) ~= "table" then
		return 0
	end

	local TotalLoad = 0

	for _, Quantity in Inventory do
		if typeof(Quantity) == "number"
			and Quantity > 0 then

			TotalLoad += Quantity
		end
	end

	return TotalLoad
end

GetHudStatus.OnServerInvoke =
	function(Player)

		local Data =
			PlayerDataService.GetData(
				Player
			)

		if not Data then
			return {
				IsLoaded = false,
			}
		end

		local Cash = 0
		local BagCapacity = 2

		if typeof(Data.Stats) == "table" then
			Cash =
				tonumber(
					Data.Stats.Cash
				) or 0

			BagCapacity =
				tonumber(
					Data.Stats.BackpackCapacity
				) or 2
		end

		local BagLoad =
			GetInventoryLoad(
				Data.Inventory
			)

		local TrainLoad = 0
		local TrainCapacity = 0

		local Overview =
			TrainInventoryService.GetOverview(
				Player
			)

		if typeof(Overview) == "table" then
			TrainLoad =
				tonumber(
					Overview.TotalTrainLoad
				) or 0

			TrainCapacity =
				tonumber(
					Overview.TotalTrainCapacity
				) or 0
		end

		return {
			IsLoaded = true,

			Cash = Cash,

			BagLoad = BagLoad,
			BagCapacity = BagCapacity,

			TrainLoad = TrainLoad,
			TrainCapacity = TrainCapacity,
		}
	end
