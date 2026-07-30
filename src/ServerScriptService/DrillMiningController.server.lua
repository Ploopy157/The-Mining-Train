local Players =
	game:GetService("Players")

local ServerScriptService =
	game:GetService("ServerScriptService")

local Workspace =
	game:GetService("Workspace")

local SpawnedTrains =
	Workspace:WaitForChild(
		"SpawnedTrains"
	)

local MineFolder =
	Workspace:WaitForChild(
		"MineContents"
	)

local DrillMiningEvent =
	ServerScriptService:WaitForChild(
		"DrillMiningEvent"
	)

local MineOverlapParameters =
	OverlapParams.new()

MineOverlapParameters.FilterType =
	Enum.RaycastFilterType.Include

MineOverlapParameters.FilterDescendantsInstances = {
	MineFolder,
}

local NextMineTimes = {}

local MinimumSpeed = 0.05
local ScanInterval = 0.05

local function GetOwner(DrillModel)
	local OwnerUserId =
		DrillModel:GetAttribute(
			"OwnerUserId"
		)

	if typeof(OwnerUserId) ~= "number" then
		return nil
	end

	return Players:GetPlayerByUserId(
		OwnerUserId
	)
end

local function GetTouchingOres(DrillBit)
	local TouchingOres = {}

	local TouchingParts =
		Workspace:GetPartsInPart(
			DrillBit,
			MineOverlapParameters
		)

	for _, Part in TouchingParts do
		if Part:IsA("BasePart")
			and Part:GetAttribute("Ore")
				== true
			and not Part:GetAttribute(
				"BeingDestroyed"
			) then

			table.insert(
				TouchingOres,
				Part
			)
		end
	end

	return TouchingOres
end

local function SelectTouchingOre(DrillBit)
	local TouchingOres =
		GetTouchingOres(
			DrillBit
		)

	if #TouchingOres == 0 then
		return nil
	end
	print(TouchingOres[#TouchingOres])
	return TouchingOres[1]
end

local function UpdateDrill(
	
	DrillModel,
	CurrentTime
)
	if not DrillModel:IsDescendantOf(
		SpawnedTrains
	) then
		NextMineTimes[DrillModel] = nil
		return
	end

	local NextMineTime =
		NextMineTimes[DrillModel]
		or 0

	if CurrentTime < NextMineTime then
		return
	end

	local Speed =
		tonumber(
			DrillModel:GetAttribute(
				"Speed"
			)
		)
		or tonumber(
			DrillModel:GetAttribute(
				"DrillSpeed"
			)
		)
		or 1

	Speed =
		math.max(
			Speed,
			MinimumSpeed
		)

	-- Schedule first so an error cannot create a rapid retry loop.
	NextMineTimes[DrillModel] =
		CurrentTime + Speed

	local Damage =
		tonumber(
			DrillModel:GetAttribute(
				"Damage"
			)
		)

	if not Damage
		or Damage <= 0 then

		return
	end

	local Player =
		GetOwner(
			DrillModel
		)

	if not Player then
		return
	end

	local DrillBit =
		DrillModel:FindFirstChild(
			"DrillBit",
			true
		)

	if not DrillBit
		or not DrillBit:IsA("BasePart") then
			print("COULD NOT FIND DRILL BIT")
		return
	end

	local Ore =
		SelectTouchingOre(
			DrillBit
		)

	if not Ore then
		return
	end

	DrillMiningEvent:Fire(
		Player,
		Ore,
		Damage,
		DrillModel,
		DrillBit
	)
end

local function CleanupDestroyedDrills()
	for DrillModel in NextMineTimes do
		if not DrillModel.Parent then
			NextMineTimes[DrillModel] = nil
		end
	end
end

task.spawn(function()
	while true do
		task.wait(ScanInterval)

		local CurrentTime =
			Workspace:GetServerTimeNow()

		for _, TrainModel in
			SpawnedTrains:GetChildren() do

			if not TrainModel:IsA("Model") then
				continue
			end

			local DrillModel =
				TrainModel:FindFirstChild(
					"Drill"
				)

			if DrillModel
				and DrillModel:IsA("Model") then

				local Success,
					ErrorMessage =
					pcall(
						UpdateDrill,
						DrillModel,
						CurrentTime
					)

				if not Success then
					warn(
						"Drill mining update failed:",
						ErrorMessage
					)
				end
			end
		end

		CleanupDestroyedDrills()
	end
end)
