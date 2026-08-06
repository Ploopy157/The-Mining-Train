local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local TrainRemotes = ReplicatedStorage:WaitForChild("TrainRemotes")
local GetTrainOverview = TrainRemotes:WaitForChild("GetTrainOverview")
local TransferCarOre = TrainRemotes:WaitForChild("TransferTrainOre")
local OpenCarMenu = TrainRemotes:WaitForChild("OpenCarMenu")
local RefreshTrainGui = TrainRemotes:WaitForChild("RefreshTrainGui")
local DepositAllToCar = TrainRemotes:WaitForChild("DepositAllToCar")

local ResponsiveGui = require(ReplicatedStorage:WaitForChild("ResponsiveGui"))




local Gui = script.Parent
local HomeGui = Gui.Parent:WaitForChild("HomeGui")
local TrainButton = HomeGui.MainHudContainer:WaitForChild("TrainButton")
local TrainFrame = Gui:WaitForChild("TrainFrame")
local Header = TrainFrame:WaitForChild("Header")
local CloseButton = Header:WaitForChild("CloseButton")
local CarsTag = Header:WaitForChild("CarsTag")
local LoadTag = Header:WaitForChild("LoadTag")
local ValueTag = Header:WaitForChild("ValueTag")
local StatusLabel = TrainFrame:WaitForChild("StatusLabel")
local CarsList = TrainFrame:WaitForChild("CarsList")
local SelectedPanel = TrainFrame:WaitForChild("SelectedPanel")
local ActionBar = TrainFrame:WaitForChild("ActionBar")
local LocomotiveSelector = TrainFrame:WaitForChild("LocomotiveSelector")
local DrillSelector = TrainFrame:WaitForChild("DrillSelector")

local CarButtonTemplate = CarsList:WaitForChild("CarButtonTemplate")
local SelectedPanel = TrainFrame:WaitForChild("SelectedPanel")
local SelectedTitle = SelectedPanel:WaitForChild("SelectedTitle")
local OreList = SelectedPanel:WaitForChild("OreList")
local OreRowTemplate = OreList:WaitForChild("OreRowTemplate")

local MobileTabs = TrainFrame:WaitForChild("MobileTabs")
local CarsButton = MobileTabs:WaitForChild("CarsButton")
local LoadButton = MobileTabs:WaitForChild("LoadButton")
local EquipmentButton = MobileTabs:WaitForChild("EquipmentButton")

local TransferFrame = Gui:WaitForChild("TransferFrame")
local TransferTitle = TransferFrame:WaitForChild("TransferTitle")
local TransferClose = TransferFrame:WaitForChild("CloseButton")
local MessageLabel = TransferFrame:WaitForChild("MessageLabel")
local BackpackList = TransferFrame.BackpackPanel:WaitForChild("ItemList")

	

local CarList =
	TransferFrame.CarPanel:WaitForChild("ItemList")

local TransferControls =
	TransferFrame:WaitForChild("TransferControls")

local QuantityBox =
	TransferControls:WaitForChild("QuantityBox")

local DepositButton =
	TransferControls:WaitForChild("DepositButton")

local WithdrawButton =
	TransferControls:WaitForChild("WithdrawButton")

local TransferItemTemplate =
	Gui:WaitForChild("ItemTemplate")

local DepositAllButton =
	TransferControls:WaitForChild("DepositAllButton")

local WithdrawAllButton = 
	TransferControls:WaitForChild("WithdrawAllButton")

local WithdrawAllInProgress = false

local TrainKey = Enum.KeyCode.T

local IsTrainOpen = false
local SelectedCarId = nil
local SelectedOreName = nil
local SelectedSource = nil
local CurrentOverview = nil

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

local function ClearGeneratedChildren(Container, Template)
	for _, Child in Container:GetChildren() do
		if Child:IsA("GuiObject") and Child ~= Template then
			Child:Destroy()
		end
	end
end

local function GetSelectedCar()
	if not CurrentOverview then
		return nil
	end

	for _, CarData in CurrentOverview.Cars do
		if CarData.CarId == SelectedCarId then
			return CarData
		end
	end

	return nil
