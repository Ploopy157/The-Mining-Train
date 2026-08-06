local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ResponsiveGui = require(ReplicatedStorage:WaitForChild("ResponsiveGui"))
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
	HomeGui.MainHudContainer.NavigationRow:WaitForChild("HomeButton")

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

