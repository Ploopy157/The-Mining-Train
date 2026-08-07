local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("TutorialRemotes")

local ResponsiveGui = require(ReplicatedStorage:WaitForChild("ResponsiveGui"))

local GetTutorialData = Remotes:WaitForChild("GetTutorialData")

local UpdateTutorialStep = Remotes:WaitForChild("UpdateTutorialStep")

local ResetTutorial = Remotes:WaitForChild("ResetTutorial")

local Gui = script.Parent
local TutorialFrame = Gui:WaitForChild("TutorialFrame")
local TutorialButton = PlayerGui:WaitForChild("SettingsGui"):WaitForChild("Window"):WaitForChild("Content"):WaitForChild("TutorialSection"):WaitForChild("TutorialButton")
local Pointer = Gui:WaitForChild("Pointer")

local Header = TutorialFrame:WaitForChild("Header")
local TitleLabel = Header:WaitForChild("TitleLabel")
local StepLabel = Header:WaitForChild("StepLabel")



local DescriptionLabel =
	TutorialFrame:WaitForChild("DescriptionLabel")

local ObjectiveLabel =
	TutorialFrame:WaitForChild("ObjectiveLabel")

local ButtonFrame =
	TutorialFrame:WaitForChild("ButtonFrame")

local SkipButton =
	ButtonFrame:WaitForChild("SkipButton")

local BackButton =
	ButtonFrame:WaitForChild("BackButton")

local NextButton =
	ButtonFrame:WaitForChild("NextButton")


local CurrentStep = 1
local IsOpen = false
local ObjectiveComplete = false
local IsUpdating = false
local PointerTarget = nil
local StartingCash = 0

local Steps = {
	[1] = {
		Title = "Welcome to Ro-Scale Mining Tycoon",
		Description = "Mine ore, load your train, return to your station, sell cargo, and purchase upgrades!",
		Objective = "Press Next to begin.",
		Manual = true,
	},

	[2] = {
		Title = "Mine Your First Ore",
		Description = "Push your train to the mine entrance, then equip your pickaxe, and mine until you find some ore.",
		Objective = "Mine at least one ore.",
		CheckType = "Inventory",
	},

	[3] = {
		Title = "Check Your Bag",
		Description = "Your bag stores ore mined with your pickaxe. Open it using the BAG button.",
		Objective = "Open the Bag menu.",
		CheckType = "BagOpen",
		PointerTarget = "BagButton",
	},

	[4] = {
		Title = "Load an Ore Car",
		Description = "Walk to one of your ore cars and use Deposit All, or open Manage Cargo and deposit ore manually.",
		Objective = "Deposit at least one ore into a train car.",
		CheckType = "TrainLoad",
	},

	[5] = {
		Title = "Sell Your Ore",
		Description = "Push the train cars inside the station platform, this will allow you to sell ore directly out of your train! Then visit the Ore Shop, and sell your ores for some nice profit!.",
		Objective = "Earn cash by selling ore.",
		CheckType = "Cash",
	},

	[6] = {
		Title = "Purchase an Upgrade",
		Description = "Visit the Upgrade Shop and purchase any available upgrade.",
		Objective = "Purchase one upgrade.",
		CheckType = "Upgrade",
	},

	[7] = {
		Title = "Tutorial Complete",
		Description = "Once you have enough ores, you can go to the furnace and smelt them down for even more money!",
		Objective = "Click Next",
		Manual = true,
	},
	[8] = {
		Title = "Tutorial Complete",
		Description = "Now you now how to play! Mine deeper, expand your train, and improve your equipment.",
		Objective = "Press Finish.",
		Manual = true,
	},

}
local TotalSteps = #Steps

local function FindDescendantByName(
	Parent,
	TargetName
)
	for _, Descendant in Parent:GetDescendants() do
		if Descendant.Name == TargetName then
			return Descendant
		end
	end

	return nil
end

local function SetPointerTarget(TargetName)
	PointerTarget = nil
	Pointer.Visible = false

	if not TargetName then
		return
	end

	local Target =
		FindDescendantByName(
			PlayerGui,
			TargetName
		)

	if Target and Target:IsA("GuiObject") then
		PointerTarget = Target
		Pointer.Visible = true
	end
end