end

local function DisplaySelectedCar()
	ClearGeneratedChildren(OreList, OreRowTemplate)

	local CarData = GetSelectedCar()

	if not CarData then
		SelectedTitle.Text = "Select a car"
		return
	end

	SelectedTitle.Text = string.format(
		"Car %d  |  %d / %d",
		CarData.Index,
		CarData.Load,
		CarData.Capacity
	)

	for Index, OreData in CarData.Inventory do
		local Row = OreRowTemplate:Clone()
		Row.Name = OreData.Name .. "Row"
		Row.LayoutOrder = Index
		Row.Visible = true
		Row.OreName.Text = OreData.Name
		Row.Quantity.Text = FormatNumber(OreData.Quantity)
		Row.Value.Text = FormatMoney(OreData.Value)
		Row.TotalValue.Text =
			FormatMoney(OreData.TotalValue)

		Row.Parent = OreList
	end
end

local function RefreshOverview()
	local Success, Overview = pcall(function()
		return GetTrainOverview:InvokeServer()
	end)

	if not Success or typeof(Overview) ~= "table" then
		StatusLabel.Text = "Unable to load train."
		return false
	end

	CurrentOverview = Overview

	CarsTag.Value.Text =
		tostring(Overview.CurrentCars)

	LoadTag.Value.Text = string.format(
		"%s / %s",
		FormatNumber(Overview.TotalTrainLoad),
		FormatNumber(Overview.TotalTrainCapacity)
	)

	ValueTag.Value.Text =
		FormatMoney(Overview.TotalTrainValue)

	StatusLabel.Text =
		"Locomotive: " .. tostring(Overview.LocomotiveId)

	ClearGeneratedChildren(
		CarsList,
		CarButtonTemplate
	)

	for _, CarData in Overview.Cars do
		local Button = CarButtonTemplate:Clone()
		Button.Name = CarData.CarId
		Button.LayoutOrder = CarData.Index
		Button.Visible = true
		Button.CarName.Text =
			"Car " .. CarData.Index

		Button.CarLoad.Text = string.format(
			"%d / %d ores",
			CarData.Load,
			CarData.Capacity
		)

		Button.Activated:Connect(function()
			SelectedCarId = CarData.CarId
			DisplaySelectedCar()
		end)

		Button.Parent = CarsList
	end

	if not SelectedCarId
		and Overview.Cars[1] then

		SelectedCarId =
			Overview.Cars[1].CarId
	end

	DisplaySelectedCar()

	return true
end

local function SetTrainOpen(ShouldOpen)
	IsTrainOpen = ShouldOpen
	TrainFrame.Visible = ShouldOpen

	if ShouldOpen then
		RefreshOverview()
	end
end

local function HighlightSelectedItems()
	for _, Container in {
		BackpackList,
		CarList,
		} do
		for _, Child in Container:GetChildren() do
			if Child:IsA("TextButton") then
				local IsSelected =
					Child:GetAttribute("OreName")
					== SelectedOreName
					and Child:GetAttribute("Source")
					== SelectedSource

				Child.BackgroundColor3 =
					IsSelected
					and Color3.fromRGB(71, 92, 125)
					or Color3.fromRGB(44, 49, 60)
			end
		end
	end
end

local function GetMaximumTransfer(
	OreQuantity,
	Source
)
	if not CurrentOverview then
		return 0
	end

	local MaximumTransfer = math.max(
		math.floor(OreQuantity or 0),
		0
	)

	if Source == "Backpack" then
		local SelectedCar = GetSelectedCar()

		if not SelectedCar then
			return 0
		end

		local RemainingCarSpace = math.max(
			SelectedCar.Capacity - SelectedCar.Load,
			0
		)

		MaximumTransfer = math.min(
			MaximumTransfer,
			RemainingCarSpace
		)
	elseif Source == "Car" then
		local Backpack = CurrentOverview.Backpack

		if not Backpack then
			return 0
		end

		local RemainingBackpackSpace = math.max(
			Backpack.Capacity - Backpack.Load,
			0
		)

		MaximumTransfer = math.min(
			MaximumTransfer,
			RemainingBackpackSpace
		)
	else
		return 0
	end

	return MaximumTransfer
