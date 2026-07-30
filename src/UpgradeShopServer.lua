local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local PlayerDataService = require(
	ServerScriptService:WaitForChild("PlayerDataService")
)

local UpgradeDefinitions = require(
	ReplicatedStorage:WaitForChild("UpgradeDefinitions")
)

local ServerStorage =
	game:GetService("ServerStorage")

local Pickaxes =
	ServerStorage:WaitForChild("Pickaxes")

local Lights =
	ServerStorage:WaitForChild("Lights")

local LightService = require(
	ServerScriptService:WaitForChild(
		"LightService"
	)
)

local TrainService = require(
	ServerScriptService:WaitForChild(
		"TrainService"
	)
)
local LocomotiveDefinitions = require(
	ReplicatedStorage:WaitForChild(
		"LocomotiveDefinitions"
	)
)

local OreInfoEvent =
	ReplicatedStorage:WaitForChild(
		"OreInfoEvent"
	)
local function ApplyLocomotiveTierUpgrade(
	Data
)
	if typeof(Data.Train) ~= "table" then
		Data.Train = {}
	end

	local CurrentLocomotiveId =
		Data.Train.LocomotiveId
		or "PushCart"

	local NextLocomotiveId,
		NextDefinition =
		LocomotiveDefinitions.GetNext(
			CurrentLocomotiveId
		)

	if not NextLocomotiveId
		or not NextDefinition then

		return false,
			"No next locomotive tier was found."
	end

	Data.Train.LocomotiveId =
		NextLocomotiveId

	if typeof(NextDefinition.MaximumCars)
		== "number" then

		Data.Train.MaximumCars =
			NextDefinition.MaximumCars
	end

	if typeof(NextDefinition.MaximumSpeed)
		== "number" then

		Data.Train.MaximumSpeed =
			NextDefinition.MaximumSpeed
	end

	if typeof(NextDefinition.Acceleration)
		== "number" then

		Data.Train.Acceleration =
			NextDefinition.Acceleration
	end

	return true, {
		LocomotiveId =
			NextLocomotiveId,

		Definition =
			NextDefinition,
	}
end

local function ApplyCarCapacityUpgrade(Data)
	if typeof(Data.Train) ~= "table" then
		return
	end

	if typeof(Data.Train.Cars) ~= "table" then
		return
	end

	if typeof(Data.Upgrades) ~= "table" then
		Data.Upgrades = {}
	end

	local CarCapacityLevel =
		Data.Upgrades.CarCapacity or 0

	local Capacity =
		UpgradeDefinitions.GetValue(
			"CarCapacity",
			CarCapacityLevel
		)

	if typeof(Capacity) ~= "number" then
		return
	end

	Capacity = math.floor(Capacity)

	for _, CarData in Data.Train.Cars do
		CarData.Capacity = Capacity
	end
end

local Remotes =
	ReplicatedStorage:WaitForChild("UpgradeShopRemotes")

local GetUpgradeShopData =
	Remotes:WaitForChild("GetUpgradeShopData")

local PurchaseUpgrade =
	Remotes:WaitForChild("PurchaseUpgrade")

local OpenUpgradeShop =
	Remotes:WaitForChild("OpenUpgradeShop")

local RefreshUpgradeShop =
	Remotes:WaitForChild("RefreshUpgradeShop")

local MaximumShopDistance = 15

local UpgradeOrder = {
	"PickaxeDamage",
	"Light",
	"BackpackCapacity",
	"CarCapacity",
	"MaximumCars",
	"LocomotiveTier",
	"DrillSpeed",
	"DrillRange",
	"FurnaceSpeed",
	"FurnaceCapacity",
}

---------------------------------------------------------------------
-- DATA SETUP
---------------------------------------------------------------------

local function EnsurePlayerUpgradeData(Data)
	if typeof(Data.Stats) ~= "table" then
		Data.Stats = {}
	end

	if typeof(Data.Stats.Cash) ~= "number" then
		Data.Stats.Cash = 0
	end

	if typeof(Data.Upgrades) ~= "table" then
		Data.Upgrades = {}
	end

	for UpgradeId in UpgradeDefinitions do
		if typeof(UpgradeDefinitions[UpgradeId])
			== "table"
			and typeof(Data.Upgrades[UpgradeId])
				~= "number" then

			Data.Upgrades[UpgradeId] = 0
		end
	end

	if typeof(Data.Train) ~= "table" then
		Data.Train = {}
	end

	if typeof(Data.Train.Cars) ~= "table" then
		Data.Train.Cars = {}
	end

	if typeof(Data.Train.Drill) ~= "table" then
		Data.Train.Drill = {}
	end

	if typeof(Data.Furnace) ~= "table" then
		Data.Furnace = {}
	end
end

---------------------------------------------------------------------
-- SHOP DISTANCE
---------------------------------------------------------------------