RunService.RenderStepped:Connect(function()
	if not PointerTarget
		or not PointerTarget.Parent
		or not PointerTarget.Visible then

		Pointer.Visible = false
		return
	end

	local Position =
		PointerTarget.AbsolutePosition

	local Size =
		PointerTarget.AbsoluteSize

	Pointer.Position = UDim2.fromOffset(
		Position.X - 34,
		Position.Y + Size.Y / 2
	)

	Pointer.Rotation = 0
	Pointer.Visible = true
end)

local function SetObjectiveComplete(Complete)
	ObjectiveComplete = Complete

	local StepData = Steps[CurrentStep]

	if StepData.Manual then
		NextButton.Active = true
		NextButton.AutoButtonColor = true
		NextButton.BackgroundColor3 =
			Color3.fromRGB(53, 128, 76)

		return
	end

	NextButton.Active = Complete
	NextButton.AutoButtonColor = Complete
	NextButton.BackgroundColor3 =
		Complete
		and Color3.fromRGB(53, 128, 76)
		or Color3.fromRGB(72, 76, 86)

	if Complete then
		ObjectiveLabel.Text =
			"✓ Objective complete!"

		ObjectiveLabel.TextColor3 =
			Color3.fromRGB(92, 224, 121)
	else
		ObjectiveLabel.Text =
			StepData.Objective

		ObjectiveLabel.TextColor3 =
			Color3.fromRGB(255, 207, 92)
	end
end

local function DisplayStep()
	local StepData = Steps[CurrentStep]

	if not StepData then
		return
	end

	TitleLabel.Text = StepData.Title
	DescriptionLabel.Text = StepData.Description
	ObjectiveLabel.Text = StepData.Objective

	StepLabel.Text = string.format(
		"STEP %d / %d",
		CurrentStep,
		TotalSteps
	)

	BackButton.Visible = CurrentStep > 1

	if CurrentStep == TotalSteps then
		NextButton.Text = "FINISH"
	else
		NextButton.Text = "NEXT"
	end

	SetPointerTarget(StepData.PointerTarget)

	if StepData.Manual then
		SetObjectiveComplete(true)
	else
		SetObjectiveComplete(false)
	end

	if StepData.CheckType == "Cash" then
		local Leaderstats =
			Player:FindFirstChild("leaderstats")

		local Cash =
			Leaderstats
			and Leaderstats:FindFirstChild("Cash")

		StartingCash = Cash and Cash.Value or 0
	end
end

local function SetOpen(ShouldOpen)
	IsOpen = ShouldOpen
	TutorialFrame.Visible = ShouldOpen

	if not ShouldOpen then
		Pointer.Visible = false
	else
		DisplayStep()
	end
end

local function SaveStep(
	Step,
	Completed
)
	if IsUpdating then
		return
	end

	IsUpdating = true

	pcall(function()
		UpdateTutorialStep:InvokeServer(
			Step,
			Completed
		)
	end)

	IsUpdating = false
end

local function GetInventoryQuantity()
	local GetInventory =
		ReplicatedStorage:FindFirstChild(
			"GetInventory",
			true
		)

	if not GetInventory
		or not GetInventory:IsA("RemoteFunction") then

		return 0
	end

	local Success, Data = pcall(function()
		return GetInventory:InvokeServer()
	end)

	if not Success or typeof(Data) ~= "table" then
		return 0
	end

	return Data.TotalQuantity or 0
end

local function GetTrainLoad()
	local TrainRemotes =
		ReplicatedStorage:FindFirstChild(
			"TrainRemotes"
		)

	local GetTrainOverview =
		TrainRemotes
		and TrainRemotes:FindFirstChild(
			"GetTrainOverview"
		)

	if not GetTrainOverview then
		return 0
	end

	local Success, Data = pcall(function()
		return GetTrainOverview:InvokeServer()
	end)

	if not Success or typeof(Data) ~= "table" then
		return 0
	end

	return Data.TotalTrainLoad or 0
end

local function IsBagOpen()
	local BackpackGui =
		PlayerGui:FindFirstChild("BackpackGui")

	if not BackpackGui then
		return false
	end

	for _, Descendant in BackpackGui:GetDescendants() do
		if Descendant:IsA("Frame")
			and Descendant.Visible
			and Descendant.Name ~= "Header" then

			return true
		end
	end

	return false
end

