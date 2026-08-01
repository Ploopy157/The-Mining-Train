local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ItemDefinitions = require(ReplicatedStorage:WaitForChild("ItemDefinitions"))
local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataService"))
local StationService = require(ServerScriptService:WaitForChild("StationService"))

local FurnaceService = {}

--local QueueCapacity = 10
local OresPerProcess = 5
local CoalCapacity = 2000
local OutputCapacity = 2000
local SpeedPerUpgrade = 0.1

local function GetInventoryLoad(Inventory)
	local Total = 0

	for _, Quantity in Inventory do
		if typeof(Quantity) == "number" and Quantity > 0 then
			Total += Quantity
		end
	end

	return Total
end

local function EnsureData(Player)
	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return nil
	end

	if typeof(Data.Inventory) ~= "table" then
		Data.Inventory = {}
	end

	if typeof(Data.Items) ~= "table" then
		Data.Items = {}
	end

	if typeof(Data.Furnace) ~= "table" then
		Data.Furnace = {}
	end

	if typeof(Data.Furnace.Queue) ~= "table" then
		Data.Furnace.Queue = {}
	end

	if typeof(Data.Furnace.Finished) ~= "table" then
		Data.Furnace.Finished = {}
	end

	if typeof(Data.Furnace.Coal) ~= "number" then
		Data.Furnace.Coal = 0
	end

	if typeof(Data.Upgrades) ~= "table" then
		Data.Upgrades = {}
	end

	if typeof(Data.Stats) ~= "table" then
		Data.Stats = {}
	end

	if typeof(Data.Stats.BackpackCapacity) ~= "number" then
		Data.Stats.BackpackCapacity = 2
	end

	if typeof(Data.Stats.IngotsSmelted) ~= "number" then
		Data.Stats.IngotsSmelted = 0
	end

	if typeof(Data.Train) ~= "table" then
		Data.Train = {}
	end

	if typeof(Data.Train.Cars) ~= "table" then
		Data.Train.Cars = {}
	end

	Data.Furnace.Coal = math.clamp(
		math.floor(Data.Furnace.Coal),
		0,
		CoalCapacity
	)

	return Data
end

local function GetSpeedMultiplier(Data)
	local Level = math.max(
		0,
		math.floor(tonumber(Data.Upgrades.FurnaceSpeed) or 0)
	)

	return 1 + Level * SpeedPerUpgrade
end

local function FindIngotForOre(OreName)
	return ItemDefinitions.GetIngotForOre(OreName)
end

local function FindCarDataById(Data, CarId)
	for _, CarData in Data.Train.Cars do
		if CarData.CarId == CarId then
			if typeof(CarData.Inventory) ~= "table" then
				CarData.Inventory = {}
			end

			return CarData
		end
	end

	return nil
end

local function FindCarIdFromPart(Part)
	local Current = Part

	while Current and Current ~= Workspace do
		if Current:IsA("Model") then
			local CarId = Current:GetAttribute("CarId")

			if typeof(CarId) == "string" and CarId ~= "" then
				return CarId
			end
		end

		Current = Current.Parent
	end

	return nil
end

local function GetEligibleCarInventories(Player, Data)
	local Station = StationService.GetPlayerStation(Player)

	if not Station then
		return {}
	end

	local Platform = Station:FindFirstChild("Furnace_Platform", true)

	if not Platform or not Platform:IsA("BasePart") then
		return {}
	end

	local Parameters = OverlapParams.new()
	Parameters.FilterType = Enum.RaycastFilterType.Exclude
	Parameters.FilterDescendantsInstances = {Platform}

	local SeenCarIds = {}
	local Inventories = {}

	for _, TouchingPart in Workspace:GetPartsInPart(Platform, Parameters) do
		local CarId = FindCarIdFromPart(TouchingPart)

		if CarId and not SeenCarIds[CarId] then
			local CarData = FindCarDataById(Data, CarId)

			if CarData then
				SeenCarIds[CarId] = true

				table.insert(Inventories, {
					Name = CarId,
					Inventory = CarData.Inventory,
				})
			end
		end
	end

	table.sort(Inventories, function(First, Second)
		return First.Name < Second.Name
	end)

	return Inventories
end

local function BuildSourceInventories(Player, Data)
	local Sources = {
		{
			Name = "Bag",
			Inventory = Data.Inventory,
		},
	}

	for _, CarSource in GetEligibleCarInventories(Player, Data) do
		table.insert(Sources, CarSource)
	end

	return Sources
