local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotes =
	ReplicatedStorage:WaitForChild("UpgradeShopRemotes")

local GetUpgradeShopData =
	Remotes:WaitForChild("GetUpgradeShopData")

local PurchaseUpgrade =
	Remotes:WaitForChild("PurchaseUpgrade")

local OpenUpgradeShop =
	Remotes:WaitForChild("OpenUpgradeShop")

local RefreshUpgradeShop =
	Remotes:WaitForChild("RefreshUpgradeShop")


local ResponsiveGui = require(ReplicatedStorage:WaitForChild("ResponsiveGui"))

local Gui = script.Parent
local ShopFrame = Gui:WaitForChild("ShopFrame")
local Header = ShopFrame:WaitForChild("Header")
local CloseButton = Header:WaitForChild("CloseButton")
local CashTag = Header:WaitForChild("CashTag")
local StatusLabel = ShopFrame:WaitForChild("StatusLabel")
local CategoryFrame = ShopFrame:WaitForChild("CategoryFrame")
local UpgradeList = ShopFrame:WaitForChild("UpgradeList")
local UpgradeTemplate =
	UpgradeList:WaitForChild("UpgradeTemplate")

local IsOpen = false
local IsLoading = false
local SelectedCategory = "All"
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
	for _, Child in UpgradeList:GetChildren() do
		if Child:IsA("Frame")
			and Child ~= UpgradeTemplate then

			Child:Destroy()
		end
	end
end

local function UpdateCategoryButtons()
	for _, Button in CategoryFrame:GetChildren() do
		if Button:IsA("TextButton") then
			local Category =
				Button:GetAttribute("Category")

			Button.BackgroundColor3 =
				Category == SelectedCategory
				and Color3.fromRGB(71, 92, 125)
				or Color3.fromRGB(45, 50, 61)
		end
	end
end

local function RefreshShop()
	if IsLoading then
		return
	end

	IsLoading = true
	ClearRows()

	local Success, Data = pcall(function()
		return GetUpgradeShopData:InvokeServer()
	end)

	if not Success or typeof(Data) ~= "table" then
		StatusLabel.Text =
			"Unable to load the upgrade shop."

		IsLoading = false
		return
	end

	CurrentData = Data
	CashTag.Value.Text =
		FormatMoney(Data.Cash or 0)

	local DisplayedCount = 0

	for _, UpgradeData in Data.Upgrades or {} do
		if SelectedCategory == "All"
			or UpgradeData.Category
				== SelectedCategory then

			DisplayedCount += 1

			local Row = UpgradeTemplate:Clone()
			Row.Name =
				UpgradeData.UpgradeId .. "Row"

			Row.LayoutOrder = DisplayedCount
			Row.Visible = true

			Row.UpgradeName.Text =
				UpgradeData.DisplayName

			Row.Description.Text =
				UpgradeData.Description

			Row.LevelLabel.Text = string.format(
				"Level %d / %d",
				UpgradeData.Level,
				UpgradeData.MaximumLevel
			)

			Row.CurrentValue.Text =
				"Current: "
				.. UpgradeData.FormattedValue

			if UpgradeData.IsMaximumLevel then
				Row.PurchaseButton.Text = "MAXIMUM\nLEVEL"
				Row.PurchaseButton.BackgroundColor3 = Color3.fromRGB(79, 83, 94)
				Row.PurchaseButton.Active = false

			elseif UpgradeData.LocomotiveLocked then
				Row.PurchaseButton.Text = "Larger Locomotive Required"
				Row.PurchaseButton.BackgroundColor3 = Color3.fromRGB(79, 83, 94)
				Row.PurchaseButton.Active = false

			else
				Row.PurchaseButton.Text = "BUY\n" .. FormatMoney(UpgradeData.Cost)

				Row.PurchaseButton.BackgroundColor3 =
					UpgradeData.CanAfford
					and Color3.fromRGB(53, 128, 76)
					or Color3.fromRGB(128, 66, 58)

				Row.PurchaseButton.Active = true

				Row.PurchaseButton.Activated:Connect(function()
					local RequestSuccess, Purchased, Result = pcall(function()
						return PurchaseUpgrade:InvokeServer(UpgradeData.UpgradeId)
					end)

					if not RequestSuccess then
						StatusLabel.Text = "Purchase request failed."
						return
					end

					if not Purchased then
						StatusLabel.Text = tostring(Result or "Purchase failed.")
						return
					end

					StatusLabel.Text = string.format(
						"Purchased %s level %d.",
						UpgradeData.DisplayName,
						Result.NewLevel
					)

					RefreshShop()
				end)
			end

			Row.Parent = UpgradeList
		end
	end

	if DisplayedCount == 0 then
		StatusLabel.Text =
			"No upgrades are available in this category."
	else
		StatusLabel.Text =
			"Select an upgrade to purchase."
	end

	IsLoading = false
end

local function SetOpen(ShouldOpen)
	IsOpen = ShouldOpen
	ShopFrame.Visible = ShouldOpen

	if ShouldOpen then
		RefreshShop()
	end
end

CloseButton.Activated:Connect(function()
	SetOpen(false)
end)

for _, Button in CategoryFrame:GetChildren() do
	if Button:IsA("TextButton") then
		Button.Activated:Connect(function()
			SelectedCategory =
				Button:GetAttribute("Category")
				or "All"

			UpdateCategoryButtons()
			RefreshShop()
		end)
	end
end

OpenUpgradeShop.OnClientEvent:Connect(function()
	SetOpen(true)
end)

RefreshUpgradeShop.OnClientEvent:Connect(function()
	if ShopFrame.Visible then
		RefreshShop()
	end
end)

ResponsiveGui.Bind(function(Layout)
	local IsCompact = Layout == ResponsiveGui.Layout.Compact

	if IsCompact then
		ShopFrame.Size = UDim2.new(1, -24, 1, -24)
		Header.Size = UDim2.new(1, 0, 0, 56)
		CategoryFrame.Position = UDim2.fromOffset(12, 68)
		CategoryFrame.Size = UDim2.new(1, -24, 0, 48)
		StatusLabel.Position = UDim2.fromOffset(12, 120)
		StatusLabel.Size = UDim2.new(1, -24, 0, 28)
		UpgradeList.Position = UDim2.fromOffset(12, 152)
		UpgradeList.Size = UDim2.new(1, -24, 1, -164)
		CashTag.Visible = false
	else
		ShopFrame.Size = Layout == ResponsiveGui.Layout.Medium
			and UDim2.new(0.9, 0, 0.88, 0)
			or UDim2.fromOffset(720, 540)

		Header.Size = UDim2.new(1, 0, 0, 72)
		CategoryFrame.Position = UDim2.fromOffset(16, 88)
		CategoryFrame.Size = UDim2.new(1, -32, 0, 44)
		StatusLabel.Position = UDim2.fromOffset(16, 132)
		StatusLabel.Size = UDim2.new(1, -32, 0, 22)
		UpgradeList.Position = UDim2.fromOffset(16, 160)
		UpgradeList.Size = UDim2.new(1, -32, 1, -176)
		CashTag.Visible = true
	end
end)

UserInputService.InputBegan:Connect(function(Input, GameProcessed)
	if GameProcessed or UserInputService:GetFocusedTextBox() then
		return
	end

	if Input.KeyCode == Enum.KeyCode.Escape and IsOpen then
		SetOpen(false)
	end
end)
