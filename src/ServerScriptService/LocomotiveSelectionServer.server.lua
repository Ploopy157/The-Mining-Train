local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataService"))
local TrainService = require(ServerScriptService:WaitForChild("TrainService"))
local LocomotiveDefinitions = require(ReplicatedStorage:WaitForChild("LocomotiveDefinitions"))

local TrainRemotes = ReplicatedStorage:WaitForChild("TrainRemotes")
local RefreshTrainGui = TrainRemotes:WaitForChild("RefreshTrainGui")

local function GetOrCreateRemoteFunction(Name)
	local ExistingRemote = TrainRemotes:FindFirstChild(Name)

	if ExistingRemote then
		if not ExistingRemote:IsA("RemoteFunction") then
			error(Name .. " exists but is not a RemoteFunction.")
		end

		return ExistingRemote
	end

	local Remote = Instance.new("RemoteFunction")
	Remote.Name = Name
	Remote.Parent = TrainRemotes

	return Remote
end

local GetLocomotiveSelectionData = GetOrCreateRemoteFunction("GetLocomotiveSelectionData")
local SelectLocomotive = GetOrCreateRemoteFunction("SelectLocomotive")

local SelectionLocks = {}

local function EnsureLocomotiveData(Data)
	if typeof(Data.Upgrades) ~= "table" then
		Data.Upgrades = {}
	end

	if typeof(Data.Train) ~= "table" then
		Data.Train = {}
	end

	local LegacyLocomotiveIds = {
	PushCart = "MotorCart",
	StarterLocomotive = "BabyDiesel",
	IntermediateLocomotive = "MiningDiesel",
}

    local function EnsureLocomotiveData(Data)
        if typeof(Data.Upgrades) ~= "table" then
            Data.Upgrades = {}
        end

        if typeof(Data.Train) ~= "table" then
            Data.Train = {}
        end

        local LegacyReplacement = LegacyLocomotiveIds[Data.Train.LocomotiveId]

        if LegacyReplacement then
            Data.Train.LocomotiveId = LegacyReplacement
        end

        if typeof(Data.Train.LocomotiveId) ~= "string"
            or not LocomotiveDefinitions.Get(Data.Train.LocomotiveId) then

            Data.Train.LocomotiveId = LocomotiveDefinitions.Order[1]
        end
    end
end

local function GetMaximumUnlockedTier(Data)
	local UpgradeLevel = math.max(
		math.floor(tonumber(Data.Upgrades.LocomotiveTier) or 0),
		0
	)

	-- Upgrade level 0 owns definition tier 1.
	return UpgradeLevel + 1
end

local function BuildSelectionData(Player)
	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return {
			Success = false,
			Message = "Player data is not loaded.",
			Locomotives = {},
		}
	end

	EnsureLocomotiveData(Data)

	local MaximumUnlockedTier = GetMaximumUnlockedTier(Data)
	local CurrentLocomotiveId = Data.Train.LocomotiveId
	local Locomotives = {}

	for LayoutOrder, LocomotiveId in LocomotiveDefinitions.Order do
		local Definition = LocomotiveDefinitions.Get(LocomotiveId)

		if not Definition then
			warn("Missing locomotive definition:", LocomotiveId)
			continue
		end

		local Tier = tonumber(Definition.Tier) or LayoutOrder

		table.insert(Locomotives, {
			LocomotiveId = LocomotiveId,
			DisplayName = Definition.DisplayName or LocomotiveId,
			Description = Definition.Description or "",
			Tier = Tier,
			MaximumSpeed = tonumber(Definition.MaximumSpeed) or 0,
			Acceleration = tonumber(Definition.Acceleration) or 0,
			IsUnlocked = Tier <= MaximumUnlockedTier,
			IsSelected = LocomotiveId == CurrentLocomotiveId,
			LayoutOrder = LayoutOrder,
		})
	end

	return {
		Success = true,
		CurrentLocomotiveId = CurrentLocomotiveId,
		MaximumUnlockedTier = MaximumUnlockedTier,
		Locomotives = Locomotives,
	}
end

GetLocomotiveSelectionData.OnServerInvoke = function(Player)
	return BuildSelectionData(Player)
end

SelectLocomotive.OnServerInvoke = function(Player, RequestedLocomotiveId)
	if SelectionLocks[Player] then
		return false, "Your locomotive is already being changed."
	end

	if typeof(RequestedLocomotiveId) ~= "string" or RequestedLocomotiveId == "" then
		return false, "Invalid locomotive selection."
	end

	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return false, "Player data is not loaded."
	end

	EnsureLocomotiveData(Data)

	local Definition = LocomotiveDefinitions.Get(RequestedLocomotiveId)

	if not Definition then
		return false, "That locomotive does not exist."
	end

	local MaximumUnlockedTier = GetMaximumUnlockedTier(Data)
	local RequestedTier = tonumber(Definition.Tier) or math.huge

	if RequestedTier > MaximumUnlockedTier then
		return false, "That locomotive has not been unlocked."
	end

	if Data.Train.LocomotiveId == RequestedLocomotiveId then
		return true, {
			Message = (Definition.DisplayName or RequestedLocomotiveId) .. " is already selected.",
			SelectionData = BuildSelectionData(Player),
		}
	end

	SelectionLocks[Player] = true

	local PreviousLocomotiveId = Data.Train.LocomotiveId
	Data.Train.LocomotiveId = RequestedLocomotiveId

	local ExistingTrain = TrainService.GetPlayerTrain(Player)

	if ExistingTrain then
		local Rebuilt, RebuildResult = TrainService.RebuildPlayerTrain(Player)

		if not Rebuilt then
			Data.Train.LocomotiveId = PreviousLocomotiveId
			SelectionLocks[Player] = nil

			return false, RebuildResult or "The train could not be rebuilt."
		end
	else
		RefreshTrainGui:FireClient(Player)
	end

	SelectionLocks[Player] = nil

	return true, {
		Message = (Definition.DisplayName or RequestedLocomotiveId) .. " selected.",
		SelectionData = BuildSelectionData(Player),
	}
end