end

local function UpdateMaximumTransferQuantity(
	OreData,
	Source
)
	local MaximumTransfer = GetMaximumTransfer(
		OreData.Quantity,
		Source
	)

	QuantityBox.Text = tostring(MaximumTransfer)

	if MaximumTransfer <= 0 then
		MessageLabel.Text = "The destination is full."
	else
		MessageLabel.Text = string.format(
			"Maximum transferable: %d %s.",
			MaximumTransfer,
			OreData.Name
		)
	end

	return MaximumTransfer
end

local function CreateTransferItem(
	Container,
	OreData,
	Source
)
	local Button = TransferItemTemplate:Clone()
	Button.Name = OreData.Name .. Source
	Button.Visible = true
	Button:SetAttribute("OreName", OreData.Name)
	Button:SetAttribute("Source", Source)
	Button:SetAttribute(
		"Quantity",
		OreData.Quantity
	)

	Button.ItemName.Text = OreData.Name
	Button.Size = UDim2.new(0.95, 0, 0, 36)
	Button.Quantity.Text =
		"x" .. FormatNumber(OreData.Quantity)

	Button.Activated:Connect(function()
		SelectedOreName = OreData.Name
		SelectedSource = Source

		UpdateMaximumTransferQuantity(
			OreData,
			Source
		)

		HighlightSelectedItems()
	end)

	Button.Parent = Container
end

local function RefreshTransferMenu(
	ShouldRefreshOverview,
	PreserveMessage
)
	if ShouldRefreshOverview ~= false then
		local Success =
			RefreshOverview()

		if not Success then
			return
		end
	end

	local CarData =
		GetSelectedCar()

	if not CarData then
		MessageLabel.Text =
			"Car not found."

		return
	end

	TransferTitle.Text = string.format(
		"MANAGE CAR %d  |  %d / %d",
		CarData.Index,
		CarData.Load,
		CarData.Capacity
	)

	TransferFrame.BackpackPanel.Title.Text =
		string.format(
			"BAG  %d / %d",
			CurrentOverview.Backpack.Load,
			CurrentOverview.Backpack.Capacity
		)

	TransferFrame.CarPanel.Title.Text =
		string.format(
			"CAR  %d / %d",
			CarData.Load,
			CarData.Capacity
		)

	ClearGeneratedChildren(
		BackpackList,
		nil
	)

	ClearGeneratedChildren(
		CarList,
		nil
	)

	for _, OreData
		in CurrentOverview.Backpack.Inventory do

		CreateTransferItem(
			BackpackList,
			OreData,
			"Backpack"
		)
	end

	for _, OreData in CarData.Inventory do
		CreateTransferItem(
			CarList,
			OreData,
			"Car"
		)
	end

	SelectedOreName = nil
	SelectedSource = nil

	if not PreserveMessage then
		MessageLabel.Text =
			"Select an ore and transfer it."
	end
end

local function PerformTransfer(Direction)
	if not SelectedCarId then
		MessageLabel.Text = "No car selected."
		return
	end

	if not SelectedOreName then
		MessageLabel.Text = "Select an ore first."
		return
	end

	if Direction == "BackpackToCar"
		and SelectedSource ~= "Backpack" then

		MessageLabel.Text = "Select ore from your bag."
		return
	end

	if Direction == "CarToBackpack"
		and SelectedSource ~= "Car" then

		MessageLabel.Text = "Select ore from the car."
		return
	end

	local Quantity = tonumber(QuantityBox.Text)

	if not Quantity
		or Quantity <= 0 then

		MessageLabel.Text = "Enter a valid quantity."
		return
	end
	Quantity = math.floor(Quantity)

	local RequestSucceeded,
		TransferSucceeded,
		Result =
		pcall(function()
			return TransferCarOre:InvokeServer(
				Direction,
				SelectedCarId,
				SelectedOreName,
				Quantity
			)
		end)

	if not RequestSucceeded then
		warn(
			"Train ore transfer request failed:",
			TransferSucceeded
		)

		MessageLabel.Text =
			"Transfer request failed."

		return
	end

	if not TransferSucceeded then
		MessageLabel.Text =
			tostring(
				Result
				or "Transfer failed."
			)

		return
	end

	if typeof(Result) ~= "table" then
		MessageLabel.Text =
			"Invalid transfer response."

		return
	end

	local Transferred =
		tonumber(
			Result.Transferred
		) or 0

	MessageLabel.Text = string.format(
		"Transferred %d %s.",
		Transferred,
		SelectedOreName
	)

	SelectedOreName = nil
	SelectedSource = nil

	if typeof(Result.Overview) == "table" then
		CurrentOverview = Result.Overview
		RefreshTransferMenu(false, true)
	else
		RefreshTransferMenu(true, true)
	end
