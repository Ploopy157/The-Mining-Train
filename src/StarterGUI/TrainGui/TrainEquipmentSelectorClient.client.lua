local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocomotiveDefinitions = require(
	ReplicatedStorage:WaitForChild("LocomotiveDefinitions")
)

local DrillDefinitions = require(
	ReplicatedStorage:WaitForChild("DrillDefinitions")
)

local TrainRemotes = ReplicatedStorage:WaitForChild("TrainRemotes")

local GetLocomotiveSelectionData = TrainRemotes:WaitForChild(
	"GetLocomotiveSelectionData"
)

local SelectLocomotive = TrainRemotes:WaitForChild(
	"SelectLocomotive"
)

local GetDrillSelectionData = TrainRemotes:WaitForChild(
	"GetDrillSelectionData"
)

local SelectDrill = TrainRemotes:WaitForChild(
	"SelectDrill"
)

local RefreshTrainGui = TrainRemotes:WaitForChild(
	"RefreshTrainGui"
)

local Gui = script.Parent
local TrainFrame = Gui:WaitForChild("TrainFrame")
local StatusLabel = TrainFrame:WaitForChild("StatusLabel")

local LocomotiveSelector = TrainFrame:WaitForChild("LocomotiveSelector")
local LocomotiveSelectedButton = LocomotiveSelector:WaitForChild("SelectedButton")
local LocomotiveSelectedName = LocomotiveSelectedButton:WaitForChild("SelectedName")
local LocomotiveArrow = LocomotiveSelectedButton:WaitForChild("Arrow")
local LocomotiveOptionsFrame = LocomotiveSelector:WaitForChild("OptionsFrame")
local LocomotiveOptionTemplate = LocomotiveOptionsFrame:WaitForChild("OptionTemplate")

local DrillSelector = TrainFrame:WaitForChild("DrillSelector")
local DrillSelectedButton = DrillSelector:WaitForChild("SelectedButton")
local DrillSelectedName = DrillSelectedButton:WaitForChild("SelectedName")
local DrillArrow = DrillSelectedButton:WaitForChild("Arrow")
local DrillOptionsFrame = DrillSelector:WaitForChild("OptionsFrame")
local DrillOptionTemplate = DrillOptionsFrame:WaitForChild("DrillOptionTemplate")

local IsLoadingLocomotives = false
local IsLoadingDrills = false
local IsSelecting = false
local OpenSelectorName = nil

local function SetSelectorOpen(SelectorName)
	OpenSelectorName = SelectorName

	local LocomotiveIsOpen = SelectorName == "Locomotive"
	local DrillIsOpen = SelectorName == "Drill"

	LocomotiveOptionsFrame.Visible = LocomotiveIsOpen
	LocomotiveArrow.Text = LocomotiveIsOpen and "▲" or "▼"

	DrillOptionsFrame.Visible = DrillIsOpen
	DrillArrow.Text = DrillIsOpen and "▲" or "▼"
end

local function CloseAllSelectors()
	SetSelectorOpen(nil)
end

local function ToggleSelector(SelectorName)
	if OpenSelectorName == SelectorName then
		CloseAllSelectors()
	else
		-- Opening either selector automatically closes the other one.
		SetSelectorOpen(SelectorName)
	end
end

local function ClearGeneratedOptions(OptionsFrame, Template)
	for _, Child in OptionsFrame:GetChildren() do
		if Child:IsA("GuiButton") and Child ~= Template then
			Child:Destroy()
		end
	end
end

local function GetLocomotiveDisplayName(LocomotiveId)
	local Definition = LocomotiveDefinitions.Get(LocomotiveId)

	if Definition then
		return Definition.DisplayName or LocomotiveId
	end

	return LocomotiveId or "Unknown Locomotive"
end

local function GetDrillDisplayName(DrillId)
	local Definition = DrillDefinitions.Get(DrillId)

	if Definition then
		return Definition.DisplayName or DrillId
	end

	return DrillId or "Unknown Drill"
