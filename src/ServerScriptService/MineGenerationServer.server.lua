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
local OreTemplates = ServerStorage:WaitForChild("Ores")
local SoundsFolder = ServerStorage:WaitForChild("Sounds")
local BlockBreakSoundTemplate = SoundsFolder:WaitForChild("BlockBreakSound")
local MineFolder = Workspace:WaitForChild("MineContents")
local SpawnedTrains = Workspace:WaitForChild("SpawnedTrains")


local BlockSize = 4
local MinimumMineX = 53
local MinimumMineY = -260
local MaximumMineY = 30
local MaximumMineDepth = 5024
local MaximumMiningDistance = 15
local MineDepthAxis = "X"
local MineDepthDirection = 1

-- The first pre-placed block establishes the mine grid origin.
local FirstBlock = MineFolder:FindFirstChildWhichIsA("BasePart", true)
assert(FirstBlock, "MineContents must contain at least one pre-placed mine block.")

local GridOrigin = FirstBlock.Position
local LastMineTimes = {}
local OccupiedCells = {}
local MinedCells = {}

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

local function GetMineDepth(WorldPosition)
	local AxisOffset

	if MineDepthAxis == "Z" then
		AxisOffset = WorldPosition.Z - GridOrigin.Z
	else
		AxisOffset = WorldPosition.X - GridOrigin.X
	end

	return math.max(0, AxisOffset * MineDepthDirection)
end

local function GetOreTemplates()
	local Templates = {}

	for _, Template in OreTemplates:GetChildren() do
		if Template:IsA("BasePart") then
			local Health = Template:GetAttribute("Health")
			local Value = Template:GetAttribute("Value")
			local Rarity = Template:GetAttribute("Rarity")

			if typeof(Health) == "number"
				and typeof(Value) == "number"
				and typeof(Rarity) == "number"
				and Rarity > 0 then

				table.insert(Templates, Template)
			else
				warn(
					Template:GetFullName(),
					"must have numeric Health, Value, and Rarity attributes."
				)
			end
		end
	end

	return Templates
end

