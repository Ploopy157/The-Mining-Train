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

local CurrentMode = "Load"
local CurrentState
local ActiveQueueLabel
local ActiveQueueEntry
local ActiveFinishTime
local SelectedOreName

local Gui = Instance.new("ScreenGui")
Gui.Name = "FurnaceGui"
Gui.ResetOnSpawn = false
Gui.Enabled = false
Gui.Parent = PlayerGui

local Frame = Instance.new("Frame")
Frame.AnchorPoint = Vector2.new(0.5, 0.5)
Frame.Position = UDim2.fromScale(0.5, 0.5)
Frame.Size = UDim2.new(0.9, 0, 0.78, 0)
Frame.BackgroundColor3 = Color3.fromRGB(35, 30, 27)
Frame.BorderSizePixel = 0
Frame.Parent = Gui

local SizeConstraint = Instance.new("UISizeConstraint")
SizeConstraint.MaxSize = Vector2.new(620, 560)
SizeConstraint.MinSize = Vector2.new(290, 340)
SizeConstraint.Parent = Frame

local FrameCorner = Instance.new("UICorner")
FrameCorner.CornerRadius = UDim.new(0, 10)
FrameCorner.Parent = Frame

local Title = Instance.new("TextLabel")
Title.Position = UDim2.fromOffset(14, 0)
Title.Size = UDim2.new(1, -64, 0, 46)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.Text = "FURNACE"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.TextSize = 22
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Frame

local Close = Instance.new("TextButton")
Close.AnchorPoint = Vector2.new(1, 0)
Close.Position = UDim2.new(1, -8, 0, 8)
Close.Size = UDim2.fromOffset(40, 32)
Close.BackgroundColor3 = Color3.fromRGB(75, 63, 56)
Close.Text = "X"
Close.TextColor3 = Color3.new(1, 1, 1)
Close.Font = Enum.Font.GothamBold
Close.TextSize = 18
Close.Parent = Frame

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 7)
CloseCorner.Parent = Close

local Status = Instance.new("TextLabel")
Status.Position = UDim2.fromOffset(14, 43)
Status.Size = UDim2.new(1, -28, 0, 38)
Status.BackgroundTransparency = 1
Status.Font = Enum.Font.Gotham
Status.Text = ""
Status.TextColor3 = Color3.fromRGB(225, 210, 180)
Status.TextSize = 14
Status.TextWrapped = true
Status.Parent = Frame

local Summary = Instance.new("TextLabel")
Summary.Position = UDim2.fromOffset(14, 80)
Summary.Size = UDim2.new(1, -28, 0, 26)
Summary.BackgroundTransparency = 1
Summary.Font = Enum.Font.GothamBold
Summary.TextColor3 = Color3.new(1, 1, 1)
Summary.TextSize = 14
Summary.TextXAlignment = Enum.TextXAlignment.Left
Summary.Parent = Frame

local CoalFrame = Instance.new("Frame")
CoalFrame.Position = UDim2.fromOffset(14, 108)
CoalFrame.Size = UDim2.new(1, -28, 0, 52)
CoalFrame.BackgroundColor3 = Color3.fromRGB(46, 40, 36)
CoalFrame.BorderSizePixel = 0
CoalFrame.Visible = false
CoalFrame.Parent = Frame

local CoalCorner = Instance.new("UICorner")
CoalCorner.CornerRadius = UDim.new(0, 8)
CoalCorner.Parent = CoalFrame

local CoalQuantity = Instance.new("TextBox")
CoalQuantity.Position = UDim2.fromOffset(8, 8)
CoalQuantity.Size = UDim2.new(0.28, -4, 0, 36)
CoalQuantity.BackgroundColor3 = Color3.fromRGB(66, 58, 52)
CoalQuantity.PlaceholderText = "Coal"
CoalQuantity.Text = ""
CoalQuantity.ClearTextOnFocus = false
CoalQuantity.TextColor3 = Color3.new(1, 1, 1)
CoalQuantity.PlaceholderColor3 = Color3.fromRGB(180, 170, 160)
CoalQuantity.Font = Enum.Font.Gotham
CoalQuantity.TextSize = 14
CoalQuantity.Parent = CoalFrame

