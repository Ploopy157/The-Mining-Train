local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local StationService = require(
	ServerScriptService:WaitForChild("StationService")
)

local function MoveCharacterToStation(
	Player,
	Character
)
	local SpawnPart =
		StationService.GetPlayerSpawn(Player)

	if not SpawnPart then
		warn(
			"No player spawn was found for",
			Player.Name
		)

		return
	end

	local Root =
		Character:WaitForChild(
			"HumanoidRootPart",
			10
		)

	if not Root then
		return
	end

	task.wait()

	Character:PivotTo(
		SpawnPart.CFrame
		* CFrame.new(0, 4, 0)
	)

	Root.AssemblyLinearVelocity = Vector3.zero
	Root.AssemblyAngularVelocity = Vector3.zero
end

local function SetUpPlayer(Player)
	local Station =
		StationService.AssignStation(Player)

	if not Station then
		Player:Kick(
			"No station could be assigned."
		)

		return
	end

	Player:SetAttribute(
		"StationName",
		Station.Name
	)

	Player:SetAttribute(
		"StationNumber",
		tonumber(
			string.match(
				Station.Name,
				"%d+"
			)
		) or 0
	)

	Player.CharacterAdded:Connect(function(Character)
		MoveCharacterToStation(
			Player,
			Character
		)
	end)

	if Player.Character then
		task.defer(function()
			MoveCharacterToStation(
				Player,
				Player.Character
			)
		end)
	end
end

Players.PlayerAdded:Connect(SetUpPlayer)

for _, Player in Players:GetPlayers() do
	task.spawn(SetUpPlayer, Player)
end

Players.PlayerRemoving:Connect(function(Player)
	StationService.ReleaseStation(Player)
end)
