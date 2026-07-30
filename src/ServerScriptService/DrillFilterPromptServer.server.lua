local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SpawnedTrains = Workspace:WaitForChild("SpawnedTrains")
local OpenDrillFilter = ReplicatedStorage:WaitForChild("DrillFilterRemotes"):WaitForChild("OpenDrillFilter")

local PromptConnections = {}

local function FindDrillModel(DrillBit)
	local Current = DrillBit.Parent

	while Current and Current ~= SpawnedTrains do
		if Current:IsA("Model") and Current:GetAttribute("IsDrill") == true then
			return Current
		end

		if Current:IsA("Model") and string.lower(Current.Name) == "drill" then
			return Current
		end

		Current = Current.Parent
	end

	return nil
end

local function GetOwnerUserId(DrillBit)
	local DrillModel = FindDrillModel(DrillBit)

	if DrillModel then
		local OwnerUserId = DrillModel:GetAttribute("OwnerUserId")

		if typeof(OwnerUserId) == "number" then
			return OwnerUserId
		end
	end

	local TrainModel = DrillBit:FindFirstAncestorWhichIsA("Model")

	while TrainModel and TrainModel.Parent ~= SpawnedTrains do
		TrainModel = TrainModel.Parent

		if TrainModel and not TrainModel:IsA("Model") then
			TrainModel = TrainModel:FindFirstAncestorWhichIsA("Model")
		end
	end

	if TrainModel then
		local OwnerUserId = TrainModel:GetAttribute("OwnerUserId")
			or TrainModel:GetAttribute("PlayerUserId")
			or TrainModel:GetAttribute("UserId")

		if typeof(OwnerUserId) == "number" then
			return OwnerUserId
		end

		local NumberFromName = tonumber(string.match(TrainModel.Name, "(%d+)$"))

		if NumberFromName then
			return NumberFromName
		end
	end

	return nil
end

local function AddPrompt(DrillBit)
	if not DrillBit:IsA("BasePart") or DrillBit.Name ~= "DrillBit" then
		return
	end

	if not DrillBit:IsDescendantOf(SpawnedTrains) then
		return
	end

	local Prompt = DrillBit:FindFirstChild("DrillFilterPrompt")

	if Prompt and not Prompt:IsA("ProximityPrompt") then
		Prompt:Destroy()
		Prompt = nil
	end

	if not Prompt then
		Prompt = Instance.new("ProximityPrompt")
		Prompt.Name = "DrillFilterPrompt"
		Prompt.Parent = DrillBit.Parent.Main
	end

	Prompt.ActionText = "Configure Drill"
	Prompt.ObjectText = "Ore Filter"
	Prompt.KeyboardKeyCode = Enum.KeyCode.E
	Prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	Prompt.HoldDuration = 0
	Prompt.MaxActivationDistance = 10
	Prompt.RequiresLineOfSight = false
	Prompt.Enabled = true

	if PromptConnections[Prompt] then
		PromptConnections[Prompt]:Disconnect()
	end

	PromptConnections[Prompt] = Prompt.Triggered:Connect(function(Player)
		local OwnerUserId = GetOwnerUserId(DrillBit)

		if OwnerUserId and Player.UserId ~= OwnerUserId then
			return
		end

		OpenDrillFilter:FireClient(Player)
	end)

	Prompt.Destroying:Connect(function()
		local Connection = PromptConnections[Prompt]

		if Connection then
			Connection:Disconnect()
			PromptConnections[Prompt] = nil
		end
	end)
end

for _, Object in SpawnedTrains:GetDescendants() do
	AddPrompt(Object)
end

SpawnedTrains.DescendantAdded:Connect(function(Object)
	task.defer(AddPrompt, Object)
end)
