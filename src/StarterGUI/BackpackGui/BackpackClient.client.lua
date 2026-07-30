local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

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
local InventoryList = InventoryFrame:WaitForChild("InventoryList")
local ItemTemplate = InventoryList:WaitForChild("ItemTemplate")

local BackpackKey = Enum.KeyCode.B
local IsOpen = false
local IsLoading = false

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

local function UpdateResponsiveSizing()
	local Camera = Workspace.CurrentCamera

	if not Camera then
		return
	end

	local ViewportSize = Camera.ViewportSize
	local IsSmallScreen = ViewportSize.X < 720 or ViewportSize.Y < 560

	if IsSmallScreen then
		InventoryFrame.Size = UDim2.new(0.8, -24, 1, -50)
	else
		InventoryFrame.Size = UDim2.fromOffset(630, 500)
	end
end

local function ConnectCamera()
	local Camera = Workspace.CurrentCamera

	if Camera then
		Camera:GetPropertyChangedSignal("ViewportSize"):Connect(
			UpdateResponsiveSizing
		)
	end

	UpdateResponsiveSizing()
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

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(
	ConnectCamera
)

ConnectCamera()