local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ResponsiveGui = require(ReplicatedStorage:WaitForChild("ResponsiveGui"))

local GetInventory = ReplicatedStorage:WaitForChild("GetInventory")

local Gui = script.Parent
local HomeGui = Gui.Parent:WaitForChild("HomeGui")
local BagButton = HomeGui.MainHudContainer:WaitForChild("BagButton")
local InventoryFrame = Gui:WaitForChild("InventoryFrame")
local Header = InventoryFrame:WaitForChild("Header")
local CloseButton = Header:WaitForChild("CloseButton")
local TotalOresTag = Header:WaitForChild("TotalOresTag")
local TotalValueTag = Header:WaitForChild("TotalValueTag")
local StatusLabel = InventoryFrame:WaitForChild("StatusLabel")
local TableHeader = InventoryFrame:WaitForChild("TableHeader")
local NameHeader = TableHeader:WaitForChild("NameHeader")
local QuantityHeader = TableHeader:WaitForChild("QuantityHeader")
local ValueHeader = TableHeader:WaitForChild("ValueHeader")
local TotalHeader = TableHeader:WaitForChild("TotalHeader")
local InventoryList = InventoryFrame:WaitForChild("InventoryList")
local ItemTemplate = InventoryList:WaitForChild("ItemTemplate")

local BackpackKey = Enum.KeyCode.B
local IsOpen = false
local IsLoading = false


local CurrentLayout = ResponsiveGui.Layout.Desktop

local function ApplyRowLayout(Row, IsCompact)
	local OreName = Row:WaitForChild("OreName")
	local Quantity = Row:WaitForChild("Quantity")
	local Value = Row:WaitForChild("Value")
	local TotalValue = Row:WaitForChild("TotalValue")

	if IsCompact then
		OreName.Position = UDim2.fromScale(0, 0)
		OreName.Size = UDim2.new(0.55, -8, 1, 0)

		Quantity.Position = UDim2.fromScale(0.55, 0)
		Quantity.Size = UDim2.new(0.2, -4, 1, 0)

		Value.Visible = false

		TotalValue.Position = UDim2.fromScale(0.75, 0)
		TotalValue.Size = UDim2.new(0.25, -8, 1, 0)
	else
		OreName.Position = UDim2.fromScale(0, 0)
		OreName.Size = UDim2.new(0.4, -8, 1, 0)

		Quantity.Position = UDim2.fromScale(0.4, 0)
		Quantity.Size = UDim2.new(0.15, -4, 1, 0)

		Value.Visible = true
		Value.Position = UDim2.fromScale(0.55, 0)
		Value.Size = UDim2.new(0.2, -4, 1, 0)

		TotalValue.Position = UDim2.fromScale(0.75, 0)
		TotalValue.Size = UDim2.new(0.25, -8, 1, 0)
	end
end

local function ApplyHeaderLayout(IsCompact)
	NameHeader.Position = UDim2.fromScale(0, 0)
	NameHeader.Size = IsCompact
		and UDim2.new(0.55, -8, 1, 0)
		or UDim2.new(0.4, -8, 1, 0)

	QuantityHeader.Position = IsCompact
		and UDim2.fromScale(0.55, 0)
		or UDim2.fromScale(0.4, 0)

	QuantityHeader.Size = IsCompact
		and UDim2.new(0.2, -4, 1, 0)
		or UDim2.new(0.15, -4, 1, 0)

	ValueHeader.Visible = not IsCompact

	if not IsCompact then
		ValueHeader.Position = UDim2.fromScale(0.55, 0)
		ValueHeader.Size = UDim2.new(0.2, -4, 1, 0)
	end

	TotalHeader.Position = UDim2.fromScale(0.75, 0)
	TotalHeader.Size = UDim2.new(0.25, -8, 1, 0)
	TotalHeader.Text = IsCompact and "TOTAL" or "TOTAL VALUE"
end

local function ApplyExistingRowLayouts(IsCompact)
	for _, Row in InventoryList:GetChildren() do
		if Row:IsA("Frame") then
			ApplyRowLayout(Row, IsCompact)
		end
	end
end

