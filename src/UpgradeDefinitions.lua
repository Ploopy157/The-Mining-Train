local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local DrillDefinitions = require(
	ReplicatedStorage:WaitForChild(
		"DrillDefinitions"
	)
)

local UpgradeDefinitions = {
	PickaxeDamage = {
		DisplayName = "Pickaxe",
		Description = "Unlocks the next pickaxe tier.",
		Category = "Mining",

		BaseCost = 60,
		CostGrowth = 2.5,
		MaximumLevel = #(game.ServerStorage.Pickaxes:GetChildren())-1,

		-- Upgrade level 0 uses template 1.
		-- Upgrade level 1 uses template 2.
		-- Upgrade level 2 uses template 3.
		BaseValue = 1,
		ValuePerLevel = 1,
		ValueSuffix = " tier",
	},

	Light = {
		DisplayName = "Lamp",
		Description = "Unlocks a brighter lamp for deeper mine layers.",
		Category = "Mining",

		BaseCost = 125,
		CostGrowth = 3.1,
		MaximumLevel = #(game.ServerStorage.Lights:GetChildren()) - 1,

		-- Upgrade level 0 uses light template 1.
		-- Upgrade level 1 uses light template 2.
		BaseValue = 1,
		ValuePerLevel = 1,
		ValueSuffix = " tier",
	},

	BackpackCapacity = {

		DisplayName = "Bag Capacity",
		Description = "Increases how many ores you can carry by hand.",
		Category = "Storage",

		BaseCost = 50,
		CostGrowth = 2,
		MaximumLevel = 16,

		BaseValue = 2,
		ValuePerLevel = 2,
		ValueSuffix = " ores",
	},

	CarCapacity = {
		DisplayName = "Ore Car Capacity",
		Description = "Increases the capacity of every ore car.",
		Category = "Train",

		BaseCost = 10,
		CostGrowth = 2.5,
		MaximumLevel = 24,

		BaseValue = 2,
		ValuePerLevel = 1,
		ValueSuffix = " ores per car",
	},

	MaximumCars = {
		DisplayName = "Maximum Cars",
		Description = "Increases how many cars your locomotive can pull.",
		Category = "Train",

		BaseCost = 50,
		CostGrowth = 10,
		MaximumLevel = 10,

		BaseValue = 1,
		ValuePerLevel = 1,
		ValueSuffix = " cars",
	},

	LocomotiveTier = {
		DisplayName = "Locomotive",
		Description = "Upgrade from a PushCart to a MotorCart, then to a true locomotive.",
		Category = "Train",

		-- Level 0: PushCart
		-- Level 1: MotorCart
		-- Level 2: Locomotive
		BaseCost = 200,
		CostGrowth = 6,
		MaximumLevel = #(game.ServerStorage.TrainTemplates.Locomotives:GetChildren())-1,

		BaseValue = 1,
		ValuePerLevel = 1,
		ValueSuffix = " tier",
	},

	DrillTier = {
		DisplayName = "Drill",
		Description = "Unlocks the next drill tier.",
		Category = "Drill",

		BaseCost = 2500,
		CostGrowth = 6,
		MaximumLevel =
			DrillDefinitions.GetMaximumLevel(),

		BaseValue = 1,
		ValuePerLevel = 1,
		ValueSuffix = " tier",
	},

	DrillSpeed = {
		DisplayName = "Drill Speed",
		Description = "Increases the drill's mining damage and excavation speed.",
		Category = "Drill",

		BaseCost = 500,
		CostGrowth = 1.65,
		MaximumLevel = 25,

		BaseValue = 1,
		ValuePerLevel = 0.15,
		ValueSuffix = "x speed",
		DecimalPlaces = 2,
	},


	FurnaceSpeed = {
		DisplayName = "Furnace Speed",
		Description = "Processes ores into ingots more quickly.",
		Category = "Furnace",

		BaseCost = 400,
		CostGrowth = 1.6,
		MaximumLevel = 25,

		BaseValue = 1,
		ValuePerLevel = 0.12,
		ValueSuffix = "x speed",
		DecimalPlaces = 2,
	},

	FurnaceCapacity = {
		DisplayName = "Furnace Capacity",
		Description = "Increases the number of ores that can be queued.",
		Category = "Furnace",

		BaseCost = 300,
		CostGrowth = 1.65,
		MaximumLevel = 20,

		BaseValue = 4,
		ValuePerLevel = 2,
		ValueSuffix = " ores",
	},
}

function UpgradeDefinitions.GetCost(
	UpgradeId,
	CurrentLevel
)
	local Definition =
		UpgradeDefinitions[UpgradeId]

	if not Definition then
		return nil
	end

	return math.floor(
		Definition.BaseCost
		* Definition.CostGrowth ^ CurrentLevel
	)
end

function UpgradeDefinitions.GetValue(
	UpgradeId,
	Level
)
	local Definition =
		UpgradeDefinitions[UpgradeId]

	if not Definition then
		return nil
	end

	return Definition.BaseValue
		+ Definition.ValuePerLevel * Level
end

return UpgradeDefinitions
