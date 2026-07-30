local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local PlayerDataService = require(
	ServerScriptService:WaitForChild(
		"PlayerDataService"
	)
)

local LocomotiveDefinitions = require(
	ReplicatedStorage:WaitForChild(
		"LocomotiveDefinitions"
	)
)

local Remotes =
	ReplicatedStorage:WaitForChild(
		"LocomotiveUpgradeRemotes"
	)

local GetLocomotiveUpgradeData =
	Remotes:WaitForChild(
		"GetLocomotiveUpgradeData"
	)

local PurchaseNextLocomotive =
	Remotes:WaitForChild(
		"PurchaseNextLocomotive"
	)

local RefreshLocomotiveShop =
	Remotes:WaitForChild(
		"RefreshLocomotiveShop"
	)

local SpawnedTrains =
	Workspace:WaitForChild(
		"SpawnedTrains"
	)

---------------------------------------------------------------------
-- DATA
---------------------------------------------------------------------

local function EnsureLocomotiveData(Data)
	if typeof(Data.Stats) ~= "table" then
		Data.Stats = {}
	end

	if typeof(Data.Stats.Cash) ~= "number" then
		Data.Stats.Cash = 0
	end

	if typeof(Data.Train) ~= "table" then
		Data.Train = {}
	end

	if typeof(Data.Train.LocomotiveId)
		~= "string" then

		Data.Train.LocomotiveId =
			"PushCart"
	end

	if typeof(Data.Unlocks) ~= "table" then
		Data.Unlocks = {}
	end

	if typeof(Data.Unlocks.Locomotives)
		~= "table" then

		Data.Unlocks.Locomotives = {
			PushCart = true,
		}
	end

	Data.Unlocks.Locomotives.PushCart =
		true
end

local function GetPlayerTrain(Player)
	return SpawnedTrains:FindFirstChild(
		"PlayerTrain_" .. Player.UserId
	)
end

local function GetCurrentDefinition(Data)
	return LocomotiveDefinitions.Get(
		Data.Train.LocomotiveId
	)
end

local function BuildUpgradeData(Player)
	local Data =
		PlayerDataService.GetData(Player)

	if not Data then
		return nil
	end

	EnsureLocomotiveData(Data)

	local CurrentId =
		Data.Train.LocomotiveId

	local CurrentDefinition =
		GetCurrentDefinition(Data)

	local NextId, NextDefinition =
		LocomotiveDefinitions.GetNext(
			CurrentId
		)

	return {
		Cash = Data.Stats.Cash,

		CurrentLocomotiveId = CurrentId,
		Current = CurrentDefinition,

		NextLocomotiveId = NextId,
		Next = NextDefinition,

		IsMaximumTier =
			NextDefinition == nil,

		CanAfford =
			NextDefinition ~= nil
			and Data.Stats.Cash
				>= NextDefinition.PurchaseCost,
	}
end

---------------------------------------------------------------------
-- TRAIN REPLACEMENT
---------------------------------------------------------------------

local function StopModel(Model)
	for _, Object in Model:GetDescendants() do
		if Object:IsA("BasePart") then
			Object.AssemblyLinearVelocity =
				Vector3.zero

			Object.AssemblyAngularVelocity =
				Vector3.zero
		end
	end
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

