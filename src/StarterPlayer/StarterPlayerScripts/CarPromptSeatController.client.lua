local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local SpawnedTrains = Workspace:WaitForChild("SpawnedTrains")

local IsSitting = false
local CharacterConnections = {}
local TrainConnections = {}

---------------------------------------------------------------------
-- CONNECTION MANAGEMENT
---------------------------------------------------------------------

local function DisconnectConnections(ConnectionList)
	for _, Connection in ConnectionList do
		Connection:Disconnect()
	end

	table.clear(ConnectionList)
end

---------------------------------------------------------------------
-- TRAIN HELPERS
---------------------------------------------------------------------

local function GetPlayerTrain()
	return SpawnedTrains:FindFirstChild(
		"PlayerTrain_" .. Player.UserId
	)
end

local function GetPromptCar(Prompt, TrainModel)
	local Current = Prompt.Parent

	while Current and Current ~= TrainModel do
		if Current:IsA("Model")
			and typeof(
				Current:GetAttribute("CarId")
			) == "string" then

			return Current
		end

		Current = Current.Parent
	end

	return nil
end

local function IsCarPrompt(Prompt, TrainModel)
	if not Prompt:IsA("ProximityPrompt") then
		return false
	end

	return GetPromptCar(
		Prompt,
		TrainModel
	) ~= nil
end

local function UpdateCarPrompts()
	local TrainModel = GetPlayerTrain()

	if not TrainModel then
		return
	end

	local PromptsEnabled =
		not IsSitting

	for _, Object in TrainModel:GetDescendants() do
		if IsCarPrompt(
			Object,
			TrainModel
		) then

			Object.Enabled =
				PromptsEnabled
		end
	end
end

---------------------------------------------------------------------
-- TRAIN SETUP
---------------------------------------------------------------------

local function ConnectTrain(
	TrainModel
)
	DisconnectConnections(
		TrainConnections
	)

	if not TrainModel then
		return
	end

	if TrainModel.Name
		~= "PlayerTrain_" .. Player.UserId then

		return
	end

	table.insert(
		TrainConnections,
		TrainModel.DescendantAdded:Connect(
			function(Object)
				if not Object:IsA(
					"ProximityPrompt"
				) then

					return
				end

				task.defer(function()
					if IsCarPrompt(
						Object,
						TrainModel
					) then

						Object.Enabled =
							not IsSitting
					end
				end)
			end
		)
	)

	table.insert(
		TrainConnections,
		TrainModel.AncestryChanged:Connect(
			function()
				if not TrainModel:IsDescendantOf(
					SpawnedTrains
				) then

					DisconnectConnections(
						TrainConnections
					)
				end
			end
		)
	)

	UpdateCarPrompts()
end

---------------------------------------------------------------------
-- CHARACTER SETUP
---------------------------------------------------------------------

local function SetUpCharacter(
	Character
)
	DisconnectConnections(
		CharacterConnections
	)

	IsSitting = false
	UpdateCarPrompts()

	local Humanoid =
		Character:WaitForChild(
			"Humanoid"
		)

	table.insert(
		CharacterConnections,
		Humanoid.Seated:Connect(
			function(Active)
				IsSitting = Active

				UpdateCarPrompts()
			end
		)
	)

	table.insert(
		CharacterConnections,
		Humanoid:GetPropertyChangedSignal(
			"SeatPart"
		):Connect(function()
			IsSitting =
				Humanoid.SeatPart ~= nil

			UpdateCarPrompts()
		end)
	)
end

---------------------------------------------------------------------
-- EVENTS
---------------------------------------------------------------------

Player.CharacterAdded:Connect(
	SetUpCharacter
)

Player.CharacterRemoving:Connect(
	function()
		DisconnectConnections(
			CharacterConnections
		)

		IsSitting = false
		UpdateCarPrompts()
	end
)

SpawnedTrains.ChildAdded:Connect(
	function(Child)
		if Child.Name
			== "PlayerTrain_" .. Player.UserId then

			task.defer(
				ConnectTrain,
				Child
			)
		end
	end
)

SpawnedTrains.ChildRemoved:Connect(
	function(Child)
		if Child.Name
			== "PlayerTrain_" .. Player.UserId then

			DisconnectConnections(
				TrainConnections
			)
		end
	end
)

if Player.Character then
	SetUpCharacter(
		Player.Character
	)
end

ConnectTrain(
	GetPlayerTrain()
)
