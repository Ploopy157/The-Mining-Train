local ServerStorage = game:GetService("ServerStorage")

local PickaxeService = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ItemDefinitions = require(
	ReplicatedStorage:WaitForChild("ItemDefinitions")
)

local PickaxeTemplates =
	ServerStorage:WaitForChild("Pickaxes")

local MinimumTemplateId = 1
local MaximumTemplateId = #PickaxeTemplates:GetChildren()

local function GetPickaxeDefinition(TemplateId)
	local PickaxeDefinitions = ItemDefinitions.Pickaxes

	if typeof(PickaxeDefinitions) ~= "table" then
		return nil
	end

	return PickaxeDefinitions[
		tostring(TemplateId)
	]
end

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

local function ValidateTemplate(Template, TemplateId)
	if not Template then
		return false,
			"Pickaxe template was not found."
	end

	if not Template:IsA("Tool") then
		return false,
			Template:GetFullName()
				.. " is not a Tool."
	end

	local Definition =
		GetPickaxeDefinition(TemplateId)

	if not Definition then
		return false,
			"Pickaxe definition "
				.. tostring(TemplateId)
				.. " was not found."
	end

	if typeof(Definition.Name) ~= "string"
		or Definition.Name == "" then

		return false,
			"Pickaxe definition "
				.. tostring(TemplateId)
				.. " has an invalid Name."
	end

	if typeof(Definition.Damage) ~= "number"
		or Definition.Damage <= 0 then

		return false,
			"Pickaxe definition "
				.. tostring(TemplateId)
				.. " has invalid Damage."
	end

	if typeof(Definition.Cooldown) ~= "number"
		or Definition.Cooldown <= 0 then

		return false,
			"Pickaxe definition "
				.. tostring(TemplateId)
				.. " has an invalid Cooldown."
	end

	if typeof(Definition.Range) ~= "number"
		or Definition.Range <= 0 then

		return false,
			"Pickaxe definition "
				.. tostring(TemplateId)
				.. " has an invalid Range."
	end

	return true, Definition
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

	local IsValid, DefinitionOrError =
	ValidateTemplate(
		Template,
		TemplateId
	)

	if not IsValid then
		return false, DefinitionOrError
	end

	local Definition = DefinitionOrError
	PickaxeService.RemovePlayerPickaxes(
		Player
	)

	local Pickaxe = Template:Clone()

	Pickaxe:SetAttribute(
	"PickaxeTemplateId",
	TemplateId
)

Pickaxe:SetAttribute(
	"IsPickaxe",
	true
)

Pickaxe:SetAttribute(
	"Damage",
	Definition.Damage
)

Pickaxe:SetAttribute(
	"Cooldown",
	Definition.Cooldown
)

Pickaxe:SetAttribute(
	"Range",
	Definition.Range
)

Pickaxe.Name =
	Definition.Name

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

function PickaxeService.GetEquippedStats(Player)
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

	local IsValid, DefinitionOrError =
		ValidateTemplate(
			Template,
			TemplateId
		)

	if not IsValid then
		return nil, DefinitionOrError
	end

	local Definition = DefinitionOrError

	return {
		TemplateId = TemplateId,
		DisplayName =
			Definition.DisplayName
			or Definition.Name,

		Damage =
			Definition.Damage,

		Cooldown =
			Definition.Cooldown,

		Range =
			Definition.Range,
	}
end

return PickaxeService