end

local function GetAvailableQuantity(Sources, ItemName)
	local Total = 0

	for _, Source in Sources do
		local Quantity = math.max(
			math.floor(tonumber(Source.Inventory[ItemName]) or 0),
			0
		)

		Total += Quantity
	end

	return Total
end

local function ConsumeQuantity(Sources, ItemName, RequestedQuantity)
	local Remaining = RequestedQuantity

	for _, Source in Sources do
		if Remaining <= 0 then
			break
		end

		local Available = math.max(
			math.floor(tonumber(Source.Inventory[ItemName]) or 0),
			0
		)

		local Consumed = math.min(Available, Remaining)

		if Consumed > 0 then
			local NewQuantity = Available - Consumed

			if NewQuantity <= 0 then
				Source.Inventory[ItemName] = nil
			else
				Source.Inventory[ItemName] = NewQuantity
			end

			Remaining -= Consumed
		end
	end

	return RequestedQuantity - Remaining
end

local function FindCoalName(Sources)
	for _, Candidate in {"Coal", "Coal Ore"} do
		if GetAvailableQuantity(Sources, Candidate) > 0 then
			return Candidate
		end
	end

	return "Coal"
end

local function GetFinishedLoad(Finished)
	return GetInventoryLoad(Finished)
end

local function StartFirstItem(Data, CurrentTime)
	local FirstItem = Data.Furnace.Queue[1]

	if not FirstItem or FirstItem.StartedAt then
		return false
	end

	local Definition = ItemDefinitions.Ingots[FirstItem.IngotName]

	if not Definition then
		table.remove(Data.Furnace.Queue, 1)
		return true
	end

	local Duration = math.max(
		1,
		math.ceil(Definition.TimeToSmelt / GetSpeedMultiplier(Data))
	)

	FirstItem.StartedAt = CurrentTime
	FirstItem.FinishesAt = CurrentTime + Duration

	return true
end

function FurnaceService.Process(Player)
	local Data = EnsureData(Player)

	if not Data then
		return false
	end

	local CurrentTime = os.time()
	local StateChanged = StartFirstItem(Data, CurrentTime)

	while true do
		local FirstItem = Data.Furnace.Queue[1]

		if not FirstItem
			or not FirstItem.FinishesAt
			or FirstItem.FinishesAt > CurrentTime then

			break
		end

		if GetFinishedLoad(Data.Furnace.Finished) >= OutputCapacity then
			break
		end

		local FinishedItem = table.remove(Data.Furnace.Queue, 1)

		Data.Furnace.Finished[FinishedItem.IngotName] =
			(Data.Furnace.Finished[FinishedItem.IngotName] or 0)
			+ 1

		Data.Stats.IngotsSmelted += 1
		StateChanged = true

		if StartFirstItem(Data, CurrentTime) then
			StateChanged = true
		end
	end

	return StateChanged
end