local function IsNearHome()
	local Stations =
		Workspace:FindFirstChild("Stations")

	if not Stations then
		return false
	end

	local Station = nil

	for _, Candidate in Stations:GetChildren() do
		if Candidate:GetAttribute("OwnerUserId")
			== Player.UserId then

			Station = Candidate
			break
		end
	end

	if not Station then
		return false
	end

	local HomePart =
		Station:FindFirstChild("HomeSpawn", true)
		or Station:FindFirstChild("PlayerSpawn", true)
		or Station:FindFirstChild(
			"TrainSpawnOrigin",
			true
		)

	local Character = Player.Character
	local Root =
		Character
		and Character:FindFirstChild(
			"HumanoidRootPart"
		)

	if not HomePart
		or not Root
		or not HomePart:IsA("BasePart") then

		return false
	end

	return (
		Root.Position - HomePart.Position
	).Magnitude <= 20
end

local function HasPurchasedUpgrade()
	local RemotesFolder =
		ReplicatedStorage:FindFirstChild(
			"UpgradeShopRemotes"
		)

	local GetUpgradeData =
		RemotesFolder
		and RemotesFolder:FindFirstChild(
			"GetUpgradeShopData"
		)

	if not GetUpgradeData then
		return false
	end

	local Success, Data = pcall(function()
		return GetUpgradeData:InvokeServer()
	end)

	if not Success or typeof(Data) ~= "table" then
		return false
	end

	for _, UpgradeData in Data.Upgrades or {} do
		if (UpgradeData.Level or 0) > 0 then
			return true
		end
	end

	return false
end

local function CheckCurrentObjective()
	if not IsOpen or ObjectiveComplete then
		return
	end

	local StepData = Steps[CurrentStep]

	if not StepData or StepData.Manual then
		return
	end

	local Complete = false

	if StepData.CheckType == "Inventory" then
		Complete = GetInventoryQuantity() > 0

	elseif StepData.CheckType == "BagOpen" then
		Complete = IsBagOpen()

	elseif StepData.CheckType == "TrainLoad" then
		Complete = GetTrainLoad() > 0

	elseif StepData.CheckType == "Home" then
		Complete = IsNearHome()

	elseif StepData.CheckType == "Cash" then
		local Leaderstats =
			Player:FindFirstChild("leaderstats")

		local Cash =
			Leaderstats
			and Leaderstats:FindFirstChild("Cash")

		Complete =
			Cash
			and Cash.Value > StartingCash
			or false

	elseif StepData.CheckType == "Upgrade" then
		Complete = HasPurchasedUpgrade()
	end

	if Complete then
		SetObjectiveComplete(true)
		SaveStep(CurrentStep, false)
	end
end

task.spawn(function()
	while true do
		task.wait(0.75)

		if IsOpen then
			CheckCurrentObjective()
		end
	end
end)

NextButton.Activated:Connect(function()
	if not ObjectiveComplete then
		return
	end

	if CurrentStep >= TotalSteps then
		SaveStep(TotalSteps, true)
		SetOpen(false)
		return
	end

	CurrentStep += 1
	SaveStep(CurrentStep, false)
	DisplayStep()
end)

BackButton.Activated:Connect(function()
	if CurrentStep <= 1 then
		return
	end

	CurrentStep -= 1
	DisplayStep()
end)

SkipButton.Activated:Connect(function()
	SaveStep(TotalSteps, true)
	SetOpen(false)
end)

TutorialButton.Activated:Connect(function()
	SetOpen(not IsOpen)
end)

local Success, TutorialData = pcall(function()
	return GetTutorialData:InvokeServer()
end)

local function ReplayTutorial()
	local Success, ResetData = pcall(function()
		return ResetTutorial:InvokeServer()
	end)

	if not Success then
		warn("Failed to reset tutorial.")
		return
	end

	CurrentStep = 1
	ObjectiveComplete = false
	StartingCash = 0
	SetOpen(true)
end

TutorialButton.Activated:Connect(function()
	if IsOpen then
		SetOpen(false)
		return
	end

	ReplayTutorial()
end)

if Success and typeof(TutorialData) == "table" then
	CurrentStep = math.clamp(
		TutorialData.Step or 1,
		1,
		TotalSteps
	)

	if not TutorialData.Completed then
		task.wait(1)
		SetOpen(true)
	end
else
	task.wait(1)
	SetOpen(true)
end

-- ResponsiveGui.Bind(function(Layout)
-- 	if Layout == ResponsiveGui.Layout.Compact then
-- 	else
-- 		-- Keep the current working desktop layout here.
-- 	end
-- end)


