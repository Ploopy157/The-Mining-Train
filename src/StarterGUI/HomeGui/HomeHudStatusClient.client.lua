local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ResponsiveGui = require(ReplicatedStorage:WaitForChild("ResponsiveGui"))

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local HomeGui = PlayerGui:WaitForChild("HomeGui")
local MainHudContainer = HomeGui:WaitForChild("MainHudContainer")
local HudLayout = MainHudContainer:WaitForChild("UIListLayout")

local CashDisplay = MainHudContainer:WaitForChild("CashDisplay")
local NavigationRow = MainHudContainer:WaitForChild("NavigationRow")
local HomeButton = NavigationRow:WaitForChild("HomeButton")
local ShopButton = NavigationRow:WaitForChild("ShopButton")

local BagButton = MainHudContainer:WaitForChild("BagButton")
local TrainButton = MainHudContainer:WaitForChild("TrainButton")

local HudStatusRemotes = ReplicatedStorage:WaitForChild("HudStatusRemotes")
local GetHudStatus = HudStatusRemotes:WaitForChild("GetHudStatus")

local HudButtons = { HomeButton, ShopButton, BagButton, TrainButton }

local DefaultColor = Color3.fromRGB(164, 126, 66)
local HoverColor = Color3.fromRGB(224, 181, 91)
local PressedColor = Color3.fromRGB(121, 91, 47)

local function Tween(Object, Properties, Duration)
	TweenService:Create(
		Object,
		TweenInfo.new(Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Properties
	):Play()
end

local function BindButtonEffects(Button)
	local Scale = Button:WaitForChild("InteractionScale")
	local Stroke = Button:WaitForChild("BrassStroke")

	Button.MouseEnter:Connect(function()
		Tween(Scale, { Scale = 1.035 }, 0.12)
		Tween(Stroke, { Color = HoverColor, Transparency = 0 }, 0.12)
	end)

	Button.MouseLeave:Connect(function()
		Tween(Scale, { Scale = 1 }, 0.12)
		Tween(Stroke, { Color = DefaultColor, Transparency = 0.2 }, 0.12)
	end)

	Button.MouseButton1Down:Connect(function()
		Tween(Scale, { Scale = 0.965 }, 0.06)
		Tween(Stroke, { Color = PressedColor }, 0.06)
	end)

	Button.MouseButton1Up:Connect(function()
		Tween(Scale, { Scale = 1.035 }, 0.08)
		Tween(Stroke, { Color = HoverColor }, 0.08)
	end)
end

for _, Button in HudButtons do
	BindButtonEffects(Button)
end


local function GetTextObject(Button)
	if not Button then
		return nil
	end

	if Button:IsA("TextButton") then
		return Button
	end

	return Button:FindFirstChildWhichIsA(
		"TextLabel",
		true
	)
end

local BagText =
	GetTextObject(BagButton)

local TrainText =
	GetTextObject(TrainButton)

local function FormatNumber(Value)
	Value =
		math.floor(
			tonumber(Value) or 0
		)

	local Text = tostring(Value)

	while true do
		local NewText, Count =
			string.gsub(
				Text,
				"^(-?%d+)(%d%d%d)",
				"%1,%2"
			)

		Text = NewText

		if Count == 0 then
			break
		end
	end

	return Text
end

local function UpdateHud()
	local Success, Status =
		pcall(function()
			return GetHudStatus:InvokeServer()
		end)

	if not Success
		or typeof(Status) ~= "table"
		or not Status.IsLoaded then

		return
	end

	CashDisplay.Text =
		"$"
		.. FormatNumber(
			Status.Cash
		)

	if BagText then
		BagText.Text =
			"BAG  "
			.. tostring(
				math.floor(
					Status.BagLoad or 0
				)
			)
			.. "/"
			.. tostring(
				math.floor(
					Status.BagCapacity or 0
				)
			)
	end

	if TrainText then
		TrainText.Text =
			"TRAIN\n"
			.. tostring(
				math.floor(
					Status.TrainLoad or 0
				)
			)
			.. "/"
			.. tostring(
				math.floor(
					Status.TrainCapacity or 0
				)
			)
	end
end

ResponsiveGui.Bind(function(Layout)
	if Layout == ResponsiveGui.Layout.Compact then
		MainHudContainer.AnchorPoint = Vector2.new(0.5, 1)
		MainHudContainer.Position = UDim2.new(0.5, 0, 1, -115)
		MainHudContainer.Size = UDim2.new(1, -180, 0, 54)

		HudLayout.FillDirection = Enum.FillDirection.Horizontal
		HudLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		HudLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		HudLayout.Padding = UDim.new(0, 6)

		CashDisplay.Size = UDim2.fromOffset(130, 54)
		HomeButton.Size = UDim2.fromOffset(70, 54)
		ShopButton.Size = UDim2.fromOffset(70, 54)

		if BagButton then
			BagButton.Size = UDim2.fromOffset(105, 54)
		end

		if TrainButton then
			TrainButton.Size = UDim2.fromOffset(125, 54)
		end
	else
		-- Keep the current working desktop layout here.
	end
end)

while true do
	UpdateHud()
	task.wait(0.25)
end