local function GetInteractionPart()
	local Shop = Workspace:FindFirstChild("UpgradeShop")

	if not Shop then
		return nil
	end

	local InteractionPart =
		Shop:FindFirstChild(
			"InteractionPart",
			true
		)

	if InteractionPart
		and InteractionPart:IsA("BasePart") then

		return InteractionPart
	end

	return nil
end

local function IsNearShop(Player)
	local InteractionPart = GetInteractionPart()

	if not InteractionPart then
		return true
	end

	local Character = Player.Character
	local Root =
		Character
		and Character:FindFirstChild(
			"HumanoidRootPart"
		)

	if not Root then
		return false
	end

	return (
		Root.Position - InteractionPart.Position
	).Magnitude <= MaximumShopDistance
end

---------------------------------------------------------------------
-- DISPLAY HELPERS
---------------------------------------------------------------------

local function FormatValue(
	Definition,
	Value
)
	local DecimalPlaces =
		Definition.DecimalPlaces or 0

	local ValueText

	if DecimalPlaces > 0 then
		ValueText = string.format(
			"%." .. DecimalPlaces .. "f",
			Value
		)
	else
		ValueText =
			tostring(math.floor(Value))
	end

	return ValueText
		.. (Definition.ValueSuffix or "")
end

local function GetPickaxeNameFromLevel(Level)
	local TemplateId =
		tostring(Level + 1)

	local Pickaxe =
		Pickaxes:FindFirstChild(
			TemplateId
		)

	if not Pickaxe then
		return "Unknown Pickaxe"
	end

	return Pickaxe:GetAttribute("Name")
		or Pickaxe.Name
end

local function GetPickaxeDamageFromLevel(Level)
	local TemplateId =
		tostring(Level + 1)

	local Pickaxe =
		Pickaxes:FindFirstChild(
			TemplateId
		)

	if not Pickaxe then
		return "Unknown Pickaxe"
	end

	return Pickaxe:GetAttribute("Damage")
		or Pickaxe.Name
end

local function GetLightNameFromLevel(Level)
	local TemplateId =
		tostring(Level + 1)

	local LightModel =
		Lights:FindFirstChild(
			TemplateId
		)

	if not LightModel then
		return "Unknown Lamp"
	end

	return LightModel:GetAttribute(
		"DisplayName"
	)
		or LightModel:GetAttribute("Name")
		or LightModel.Name
end

local function GetLightRangeFromLevel(Level)
	local TemplateId =
		tostring(Level + 1)

	local LightModel =
		Lights:FindFirstChild(
			TemplateId
		)

	if not LightModel then
		return 0
	end

	return LightModel:GetAttribute("Range")
		or 0
end

local function BuildShopData(Player)

	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return {
			Cash = 0,
			Upgrades = {},
		}
	end

	EnsurePlayerUpgradeData(Data)

	local Upgrades = {}

	for _, UpgradeId in UpgradeOrder do
		local Definition =
			UpgradeDefinitions[UpgradeId]

		if Definition then
			local Level =
				Data.Upgrades[UpgradeId] or 0

			local IsMaximumLevel =
				Level >= Definition.MaximumLevel

			local Cost =
				IsMaximumLevel
				and 0
				or UpgradeDefinitions.GetCost(
					UpgradeId,
					Level
				)

			local CurrentValue =
				UpgradeDefinitions.GetValue(
					UpgradeId,
					Level
				)

			table.insert(Upgrades, {
				UpgradeId = UpgradeId,
				DisplayName = Definition.DisplayName,
				Description = Definition.Description,
				Category = Definition.Category,

				Level = Level,
				MaximumLevel =
					Definition.MaximumLevel,

				Cost = Cost,
				IsMaximumLevel = IsMaximumLevel,
				CanAfford =
					Data.Stats.Cash >= Cost,

				CurrentValue = CurrentValue,
				FormattedValue =
					UpgradeId == "PickaxeDamage"
					and (
						IsMaximumLevel
						and (
							"Current: "
							.. GetPickaxeNameFromLevel(Level)
						)
						or (GetPickaxeNameFromLevel(Level)
							.." ("
							..GetPickaxeDamageFromLevel(Level)
							.. ") -> "
							.. GetPickaxeNameFromLevel(Level + 1)
							.." ("
							..GetPickaxeDamageFromLevel(Level+1)
							.. ")"
						)

					)
					or FormatValue(
						Definition,
						CurrentValue
					),
			})
		end
	end

	return {
		Cash = Data.Stats.Cash,
		Upgrades = Upgrades,
	}
end

