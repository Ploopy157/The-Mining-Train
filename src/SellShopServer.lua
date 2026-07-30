local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local PlayerDataService = require(
	ServerScriptService:WaitForChild("PlayerDataService")
)

local TrainInventoryService = require(
	ServerScriptService:WaitForChild("TrainInventoryService")
)

local OreTemplates =
	ServerStorage:WaitForChild("Ores")

local StationsFolder =
	Workspace:WaitForChild("Stations")

local SpawnedTrains =
	Workspace:WaitForChild("SpawnedTrains")

local Remotes =
	ReplicatedStorage:WaitForChild("SellShopRemotes")

local GetSellShopData =
	Remotes:WaitForChild("GetSellShopData")

local SellOre =
	Remotes:WaitForChild("SellOre")

local SellAllOre =
	Remotes:WaitForChild("SellAllOre")

local OpenSellShop =
	Remotes:WaitForChild("OpenSellShop")

local RefreshSellShop =
	Remotes:WaitForChild("RefreshSellShop")

local MaximumShopDistance = 15

---------------------------------------------------------------------
-- GENERAL HELPERS
---------------------------------------------------------------------

local function GetOreValue(OreName)
	local Template = OreTemplates:FindFirstChild(OreName)

	if not Template then
		return 0
	end

	local Value = Template:GetAttribute("Value")

	if typeof(Value) ~= "number" then
		return 0
	end

	return math.max(Value, 0)
end

local function EnsureStats(Data)
	if typeof(Data.Stats) ~= "table" then
		Data.Stats = {}
	end

	if typeof(Data.Stats.Cash) ~= "number" then
		Data.Stats.Cash = 0
	end

	if typeof(Data.Stats.BackpackCapacity) ~= "number" then
		Data.Stats.BackpackCapacity = 2
	end

	if typeof(Data.Stats.TotalOreSold) ~= "number" then
		Data.Stats.TotalOreSold = 0
	end

	if typeof(Data.Stats.TotalMoneyEarned) ~= "number" then
		Data.Stats.TotalMoneyEarned = 0
	end
end

local function AddCash(Player, Amount)
	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return false
	end

	EnsureStats(Data)

	if typeof(PlayerDataService.AddCash) == "function" then
		return PlayerDataService.AddCash(Player, Amount)
	end

	Data.Stats.Cash += Amount

	local Leaderstats = Player:FindFirstChild("leaderstats")
	local CashValue =
		Leaderstats and Leaderstats:FindFirstChild("Cash")

	if CashValue then
		CashValue.Value = Data.Stats.Cash
	end

	return true
end

---------------------------------------------------------------------
-- SHOP PROXIMITY
---------------------------------------------------------------------

local function GetShopInteractionPart()
	local Shop = Workspace:FindFirstChild("OreShop")

	if not Shop then
		return nil
	end

	local InteractionPart = Shop:FindFirstChild(
		"InteractionPart",
		true
	)

	if InteractionPart
		and InteractionPart:IsA("BasePart") then

		return InteractionPart
	end

	return nil
end

local function IsPlayerNearShop(Player)
	local InteractionPart = GetShopInteractionPart()

	-- Allows testing before the final shop model is added.
	if not InteractionPart then
		return true
	end

	local Character = Player.Character
	local Root =
		Character
		and Character:FindFirstChild("HumanoidRootPart")

	if not Root then
		return false
	end

	return (
		Root.Position - InteractionPart.Position
	).Magnitude <= MaximumShopDistance
end

---------------------------------------------------------------------
-- STATION AND TRAIN DETECTION
---------------------------------------------------------------------

local function GetPlayerStation(Player)
	for _, Station in StationsFolder:GetChildren() do
		if Station:GetAttribute("OwnerUserId")
			== Player.UserId then

			return Station
		end
	end

	-- Testing fallback when Station_1 has not yet been assigned.
	local StationOne =
		StationsFolder:FindFirstChild("Station_1")

	if StationOne then
		local OwnerUserId =
			StationOne:GetAttribute("OwnerUserId") or 0

		if OwnerUserId == 0
			or OwnerUserId == Player.UserId then

			return StationOne
		end
	end

	return nil