function FurnaceService.GetState(Player)
	local Data = EnsureData(Player)

	if not Data then
		return nil, "Player data is not loaded."
	end

	FurnaceService.Process(Player)

	local CurrentTime = os.time()
	local Sources = BuildSourceInventories(Player, Data)
	local CoalName = FindCoalName(Sources)
	local AvailableOres = {}
	local Queue = {}
	local Finished = {}

	for OreName in ItemDefinitions.Ores do
		local IngotDefinition = FindIngotForOre(OreName)

		if IngotDefinition then
			local Quantity = GetAvailableQuantity(Sources, OreName)

			if Quantity > 0 then
				table.insert(AvailableOres, {
					Name = OreName,
					Quantity = Quantity,
					Processes = math.floor(Quantity / OresPerProcess),
					CoalRequired = IngotDefinition.CoalToSmelt,
					IngotName = IngotDefinition.Name,
					IngotValue = IngotDefinition.Value,
				})
			end
		end
	end

	table.sort(AvailableOres, function(First, Second)
		return First.Name < Second.Name
	end)

	for Index, Entry in Data.Furnace.Queue do
		local Remaining = 0

		if Entry.FinishesAt then
			Remaining = math.max(Entry.FinishesAt - CurrentTime, 0)
		end

		table.insert(Queue, {
			Index = Index,
			OreName = Entry.OreName,
			IngotName = Entry.IngotName,
			OresReserved = Entry.OresReserved or OresPerProcess,
			CoalReserved = Entry.CoalReserved or 0,
			Remaining = Remaining,
			IsActive = Index == 1,
		})
	end

	for IngotName, Quantity in Data.Furnace.Finished do
		if typeof(Quantity) == "number" and Quantity > 0 then
			table.insert(Finished, {
				Name = IngotName,
				Quantity = Quantity,
				Value = ItemDefinitions.Ingots[IngotName]
					and ItemDefinitions.Ingots[IngotName].Value
					or 0,
			})
		end
	end

	table.sort(Finished, function(First, Second)
		return First.Name < Second.Name
	end)

	return {
		AvailableOres = AvailableOres,
		AvailableCoal = GetAvailableQuantity(Sources, CoalName),
		CoalName = CoalName,
		StoredCoal = Data.Furnace.Coal,
		CoalCapacity = CoalCapacity,
		EligibleCars = #Sources - 1,
		Queue = Queue,
		QueueLoad = #Data.Furnace.Queue,
		QueueCapacity = Data.Upgrades.FurnaceCapacity+1,
		OresPerProcess = OresPerProcess,
		Finished = Finished,
		OutputLoad = GetFinishedLoad(Data.Furnace.Finished),
		OutputCapacity = OutputCapacity,
	}
end

function FurnaceService.StoreCoal(Player, RequestedQuantity)
	local Data = EnsureData(Player)

	if not Data then
		return false, "Player data is not loaded."
	end

	local Sources = BuildSourceInventories(Player, Data)
	local CoalName = FindCoalName(Sources)
	local AvailableCoal = GetAvailableQuantity(Sources, CoalName)
	local RemainingCapacity = CoalCapacity - Data.Furnace.Coal

	RequestedQuantity = math.floor(tonumber(RequestedQuantity) or AvailableCoal)

	if RequestedQuantity <= 0 then
		return false, "Enter a valid coal quantity."
	end

	local TransferQuantity = math.min(
		RequestedQuantity,
		AvailableCoal,
		RemainingCapacity
	)

	if TransferQuantity <= 0 then
		if RemainingCapacity <= 0 then
			return false, "The furnace coal storage is full."
		end

		return false, "No coal is available in the bag or parked train."
	end

	local Consumed = ConsumeQuantity(
		Sources,
		CoalName,
		TransferQuantity
	)

	if Consumed <= 0 then
		return false, "Coal could not be transferred."
	end

	Data.Furnace.Coal += Consumed

	return true, {
		Transferred = Consumed,
		State = FurnaceService.GetState(Player),
	}
end

function FurnaceService.WithdrawCoal(Player, RequestedQuantity)
	local Data = EnsureData(Player)

	if not Data then
		return false, "Player data is not loaded."
	end

	RequestedQuantity = math.floor(
		tonumber(RequestedQuantity)
			or Data.Furnace.Coal
	)

	if RequestedQuantity <= 0 then
		return false, "Enter a valid coal quantity."
	end

	local BagLoad =
		GetInventoryLoad(Data.Inventory)
		+ GetInventoryLoad(Data.Items)

	local RemainingBagSpace = math.max(
		math.floor(Data.Stats.BackpackCapacity) - BagLoad,
		0
	)

	local TransferQuantity = math.min(
		RequestedQuantity,
		Data.Furnace.Coal,
		RemainingBagSpace
	)

	if TransferQuantity <= 0 then
		if Data.Furnace.Coal <= 0 then
			return false, "The furnace has no stored coal."
		end

		return false, "Your bag is full."
	end

	Data.Furnace.Coal -= TransferQuantity
	Data.Inventory.Coal =
		(Data.Inventory.Coal or 0)
		+ TransferQuantity

	return true, {
		Transferred = TransferQuantity,
		State = FurnaceService.GetState(Player),
	}
end

