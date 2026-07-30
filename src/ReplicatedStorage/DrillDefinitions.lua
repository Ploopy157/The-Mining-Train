local DrillDefinitions = {}
--Testing Changes
DrillDefinitions.Order = {
	"NoDrill",
	"Drill1x2",
	"Drill3x2",
	"Drill3x3",
	"Drill5x3",
	"Drill5x5",
}

DrillDefinitions.Data = {
	NoDrill = {
		DisplayName = "No Drill",
		Description = "The train does not currently have a drill.",

		Tier = 0,
		PurchaseCost = 0,

		Damage = 0,
		Speed = 0,

		Width = 0,
		Height = 0,

		IsUnlocked = false,
	},

	Drill1x2 = {
		DisplayName = "1x2 Drill",
		Description = "A narrow starter drill covering a 1 by 2 block face.",

		Tier = 1,
		PurchaseCost = 2500,

		Damage = 2,
		Speed = 1.5,

		Width = 1,
		Height = 2,

		TemplateName = "1x2 Drill",
		IsUnlocked = true,
	},

	Drill3x2 = {
		DisplayName = "3x2 Drill",
		Description = "A wider drill covering a 3 by 2 block face.",

		Tier = 2,
		PurchaseCost = 15000,

		Damage = 5,
		Speed = 1.1,

		Width = 3,
		Height = 2,

		TemplateName = "3x2 Drill",
		IsUnlocked = true,
	},

	Drill3x3 = {
		DisplayName = "3x3 Drill",
		Description = "A full-height drill covering a 3 by 3 block face.",

		Tier = 3,
		PurchaseCost = 75000,

		Damage = 12,
		Speed = 0.8,

		Width = 3,
		Height = 3,

		TemplateName = "3x3 Drill",
		IsUnlocked = true,
	},

	Drill5x3 = {
		DisplayName = "5x3 Drill",
		Description = "An advanced wide drill covering a 5 by 3 block face.",

		Tier = 4,
		PurchaseCost = 350000,

		Damage = 30,
		Speed = 0.55,

		Width = 5,
		Height = 3,

		TemplateName = "5x3 Drill",
		IsUnlocked = true,
	},

	Drill5x5 = {
		DisplayName = "5x5 Drill",
		Description = "A massive end-game drill covering a 5 by 5 block face.",

		Tier = 5,
		PurchaseCost = 1500000,

		Damage = 70,
		Speed = 0.35,

		Width = 5,
		Height = 5,

		TemplateName = "5x5 Drill",
		IsUnlocked = true,
	},
	
	TESTDRILL = {
		DisplayName = "TESTDRILL",
		Description = "For Developers Only",

		Tier = 999,
		PurchaseCost = 1000000000000,

		Damage = 1000,
		Speed = 0.01,

		Width = 5,
		Height = 5,

		TemplateName = "TESTDRILL",
		IsUnlocked = true,
	},
}

DrillDefinitions.LegacyIds = {
	StarterDrill = "NoDrill",
	IronDrill = "Drill3x2",
	SteelDrill = "Drill3x3",
	MiningDrill = "Drill5x3",
}

function DrillDefinitions.NormalizeId(
	DrillId
)
	if typeof(DrillId) ~= "string" then
		return ""
	end

	return DrillDefinitions.LegacyIds[DrillId]
		or DrillId
end

function DrillDefinitions.Get(
	DrillId
)
	DrillId =
		DrillDefinitions.NormalizeId(
			DrillId
		)

	return DrillDefinitions.Data[
		DrillId
	]
end

function DrillDefinitions.GetOrderIndex(
	DrillId
)
	DrillId =
		DrillDefinitions.NormalizeId(
			DrillId
		)

	for Index, OrderedId in
		DrillDefinitions.Order do

		if OrderedId == DrillId then
			return Index
		end
	end

	return 1
end

function DrillDefinitions.GetTier(
	DrillId
)
	local Definition =
		DrillDefinitions.Get(
			DrillId
		)

	return Definition
		and Definition.Tier
		or 0
end

function DrillDefinitions.GetNext(
	CurrentDrillId
)
	local CurrentIndex =
		DrillDefinitions.GetOrderIndex(
			CurrentDrillId
		)

	local NextId =
		DrillDefinitions.Order[
			CurrentIndex + 1
		]

	if not NextId then
		return nil, nil
	end

	return NextId,
		DrillDefinitions.Get(
			NextId
		)
end

function DrillDefinitions.GetMaximumLevel()
	return math.max(
		#DrillDefinitions.Order - 1,
		0
	)
end

return DrillDefinitions
