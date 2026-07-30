local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local StationsFolder =
	Workspace:WaitForChild("Stations")

local StationTemplate =
	ServerStorage:WaitForChild("StationTemplate")

local StationService = {}

local StationSpacing = 100
local StationsPerRow = 10
local PlayerStations = {}

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------

local function GetStationNumber(Station)
	local NumberText =
		string.match(Station.Name, "^Station_(%d+)$")

	return tonumber(NumberText)
end

local function GetSortedStations()
	local Stations = {}

	for _, Station in StationsFolder:GetChildren() do
		if Station:IsA("Model") then
			table.insert(Stations, Station)
		end
	end

	table.sort(Stations, function(First, Second)
		local FirstNumber =
			GetStationNumber(First) or math.huge

		local SecondNumber =
			GetStationNumber(Second) or math.huge

		if FirstNumber == SecondNumber then
			return First.Name < Second.Name
		end

		return FirstNumber < SecondNumber
	end)

	return Stations
end

local function GetNextStationNumber()
	local HighestNumber = 0

	for _, Station in StationsFolder:GetChildren() do
		local StationNumber =
			GetStationNumber(Station)

		if StationNumber then
			HighestNumber = math.max(
				HighestNumber,
				StationNumber
			)
		end
	end

	return HighestNumber + 1
end

local function SetStationSign(
	Station,
	Player
)
	local SignText =
		Station:FindFirstChild(
			"OwnerLabel",
			true
		)
		or Station:FindFirstChild(
			"StationSign",
			true
		)

	if SignText
		and SignText:IsA("TextLabel") then

		SignText.Text =
			Player and Player.DisplayName or "AVAILABLE"
	end
end

local function SetStationOwnership(
	Station,
	Player
)
	if Player then
		Station:SetAttribute(
			"OwnerUserId",
			Player.UserId
		)

		Station:SetAttribute(
			"OwnerName",
			Player.Name
		)

		SetStationSign(Station, Player)
	else
		Station:SetAttribute("OwnerUserId", 0)
		Station:SetAttribute("OwnerName", "")
		SetStationSign(Station, nil)
	end
end

local function PositionNewStation(
	Station,
	StationNumber
)
	local FirstStation =
		StationsFolder:FindFirstChild("Station_1")

	if not FirstStation then
		return
	end

	local Row =
		math.floor(
			(StationNumber - 1)
			/ StationsPerRow
		)

	local Column =
		(StationNumber - 1)
		% StationsPerRow

	local Offset = Vector3.new(
		Row * StationSpacing,
		0,
		Column * StationSpacing
	)

	Station:PivotTo(
		FirstStation:GetPivot()
		+ Offset
	)
end

local function CreateStation()
	local StationNumber =
		GetNextStationNumber()

	local Station =
		StationTemplate:Clone()

	Station.Name =
		"Station_" .. StationNumber

	SetStationOwnership(Station, nil)
	Station.Parent = StationsFolder

	PositionNewStation(
		Station,
		StationNumber
	)

	return Station
end

---------------------------------------------------------------------
-- PUBLIC FUNCTIONS
---------------------------------------------------------------------

function StationService.GetPlayerStation(Player)
	local CachedStation =
		PlayerStations[Player]

	if CachedStation
		and CachedStation.Parent
		and CachedStation:GetAttribute(
			"OwnerUserId"
		) == Player.UserId then

		return CachedStation
	end

	for _, Station in GetSortedStations() do
		if Station:GetAttribute("OwnerUserId")
			== Player.UserId then

			PlayerStations[Player] = Station
			return Station
		end
	end

	return nil
end

function StationService.AssignStation(Player)
	local ExistingStation =
		StationService.GetPlayerStation(Player)

	if ExistingStation then
		return ExistingStation
	end

	for _, Station in GetSortedStations() do
		local OwnerUserId =
			Station:GetAttribute("OwnerUserId")
			or 0

		if OwnerUserId == 0 then
			SetStationOwnership(
				Station,
				Player
			)

			PlayerStations[Player] = Station
			return Station
		end
	end

	local NewStation = CreateStation()

	SetStationOwnership(
		NewStation,
		Player
	)

	PlayerStations[Player] = NewStation

	return NewStation
end

function StationService.ReleaseStation(Player)
	local Station =
		StationService.GetPlayerStation(Player)

	if Station then
		SetStationOwnership(Station, nil)
	end

	PlayerStations[Player] = nil
end

function StationService.GetTrainSpawnOrigin(Player)
	local Station =
		StationService.GetPlayerStation(Player)
		or StationService.AssignStation(Player)

	if not Station then
		return nil
	end

	local SpawnOrigin =
		Station:FindFirstChild(
			"TrainSpawnOrigin",
			true
		)

	if SpawnOrigin
		and SpawnOrigin:IsA("BasePart") then

		return SpawnOrigin
	end

	return nil
end

function StationService.GetPlayerSpawn(Player)
	local Station =
		StationService.GetPlayerStation(Player)
		or StationService.AssignStation(Player)

	if not Station then
		return nil
	end

	for _, SpawnName in {
		"PlayerSpawn",
		"HomeSpawn",
		"Spawn",
		"TrainSpawnOrigin",
	} do
		local SpawnPart =
			Station:FindFirstChild(
				SpawnName,
				true
			)

		if SpawnPart
			and SpawnPart:IsA("BasePart") then

			return SpawnPart
		end
	end

	return nil
end

function StationService.GetPlatform(Player)
	local Station =
		StationService.GetPlayerStation(Player)

	if not Station then
		return nil
	end

	local Platform =
		Station:FindFirstChild(
			"Platform",
			true
		)

	if Platform and Platform:IsA("BasePart") then
		return Platform
	end

	return nil
end

function StationService.GetAssignedStations()
	local Result = {}

	for _, Station in GetSortedStations() do
		local OwnerUserId =
			Station:GetAttribute("OwnerUserId")
			or 0

		if OwnerUserId ~= 0 then
			Result[OwnerUserId] = Station
		end
	end

	return Result
end

return StationService
