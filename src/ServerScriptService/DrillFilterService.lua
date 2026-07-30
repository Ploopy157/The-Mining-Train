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

function DrillFilterService.GetOreNames()
	local Names = {}

	for _, Template in OreTemplates:GetChildren() do
		if Template:IsA("BasePart") and Template:GetAttribute("IsStone") ~= true then
			table.insert(Names, Template.Name)
		end
	end

	table.sort(Names)
	return Names
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

	for _, OreName in DrillFilterService.GetOreNames() do
		table.insert(Entries, {
			Name = OreName,
			Destroy = Filter[OreName] == true,
		})
	end

	return Entries
end

return DrillFilterService
