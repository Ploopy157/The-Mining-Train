local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local FurnaceRemotes = ReplicatedStorage:WaitForChild("FurnaceRemotes")

local GetFurnaceState = FurnaceRemotes:WaitForChild("GetFurnaceState")
local StoreCoal = FurnaceRemotes:WaitForChild("StoreCoal")
local WithdrawCoal = FurnaceRemotes:WaitForChild("WithdrawCoal")
local AddQueueProcess = FurnaceRemotes:WaitForChild("AddQueueProcess")
local RemoveQueueItem = FurnaceRemotes:WaitForChild("RemoveQueueItem")
local CollectIngots = FurnaceRemotes:WaitForChild("CollectIngots")
local OpenFurnace = FurnaceRemotes:WaitForChild("OpenFurnace")
local FurnaceUpdated = FurnaceRemotes:WaitForChild("FurnaceUpdated")
local ResponsiveGui = require(ReplicatedStorage:WaitForChild("ResponsiveGui"))

local CurrentMode = "Load"
local CurrentState
local ActiveQueueLabel
local ActiveQueueEntry
local ActiveFinishTime
local SelectedOreName

local Colors = {
	Background = Color3.fromRGB(39, 30, 27),
	Header = Color3.fromRGB(58, 40, 34),
	Panel = Color3.fromRGB(50, 38, 34),
	PanelLight = Color3.fromRGB(66, 49, 42),
	Row = Color3.fromRGB(61, 45, 39),
	RowSelected = Color3.fromRGB(91, 61, 40),
	Input = Color3.fromRGB(34, 27, 25),
	Copper = Color3.fromRGB(166, 103, 54),
	CopperBright = Color3.fromRGB(221, 151, 78),
	Brass = Color3.fromRGB(190, 145, 75),
	Cream = Color3.fromRGB(255, 239, 211),
	MutedText = Color3.fromRGB(211, 188, 159),
	Danger = Color3.fromRGB(151, 60, 51),
	DangerBright = Color3.fromRGB(207, 91, 76),
	Success = Color3.fromRGB(60, 121, 76),
	Secondary = Color3.fromRGB(91, 68, 55),
	StrokeDark = Color3.fromRGB(22, 16, 15),
}

local function AddCorner(Object, Radius)
	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, Radius)
	Corner.Parent = Object
	return Corner
end

local function AddStroke(Object, Color, Thickness, Transparency)
	local Stroke = Instance.new("UIStroke")
	Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Stroke.Color = Color
	Stroke.Thickness = Thickness
	Stroke.Transparency = Transparency
	Stroke.Parent = Object
	return Stroke
end

local function StyleText(Object, Color)
	Object.Font = Enum.Font.GothamBold
	Object.TextColor3 = Color or Colors.Cream
	Object.TextStrokeColor3 = Colors.StrokeDark
	Object.TextStrokeTransparency = 0.78
end

local function StyleButton(Button, BackgroundColor, StrokeColor)
	Button.AutoButtonColor = true
	Button.BackgroundColor3 = BackgroundColor
	Button.BorderSizePixel = 0

	StyleText(Button)
	AddCorner(Button, 7)
	AddStroke(Button, StrokeColor or Colors.Copper, 1.4, 0.15)
end

local Gui = Instance.new("ScreenGui")
Gui.Name = "FurnaceGui"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = false
Gui.DisplayOrder = 10
Gui.Enabled = false
Gui.Parent = PlayerGui

local Frame = Instance.new("Frame")
Frame.Name = "FurnaceFrame"
Frame.AnchorPoint = Vector2.new(0.5, 0.5)
Frame.Position = UDim2.fromScale(0.5, 0.5)
Frame.Size = UDim2.fromScale(0.94, 0.9)
Frame.BackgroundColor3 = Colors.Background
Frame.BorderSizePixel = 0
Frame.ClipsDescendants = true
Frame.Parent = Gui