end

local function PerformWithdrawAll()
	if WithdrawAllInProgress then
		return
	end

	if not SelectedCarId then
		MessageLabel.Text = "No car selected."
		return
	end

	local CarData = GetSelectedCar()

	if not CarData then
		MessageLabel.Text = "Car not found."
		return
	end

	if CarData.Load <= 0 then
		MessageLabel.Text = "This car is empty."
		return
	end

	if not CurrentOverview or not CurrentOverview.Backpack then
		MessageLabel.Text = "Backpack data is unavailable."
		return
	end

	local Backpack = CurrentOverview.Backpack
	local RemainingBackpackSpace = math.max(
		Backpack.Capacity - Backpack.Load,
		0
	)

	if RemainingBackpackSpace <= 0 then
		MessageLabel.Text = "Your backpack is full."
		return
	end

	WithdrawAllInProgress = true

	WithdrawAllButton.Active = false
	WithdrawAllButton.AutoButtonColor = false

	local OriginalText = WithdrawAllButton.Text
	WithdrawAllButton.Text = "Withdrawing..."

	local RequestSucceeded, TransferSucceeded, Result =
		pcall(function()
			return TransferCarOre:InvokeServer(
				"CarToBackpackAll",
				SelectedCarId,
				"",
				0
			)
		end)

	WithdrawAllInProgress = false

	WithdrawAllButton.Active = true
	WithdrawAllButton.AutoButtonColor = true
	WithdrawAllButton.Text = OriginalText

	if not RequestSucceeded then
		warn(
			"Withdraw All request failed:",
			TransferSucceeded
		)

		MessageLabel.Text = "Withdraw request failed."
		return
	end

	if not TransferSucceeded then
		MessageLabel.Text = tostring(
			Result or "Nothing could be withdrawn."
		)

		return
	end

	if typeof(Result) ~= "table" then
		MessageLabel.Text = "Invalid withdrawal response."
		return
	end

	local Transferred = math.max(
		math.floor(
			tonumber(Result.Transferred) or 0
		),
		0
	)

	if Result.Message then
		MessageLabel.Text = tostring(Result.Message)
	else
		MessageLabel.Text = string.format(
			"Withdrew %d ore%s from the car.",
			Transferred,
			Transferred == 1 and "" or "s"
		)
	end

	SelectedOreName = nil
	SelectedSource = nil

	if typeof(Result.Overview) == "table" then
		CurrentOverview = Result.Overview
		RefreshTransferMenu(false, true)
	else
		RefreshTransferMenu(true, true)
	end
end

TrainButton.Activated:Connect(function()
	SetTrainOpen(not IsTrainOpen)
end)

CloseButton.Activated:Connect(function()
	SetTrainOpen(false)
end)

TransferClose.Activated:Connect(function()
	TransferFrame.Visible = false
end)

DepositButton.Activated:Connect(function()
	PerformTransfer("BackpackToCar")
end)

WithdrawButton.Activated:Connect(function()
	PerformTransfer("CarToBackpack")
end)

WithdrawAllButton.Activated:Connect(
	PerformWithdrawAll)

