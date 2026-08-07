local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local MiningEvent = ReplicatedStorage:WaitForChild("Mining Event")
local OreInfoEvent = ReplicatedStorage:WaitForChild("OreInfoEvent")
local DrillMiningEvent = ServerScriptService:WaitForChild("DrillMiningEvent")
local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataService"))
local PickaxeService = require(ServerScriptService:WaitForChild("PickaxeService"))
local TrainInventoryService = require(ServerScriptService:WaitForChild("TrainInventoryService"))
local DrillFilterService = require(ServerScriptService:WaitForChild("DrillFilterService"))
local StationService = require(ServerScriptService:WaitForChild("StationService"))
local TrainService = require(ServerScriptService:WaitForChild("TrainService"))
local OreTemplates = ServerStorage:WaitForChild("Ores")
local SoundsFolder = ServerStorage:WaitForChild("Sounds")
local BlockBreakSoundTemplate = SoundsFolder:WaitForChild("BlockBreakSound")
local MineFolder = Workspace:WaitForChild("MineContents")
local SpawnedTrains = Workspace:WaitForChild("SpawnedTrains")


local BlockSize = 5
local MinimumMineX = 53
local MinimumMineY = -260
local MaximumMineY = 30
local MaximumMineDepth = 5024
-- local MaximumMiningDistance = 15
local MineDepthAxis = "X"
local MineDepthDirection = 1
local MineClearBatchSize = 150 -- How many ores to clear per frame during a mine reset.

local DrillPadding = Vector3.new(0.05, 0, 0.05)

local MineResetInterval = 90 * 60 --(1h 30 minutes)
local MineResetWarningTimes = {
	[1800] = "The mine will reset in 30 minutes!",
	[1200] = "The mine will reset in 20 minutes!",
	[600] = "The mine will reset in 10 minutes!",
	[300] = "The mine will reset in 5 minutes!",
	[60] = "The mine will reset in 1 minute!",
	[30] = "The mine will reset in 30 seconds!",
	[10] = "The mine will reset in 10 seconds: Players and trains will return to their stations.",
	[5] = "5",
	[4] = "4",
	[3] = "3",
	[2] = "2",
	[1] = "1",
}

--build the ore table
local OreEntries = {}

local function BuildOreEntries()
	table.clear(OreEntries)

	for _, Template in OreTemplates:GetChildren() do
		if not Template:IsA("BasePart") then
			continue
		end

		local Health = Template:GetAttribute("Health")
		local Value = Template:GetAttribute("Value")
		local Rarity = Template:GetAttribute("Rarity")

		if typeof(Health) ~= "number"
			or typeof(Value) ~= "number"
			or typeof(Rarity) ~= "number"
			or Rarity <= 0 then

			warn(
				Template:GetFullName(),
				"must have numeric Health, Value, and positive Rarity attributes."
			)

			continue
		end

		table.insert(OreEntries, {
			Template = Template,
			MinimumDepth = tonumber(Template:GetAttribute("MinimumDepth")) or 0,
			MaximumDepth = tonumber(Template:GetAttribute("MaximumDepth")) or math.huge,
			Weight = 1 / Rarity,
		})
	end
end

BuildOreEntries()

-- The first pre-placed block establishes the mine grid origin.
local FirstBlock = MineFolder:FindFirstChildWhichIsA("BasePart", true)
assert(FirstBlock, "MineContents must contain at least one pre-placed mine block.")

local GridOrigin = FirstBlock.Position

local InitialMineTemplate = Instance.new("Folder")
InitialMineTemplate.Name = "InitialMineTemplate"

for _, Object in MineFolder:GetChildren() do
	Object:Clone().Parent = InitialMineTemplate
end

local LastMineTimes = {}
local OccupiedCells = {}
local MinedCells = {}
local MineResetInProgress = false

local NeighborDirections = {
	Vector3.new(1, 0, 0),
	Vector3.new(-1, 0, 0),
	Vector3.new(0, 1, 0),
	Vector3.new(0, -1, 0),
	Vector3.new(0, 0, 1),
	Vector3.new(0, 0, -1),
}