local SizeConstraint = Instance.new("UISizeConstraint")
SizeConstraint.MaxSize = Vector2.new(650, 520)
SizeConstraint.MinSize = Vector2.new(300, 300)
SizeConstraint.Parent = Frame

AddCorner(Frame, 10)
AddStroke(Frame, Colors.CopperBright, 1.6, 0.1)

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Position = UDim2.fromScale(0, 0)
Header.Size = UDim2.new(1, 0, 0, 72)
Header.BackgroundColor3 = Colors.Header
Header.BorderSizePixel = 0
Header.Parent = Frame

AddCorner(Header, 10)

local HeaderBottomCover = Instance.new("Frame")
HeaderBottomCover.Name = "BottomCover"
HeaderBottomCover.AnchorPoint = Vector2.new(0, 1)
HeaderBottomCover.Position = UDim2.fromScale(0, 1)
HeaderBottomCover.Size = UDim2.new(1, 0, 0, 12)
HeaderBottomCover.BackgroundColor3 = Colors.Header
HeaderBottomCover.BorderSizePixel = 0
HeaderBottomCover.Parent = Header

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Position = UDim2.fromOffset(16, 0)
Title.Size = UDim2.new(1, -76, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = "FURNACE"
Title.TextSize = 23
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

StyleText(Title)

local Close = Instance.new("TextButton")
Close.Name = "CloseButton"
Close.AnchorPoint = Vector2.new(1, 0.5)
Close.Position = UDim2.new(1, -14, 0.5, 0)
Close.Size = UDim2.fromOffset(42, 42)
Close.Text = "X"
Close.TextSize = 18
Close.Parent = Header

StyleButton(Close, Colors.Danger, Colors.DangerBright)

local Status = Instance.new("TextLabel")
Status.Name = "StatusLabel"
Status.Position = UDim2.fromOffset(16, 78)
Status.Size = UDim2.new(1, -32, 0, 28)
Status.BackgroundTransparency = 1
Status.Font = Enum.Font.Gotham
Status.Text = ""
Status.TextColor3 = Colors.MutedText
Status.TextSize = 14
Status.TextWrapped = true
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Parent = Frame

local SummaryFrame = Instance.new("Frame")
SummaryFrame.Name = "SummaryFrame"
SummaryFrame.Position = UDim2.fromOffset(16, 110)
SummaryFrame.Size = UDim2.new(1, -32, 0, 42)
SummaryFrame.BackgroundColor3 = Colors.PanelLight
SummaryFrame.BorderSizePixel = 0
SummaryFrame.Parent = Frame

AddCorner(SummaryFrame, 8)
AddStroke(SummaryFrame, Colors.Brass, 1.2, 0.3)

local Summary = Instance.new("TextLabel")
Summary.Name = "Summary"
Summary.Position = UDim2.fromOffset(12, 0)
Summary.Size = UDim2.new(1, -24, 1, 0)
Summary.BackgroundTransparency = 1
Summary.Text = ""
Summary.TextSize = 14
Summary.TextXAlignment = Enum.TextXAlignment.Left
Summary.Parent = SummaryFrame

StyleText(Summary)

local CoalFrame = Instance.new("Frame")
CoalFrame.Name = "CoalControls"
CoalFrame.Position = UDim2.fromOffset(16, 160)
CoalFrame.Size = UDim2.new(1, -32, 0, 52)
CoalFrame.BackgroundColor3 = Colors.Panel
CoalFrame.BorderSizePixel = 0
CoalFrame.Visible = false
CoalFrame.Parent = Frame

AddCorner(CoalFrame, 8)
AddStroke(CoalFrame, Colors.Copper, 1.2, 0.32)

local CoalQuantity = Instance.new("TextBox")
CoalQuantity.Name = "CoalQuantity"
CoalQuantity.Position = UDim2.fromOffset(8, 8)
CoalQuantity.Size = UDim2.new(0.25, -4, 0, 36)
CoalQuantity.BackgroundColor3 = Colors.Input
CoalQuantity.BorderSizePixel = 0
CoalQuantity.PlaceholderText = "COAL"
CoalQuantity.PlaceholderColor3 = Colors.MutedText
CoalQuantity.Text = ""
CoalQuantity.ClearTextOnFocus = false
CoalQuantity.TextColor3 = Colors.Cream
CoalQuantity.Font = Enum.Font.GothamBold
CoalQuantity.TextSize = 14
CoalQuantity.Parent = CoalFrame

AddCorner(CoalQuantity, 6)
AddStroke(CoalQuantity, Colors.Brass, 1, 0.45)

local StoreButton = Instance.new("TextButton")
StoreButton.Name = "StoreCoalButton"
StoreButton.Position = UDim2.new(0.25, 4, 0, 8)
StoreButton.Size = UDim2.new(0.375, -8, 0, 36)
StoreButton.Text = "STORE COAL"
StoreButton.TextSize = 13
StoreButton.Parent = CoalFrame

StyleButton(StoreButton, Colors.Copper, Colors.CopperBright)

local WithdrawButton = Instance.new("TextButton")
WithdrawButton.Name = "WithdrawCoalButton"
WithdrawButton.Position = UDim2.new(0.625, 0, 0, 8)
WithdrawButton.Size = UDim2.new(0.375, -8, 0, 36)
WithdrawButton.Text = "WITHDRAW"
WithdrawButton.TextSize = 13
WithdrawButton.Parent = CoalFrame

StyleButton(WithdrawButton, Colors.Secondary, Colors.Brass)

local List = Instance.new("ScrollingFrame")
List.Name = "InventoryList"
List.Position = UDim2.fromOffset(16, 220)
List.Size = UDim2.new(1, -32, 1, -288)
List.BackgroundColor3 = Colors.Panel
List.BorderSizePixel = 0
List.Active = true
List.ClipsDescendants = true
List.ScrollingDirection = Enum.ScrollingDirection.Y
List.ScrollBarImageColor3 = Colors.CopperBright
List.ScrollBarImageTransparency = 0.1
List.ScrollBarThickness = 7
List.AutomaticCanvasSize = Enum.AutomaticSize.Y
List.CanvasSize = UDim2.fromOffset(0, 0)
List.Parent = Frame

AddCorner(List, 8)
AddStroke(List, Colors.Copper, 1.2, 0.4)

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 7)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = List

