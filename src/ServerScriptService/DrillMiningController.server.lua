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

local DrillBitCache = {}

local function GetDrillBits(DrillModel)
	local Cached = DrillBitCache[DrillModel]

	if Cached then
		return Cached
	end

	local DrillBits = {}

	for _, DrillBitName in {
		"DrillBit",
		"LowerDrillBit",
	} do
		local DrillBit = DrillModel:FindFirstChild(DrillBitName, true)

		if DrillBit and DrillBit:IsA("BasePart") then
			table.insert(DrillBits, DrillBit)
		end
	end

	DrillBitCache[DrillModel] = DrillBits
	return DrillBits
end

local function CleanupDestroyedDrills()
	for DrillModel in NextMineTimes do
		if not DrillModel.Parent then
			NextMineTimes[DrillModel] = nil
			DrillBitCache[DrillModel] = nil
		end
	end
end

local NextMineTimes = {}

local MinimumSpeed = 0.05
local ScanInterval = 0.05
local DrillPadding = Vector3.new(0.05, 0, 0.05)

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

local function GetDrillBits(DrillModel)
	local DrillBits = {}

	for _, DrillBitName in {
		"DrillBit",
		"LowerDrillBit",
	} do
		local DrillBit = DrillModel:FindFirstChild(DrillBitName, true)

		if DrillBit and DrillBit:IsA("BasePart") then
			table.insert(DrillBits, DrillBit)
		end
	end

	return DrillBits
end

local function GetTouchingOres(DrillBits)
	local TouchingOres = {}
	local SeenOres = {}

	for _, DrillBit in DrillBits do

local TouchingParts = Workspace:GetPartBoundsInBox(
	DrillBit.CFrame,
	DrillBit.Size + DrillPadding,
	MineOverlapParameters
)

		for _, Part in TouchingParts do
			if not Part:IsA("BasePart") then
				continue
			end

			if Part:GetAttribute("Ore") ~= true then
				continue
			end

			if Part:GetAttribute("BeingDestroyed") then
				continue
			end

			if SeenOres[Part] then
				continue
			end

			SeenOres[Part] = true

			table.insert(TouchingOres, {
				Ore = Part,
				DrillBit = DrillBit,
			})
		end
	end

	return TouchingOres
end

local function GetLowestTouchingOre(TouchingOres)
	local LowestHit

	for _, Hit in TouchingOres do
		if not LowestHit or Hit.Ore.Position.Y < LowestHit.Ore.Position.Y then
			LowestHit = Hit
		end
	end

	return LowestHit
end

local function UpdateDrillSound(DrillBit, IsDrilling)
	local DrillSound = DrillBit:FindFirstChild("DrillSound")

	if not DrillSound or not DrillSound:IsA("Sound") then
		return
	end

	DrillSound.Looped = true

	if IsDrilling then
		if not DrillSound.Playing then
			DrillSound:Play()
		end
	elseif DrillSound.Playing then
		DrillSound:Stop()
	end
end

local function UpdateDrill(DrillModel, CurrentTime)
	if not DrillModel:IsDescendantOf(SpawnedTrains) then
		NextMineTimes[DrillModel] = nil
		return
	end

	if Workspace:GetAttribute("MineResetInProgress") then
		return
	end

	local NextMineTime = NextMineTimes[DrillModel] or 0

	if CurrentTime < NextMineTime then
		return
	end

	local DrillBits = GetDrillBits(DrillModel)

	if #DrillBits == 0 then
		return
	end

	local TouchingOres = GetTouchingOres(DrillBits)
	local IsDrilling = #TouchingOres > 0

	if MainDrillBit and MainDrillBit:IsA("BasePart") then
		UpdateDrillSound(MainDrillBit, IsDrilling)
	end

	if not IsDrilling then
		return
	end

	local NextMineTime = NextMineTimes[DrillModel] or 0

	if CurrentTime < NextMineTime then
		return
	end

	local Speed = tonumber(DrillModel:GetAttribute("Speed"))
		or tonumber(DrillModel:GetAttribute("DrillSpeed"))
		or 1

	Speed = math.max(Speed, MinimumSpeed)

	-- Schedule first so an error cannot create a rapid retry loop.
	NextMineTimes[DrillModel] = CurrentTime + Speed

	local Damage = tonumber(DrillModel:GetAttribute("Damage"))

	if not Damage or Damage <= 0 then
		return
	end

	local Player = GetOwner(DrillModel)

	if not Player then
		return
	end

	local Hit = GetLowestTouchingOre(TouchingOres)

	if not Hit then
		return
	end

	DrillMiningEvent:Fire(
		Player,
		Hit.Ore,
		Damage,
		DrillModel,
		Hit.DrillBit
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
