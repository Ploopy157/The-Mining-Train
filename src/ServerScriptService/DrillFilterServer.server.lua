local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DrillFilterService = require(ServerScriptService:WaitForChild("DrillFilterService"))
local Remotes = ReplicatedStorage:WaitForChild("DrillFilterRemotes")
local GetFilter = Remotes:WaitForChild("GetDrillFilter")
local SetFilter = Remotes:WaitForChild("SetDrillFilter")

GetFilter.OnServerInvoke = function(Player)
	return DrillFilterService.GetClientData(Player)
end

SetFilter.OnServerEvent:Connect(function(Player, OreName, ShouldDestroy)
	DrillFilterService.SetDestroy(Player, OreName, ShouldDestroy)
end)
