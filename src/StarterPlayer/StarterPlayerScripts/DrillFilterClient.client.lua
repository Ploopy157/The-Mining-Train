local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("DrillFilterRemotes")
local GetFilter = Remotes:WaitForChild("GetDrillFilter")
local SetFilter = Remotes:WaitForChild("SetDrillFilter")
local OpenDrillFilter = Remotes:WaitForChild("OpenDrillFilter")

local Existing = PlayerGui:FindFirstChild("DrillFilterGui")

if Existing then
	Existing:Destroy()
end

local Gui = Instance.new("ScreenGui")
Gui.Name = "DrillFilterGui"
Gui.ResetOnSpawn = false
Gui.Parent = PlayerGui

local Panel = Instance.new("Frame")
Panel.AnchorPoint = Vector2.new(0.5, 0.5)
Panel.Position = UDim2.fromScale(0.5, 0.5)
Panel.Size = UDim2.new(0.72, 0, 0.76, 0)
Panel.BackgroundColor3 = Color3.fromRGB(31, 31, 36)
Panel.BorderSizePixel = 0
Panel.Visible = false
Panel.Parent = Gui

local Constraint = Instance.new("UISizeConstraint")
Constraint.MinSize = Vector2.new(330, 300)
Constraint.MaxSize = Vector2.new(720, 620)
Constraint.Parent = Panel

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 12)
Corner.Parent = Panel

local Title = Instance.new("TextLabel")
Title.Position = UDim2.fromOffset(18, 12)
Title.Size = UDim2.new(1, -70, 0, 34)
Title.BackgroundTransparency = 1
Title.Text = "Drill Ore Filter"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.TextSize = 23
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.GothamBold
Title.Parent = Panel

local Close = Instance.new("TextButton")
Close.AnchorPoint = Vector2.new(1, 0)
Close.Position = UDim2.new(1, -12, 0, 12)
Close.Size = UDim2.fromOffset(38, 38)
Close.BackgroundColor3 = Color3.fromRGB(72, 72, 80)
Close.BorderSizePixel = 0
Close.Text = "x"
Close.TextColor3 = Color3.new(1, 1, 1)
Close.TextSize = 25
Close.Font = Enum.Font.GothamBold
Close.Parent = Panel

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 8)
CloseCorner.Parent = Close

local Header = Instance.new("Frame")
Header.Position = UDim2.fromOffset(18, 62)
Header.Size = UDim2.new(1, -36, 0, 36)
Header.BackgroundColor3 = Color3.fromRGB(44, 44, 50)
Header.BorderSizePixel = 0
Header.Parent = Panel

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 7)
HeaderCorner.Parent = Header

local function HeaderLabel(Text, Position, Size)
	local Label = Instance.new("TextLabel")
	Label.Position = Position
	Label.Size = Size
	Label.BackgroundTransparency = 1
	Label.Text = Text
	Label.TextColor3 = Color3.new(1, 1, 1)
	Label.TextSize = 16
	Label.Font = Enum.Font.GothamBold
	Label.Parent = Header
end

HeaderLabel("Ore", UDim2.fromScale(0, 0), UDim2.new(0.5, 0, 1, 0))
HeaderLabel("Keep", UDim2.fromScale(0.5, 0), UDim2.new(0.25, 0, 1, 0))
HeaderLabel("Destroy", UDim2.fromScale(0.75, 0), UDim2.new(0.25, 0, 1, 0))

local Scroll = Instance.new("ScrollingFrame")
Scroll.Position = UDim2.fromOffset(18, 106)
Scroll.Size = UDim2.new(1, -36, 1, -124)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 7
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.CanvasSize = UDim2.new()
Scroll.Parent = Panel

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 7)
Layout.Parent = Scroll

local function SetColours(Keep, Destroy, IsDestroy)
	Keep.BackgroundColor3 = IsDestroy and Color3.fromRGB(66, 66, 73) or Color3.fromRGB(53, 126, 76)
	Destroy.BackgroundColor3 = IsDestroy and Color3.fromRGB(152, 63, 63) or Color3.fromRGB(66, 66, 73)
end

local function MakeButton(Text)
	local Button = Instance.new("TextButton")
	Button.BorderSizePixel = 0
	Button.Text = Text
	Button.TextColor3 = Color3.new(1, 1, 1)
	Button.TextSize = 14
	Button.Font = Enum.Font.GothamBold

	local ButtonCorner = Instance.new("UICorner")
	ButtonCorner.CornerRadius = UDim.new(0, 7)
	ButtonCorner.Parent = Button

	return Button
end

local function AddRow(Entry, Order)
	local Row = Instance.new("Frame")
	Row.Name = Entry.Name
	Row.LayoutOrder = Order
	Row.Size = UDim2.new(1, -4, 0, 44)
	Row.BackgroundColor3 = Color3.fromRGB(39, 39, 45)
	Row.BorderSizePixel = 0
	Row.Parent = Scroll

	local RowCorner = Instance.new("UICorner")
	RowCorner.CornerRadius = UDim.new(0, 8)
	RowCorner.Parent = Row

	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(0.5, 0, 1, 0)
	Label.BackgroundTransparency = 1
	Label.Text = Entry.Name
	Label.TextColor3 = Color3.new(1, 1, 1)
	Label.TextSize = 16
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Font = Enum.Font.Gotham
	Label.Parent = Row

	local Padding = Instance.new("UIPadding")
	Padding.PaddingLeft = UDim.new(0, 12)
	Padding.Parent = Label

	local Keep = MakeButton("Keep")
	Keep.Position = UDim2.new(0.5, 4, 0, 5)
	Keep.Size = UDim2.new(0.25, -8, 1, -10)
	Keep.Parent = Row

	local Destroy = MakeButton("Destroy")
	Destroy.Position = UDim2.new(0.75, 4, 0, 5)
	Destroy.Size = UDim2.new(0.25, -8, 1, -10)
	Destroy.Parent = Row

	local IsDestroy = Entry.Destroy == true

	local function Update(NewValue)
		IsDestroy = NewValue
		SetColours(Keep, Destroy, IsDestroy)
		SetFilter:FireServer(Entry.Name, IsDestroy)
	end

	Keep.Activated:Connect(function()
		Update(false)
	end)

	Destroy.Activated:Connect(function()
		Update(true)
	end)

	SetColours(Keep, Destroy, IsDestroy)
end

local Loaded = false

local function Load()
	if Loaded then
		return
	end

	local Success, Entries = pcall(function()
		return GetFilter:InvokeServer()
	end)

	if not Success or typeof(Entries) ~= "table" then
		warn("Could not load drill filter.")
		return
	end

	for Index, Entry in Entries do
		AddRow(Entry, Index)
	end

	Loaded = true
end

OpenDrillFilter.OnClientEvent:Connect(function()
	Load()
	Panel.Visible = true
end)

Close.Activated:Connect(function()
	Panel.Visible = false
end)