local StoreButton = Instance.new("TextButton")
StoreButton.Position = UDim2.new(0.28, 4, 0, 8)
StoreButton.Size = UDim2.new(0.36, -8, 0, 36)
StoreButton.BackgroundColor3 = Color3.fromRGB(120, 78, 39)
StoreButton.Text = "STORE COAL"
StoreButton.TextColor3 = Color3.new(1, 1, 1)
StoreButton.Font = Enum.Font.GothamBold
StoreButton.TextSize = 13
StoreButton.Parent = CoalFrame

local WithdrawButton = Instance.new("TextButton")
WithdrawButton.Position = UDim2.new(0.64, 0, 0, 8)
WithdrawButton.Size = UDim2.new(0.36, -8, 0, 36)
WithdrawButton.BackgroundColor3 = Color3.fromRGB(91, 68, 55)
WithdrawButton.Text = "WITHDRAW"
WithdrawButton.TextColor3 = Color3.new(1, 1, 1)
WithdrawButton.Font = Enum.Font.GothamBold
WithdrawButton.TextSize = 13
WithdrawButton.Parent = CoalFrame

for _, Button in {StoreButton, WithdrawButton} do
	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 6)
	Corner.Parent = Button
end

local List = Instance.new("ScrollingFrame")
List.Position = UDim2.fromOffset(14, 166)
List.Size = UDim2.new(1, -28, 1, -226)
List.BackgroundColor3 = Color3.fromRGB(46, 40, 36)
List.BorderSizePixel = 0
List.ScrollBarThickness = 7
List.AutomaticCanvasSize = Enum.AutomaticSize.Y
List.CanvasSize = UDim2.new()
List.Parent = Frame

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 8)
ListCorner.Parent = List

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 6)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = List

local Padding = Instance.new("UIPadding")
Padding.PaddingTop = UDim.new(0, 8)
Padding.PaddingBottom = UDim.new(0, 8)
Padding.PaddingLeft = UDim.new(0, 8)
Padding.PaddingRight = UDim.new(0, 8)
Padding.Parent = List

local Action = Instance.new("TextButton")
Action.AnchorPoint = Vector2.new(0.5, 1)
Action.Position = UDim2.new(0.5, 0, 1, -10)
Action.Size = UDim2.new(1, -28, 0, 44)
Action.BackgroundColor3 = Color3.fromRGB(132, 84, 42)
Action.Text = "ADD TO QUEUE"
Action.TextColor3 = Color3.new(1, 1, 1)
Action.Font = Enum.Font.GothamBold
Action.TextSize = 17
Action.Parent = Frame

local ActionCorner = Instance.new("UICorner")
ActionCorner.CornerRadius = UDim.new(0, 8)
ActionCorner.Parent = Action

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
	Row.Size = UDim2.new(1, 0, 0, 48)
	Row.BackgroundColor3 = IsSelected
		and Color3.fromRGB(100, 72, 48)
		or Color3.fromRGB(61, 53, 47)

	Row.BorderSizePixel = 0
	Row.Parent = List

	local RowCorner = Instance.new("UICorner")
	RowCorner.CornerRadius = UDim.new(0, 6)
	RowCorner.Parent = Row

	local Label = Instance.new("TextLabel")
	Label.Position = UDim2.fromOffset(10, 0)
	Label.Size = ButtonText
		and UDim2.new(1, -98, 1, 0)
		or UDim2.new(1, -20, 1, 0)

	Label.BackgroundTransparency = 1
	Label.Font = Enum.Font.Gotham
	Label.Text = Text
	Label.TextColor3 = Color3.new(1, 1, 1)
	Label.TextSize = 14
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = Row

	if ButtonText then
		local Button = Instance.new("TextButton")
		Button.AnchorPoint = Vector2.new(1, 0.5)
		Button.Position = UDim2.new(1, -7, 0.5, 0)
		Button.Size = UDim2.fromOffset(80, 32)
		Button.BackgroundColor3 = Color3.fromRGB(91, 68, 55)
		Button.Text = ButtonText
		Button.TextColor3 = Color3.new(1, 1, 1)
		Button.Font = Enum.Font.GothamBold
		Button.TextSize = 12
		Button.Parent = Row

		local Corner = Instance.new("UICorner")
		Corner.CornerRadius = UDim.new(0, 6)
		Corner.Parent = Button

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
