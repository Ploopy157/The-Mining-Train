local ReplicatedStorage =
	game:GetService("ReplicatedStorage")
local OpenDrillFilter = ReplicatedStorage:WaitForChild("DrillFilterRemotes"):WaitForChild("OpenDrillFilter")

local ServerStorage =
	game:GetService("ServerStorage")

local DrillDefinitions = require(
	ReplicatedStorage:WaitForChild(
		"DrillDefinitions"
	)
)

local UpgradeDefinitions = require(
	ReplicatedStorage:WaitForChild(
		"UpgradeDefinitions"
	)
)

local DrillTemplates =
	ServerStorage:WaitForChild(
		"TrainTemplates"
	):WaitForChild(
		"Drills"
	)

local DrillService = {}

local function GetSavedDrillId(Data)
	if typeof(Data) ~= "table"
		or typeof(Data.Train) ~= "table"
		or typeof(Data.Train.DrillId)
			~= "string" then

		return "StarterDrill"
	end

	return Data.Train.DrillId
end

local function GetSpeedMultiplier(Data)
	if typeof(Data) ~= "table"
		or typeof(Data.Upgrades)
			~= "table" then

		return 1
	end

	local Level =
		tonumber(
			Data.Upgrades.DrillSpeed
		) or 0

	local Multiplier =
		UpgradeDefinitions.GetValue(
			"DrillSpeed",
			Level
		)

	if typeof(Multiplier) ~= "number"
		or Multiplier <= 0 then

		return 1
	end

	return Multiplier
end

function DrillService.GetStats(Data)
	local DrillId =
		GetSavedDrillId(Data)

	local Definition =
		DrillDefinitions.Get(
			DrillId
		)

	if not Definition then
		DrillId = "StarterDrill"

		Definition =
			DrillDefinitions.Get(
				DrillId
			)
	end

	if not Definition then
		return nil,
			"StarterDrill definition was not found."
	end

	local Damage =
		tonumber(
			Definition.Damage
		) or 1

	local BaseSpeed =
		tonumber(
			Definition.Speed
		) or 1

	local SpeedMultiplier =
		GetSpeedMultiplier(Data)

	-- Speed is the interval between mining attempts.
	-- A larger upgrade multiplier reduces that interval.
	local EffectiveSpeed =
		BaseSpeed / SpeedMultiplier

	return {
		DrillId = DrillId,

		DisplayName =
			Definition.DisplayName
			or DrillId,

		Damage =
			math.max(
				Damage,
				0
			),

		Speed =
			math.max(
				EffectiveSpeed,
				0.05
			),

		BaseSpeed =
			math.max(
				BaseSpeed,
				0.05
			),

		SpeedMultiplier =
			SpeedMultiplier,


		Definition =
			Definition,
	}
end

local function AddFilterPrompt(Player, DrillBit)
	local ExistingPrompt = DrillBit:FindFirstChild("DrillFilterPrompt")

	if ExistingPrompt then
		ExistingPrompt:Destroy()
	end

	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Name = "DrillFilterPrompt"
	Prompt.ActionText = "Configure Drill"
	Prompt.ObjectText = "Ore Filter"
	Prompt.KeyboardKeyCode = Enum.KeyCode.E
	Prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	Prompt.HoldDuration = 0
	Prompt.MaxActivationDistance = 10
	Prompt.RequiresLineOfSight = false
	Prompt.Parent = DrillBit

	Prompt.Triggered:Connect(function(TriggeringPlayer)
		if TriggeringPlayer ~= Player then
			return
		end

		OpenDrillFilter:FireClient(TriggeringPlayer)
	end)
end

local function ValidateTemplate(
	Template,
	TemplateName
)
	if not Template then
		return false,
			"Drill template "
			.. TemplateName
			.. " was not found."
	end

	if not Template:IsA("Model") then
		return false,
			"Drill template "
			.. TemplateName
			.. " must be a Model."
	end

	if not Template.PrimaryPart then
		return false,
			"Drill template "
			.. TemplateName
			.. " needs a PrimaryPart."
	end

	local DrillBit =
		Template:FindFirstChild(
			"DrillBit",
			true
		)

	if not DrillBit
		or not DrillBit:IsA("BasePart") then

		return false,
			"Drill template "
			.. TemplateName
			.. " needs a DrillBit BasePart."
	end

	return true
end

local function ApplyAttributes(
	DrillModel,
	DrillBit,
	Player,
	Stats
)
	DrillModel:SetAttribute(
		"IsDrill",
		true
	)

	DrillModel:SetAttribute(
		"OwnerUserId",
		Player.UserId
	)

	DrillModel:SetAttribute(
		"DrillId",
		Stats.DrillId
	)

	DrillModel:SetAttribute(
		"Damage",
		Stats.Damage
	)

	DrillModel:SetAttribute(
		"Speed",
		Stats.Speed
	)

	DrillModel:SetAttribute(
		"DrillSpeed",
		Stats.Speed
	)


	DrillBit:SetAttribute(
		"IsDrillBit",
		true
	)

	DrillBit:SetAttribute(
		"Damage",
		Stats.Damage
	)

	DrillBit:SetAttribute(
		"Speed",
		Stats.Speed
	)
end

function DrillService.CreateDrill(
	Player,
	Data
)
	if not Player
		or not Player.Parent then

		return nil,
			"Player is no longer connected."
	end

	local Stats,
		StatsError =
		DrillService.GetStats(
			Data
		)

	if not Stats then
		return nil,
			StatsError
	end

	if Stats.DrillId == "NoDrill"
		or Stats.IsUnlocked == false then

		return nil, {
			DrillId = "NoDrill",
			IsUnlocked = false,
			NoPhysicalDrill = true,
			Stats = Stats,
		}
	end

	local TemplateName =
		Stats.Definition.TemplateName
		or Stats.DrillId

	local Template =
		DrillTemplates:FindFirstChild(
			TemplateName
		)
		or DrillTemplates:FindFirstChild(
			Stats.DrillId
		)

	local Valid,
		ValidationError =
		ValidateTemplate(
			Template,
			TemplateName
		)

	if not Valid then
		return nil,
			ValidationError
	end

	local DrillModel =
		Template:Clone()

	DrillModel.Name = "Drill"

	local DrillBit =
		DrillModel:FindFirstChild(
			"DrillBit",
			true
		)

	ApplyAttributes(
		DrillModel,
		DrillBit,
		Player,
		Stats
	)

	return DrillModel,
		Stats
end

return DrillService