function FurnaceService.AddQueueProcess(Player, OreName)
	local Data = EnsureData(Player)

	if not Data then
		return false, "Player data is not loaded."
	end

	FurnaceService.Process(Player)

	if #Data.Furnace.Queue >= Data.Upgrades.FurnaceCapacity+1 then
		return false, "The furnace queue is full."
	end

	if typeof(OreName) ~= "string" or OreName == "" then
		return false, "Select a smeltable ore."
	end

	local Definition = FindIngotForOre(OreName)

	if not Definition then
		return false, "That ore cannot be smelted."
	end

	local Sources = BuildSourceInventories(Player, Data)
	local AvailableOre = GetAvailableQuantity(Sources, OreName)

	if AvailableOre < OresPerProcess then
		return false,
			"You need "
			.. OresPerProcess
			.. " "
			.. OreName
			.. " ore."
	end

	if Data.Furnace.Coal < Definition.CoalToSmelt then
		return false,
			"You need "
			.. Definition.CoalToSmelt
			.. " stored coal."
	end

	local ConsumedOre = ConsumeQuantity(
		Sources,
		OreName,
		OresPerProcess
	)

	if ConsumedOre ~= OresPerProcess then
		return false, "The ore transfer became incomplete."
	end

	Data.Furnace.Coal -= Definition.CoalToSmelt

	table.insert(Data.Furnace.Queue, {
		OreName = OreName,
		IngotName = Definition.Name,
		OresReserved = OresPerProcess,
		CoalReserved = Definition.CoalToSmelt,
	})

	StartFirstItem(Data, os.time())

	return true, {
		Added = OreName,
		State = FurnaceService.GetState(Player),
	}
end

function FurnaceService.RemoveQueueItem(Player, QueueIndex)
	local Data = EnsureData(Player)

	if not Data then
		return false, "Player data is not loaded."
	end

	FurnaceService.Process(Player)

	QueueIndex = math.floor(tonumber(QueueIndex) or 0)
	local Entry = Data.Furnace.Queue[QueueIndex]

	if not Entry then
		return false, "That queue item no longer exists."
	end

	local OresToReturn = Entry.OresReserved or OresPerProcess
	local BagLoad =
		GetInventoryLoad(Data.Inventory)
		+ GetInventoryLoad(Data.Items)

	local RemainingBagSpace = math.max(
		math.floor(Data.Stats.BackpackCapacity) - BagLoad,
		0
	)

	if RemainingBagSpace < OresToReturn then
		return false,
			"Your bag needs "
			.. OresToReturn
			.. " free spaces."
	end

	if Data.Furnace.Coal + (Entry.CoalReserved or 0) > CoalCapacity then
		return false, "The furnace coal storage is full."
	end

	table.remove(Data.Furnace.Queue, QueueIndex)

	Data.Inventory[Entry.OreName] =
		(Data.Inventory[Entry.OreName] or 0)
		+ OresToReturn

	Data.Furnace.Coal += Entry.CoalReserved or 0

	if QueueIndex == 1 then
		local NewFirst = Data.Furnace.Queue[1]

		if NewFirst then
			NewFirst.StartedAt = nil
			NewFirst.FinishesAt = nil
		end

		StartFirstItem(Data, os.time())
	end

	return true, {
		Removed = Entry.OreName,
		State = FurnaceService.GetState(Player),
	}
end

function FurnaceService.CollectAll(Player)
	local Data = EnsureData(Player)

	if not Data then
		return false, "Player data is not loaded."
	end

	FurnaceService.Process(Player)

	local BagLoad =
		GetInventoryLoad(Data.Inventory)
		+ GetInventoryLoad(Data.Items)

	local RemainingBagSpace = math.max(
		math.floor(Data.Stats.BackpackCapacity) - BagLoad,
		0
	)

	if RemainingBagSpace <= 0 then
		return false, "Your bag is full."
	end

	local Collected = 0

	for IngotName, Available in Data.Furnace.Finished do
		local Quantity = math.min(
			math.max(math.floor(tonumber(Available) or 0), 0),
			RemainingBagSpace
		)

		if Quantity > 0 then
			Data.Items[IngotName] =
				(Data.Items[IngotName] or 0)
				+ Quantity

			local Remaining = Available - Quantity

			if Remaining <= 0 then
				Data.Furnace.Finished[IngotName] = nil
			else
				Data.Furnace.Finished[IngotName] = Remaining
			end

			Collected += Quantity
			RemainingBagSpace -= Quantity
		end

		if RemainingBagSpace <= 0 then
			break
		end
	end

	if Collected <= 0 then
		return false, "There are no finished ingots that fit in your bag."
	end

	return true, {
		Collected = Collected,
		State = FurnaceService.GetState(Player),
	}
end

return FurnaceService