local Padding = Instance.new("UIPadding")
Padding.PaddingTop = UDim.new(0, 8)
Padding.PaddingBottom = UDim.new(0, 8)
Padding.PaddingLeft = UDim.new(0, 8)
Padding.PaddingRight = UDim.new(0, 8)
Padding.Parent = List

local Action = Instance.new("TextButton")
Action.Name = "ActionButton"
Action.AnchorPoint = Vector2.new(0.5, 1)
Action.Position = UDim2.new(0.5, 0, 1, -10)
Action.Size = UDim2.new(1, -32, 0, 48)
Action.Text = "ADD TO QUEUE"
Action.TextSize = 16
Action.Parent = Frame

StyleButton(Action, Colors.Copper, Colors.CopperBright)

local function ClearRows()
	for _, Child in List:GetChildren() do
		if Child:IsA("GuiObject")
			and Child ~= Layout
			and Child ~= Padding then

			Child:Destroy()
		end
	end
end

local function MakeRow(Text, ButtonText, Callback, IsSelected)
	local Row = Instance.new("Frame")
	Row.Name = "InventoryRow"
	Row.Size = UDim2.new(1, 0, 0, 52)
	Row.BackgroundColor3 = IsSelected and Colors.RowSelected or Colors.Row
	Row.BorderSizePixel = 0
	Row.Parent = List

	AddCorner(Row, 7)
	AddStroke(
		Row,
		IsSelected and Colors.CopperBright or Colors.Copper,
		IsSelected and 1.4 or 1,
		IsSelected and 0.1 or 0.55
	)

	local Label = Instance.new("TextLabel")
	Label.Name = "ItemLabel"
	Label.Position = UDim2.fromOffset(12, 0)
	Label.Size = ButtonText and UDim2.new(1, -116, 1, 0) or UDim2.new(1, -24, 1, 0)
	Label.BackgroundTransparency = 1
	Label.Font = Enum.Font.Gotham
	Label.Text = Text
	Label.TextColor3 = Colors.Cream
	Label.TextSize = 14
	Label.TextWrapped = true
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = Row

	if ButtonText then
		local Button = Instance.new("TextButton")
		Button.Name = ButtonText == "REMOVE" and "RemoveButton" or "RowActionButton"
		Button.AnchorPoint = Vector2.new(1, 0.5)
		Button.Position = UDim2.new(1, -8, 0.5, 0)
		Button.Size = UDim2.fromOffset(92, 34)
		Button.Text = ButtonText
		Button.TextSize = 12
		Button.Parent = Row

		if ButtonText == "REMOVE" then
			StyleButton(Button, Colors.Danger, Colors.DangerBright)
		elseif IsSelected then
			StyleButton(Button, Colors.Success, Colors.CopperBright)
		else
			StyleButton(Button, Colors.Secondary, Colors.Brass)
		end

		Button.Activated:Connect(Callback)
	end

	return Label
