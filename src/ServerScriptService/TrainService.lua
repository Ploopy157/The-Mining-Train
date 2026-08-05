local CarGap = 1
local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local ServerScriptService =
	game:GetService("ServerScriptService")

local ServerStorage =
	game:GetService("ServerStorage")

local Workspace =
	game:GetService("Workspace")


local PlayerDataService = require(
	ServerScriptService:WaitForChild(
		"PlayerDataService"
	)
)

local TrainInventoryService = require(
	ServerScriptService:WaitForChild(
		"TrainInventoryService"
	)
)

local StationService = require(
	ServerScriptService:WaitForChild(
		"StationService"
	)
)

local UpgradeDefinitions = require(
	ReplicatedStorage:WaitForChild(
		"UpgradeDefinitions"
	)
)

local LocomotiveDefinitions = require(
	ReplicatedStorage:WaitForChild(
		"LocomotiveDefinitions"
	)
)

local TrainTemplates =
	ServerStorage:WaitForChild(
		"TrainTemplates"
	)

local LocomotiveTemplates =
	TrainTemplates:WaitForChild(
		"Locomotives"
	)

local CarTemplates =
	TrainTemplates:WaitForChild(
		"Cars"
	)

local SpawnedTrains =
	Workspace:FindFirstChild(
		"SpawnedTrains"
	)

local CarCargoVisualService = require(
	ServerScriptService:WaitForChild(
		"CarCargoVisualService"
	)
)
local DrillService = require(
	ServerScriptService:WaitForChild(
		"DrillService"
	)
)

local TrainRemotes =
	ReplicatedStorage:WaitForChild(
		"TrainRemotes"
	)

local OpenCarMenu =
	TrainRemotes:WaitForChild(
		"OpenCarMenu"
	)

local RefreshTrainGui =
	TrainRemotes:WaitForChild(
		"RefreshTrainGui"
	)

if SpawnedTrains
	and not SpawnedTrains:IsA("Folder") then

	error(
		"Workspace.SpawnedTrains exists but is not a Folder."
	)
end

if not SpawnedTrains then
	SpawnedTrains = Instance.new("Folder")
	SpawnedTrains.Name = "SpawnedTrains"
	SpawnedTrains.Parent = Workspace
end

local TrainService = {}

local RebuildLocks = {}

---------------------------------------------------------------------
-- GENERAL HELPERS
---------------------------------------------------------------------

function TrainService.GetTrainName(Player)
	return "PlayerTrain_" .. Player.UserId
end

function TrainService.GetPlayerTrain(Player)
	return SpawnedTrains:FindFirstChild(
		TrainService.GetTrainName(Player)
	)
end

function TrainService.GetLocomotive(
	TrainModel
)
	if not TrainModel then
		return nil
	end

	local Locomotive =
		TrainModel:FindFirstChild(
			"Locomotive"
		)

	if Locomotive
		and Locomotive:IsA("Model") then

		return Locomotive
	end

	for _, Child in TrainModel:GetChildren() do
		if Child:IsA("Model")
			and not Child:GetAttribute(
				"CarId"
			) then

			return Child
		end
	end

	return nil
end

function TrainService.StopTrainPhysics(
	TrainModel
)
	if not TrainModel then
		return
	end

	for _, Object in TrainModel:GetDescendants() do
		if Object:IsA("BasePart") then
			Object.AssemblyLinearVelocity =
				Vector3.zero

			Object.AssemblyAngularVelocity =
				Vector3.zero
		end
	end
end

function TrainService.DestroyPlayerTrain(
	Player
)
	local TrainModel =
		TrainService.GetPlayerTrain(Player)

	if TrainModel then
		TrainModel:Destroy()
	end
end

local function ClearGeneratedCargoVisuals(
	CarModel
)
	local VisualFolder =
		CarModel:FindFirstChild(
			"CargoGridVisuals"
		)

	if VisualFolder then
		VisualFolder:Destroy()
	end
end

---------------------------------------------------------------------
-- MODEL POSITIONING
---------------------------------------------------------------------

local function ValidateTemplate(
	Template,
	TemplateDescription
)
	if not Template then
		return false,
			TemplateDescription
			.. " was not found."
	end

	if not Template:IsA("Model") then
		return false,
			TemplateDescription
			.. " must be a Model."
	end

	if not Template.PrimaryPart then
		return false,
			TemplateDescription
			.. " does not have a PrimaryPart."
	end

	return true
end