end

local function GetStationPlatform(Player)
	local Station = GetPlayerStation(Player)

	if not Station then
		return nil
	end

	local Platform = Station:FindFirstChild(
		"Platform",
		true
	)

	if Platform and Platform:IsA("BasePart") then
		return Platform
	end

	return nil
end

local function GetPlayerTrain(Player)
	return SpawnedTrains:FindFirstChild(
		"PlayerTrain_" .. Player.UserId
	)
end

local function FindCarModelFromPart(
	Player,
	TouchedPart
)
	local PlayerTrain = GetPlayerTrain(Player)

	if not PlayerTrain then
		return nil
	end

	local Current = TouchedPart

	while Current and Current ~= Workspace do
		if Current:IsA("Model")
			and Current:IsDescendantOf(PlayerTrain)
			and typeof(Current:GetAttribute("CarId"))
				== "string"
			and Current:GetAttribute("OwnerUserId")
				== Player.UserId then

			return Current
		end

		Current = Current.Parent
	end

	return nil
end

local function GetCarsTouchingStation(Player)
	local Platform = GetStationPlatform(Player)

	if not Platform then
		return {}, "Your station platform was not found."
	end

	local TouchingParts = Platform:GetTouchingParts()
	local CarsById = {}

	for _, TouchedPart in TouchingParts do
		local CarModel =
			FindCarModelFromPart(
				Player,
				TouchedPart
			)

		if CarModel then
			local CarId =
				CarModel:GetAttribute("CarId")

			CarsById[CarId] = CarModel
		end
	end

	return CarsById, nil
end

local function GetEligibleCarData(Player)
	local CarsById, ErrorMessage =
		GetCarsTouchingStation(Player)

	if ErrorMessage then
		return {}, ErrorMessage
	end

	local EligibleCars = {}

	for CarId in CarsById do
		local CarData, CarIndex =
			TrainInventoryService.FindCarData(
				Player,
				CarId
			)

		if CarData then
			table.insert(EligibleCars, {
				CarId = CarId,
				Index = CarIndex,
				Data = CarData,
			})
		end
	end

	table.sort(EligibleCars, function(First, Second)
		return First.Index < Second.Index
	end)

	return EligibleCars, nil
end

---------------------------------------------------------------------
-- INVENTORY AGGREGATION
---------------------------------------------------------------------

local function AddInventoryToTotals(
	Totals,
	Inventory
)
	for OreName, Quantity in Inventory do
		if typeof(OreName) == "string"
			and typeof(Quantity) == "number"
			and Quantity > 0 then

			Totals[OreName] =
				(Totals[OreName] or 0)
				+ Quantity
		end
	end
end

