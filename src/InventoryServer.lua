local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local GetInventory = ReplicatedStorage:WaitForChild("GetInventory")
local OreTemplates = ServerStorage:WaitForChild("Ores")

local PlayerDataService = require(
	ServerScriptService:WaitForChild("PlayerDataService")
)

GetInventory.OnServerInvoke = function(Player)
	local Data = PlayerDataService.GetData(Player)

	if not Data or typeof(Data.Inventory) ~= "table" then
		return {
			Items = {},
			TotalQuantity = 0,
			TotalValue = 0,
		}
	end

	local Items = {}
	local TotalQuantity = 0
	local InventoryValue = 0

	for OreName, Quantity in Data.Inventory do
		if typeof(OreName) == "string"
			and typeof(Quantity) == "number"
			and Quantity > 0 then

			local OreTemplate = OreTemplates:FindFirstChild(OreName)
			local OreValue = 0

			if OreTemplate then
				OreValue = OreTemplate:GetAttribute("Value") or 0
			end

			local OreTotalValue = Quantity * OreValue

			TotalQuantity += Quantity
			InventoryValue += OreTotalValue

			table.insert(Items, {
				Name = OreName,
				Quantity = Quantity,
				Value = OreValue,
				TotalValue = OreTotalValue,
			})
		end
	end

	return {
		Items = Items,
		TotalQuantity = TotalQuantity,
		TotalValue = InventoryValue,
	}
end
