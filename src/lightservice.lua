local Players =
	game:GetService("Players")

local ServerStorage =
	game:GetService("ServerStorage")

local ServerScriptService =
	game:GetService("ServerScriptService")

local PlayerDataService = require(
	ServerScriptService:WaitForChild(
		"PlayerDataService"
	)
)

local LightsFolder =
	ServerStorage:WaitForChild(
		"Lights"
	)

local LightService = {}

local CharacterConnections = {}
local ServiceStarted = false

local function GetLightLevel(Player)
	local Data =
		PlayerDataService.GetData(Player)

	if not Data then
		return 0
	end

	if typeof(Data.Upgrades) ~= "table" then
		Data.Upgrades = {}
	end

	local Level =
		tonumber(
			Data.Upgrades.Light
		) or 0

	return math.max(
		0,
		math.floor(Level)
	)
end

local function RemoveExistingLamp(Character)
	local ExistingLamp =
		Character:FindFirstChild(
			"EquippedLamp"
		)

	if ExistingLamp then
		ExistingLamp:Destroy()
	end
end

local function GetMountPart(Character)
	return Character:FindFirstChild("Head")
		or Character:FindFirstChild("UpperTorso")
		or Character:FindFirstChild("Torso")
end

function LightService.ApplyToCharacter(
	Player,
	Character
)
	if not Player
		or not Character then

		return false,
			"Player or Character was not provided."
	end

	RemoveExistingLamp(Character)

	local Level =
		GetLightLevel(Player)

	local TemplateId =
		tostring(Level + 1)

	local Template =
		LightsFolder:FindFirstChild(
			TemplateId
		)

	if not Template
		or not Template:IsA("Model") then

		return false,
			"Light template "
				.. TemplateId
				.. " was not found."
	end

	local MountPart =
		GetMountPart(Character)

	if not MountPart
		or not MountPart:IsA("BasePart") then

		return false,
			"Character mount part was not found."
	end

	local Lamp =
		Template:Clone()

	Lamp.Name = "EquippedLamp"
	Lamp:SetAttribute(
		"LightLevel",
		Level
	)

	Lamp:SetAttribute(
		"LightTemplateId",
		TemplateId
	)

	Lamp.Parent = Character

	local LampCore =
		Lamp.PrimaryPart
		or Lamp:FindFirstChild(
			"LampCore",
			true
		)
		or Lamp:FindFirstChildWhichIsA(
			"BasePart",
			true
		)

	if not LampCore then
		Lamp:Destroy()

		return false,
			"Light model does not contain a BasePart."
	end

	Lamp.PrimaryPart = LampCore

	for _, Object in Lamp:GetDescendants() do
		if Object:IsA("BasePart") then
			Object.Anchored = false
			Object.CanCollide = false
			Object.CanTouch = false
			Object.CanQuery = false
			Object.Massless = true
		end
	end

	Lamp:PivotTo(
		MountPart.CFrame
		* CFrame.new(
			0,
			0.22,
			-0.55
		)
	)

	local Weld =
		Instance.new("WeldConstraint")

	Weld.Name = "LampWeld"
	Weld.Part0 = MountPart
	Weld.Part1 = LampCore
	Weld.Parent = LampCore

	return true,
		Lamp
end

function LightService.ApplyToPlayer(Player)
	if not Player then
		return false,
			"Player was not provided."
	end

	local Character =
		Player.Character

	if not Character then
		return false,
			"Player character is not loaded."
	end

	return LightService.ApplyToCharacter(
		Player,
		Character
	)
end

local function ConnectPlayer(Player)
	if CharacterConnections[Player] then
		CharacterConnections[Player]
			:Disconnect()
	end

	CharacterConnections[Player] =
		Player.CharacterAdded:Connect(
			function(Character)
				task.spawn(function()
					local LoadedAttempts = 0

					while not PlayerDataService
						.IsLoaded(Player)
						and LoadedAttempts < 100 do

						LoadedAttempts += 1
						task.wait(0.1)
					end

					task.wait(0.2)

					LightService.ApplyToCharacter(
						Player,
						Character
					)
				end)
			end
		)

	if Player.Character then
		task.spawn(function()
			local LoadedAttempts = 0

			while not PlayerDataService
				.IsLoaded(Player)
				and LoadedAttempts < 100 do

				LoadedAttempts += 1
				task.wait(0.1)
			end

			LightService.ApplyToCharacter(
				Player,
				Player.Character
			)
		end)
	end
end

function LightService.Start()
	if ServiceStarted then
		return
	end

	ServiceStarted = true

	Players.PlayerAdded:Connect(
		ConnectPlayer
	)

	Players.PlayerRemoving:Connect(
		function(Player)
			if CharacterConnections[Player] then
				CharacterConnections[Player]
					:Disconnect()

				CharacterConnections[Player] = nil
			end
		end
	)

	for _, Player in Players:GetPlayers() do
		ConnectPlayer(Player)
	end
end

return LightService
