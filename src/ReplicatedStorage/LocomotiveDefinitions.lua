local LocomotiveDefinitions = {}

LocomotiveDefinitions.Order = {
	"PushCart",
	"MotorCart",
	"StarterLocomotive",
	"IntermediateLocomotive",
}

LocomotiveDefinitions.Data = {
	PushCart = {
		DisplayName = "Motor Cart",
		Description = "A manually pushed starter cart.",

		Tier = 1,
		PurchaseCost = 0,

		MaximumSpeed = 7,
		Acceleration = 3,

		TemplateName = "Motor Cart",
	},

	MotorCart = {
		DisplayName = "0-4-2ST",
		Description = "A compact powered cart for early mining operations.",

		Tier = 2,
		PurchaseCost = 750,

		MaximumSpeed = 3,
		Acceleration = 5,

		TemplateName = "0-4-2ST",
	},


	StarterLocomotive = {
		DisplayName = "Baby Diesel",
		Description = "A small locomotive capable of moving a larger train.",

		Tier = 3,
		PurchaseCost = 5000,

		MaximumSpeed = 7,
		Acceleration = 7,

		TemplateName = "Baby Diesel",
	},
	
	IntermediateLocomotive = {
		DisplayName = "Mining Diesel",
		Description = "A Rugged industrial locomotive with a nice top speed.",

		Tier = 4,
		PurchaseCost = 10000,

		MaximumSpeed = 15,
		Acceleration = 10,

		TemplateName = "Mining Diesel",
	},
}

function LocomotiveDefinitions.Get(
	LocomotiveId
)
	return LocomotiveDefinitions.Data[
		LocomotiveId
	]
end

function LocomotiveDefinitions.GetTier(
	LocomotiveId
)
	local Definition =
		LocomotiveDefinitions.Get(
			LocomotiveId
		)

	return Definition and Definition.Tier or 1
end

function LocomotiveDefinitions.GetNext(
	CurrentLocomotiveId
)
	local CurrentTier =
		LocomotiveDefinitions.GetTier(
			CurrentLocomotiveId
		)

	local NextId =
		LocomotiveDefinitions.Order[
			CurrentTier + 1
		]

	if not NextId then
		return nil, nil
	end

	return NextId,
		LocomotiveDefinitions.Get(NextId)
end

return LocomotiveDefinitions
