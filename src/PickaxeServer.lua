local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local PlayerDataService = require(
	ServerScriptService:WaitForChild(
		"PlayerDataService"
	)
)

local TrainInventoryService = require(
	ServerScriptService:WaitForChild(
		"TrainInventoryService"
	)
)

local CarCargoVisualService = require(
	ServerScriptService:WaitForChild(
		"CarCargoVisualService"
	)
)

local SpawnedTrains =
	Workspace:WaitForChild("SpawnedTrains")

-- How often saved cargo is compared to displayed cargo.
local RefreshInterval = 0.25

local LastSignatures = {}

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------

local function GetPlayerTrain(Player)
	return SpawnedTrains:FindFirstChild(
		"PlayerTrain_" .. Player.UserId
	)
end

local function GetCarKey(Player, CarId)
	return tostring(Player.UserId)
		.. ":"
		.. tostring(CarId)
end

local function FindCarModel(
	TrainModel,
	CarId
)
	for _, Child in TrainModel:GetChildren() do
		if Child:IsA("Model")
			and Child:GetAttribute("CarId")
				== CarId then

			return Child
		end
	end

	return nil
end

local function UpdatePlayerCars(Player)
	local Data =
		PlayerDataService.GetData(Player)

	if not Data
		or typeof(Data.Train) ~= "table"
		or typeof(Data.Train.Cars) ~= "table" then

		return
	end

	local TrainModel =
		GetPlayerTrain(Player)

	if not TrainModel then
		return
	end

	for _, CarData in Data.Train.Cars do
		local CarId = CarData.CarId

		if typeof(CarId) == "string" then
			local CarModel =
				FindCarModel(
					TrainModel,
					CarId
				)

			if CarModel then
				local Signature =
					CarCargoVisualService
						.GetInventorySignature(
							CarData
						)

				local CarKey =
					GetCarKey(
						Player,
						CarId
					)

				if LastSignatures[CarKey]
					~= Signature then

					CarCargoVisualService.UpdateCar(
						CarModel,
						CarData
					)

					LastSignatures[CarKey] =
						Signature
				else
					-- Older scripts may resize or reveal
					-- CargoDisplay after a transfer. Calling
					-- Prepare indirectly keeps it hidden and
					-- restored without rebuilding the grid.
					local CargoDisplay =
						CarModel:FindFirstChild(
							"CargoDisplay",
							true
						)

					if CargoDisplay
						and CargoDisplay:IsA(
							"BasePart"
						) then

						CargoDisplay.Transparency = 1
						CargoDisplay.CanCollide = false
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- WATCH LOOP
---------------------------------------------------------------------

task.spawn(function()
	while true do
		task.wait(RefreshInterval)

		for _, Player in Players:GetPlayers() do
			local Success, ErrorMessage =
				pcall(
					UpdatePlayerCars,
					Player
				)

			if not Success then
				warn(
					"Cargo visual update failed:",
					ErrorMessage
				)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(Player)
	local Prefix =
		tostring(Player.UserId) .. ":"

	for CarKey in LastSignatures do
		if string.sub(
			CarKey,
			1,
			#Prefix
		) == Prefix then

			LastSignatures[CarKey] = nil
		end
	end
end)