DepositAllButton.Activated:Connect(function()
	if not SelectedCarId then
		MessageLabel.Text = "No car selected."
		return
	end

	DepositAllButton.Active = false
	DepositAllButton.AutoButtonColor = false

	local RequestSuccess, DepositSuccess, Result =
		pcall(function()
			return DepositAllToCar:InvokeServer(
				SelectedCarId
			)
		end)

	DepositAllButton.Active = true
	DepositAllButton.AutoButtonColor = true

	if not RequestSuccess then
		MessageLabel.Text =
			"Deposit request failed."

		return
	end

	if not DepositSuccess then
		MessageLabel.Text =
			tostring(
				Result or "Nothing was deposited."
			)

		return
	end

	MessageLabel.Text = string.format(
		"Deposited %d ore%s into the car.",
		Result.TotalDeposited,
		Result.TotalDeposited == 1 and "" or "s"
	)

	RefreshTransferMenu()
end)

OpenCarMenu.OnClientEvent:Connect(function(CarId)
	SelectedCarId = CarId
	TrainFrame.Visible = false
	IsTrainOpen = false
	TransferFrame.Visible = true
	RefreshTransferMenu()
end)

RefreshTrainGui.OnClientEvent:Connect(function()
	local Success =
		RefreshOverview()

	if not Success then
		return
	end

	if TransferFrame.Visible then
		RefreshTransferMenu(false)
	end
end)

UserInputService.InputBegan:Connect(function(
	Input,
	GameProcessed
)
	if GameProcessed then
		return
	end

	if UserInputService:GetFocusedTextBox() then
		return
	end

	if Input.KeyCode == TrainKey then
		SetTrainOpen(not IsTrainOpen)
	end
end)

local CurrentMobilePage = "Cars"
local IsCompactLayout = false

local MobilePages = {
	Cars = CarsPage,
	Load = LoadPage,
	Equipment = EquipmentPage,
}

local MobileButtons = {
	Cars = CarsButton,
	Load = LoadButton,
	Equipment = EquipmentButton,
}

local function ShowMobilePage(PageName)
	CurrentMobilePage = PageName

	for Name, Page in MobilePages do
		Page.Visible = not IsCompactLayout or Name == PageName
	end

	for Name, Button in MobileButtons do
		Button.BackgroundColor3 = Name == PageName
			and Color3.fromRGB(71, 92, 125)
			or Color3.fromRGB(45, 50, 61)
	end
end

for Name, Button in MobileButtons do
	Button.Activated:Connect(function()
		ShowMobilePage(Name)
	end)
end

ResponsiveGui.Bind(function(Layout)
	IsCompactLayout = Layout == ResponsiveGui.Layout.Compact
	MobileTabs.Visible = IsCompactLayout

	if IsCompactLayout then
		TrainFrame.Size = UDim2.new(1, -24, 1, -24)
		Header.Size = UDim2.new(1, 0, 0, 52)
		MobileTabs.Position = UDim2.fromOffset(12, 58)
		StatusLabel.Position = UDim2.fromOffset(12, 108)
		StatusLabel.Size = UDim2.new(1, -24, 0, 24)

		local PagePosition = UDim2.fromOffset(12, 138)
		local PageSize = UDim2.new(1, -24, 1, -204)

		for _, Page in MobilePages do
			Page.Position = PagePosition
			Page.Size = PageSize
		end

		LocomotiveSelector.Position = UDim2.fromOffset(0, 0)
		LocomotiveSelector.Size = UDim2.new(1, 0, 0.5, -6)
		DrillSelector.Position = UDim2.new(0, 0, 0.5, 6)
		DrillSelector.Size = UDim2.new(1, 0, 0.5, -6)

		ActionBar.Position = UDim2.new(0, 12, 1, -58)
		ActionBar.Size = UDim2.new(1, -24, 0, 48)

		ShowMobilePage(CurrentMobilePage)
		return
	end

	MobileTabs.Visible = false

	for _, Page in MobilePages do
		Page.Visible = true
	end

	-- Restore your present desktop positions here.
	TrainFrame.Size = Layout == ResponsiveGui.Layout.Medium
		and UDim2.new(0.94, 0, 0.9, 0)
		or UDim2.fromOffset(920, 620)
end)