local MineOverlapParameters = OverlapParams.new()
MineOverlapParameters.FilterType = Enum.RaycastFilterType.Include
MineOverlapParameters.FilterDescendantsInstances = {MineFolder}

local function PositionToGrid(Position)
	local Offset = Position - GridOrigin

	return Vector3.new(
		math.round(Offset.X / BlockSize),
		math.round(Offset.Y / BlockSize),
		math.round(Offset.Z / BlockSize)
	)
end

local function GridToPosition(GridPosition)
	return GridOrigin + Vector3.new(
		GridPosition.X * BlockSize,
		GridPosition.Y * BlockSize,
		GridPosition.Z * BlockSize
	)
end

local function GridToKey(GridPosition)
	return string.format("%d,%d,%d", GridPosition.X, GridPosition.Y, GridPosition.Z)
end

local function IsInsideMineBoundary(GridPosition)
	local WorldPosition = GridToPosition(GridPosition)

	if WorldPosition.X < MinimumMineX then
		return false
	end

	if WorldPosition.Y < MinimumMineY or WorldPosition.Y > MaximumMineY then
		return false
	end

	-- The current mine progresses along positive X.
	return WorldPosition.X <= GridOrigin.X + MaximumMineDepth
end

local function RegisterExistingBlocks()
	for _, Object in MineFolder:GetDescendants() do
		if Object:IsA("BasePart") then
			local GridPosition = PositionToGrid(Object.Position)
			local GridKey = GridToKey(GridPosition)

			OccupiedCells[GridKey] = Object
			Object:SetAttribute("GridKey", GridKey)
		end
	end
end

local function ClearCellTracking()
	table.clear(OccupiedCells)
	table.clear(MinedCells)
	table.clear(LastMineTimes)
end

local function ClearMineContents()
	local Objects = MineFolder:GetChildren()

	for Index, Object in Objects do
		Object:Destroy()

		if Index % MineClearBatchSize == 0 then
			task.wait()
		end
	end
end

local function RestoreInitialMine()
	for _, Template in InitialMineTemplate:GetChildren() do
		Template:Clone().Parent = MineFolder
	end

	RegisterExistingBlocks()
end

--Teleport plaeyers to the station when the mine resets
local function TeleportPlayerToStation(Player)
	if not Player or not Player.Parent then
		return false, "Player is no longer connected."
	end

	local Character = Player.Character

	if not Character then
		return false, "Player does not currently have a character."
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	local PlayerSpawn = StationService.GetPlayerSpawn(Player)

	if not PlayerSpawn or not PlayerSpawn:IsA("BasePart") then
		return false, "The player's station does not have a valid spawn part."
	end

	if Humanoid then
		Humanoid.Sit = false
	end

	for _, Object in Character:GetDescendants() do
		if Object:IsA("BasePart") then
			Object.AssemblyLinearVelocity = Vector3.zero
			Object.AssemblyAngularVelocity = Vector3.zero
		end
	end

	Character:PivotTo(PlayerSpawn.CFrame * CFrame.new(0, 4, 0))

	return true
end
--Reset train when the mine resets
local function ResetPlayerTrain(Player)
	if not Player or not Player.Parent then
		return false, "Player is no longer connected."
	end

	local ExistingTrain = TrainService.GetPlayerTrain(Player)

	if ExistingTrain then
		return TrainService.RebuildPlayerTrain(Player)
	end

	return TrainService.SpawnPlayerTrain(Player)
end

local function ReturnPlayersAndTrainsToStations()
	local PlayersToReset = Players:GetPlayers()

	-- Move players first so nobody remains seated in a train that is rebuilt.
	for _, Player in PlayersToReset do
		local Teleported, TeleportError = TeleportPlayerToStation(Player)

		if not Teleported then
			warn(
				"[MineReset] Could not teleport",
				Player.Name,
				TeleportError
			)
		end
	end

	-- Give seat welds and character physics a moment to update.
	task.wait(0.25)

	for _, Player in PlayersToReset do
		if not Player.Parent then
			continue
		end

		local ResetSuccessfully, ResetResult = ResetPlayerTrain(Player)

		if not ResetSuccessfully then
			warn(
				"[MineReset] Could not reset train for",
				Player.Name,
				ResetResult
			)
		end

		task.wait()
	end
