local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


local PlayerDataService = require(
	ServerScriptService:WaitForChild("PlayerDataService")
)

local UpgradeDefinitions = require(
	ReplicatedStorage:WaitForChild(
		"UpgradeDefinitions"
	)
)

local OreTemplates = ServerStorage:WaitForChild("Ores")

local TrainInventoryService = {}

local StartingBackpackCapacity = 2
local StartingCarCapacity = 2

local function SyncCarsToMaximum(Data)
	if typeof(Data.Upgrades) ~= "table" then
		Data.Upgrades = {}
	end

	if typeof(Data.Train) ~= "table" then
		Data.Train = {}
	end

	if typeof(Data.Train.Cars) ~= "table" then
		Data.Train.Cars = {}
	end

	local MaximumCarsLevel =
		tonumber(
			Data.Upgrades.MaximumCars
		) or 0

	local MaximumCars =
		UpgradeDefinitions.GetValue(
			"MaximumCars",
			MaximumCarsLevel
		)

	MaximumCars =
		math.max(
			1,
			math.floor(
				tonumber(MaximumCars) or 1
			)
		)

	local CarCapacityLevel =
		tonumber(
			Data.Upgrades.CarCapacity
		) or 0

	local CarCapacity =
		UpgradeDefinitions.GetValue(
			"CarCapacity",
			CarCapacityLevel
		)

	CarCapacity =
		math.max(
			1,
			math.floor(
				tonumber(CarCapacity)
				or StartingCarCapacity
			)
		)

	while #Data.Train.Cars < MaximumCars do
		local NewCarIndex =
			#Data.Train.Cars + 1

		table.insert(
			Data.Train.Cars,
			{
				CarId =
					"Car_" .. NewCarIndex,

				CarType =
					"StarterOreCar",

				Capacity =
					CarCapacity,

				Inventory = {},
			}
		)
	end
end

local function GetInventoryLoad(Inventory)
	local Total = 0

	for _, Quantity in Inventory do
		if typeof(Quantity) == "number" and Quantity > 0 then
			Total += Quantity
		end
	end

	return Total
end

local function EnsureTrainData(Player)
	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return nil
	end

	if typeof(Data.Inventory) ~= "table" then
		Data.Inventory = {}
	end

	if typeof(Data.Stats) ~= "table" then
		Data.Stats = {}
	end

	if typeof(Data.Stats.BackpackCapacity) ~= "number" then
		Data.Stats.BackpackCapacity = StartingBackpackCapacity
	end

	if typeof(Data.Train) ~= "table" then
		Data.Train = {}
	end

	if typeof(Data.Train.LocomotiveId) ~= "string" then
		Data.Train.LocomotiveId = "PushCart"
	end

	if typeof(Data.Train.Cars) ~= "table" then
		Data.Train.Cars = {}
	end

	if #Data.Train.Cars == 0 then
		Data.Train.Cars = {
			{
				CarId = "Car_1",
				CarType = "StarterOreCar",
				Capacity = StartingCarCapacity,
				Inventory = {},
			},
		}
	end

	SyncCarsToMaximum(Data)

	for Index, CarData in Data.Train.Cars do
		if typeof(CarData.CarId) ~= "string" then
			CarData.CarId = "Car_" .. Index
		end

		if typeof(CarData.CarType) ~= "string" then
			CarData.CarType = "StarterOreCar"
		end

		if typeof(CarData.Capacity) ~= "number" then
			CarData.Capacity = StartingCarCapacity
		end

		if typeof(CarData.Inventory) ~= "table" then
			CarData.Inventory = {}
		end
	end

	return Data
end

local function FindCarData(Player, CarId)
	local Data = EnsureTrainData(Player)

	if not Data then
		return nil, nil
	end

	for Index, CarData in Data.Train.Cars do
		if CarData.CarId == CarId then
			return CarData, Index
		end
	end

	return nil, nil
end

local function GetOreValue(OreName)
	local Template = OreTemplates:FindFirstChild(OreName)

	if not Template then
		return 0
	end

	return Template:GetAttribute("Value") or 0
end

