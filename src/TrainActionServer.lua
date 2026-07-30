local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TrainRemotes =
	ReplicatedStorage:WaitForChild("TrainRemotes")

local TrainAction =
	TrainRemotes:WaitForChild("TrainAction")

local StationsFolder =
	Workspace:WaitForChild("Stations")

local SpawnedTrains =
	Workspace:WaitForChild("SpawnedTrains")

local ServerScriptService =
	game:GetService("ServerScriptService")

local TrainService = require(
	ServerScriptService:WaitForChild(
		"TrainService"
	)
)


local ReturnTrainCooldown = 5

local TeleportToTrainOffset =
	CFrame.new(8, 4, 0)

local HomeFallbackOffset =
	CFrame.new(8, 4, 0)

local LastReturnTime = {}

---------------------------------------------------------------------
-- STATION HELPERS
---------------------------------------------------------------------

local function GetPlayerStation(Player)
	for _, Station in StationsFolder:GetChildren() do
		if Station:GetAttribute("OwnerUserId")
			== Player.UserId then

			return Station
		end
	end

	return nil
end

local function GetStationSpawnOrigin(Player)
	local Station = GetPlayerStation(Player)

	if not Station then
		return nil, nil
	end

	local TrainSpawnOrigin =
		Station:FindFirstChild(
			"TrainSpawnOrigin",
			true
		)

	if not TrainSpawnOrigin
		or not TrainSpawnOrigin:IsA("BasePart") then

		return Station, nil
	end

	return Station, TrainSpawnOrigin
end

local function GetHomePart(Player)
	local Station = GetPlayerStation(Player)

	if not Station then
		return nil
	end

	for _, Name in {
		"HomeSpawn",
		"PlayerSpawn",
		"Spawn",
	} do
		local Part = Station:FindFirstChild(
			Name,
			true
		)

		if Part and Part:IsA("BasePart") then
			return Part
		end
	end

	local TrainSpawnOrigin =
		Station:FindFirstChild(
			"TrainSpawnOrigin",
			true
		)

	if TrainSpawnOrigin
		and TrainSpawnOrigin:IsA("BasePart") then

		return TrainSpawnOrigin
	end

	return nil
end

---------------------------------------------------------------------
-- TRAIN HELPERS
---------------------------------------------------------------------


local function StopTrainPhysics(TrainModel)
	for _, Object in TrainModel:GetDescendants() do
		if Object:IsA("BasePart") then
			Object.AssemblyLinearVelocity =
				Vector3.zero

			Object.AssemblyAngularVelocity =
				Vector3.zero
		end
	end
end

local function GetCharacterRoot(Player)
	local Character = Player.Character

	if not Character then
		return nil, nil
	end

	local Humanoid =
		Character:FindFirstChildOfClass("Humanoid")

	local Root =
		Character:FindFirstChild("HumanoidRootPart")

	return Character, Root, Humanoid
end

local function TeleportCharacter(
	Player,
	TargetCFrame
)
	local Character, Root, Humanoid =
		GetCharacterRoot(Player)

	if not Character or not Root then
		return false
	end

	if Humanoid then
		Humanoid.Sit = false
	end

	Root.AssemblyLinearVelocity = Vector3.zero
	Root.AssemblyAngularVelocity = Vector3.zero

	Character:PivotTo(TargetCFrame)

	return true
end

---------------------------------------------------------------------
-- ACTIONS
---------------------------------------------------------------------

--local function ReturnTrain(Player)
--	local CurrentTime = os.clock()

--	local LastTime =
--		LastReturnTime[Player] or 0

--	local RemainingCooldown =
--		ReturnTrainCooldown
--	- (CurrentTime - LastTime)

--	if RemainingCooldown > 0 then
--		return false, string.format(
--			"Return Train is available again in %.1f seconds.",
--			RemainingCooldown
--		)
--	end

--	local ExistingTrain =
--		TrainService.GetPlayerTrain(Player)

--	if not ExistingTrain then
--		return false,
--			"Your train is not currently spawned."
--	end

--	local Rebuilt, Message =
--		TrainService.RebuildPlayerTrain(
--			Player
--		)

--	if not Rebuilt then
--		return false, Message
--	end

--	LastReturnTime[Player] =
--		CurrentTime

--	return true, Message
--end
local function ReturnTrain(Player)
	local CurrentTime = os.clock()

	local LastTime =
		LastReturnTime[Player] or 0

	local RemainingCooldown =
		ReturnTrainCooldown
	- (CurrentTime - LastTime)

	if RemainingCooldown > 0 then
		return false, string.format(
			"Return Train is available again in %.1f seconds.",
			RemainingCooldown
		)
	end

	local ExistingTrain =
		TrainService.GetPlayerTrain(
			Player
		)

	if not ExistingTrain then
		return false,
			"Your train is not currently spawned."
	end

	local Rebuilt, Message =
		TrainService.RebuildPlayerTrain(
			Player
		)

	if not Rebuilt then
		return false,
			Message
	end

	LastReturnTime[Player] =
		CurrentTime

	return true,
		Message
end

local function TeleportToTrain(Player)
	local TrainModel = TrainService.GetPlayerTrain(Player)

	if not TrainModel then
		return false, "Your train is not currently spawned."
	end

	local Locomotive = TrainService.GetLocomotive(TrainModel)

	if not Locomotive then
		return false, "Your locomotive could not be found."
	end

	local TargetCFrame =
		Locomotive:GetPivot()
		* TeleportToTrainOffset

	local Teleported =
		TeleportCharacter(
			Player,
			TargetCFrame
		)

	if not Teleported then
		return false, "Your character is not ready."
	end

	return true, "Teleported to your train."
end

local function TeleportHome(Player)
	local HomePart = GetHomePart(Player)

	if not HomePart then
		return false,
			"Your station needs a HomeSpawn or PlayerSpawn Part."
	end

	local TargetCFrame

	if HomePart.Name == "TrainSpawnOrigin" then
		TargetCFrame =
			HomePart.CFrame
			* HomeFallbackOffset
	else
		TargetCFrame =
			HomePart.CFrame
			* CFrame.new(0, 4, 0)
	end

	local Teleported =
		TeleportCharacter(
			Player,
			TargetCFrame
		)

	if not Teleported then
		return false, "Your character is not ready."
	end

	return true, "Teleported home."
end

---------------------------------------------------------------------
-- REMOTE
---------------------------------------------------------------------

TrainAction.OnServerInvoke = function(
	Player,
	ActionName
)
	if typeof(ActionName) ~= "string" then
		return false, "Invalid train action."
	end

	if ActionName == "ReturnTrain" then
		return ReturnTrain(Player)
	elseif ActionName == "TeleportToTrain" then
		return TeleportToTrain(Player)
	elseif ActionName == "Home" then
		return TeleportHome(Player)
	end

	return false, "Unknown train action."
end

Players.PlayerRemoving:Connect(function(Player)
	LastReturnTime[Player] = nil
end)
