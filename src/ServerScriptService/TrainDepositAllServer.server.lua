local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local PlayerDataService = require(
	ServerScriptService:WaitForChild("PlayerDataService")
)

local TrainInventoryService = require(
	ServerScriptService:WaitForChild(
		"TrainInventoryService"
	)
)

local TrainRemotes =
	ReplicatedStorage:WaitForChild("TrainRemotes")

local DepositAllToCar =
	TrainRemotes:WaitForChild("DepositAllToCar")

local RefreshTrainGui =
	TrainRemotes:WaitForChild("RefreshTrainGui")

local SpawnedTrains =
	Workspace:WaitForChild("SpawnedTrains")

-- Adjust this to change the prompt and server distance.
local MaximumCarInteractionDistance = 8

---------------------------------------------------------------------
-- TRAIN AND CAR HELPERS
---------------------------------------------------------------------

local function GetPlayerTrain(Player)
	return SpawnedTrains:FindFirstChild(
		"PlayerTrain_" .. Player.UserId
	)
end

local function GetPhysicalCar(Player, CarId)
	local TrainModel = GetPlayerTrain(Player)

	if not TrainModel then
		return nil
	end

	for _, Child in TrainModel:GetChildren() do
		if Child:IsA("Model")
			and Child:GetAttribute("CarId") == CarId
			and Child:GetAttribute("OwnerUserId")
				== Player.UserId then

			return Child
		end
	end

	return nil
end

local function GetInteractionPart(CarModel)
	local InteractionPart =
		CarModel:FindFirstChild(
			"InteractionPart",
			true
		)

	if InteractionPart
		and InteractionPart:IsA("BasePart") then

		return InteractionPart
	end

	if CarModel.PrimaryPart then
		return CarModel.PrimaryPart
	end

	return nil
end

local function IsPlayerNearCar(Player, CarModel)
	local Character = Player.Character

	if not Character then
		return false
	end

	local Root =
		Character:FindFirstChild(
			"HumanoidRootPart"
		)

	if not Root then
		return false
	end

	local InteractionPart =
		GetInteractionPart(CarModel)

	if not InteractionPart then
		return false
	end

	return (
		Root.Position - InteractionPart.Position
	).Magnitude <= MaximumCarInteractionDistance
end

---------------------------------------------------------------------
-- INVENTORY HELPERS
---------------------------------------------------------------------

local function GetInventoryLoad(Inventory)
	local Total = 0

	for _, Quantity in Inventory do
		if typeof(Quantity) == "number"
			and Quantity > 0 then

			Total += Quantity
		end
	end

	return Total
end

local function GetSortedOreNames(Inventory)
	local OreNames = {}

	for OreName, Quantity in Inventory do
		if typeof(OreName) == "string"
			and typeof(Quantity) == "number"
			and Quantity > 0 then

			table.insert(OreNames, OreName)
		end
	end

	table.sort(OreNames, function(First, Second)
		return First:lower() < Second:lower()
	end)

	return OreNames
end

local function DepositEntireBackpack(
	Player,
	CarId
)
	local Data = PlayerDataService.GetData(Player)

	if not Data then
		return false, "Player data is not loaded."
	end

	if typeof(Data.Inventory) ~= "table" then
		Data.Inventory = {}
	end

	local CarData =
		TrainInventoryService.FindCarData(
			Player,
			CarId
		)

	if not CarData then
		return false, "Car data was not found."
	end

	if typeof(CarData.Inventory) ~= "table" then
		CarData.Inventory = {}
	end

	local CarLoad =
		GetInventoryLoad(CarData.Inventory)

	local RemainingSpace =
		math.max(
			CarData.Capacity - CarLoad,
			0
		)

	if RemainingSpace <= 0 then
		return false, "The car is full."
	end

	local BackpackLoad =
		GetInventoryLoad(Data.Inventory)

	if BackpackLoad <= 0 then
		return false, "Your bag is empty."
	end

	local TotalDeposited = 0
	local DepositedItems = {}

	-- Alphabetical order makes partial deposits predictable
	-- when the car cannot hold the entire backpack.
	for _, OreName in GetSortedOreNames(
		Data.Inventory
	) do
		if RemainingSpace <= 0 then
			break
		end

		local AvailableQuantity =
			Data.Inventory[OreName] or 0

		local DepositQuantity = math.min(
			AvailableQuantity,
			RemainingSpace
		)

		if DepositQuantity > 0 then
			local NewBackpackQuantity =
				AvailableQuantity
				- DepositQuantity

			if NewBackpackQuantity <= 0 then
				Data.Inventory[OreName] = nil
			else
				Data.Inventory[OreName] =
					NewBackpackQuantity
			end

			CarData.Inventory[OreName] =
				(CarData.Inventory[OreName] or 0)
				+ DepositQuantity

			TotalDeposited += DepositQuantity
			RemainingSpace -= DepositQuantity

			table.insert(DepositedItems, {
				Name = OreName,
				Quantity = DepositQuantity,
			})
		end
	end

	if TotalDeposited <= 0 then
		return false, "No ore could be deposited."
	end

	return true, {
		TotalDeposited = TotalDeposited,
		RemainingSpace = RemainingSpace,
		Items = DepositedItems,
	}
end

---------------------------------------------------------------------
-- CAR VISUAL
---------------------------------------------------------------------