end


local function ResetMine()
	if MineResetInProgress then
		return false
	end

	MineResetInProgress = true
	Workspace:SetAttribute("MineResetInProgress", true)

	OreInfoEvent:FireAllClients("The mine is resetting! Returning everyone to their stations.")

	local ResetSucceeded, ResetError = xpcall(function()
		ReturnPlayersAndTrainsToStations()

		ClearMineContents()
		ClearCellTracking()
		RestoreInitialMine()
	end, debug.traceback)

	Workspace:SetAttribute("MineResetInProgress", false)
	MineResetInProgress = false

	if not ResetSucceeded then
		warn("[MineReset] Reset failed:", ResetError)

		OreInfoEvent:FireAllClients(
			"The mine reset encountered an error."
		)

		return false
	end

	OreInfoEvent:FireAllClients(
		"The mine has been restored and all trains have returned!"
	)

	return true
end

local function GetMineDepth(WorldPosition)
	local AxisOffset

	if MineDepthAxis == "Z" then
		AxisOffset = WorldPosition.Z - GridOrigin.Z
	else
		AxisOffset = WorldPosition.X - GridOrigin.X
	end

	return math.max(0, AxisOffset * MineDepthDirection)
end

local function SelectRandomOre(Depth)
	if #OreEntries == 0 then
		warn("No valid ore templates were found in ServerStorage.Ores.")
		return nil
	end

	local TotalWeight = 0

	for _, OreEntry in OreEntries do
		if Depth >= OreEntry.MinimumDepth
			and Depth < OreEntry.MaximumDepth then

			TotalWeight += OreEntry.Weight
		end
	end

	if TotalWeight <= 0 then
		warn("No ore templates are eligible at depth:", Depth)
		return nil
	end

	local Roll = math.random() * TotalWeight
	local CurrentWeight = 0

	for _, OreEntry in OreEntries do
		if Depth < OreEntry.MinimumDepth
			or Depth >= OreEntry.MaximumDepth then

			continue
		end

		CurrentWeight += OreEntry.Weight

		if Roll <= CurrentWeight then
			return OreEntry.Template
		end
	end

	return nil
end

local function CanGenerateAt(GridPosition)
	local GridKey = GridToKey(GridPosition)

	if not IsInsideMineBoundary(GridPosition) then
		return false
	end

	if MinedCells[GridKey] or OccupiedCells[GridKey] then
		return false
	end

	return true
end

local function CreateOre(GridPosition)
	if not CanGenerateAt(GridPosition) then
		return nil
	end

	local WorldPosition = GridToPosition(GridPosition)
	local Depth = GetMineDepth(WorldPosition)
	local Template = SelectRandomOre(Depth)

	if not Template then
		return nil
	end

	local Ore = Template:Clone()
	local GridKey = GridToKey(GridPosition)

	Ore.Position = WorldPosition
	Ore.Anchored = true
	Ore:SetAttribute("GridKey", GridKey)
	Ore.Parent = MineFolder
	OccupiedCells[GridKey] = Ore

	return Ore
end

local function GenerateOreAroundGridPosition(CenterGridPosition)
	for _, Direction in NeighborDirections do
		CreateOre(CenterGridPosition + Direction)
	end
end

local function IsPlayerNearOre(Player, Ore, MiningRange)
	if typeof(MiningRange) ~= "number" or MiningRange <= 0 then
		return false
	end

	local Character = Player.Character
	local HumanoidRootPart = Character and Character:FindFirstChild("HumanoidRootPart")

	if not HumanoidRootPart then
		return false
	end

	local Distance = (
		HumanoidRootPart.Position - Ore.Position
	).Magnitude

	return Distance <= MiningRange
end

