local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local PlayerDataService = {}

local PlayerDataStore = DataStoreService:GetDataStore("TheMiningTrainData_V2.3") --CHANGING THIS RESETS DATA

local AutoSaveInterval = 60
local MaximumSaveAttempts = 3

local DefaultData = {
	DataVersion = 1,

	Inventory = {
		-- Raw ores carried by the player.
	},

	Items = {
		-- Finished ingots and future non-ore bag items.
	},

	Stats = {
		Cash = 0,
		Rebirths = 0,
		BackpackCapacity = 2,
		RebirthPoints = 0,

		BlocksMined = 0,
		TotalOreMined = 0,
		TotalValueMined = 0,
		IngotsSmelted = 0,
		LifetimeMoney = 0,

		HighestMineDepth = 0,
		TotalDistanceTraveled = 0,
	},

	Upgrades = {
		PickaxeDamage = 0,
		Light = 0,
		DrillSize = 0,
		DrillSpeed = 0,
		TrainSpeed = 0,
		TrainLength = 1,
		CarCapacity = 0,
		OreLuck = 0,
		FurnaceSpeed = 0,
		FurnaceCapacity = 0,
	},
	
	Train = {
		LocomotiveId = "PushCart",
		DrillId = "StarterDrill",

		Cars = {
			{
				CarId = "Car_1",
				CarType = "StarterOreCar",
				Capacity = 2,
				Inventory = {},
			},
		},
	},
}

local PlayerData = {}

local function DeepCopy(Original)
	local Copy = {}

	for Key, Value in Original do
		if typeof(Value) == "table" then
			Copy[Key] = DeepCopy(Value)
		else
			Copy[Key] = Value
		end
	end

	return Copy
end

local function ReconcileTable(Data, Template)
	for Key, DefaultValue in Template do
		if Data[Key] == nil then
			if typeof(DefaultValue) == "table" then
				Data[Key] = DeepCopy(DefaultValue)
			else
				Data[Key] = DefaultValue
			end
		elseif typeof(DefaultValue) == "table"
			and typeof(Data[Key]) == "table" then

			ReconcileTable(Data[Key], DefaultValue)
		end
	end
end

local function GetPlayerKey(Player)
	return string.format("Player_%d", Player.UserId)
end

function PlayerDataService.GetData(Player)
	return PlayerData[Player]
end

function PlayerDataService.IsLoaded(Player)
	return PlayerData[Player] ~= nil
end

local function CreateLeaderstats(Player)
	local Data = PlayerData[Player]

	if not Data then
		return
	end

	local Leaderstats = Instance.new("Folder")
	Leaderstats.Name = "leaderstats"
	Leaderstats.Parent = Player

	local Cash = Instance.new("NumberValue")
	Cash.Name = "Cash"
	Cash.Value = Data.Stats.Cash
	Cash.Parent = Leaderstats

	local Rebirths = Instance.new("IntValue")
	Rebirths.Name = "Rebirths"
	Rebirths.Value = Data.Stats.Rebirths
	Rebirths.Parent = Leaderstats
end

function PlayerDataService.LoadPlayer(Player)
	if PlayerData[Player] then
		return true
	end

	local PlayerKey = GetPlayerKey(Player)
	local LoadedData = nil

	local Success, ErrorMessage = pcall(function()
		LoadedData = PlayerDataStore:GetAsync(PlayerKey)
	end)

	if not Success then
		warn(
			"Failed to load data for",
			Player.Name,
			ErrorMessage
		)

		return false
	end

	if typeof(LoadedData) ~= "table" then
		LoadedData = DeepCopy(DefaultData)
	else
		ReconcileTable(LoadedData, DefaultData)
	end

	PlayerData[Player] = LoadedData

	print("Loaded data for", Player.Name)
	
	CreateLeaderstats(Player)
	
	return true
	
end

function PlayerDataService.SavePlayer(Player)
	local Data = PlayerData[Player]

	if not Data then
		return false
	end

	local PlayerKey = GetPlayerKey(Player)

	for Attempt = 1, MaximumSaveAttempts do
		local Success, ErrorMessage = pcall(function()
			PlayerDataStore:UpdateAsync(PlayerKey, function()
				return Data
			end)
		end)

		if Success then
			print("Saved data for", Player.Name)
			return true
		end

		warn(
			string.format(
				"Save attempt %d failed for %s: %s",
				Attempt,
				Player.Name,
				tostring(ErrorMessage)
			)
		)

		task.wait(Attempt * 2)
	end

	warn("All save attempts failed for", Player.Name)

	return false
end

function PlayerDataService.RemovePlayer(Player)
	PlayerData[Player] = nil
end

function PlayerDataService.AddOre(Player, OreName, Quantity)
	local Data = PlayerData[Player]

	if not Data then
		return false, "DataNotLoaded"
	end

	local CurrentLoad = PlayerDataService.GetBackpackLoad(Player)
	local Capacity = PlayerDataService.GetBackpackCapacity(Player)
	local AvailableSpace = Capacity - CurrentLoad

	if AvailableSpace <= 0 then
		return false, "BackpackFull"
	end

	local AmountAdded = math.min(Quantity, AvailableSpace)

	Data.Inventory[OreName] =
		(Data.Inventory[OreName] or 0)
		+ AmountAdded

	Data.Stats.TotalOreMined += AmountAdded

	return true, AmountAdded