local function PivotModelByPrimaryPart(
	Model,
	TargetPrimaryPartCFrame
)
	if not Model.PrimaryPart then
		return false,
			Model.Name
			.. " does not have a PrimaryPart."
	end

	-- This offset converts a desired PrimaryPart CFrame into the
	-- Model pivot CFrame expected by Model:PivotTo().
	local PrimaryToPivot =
		Model.PrimaryPart.CFrame:ToObjectSpace(
			Model:GetPivot()
		)

	Model:PivotTo(
		TargetPrimaryPartCFrame
			* PrimaryToPivot
	)

	return true
end

local function GetTrainLength(
	Model
)
	local AttributeLength =
		Model:GetAttribute("TrainLength")

	if typeof(AttributeLength) == "number"
		and AttributeLength > 0 then

		return AttributeLength
	end

	local Size =
		Model:GetExtentsSize()

	return math.max(
		Size.Z,
		0.1
	)
end

local function GetCarDirection(
	SpawnOrigin
)
	local Direction =
		SpawnOrigin:GetAttribute(
			"CarDirection"
		)

	if typeof(Direction) ~= "number"
		or Direction == 0 then

		return 1
	end

	return Direction >= 0
		and 1
		or -1
end

local function GetCarGap(
	SpawnOrigin
)
	local Gap = CarGap
	-- 	SpawnOrigin:GetAttribute(
	-- 		"CarGap"
	-- 	)

	-- if typeof(Gap) ~= "number" then
	-- 	return 0.25
	-- end

	return math.max(Gap, 0)
end

---------------------------------------------------------------------
-- DATA PREPARATION
---------------------------------------------------------------------

function TrainService.GetCarCapacity(
	Data
)
	if typeof(Data.Upgrades) ~= "table" then
		Data.Upgrades = {}
	end

	local Level =
		tonumber(
			Data.Upgrades.CarCapacity
		) or 0

	local Capacity =
		UpgradeDefinitions.GetValue(
			"CarCapacity",
			Level
		)

	if typeof(Capacity) ~= "number" then
		Capacity = 2
	end

	return math.max(
		1,
		math.floor(Capacity)
	)
end

local function PrepareTrainData(
	Player,
	Data
)
	-- This ensures the starter locomotive and two starter cars exist.
	local EnsuredData =
		TrainInventoryService
		.EnsureTrainData(Player)

	if EnsuredData then
		Data = EnsuredData
	end

	if typeof(Data.Train) ~= "table" then
		Data.Train = {}
	end

	if typeof(Data.Train.Cars)
		~= "table" then

		Data.Train.Cars = {}
	end

	--Remove old loco names in ~4 months (December)
	if typeof(Data.Train.LocomotiveId) ~= "string"
		or Data.Train.LocomotiveId == "PushCart"
		or not LocomotiveDefinitions.Get(Data.Train.LocomotiveId) then

		Data.Train.LocomotiveId = "MotorCart"
	end

	if Data.Train.LocomotiveId == "StarterLocomotive" then
		Data.Train.LocomotiveId = "BabyDiesel"
	end
	if Data.Train.LocomotiveId == "IntermediateLocomotive" then
		Data.Train.LocomotiveId = "MiningDiesel"
	end

	local EffectiveCapacity =
		TrainService.GetCarCapacity(
			Data
		)

	for Index, CarData in Data.Train.Cars do
		if typeof(CarData.CarId)
			~= "string" then

			CarData.CarId =
				"Car_" .. Index
		end

		if typeof(CarData.CarType)
			~= "string" then

			CarData.CarType =
				"StarterOreCar"
		end

		if typeof(CarData.Inventory)
			~= "table" then

			CarData.Inventory = {}
		end

		-- UpgradeDefinitions is authoritative.
		CarData.Capacity =
			EffectiveCapacity
	end

	return Data, EffectiveCapacity
end

---------------------------------------------------------------------
-- LOCOMOTIVE CREATION
---------------------------------------------------------------------

local function CreateLocomotive(
	Player,
	Data
)
	local LocomotiveId =
		Data.Train.LocomotiveId

	local Definition =
		LocomotiveDefinitions.Get(
			LocomotiveId
		)

	if not Definition then
		return nil,
			"Locomotive definition "
			.. tostring(LocomotiveId)
			.. " was not found."
	end

	local TemplateName =
		Definition.TemplateName
		or LocomotiveId

	local Template =
		LocomotiveTemplates:FindFirstChild(
			TemplateName
		)

	local Valid, ErrorMessage =
		ValidateTemplate(
			Template,
			"Locomotive template "
			.. TemplateName
		)

	if not Valid then
		return nil, ErrorMessage
	end

	local Locomotive =
		Template:Clone()

	Locomotive.Name = "Locomotive"

	Locomotive:SetAttribute(
		"OwnerUserId",
		Player.UserId
	)

	Locomotive:SetAttribute(
		"LocomotiveId",
		LocomotiveId
	)


	Locomotive:SetAttribute(
		"MaximumSpeed",
		Definition.MaximumSpeed or 7
	)

	Locomotive:SetAttribute(
		"Acceleration",
		Definition.Acceleration or 3
	)

	return Locomotive