end

local function ApplyLocomotiveSelectionData(SelectionData)
	if typeof(SelectionData) ~= "table"
		or SelectionData.Success ~= true then

		LocomotiveSelectedName.Text = "Unable to load"
		ClearGeneratedOptions(
			LocomotiveOptionsFrame,
			LocomotiveOptionTemplate
		)

		return
	end

	LocomotiveSelectedName.Text = GetLocomotiveDisplayName(
		SelectionData.CurrentLocomotiveId
	)

	ClearGeneratedOptions(
		LocomotiveOptionsFrame,
		LocomotiveOptionTemplate
	)

	for _, LocomotiveData in SelectionData.Locomotives do
		local Button = LocomotiveOptionTemplate:Clone()

		Button.Name = LocomotiveData.LocomotiveId .. "Option"
		Button.LayoutOrder = LocomotiveData.LayoutOrder or LocomotiveData.Tier or 0
		Button.Visible = true
		Button.Active = LocomotiveData.IsUnlocked == true
		Button.AutoButtonColor = LocomotiveData.IsUnlocked == true
		Button.Selectable = LocomotiveData.IsUnlocked == true
		Button:SetAttribute("LocomotiveId", LocomotiveData.LocomotiveId)

		Button.LocomotiveName.Text = LocomotiveData.DisplayName

		Button.LocomotiveStats.Text = string.format(
			"Tier %d | Spd %s | Acc %s",
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
				CloseAllSelectors()
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
				warn("SelectLocomotive failed:", SelectionSucceeded)
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
					ApplyLocomotiveSelectionData(
						Result.SelectionData
					)
				end
			end

			CloseAllSelectors()
		end)

		Button.Parent = LocomotiveOptionsFrame
	end
end

local function ApplyDrillSelectionData(SelectionData)
	if typeof(SelectionData) ~= "table"
		or SelectionData.Success ~= true then

		DrillSelectedName.Text = "Unable to load"
		ClearGeneratedOptions(
			DrillOptionsFrame,
			DrillOptionTemplate
		)

		return
	end

	DrillSelectedName.Text = GetDrillDisplayName(
		SelectionData.CurrentDrillId
	)

	ClearGeneratedOptions(
		DrillOptionsFrame,
		DrillOptionTemplate
	)

	for _, DrillData in SelectionData.Drills do
		local Button = DrillOptionTemplate:Clone()

		Button.Name = DrillData.DrillId .. "Option"
		Button.LayoutOrder = DrillData.LayoutOrder or DrillData.Tier or 0
		Button.Visible = true
		Button.Active = DrillData.IsUnlocked == true
		Button.AutoButtonColor = DrillData.IsUnlocked == true
		Button.Selectable = DrillData.IsUnlocked == true
		Button:SetAttribute("DrillId", DrillData.DrillId)

		Button.DrillName.Text = DrillData.DisplayName

		if DrillData.DrillId == "NoDrill" then
			Button.DrillStats.Text = "Remove equipped drill"
		else
			Button.DrillStats.Text = string.format(
				"%dx%d | Dmg %s | Spd %s",
				DrillData.Width or 0,
				DrillData.Height or 0,
				tostring(DrillData.Damage or 0),
				tostring(DrillData.Speed or 0)
			)
		end

		if DrillData.IsSelected then
			Button.Status.Text = "SELECTED"
			Button.Status.TextColor3 = Color3.fromRGB(92, 224, 121)
			Button.BackgroundColor3 = Color3.fromRGB(50, 67, 60)
		elseif DrillData.IsUnlocked then
			Button.Status.Text = "SELECT"
			Button.Status.TextColor3 = Color3.fromRGB(92, 224, 121)
			Button.BackgroundColor3 = Color3.fromRGB(44, 49, 60)
		else
			Button.Status.Text = "LOCKED"
			Button.Status.TextColor3 = Color3.fromRGB(190, 196, 211)
			Button.BackgroundColor3 = Color3.fromRGB(35, 39, 48)
			Button.DrillName.TextColor3 = Color3.fromRGB(150, 155, 168)
			Button.DrillStats.TextColor3 = Color3.fromRGB(120, 125, 138)
		end

		Button.Activated:Connect(function()
			if IsSelecting then
				return
			end

			if not DrillData.IsUnlocked then
				StatusLabel.Text = string.format(
					"Requires drill tier %d.",
					DrillData.Tier or 0
				)

				return
			end

			if DrillData.IsSelected then
				CloseAllSelectors()
				return
			end

			IsSelecting = true
			StatusLabel.Text = "Changing drill..."
			Button.Status.Text = "WAIT"

			local RequestSucceeded, SelectionSucceeded, Result = pcall(function()
				return SelectDrill:InvokeServer(
					DrillData.DrillId
				)
			end)

			IsSelecting = false

			if not RequestSucceeded then
				StatusLabel.Text = "Drill request failed."
				warn("SelectDrill failed:", SelectionSucceeded)
				return
			end

			if not SelectionSucceeded then
				StatusLabel.Text = tostring(
					Result or "Drill selection failed."
				)

				return
			end

			if typeof(Result) == "table" then
				StatusLabel.Text = tostring(
					Result.Message or "Drill selected."
				)

				if typeof(Result.SelectionData) == "table" then
					ApplyDrillSelectionData(
						Result.SelectionData
					)
				end
			end

			CloseAllSelectors()
		end)

		Button.Parent = DrillOptionsFrame
	end