local function SelectRandomOre(Depth)
	local Templates = GetOreTemplates()

	if #Templates == 0 then
		warn("No valid ore templates were found in ServerStorage.Ores.")
		return nil
	end

	local EligibleTemplates = {}

	for _, Template in Templates do
		local MinimumDepth = Template:GetAttribute("MinimumDepth")
		local MaximumDepth = Template:GetAttribute("MaximumDepth")

		if typeof(MinimumDepth) ~= "number" then
			MinimumDepth = 0
		end

		if typeof(MaximumDepth) ~= "number" then
			MaximumDepth = math.huge
		end

		if Depth >= MinimumDepth and Depth < MaximumDepth then
			table.insert(EligibleTemplates, Template)
		end
	end

	if #EligibleTemplates == 0 then
		warn("No ore templates are eligible at depth:", Depth)
		return nil
	end

	local TotalWeight = 0
	local WeightedTemplates = {}

	for _, Template in EligibleTemplates do
		local Rarity = Template:GetAttribute("Rarity")
		local Weight = 1 / Rarity

		TotalWeight += Weight

		table.insert(WeightedTemplates, {
			Template = Template,
			Weight = Weight,
		})
	end

	local Roll = math.random() * TotalWeight
	local CurrentWeight = 0

	for _, OreEntry in WeightedTemplates do
		CurrentWeight += OreEntry.Weight

		if Roll <= CurrentWeight then
			return OreEntry.Template
		end
	end

	return WeightedTemplates[#WeightedTemplates].Template
end

local function IsCellPhysicallyEmpty(GridPosition)
	local WorldPosition = GridToPosition(GridPosition)
	local CheckSize = Vector3.one * (BlockSize * 0.8)
	local Parts = Workspace:GetPartBoundsInBox(
		CFrame.new(WorldPosition),
		CheckSize,
		MineOverlapParameters
	)

	return #Parts == 0
end

local function CanGenerateAt(GridPosition)
	local GridKey = GridToKey(GridPosition)

	if not IsInsideMineBoundary(GridPosition) then
		return false
	end

	if MinedCells[GridKey] or OccupiedCells[GridKey] then
		return false
	end

	return IsCellPhysicallyEmpty(GridPosition)
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

local function IsPlayerNearOre(Player, Ore)
	local Character = Player.Character
	local HumanoidRootPart = Character and Character:FindFirstChild("HumanoidRootPart")

	if not HumanoidRootPart then
		return false
	end

	return (HumanoidRootPart.Position - Ore.Position).Magnitude <= MaximumMiningDistance
end

local function IsDrillTouchingOre(DrillBit, Ore)
	if not DrillBit or not DrillBit:IsA("BasePart") then
		return false
	end

	if not DrillBit:IsDescendantOf(SpawnedTrains) then
		return false
	end

	for _, TouchingPart in Workspace:GetPartsInPart(DrillBit, MineOverlapParameters) do
		if TouchingPart == Ore then
			return true
		end
	end

	return false
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

	if not DrillBit or not DrillBit:IsDescendantOf(DrillModel) then
		return false
	end

	return IsDrillTouchingOre(DrillBit, Ore)
end

local function GetPickaxeDamage(Player)
	local PickaxeStats, PickaxeError = PickaxeService.GetEquippedStats(Player)

	if not PickaxeStats then
		OreInfoEvent:FireClient(Player, PickaxeError or "Equip a pickaxe first")
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

local function AttachBlockBreakSound(Ore)
	if not BlockBreakSoundTemplate:IsA("Sound") then
		warn("ServerStorage.Sounds.BlockBreakSound must be a Sound.")
		return
	end

	local BreakSound = BlockBreakSoundTemplate:Clone()

	BreakSound.Name = "BlockBreakSound"
	BreakSound.Looped = false
	BreakSound.PlayOnRemove = true
	BreakSound.Parent = Ore
end

local function DestroyMinedOre(Ore)
	if not Ore or not Ore.Parent then
		return false
	end

	Ore:SetAttribute("BeingDestroyed", true)

	local GridPosition = PositionToGrid(Ore.Position)
	local GridKey = GridToKey(GridPosition)

	MinedCells[GridKey] = true
	OccupiedCells[GridKey] = nil

	AttachBlockBreakSound(Ore)
	Ore:Destroy()

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
		if not IsPlayerNearOre(Player, Ore) then
			return
		end

		Damage = GetPickaxeDamage(Player)

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
	local OreValue = Ore:GetAttribute("Value") or 0
	local OreQuantity = 1

	-- Stone is destroyed without entering inventory.
	if Ore:GetAttribute("IsStone") then
		if DestroyMinedOre(Ore) then
			PlayerDataService.AddStat(Player, "BlocksMined", 1)
		end

		return
	end

	local ShouldDestroyDrilledOre =
		IsDrillMining
		and DrillFilterService.ShouldDestroy(Player, OreName)

	if ShouldDestroyDrilledOre then
		if DestroyMinedOre(Ore) then
			PlayerDataService.AddStat(Player, "BlocksMined", 1)
		end

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

	if not DestroyMinedOre(Ore) then
		warn("Ore was added to inventory but could not be destroyed:", OreName)
		OreInfoEvent:FireClient(Player, "Ore collection error")
		return
	end

	PlayerDataService.AddStat(Player, "BlocksMined", 1)
	PlayerDataService.AddStat(Player, "TotalValueMined", OreValue)
	OreInfoEvent:FireClient(
		Player,
		"+" .. tostring(OreQuantity) .. " " .. OreName
	)
end

RegisterExistingBlocks()

MiningEvent.OnServerEvent:Connect(function(Player, Ore)
	MineOre(Player, Ore)
end)

DrillMiningEvent.Event:Connect(function(Player, Ore, Damage, DrillModel, DrillBit)
	MineOre(Player, Ore, Damage, DrillModel, DrillBit)
end)

Players.PlayerRemoving:Connect(function(Player)
	LastMineTimes[Player] = nil
end)

