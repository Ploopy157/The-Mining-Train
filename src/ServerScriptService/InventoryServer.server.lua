local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local GetInventory = ReplicatedStorage:WaitForChild("GetInventory")
local OreTemplates = ServerStorage:WaitForChild("Ores")

local ItemDefinitions = require(
	ReplicatedStorage:WaitForChild("ItemDefinitions")
)

local PlayerDataService = require(
	ServerScriptService:WaitForChild("PlayerDataService")
)

local function GetItemValue(ItemName)
	local IngotDefinition =
		ItemDefinitions.Ingots[ItemName]

	if IngotDefinition then
		return math.max(
			tonumber(IngotDefinition.Value) or 0,
			0
		)
	end

	local OreTemplate =
		OreTemplates:FindFirstChild(ItemName)

	if not OreTemplate then
		return 0
	end

	return math.max(
		tonumber(
			OreTemplate:GetAttribute("Value")
		) or 0,
		0
	)
end

local function AddInventoryRows(
	CombinedItems,
	Inventory,
	ItemType
)
	if typeof(Inventory) ~= "table" then
		return
	end

	for ItemName, Quantity in Inventory do
		if typeof(ItemName) == "string"
			and typeof(Quantity) == "number"
			and Quantity > 0 then

			local Existing =
				CombinedItems[ItemName]

			if not Existing then
				Existing = {
					Name = ItemName,
					Quantity = 0,
					ItemType = ItemType,
				}

				CombinedItems[ItemName] =
					Existing
			end

			Existing.Quantity += Quantity

			if ItemType == "Ingot" then
				Existing.ItemType = "Ingot"
			end
		end
	end
end

GetInventory.OnServerInvoke = function(Player)
	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return {
			Items = {},
			TotalQuantity = 0,
			TotalValue = 0,
			Capacity = 0,
		}
	end

	if typeof(Data.Inventory) ~= "table" then
		Data.Inventory = {}
	end

	if typeof(Data.Items) ~= "table" then
		Data.Items = {}
	end

	if typeof(Data.Stats) ~= "table" then
		Data.Stats = {}
	end

	local CombinedItems = {}

	AddInventoryRows(
		CombinedItems,
		Data.Inventory,
		"Ore"
	)

	AddInventoryRows(
		CombinedItems,
		Data.Items,
		"Ingot"
	)

	local Items = {}
	local TotalQuantity = 0
	local TotalValue = 0

	for ItemName, ItemData in CombinedItems do
		local ItemValue =
			GetItemValue(ItemName)

		local ItemTotalValue =
			ItemData.Quantity * ItemValue

		TotalQuantity += ItemData.Quantity
		TotalValue += ItemTotalValue

		table.insert(Items, {
			Name = ItemName,
			Quantity = ItemData.Quantity,
			Value = ItemValue,
			TotalValue = ItemTotalValue,
			ItemType = ItemData.ItemType,
		})
	end

	table.sort(Items, function(First, Second)
		if First.ItemType ~= Second.ItemType then
			return First.ItemType == "Ore"
		end

		return First.Name:lower()
			< Second.Name:lower()
	end)

	return {
		Items = Items,
		TotalQuantity = TotalQuantity,
		TotalValue = TotalValue,
		Capacity =
			tonumber(
				Data.Stats.BackpackCapacity
			) or 2,
	}
end