local function IsDrillTouchingOre(DrillBit, Ore)
	if not DrillBit or not DrillBit:IsA("BasePart") then
		return false
	end

	if not Ore or not Ore:IsA("BasePart") then
		return false
	end

	if not DrillBit:IsDescendantOf(SpawnedTrains) then
		return false
	end

	for _, TouchingPart in Workspace:GetPartBoundsInBox(
		DrillBit.CFrame,
		DrillBit.Size + DrillPadding,
		MineOverlapParameters
	) do
		if TouchingPart == Ore then
			return true
		end
	end

	return false
end

local function IsValidDrillBit(DrillModel, DrillBit)
	if not DrillModel or not DrillModel:IsA("Model") then
		return false
	end

	if not DrillBit or not DrillBit:IsA("BasePart") then
		return false
	end

	if not DrillBit:IsDescendantOf(DrillModel) then
		return false
	end

	return DrillBit.Name == "DrillBit"
		or DrillBit.Name == "LowerDrillBit"
end

local function ValidateDrillHit(Player, Ore, Damage, DrillModel, DrillBit)
	if typeof(Damage) ~= "number" or Damage <= 0 then
		return false
	end

	if not DrillModel or not DrillModel:IsA("Model") then
		return false
	end

	if not DrillModel:IsDescendantOf(SpawnedTrains) then
		return false
	end

	if DrillModel:GetAttribute("OwnerUserId") ~= Player.UserId then
		return false
	end

	if not IsValidDrillBit(DrillModel, DrillBit) then
		return false
	end

	return IsDrillTouchingOre(DrillBit, Ore)
end

local function GetPickaxeDamage(Player, PickaxeStats)
	if typeof(PickaxeStats) ~= "table" then
		return nil
	end

	local CurrentTime = Workspace:GetServerTimeNow()
	local LastMineTime = LastMineTimes[Player] or 0

	if CurrentTime - LastMineTime < PickaxeStats.Cooldown then
		return nil
	end

	LastMineTimes[Player] = CurrentTime

	return PickaxeStats.Damage
end

local function UpdateHighestMineDepth(Player, Ore)
	if not Player or not Ore then
		return
	end

	local Depth = math.floor(GetMineDepth(Ore.Position) + 0.5)
	local CurrentDepth = PlayerDataService.GetStat(Player, "HighestMineDepth") or 0

	if Depth > CurrentDepth then
		PlayerDataService.SetStat(Player, "HighestMineDepth", Depth)
	end
end

local function AttachBlockBreakSound(Ore)
	if not BlockBreakSoundTemplate:IsA("Sound") then
		warn("ServerStorage.Sounds.BlockBreakSound must be a Sound.")
		return
	end

	local BreakSound = BlockBreakSoundTemplate:Clone()

	BreakSound.Name = "BlockBreakSound"
	BreakSound.Looped = false
	BreakSound.PlayOnRemove = true
	BreakSound:SetAttribute("SoundCategory", "SFX")
	BreakSound.Parent = Ore
end

local function DestroyMinedOre(Player, Ore)
	if not Player or not Ore or not Ore.Parent then
		return false
	end

	UpdateHighestMineDepth(Player, Ore)

	Ore:SetAttribute("BeingDestroyed", true)

	local GridPosition = PositionToGrid(Ore.Position)
	local GridKey = GridToKey(GridPosition)

	MinedCells[GridKey] = true
	OccupiedCells[GridKey] = nil

	AttachBlockBreakSound(Ore)
	Ore:Destroy()

	PlayerDataService.AddStat(Player, "BlocksMined", 1)

	local GenerationSucceeded, GenerationError = pcall(
		GenerateOreAroundGridPosition,
		GridPosition
	)

	if not GenerationSucceeded then
		warn(
			"Failed to generate ore around mined cell "
				.. GridKey
				.. ": "
				.. tostring(GenerationError)
		)
	end

	return true
end

