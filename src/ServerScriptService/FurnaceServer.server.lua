local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local FurnaceService = require(ServerScriptService:WaitForChild("FurnaceService"))
local FurnaceRemotes = ReplicatedStorage:WaitForChild("FurnaceRemotes")

local GetFurnaceState = FurnaceRemotes:WaitForChild("GetFurnaceState")
local StoreCoal = FurnaceRemotes:WaitForChild("StoreCoal")
local WithdrawCoal = FurnaceRemotes:WaitForChild("WithdrawCoal")
local AddQueueProcess = FurnaceRemotes:WaitForChild("AddQueueProcess")
local RemoveQueueItem = FurnaceRemotes:WaitForChild("RemoveQueueItem")
local CollectIngots = FurnaceRemotes:WaitForChild("CollectIngots")
local OpenFurnace = FurnaceRemotes:WaitForChild("OpenFurnace")
local FurnaceUpdated = FurnaceRemotes:WaitForChild("FurnaceUpdated")

local Stations = Workspace:WaitForChild("Stations")
local PromptConnections = {}

local function GetStation(Object)
	local Current = Object

	while Current and Current ~= Stations do
		if Current:IsA("Model")
			and Current:GetAttribute("OwnerUserId") ~= nil then

			return Current
		end

		Current = Current.Parent
	end

	return nil
end

local function IsOwner(Player, Part)
	local Station = GetStation(Part)

	if not Station then
		return false
	end

	return Station:GetAttribute("OwnerUserId") == Player.UserId
end

local function ConfigurePrompt(Part, ActionText, ObjectText)
	local Prompt = Part:FindFirstChild("FurnacePrompt")

	if Prompt and not Prompt:IsA("ProximityPrompt") then
		Prompt:Destroy()
		Prompt = nil
	end

	if not Prompt then
		Prompt = Instance.new("ProximityPrompt")
		Prompt.Name = "FurnacePrompt"
		Prompt.Parent = Part
	end

	Prompt.ActionText = ActionText
	Prompt.ObjectText = ObjectText
	Prompt.KeyboardKeyCode = Enum.KeyCode.E
	Prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	Prompt.HoldDuration = 0
	Prompt.MaxActivationDistance = 10
	Prompt.RequiresLineOfSight = false
	Prompt.Enabled = true

	return Prompt
end

local function ConnectPart(Part)
	if not Part:IsA("BasePart") then
		return
	end

	local Prompt
	local Mode

	if Part.Name == "FurnaceDropoff" then
		Prompt = ConfigurePrompt(Part, "Load Furnace", "Ore & Coal")
		Mode = "Load"
	elseif Part.Name == "FurnaceInteraction" then
		Prompt = ConfigurePrompt(Part, "Manage Furnace", "Smelting Queue")
		Mode = "Queue"
	elseif Part.Name == "FurnaceInventory" then
		Prompt = ConfigurePrompt(Part, "View Ingots", "Finished Smelting")
		Mode = "Finished"
	else
		return
	end

	if PromptConnections[Prompt] then
		PromptConnections[Prompt]:Disconnect()
	end

	PromptConnections[Prompt] = Prompt.Triggered:Connect(function(Player)
		if not IsOwner(Player, Part) then
			return
		end

		local State = FurnaceService.GetState(Player)
		OpenFurnace:FireClient(Player, Mode, nil, State)
	end)
end

for _, Object in Stations:GetDescendants() do
	ConnectPart(Object)
end

Stations.DescendantAdded:Connect(function(Object)
	task.defer(ConnectPart, Object)
end)

GetFurnaceState.OnServerInvoke = function(Player)
	return FurnaceService.GetState(Player)
end

StoreCoal.OnServerInvoke = function(Player, Quantity)
	local Success, Result = FurnaceService.StoreCoal(Player, Quantity)

	if Success then
		FurnaceUpdated:FireClient(Player, Result.State)
	end

	return Success, Result
end

WithdrawCoal.OnServerInvoke = function(Player, Quantity)
	local Success, Result = FurnaceService.WithdrawCoal(Player, Quantity)

	if Success then
		FurnaceUpdated:FireClient(Player, Result.State)
	end

	return Success, Result
end

AddQueueProcess.OnServerInvoke = function(Player, OreName)
	local Success, Result = FurnaceService.AddQueueProcess(Player, OreName)

	if Success then
		FurnaceUpdated:FireClient(Player, Result.State)
	end

	return Success, Result
end

RemoveQueueItem.OnServerInvoke = function(Player, QueueIndex)
	local Success, Result = FurnaceService.RemoveQueueItem(Player, QueueIndex)

	if Success then
		FurnaceUpdated:FireClient(Player, Result.State)
	end

	return Success, Result
end

CollectIngots.OnServerInvoke = function(Player)
	local Success, Result = FurnaceService.CollectAll(Player)

	if Success then
		FurnaceUpdated:FireClient(Player, Result.State)
	end

	return Success, Result
end

task.spawn(function()
	while true do
		task.wait(1)

		for _, Player in Players:GetPlayers() do
			FurnaceService.Process(Player)
		end
	end
end)
