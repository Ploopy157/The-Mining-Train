local LocomotiveDefinitions = {}

LocomotiveDefinitions.Order = {
	"PushCart",
	"MotorCart",
	"StarterLocomotive",
}

LocomotiveDefinitions.Data = {
	PushCart = {
		DisplayName = "Push Cart",
		Description = "A manually pushed starter cart.",

		Tier = 1,
		PurchaseCost = 0,

		MaximumSpeed = 7,
		Acceleration = 3,

		TemplateName = "Push Cart",
	},

	MotorCart = {
		DisplayName = "Motor Cart",
		Description = "A compact powered cart for early mining operations.",

		Tier = 2,
		PurchaseCost = 750,

		MaximumSpeed = 3,
		Acceleration = 5,

		TemplateName = "Motor Cart",
	},

	StarterLocomotive = {
		DisplayName = "Mini Diesel",
		Description = "A true locomotive capable of pulling a larger train.",

		Tier = 3,
		PurchaseCost = 5000,

		MaximumSpeed = 7,
		Acceleration = 7,

		TemplateName = "Mini Diesel",
	},
	
	IntermediateLocomotive = {
		DisplayName = "Mini Diesel",
		Description = "A true locomotive capable of pulling a larger train.",

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