ResponsiveGui.Bind(function(Layout)
	CurrentLayout = Layout

	local IsCompact = Layout == ResponsiveGui.Layout.Compact

	if IsCompact then
		InventoryFrame.Size = UDim2.new(1, -24, 1, -24)

		Header.Size = UDim2.new(1, 0, 0, 56)

		StatusLabel.Position = UDim2.fromOffset(12, 62)
		StatusLabel.Size = UDim2.new(1, -24, 0, 24)

		TableHeader.Position = UDim2.fromOffset(12, 90)
		TableHeader.Size = UDim2.new(1, -24, 0, 30)

		InventoryList.Position = UDim2.fromOffset(12, 124)
		InventoryList.Size = UDim2.new(1, -24, 1, -136)

		TotalOresTag.Visible = true
		TotalValueTag.Visible = false
	elseif Layout == ResponsiveGui.Layout.Medium then
		InventoryFrame.Size = UDim2.new(0.9, 0, 0.88, 0)

		Header.Size = UDim2.new(1, 0, 0, 72)

		StatusLabel.Position = UDim2.fromOffset(16, 79)
		StatusLabel.Size = UDim2.new(1, -32, 0, 25)

		TableHeader.Position = UDim2.fromOffset(16, 108)
		TableHeader.Size = UDim2.new(1, -32, 0, 32)

		InventoryList.Position = UDim2.fromOffset(16, 144)
		InventoryList.Size = UDim2.new(1, -32, 1, -160)

		TotalOresTag.Visible = true
		TotalValueTag.Visible = true
	else
		InventoryFrame.Size = UDim2.fromOffset(760, 560)

		Header.Size = UDim2.new(1, 0, 0, 72)

		StatusLabel.Position = UDim2.fromOffset(16, 79)
		StatusLabel.Size = UDim2.new(1, -32, 0, 25)

		TableHeader.Position = UDim2.fromOffset(16, 108)
		TableHeader.Size = UDim2.new(1, -32, 0, 32)

		InventoryList.Position = UDim2.fromOffset(16, 144)
		InventoryList.Size = UDim2.new(1, -32, 1, -160)

		TotalOresTag.Visible = true
		TotalValueTag.Visible = true
	end

	ApplyHeaderLayout(IsCompact)
	ApplyExistingRowLayouts(IsCompact)
end)

local function FormatNumber(Number)
	local Formatted = tostring(math.floor(tonumber(Number) or 0))
	local Replaced

	repeat
		Formatted, Replaced = string.gsub(
			Formatted,
			"^(-?%d+)(%d%d%d)",
			"%1,%2"
		)
	until Replaced == 0

	return Formatted
end

local function FormatMoney(Number)
	return "$" .. FormatNumber(Number)
end

local function ClearRows()
	for _, Child in InventoryList:GetChildren() do
		if Child:IsA("Frame") and Child ~= ItemTemplate then
			Child:Destroy()
		end
	end
end

local function RefreshInventory()
	if IsLoading then
		return
	end

	IsLoading = true
	StatusLabel.Text = "Loading inventory..."
	ClearRows()

	local Success, InventoryData = pcall(function()
		return GetInventory:InvokeServer()
	end)

	if not Success or typeof(InventoryData) ~= "table" then
		StatusLabel.Text = "Unable to load inventory."
		IsLoading = false
		return
	end

	local Items = InventoryData.Items or {}
	local TotalQuantity = tonumber(InventoryData.TotalQuantity) or 0
	local Capacity = tonumber(InventoryData.Capacity) or 0
	local InventoryValue = tonumber(InventoryData.TotalValue) or 0

	TotalOresTag.TagValue.Text = string.format(
		"%s / %s",
		FormatNumber(TotalQuantity),
		FormatNumber(Capacity)
	)

	TotalValueTag.TagValue.Text = FormatMoney(InventoryValue)

	table.sort(Items, function(FirstItem, SecondItem)
		if FirstItem.ItemType ~= SecondItem.ItemType then
			return FirstItem.ItemType == "Ore"
		end

		return FirstItem.Name:lower() < SecondItem.Name:lower()
	end)

	for Index, ItemData in Items do
		local Row = ItemTemplate:Clone()

		Row.Name = ItemData.Name .. "Row"
		Row.LayoutOrder = Index
		Row.Visible = true
		Row:SetAttribute("ItemType", ItemData.ItemType or "Ore")

		Row.OreName.Text = ItemData.Name
		Row.Quantity.Text = FormatNumber(ItemData.Quantity)
		Row.Value.Text = FormatMoney(ItemData.Value)
		Row.TotalValue.Text = FormatMoney(ItemData.TotalValue)
		ApplyRowLayout(Row, CurrentLayout == ResponsiveGui.Layout.Compact)
		Row.Parent = InventoryList
	end

	if #Items == 0 then
		StatusLabel.Text = "Your bag is empty."
	else
		StatusLabel.Text = string.format(
			"%d item type%s",
			#Items,
			#Items == 1 and "" or "s"
		)
	end

	IsLoading = false
end

local function SetBagOpen(ShouldOpen)
	IsOpen = ShouldOpen
	InventoryFrame.Visible = IsOpen

	if IsOpen then
		RefreshInventory()
	end
end

local function ToggleBag()
	SetBagOpen(not IsOpen)
end


BagButton.Activated:Connect(ToggleBag)

CloseButton.Activated:Connect(function()
	SetBagOpen(false)
end)

UserInputService.InputBegan:Connect(function(Input, GameProcessed)
	if GameProcessed or UserInputService:GetFocusedTextBox() then
		return
	end

	if Input.KeyCode == BackpackKey then
		ToggleBag()
	end
end)

