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

local function WithdrawAllFromCar(Player, CarId)
	local Data = EnsureTrainData(Player)

	if not Data then
		return false, "Player data is not loaded."
	end

	if typeof(CarId) ~= "string" or CarId == "" then
		return false, "Invalid car."
	end

	local CarData = FindCarData(Player, CarId)

	if not CarData then
		return false, "Car was not found."
	end

	if typeof(CarData.Inventory) ~= "table" then
		return false, "The car inventory is invalid."
	end

	if typeof(Data.Inventory) ~= "table" then
		return false, "The backpack inventory is invalid."
	end

	local BackpackCapacity = math.max(
		math.floor(
			tonumber(Data.Stats.BackpackCapacity)
			or StartingBackpackCapacity
		),
		0
	)

	local BackpackLoad = GetInventoryLoad(Data.Inventory)
	local RemainingSpace = math.max(
		BackpackCapacity - BackpackLoad,
		0
	)

	if RemainingSpace <= 0 then
		return false, "Your backpack is full."
	end

	local OreNames = {}

	for OreName, Quantity in CarData.Inventory do
		if typeof(OreName) == "string"
			and typeof(Quantity) == "number"
			and Quantity > 0 then

			table.insert(OreNames, OreName)
		end
	end

	if #OreNames == 0 then
		return false, "This train car is empty."
	end

	-- Keep the withdrawal order predictable.
	table.sort(OreNames, function(First, Second)
		return First:lower() < Second:lower()
	end)

	local TotalTransferred = 0

	for _, OreName in OreNames do
		if RemainingSpace <= 0 then
			break
		end

		local AvailableQuantity = math.max(
			math.floor(
				tonumber(CarData.Inventory[OreName]) or 0
			),
			0
		)

		if AvailableQuantity <= 0 then
			continue
		end

		local TransferQuantity = math.min(
			AvailableQuantity,
			RemainingSpace
		)

		if TransferQuantity <= 0 then
			continue
		end

		local RemainingInCar =
			AvailableQuantity - TransferQuantity

		if RemainingInCar <= 0 then
			CarData.Inventory[OreName] = nil
		else
			CarData.Inventory[OreName] =
				RemainingInCar
		end

		Data.Inventory[OreName] =
			(tonumber(Data.Inventory[OreName]) or 0)
			+ TransferQuantity

		TotalTransferred += TransferQuantity
		RemainingSpace -= TransferQuantity
	end

	if TotalTransferred <= 0 then
		return false, "Nothing could be withdrawn."
	end

	local CarStillHasOre =
		GetInventoryLoad(CarData.Inventory) > 0

	local Message

	if CarStillHasOre then
		Message = string.format(
			"Withdrew %d ore. Your backpack is now full.",
			TotalTransferred
		)
	else
		Message = string.format(
			"Withdrew all %d ore from the car.",
			TotalTransferred
		)
	end

	return true, {
		Transferred = TotalTransferred,
		Direction = "CarToBackpackAll",
		CarId = CarId,
		Partial = CarStillHasOre,
		Message = Message,
		Overview = TrainInventoryService.GetOverview(Player),
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

	if Direction == "CarToBackpackAll" then
		return WithdrawAllFromCar(
			Player,
			CarId
		)
	end

	if Direction ~= "BackpackToCar"
		and Direction ~= "CarToBackpack" then

		return false, "Invalid transfer direction."
	end

	if typeof(CarId) ~= "string"
		or CarId == ""
		or typeof(OreName) ~= "string"
		or OreName == ""
		or typeof(RequestedQuantity) ~= "number" then

		return false, "Invalid transfer request."
	end

	if RequestedQuantity ~= RequestedQuantity
		or RequestedQuantity == math.huge
		or RequestedQuantity == -math.huge then

		return false, "Invalid quantity."
	end

	RequestedQuantity = math.floor(RequestedQuantity)

	if RequestedQuantity <= 0 or RequestedQuantity > 10000 then
		return false, "Invalid quantity."
	end

	local OreTemplate = OreTemplates:FindFirstChild(OreName)

	if not OreTemplate
		or not OreTemplate:IsA("BasePart")
		or OreTemplate:GetAttribute("IsStone") == true then

		return false, "That ore cannot be transferred."
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
	else
		SourceInventory = CarData.Inventory
		DestinationInventory = Data.Inventory
		DestinationCapacity = Data.Stats.BackpackCapacity
	end

	if typeof(SourceInventory) ~= "table"
		or typeof(DestinationInventory) ~= "table"
		or typeof(DestinationCapacity) ~= "number" then

		return false, "Inventory data is invalid."
	end

	local AvailableQuantity = math.max(
		math.floor(tonumber(SourceInventory[OreName]) or 0),
		0
	)

	if AvailableQuantity <= 0 then
		return false, "You do not have that ore."
	end

	local DestinationLoad = GetInventoryLoad(DestinationInventory)
	local RemainingSpace = math.max(
		math.floor(DestinationCapacity) - DestinationLoad,
		0
	)

	if RemainingSpace <= 0 then
		if Direction == "CarToBackpack" then
			return false, "Your backpack is full."
		end

		return false, "The train car is full."
	end

	local TransferQuantity = math.min(
		RequestedQuantity,
		AvailableQuantity,
		RemainingSpace
	)

	if TransferQuantity <= 0 then
		return false, "Nothing could be transferred."
	end

	local NewSourceQuantity = AvailableQuantity - TransferQuantity

	if NewSourceQuantity <= 0 then
		SourceInventory[OreName] = nil
	else
		SourceInventory[OreName] = NewSourceQuantity
	end

	DestinationInventory[OreName] =
		(tonumber(DestinationInventory[OreName]) or 0)
		+ TransferQuantity

	return true, {
		Transferred = TransferQuantity,
		Direction = Direction,
		CarId = CarId,
		OreName = OreName,
		SourceRemaining = SourceInventory[OreName] or 0,
		DestinationQuantity = DestinationInventory[OreName],
		Overview = TrainInventoryService.GetOverview(Player),
	}
end
local function GetVehicleModel(Object, TrainModel)
	local Current = Object

	while Current and Current.Parent ~= TrainModel do
		Current = Current.Parent
	end

	if Current and Current:IsA("Model") then
		return Current
	end

	return nil
end

local function GetCoupledVehicleModels(DrillModel)
	local TrainModel = DrillModel and DrillModel.Parent

	if not DrillModel
		or not DrillModel:IsA("Model")
		or not TrainModel
		or not TrainModel:IsA("Model")
		or not TrainModel:IsDescendantOf(Workspace) then

		return {}
	end

	local ConnectedModels = {}
	local PendingModels = {DrillModel}
	local NextPendingIndex = 1

	ConnectedModels[DrillModel] = true

	while NextPendingIndex <= #PendingModels do
		local VehicleModel = PendingModels[NextPendingIndex]
		NextPendingIndex += 1

		for _, Object in VehicleModel:GetDescendants() do
			if not Object:IsA("BasePart")
				or Object.Name ~= "RoGaugeCoupler" then

				continue
			end

			local CoupledTo = Object:FindFirstChild("CoupledTo")

			if not CoupledTo
				or not CoupledTo:IsA("ObjectValue")
				or not CoupledTo.Value then

				continue
			end

			local OtherVehicle =
				GetVehicleModel(
					CoupledTo.Value,
					TrainModel
				)

			if OtherVehicle
				and not ConnectedModels[OtherVehicle] then

				ConnectedModels[OtherVehicle] = true
				table.insert(PendingModels, OtherVehicle)
			end
		end
	end

	return ConnectedModels
end

local function GetCoupledCarIds(DrillModel)
	local CoupledCarIds = {}

	for VehicleModel in GetCoupledVehicleModels(DrillModel) do
		local CarId = VehicleModel:GetAttribute("CarId")

		if typeof(CarId) == "string"
			and CarId ~= "" then

			CoupledCarIds[CarId] = true
		end
	end

	return CoupledCarIds
end

function TrainInventoryService.AddOreToAvailableCar(
	Player,
	OreName,
	Quantity,
	DrillModel
)
	local Data = EnsureTrainData(Player)

	if not Data then
		return false, 0, "Player data is not loaded."
	end

	if typeof(OreName) ~= "string"
		or OreName == ""
		or typeof(Quantity) ~= "number" then

		return false, 0, "Invalid ore deposit request."
	end

	if not DrillModel
		or not DrillModel:IsA("Model") then

		return false, 0, "Drill model was not provided."
	end

	if DrillModel:GetAttribute("OwnerUserId")
		~= Player.UserId then

		return false, 0, "Drill ownership is invalid."
	end

	Quantity = math.floor(Quantity)

	if Quantity <= 0 then
		return false, 0, "Invalid ore quantity."
	end

	local CoupledCarIds =
		GetCoupledCarIds(DrillModel)

	local HasCoupledCar = false

	for _ in CoupledCarIds do
		HasCoupledCar = true
		break
	end

	if not HasCoupledCar then
		return false, 0, "NoCoupledCars"
	end

	local RemainingQuantity = Quantity
	local AmountAdded = 0

	for _, CarData in Data.Train.Cars do
		if not CoupledCarIds[CarData.CarId] then
			continue
		end

		local Inventory = CarData.Inventory
		local Capacity = math.max(
			math.floor(
				tonumber(CarData.Capacity) or 0
			),
			0
		)

		local CurrentLoad =
			GetInventoryLoad(Inventory)

		local AvailableSpace =
			math.max(
				Capacity - CurrentLoad,
				0
			)

		local CarAmount =
			math.min(
				RemainingQuantity,
				AvailableSpace
			)

		if CarAmount > 0 then
			Inventory[OreName] =
				(Inventory[OreName] or 0)
				+ CarAmount

			AmountAdded += CarAmount
			RemainingQuantity -= CarAmount
		end

		if RemainingQuantity <= 0 then
			break
		end
	end

	if AmountAdded <= 0 then
		return false, 0, "CoupledCarsFull"
	end

	if typeof(Data.Stats) == "table"
		and typeof(Data.Stats.TotalOreMined)
			== "number" then

		Data.Stats.TotalOreMined += AmountAdded
	end

	if RemainingQuantity > 0 then
		return false,
			AmountAdded,
			"CoupledCarsPartiallyFull"
	end

	return true, AmountAdded
end

return TrainInventoryService

