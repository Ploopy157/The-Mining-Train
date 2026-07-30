local Players = game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

local PlayerGui =
	Player:WaitForChild("PlayerGui")

local HomeGui =
	PlayerGui:WaitForChild("HomeGui")

local MainHudContainer =
	HomeGui:WaitForChild(
		"MainHudContainer"
	)

local CashDisplay =
	MainHudContainer:WaitForChild(
		"CashDisplay"
	)

local HomeButton =
	MainHudContainer:WaitForChild(
		"HomeButton"
	)

local ShopButton =
	MainHudContainer:WaitForChild(
		"ShopButton"
	)

local BagButton =
	MainHudContainer:FindFirstChild(
		"BagButton"
	)
	or MainHudContainer:FindFirstChild(
		"BackpackButton"
	)
	or MainHudContainer:FindFirstChild(
		"InventoryButton"
	)

local TrainButton =
	MainHudContainer:FindFirstChild(
		"TrainButton"
	)
	or MainHudContainer:FindFirstChild(
		"TrainInventoryButton"
	)

local HudStatusRemotes =
	ReplicatedStorage:WaitForChild(
		"HudStatusRemotes"
	)

local GetHudStatus =
	HudStatusRemotes:WaitForChild(
		"GetHudStatus"
	)

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

while true do
	UpdateHud()
	task.wait(0.25)
end