local function MineOre(Player, Ore, DrillDamage, DrillModel, DrillBit)
	if MineResetInProgress then
		return
	end
	if not Player or not Player:IsA("Player") then
		return
	end

	if typeof(Ore) ~= "Instance" or not Ore:IsA("BasePart") then
		return
	end

	if not Ore:IsDescendantOf(MineFolder) or Ore:GetAttribute("BeingDestroyed") then
		return
	end

	local IsDrillMining = DrillModel ~= nil
	local Damage

	if IsDrillMining then
		if not ValidateDrillHit(Player, Ore, DrillDamage, DrillModel, DrillBit) then
			return
		end

		Damage = DrillDamage
	else
		local PickaxeStats, PickaxeError =
			PickaxeService.GetEquippedStats(Player)

		if not PickaxeStats then
			OreInfoEvent:FireClient(
				Player,
				PickaxeError or "Equip a pickaxe first."
			)

			return
		end

		if not IsPlayerNearOre(
			Player,
			Ore,
			PickaxeStats.Range
		) then
			return
		end

		Damage = GetPickaxeDamage(
			Player,
			PickaxeStats
		)

		if not Damage then
			return
		end
	end

	local CurrentHealth = Ore:GetAttribute("Health")

	if typeof(CurrentHealth) ~= "number" then
		warn(Ore:GetFullName(), "does not have a valid Health attribute.")
		return
	end

	CurrentHealth = math.max(CurrentHealth - Damage, 0)
	Ore:SetAttribute("Health", CurrentHealth)

	-- Both pickaxes and drills must reduce the block to zero health.
	if CurrentHealth > 0 then
		return
	end

	local OreName = Ore.Name
	local OreQuantity = 1

	-- Stone should always be destroyed and never stored.
	if Ore:GetAttribute("IsStone") then
		DestroyMinedOre(Player, Ore)
		return
	end

	-- Ores configured as Destroy on the drill are destroyed
	-- instead of being added to the train.
	local ShouldDestroyDrilledOre =
		IsDrillMining
		and DrillFilterService.ShouldDestroy(Player, OreName)

	if ShouldDestroyDrilledOre then
		DestroyMinedOre(Player, Ore)
		return
	end

	local AddedSuccessfully

	if IsDrillMining then
		AddedSuccessfully =
			TrainInventoryService.AddOreToAvailableCar(
				Player,
				OreName,
				OreQuantity,
				DrillModel
			)
	else
		AddedSuccessfully =
			PlayerDataService.AddOre(
				Player,
				OreName,
				OreQuantity
			)
	end

	if not AddedSuccessfully then
		OreInfoEvent:FireClient(
			Player,
			IsDrillMining
				and "Train is full!"
				or "INVENTORY FULL"
		)

	return
end

if not DestroyMinedOre(Player, Ore) then
	warn("Ore was added to inventory but could not be destroyed:", OreName)
	OreInfoEvent:FireClient(Player, "Ore collection error")
	return
end

OreInfoEvent:FireClient(
	Player,
	"+" .. tostring(OreQuantity) .. " " .. OreName
)
end

RegisterExistingBlocks()

task.spawn(function()
	while true do
		local ResetAt = Workspace:GetServerTimeNow() + MineResetInterval
		local SentWarnings = {}

		Workspace:SetAttribute("NextMineResetTime", ResetAt)

		while Workspace:GetServerTimeNow() < ResetAt do
			local SecondsRemaining = math.ceil(
				ResetAt - Workspace:GetServerTimeNow()
			)

			for WarningTime, Message in MineResetWarningTimes do
				if SecondsRemaining <= WarningTime and not SentWarnings[WarningTime] then
					SentWarnings[WarningTime] = true
					OreInfoEvent:FireAllClients(Message)
				end
			end
			Workspace:SetAttribute("MineResetSecondsRemaining", SecondsRemaining)

			task.wait(1)
		end

		ResetMine()
	end
end)

MiningEvent.OnServerEvent:Connect(function(Player, Ore)
	MineOre(Player, Ore)
end)

DrillMiningEvent.Event:Connect(function(Player, Ore, Damage, DrillModel, DrillBit)
	MineOre(Player, Ore, Damage, DrillModel, DrillBit)
end)

Players.PlayerRemoving:Connect(function(Player)
	LastMineTimes[Player] = nil
end)

