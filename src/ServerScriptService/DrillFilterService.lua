local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataService"))
local OreTemplates = ServerStorage:WaitForChild("Ores")

local DrillFilterService = {}

local function GetFilter(Data)
	Data.Train = Data.Train or {}
	Data.Train.DrillDestroyOres = Data.Train.DrillDestroyOres or {}

	return Data.Train.DrillDestroyOres
end

function DrillFilterService.GetOreEntries()
	local Entries = {}

	for _, Template in OreTemplates:GetChildren() do
		if not Template:IsA("BasePart") then
			continue
		end

		if Template:GetAttribute("IsStone") == true then
			continue
		end

		local Value = tonumber(Template:GetAttribute("Value")) or 0

		table.insert(Entries, {
			Name = Template.Name,
			Value = Value,
		})
	end

	table.sort(Entries, function(First, Second)
		if First.Value == Second.Value then
			return First.Name < Second.Name
		end

		return First.Value < Second.Value
	end)

	return Entries
end

function DrillFilterService.IsValidOre(OreName)
	local Template = typeof(OreName) == "string" and OreTemplates:FindFirstChild(OreName)

	return Template ~= nil
		and Template:IsA("BasePart")
		and Template:GetAttribute("IsStone") ~= true
end

function DrillFilterService.ShouldDestroy(Player, OreName)
	local Data = PlayerDataService.GetData(Player)

	if not Data or not DrillFilterService.IsValidOre(OreName) then
		return false
	end

	return GetFilter(Data)[OreName] == true
end

function DrillFilterService.SetDestroy(Player, OreName, ShouldDestroy)
	local Data = PlayerDataService.GetData(Player)

	if not Data or not DrillFilterService.IsValidOre(OreName) or typeof(ShouldDestroy) ~= "boolean" then
		return false
	end

	local Filter = GetFilter(Data)
	Filter[OreName] = ShouldDestroy and true or nil

	return true
end

function DrillFilterService.GetClientData(Player)
	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return nil
	end

	local Filter = GetFilter(Data)
	local Entries = {}

	for _, OreEntry in DrillFilterService.GetOreEntries() do
		table.insert(Entries, {
			Name = OreEntry.Name,
			Value = OreEntry.Value,
			Destroy = Filter[OreEntry.Name] == true,
		})
	end

	return Entries
end

return DrillFilterService