local function AddCarsUpToMaximum(
	Data,
	MaximumCars
)
	if typeof(Data.Train) ~= "table" then
		Data.Train = {}
	end

	if typeof(Data.Train.Cars) ~= "table" then
		Data.Train.Cars = {}
	end

	MaximumCars =
		math.max(
			1,
			math.floor(
				tonumber(MaximumCars) or 1
			)
		)

	local CarCapacityLevel =
		tonumber(
			Data.Upgrades.CarCapacity
		) or 0

	local CarCapacity =
		UpgradeDefinitions.GetValue(
			"CarCapacity",
			CarCapacityLevel
		)

	CarCapacity =
		math.max(
			1,
			math.floor(
				tonumber(CarCapacity) or 2
			)
		)

	while #Data.Train.Cars < MaximumCars do
		local NewIndex =
			#Data.Train.Cars + 1

		table.insert(
			Data.Train.Cars,
			{
				CarId =
					"Car_" .. NewIndex,

				CarType =
					"StarterOreCar",

				Capacity =
					CarCapacity,

				Inventory = {},
			}
		)
	end
end

---------------------------------------------------------------------
-- APPLY UPGRADE EFFECTS
---------------------------------------------------------------------

local function ApplyUpgrade(
	Player,
	Data,
	UpgradeId,
	NewLevel
)
	local NewValue =
		UpgradeDefinitions.GetValue(
			UpgradeId,
			NewLevel
		)

	if UpgradeId == "BackpackCapacity" then
		Data.Stats.BackpackCapacity =
			math.floor(NewValue)

	elseif UpgradeId == "CarCapacity" then
		for _, CarData in Data.Train.Cars do
			CarData.Capacity =
				math.floor(NewValue)
		end

	elseif UpgradeId == "MaximumCars" then
		AddCarsUpToMaximum(
			Data,
			NewValue
		)
	elseif UpgradeId == "LocomotiveTier" then
		local AppliedSuccessfully,
			Result =
			ApplyLocomotiveTierUpgrade(
				Data
			)

		if not AppliedSuccessfully then
			return false, Result
		end
	elseif UpgradeId == "DrillSpeed" then
		Data.Train.Drill.SpeedMultiplier =
			NewValue

	elseif UpgradeId == "DrillRange" then
		Data.Train.Drill.Range =
			NewValue

	elseif UpgradeId == "FurnaceSpeed" then
		Data.Furnace.SpeedMultiplier =
			NewValue

	elseif UpgradeId == "FurnaceCapacity" then
		Data.Furnace.Capacity =
			math.floor(NewValue)

	elseif UpgradeId == "Light" then
		task.defer(function()
			LightService.ApplyToPlayer(
				Player
			)
		end)

	elseif UpgradeId == "PickaxeDamage" then
		Data.Stats.PickaxeDamage =
			math.floor(NewValue)

		local Character = Player.Character

		if Character then
			local Tool =
				Character:FindFirstChildWhichIsA(
					"Tool"
				)

			if Tool then
				Tool:SetAttribute(
					"Damage",
					Data.Stats.PickaxeDamage
				)
			end
		end

		local Backpack =
			Player:FindFirstChild("Backpack")

		if Backpack then
			for _, Tool in Backpack:GetChildren() do
				if Tool:IsA("Tool")
					and Tool:GetAttribute("Damage")
						~= nil then

					Tool:SetAttribute(
						"Damage",
						Data.Stats.PickaxeDamage
					)
				end
			end
		end
	end
return true
end

---------------------------------------------------------------------
-- PURCHASES
---------------------------------------------------------------------



GetUpgradeShopData.OnServerInvoke = function(Player)
	return BuildShopData(Player)
end

local SlotsPerCarModelTier = 6

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

	return math.floor(
		(Capacity - 1)
			/ SlotsPerCarModelTier
	) + 1
end