end

local function Render(State)
	if not State then
		return
	end

	CurrentState = State
	ActiveQueueLabel = nil
	ActiveQueueEntry = nil
	ActiveFinishTime = nil
	ClearRows()

	if CurrentMode == "Load" then
		Title.Text = "LOAD FURNACE"
		CoalFrame.Visible = true
		Action.Visible = true
		Action.Text = "ADD TO QUEUE"

		Summary.Text = string.format(
			"Coal %d/%d | Queue %d/%d",
			State.StoredCoal,
			State.CoalCapacity,
			State.QueueLoad,
			State.QueueCapacity
		)

		if #State.AvailableOres == 0 then
			SelectedOreName = nil
			MakeRow("No smeltable ore in bag or parked train.", nil)
		else
			local SelectionStillExists = false

			for _, Entry in State.AvailableOres do
				if Entry.Name == SelectedOreName then
					SelectionStillExists = true
				end

				MakeRow(
					string.format(
						"%s  %d/5 | Coal %d | $%d",
						Entry.Name,
						Entry.Quantity,
						Entry.CoalRequired,
						Entry.IngotValue
					),
					Entry.Name == SelectedOreName
						and "SELECTED"
						or "SELECT",
					function()
						SelectedOreName = Entry.Name
						Render(CurrentState)
					end,
					Entry.Name == SelectedOreName
				)
			end

			if not SelectionStillExists then
				SelectedOreName = nil
			end
		end
	elseif CurrentMode == "Queue" then
		Title.Text = "FURNACE QUEUE"
		CoalFrame.Visible = false
		Action.Visible = false

		Summary.Text = string.format(
			"Processes %d/%d | Stored Coal %d",
			State.QueueLoad,
			State.QueueCapacity,
			State.StoredCoal
		)

		if #State.Queue == 0 then
			MakeRow("The furnace queue is empty.", nil)
		else
			for _, Entry in State.Queue do
				local Remaining = math.max(tonumber(Entry.Remaining) or 0, 0)
				local TimeText = Entry.IsActive and string.format(" - %ds", math.ceil(Remaining)) or ""

				local Label = MakeRow(
					Entry.OreName
						.. " -> "
						.. Entry.IngotName
						.. TimeText,
					"REMOVE",
					function()
						local Success, Result = RemoveQueueItem:InvokeServer(Entry.Index)

						if Success then
							Status.Text = "Returned " .. Result.Removed .. " and reserved coal."
							Render(Result.State)
						else
							Status.Text = tostring(Result)
						end
					end
				)

				if Entry.IsActive then
					ActiveQueueLabel = Label
					ActiveQueueEntry = Entry
					ActiveFinishTime = os.clock() + Remaining
				end
			end
		end
	else
		Title.Text = "FINISHED INGOTS"
		CoalFrame.Visible = false
		Action.Visible = true
		Action.Text = "COLLECT ALL INGOTS"

		Summary.Text = string.format(
			"Output %d/%d",
			State.OutputLoad,
			State.OutputCapacity
		)

		if #State.Finished == 0 then
			MakeRow("No finished ingots.", nil)
		else
			for _, Entry in State.Finished do
				MakeRow(
					string.format(
						"%s  x%d | $%d each",
						Entry.Name,
						Entry.Quantity,
						Entry.Value
					),
					nil
				)
			end
		end
	end
