local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotes =
	ReplicatedStorage:WaitForChild("SellShopRemotes")

local GetSellShopData =
	Remotes:WaitForChild("GetSellShopData")

local SellOre =
	Remotes:WaitForChild("SellOre")

local SellAllOre =
	Remotes:WaitForChild("SellAllOre")

local OpenSellShop =
	Remotes:WaitForChild("OpenSellShop")

local RefreshSellShop =
	Remotes:WaitForChild("RefreshSellShop")

local Gui = script.Parent
local ShopFrame = Gui:WaitForChild("ShopFrame")
local Header = ShopFrame:WaitForChild("Header")

local CloseButton = Header:WaitForChild("CloseButton")
local TotalOresTag = Header:WaitForChild("TotalOresTag")
local TotalValueTag = Header:WaitForChild("TotalValueTag")
local CapacityTag = Header:WaitForChild("CapacityTag")

local StatusLabel = ShopFrame:WaitForChild("StatusLabel")
local InventoryList = ShopFrame:WaitForChild("InventoryList")
local ItemTemplate = InventoryList:WaitForChild("ItemTemplate")

local ControlsFrame = ShopFrame:WaitForChild("ControlsFrame")
local SelectedOreLabel =
	ControlsFrame:WaitForChild("SelectedOreLabel")

local QuantityBox =
	ControlsFrame:WaitForChild("QuantityBox")

local SellSelectedButton =
	ControlsFrame:WaitForChild("SellSelectedButton")

local SellOreStackButton =
	ControlsFrame:WaitForChild("SellOreStackButton")

local SellEverythingButton =
	ControlsFrame:WaitForChild("SellEverythingButton")

local IsOpen = false
local IsLoading = false
local SelectedOreName = nil
local SelectedOreQuantity = 0
local CurrentData = nil

local function FormatNumber(Number)
	local Formatted = tostring(math.floor(Number))
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
		if Child:IsA("TextButton")
			and Child ~= ItemTemplate then

			Child:Destroy()
		end
	end
end

local function HighlightSelection()
	for _, Child in InventoryList:GetChildren() do
		if Child:IsA("TextButton")
			and Child ~= ItemTemplate then

			local IsSelected =
				Child:GetAttribute("OreName")
				== SelectedOreName

			Child.BackgroundColor3 =
				IsSelected
				and Color3.fromRGB(69, 92, 73)
				or Color3.fromRGB(44, 49, 60)
		end
	end
end

local function SelectOre(OreData)
	SelectedOreName = OreData.Name
	SelectedOreQuantity = OreData.Quantity

	QuantityBox.Text =
		tostring(OreData.Quantity)

	SelectedOreLabel.Text = string.format(
		"Selected: %s  |  Maximum: %s  |  Worth: %s",
		OreData.Name,
		FormatNumber(OreData.Quantity),
		FormatMoney(OreData.TotalValue)
	)

	StatusLabel.Text = string.format(
		"Sell up to %s %s.",
		FormatNumber(OreData.Quantity),
		OreData.Name
	)

	HighlightSelection()
end

local function RefreshInventory()
	if IsLoading then
		return
	end

	IsLoading = true
	ClearRows()

	local Success, Data = pcall(function()
		return GetSellShopData:InvokeServer()
	end)

	if not Success or typeof(Data) ~= "table" then
		StatusLabel.Text = "Unable to load the shop."
		IsLoading = false
		return
	end

	CurrentData = Data

	TotalOresTag.Value.Text =
		FormatNumber(Data.TotalQuantity or 0)

	TotalValueTag.Value.Text =
		FormatMoney(Data.TotalValue or 0)

	CapacityTag.Value.Text = string.format(
		"%s | %s",
		FormatNumber(Data.BagLoad or 0),
		FormatNumber(Data.TrainLoad or "X")
	)

	local Items = Data.Items or {}

	for Index, OreData in Items do
		local Row = ItemTemplate:Clone()
		Row.Name = OreData.Name .. "Row"
		Row.LayoutOrder = Index
		Row.Visible = true
		Row:SetAttribute("OreName", OreData.Name)

		Row.OreName.Text = OreData.Name
		Row.Quantity.Text =
			FormatNumber(OreData.Quantity)

		Row.Value.Text =
			FormatMoney(OreData.Value)

		Row.TotalValue.Text =
			FormatMoney(OreData.TotalValue)

		Row.Activated:Connect(function()
			SelectOre(OreData)
		end)

		Row.Parent = InventoryList
	end

	if #Items == 0 then
		StatusLabel.Text = "Your bag is empty."
		SelectedOreName = nil
		SelectedOreQuantity = 0
		QuantityBox.Text = "0"
		SelectedOreLabel.Text = "Selected: None"
	elseif SelectedOreName then
		local FoundSelection = nil

		for _, OreData in Items do
			if OreData.Name == SelectedOreName then
				FoundSelection = OreData
				break
			end
		end

		if FoundSelection then
			SelectOre(FoundSelection)
		else
			SelectedOreName = nil
			SelectedOreQuantity = 0
			QuantityBox.Text = "0"
			SelectedOreLabel.Text = "Selected: None"
			StatusLabel.Text = "Select an ore to sell."
		end
	else
		StatusLabel.Text = "Select an ore to sell."
	end

	IsLoading = false