end

local function RefreshLocomotives()
	if IsLoadingLocomotives then
		return
	end

	IsLoadingLocomotives = true

	local Success, SelectionData = pcall(function()
		return GetLocomotiveSelectionData:InvokeServer()
	end)

	IsLoadingLocomotives = false

	if not Success then
		LocomotiveSelectedName.Text = "Unable to load"
		warn("GetLocomotiveSelectionData failed:", SelectionData)
		return
	end

	ApplyLocomotiveSelectionData(SelectionData)
end

local function RefreshDrills()
	if IsLoadingDrills then
		return
	end

	IsLoadingDrills = true

	local Success, SelectionData = pcall(function()
		return GetDrillSelectionData:InvokeServer()
	end)

	IsLoadingDrills = false

	if not Success then
		DrillSelectedName.Text = "Unable to load"
		warn("GetDrillSelectionData failed:", SelectionData)
		return
	end

	ApplyDrillSelectionData(SelectionData)
end

local function RefreshAllSelectors()
	RefreshLocomotives()
	RefreshDrills()
end

LocomotiveSelectedButton.Activated:Connect(function()
	if IsSelecting or IsLoadingLocomotives then
		return
	end

	local WillOpen = OpenSelectorName ~= "Locomotive"

	ToggleSelector("Locomotive")

	if WillOpen then
		RefreshLocomotives()
	end
end)

DrillSelectedButton.Activated:Connect(function()
	if IsSelecting or IsLoadingDrills then
		return
	end

	local WillOpen = OpenSelectorName ~= "Drill"

	ToggleSelector("Drill")

	if WillOpen then
		RefreshDrills()
	end
end)

UserInputService.InputBegan:Connect(function(Input, WasProcessed)
	if WasProcessed or not OpenSelectorName then
		return
	end

	if Input.KeyCode == Enum.KeyCode.Escape
		or Input.KeyCode == Enum.KeyCode.ButtonB then

		CloseAllSelectors()
	end
end)

RefreshTrainGui.OnClientEvent:Connect(function()
	RefreshAllSelectors()
end)

TrainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	if TrainFrame.Visible then
		RefreshAllSelectors()
	else
		CloseAllSelectors()
	end
end)

CloseAllSelectors()

if TrainFrame.Visible then
	RefreshAllSelectors()
end