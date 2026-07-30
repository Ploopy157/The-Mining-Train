local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TrainRemotes =
	ReplicatedStorage:WaitForChild("TrainRemotes")

local TrainAction =
	TrainRemotes:WaitForChild("TrainAction")

local TrainGui = script.Parent
local TrainFrame = TrainGui:WaitForChild("TrainFrame")
local StatusLabel = TrainFrame:WaitForChild("StatusLabel")
local ActionBar = TrainFrame:WaitForChild("ActionBar")

local TeleportTrainButton =
	ActionBar:WaitForChild("TeleportTrainButton")

local ReturnTrainButton =
	ActionBar:WaitForChild("ReturnTrainButton")

local PlayerGui =
	game:GetService("Players").LocalPlayer:WaitForChild(
		"PlayerGui"
	)

local HomeGui =
	PlayerGui:WaitForChild("HomeGui")

local HomeButton =
	HomeGui.MainHudContainer:WaitForChild("HomeButton")

local RequestInProgress = false

local function SetButtonsEnabled(Enabled)
	TeleportTrainButton.Active = Enabled
	ReturnTrainButton.Active = Enabled
	HomeButton.Active = Enabled

	TeleportTrainButton.AutoButtonColor = Enabled
	ReturnTrainButton.AutoButtonColor = Enabled
	HomeButton.AutoButtonColor = Enabled
end

local function PerformAction(ActionName)
	if RequestInProgress then
		return
	end

	RequestInProgress = true
	SetButtonsEnabled(false)

	local Success, ActionSucceeded, Message =
		pcall(function()
			return TrainAction:InvokeServer(ActionName)
		end)

	if not Success then
		StatusLabel.Text =
			"Unable to contact the server."

		RequestInProgress = false
		SetButtonsEnabled(true)
		return false
	end

	if not ActionSucceeded then
		StatusLabel.Text =
			tostring(Message or "Action failed.")

		RequestInProgress = false
		SetButtonsEnabled(true)
		return false
	end

	StatusLabel.Text =
		tostring(Message or "Action completed.")

	RequestInProgress = false
	SetButtonsEnabled(true)

	return true
end

TeleportTrainButton.Activated:Connect(function()
	local Success = PerformAction("TeleportToTrain")

	if Success then
		TrainFrame.Visible = false
	end
end)

ReturnTrainButton.Activated:Connect(function()
	PerformAction("ReturnTrain")
end)

HomeButton.Activated:Connect(function()
	local Success = PerformAction("Home")

	if Success then
		TrainFrame.Visible = false
	end
end)

local function UpdateResponsiveSizing()
	local Camera = Workspace.CurrentCamera

	if not Camera then
		return
	end

	local ViewportSize = Camera.ViewportSize
	local IsSmallScreen =
		ViewportSize.X < 760
		or ViewportSize.Y < 600

	if IsSmallScreen then
		--HomeButton.Size = UDim2.fromOffset(60, 60)
		--HomeButton.Position =
		--	UDim2.new(1, -10, 0.5, -70)

		TeleportTrainButton.TextSize = 11
		ReturnTrainButton.TextSize = 11
	else
		--HomeButton.Size = UDim2.fromOffset(72, 72)
		--HomeButton.Position =
		--	UDim2.new(1, -16, 0.5, -82)

		TeleportTrainButton.TextSize = 14
		ReturnTrainButton.TextSize = 14
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
