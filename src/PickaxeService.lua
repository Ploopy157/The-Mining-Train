local ServerStorage = game:GetService("ServerStorage")

local PickaxeService = {}

local PickaxeTemplates =
	ServerStorage:WaitForChild("Pickaxes")

local MinimumTemplateId = 1
local MaximumTemplateId = #(game.ServerStorage.Pickaxes:GetChildren())-1

local function NormalizeTemplateId(TemplateId)
	TemplateId =
		math.floor(
			tonumber(TemplateId)
				or MinimumTemplateId
		)

	return math.clamp(
		TemplateId,
		MinimumTemplateId,
		MaximumTemplateId
	)
end

local function IsPlayerPickaxe(Object)
	return Object:IsA("Tool")
		and typeof(
			Object:GetAttribute(
				"PickaxeTemplateId"
			)
		) == "number"
end

local function ValidateTemplate(Template)
	if not Template then
		return false,
			"Pickaxe template was not found."
	end

	if not Template:IsA("Tool") then
		return false,
			Template:GetFullName()
				.. " is not a Tool."
	end

	local DisplayName =
		Template:GetAttribute("Name")

	local Damage =
		Template:GetAttribute("Damage")

	local Cooldown =
		Template:GetAttribute("Cooldown")

	if typeof(DisplayName) ~= "string"
		or DisplayName == "" then

		return false,
			Template:GetFullName()
				.. " has an invalid Name attribute."
	end

	if typeof(Damage) ~= "number"
		or Damage <= 0 then

		return false,
			Template:GetFullName()
				.. " has an invalid Damage attribute."
	end

	if typeof(Cooldown) ~= "number"
		or Cooldown <= 0 then

		return false,
			Template:GetFullName()
				.. " has an invalid Cooldown attribute."
	end

	return true
end

local function RemovePickaxesFromContainer(
	Container
)
	if not Container then
		return
	end

	for _, Object in Container:GetChildren() do
		if IsPlayerPickaxe(Object) then
			Object:Destroy()
		end
	end
end

function PickaxeService.GetTemplate(
	TemplateId
)
	TemplateId =
		NormalizeTemplateId(TemplateId)

	return PickaxeTemplates:FindFirstChild(
		tostring(TemplateId)
	)
end

function PickaxeService.GetTemplateIdForUpgradeLevel(
	UpgradeLevel
)
	UpgradeLevel =
		math.max(
			0,
			math.floor(
				tonumber(UpgradeLevel) or 0
			)
		)

	return NormalizeTemplateId(
		UpgradeLevel + 1
	)
end

function PickaxeService.GetPlayerTemplateId(
	PlayerData
)
	if typeof(PlayerData) ~= "table" then
		return MinimumTemplateId
	end

	if typeof(PlayerData.Upgrades) ~= "table" then
		return MinimumTemplateId
	end

	return PickaxeService
		.GetTemplateIdForUpgradeLevel(
			PlayerData.Upgrades.PickaxeDamage
		)
end

function PickaxeService.RemovePlayerPickaxes(
	Player
)
	if not Player then
		return
	end

	RemovePickaxesFromContainer(
		Player:FindFirstChildOfClass(
			"Backpack"
		)
	)

	RemovePickaxesFromContainer(
		Player.Character
	)
end

function PickaxeService.GivePickaxe(
	Player,
	TemplateId
)
	if not Player or not Player.Parent then
		return false,
			"Player is no longer connected."
	end

	local Backpack =
		Player:FindFirstChildOfClass(
			"Backpack"
		)

	if not Backpack then
		return false,
			"Player Backpack was not found."
	end

	TemplateId =
		NormalizeTemplateId(TemplateId)

	local Template =
		PickaxeService.GetTemplate(
			TemplateId
		)

	local IsValid, ValidationError =
		ValidateTemplate(Template)

	if not IsValid then
		return false, ValidationError
	end

	PickaxeService.RemovePlayerPickaxes(
		Player
	)

	local Pickaxe = Template:Clone()

	Pickaxe:SetAttribute(
		"PickaxeTemplateId",
		TemplateId
	)

	Pickaxe.Name =
		Template:GetAttribute("Name")

	Pickaxe.Parent = Backpack

	return true, Pickaxe
end

function PickaxeService.GetEquippedPickaxe(
	Player
)
	local Character =
		Player and Player.Character

	if not Character then
		return nil
	end

	for _, Object in Character:GetChildren() do
		if IsPlayerPickaxe(Object) then
			return Object
		end
	end

	return nil
end

function PickaxeService.GetEquippedStats(
	Player
)
	local Pickaxe =
		PickaxeService.GetEquippedPickaxe(
			Player
		)

	if not Pickaxe then
		return nil,
			"Equip a pickaxe first."
	end

	local TemplateId =
		Pickaxe:GetAttribute(
			"PickaxeTemplateId"
		)

	local Template =
		PickaxeService.GetTemplate(
			TemplateId
		)

	local IsValid, ValidationError =
		ValidateTemplate(Template)

	if not IsValid then
		return nil, ValidationError
	end

	return {
		TemplateId = TemplateId,
		DisplayName =
			Template:GetAttribute("Name"),

		Damage =
			Template:GetAttribute("Damage"),

		Cooldown =
			Template:GetAttribute("Cooldown"),
	}
end

return PickaxeService
