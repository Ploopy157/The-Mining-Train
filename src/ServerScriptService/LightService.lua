local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataService"))
local ItemDefinitions = require(ReplicatedStorage:WaitForChild("ItemDefinitions"))

local LightsFolder = ServerStorage:WaitForChild("Lights")

local LightService = {}

local CharacterConnections = {}
local ServiceStarted = false

local function GetLightLevel(Player)
	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return 0
	end

	if typeof(Data.Upgrades) ~= "table" then
		Data.Upgrades = {}
	end

	local Level = tonumber(Data.Upgrades.Light) or 0

	return math.max(0, math.floor(Level))
end

local function GetLightDefinition(TemplateId)
	if typeof(ItemDefinitions.Lights) ~= "table" then
		return nil
	end

	return ItemDefinitions.Lights[tostring(TemplateId)]
end

local function RemoveExistingLamp(Character)
	local ExistingLamp = Character:FindFirstChild("EquippedLamp")

	if ExistingLamp then
		ExistingLamp:Destroy()
	end
end

local function GetMountPart(Character)
	return Character:FindFirstChild("Head")
		or Character:FindFirstChild("UpperTorso")
		or Character:FindFirstChild("Torso")
end

local function ApplyLightColor(Object, Definition)
	if typeof(Definition.LightColor) == "Color3" then
		Object.Color = Definition.LightColor
	end
end

local function ApplyPointLightDefinition(PointLight, Definition)
	PointLight.Brightness =
		tonumber(Definition.PointBrightness)
		or tonumber(Definition.Brightness)
		or PointLight.Brightness

	PointLight.Range =
		tonumber(Definition.PointRange)
		or tonumber(Definition.Range)
		or PointLight.Range

	ApplyLightColor(PointLight, Definition)

	PointLight.Enabled =
		PointLight.Brightness > 0
		and PointLight.Range > 0
end

local function ApplySpotLightDefinition(SpotLight, Definition)
	SpotLight.Brightness =
		tonumber(Definition.SpotBrightness)
		or tonumber(Definition.Brightness)
		or SpotLight.Brightness

	SpotLight.Range =
		tonumber(Definition.SpotRange)
		or tonumber(Definition.Range)
		or SpotLight.Range

	SpotLight.Angle =
		tonumber(Definition.SpotAngle)
		or SpotLight.Angle

	ApplyLightColor(SpotLight, Definition)

	SpotLight.Enabled =
		SpotLight.Brightness > 0
		and SpotLight.Range > 0
end

local function ApplySurfaceLightDefinition(SurfaceLight, Definition)
	SurfaceLight.Brightness =
		tonumber(Definition.SurfaceBrightness)
		or tonumber(Definition.PointBrightness)
		or tonumber(Definition.Brightness)
		or SurfaceLight.Brightness

	SurfaceLight.Range =
		tonumber(Definition.SurfaceRange)
		or tonumber(Definition.PointRange)
		or tonumber(Definition.Range)
		or SurfaceLight.Range

	if Definition.SurfaceAngle ~= nil then
		SurfaceLight.Angle =
			tonumber(Definition.SurfaceAngle)
			or SurfaceLight.Angle
	end

	ApplyLightColor(SurfaceLight, Definition)

	SurfaceLight.Enabled =
		SurfaceLight.Brightness > 0
		and SurfaceLight.Range > 0
end

local function ApplyLampDefinition(Lamp, Definition)
	if not Definition then
		warn("[LightService] A light definition was not provided.")
		return
	end

	for _, Object in Lamp:GetDescendants() do
		if Object:IsA("PointLight") then
			ApplyPointLightDefinition(Object, Definition)
		elseif Object:IsA("SpotLight") then
			ApplySpotLightDefinition(Object, Definition)
		elseif Object:IsA("SurfaceLight") then
			ApplySurfaceLightDefinition(Object, Definition)
		end
	end
end