local function ReplacePhysicalLocomotive(
	Player,
	NewLocomotiveId
)
	local TrainModel = GetPlayerTrain(Player)

	if not TrainModel then
		return false,
			"Your train is not currently spawned."
	end

	local OldLocomotive =
		TrainModel:FindFirstChild(
			"Locomotive"
		)

	if not OldLocomotive
		or not OldLocomotive:IsA("Model") then

		return false,
			"Your current locomotive was not found."
	end

	if not OldLocomotive.PrimaryPart then
		return false,
			"Your current locomotive has no PrimaryPart."
	end

	local TemplateFolder =
		game:GetService("ServerStorage")
			:WaitForChild("TrainTemplates")
			:WaitForChild("Locomotives")

	local Definition =
		LocomotiveDefinitions.Get(
			NewLocomotiveId
		)

	if not Definition then
		return false,
			"New locomotive definition was not found."
	end

	local Template =
		TemplateFolder:FindFirstChild(
			Definition.TemplateName
		)

	if not Template
		or not Template:IsA("Model") then

		return false,
			"Locomotive template "
				.. Definition.TemplateName
				.. " was not found."
	end

	if not Template.PrimaryPart then
		return false,
			"Locomotive template "
				.. Definition.TemplateName
				.. " has no PrimaryPart."
	end

	local OldPrimaryCFrame =
		OldLocomotive.PrimaryPart.CFrame

	StopModel(TrainModel)

	local NewLocomotive =
		Template:Clone()

	NewLocomotive.Name = "Locomotive"

	NewLocomotive:SetAttribute(
		"OwnerUserId",
		Player.UserId
	)

	NewLocomotive:SetAttribute(
		"LocomotiveId",
		NewLocomotiveId
	)

	NewLocomotive:SetAttribute(
		"MaximumSpeed",
		Definition.MaximumSpeed
	)

	NewLocomotive:SetAttribute(
		"Acceleration",
		Definition.Acceleration
	)

	NewLocomotive.Parent = TrainModel

	local Positioned, PositionError =
		PivotModelByPrimaryPart(
			NewLocomotive,
			OldPrimaryCFrame
		)

	if not Positioned then
		NewLocomotive:Destroy()

		return false, PositionError
	end

	OldLocomotive:Destroy()

	StopModel(TrainModel)

	return true
end

---------------------------------------------------------------------
-- PURCHASE
---------------------------------------------------------------------

GetLocomotiveUpgradeData.OnServerInvoke =
	function(Player)

		return BuildUpgradeData(Player)
	end

PurchaseNextLocomotive.OnServerInvoke =
	function(Player)

		local Data =
			PlayerDataService.GetData(Player)

		if not Data then
			return false,
				"Player data is not loaded."
		end

		EnsureLocomotiveData(Data)

		local CurrentId =
			Data.Train.LocomotiveId

		local NextId, NextDefinition =
			LocomotiveDefinitions.GetNext(
				CurrentId
			)

		if not NextDefinition then
			return false,
				"You already own the highest locomotive tier."
		end

		local Cost =
			NextDefinition.PurchaseCost

		if Data.Stats.Cash < Cost then
			return false,
				"You do not have enough cash."
		end

		-- Replace the physical model first. Cash and saved
		-- ownership are changed only after replacement succeeds.
		local Replaced, ReplaceError =
			ReplacePhysicalLocomotive(
				Player,
				NextId
			)

		if not Replaced then
			return false, ReplaceError
		end

		Data.Stats.Cash -= Cost
		Data.Train.LocomotiveId = NextId

		Data.Train.MaximumCars =
			NextDefinition.MaximumCars

		Data.Train.MaximumSpeed =
			NextDefinition.MaximumSpeed

		Data.Train.Acceleration =
			NextDefinition.Acceleration

		Data.Unlocks.Locomotives[NextId] =
			true

		local Leaderstats =
			Player:FindFirstChild(
				"leaderstats"
			)

		local CashValue =
			Leaderstats
			and Leaderstats:FindFirstChild(
				"Cash"
			)

		if CashValue then
			CashValue.Value =
				Data.Stats.Cash
		end

		RefreshLocomotiveShop:FireClient(
			Player
		)

		return true, {
			LocomotiveId = NextId,
			DisplayName =
				NextDefinition.DisplayName,

			RemainingCash =
				Data.Stats.Cash,

			MaximumCars =
				NextDefinition.MaximumCars,

			MaximumSpeed =
				NextDefinition.MaximumSpeed,
		}
	end