end

function PlayerDataService.RemoveOre(Player, OreName, Quantity)
	local Data = PlayerData[Player]

	if not Data then
		return false
	end

	if typeof(OreName) ~= "string" or OreName == "" then
		return false
	end

	if typeof(Quantity) ~= "number" or Quantity <= 0 then
		return false
	end

	local CurrentQuantity = Data.Inventory[OreName] or 0

	if CurrentQuantity < Quantity then
		return false
	end

	local NewQuantity = CurrentQuantity - Quantity

	if NewQuantity <= 0 then
		Data.Inventory[OreName] = nil
	else
		Data.Inventory[OreName] = NewQuantity
	end

	return true
end

function PlayerDataService.GetOreQuantity(Player, OreName)
	local Data = PlayerData[Player]

	if not Data then
		return 0
	end

	return Data.Inventory[OreName] or 0
end

function PlayerDataService.AddCash(Player, Amount)
	local Data = PlayerData[Player]

	if not Data then
		return false
	end

	if typeof(Amount) ~= "number" then
		return false
	end

	Data.Stats.Cash += Amount

	if Amount > 0 then
		Data.Stats.LifetimeMoney = (Data.Stats.LifetimeMoney or 0) + Amount
	end

	local Leaderstats = Player:FindFirstChild("leaderstats")
	local CashValue = Leaderstats and Leaderstats:FindFirstChild("Cash")

	if CashValue then
		CashValue.Value = Data.Stats.Cash
	end

	return true
end

function PlayerDataService.AddStat(Player, StatName, Amount)
	local Data = PlayerData[Player]

	if not Data then
		return false
	end

	if typeof(StatName) ~= "string" then
		return false
	end

	if typeof(Amount) ~= "number" then
		return false
	end

	local CurrentValue = Data.Stats[StatName]

	if typeof(CurrentValue) ~= "number" then
		warn("Invalid numeric stat:", StatName)
		return false
	end

	Data.Stats[StatName] += Amount

	return true
end

function PlayerDataService.SetStat(Player, StatName, Value)
	local Data = PlayerData[Player]

	if not Data then
		return false
	end

	if Data.Stats[StatName] == nil then
		warn("Invalid stat:", StatName)
		return false
	end

	Data.Stats[StatName] = Value

	return true
end

function PlayerDataService.GetStat(Player, StatName)
	local Data = PlayerData[Player]

	if not Data then
		return nil
	end

	return Data.Stats[StatName]
end

function PlayerDataService.Start()
	Players.PlayerAdded:Connect(function(Player)
		local LoadedSuccessfully = PlayerDataService.LoadPlayer(Player)

		if not LoadedSuccessfully then
			Player:Kick(
				"Your data could not be loaded. Please rejoin to prevent data loss."
			)
		end
	end)

	Players.PlayerRemoving:Connect(function(Player)
		PlayerDataService.SavePlayer(Player)
		PlayerDataService.RemovePlayer(Player)
	end)

	for _, Player in Players:GetPlayers() do
		task.spawn(function()
			PlayerDataService.LoadPlayer(Player)
		end)
	end

	task.spawn(function()
		while true do
			task.wait(AutoSaveInterval)

			for _, Player in Players:GetPlayers() do
				task.spawn(function()
					PlayerDataService.SavePlayer(Player)
				end)
			end
		end
	end)

	game:BindToClose(function()
		local SaveThreads = 0

		for _, Player in Players:GetPlayers() do
			SaveThreads += 1

			task.spawn(function()
				PlayerDataService.SavePlayer(Player)
				SaveThreads -= 1
			end)
		end

		while SaveThreads > 0 do
			task.wait()
		end
	end)
	
	
	function PlayerDataService.SetCash(Player, Amount)
		local Data = PlayerData[Player]

		if not Data then
			return false
		end

		Data.Stats.Cash = math.max(Amount, 0)

		local Leaderstats = Player:FindFirstChild("leaderstats")
		local CashValue = Leaderstats and Leaderstats:FindFirstChild("Cash")

		if CashValue then
			CashValue.Value = Data.Stats.Cash
		end

		return true
	end
	function PlayerDataService.GetBackpackLoad(Player)
		local Data = PlayerData[Player]

		if not Data then
			return 0
		end

		if typeof(Data.Inventory) ~= "table" then
			Data.Inventory = {}
		end

		if typeof(Data.Items) ~= "table" then
			Data.Items = {}
		end

		local Total = 0

		for _, Inventory in {
			Data.Inventory,
			Data.Items,
		} do
			for _, Quantity in Inventory do
				if typeof(Quantity) == "number"
					and Quantity > 0 then

					Total += Quantity
				end
			end
		end

		return Total
	end

	function PlayerDataService.GetBackpackCapacity(Player)
		local Data = PlayerData[Player]

		if not Data then
			return 0
		end

		return Data.Stats.BackpackCapacity or 2
	end
end



return PlayerDataService