local function BuildShopData(Player)
	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return {
			Items = {},
			BagQuantity = 0,
			TotalQuantity = 0,
			TotalValue = 0,
			Capacity = 0,
			EligibleCars = 0,
			TrainLoad = 0,
			Message = "Player data is not loaded.",
		}
	end

	if typeof(Data.Inventory) ~= "table" then
		Data.Inventory = {}
	end

	EnsureStats(Data)

	local EligibleCars, CarError =
		GetEligibleCarData(Player)

	local CombinedInventory = {}
	
	local BagLoad = 0

	for _, Quantity in Data.Inventory do
		if typeof(Quantity) == "number"
			and Quantity > 0 then

			BagLoad += Quantity
		end
	end

	-- Backpack ore remains sellable.
	AddInventoryToTotals(
		CombinedInventory,
		Data.Inventory
	)

	local TrainLoad = 0

	for _, EligibleCar in EligibleCars do
		local CarInventory =
			EligibleCar.Data.Inventory

		if typeof(CarInventory) ~= "table" then
			CarInventory = {}
			EligibleCar.Data.Inventory = CarInventory
		end

		AddInventoryToTotals(
			CombinedInventory,
			CarInventory
		)

		for _, Quantity in CarInventory do
			if typeof(Quantity) == "number"
				and Quantity > 0 then

				TrainLoad += Quantity
			end
		end
	end

	local Items = {}
	local TotalQuantity = 0
	local TotalValue = 0

	for OreName, Quantity in CombinedInventory do
		local Value = GetOreValue(OreName)
		local OreTotalValue = Quantity * Value

		TotalQuantity += Quantity
		TotalValue += OreTotalValue

		table.insert(Items, {
			Name = OreName,
			Quantity = Quantity,
			Value = Value,
			TotalValue = OreTotalValue,
		})
	end

	table.sort(Items, function(First, Second)
		return First.Name:lower()
			< Second.Name:lower()
	end)

	local Message

	if CarError then
		Message = CarError
	elseif #EligibleCars == 0 then
		Message =
			"No train cars are touching your station platform."
	else
		Message = string.format(
			"%d train car%s connected to the shop.",
			#EligibleCars,
			#EligibleCars == 1 and "" or "s"
		)
	end

	return {
		Items = Items,
		TotalQuantity = TotalQuantity,
		TotalValue = TotalValue,

		Capacity = Data.Stats.BackpackCapacity,

		BagLoad = BagLoad,
		TrainLoad = TrainLoad,
		TrainIsParked = #EligibleCars > 0,

		Cash = Data.Stats.Cash,
		EligibleCars = #EligibleCars,
		Message = Message,
	}
end

---------------------------------------------------------------------
-- ORE REMOVAL
---------------------------------------------------------------------

local function RemoveOreFromInventory(
	Inventory,
	OreName,
	RequestedQuantity
)
	local CurrentQuantity =
		Inventory[OreName] or 0

	local RemovedQuantity = math.min(
		CurrentQuantity,
		RequestedQuantity
	)

	if RemovedQuantity <= 0 then
		return 0
	end

	local RemainingQuantity =
		CurrentQuantity - RemovedQuantity

	if RemainingQuantity <= 0 then
		Inventory[OreName] = nil
	else
		Inventory[OreName] =
			RemainingQuantity
	end

	return RemovedQuantity
end

local function RemoveSellableOre(
	Player,
	OreName,
	RequestedQuantity
)
	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return 0
	end

	local RemainingToRemove =
		RequestedQuantity

	local TotalRemoved = 0

	-- Remove from backpack first.
	local BackpackRemoved =
		RemoveOreFromInventory(
			Data.Inventory,
			OreName,
			RemainingToRemove
		)

	TotalRemoved += BackpackRemoved
	RemainingToRemove -= BackpackRemoved

	if RemainingToRemove <= 0 then
		return TotalRemoved
	end

	-- Then remove from eligible cars in train order.
	local EligibleCars =
		GetEligibleCarData(Player)

	for _, EligibleCar in EligibleCars do
		if RemainingToRemove <= 0 then
			break
		end

		local RemovedFromCar =
			RemoveOreFromInventory(
				EligibleCar.Data.Inventory,
				OreName,
				RemainingToRemove
			)

		TotalRemoved += RemovedFromCar
		RemainingToRemove -= RemovedFromCar
	end

	return TotalRemoved
end

local function CountSellableOre(
	Player,
	OreName
)
	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return 0
	end

	local Total =
		Data.Inventory[OreName] or 0

	local EligibleCars =
		GetEligibleCarData(Player)

	for _, EligibleCar in EligibleCars do
		Total +=
			EligibleCar.Data.Inventory[OreName]
			or 0
	end

	return Total
end

---------------------------------------------------------------------
-- REMOTE FUNCTIONS
---------------------------------------------------------------------

GetSellShopData.OnServerInvoke = function(Player)
	return BuildShopData(Player)
end

