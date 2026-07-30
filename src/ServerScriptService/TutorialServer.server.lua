local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(
	ServerScriptService:WaitForChild("PlayerDataService")
)

local Remotes =
	ReplicatedStorage:WaitForChild("TutorialRemotes")

local GetTutorialData =
	Remotes:WaitForChild("GetTutorialData")

local UpdateTutorialStep =
	Remotes:WaitForChild("UpdateTutorialStep")

local ResetTutorial =
	Remotes:WaitForChild("ResetTutorial")

local MaximumTutorialStep = 8

local function EnsureTutorialData(Player)
	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return nil
	end

	if typeof(Data.Tutorial) ~= "table" then
		Data.Tutorial = {
			Step = 1,
			Completed = false,
		}
	end

	if typeof(Data.Tutorial.Step) ~= "number" then
		Data.Tutorial.Step = 1
	end

	if typeof(Data.Tutorial.Completed) ~= "boolean" then
		Data.Tutorial.Completed = false
	end

	return Data.Tutorial
end

GetTutorialData.OnServerInvoke = function(Player)
	local Tutorial = EnsureTutorialData(Player)

	if not Tutorial then
		return {
			Step = 1,
			Completed = false,
		}
	end

	return {
		Step = Tutorial.Step,
		Completed = Tutorial.Completed,
	}
end

UpdateTutorialStep.OnServerInvoke = function(
	Player,
	Step,
	Completed
)
	if typeof(Step) ~= "number"
		or typeof(Completed) ~= "boolean" then

		return false, "Invalid tutorial update."
	end

	Step = math.clamp(
		math.floor(Step),
		1,
		MaximumTutorialStep
	)

	local Tutorial = EnsureTutorialData(Player)

	if not Tutorial then
		return false, "Player data is not loaded."
	end

	-- Prevent clients from skipping arbitrary numbers of steps,
	-- except when completing or skipping the tutorial.
	if not Completed
		and Step > Tutorial.Step + 1 then

		return false, "Invalid tutorial step."
	end

	Tutorial.Step = Step
	Tutorial.Completed = Completed

	return true, {
		Step = Tutorial.Step,
		Completed = Tutorial.Completed,
	}
end

ResetTutorial.OnServerInvoke = function(Player)
	local Tutorial = EnsureTutorialData(Player)

	if not Tutorial then
		return false, "Player data is not loaded."
	end

	Tutorial.Step = 1
	Tutorial.Completed = false

	return true
end