local function PrepareLampParts(Lamp)
	for _, Object in Lamp:GetDescendants() do
		if Object:IsA("BasePart") then
			Object.Anchored = false
			Object.CanCollide = false
			Object.CanTouch = false
			Object.CanQuery = false
			Object.Massless = true
		end
	end
end

function LightService.ApplyToCharacter(Player, Character)
	if not Player or not Character then
		return false, "Player or Character was not provided."
	end

	RemoveExistingLamp(Character)

	local Level = GetLightLevel(Player)
	local TemplateId = tostring(Level + 1)
	local Definition = GetLightDefinition(TemplateId)
	local Template = LightsFolder:FindFirstChild(TemplateId)

	if not Definition then
		return false, "Light definition " .. TemplateId .. " was not found."
	end

	if not Template or not Template:IsA("Model") then
		return false, "Light template " .. TemplateId .. " was not found."
	end

	local MountPart = GetMountPart(Character)

	if not MountPart or not MountPart:IsA("BasePart") then
		return false, "Character mount part was not found."
	end

	local Lamp = Template:Clone()

	Lamp.Name = "EquippedLamp"
	Lamp:SetAttribute("LightLevel", Level)
	Lamp:SetAttribute("LightTemplateId", TemplateId)
	Lamp.Parent = Character

	local LampCore =
		Lamp.PrimaryPart
		or Lamp:FindFirstChild("LampCore", true)
		or Lamp:FindFirstChildWhichIsA("BasePart", true)

	if not LampCore then
		Lamp:Destroy()
		return false, "Light model does not contain a BasePart."
	end

	Lamp.PrimaryPart = LampCore

	PrepareLampParts(Lamp)
	ApplyLampDefinition(Lamp, Definition)

	Lamp:PivotTo(
		MountPart.CFrame
			* CFrame.new(0, 0.22, -0.55)
	)

	local Weld = Instance.new("WeldConstraint")

	Weld.Name = "LampWeld"
	Weld.Part0 = MountPart
	Weld.Part1 = LampCore
	Weld.Parent = LampCore

	return true, Lamp
end

function LightService.ApplyToPlayer(Player)
	if not Player then
		return false, "Player was not provided."
	end

	local Character = Player.Character

	if not Character then
		return false, "Player character is not loaded."
	end

	return LightService.ApplyToCharacter(Player, Character)
end

local function WaitForPlayerData(Player)
	local LoadedAttempts = 0

	while not PlayerDataService.IsLoaded(Player)
		and LoadedAttempts < 100 do

		LoadedAttempts += 1
		task.wait(0.1)
	end

	return PlayerDataService.IsLoaded(Player)
end

local function ApplyAfterCharacterSpawn(Player, Character)
	task.spawn(function()
		WaitForPlayerData(Player)
		task.wait(0.2)

		if not Player.Parent then
			return
		end

		if Player.Character ~= Character then
			return
		end

		local Success, Result = LightService.ApplyToCharacter(Player, Character)

		if not Success then
			warn(
				"[LightService] Could not apply light for "
					.. Player.Name
					.. ": "
					.. tostring(Result)
			)
		end
	end)
end

local function ConnectPlayer(Player)
	if CharacterConnections[Player] then
		CharacterConnections[Player]:Disconnect()
	end

	CharacterConnections[Player] =
		Player.CharacterAdded:Connect(function(Character)
			ApplyAfterCharacterSpawn(Player, Character)
		end)

	if Player.Character then
		ApplyAfterCharacterSpawn(Player, Player.Character)
	end
end

function LightService.Start()
	if ServiceStarted then
		return
	end

	ServiceStarted = true

	Players.PlayerAdded:Connect(ConnectPlayer)

	Players.PlayerRemoving:Connect(function(Player)
		if CharacterConnections[Player] then
			CharacterConnections[Player]:Disconnect()
			CharacterConnections[Player] = nil
		end
	end)

	for _, Player in Players:GetPlayers() do
		ConnectPlayer(Player)
	end
end

return LightService