SellOre.OnServerInvoke = function(
	Player,
	OreName,
	RequestedQuantity
)
	if not IsPlayerNearShop(Player) then
		return false, "Move closer to the shop."
	end

	if typeof(OreName) ~= "string"
		or OreName == "" then

		return false, "Invalid ore."
	end

	if typeof(RequestedQuantity) ~= "number" then
		return false, "Invalid quantity."
	end

	RequestedQuantity =
		math.floor(RequestedQuantity)

	if RequestedQuantity <= 0
		or RequestedQuantity > 1000000 then

		return false, "Invalid quantity."
	end

	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return false, "Player data is not loaded."
	end

	EnsureStats(Data)

	local AvailableQuantity =
		CountSellableOre(Player, OreName)

	if AvailableQuantity <= 0 then
		return false, "You do not have that ore in your bag or connected train cars."
	end

	local OreValue = GetOreValue(OreName)

	if OreValue <= 0 then
		return false, "That ore cannot be sold."
	end

	local QuantityToSell = math.min(
		RequestedQuantity,
		AvailableQuantity
	)

	local ActualRemoved =
		RemoveSellableOre(
			Player,
			OreName,
			QuantityToSell
		)

	if ActualRemoved <= 0 then
		return false, "No eligible ore could be removed."
	end

	local CashEarned =
		ActualRemoved * OreValue

	AddCash(Player, CashEarned)

	Data.Stats.TotalOreSold += ActualRemoved
	Data.Stats.TotalMoneyEarned += CashEarned

	RefreshSellShop:FireClient(Player)

	return true, {
		Quantity = ActualRemoved,
		CashEarned = CashEarned,
		NewCash = Data.Stats.Cash,
	}
end

SellAllOre.OnServerInvoke = function(Player)
	if not IsPlayerNearShop(Player) then
		return false, "Move closer to the shop."
	end

	local ShopData = BuildShopData(Player)

	if #ShopData.Items == 0 then
		return false, "There are no sellable ores in your bag or connected train cars."
	end

	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return false, "Player data is not loaded."
	end

	EnsureStats(Data)

	local TotalQuantity = 0
	local TotalCash = 0

	for _, OreData in ShopData.Items do
		local RemovedQuantity =
			RemoveSellableOre(
				Player,
				OreData.Name,
				OreData.Quantity
			)

		if RemovedQuantity > 0 then
			TotalQuantity += RemovedQuantity
			TotalCash +=
				RemovedQuantity
				* OreData.Value
		end
	end

	if TotalQuantity <= 0 then
		return false, "No eligible ore could be sold."
	end

	AddCash(Player, TotalCash)

	Data.Stats.TotalOreSold += TotalQuantity
	Data.Stats.TotalMoneyEarned += TotalCash

	RefreshSellShop:FireClient(Player)

	return true, {
		Quantity = TotalQuantity,
		CashEarned = TotalCash,
		NewCash = Data.Stats.Cash,
	}
end

---------------------------------------------------------------------
-- SHOP PROMPT
---------------------------------------------------------------------

local function ConfigureShopPrompt()
	local InteractionPart =
		GetShopInteractionPart()

	if not InteractionPart then
		warn(
			"Workspace.OreShop.InteractionPart was not found."
		)

		return
	end

	local ExistingPrompt =
		InteractionPart:FindFirstChild(
			"SellOrePrompt"
		)

	if ExistingPrompt then
		ExistingPrompt:Destroy()
	end

	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Name = "SellOrePrompt"
	Prompt.ActionText = "Sell Ores"
	Prompt.ObjectText = "Ore Shop"
	Prompt.HoldDuration = 0
	Prompt.MaxActivationDistance =
		MaximumShopDistance

	Prompt.RequiresLineOfSight = false
	Prompt.KeyboardKeyCode = Enum.KeyCode.E
	Prompt.Parent = InteractionPart

	Prompt.Triggered:Connect(function(Player)
		if not IsPlayerNearShop(Player) then
			return
		end

		OpenSellShop:FireClient(Player)
	end)
end

ConfigureShopPrompt()

Workspace.ChildAdded:Connect(function(Child)
	if Child.Name == "OreShop" then
		task.wait()
		ConfigureShopPrompt()
	end
end)