end

local function Refresh()
	local Success, State = pcall(function()
		return GetFurnaceState:InvokeServer()
	end)

	if Success and State then
		Render(State)
	else
		Status.Text = "Unable to load furnace data."
	end
end

local function GetCoalQuantity()
	local Quantity = tonumber(CoalQuantity.Text)

	if Quantity then
		return math.floor(Quantity)
	end

	return nil
end

Close.Activated:Connect(function()
	Gui.Enabled = false
end)

StoreButton.Activated:Connect(function()
	local Success, Result = StoreCoal:InvokeServer(
		GetCoalQuantity()
	)

	if Success then
		Status.Text = string.format(
			"Stored %d coal.",
			Result.Transferred
		)

		CoalQuantity.Text = ""
		Render(Result.State)
	else
		Status.Text = tostring(Result)
	end
end)

WithdrawButton.Activated:Connect(function()
	local Success, Result = WithdrawCoal:InvokeServer(
		GetCoalQuantity()
	)

	if Success then
		Status.Text = string.format(
			"Withdrew %d coal.",
			Result.Transferred
		)

		CoalQuantity.Text = ""
		Render(Result.State)
	else
		Status.Text = tostring(Result)
	end
end)

Action.Activated:Connect(function()
	if CurrentMode == "Load" then
		if not SelectedOreName then
			Status.Text = "Select an ore first."
			return
		end

		local Success, Result =
			AddQueueProcess:InvokeServer(
				SelectedOreName
			)

		if Success then
			Status.Text =
				"Added one "
				.. SelectedOreName
				.. " process."

			Render(Result.State)
		else
			Status.Text = tostring(Result)
		end
	elseif CurrentMode == "Finished" then
		local Success, Result =
			CollectIngots:InvokeServer()

		if Success then
			Status.Text = string.format(
				"Collected %d ingot(s).",
				Result.Collected
			)

			Render(Result.State)
		else
			Status.Text = tostring(Result)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(0.1)

		if not Gui.Enabled
			or CurrentMode ~= "Queue"
			or not ActiveQueueLabel
			or not ActiveQueueLabel.Parent
			or not ActiveQueueEntry
			or not ActiveFinishTime then

			continue
		end

		local Remaining = math.max(ActiveFinishTime - os.clock(), 0)

		ActiveQueueLabel.Text = string.format(
			"%s -> %s - %ds",
			ActiveQueueEntry.OreName,
			ActiveQueueEntry.IngotName,
			math.ceil(Remaining)
		)
	end
end)

OpenFurnace.OnClientEvent:Connect(function(Mode, Message, State)
	CurrentMode = Mode == "Finished"
		and "Finished"
		or Mode == "Queue"
			and "Queue"
			or "Load"

	Status.Text = Message or ""
	Gui.Enabled = true

	if State then
		Render(State)
	else
		Refresh()
	end
end)

FurnaceUpdated.OnClientEvent:Connect(function(State)
	if Gui.Enabled and State then
		Render(State)
	end
end)


