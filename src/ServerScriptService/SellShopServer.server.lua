local AnalyticsService = game:GetService("AnalyticsService")
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

local ItemDefinitions = require(
	ReplicatedStorage:WaitForChild("ItemDefinitions")
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

local function GetItemValue(ItemName)
	local IngotDefinition =
		ItemDefinitions.Ingots[ItemName]

	if IngotDefinition then
		local IngotValue =
			tonumber(IngotDefinition.Value)

		if IngotValue then
			return math.max(IngotValue, 0)
		end
	end

	local Template =
		OreTemplates:FindFirstChild(ItemName)

	if not Template then
		return 0
	end

	local OreValue =
		Template:GetAttribute("Value")

	if typeof(OreValue) ~= "number" then
		return 0
	end

	return math.max(OreValue, 0)
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


local function LogItemSale(Player, ItemName, Quantity, CashEarned, EndingCash)
	if Quantity <= 0 or CashEarned <= 0 then
		return
	end

	local ItemSku = "Sell_" .. ItemName:gsub("%s+", "")

	AnalyticsService:LogEconomyEvent(
		Player,
		Enum.AnalyticsEconomyFlowType.Source,
		"Cash",
		CashEarned,
		EndingCash,
		Enum.AnalyticsEconomyTransactionType.Shop.Name,
		ItemSku
	)
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

	if typeof(Data.Items) ~= "table" then
		Data.Items = {}
	end

	EnsureStats(Data)

	local EligibleCars, CarError =
		GetEligibleCarData(Player)

	local CombinedInventory = {}
	
	local BagLoad = 0

	for _, Inventory in {
		Data.Inventory,
		Data.Items,
	} do
		for _, Quantity in Inventory do
			if typeof(Quantity) == "number"
				and Quantity > 0 then

				BagLoad += Quantity
			end
		end
	end

	-- Raw ores and collected ingots in the bag are sellable.
	AddInventoryToTotals(
		CombinedInventory,
		Data.Inventory
	)

	AddInventoryToTotals(
		CombinedInventory,
		Data.Items
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

	for ItemName, Quantity in CombinedInventory do
		local Value = GetItemValue(ItemName)
		local ItemTotalValue = Quantity * Value

		TotalQuantity += Quantity
		TotalValue += ItemTotalValue

		table.insert(Items, {
			Name = ItemName,
			Quantity = Quantity,
			Value = Value,
			TotalValue = ItemTotalValue,
			ItemType =
				ItemDefinitions.Ingots[ItemName]
				and "Ingot"
				or "Ore",
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

local function RemoveItemFromInventory(
	Inventory,
	ItemName,
	RequestedQuantity
)
	if typeof(Inventory) ~= "table" then
		warn(
			"[SellShop] Removal failed: inventory is not a table.",
			"Item:",
			ItemName,
			"InventoryType:",
			typeof(Inventory)
		)

		return 0
	end

	if typeof(ItemName) ~= "string"
		or ItemName == "" then

		warn(
			"[SellShop] Removal failed: invalid item name.",
			"Item:",
			ItemName,
			"ItemType:",
			typeof(ItemName)
		)

		return 0
	end

	local CurrentQuantity =
		tonumber(Inventory[ItemName]) or 0

	local QuantityToRemove =
		math.max(
			math.floor(
				tonumber(RequestedQuantity) or 0
			),
			0
		)

	local RemovedQuantity =
		math.min(
			math.max(CurrentQuantity, 0),
			QuantityToRemove
		)

	if RemovedQuantity <= 0 then
		return 0
	end

	local RemainingQuantity =
		CurrentQuantity - RemovedQuantity

	if RemainingQuantity <= 0 then
		Inventory[ItemName] = nil
	else
		Inventory[ItemName] =
			RemainingQuantity
	end

	return RemovedQuantity
end
local function RemoveSellableItem(
	Player,
	ItemName,
	RequestedQuantity
)
	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return 0
	end

	local RemainingToRemove =
		RequestedQuantity

	local TotalRemoved = 0

	if typeof(Data.Items) ~= "table" then
		Data.Items = {}
	end

	-- Collected ingots are removed from the bag item inventory first.
	local ItemRemoved =
		RemoveItemFromInventory(
			Data.Items,
			ItemName,
			RemainingToRemove
		)

	TotalRemoved += ItemRemoved
	RemainingToRemove -= ItemRemoved

	if RemainingToRemove <= 0 then
		return TotalRemoved
	end

	-- Then remove raw ores from the backpack.
	local BackpackRemoved =
		RemoveItemFromInventory(
			Data.Inventory,
			ItemName,
			RemainingToRemove
		)

	TotalRemoved += BackpackRemoved
	RemainingToRemove -= BackpackRemoved

	if RemainingToRemove <= 0 then
		return TotalRemoved
	end

	-- Only raw ores can exist in eligible train cars.
	local EligibleCars =
		GetEligibleCarData(Player)

	for _, EligibleCar in EligibleCars do
		if RemainingToRemove <= 0 then
			break
		end

		local RemovedFromCar =
			RemoveItemFromInventory(
				EligibleCar.Data.Inventory,
				ItemName,
				RemainingToRemove
			)

		TotalRemoved += RemovedFromCar
		RemainingToRemove -= RemovedFromCar
	end

	return TotalRemoved
end

local function CountSellableItem(
	Player,
	ItemName
)
	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return 0
	end

	if typeof(Data.Items) ~= "table" then
		Data.Items = {}
	end

	local Total =
		(Data.Items[ItemName] or 0)
		+ (Data.Inventory[ItemName] or 0)

	-- Ingot names do not exist in train inventories, but raw ores do.
	if not ItemDefinitions.Ingots[ItemName] then
		local EligibleCars =
			GetEligibleCarData(Player)

		for _, EligibleCar in EligibleCars do
			Total +=
				EligibleCar.Data.Inventory[ItemName]
				or 0
		end
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
	ItemName,
	RequestedQuantity
)
	if not IsPlayerNearShop(Player) then
		warn(
			"[SellShop] Rejected: player is not near the shop.",
			Player and Player.Name
		)

		return false, "Move closer to the shop."
	end

	if typeof(ItemName) ~= "string"
		or ItemName == "" then

		warn(
			"[SellShop] Rejected: invalid item name.",
			"Received:",
			ItemName,
			"Type:",
			typeof(ItemName)
		)

		return false, "Invalid item."
	end

	if typeof(RequestedQuantity) ~= "number" then
		warn(
			"[SellShop] Rejected: invalid quantity type.",
			"Item:",
			ItemName,
			"Received:",
			RequestedQuantity,
			"Type:",
			typeof(RequestedQuantity)
		)

		return false, "Invalid quantity."
	end

	RequestedQuantity = math.floor(RequestedQuantity)

	if RequestedQuantity <= 0
		or RequestedQuantity > 1000000 then

		warn(
			"[SellShop] Rejected: quantity out of range.",
			"Item:",
			ItemName,
			"Quantity:",
			RequestedQuantity
		)

		return false, "Invalid quantity."
	end

	local Data = PlayerDataService.GetData(Player)

	if not Data then
		warn(
			"[SellShop] Rejected: player data is not loaded.",
			Player.Name
		)

		return false, "Player data is not loaded."
	end

	if typeof(Data.Inventory) ~= "table" then
		Data.Inventory = {}
	end

	if typeof(Data.Items) ~= "table" then
		Data.Items = {}
	end

	EnsureStats(Data)

	local IngotDefinition =
		ItemDefinitions.Ingots[ItemName]

	local OreTemplate =
		OreTemplates:FindFirstChild(ItemName)

	local AvailableQuantity =
		CountSellableItem(
			Player,
			ItemName
		)

	local ItemValue =
		GetItemValue(ItemName)

	if AvailableQuantity <= 0 then
		warn(
			"[SellShop] Rejected: no available quantity.",
			"Item:",
			ItemName,
			"Data.Items:",
			Data.Items[ItemName],
			"Data.Inventory:",
			Data.Inventory[ItemName]
		)

		return false,
			"You do not have that item in your bag or connected train cars."
	end

	if ItemValue <= 0 then
		warn(
			"[SellShop] Rejected: item has no valid value.",
			"Item:",
			ItemName,
			"IngotDefinition:",
			IngotDefinition,
			"OreTemplate:",
			OreTemplate
		)

		return false, "That item cannot be sold."
	end

	local QuantityToSell =
		math.min(
			RequestedQuantity,
			AvailableQuantity
		)

	local ActualRemoved =
		RemoveSellableItem(
			Player,
			ItemName,
			QuantityToSell
		)

	if ActualRemoved <= 0 then
		warn(
			"[SellShop] Rejected: removal returned zero.",
			"Item:",
			ItemName
		)

		return false, "No eligible item could be removed."
	end

	local CashEarned =
		ActualRemoved * ItemValue

	local CashAdded =
		AddCash(
			Player,
			CashEarned
		)

	if not CashAdded then
		warn(
			"[SellShop] Warning: AddCash returned false.",
			"Player:",
			Player.Name,
			"CashEarned:",
			CashEarned
		)
	end

	Data.Stats.TotalOreSold += ActualRemoved
	Data.Stats.TotalMoneyEarned += CashEarned

	LogItemSale(
		Player,
		ItemName,
		ActualRemoved,
		CashEarned,
		Data.Stats.Cash
	)

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
		return false, "There are no sellable items in your bag or connected train cars."
	end

	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return false, "Player data is not loaded."
	end

	EnsureStats(Data)

	local TotalQuantity = 0
	local TotalCash = 0
	local SoldItems = {}

	for _, OreData in ShopData.Items do
		local RemovedQuantity = RemoveSellableItem(
			Player,
			OreData.Name,
			OreData.Quantity
		)

		if RemovedQuantity > 0 then
			local ItemCash = RemovedQuantity * OreData.Value

			TotalQuantity += RemovedQuantity
			TotalCash += ItemCash

			table.insert(SoldItems, {
				Name = OreData.Name,
				Quantity = RemovedQuantity,
				Cash = ItemCash,
			})
		end
	end

	if TotalQuantity <= 0 then
		return false, "No eligible item could be sold."
	end

	AddCash(Player, TotalCash)

	Data.Stats.TotalOreSold += TotalQuantity
	Data.Stats.TotalMoneyEarned += TotalCash

	for _, SoldItem in SoldItems do
		LogItemSale(
			Player,
			SoldItem.Name,
			SoldItem.Quantity,
			SoldItem.Cash,
			Data.Stats.Cash
		)
	end

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
	Prompt.ActionText = "Sell Items"
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

