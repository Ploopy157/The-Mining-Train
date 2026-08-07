local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataService"))

local Remotes = ReplicatedStorage:FindFirstChild("SettingsRemotes") or Instance.new("Folder")
Remotes.Name = "SettingsRemotes"
Remotes.Parent = ReplicatedStorage

local GetSettings = Remotes:FindFirstChild("GetSettings") or Instance.new("RemoteFunction")
GetSettings.Name = "GetSettings"
GetSettings.Parent = Remotes

local SaveSettings = Remotes:FindFirstChild("SaveSettings") or Instance.new("RemoteEvent")
SaveSettings.Name = "SaveSettings"
SaveSettings.Parent = Remotes

local GetStats = Remotes:FindFirstChild("GetStats") or Instance.new("RemoteFunction")
GetStats.Name = "GetStats"
GetStats.Parent = Remotes

local ResetData = Remotes:FindFirstChild("ResetData") or Instance.new("RemoteFunction")
ResetData.Name = "ResetData"
ResetData.Parent = Remotes

local DefaultSettings = {
	MusicVolume = 0.7,
	SfxVolume = 0.8,
}

local ResetDefaultData = {
	DataVersion = 1,
	Inventory = {},
	Items = {},
	Settings = {
		MusicVolume = 0.7,
		SfxVolume = 0.8,
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

local ResetCooldowns = {}

local function DeepCopy(Original)
	local Copy = {}

	for Key, Value in Original do
		Copy[Key] = typeof(Value) == "table" and DeepCopy(Value) or Value
	end

	return Copy
end

local function GetData(Player)
	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return nil
	end

	if typeof(Data.Settings) ~= "table" then
		Data.Settings = DeepCopy(DefaultSettings)
	end

	return Data
end

local function SanitizeVolume(Value, DefaultValue)
	Value = tonumber(Value)

	if not Value then
		return DefaultValue
	end

	return math.clamp(Value, 0, 1)
end

local function ResetPlayerData(Player)
	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return false, "Player data is not loaded."
	end

	table.clear(Data)

	for Key, Value in ResetDefaultData do
		Data[Key] = typeof(Value) == "table" and DeepCopy(Value) or Value
	end

	local Leaderstats = Player:FindFirstChild("leaderstats")
	local CashValue = Leaderstats and Leaderstats:FindFirstChild("Cash")
	local RebirthsValue = Leaderstats and Leaderstats:FindFirstChild("Rebirths")

	if CashValue then
		CashValue.Value = 0
	end

	if RebirthsValue then
		RebirthsValue.Value = 0
	end

	local Saved = PlayerDataService.SavePlayer(Player)

	if not Saved then
		return false, "The reset could not be saved. Your current session was not ended."
	end

	task.defer(function()
		Player:Kick("Your data was reset successfully. Rejoin to start over.")
	end)

	return true, "Data reset successfully."
end

GetSettings.OnServerInvoke = function(Player)
	local Data = GetData(Player)

	if not Data then
		return DeepCopy(DefaultSettings)
	end

	return {
		MusicVolume = SanitizeVolume(Data.Settings.MusicVolume, DefaultSettings.MusicVolume),
		SfxVolume = SanitizeVolume(Data.Settings.SfxVolume, DefaultSettings.SfxVolume),
	}
end

SaveSettings.OnServerEvent:Connect(function(Player, NewSettings)
	if typeof(NewSettings) ~= "table" then
		return
	end

	local Data = GetData(Player)

	if not Data then
		return
	end

	Data.Settings.MusicVolume = SanitizeVolume(NewSettings.MusicVolume, Data.Settings.MusicVolume or DefaultSettings.MusicVolume)
	Data.Settings.SfxVolume = SanitizeVolume(NewSettings.SfxVolume, Data.Settings.SfxVolume or DefaultSettings.SfxVolume)
end)

GetStats.OnServerInvoke = function(Player)
	local Data = GetData(Player)

	if not Data or typeof(Data.Stats) ~= "table" then
		return {}
	end

	return {
		BlocksMined = Data.Stats.BlocksMined or 0,
		TotalOreMined = Data.Stats.TotalOreMined or 0,
		LifetimeMoney = Data.Stats.LifetimeMoney or 0,
		IngotsSmelted = Data.Stats.IngotsSmelted or 0,
		HighestMineDepth = Data.Stats.HighestMineDepth or 0,
		TotalDistanceTraveled = Data.Stats.TotalDistanceTraveled or 0,
	}
end

ResetData.OnServerInvoke = function(Player, Confirmation)
	if Confirmation ~= "RESET" then
		return false, "Invalid confirmation."
	end

	local CurrentTime = os.clock()
	local LastResetAttempt = ResetCooldowns[Player] or 0

	if CurrentTime - LastResetAttempt < 10 then
		return false, "Please wait before trying again."
	end

	ResetCooldowns[Player] = CurrentTime
	return ResetPlayerData(Player)
end

Players.PlayerRemoving:Connect(function(Player)
	ResetCooldowns[Player] = nil
end)