ResponsiveGui.Bind(function(Layout)
	local IsCompact = Layout == ResponsiveGui.Layout.Compact
	local IsMedium = Layout == ResponsiveGui.Layout.Medium

	Frame.AnchorPoint = Vector2.new(0.5, 0.5)
	Frame.Position = UDim2.fromScale(0.5, 0.5)

	if IsCompact then
		Frame.Size = UDim2.fromScale(0.94, 0.9)

		Header.Size = UDim2.new(1, 0, 0, 48)

		Title.Position = UDim2.fromOffset(12, 0)
		Title.Size = UDim2.new(1, -68, 1, 0)
		Title.TextSize = 19

		Close.Position = UDim2.new(1, -8, 0.5, 0)
		Close.Size = UDim2.fromOffset(38, 34)

		Status.Position = UDim2.fromOffset(12, 52)
		Status.Size = UDim2.new(1, -24, 0, 26)
		Status.TextSize = 12

		SummaryFrame.Position = UDim2.fromOffset(12, 60)
		SummaryFrame.Size = UDim2.new(1, -24, 0, 34)
		Summary.TextSize = 12

		CoalFrame.Position = UDim2.fromOffset(12, 100)
		CoalFrame.Size = UDim2.new(1, -24, 0, 46)

		CoalQuantity.Position = UDim2.fromOffset(7, 6)
		CoalQuantity.Size = UDim2.new(0.24, -3, 1, -12)
		CoalQuantity.TextSize = 12

		StoreButton.Position = UDim2.new(0.24, 4, 0, 6)
		StoreButton.Size = UDim2.new(0.38, -7, 1, -12)
		StoreButton.TextSize = 11

		WithdrawButton.Position = UDim2.new(0.62, 0, 0, 6)
		WithdrawButton.Size = UDim2.new(0.38, -7, 1, -12)
		WithdrawButton.TextSize = 11

		List.Position = UDim2.fromOffset(12, 150)
		List.Size = UDim2.new(1, -24, 1, -210)
		List.ScrollBarThickness = 6

		Action.Position = UDim2.new(0.5, 0, 1, -8)
		Action.Size = UDim2.new(1, -24, 0, 46)
		Action.TextSize = 14

		return
	else 
	end

	Frame.Size = IsMedium
		and UDim2.fromScale(0.94, 0.9)
		or UDim2.fromOffset(650, 520)

	Header.Size = UDim2.new(1, 0, 0, 72)

	Title.Position = UDim2.fromOffset(16, 0)
	Title.Size = UDim2.new(1, -76, 1, 0)
	Title.TextSize = 23

	Close.Position = UDim2.new(1, -14, 0.5, 0)
	Close.Size = UDim2.fromOffset(42, 42)

	Status.Position = UDim2.fromOffset(16, 78)
	Status.Size = UDim2.new(1, -32, 0, 28)
	Status.TextSize = 14

	SummaryFrame.Position = UDim2.fromOffset(16, 110)
	SummaryFrame.Size = UDim2.new(1, -32, 0, 42)
	Summary.TextSize = 14

	CoalFrame.Position = UDim2.fromOffset(16, 160)
	CoalFrame.Size = UDim2.new(1, -32, 0, 52)

	CoalQuantity.Position = UDim2.fromOffset(8, 8)
	CoalQuantity.Size = UDim2.new(0.25, -4, 0, 36)
	CoalQuantity.TextSize = 14

	StoreButton.Position = UDim2.new(0.25, 4, 0, 8)
	StoreButton.Size = UDim2.new(0.375, -8, 0, 36)
	StoreButton.TextSize = 13

	WithdrawButton.Position = UDim2.new(0.625, 0, 0, 8)
	WithdrawButton.Size = UDim2.new(0.375, -8, 0, 36)
	WithdrawButton.TextSize = 13

	List.Position = UDim2.fromOffset(16, 220)
	List.Size = UDim2.new(1, -32, 1, -288)
	List.ScrollBarThickness = 7

	Action.Position = UDim2.new(0.5, 0, 1, -10)
	Action.Size = UDim2.new(1, -32, 0, 48)
	Action.TextSize = 16
end)