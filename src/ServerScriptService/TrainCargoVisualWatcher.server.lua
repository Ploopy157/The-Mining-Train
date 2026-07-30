local Players = game:GetService("Players")
local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local ServerScriptService =
	game:GetService("ServerScriptService")

local PlayerDataService = require(
	ServerScriptService:WaitForChild(
		"PlayerDataService"
	)
)

local PickaxeService = require(
	ServerScriptService:WaitForChild(
		"PickaxeService"
	)
)

local OreInfoEvent =
	ReplicatedStorage:WaitForChild(
		"OreInfoEvent"
	)

local LastTemplateIds = {}
local CharacterConnections = {}

local function WaitForPlayerData(Player)
	while Player.Parent
		and not PlayerDataService.IsLoaded(Player) do

		task.wait(0.1)
	end

	return PlayerDataService.GetData(Player)
end

local function EquipSavedPickaxe(
	Player,
	ShowNotice
)
	local Data =
		PlayerDataService.GetData(Player)

	if not Data then
		return false
	end

	local TemplateId =
		PickaxeService.GetPlayerTemplateId(
			Data
		)

	local EquippedPickaxe =
		PickaxeService.GetEquippedPickaxe(
			Player
		)

	local Backpack =
		Player:FindFirstChildOfClass(
			"Backpack"
		)

	local ExistingTemplateId =
		EquippedPickaxe
			and EquippedPickaxe:GetAttribute(
				"PickaxeTemplateId"
			)

	if not ExistingTemplateId and Backpack then
		for _, Object in Backpack:GetChildren() do
			if Object:IsA("Tool") then
				local ObjectTemplateId =
					Object:GetAttribute(
						"PickaxeTemplateId"
					)

				if typeof(ObjectTemplateId)
					== "number" then

					ExistingTemplateId =
						ObjectTemplateId

					break
				end
			end
		end
	end

	if ExistingTemplateId == TemplateId then
		LastTemplateIds[Player] =
			TemplateId

		return true
	end

	local Success, Result =
		PickaxeService.GivePickaxe(
			Player,
			TemplateId
		)

	if not Success then
		warn(
			"Failed to equip pickaxe for "
				.. Player.Name
				.. ": "
				.. tostring(Result)
		)

		return false
	end

	LastTemplateIds[Player] =
		TemplateId

	if ShowNotice then
		OreInfoEvent:FireClient(
			Player,
			"Equipped "
				.. Result.Name
		)
	end

	return true
end

local function SetupPlayer(Player)
	if CharacterConnections[Player] then
		CharacterConnections[Player]
			:Disconnect()
	end

	CharacterConnections[Player] =
		Player.CharacterAdded:Connect(
			function()
				task.spawn(function()
					local Data =
						WaitForPlayerData(
							Player
						)

					if not Data then
						return
					end

					task.wait(0.25)

					EquipSavedPickaxe(
						Player,
						false
					)
				end)
			end
		)

	task.spawn(function()
		local Data =
			WaitForPlayerData(Player)

		if not Data then
			return
		end

		if Player.Character then
			task.wait(0.25)

			EquipSavedPickaxe(
				Player,
				false
			)
		end
	end)
end

Players.PlayerAdded:Connect(
	SetupPlayer
)

for _, Player in Players:GetPlayers() do
	SetupPlayer(Player)
end

task.spawn(function()
	while true do
		task.wait(0.5)

		for _, Player in Players:GetPlayers() do
			local Data =
				PlayerDataService.GetData(
					Player
				)

			if Data then
				local TemplateId =
					PickaxeService
						.GetPlayerTemplateId(
							Data
						)

				if LastTemplateIds[Player]
					~= TemplateId then

					EquipSavedPickaxe(
						Player,
						LastTemplateIds[Player]
							~= nil
					)
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(
	function(Player)
		LastTemplateIds[Player] = nil

		if CharacterConnections[Player] then
			CharacterConnections[Player]
				:Disconnect()

			CharacterConnections[Player] =
				nil
		end
	end
)