end

---------------------------------------------------------------------
-- CAR CREATION
---------------------------------------------------------------------

local function ConfigureCarInteraction(
	Player,
	CarModel,
	CarData
)
	local InteractionPart =
		CarModel:FindFirstChild(
			"InteractionPart",
			true
		)

	if not InteractionPart
		or not InteractionPart:IsA("BasePart") then

		warn(
			"Car template",
			CarModel.Name,
			"does not contain an InteractionPart."
		)

		return
	end

	local ExistingPrompt =
		InteractionPart:FindFirstChild(
			"ManageInventoryPrompt"
		)

	if ExistingPrompt then
		ExistingPrompt:Destroy()
	end

	local Prompt =
		Instance.new("ProximityPrompt")

	Prompt.Name =
		"ManageInventoryPrompt"

	Prompt.ActionText =
		"Manage Inventory"

	Prompt.ObjectText =
		"Ore Car"

	Prompt.KeyboardKeyCode =
		Enum.KeyCode.E

	Prompt.GamepadKeyCode =
		Enum.KeyCode.ButtonX

	Prompt.HoldDuration = 0
	Prompt.MaxActivationDistance = 8
	Prompt.RequiresLineOfSight = false
	Prompt.Exclusivity =
		Enum.ProximityPromptExclusivity.OnePerButton
	--Prompt.UIOffset = Vector2.new(0, 75)

	Prompt.Parent =
		InteractionPart

	Prompt.Triggered:Connect(
		function(TriggeredPlayer)
			if TriggeredPlayer ~= Player then
				return
			end

			if CarModel:GetAttribute(
				"OwnerUserId"
				) ~= Player.UserId then

				return
			end

			if not CarModel:IsDescendantOf(
				SpawnedTrains
				) then

				return
			end

			OpenCarMenu:FireClient(
				Player,
				CarData.CarId
			)
		end
	)
end

local SlotsPerCarModelTier = 6
local MaximumCarModelTier = 5

local function GetCarModelTier(
	Capacity
)
	Capacity =
		math.max(
			1,
			math.floor(
				tonumber(Capacity) or 1
			)
		)

	return math.clamp(
		math.floor(
			(Capacity - 1)
				/ SlotsPerCarModelTier
		) + 1,
		1,
		MaximumCarModelTier
	)
end

local function GetCarTemplateName(
	CarData,
	EffectiveCapacity
)
	local BaseCarType =
		CarData.CarType
		or "StarterOreCar"

	local ModelTier =
		GetCarModelTier(
			EffectiveCapacity
		)

	return string.format(
		"%s_Tier%d",
		BaseCarType,
		ModelTier
	), ModelTier
end

local function CreateCar(
	Player,
	CarData,
	Index,
	EffectiveCapacity
)
	local TemplateName,
		ModelTier =
		GetCarTemplateName(
			CarData,
			EffectiveCapacity
		)

	local Template =
		CarTemplates:FindFirstChild(
			TemplateName
		)

	-- Allows the original StarterOreCar to remain a fallback
	-- while the tiered templates are being constructed.
	if not Template then
		warn(
			"Car template",
			TemplateName,
			"was not found; using",
			CarData.CarType,
			"instead."
		)

		Template =
			CarTemplates:FindFirstChild(
				CarData.CarType
			)
	end

	local Valid, ErrorMessage =
		ValidateTemplate(
			Template,
			"Car template "
			.. tostring(
				TemplateName
			)
		)

	if not Valid then
		return nil, ErrorMessage
	end

	local CarModel =
		Template:Clone()

	CarModel.Name =
		CarData.CarId

	CarModel:SetAttribute(
		"OwnerUserId",
		Player.UserId
	)

	CarModel:SetAttribute(
		"CarId",
		CarData.CarId
	)

	CarModel:SetAttribute(
		"CarType",
		CarData.CarType
	)

	CarModel:SetAttribute(
		"TrainIndex",
		Index
	)

	CarModel:SetAttribute(
		"CarModelTier",
		ModelTier
	)

	CarModel:SetAttribute(
		"CarTemplateName",
		TemplateName
	)

	ClearGeneratedCargoVisuals(
		CarModel
	)


	ConfigureCarInteraction(
		Player,
		CarModel,
		CarData
	)

	return CarModel
