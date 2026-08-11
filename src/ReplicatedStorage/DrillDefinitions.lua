local DrillDefinitions = {}
DrillDefinitions.Order = {
	"NoDrill",
	"Drill2x2",
	"Drill2x3",
	"Drill4x3",
	"Drill4x4",
	"Drill4x5",
	"Drill6x5",
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

	Drill2x2 = {
		DisplayName = "Mole Drill",
		Description = "A small starter drill covering a 2 by 2 block face.",

		Tier = 1,
		PurchaseCost = 2500,

		Damage = 4,
		Speed = 2,

		Width = 2,
		Height = 2,

		TemplateName = "2x2 Drill",
		IsUnlocked = true,
	},

	Drill2x3 = {
		DisplayName = "Rabbit Drill",
		Description = "A double-bit drill covering a 2 by 3 block face.",

		Tier = 2,
		PurchaseCost = 15000,

		Damage = 10,
		Speed = 0.5,

		Width = 2,
		Height = 3,

		TemplateName = "2x3 Drill",
		IsUnlocked = true,
	},

	Drill4x3 = {
		DisplayName = "Lion Drill",
		Description = "A Double-bore drill covering a 4 by 3 block face.",

		Tier = 3,
		PurchaseCost = 75000,

		Damage = 24,
		Speed = 0.25,

		Width = 4,
		Height = 3,

		TemplateName = "4x3 Drill",
		IsUnlocked = true,
	},

	Drill4x4 = {
		DisplayName = "Frog Drill",
		Description = "A massive, bore covering a 4 by 4 block face.",

		Tier = 4,
		PurchaseCost = 350000,

		Damage = 48,
		Speed = 0.25,

		Width = 4,
		Height = 4,

		TemplateName = "4x4 Drill",
		IsUnlocked = true,
	},

	Drill4x5 = {
		DisplayName = "ROB Drill",
		Description = "A massive Robotic drill covering a 4 by 5 block face.",

		Tier = 5,
		PurchaseCost = 1500000,

		Damage = 100,
		Speed = 0.1,

		Width = 4,
		Height = 5,

		TemplateName = "4x5 Drill",
		IsUnlocked = true,
	},
	Drill6x5 = {
		DisplayName = "Tunnel Bore",
		Description = "If you get this reference, you're a true gamer.",

		Tier = 6,
		PurchaseCost = 5000000,

		Damage = 1000,
		Speed = 0.05,

		Width = 6,
		Height = 5,

		TemplateName = "6x5 Drill",
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