local function UpdateCarVisual(
	Player,
	CarId
)
	local CarData =
		TrainInventoryService.FindCarData(
			Player,
			CarId
		)

	local CarModel =
		GetPhysicalCar(Player, CarId)

	if not CarData or not CarModel then
		return
	end

	local CargoDisplay =
		CarModel:FindFirstChild(
			"CargoDisplay",
			true
		)

	if not CargoDisplay
		or not CargoDisplay:IsA("BasePart") then

		return
	end

	local Load =
		GetInventoryLoad(CarData.Inventory)

	local Capacity =
		math.max(CarData.Capacity, 1)

	local FillRatio =
		math.clamp(
			Load / Capacity,
			0,
			1
		)

	local OriginalSize =
		CargoDisplay:GetAttribute(
			"DepositAllOriginalSize"
		)

	local OriginalCFrame =
		CargoDisplay:GetAttribute(
			"DepositAllOriginalCFrame"
		)

	if typeof(OriginalSize) ~= "Vector3" then
		OriginalSize = CargoDisplay.Size

		CargoDisplay:SetAttribute(
			"DepositAllOriginalSize",
			OriginalSize
		)
	end

	if typeof(OriginalCFrame) ~= "CFrame" then
		OriginalCFrame = CargoDisplay.CFrame

		CargoDisplay:SetAttribute(
			"DepositAllOriginalCFrame",
			OriginalCFrame
		)
	end

	local MaximumHeight =
		math.max(OriginalSize.Y, 2.4)

	local NewHeight =
		math.max(0.1, MaximumHeight * FillRatio)

	local LocalBottomOffset =
		-OriginalSize.Y / 2

	local LocalCenterOffset =
		LocalBottomOffset + NewHeight / 2

	CargoDisplay.Size = Vector3.new(
		OriginalSize.X,
		NewHeight,
		OriginalSize.Z
	)

	CargoDisplay.CFrame =
		OriginalCFrame
		* CFrame.new(
			0,
			LocalCenterOffset,
			0
		)

	CargoDisplay.Transparency =
		Load <= 0 and 1 or 0
end

local function FireInventoryRefresh(Player)
	RefreshTrainGui:FireClient(Player)

	for _, RemoteName in {
		"InventoryChanged",
		"RefreshInventory",
		"RefreshBackpack",
	} do
		local Remote =
			ReplicatedStorage:FindFirstChild(
				RemoteName,
				true
			)

		if Remote and Remote:IsA("RemoteEvent") then
			Remote:FireClient(Player)
		end
	end
end

---------------------------------------------------------------------
-- VALIDATED DEPOSIT
---------------------------------------------------------------------

local function HandleDepositAll(
	Player,
	CarId
)
	if typeof(CarId) ~= "string" then
		return false, "Invalid car."
	end

	local CarModel =
		GetPhysicalCar(Player, CarId)

	if not CarModel then
		return false, "Your car was not found."
	end

	if CarModel:GetAttribute("OwnerUserId")
		~= Player.UserId then

		return false, "You do not own this car."
	end

	if not IsPlayerNearCar(Player, CarModel) then
		return false, "Move closer to the car."
	end

	local Success, Result =
		DepositEntireBackpack(
			Player,
			CarId
		)

	if not Success then
		return false, Result
	end

	UpdateCarVisual(Player, CarId)
	FireInventoryRefresh(Player)

	return true, Result
end

DepositAllToCar.OnServerInvoke = function(
	Player,
	CarId
)
	return HandleDepositAll(Player, CarId)
end

---------------------------------------------------------------------
-- SECOND PROXIMITY PROMPT
---------------------------------------------------------------------

local function ConfigureDepositPrompt(
	CarModel
)
	if not CarModel:IsA("Model") then
		return
	end

	local CarId =
		CarModel:GetAttribute("CarId")

	local OwnerUserId =
		CarModel:GetAttribute("OwnerUserId")

	if typeof(CarId) ~= "string"
		or typeof(OwnerUserId) ~= "number" then

		return
	end

	local InteractionPart =
		GetInteractionPart(CarModel)

	if not InteractionPart then
		return
	end

	local ExistingPrompt =
		InteractionPart:FindFirstChild(
			"DepositAllPrompt"
		)

	if ExistingPrompt then
		ExistingPrompt:Destroy()
	end

	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Name = "DepositAllPrompt"
	Prompt.ActionText = "Deposit All"
	Prompt.ObjectText =
		"Ore Car " .. tostring(
			CarModel:GetAttribute("TrainIndex")
				or ""
		)

	Prompt.HoldDuration = 0
	Prompt.MaxActivationDistance =
		MaximumCarInteractionDistance

	Prompt.RequiresLineOfSight = false

	-- E remains Manage Cargo.
	Prompt.KeyboardKeyCode = Enum.KeyCode.F
	Prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	Prompt.Parent = InteractionPart
	Prompt.UIOffset = Vector2.new(0,75)

	Prompt.Triggered:Connect(function(Player)
		if Player.UserId ~= OwnerUserId then
			return
		end

		HandleDepositAll(Player, CarId)
	end)
end

local function ConfigureTrain(
	TrainModel
)
	if not TrainModel:IsA("Model") then
		return
	end

	for _, Child in TrainModel:GetChildren() do
		ConfigureDepositPrompt(Child)
	end

	TrainModel.ChildAdded:Connect(function(Child)
		task.defer(function()
			ConfigureDepositPrompt(Child)
		end)
	end)
end

for _, TrainModel in SpawnedTrains:GetChildren() do
	ConfigureTrain(TrainModel)
end

SpawnedTrains.ChildAdded:Connect(function(TrainModel)
	task.defer(function()
		ConfigureTrain(TrainModel)
	end)
end)