end

---------------------------------------------------------------------
-- COMPLETE TRAIN BUILDER
---------------------------------------------------------------------

local function BuildPlayerTrain(
	Player,
	Data,
	TrainSpawnOrigin,
	DrillSpawnOrigin
)
	local PreparedData, EffectiveCapacity =
		PrepareTrainData(
			Player,
			Data
		)

	local TrainModel = Instance.new("Model")

	TrainModel.Name =
		TrainService.GetTrainName(
			Player
		)

	TrainModel:SetAttribute(
		"OwnerUserId",
		Player.UserId
	)

	local Locomotive, LocomotiveError =
		CreateLocomotive(
			Player,
			PreparedData
		)

	if not Locomotive then
		TrainModel:Destroy()

		return nil,
			LocomotiveError
	end

	local Direction =
		GetCarDirection(
			TrainSpawnOrigin
		)

	local CarGap =
		GetCarGap(
			TrainSpawnOrigin
		)

	local TotalOffset = 0
	local PreviousLength = nil

	-----------------------------------------------------------------
	-- ORE CARS: BEGIN AT THE BACK OF THE TRAIN
	-----------------------------------------------------------------

	for Index, CarData in PreparedData.Train.Cars do
		local CarModel, CarError =
			CreateCar(
				Player,
				CarData,
				Index,
				EffectiveCapacity
			)

		if not CarModel then
			TrainModel:Destroy()

			return nil,
				CarError
		end

		CarModel.Parent = TrainModel

		local CarLength =
			GetTrainLength(
				CarModel
			)

		-- The first car sits directly at TrainSpawnOrigin.
		if PreviousLength then
			TotalOffset +=
				PreviousLength / 2
				+ CarGap
				+ CarLength / 2
		end

		local CarPrimaryCFrame =
			TrainSpawnOrigin.CFrame
			* CFrame.new(
				0,
				0,
				TotalOffset * Direction
			)

		local CarPositioned, CarPositionError =
			PivotModelByPrimaryPart(
				CarModel,
				CarPrimaryCFrame
			)

		if not CarPositioned then
			TrainModel:Destroy()

			return nil,
				CarPositionError
		end

		PreviousLength =
			CarLength
	end

-----------------------------------------------------------------
-- LOCOMOTIVE: ALWAYS IN FRONT OF THE ORE CARS
-----------------------------------------------------------------

	local LocomotiveId = PreparedData.Train.LocomotiveId
	local LocomotiveLength = GetTrainLength(Locomotive)

	if PreviousLength then
		TotalOffset +=
			PreviousLength / 2
			+ CarGap
			+ LocomotiveLength / 2
	end

	local LocomotiveOffset = TotalOffset

	Locomotive.Parent = TrainModel

	local LocomotivePrimaryCFrame =
		TrainSpawnOrigin.CFrame
		* CFrame.new(
			0,
			0,
			LocomotiveOffset * Direction
		)

	local LocomotivePositioned, LocomotivePositionError =
		PivotModelByPrimaryPart(
			Locomotive,
			LocomotivePrimaryCFrame
		)

	if not LocomotivePositioned then
		TrainModel:Destroy()

		return nil,
			LocomotivePositionError
	end

	PreviousLength =
		LocomotiveLength

	-----------------------------------------------------------------
	-- DRILL: OPTIONAL
	-----------------------------------------------------------------

	
		local DrillModel, DrillResult =
			DrillService.CreateDrill(
				Player,
				PreparedData
			)

		if DrillModel then
			DrillModel.Parent = TrainModel

			if not DrillSpawnOrigin
				or not DrillSpawnOrigin:IsA("BasePart") then

				TrainModel:Destroy()

				return nil,
					"Your station needs a DrillSpawnOrigin Part."
			end

			local DrillPrimaryCFrame =
				DrillSpawnOrigin.CFrame

			local DrillPositioned, DrillPositionError =
				PivotModelByPrimaryPart(
					DrillModel,
					DrillPrimaryCFrame
				)

			if not DrillPositioned then
				TrainModel:Destroy()

				return nil,
					DrillPositionError
			end
		
		end
	end

	TrainService.StopTrainPhysics(
		TrainModel
	)

	return TrainModel