end

local function SetShopOpen(ShouldOpen)
	IsOpen = ShouldOpen
	ShopFrame.Visible = ShouldOpen

	if ShouldOpen then
		RefreshInventory()
	end
end

local function PerformSelectedSale(SellEntireStack)
	if not SelectedOreName then
		StatusLabel.Text = "Select an ore first."
		return
	end

	local Quantity

	if SellEntireStack then
		Quantity = SelectedOreQuantity
	else
		Quantity = tonumber(QuantityBox.Text)
	end

	if not Quantity then
		StatusLabel.Text = "Enter a valid quantity."
		return
	end

	Quantity = math.floor(Quantity)

	if Quantity <= 0 then
		StatusLabel.Text =
			"Quantity must be greater than zero."

		return
	end

	local Success, SoldSuccessfully, Result =
		pcall(function()
			return SellOre:InvokeServer(
				SelectedOreName,
				Quantity
			)
		end)

	if not Success then
		StatusLabel.Text = "The sale request failed."
		return
	end

	if not SoldSuccessfully then
		StatusLabel.Text =
			tostring(Result or "The sale failed.")

		return
	end

	local SoldQuantity = Result.Quantity or 0
	local CashEarned = Result.CashEarned or 0

	StatusLabel.Text = string.format(
		"Sold %s %s for %s.",
		FormatNumber(SoldQuantity),
		SelectedOreName,
		FormatMoney(CashEarned)
	)

	RefreshInventory()
end

local function PerformSellEverything()
	local Success, SoldSuccessfully, Result =
		pcall(function()
			return SellAllOre:InvokeServer()
		end)

	if not Success then
		StatusLabel.Text = "The sale request failed."
		return
	end

	if not SoldSuccessfully then
		StatusLabel.Text =
			tostring(Result or "The sale failed.")

		return
	end

	StatusLabel.Text = string.format(
		"Sold %s ores for %s.",
		FormatNumber(Result.Quantity or 0),
		FormatMoney(Result.CashEarned or 0)
	)

	SelectedOreName = nil
	SelectedOreQuantity = 0
	QuantityBox.Text = "0"
	SelectedOreLabel.Text = "Selected: None"

	RefreshInventory()
end

CloseButton.Activated:Connect(function()
	SetShopOpen(false)
end)

SellSelectedButton.Activated:Connect(function()
	PerformSelectedSale(false)
end)

SellOreStackButton.Activated:Connect(function()
	PerformSelectedSale(true)
end)

SellEverythingButton.Activated:Connect(
	PerformSellEverything
)

OpenSellShop.OnClientEvent:Connect(function()
	SetShopOpen(true)
end)

RefreshSellShop.OnClientEvent:Connect(function()
	if ShopFrame.Visible then
		RefreshInventory()
	end
end)

UserInputService.InputChanged:Connect(function(Input)
	if Input.UserInputType
		~= Enum.UserInputType.MouseWheel then

		return
	end

	if QuantityBox:IsFocused() then
		QuantityBox:ReleaseFocus(false)
	end
end)

local function UpdateResponsiveSizing()
	local Camera = Workspace.CurrentCamera

	if not Camera then
		return
	end

	local ViewportSize = Camera.ViewportSize
	local IsSmallScreen =
		ViewportSize.X < 720
		or ViewportSize.Y < 570

	if IsSmallScreen then
		ShopFrame.Size =
			UDim2.new(.8, -24, 1, -50)

		ShopFrame.Header.Title.TextSize = 21

		-- Hide the capacity tag on narrow screens.
		CapacityTag.Visible = ViewportSize.X >= 560
	else
		ShopFrame.Size =
			UDim2.fromOffset(650, 520)

		CapacityTag.Visible = true
	end
end

local function ConnectCamera()
	local Camera = Workspace.CurrentCamera

	if Camera then
		Camera:GetPropertyChangedSignal(
			"ViewportSize"
		):Connect(UpdateResponsiveSizing)
	end

	UpdateResponsiveSizing()
end

Workspace:GetPropertyChangedSignal(
	"CurrentCamera"
):Connect(ConnectCamera)

ConnectCamera()
