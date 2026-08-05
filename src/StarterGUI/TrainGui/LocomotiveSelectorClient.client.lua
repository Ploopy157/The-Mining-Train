local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocomotiveDefinitions = require(
	ReplicatedStorage:WaitForChild("LocomotiveDefinitions")
)

local TrainRemotes = ReplicatedStorage:WaitForChild("TrainRemotes")
local GetLocomotiveSelectionData = TrainRemotes:WaitForChild("GetLocomotiveSelectionData")
local SelectLocomotive = TrainRemotes:WaitForChild("SelectLocomotive")
local RefreshTrainGui = TrainRemotes:WaitForChild("RefreshTrainGui")

local Gui = script.Parent
local TrainFrame = Gui:WaitForChild("TrainFrame")
local StatusLabel = TrainFrame:WaitForChild("StatusLabel")

local Selector = TrainFrame:WaitForChild("LocomotiveSelector")
local SelectedButton = Selector:WaitForChild("SelectedButton")
local SelectedName = SelectedButton:WaitForChild("SelectedName")
local Arrow = SelectedButton:WaitForChild("Arrow")

local OptionsFrame = Selector:WaitForChild("OptionsFrame")
local OptionTemplate = OptionsFrame:WaitForChild("OptionTemplate")

local IsOpen = false
local IsLoading = false
local IsSelecting = false
local CurrentSelectionData = nil

local function SetDropdownOpen(ShouldOpen)
	IsOpen = ShouldOpen
	OptionsFrame.Visible = ShouldOpen
	Arrow.Text = ShouldOpen and "▲" or "▼"
end

local function ClearOptions()
	for _, Child in OptionsFrame:GetChildren() do
		if Child:IsA("GuiButton") and Child ~= OptionTemplate then
			Child:Destroy()
		end
	end
end

local function GetDisplayName(LocomotiveId)
	local Definition = LocomotiveDefinitions.Get(LocomotiveId)

	if Definition then
		return Definition.DisplayName or LocomotiveId
	end

	return LocomotiveId or "Unknown Locomotive"
end

local function ApplySelectionData(SelectionData)
	if typeof(SelectionData) ~= "table" or SelectionData.Success ~= true then
		CurrentSelectionData = nil
		SelectedName.Text = "Unable to load locomotives"
		ClearOptions()
		return
	end

	CurrentSelectionData = SelectionData
	SelectedName.Text = GetDisplayName(SelectionData.CurrentLocomotiveId)

	ClearOptions()

	for _, LocomotiveData in SelectionData.Locomotives do
		local Button = OptionTemplate:Clone()

		Button.Name = LocomotiveData.LocomotiveId .. "Option"
		Button.LayoutOrder = LocomotiveData.LayoutOrder or LocomotiveData.Tier or 0
		Button.Visible = true
		Button.Active = LocomotiveData.IsUnlocked == true
		Button.AutoButtonColor = LocomotiveData.IsUnlocked == true
		Button.Selectable = LocomotiveData.IsUnlocked == true
		Button:SetAttribute("LocomotiveId", LocomotiveData.LocomotiveId)

		Button.LocomotiveName.Text = LocomotiveData.DisplayName

		Button.LocomotiveStats.Text = string.format(
			"Tier %d  |  Speed %s  |  Acceleration %s",
			LocomotiveData.Tier or 0,
			tostring(LocomotiveData.MaximumSpeed or 0),
			tostring(LocomotiveData.Acceleration or 0)
		)

		if LocomotiveData.IsSelected then
			Button.Status.Text = "SELECTED"
			Button.Status.TextColor3 = Color3.fromRGB(92, 224, 121)
			Button.BackgroundColor3 = Color3.fromRGB(50, 67, 60)
		elseif LocomotiveData.IsUnlocked then
			Button.Status.Text = "SELECT"
			Button.Status.TextColor3 = Color3.fromRGB(92, 224, 121)
			Button.BackgroundColor3 = Color3.fromRGB(44, 49, 60)
		else
			Button.Status.Text = "LOCKED"
			Button.Status.TextColor3 = Color3.fromRGB(190, 196, 211)
			Button.BackgroundColor3 = Color3.fromRGB(35, 39, 48)
			Button.LocomotiveName.TextColor3 = Color3.fromRGB(150, 155, 168)
			Button.LocomotiveStats.TextColor3 = Color3.fromRGB(120, 125, 138)
		end

		Button.Activated:Connect(function()
			if IsSelecting then
				return
			end

			if not LocomotiveData.IsUnlocked then
				StatusLabel.Text = string.format(
					"Requires locomotive tier %d.",
					LocomotiveData.Tier or 0
				)

				return
			end

			if LocomotiveData.IsSelected then
				SetDropdownOpen(false)
				return
			end

			IsSelecting = true
			StatusLabel.Text = "Changing locomotive..."
			Button.Status.Text = "WAIT"

			local RequestSucceeded, SelectionSucceeded, Result = pcall(function()
				return SelectLocomotive:InvokeServer(
					LocomotiveData.LocomotiveId
				)
			end)

			IsSelecting = false

			if not RequestSucceeded then
				StatusLabel.Text = "Locomotive request failed."
				warn("SelectLocomotive request failed:", SelectionSucceeded)
				return
			end

			if not SelectionSucceeded then
				StatusLabel.Text = tostring(
					Result or "Locomotive selection failed."
				)

				return
			end

			if typeof(Result) == "table" then
				StatusLabel.Text = tostring(
					Result.Message or "Locomotive selected."
				)

				if typeof(Result.SelectionData) == "table" then
					ApplySelectionData(Result.SelectionData)
				end
			else
				StatusLabel.Text = "Locomotive selected."
			end

			SetDropdownOpen(false)
		end)

		Button.Parent = OptionsFrame
	end
end

local function RefreshSelector()
	if IsLoading then
		return
	end

	IsLoading = true

	local Success, SelectionData = pcall(function()
		return GetLocomotiveSelectionData:InvokeServer()
	end)

	IsLoading = false

	if not Success then
		SelectedName.Text = "Unable to load locomotives"
		warn("GetLocomotiveSelectionData failed:", SelectionData)
		return
	end

	ApplySelectionData(SelectionData)
end

SelectedButton.Activated:Connect(function()
	if IsLoading or IsSelecting then
		return
	end

	SetDropdownOpen(not IsOpen)

	if IsOpen then
		RefreshSelector()
	end
end)

UserInputService.InputBegan:Connect(function(Input, WasProcessed)
	if WasProcessed or not IsOpen then
		return
	end

	if Input.KeyCode == Enum.KeyCode.Escape
		or Input.KeyCode == Enum.KeyCode.ButtonB then

		SetDropdownOpen(false)
	end
end)

RefreshTrainGui.OnClientEvent:Connect(function()
	RefreshSelector()
end)

TrainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	if TrainFrame.Visible then
		RefreshSelector()
	else
		SetDropdownOpen(false)
	end
end)

if TrainFrame.Visible then
	RefreshSelector()
end