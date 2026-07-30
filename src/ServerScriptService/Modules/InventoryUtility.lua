local InventoryUtility = {}

function InventoryUtility.GetLoad(Inventory)
	local Total = 0

	for _, Quantity in Inventory do
		if typeof(Quantity) == "number" then
			Total += Quantity
		end
	end

	return Total
end

function InventoryUtility.GetRemainingSpace(Inventory, Capacity)
	return math.max(
		Capacity - InventoryUtility.GetLoad(Inventory),
		0
	)
end

function InventoryUtility.AddItem(
	Inventory,
	ItemName,
	Quantity,
	Capacity
)
	if Quantity <= 0 then
		return 0
	end

	local Space = InventoryUtility.GetRemainingSpace(
		Inventory,
		Capacity
	)

	local AmountAdded = math.min(Quantity, Space)

	if AmountAdded <= 0 then
		return 0
	end

	Inventory[ItemName] =
		(Inventory[ItemName] or 0)
		+ AmountAdded

	return AmountAdded
end

function InventoryUtility.RemoveItem(
	Inventory,
	ItemName,
	Quantity
)
	local CurrentQuantity = Inventory[ItemName] or 0
	local AmountRemoved = math.min(CurrentQuantity, Quantity)

	if AmountRemoved <= 0 then
		return 0
	end

	local NewQuantity = CurrentQuantity - AmountRemoved

	if NewQuantity <= 0 then
		Inventory[ItemName] = nil
	else
		Inventory[ItemName] = NewQuantity
	end

	return AmountRemoved
end

function InventoryUtility.TransferItem(
	SourceInventory,
	DestinationInventory,
	ItemName,
	RequestedQuantity,
	DestinationCapacity
)
	local AvailableQuantity =
		SourceInventory[ItemName] or 0

	local RemainingSpace =
		InventoryUtility.GetRemainingSpace(
			DestinationInventory,
			DestinationCapacity
		)

	local TransferQuantity = math.min(
		RequestedQuantity,
		AvailableQuantity,
		RemainingSpace
	)

	if TransferQuantity <= 0 then
		return 0
	end

	InventoryUtility.RemoveItem(
		SourceInventory,
		ItemName,
		TransferQuantity
	)

	InventoryUtility.AddItem(
		DestinationInventory,
		ItemName,
		TransferQuantity,
		DestinationCapacity
	)

	return TransferQuantity
end

return InventoryUtility