PurchaseUpgrade.OnServerInvoke = function(
	Player,
	UpgradeId
)
	if not IsNearShop(Player) then
		return false, "Move closer to the upgrade shop."
	end

	if typeof(UpgradeId) ~= "string" then
		return false, "Invalid upgrade."
	end

	local Definition =
		UpgradeDefinitions[UpgradeId]

	if typeof(Definition) ~= "table" then
		return false, "Upgrade was not found."
	end

	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return false, "Player data is not loaded."
	end

	EnsurePlayerUpgradeData(Data)

	local CurrentLevel =
		Data.Upgrades[UpgradeId] or 0

	if CurrentLevel >= Definition.MaximumLevel then
		return false, "This upgrade is already at maximum level."
	end

	local Cost =
		UpgradeDefinitions.GetCost(
			UpgradeId,
			CurrentLevel
		)

	if Data.Stats.Cash < Cost then
		return false, "You do not have enough cash."
	end

	local PreviousCarCapacity

	if UpgradeId == "CarCapacity" then
		PreviousCarCapacity =
			UpgradeDefinitions.GetValue(
				"CarCapacity",
				CurrentLevel
			)
	end
	Data.Stats.Cash -= Cost

	local NewLevel = CurrentLevel + 1
	Data.Upgrades[UpgradeId] = NewLevel
	
	local PreviousCarCapacity
	if UpgradeId == "CarCapacity" then
		
		ApplyCarCapacityUpgrade(Data)
	end

	local AppliedSuccessfully,
		ApplyError =
		ApplyUpgrade(
			Player,
			Data,
			UpgradeId,
			NewLevel
		)
	if UpgradeId == "CarCapacity" then
		local NewCarCapacity =
			UpgradeDefinitions.GetValue(
				"CarCapacity",
				NewLevel
			)

		local PreviousModelTier =
			GetCarModelTier(
				PreviousCarCapacity
			)

		local NewModelTier =
			GetCarModelTier(
				NewCarCapacity
			)

		-- Only rebuild when the physical model actually changes.
		-- Capacity and cargo transparency can update normally between tiers.
		if NewModelTier ~= PreviousModelTier
			and TrainService.GetPlayerTrain(
				Player
			) then

			local RebuiltSuccessfully,
				RebuildMessage =
				TrainService.RebuildPlayerTrain(
					Player
				)

			if not RebuiltSuccessfully then
				warn(
					"Car capacity upgraded, but train rebuild failed for",
					Player.Name,
					RebuildMessage
				)
			end
		end
	end

	if AppliedSuccessfully == false then
		-- Roll back the purchase if applying the upgrade failed.
		Data.Upgrades[UpgradeId] =
			CurrentLevel

		Data.Stats.Cash += Cost

		return false,
			ApplyError
			or "The upgrade could not be applied."
	end
	
	local ShouldReturnTrain =
		UpgradeId == "MaximumCars"
		or UpgradeId == "LocomotiveTier"

	if ShouldReturnTrain
		and TrainService.GetPlayerTrain(Player) then

		local RebuiltSuccessfully,
			RebuildMessage =
			TrainService.RebuildPlayerTrain(
				Player
			)

		if not RebuiltSuccessfully then
			warn(
				"Upgrade purchased, but train rebuild failed for",
				Player.Name,
				UpgradeId,
				RebuildMessage
			)

			OreInfoEvent:FireClient(
				Player,
				"Upgrade purchased, but train return failed"
			)
		else
			OreInfoEvent:FireClient(
				Player,
				"Upgrade purchased — train returned to station"
			)
		end
	end
	
	if UpgradeId == "MaximumCars"
		or UpgradeId == "LocomotiveTier" then

		if TrainService.GetPlayerTrain(Player) then
			local RebuiltSuccessfully,
				RebuildMessage =
				TrainService.RebuildPlayerTrain(
					Player
				)

			if not RebuiltSuccessfully then
				warn(
					"Upgrade succeeded, but train return failed for",
					Player.Name,
					UpgradeId,
					RebuildMessage
				)

				OreInfoEvent:FireClient(
					Player,
					"Upgrade purchased, but train return failed"
				)
			else
				OreInfoEvent:FireClient(
					Player,
					"Upgrade purchased — train returned to station"
				)
			end
		end
	end

	local Leaderstats =
		Player:FindFirstChild("leaderstats")

	local CashValue =
		Leaderstats
		and Leaderstats:FindFirstChild("Cash")

	if CashValue then
		CashValue.Value =
			Data.Stats.Cash
	end

	RefreshUpgradeShop:FireClient(Player)

	return true, {
		NewLevel = NewLevel,
		NewValue =
			UpgradeDefinitions.GetValue(
				UpgradeId,
				NewLevel
			),
		RemainingCash = Data.Stats.Cash,
	}
end

---------------------------------------------------------------------
-- PROMPT
---------------------------------------------------------------------

local function ConfigurePrompt()
	local InteractionPart = GetInteractionPart()

	if not InteractionPart then
		warn(
			"Workspace.UpgradeShop.InteractionPart was not found."
		)

		return
	end

	local ExistingPrompt =
		InteractionPart:FindFirstChild(
			"UpgradeShopPrompt"
		)

	if ExistingPrompt then
		ExistingPrompt:Destroy()
	end

	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Name = "UpgradeShopPrompt"
	Prompt.ActionText = "Buy Upgrades"
	Prompt.ObjectText = "Upgrade Shop"
	Prompt.HoldDuration = 0
	Prompt.MaxActivationDistance =
		MaximumShopDistance

	Prompt.RequiresLineOfSight = false
	Prompt.KeyboardKeyCode = Enum.KeyCode.E
	Prompt.Parent = InteractionPart

	Prompt.Triggered:Connect(function(Player)
		if IsNearShop(Player) then
			OpenUpgradeShop:FireClient(Player)
		end
	end)
end

ConfigurePrompt()

Workspace.ChildAdded:Connect(function(Child)
	if Child.Name == "UpgradeShop" then
		task.wait()
		ConfigurePrompt()
	end
end)
