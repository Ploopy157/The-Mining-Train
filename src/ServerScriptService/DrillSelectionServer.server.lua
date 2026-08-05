local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataService"))
local TrainService = require(ServerScriptService:WaitForChild("TrainService"))
local DrillDefinitions = require(ReplicatedStorage:WaitForChild("DrillDefinitions"))

local TrainRemotes = ReplicatedStorage:WaitForChild("TrainRemotes")
local RefreshTrainGui = TrainRemotes:WaitForChild("RefreshTrainGui")

local TestDrillUserIds = {
	[79091366] = true,
}

local function CanUseTestDrill(Player)
	return TestDrillUserIds[Player.UserId] == true
end

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

local GetDrillSelectionData = GetOrCreateRemoteFunction("GetDrillSelectionData")
local SelectDrill = GetOrCreateRemoteFunction("SelectDrill")

local SelectionLocks = {}

local function EnsureDrillData(Data)
	if typeof(Data.Upgrades) ~= "table" then
		Data.Upgrades = {}
	end

	if typeof(Data.Train) ~= "table" then
		Data.Train = {}
	end

	local NormalizedDrillId = DrillDefinitions.NormalizeId(Data.Train.DrillId)

	if typeof(NormalizedDrillId) ~= "string"
		or NormalizedDrillId == ""
		or not DrillDefinitions.Get(NormalizedDrillId) then

		NormalizedDrillId = "NoDrill"
	end

	Data.Train.DrillId = NormalizedDrillId
end

local function GetMaximumUnlockedTier(Data)
	return math.max(
		math.floor(
			tonumber(Data.Upgrades.DrillTier) or 0
		),
		0
	)
end

local function IsDrillUnlocked(
	Player,
	Data,
	DrillId,
	Definition
)
	if DrillId == "NoDrill" then
		return true
	end

	if DrillId == "TESTDRILL" then
		return CanUseTestDrill(Player)
	end

	local DefinitionTier = tonumber(Definition.Tier) or math.huge

	return DefinitionTier <= GetMaximumUnlockedTier(Data)
end

local function BuildSelectionData(Player)
	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return {
			Success = false,
			Message = "Player data is not loaded.",
			Drills = {},
		}
	end

	EnsureDrillData(Data)

	local CurrentDrillId = Data.Train.DrillId
	local MaximumUnlockedTier = GetMaximumUnlockedTier(Data)
	local Drills = {}

	for LayoutOrder, DrillId in DrillDefinitions.Order do
		local Definition = DrillDefinitions.Get(DrillId)

		if not Definition then
			warn("Missing drill definition:", DrillId)
			continue
		end

		table.insert(Drills, {
			DrillId = DrillId,
			DisplayName = Definition.DisplayName or DrillId,
			Description = Definition.Description or "",
			Tier = tonumber(Definition.Tier) or 0,
			Damage = tonumber(Definition.Damage) or 0,
			Speed = tonumber(Definition.Speed) or 0,
			Width = tonumber(Definition.Width) or 0,
			Height = tonumber(Definition.Height) or 0,
			IsUnlocked = IsDrillUnlocked(
                Player,
                Data,
                DrillId,
                Definition
            ),
			IsSelected = DrillId == CurrentDrillId,
			LayoutOrder = LayoutOrder,
		})
	end

    if CanUseTestDrill(Player) then
        local TestDrillDefinition = DrillDefinitions.Get("TESTDRILL")

        if TestDrillDefinition then
            table.insert(Drills, {
                DrillId = "TESTDRILL",
                DisplayName = TestDrillDefinition.DisplayName
                    or "TESTDRILL",

                Description = TestDrillDefinition.Description
                    or "Developer test drill.",

                Tier = tonumber(TestDrillDefinition.Tier) or 999,
                Damage = tonumber(TestDrillDefinition.Damage) or 0,
                Speed = tonumber(TestDrillDefinition.Speed) or 0,
                Width = tonumber(TestDrillDefinition.Width) or 0,
                Height = tonumber(TestDrillDefinition.Height) or 0,

                IsUnlocked = true,
                IsSelected = CurrentDrillId == "TESTDRILL",
                LayoutOrder = #DrillDefinitions.Order + 1,
            })
        end
    end

	return {
		Success = true,
		CurrentDrillId = CurrentDrillId,
		MaximumUnlockedTier = MaximumUnlockedTier,
		Drills = Drills,
	}
end

GetDrillSelectionData.OnServerInvoke = function(Player)
	return BuildSelectionData(Player)
end

SelectDrill.OnServerInvoke = function(Player, RequestedDrillId)
	if SelectionLocks[Player] then
		return false, "Your drill is already being changed."
	end

	if typeof(RequestedDrillId) ~= "string" or RequestedDrillId == "" then
		return false, "Invalid drill selection."
	end

	RequestedDrillId = DrillDefinitions.NormalizeId(RequestedDrillId)

	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return false, "Player data is not loaded."
	end

	EnsureDrillData(Data)

	local Definition = DrillDefinitions.Get(RequestedDrillId)

	if not Definition then
		return false, "That drill does not exist."
	end

	if RequestedDrillId == "TESTDRILL"
        and not CanUseTestDrill(Player) then

        return false, "You do not have access to that drill."
    end

    if not IsDrillUnlocked(
        Player,
        Data,
        RequestedDrillId,
        Definition
    ) then

        return false, "That drill has not been unlocked."
    end

	if Data.Train.DrillId == RequestedDrillId then
		return true, {
			Message = (Definition.DisplayName or RequestedDrillId) .. " is already selected.",
			SelectionData = BuildSelectionData(Player),
		}
	end

	SelectionLocks[Player] = true

	local PreviousDrillId = Data.Train.DrillId
	Data.Train.DrillId = RequestedDrillId

	local ExistingTrain = TrainService.GetPlayerTrain(Player)

	if ExistingTrain then
		local Rebuilt, RebuildResult = TrainService.RebuildPlayerTrain(Player)

		if not Rebuilt then
			Data.Train.DrillId = PreviousDrillId
			SelectionLocks[Player] = nil

			return false, RebuildResult or "The train could not be rebuilt."
		end
	else
		RefreshTrainGui:FireClient(Player)
	end

	SelectionLocks[Player] = nil

	return true, {
		Message = (Definition.DisplayName or RequestedDrillId) .. " selected.",
		SelectionData = BuildSelectionData(Player),
	}
end