end
---------------------------------------------------------------------
-- UPDATE CARS FUNCTION
---------------------------------------------------------------------

local function RefreshTrainCargoVisuals(
	TrainModel,
	Data
)
	if not TrainModel
		or typeof(Data) ~= "table"
		or typeof(Data.Train) ~= "table"
		or typeof(Data.Train.Cars) ~= "table" then

		return
	end

	local CarDataById = {}

	for _, CarData in Data.Train.Cars do
		if typeof(CarData.CarId) == "string" then
			CarDataById[CarData.CarId] =
				CarData
		end
	end

	for _, CarModel in TrainModel:GetChildren() do
		if not CarModel:IsA("Model") then
			continue
		end

		local CarId =
			CarModel:GetAttribute("CarId")

		if typeof(CarId) ~= "string" then
			continue
		end

		local CarData =
			CarDataById[CarId]

		if not CarData then
			warn(
				"No saved CarData found for",
				CarId
			)

			continue
		end

		local Updated =
			CarCargoVisualService.UpdateCar(
				CarModel,
				CarData
			)

		if not Updated then
			warn(
				"Could not refresh cargo visuals for",
				CarModel:GetFullName()
			)
		end
	end
end

---------------------------------------------------------------------
-- PUBLIC SPAWN FUNCTION
---------------------------------------------------------------------

function TrainService.SpawnPlayerTrain(
	Player,
	ProvidedData
)
	if not Player
		or not Player.Parent then

		return false,
			"Player is no longer connected."
	end

	local Data =
		ProvidedData
		or PlayerDataService.GetData(
			Player
		)

	if not Data then
		return false,
			"Player data is not loaded."
	end

	if TrainService.GetPlayerTrain(
		Player
		) then
		return false,
			"Player train is already spawned."
	end

	local TrainSpawnOrigin =
		StationService.GetTrainSpawnOrigin(
			Player
		)

	local DrillSpawnOrigin =
		StationService.GetDrillSpawnOrigin(
			Player
		)
	if not TrainSpawnOrigin
		or not TrainSpawnOrigin:IsA("BasePart") then

		return false,
			"Your station needs a TrainSpawnOrigin Part."
	end

local TrainModel, BuildError =
		BuildPlayerTrain(
			Player,
			Data,
			TrainSpawnOrigin,
			DrillSpawnOrigin
		)

	if not TrainModel then
		return false,
			BuildError
	end

	TrainModel.Parent =
		SpawnedTrains

	TrainService.StopTrainPhysics(
		TrainModel
	)
	
	RefreshTrainCargoVisuals(
		TrainModel,
		Data
	)


	RefreshTrainGui:FireClient(
		Player
	)

	return true,
		TrainModel
end

---------------------------------------------------------------------
-- REBUILD
---------------------------------------------------------------------

function TrainService.RebuildPlayerTrain(
	Player
)
	if RebuildLocks[Player] then
		return false,
			"Your train is already being rebuilt."
	end

	RebuildLocks[Player] = true

	local OldTrain
	local OldTrainDetached = false

	local CallSuccess,
		RebuildSuccess,
		Result =
		xpcall(
			function()
				local Data =
					PlayerDataService.GetData(
						Player
					)

				if not Data then
					return false,
						"Player data is not loaded."
				end

				OldTrain =
					TrainService.GetPlayerTrain(
						Player
					)

				if not OldTrain then
					return false,
						"Your train is not currently spawned."
				end

				TrainService.StopTrainPhysics(
					OldTrain
				)

				OldTrain.Parent = nil
				OldTrainDetached = true

				local Spawned,
					NewTrainOrError =
					TrainService.SpawnPlayerTrain(
						Player,
						Data
					)

				if not Spawned then
					OldTrain.Parent = SpawnedTrains
					OldTrainDetached = false

					TrainService.StopTrainPhysics(
						OldTrain
					)

					return false,
						NewTrainOrError
				end

				OldTrain:Destroy()
				OldTrainDetached = false

				return true,
					"Your train was rebuilt at its station."
			end,
			debug.traceback
		)

	RebuildLocks[Player] = nil

	if not CallSuccess then
		if OldTrainDetached
			and OldTrain
			and OldTrain.Parent == nil then

			OldTrain.Parent = SpawnedTrains
			TrainService.StopTrainPhysics(
				OldTrain
			)
		end

		warn(
			"Train rebuild failed for",
			Player.Name,
			RebuildSuccess
		)

		return false,
			"An unexpected error occurred while rebuilding your train."
	end

	return RebuildSuccess,
		Result
end

return TrainService