local function BuildInventoryRows(Inventory)
	local Rows = {}
	local TotalQuantity = 0
	local TotalValue = 0

	for OreName, Quantity in Inventory do
		if typeof(OreName) == "string"
			and typeof(Quantity) == "number"
			and Quantity > 0 then

			local Value = GetOreValue(OreName)
			local OreTotalValue = Value * Quantity

			TotalQuantity += Quantity
			TotalValue += OreTotalValue

			table.insert(Rows, {
				Name = OreName,
				Quantity = Quantity,
				Value = Value,
				TotalValue = OreTotalValue,
			})
		end
	end

	table.sort(Rows, function(First, Second)
		return First.Name:lower() < Second.Name:lower()
	end)

	return Rows, TotalQuantity, TotalValue
end

function TrainInventoryService.GetInventoryLoad(Inventory)
	return GetInventoryLoad(Inventory)
end

function TrainInventoryService.EnsureTrainData(Player)
	return EnsureTrainData(Player)
end

function TrainInventoryService.FindCarData(Player, CarId)
	return FindCarData(Player, CarId)
end

function TrainInventoryService.GetOverview(Player)
	local Data = EnsureTrainData(Player)

	if not Data then
		return nil
	end

	local BackpackRows, BackpackLoad, BackpackValue =
		BuildInventoryRows(Data.Inventory)

	local Cars = {}
	local TotalTrainLoad = 0
	local TotalTrainCapacity = 0
	local TotalTrainValue = 0

	for Index, CarData in Data.Train.Cars do
		local Rows, Load, Value =
			BuildInventoryRows(CarData.Inventory)

		TotalTrainLoad += Load
		TotalTrainCapacity += CarData.Capacity
		TotalTrainValue += Value

		table.insert(Cars, {
			Index = Index,
			CarId = CarData.CarId,
			CarType = CarData.CarType,
			Capacity = CarData.Capacity,
			Load = Load,
			Value = Value,
			Inventory = Rows,
		})
	end

	return {
		LocomotiveId = Data.Train.LocomotiveId,
		Backpack = {
			Capacity = Data.Stats.BackpackCapacity,
			Load = BackpackLoad,
			Value = BackpackValue,
			Inventory = BackpackRows,
		},

		Cars = Cars,
		CurrentCars = #Cars,
		TotalTrainLoad = TotalTrainLoad,
		TotalTrainCapacity = TotalTrainCapacity,
		TotalTrainValue = TotalTrainValue,
	}
end

function TrainInventoryService.Transfer(
	Player,
	Direction,
	CarId,
	OreName,
	RequestedQuantity
)
	local Data = EnsureTrainData(Player)

	if not Data then
		return false, "Player data is not loaded."
	end

	if typeof(Direction) ~= "string"
		or typeof(CarId) ~= "string"
		or typeof(OreName) ~= "string"
		or typeof(RequestedQuantity) ~= "number" then

		return false, "Invalid transfer request."
	end

	RequestedQuantity = math.floor(RequestedQuantity)

	if RequestedQuantity <= 0 or RequestedQuantity > 10000 then
		return false, "Invalid quantity."
	end

	local CarData = FindCarData(Player, CarId)

	if not CarData then
		return false, "Car was not found."
	end

	local SourceInventory
	local DestinationInventory
	local DestinationCapacity

	if Direction == "BackpackToCar" then
		SourceInventory = Data.Inventory
		DestinationInventory = CarData.Inventory
		DestinationCapacity = CarData.Capacity
	elseif Direction == "CarToBackpack" then
		SourceInventory = CarData.Inventory
		DestinationInventory = Data.Inventory
		DestinationCapacity = Data.Stats.BackpackCapacity
	else
		return false, "Invalid transfer direction."
	end

	local AvailableQuantity = SourceInventory[OreName] or 0
	local DestinationLoad = GetInventoryLoad(DestinationInventory)
	local RemainingSpace =
		math.max(DestinationCapacity - DestinationLoad, 0)

	local TransferQuantity = math.min(
		RequestedQuantity,
		AvailableQuantity,
		RemainingSpace
	)

	if TransferQuantity <= 0 then
		if AvailableQuantity <= 0 then
			return false, "You do not have that ore."
		end

		return false, "The destination is full."
	end

	local NewSourceQuantity =
		AvailableQuantity - TransferQuantity

	if NewSourceQuantity <= 0 then
		SourceInventory[OreName] = nil
	else
		SourceInventory[OreName] = NewSourceQuantity
	end

	DestinationInventory[OreName] =
		(DestinationInventory[OreName] or 0)
		+ TransferQuantity

	return true, TransferQuantity
end

return TrainInventoryService
