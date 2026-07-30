-- The Mining Train - Studio Repair Command
-- Run once in Roblox Studio's Command Bar while the game is stopped.
-- Every changed script is backed up under ServerStorage.CodeMigrationBackups.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")

ChangeHistoryService:SetWaypoint("Before Mining Train Repair")

local BackupRoot = ServerStorage:FindFirstChild("CodeMigrationBackups")
if not BackupRoot then
	BackupRoot = Instance.new("Folder")
	BackupRoot.Name = "CodeMigrationBackups"
	BackupRoot.Parent = ServerStorage
end

local BackupFolder = Instance.new("Folder")
BackupFolder.Name = "Repair_" .. os.date("!%Y%m%d_%H%M%S")
BackupFolder.Parent = BackupRoot

local Changed = {}
local WarningCount = 0

local function GetPath(Object)
	local Parts = {}
	local Current = Object

	while Current and Current ~= game do
		table.insert(Parts, 1, Current.Name)
		Current = Current.Parent
	end

	return table.concat(Parts, ".")
end

local function FindSource(Names)
	for _, Object in game:GetDescendants() do
		if Object:IsA("LuaSourceContainer") then
			for _, Name in Names do
				if string.lower(Object.Name) == string.lower(Name) then
					return Object
				end
			end
		end
	end

	return nil
end

local function Backup(Object)
	if Changed[Object] then
		return
	end

	local Value = Instance.new("StringValue")
	Value.Name = Object.Name
	Value.Value = Object.Source
	Value:SetAttribute("OriginalPath", GetPath(Object))
	Value:SetAttribute("OriginalClassName", Object.ClassName)
	Value.Parent = BackupFolder

	Changed[Object] = true
end

local function SetSource(Object, Source)
	if Source == Object.Source then
		return
	end

	Backup(Object)
	Object.Source = Source
	print("[Mining Train Repair] Updated " .. GetPath(Object))
end

local function ReplaceOnce(Source, OldText, NewText, Label)
	local StartPosition, EndPosition =
		string.find(Source, OldText, 1, true)

	if not StartPosition then
		error("Missing expected source block: " .. Label)
	end

	return string.sub(Source, 1, StartPosition - 1)
		.. NewText
		.. string.sub(Source, EndPosition + 1)
end

local function RemoveIfPresent(Source, Text)
	local StartPosition, EndPosition =
		string.find(Source, Text, 1, true)

	if not StartPosition then
		return Source
	end

	return string.sub(Source, 1, StartPosition - 1)
		.. string.sub(Source, EndPosition + 1)
end

local function Patch(Names, Callback)
	local Object = FindSource(Names)

	if not Object then
		WarningCount += 1
		warn(
			"[Mining Train Repair] Could not find "
				.. table.concat(Names, " / ")
		)
		return
	end

	local Success, Result =
		pcall(Callback, Object.Source, Object)

	if not Success then
		WarningCount += 1
		warn(
			"[Mining Train Repair] "
				.. GetPath(Object)
				.. " was not changed: "
				.. tostring(Result)
		)
		return
	end

	SetSource(Object, Result)
end

---------------------------------------------------------------------
-- MINING: REQUIRE HEALTH TO REACH ZERO
---------------------------------------------------------------------

Patch(
	{"GenerateOre", "GenerateOre.Lua", "MineGenerationServer"},
	function(Source)
		if not string.find(
			Source,
			"if CurrentHealth > 0 then",
			1,
			true
		) then
			Source = ReplaceOnce(
				Source,
				[[	CurrentHealth = math.max(CurrentHealth - Damage, 0)
	Ore:SetAttribute("Health", CurrentHealth)]],
				[[	CurrentHealth = math.max(CurrentHealth - Damage, 0)
	Ore:SetAttribute("Health", CurrentHealth)

	-- Do not collect or destroy the block until its health reaches zero.
	if CurrentHealth > 0 then
		return
	end]],
				"ore health gate"
			)
		end

		if not string.find(
			Source,
			"local MineOverlapParameters",
			1,
			true
		) then
			Source = ReplaceOnce(
				Source,
				[[local NeighborDirections = {
	Vector3.new(1, 0, 0),
	Vector3.new(-1, 0, 0),
	Vector3.new(0, 1, 0),
	Vector3.new(0, -1, 0),
	Vector3.new(0, 0, 1),
	Vector3.new(0, 0, -1),
}]],
				[[local NeighborDirections = {
	Vector3.new(1, 0, 0),
	Vector3.new(-1, 0, 0),
	Vector3.new(0, 1, 0),
	Vector3.new(0, -1, 0),
	Vector3.new(0, 0, 1),
	Vector3.new(0, 0, -1),
}

local MineOverlapParameters = OverlapParams.new()
MineOverlapParameters.FilterType = Enum.RaycastFilterType.Include
MineOverlapParameters.FilterDescendantsInstances = {MineFolder}]],
				"cached mine overlap parameters"
			)

			Source = ReplaceOnce(
				Source,
				[[	local OverlapParameters = OverlapParams.new()
	OverlapParameters.FilterType = Enum.RaycastFilterType.Include
	OverlapParameters.FilterDescendantsInstances = {MineFolder}

	-- Slightly smaller than the block so neighboring blocks are not detected.]],
				[[	-- Slightly smaller than the block so neighboring blocks are not detected.]],
				"remove repeated OverlapParams allocation"
			)

			Source = ReplaceOnce(
				Source,
				[[		OverlapParameters
	)]],
				[[		MineOverlapParameters
	)]],
				"use cached OverlapParams"
			)
		end

		return Source
	end
)

---------------------------------------------------------------------
-- CARGO VISUAL CLEAR FIX
---------------------------------------------------------------------

Patch({"CarCargoVisualService"}, function(Source)
	local OldBlock = [[function CarCargoVisualService.ClearCar(
	Car,
	UnlockedSlotCount
)
	return CarCargoVisualService.RefreshCar(
		Car,
		UnlockedSlotCount,
		{}
	)
end]]

	local NewBlock = [[function CarCargoVisualService.ClearCar(
	Car,
	UnlockedSlotCount
)
	return CarCargoVisualService.RefreshCar(
		Car,
		{
			Capacity = UnlockedSlotCount,
			Inventory = {},
		}
	)
end]]

	if string.find(Source, OldBlock, 1, true) then
		Source = ReplaceOnce(
			Source,
			OldBlock,
			NewBlock,
			"CarCargoVisualService.ClearCar"
		)
	end

	return Source
end)

---------------------------------------------------------------------
-- PICKAXE TEMPLATE LIMIT
---------------------------------------------------------------------

Patch(
	{"PickaxeService", "PickaxeService(2)"},
	function(Source)
		Source = string.gsub(
			Source,
			"local MaximumTemplateId%s*=%s*#%(game%.ServerStorage%.Pickaxes:GetChildren%(%)%)%s*%-%s*1",
			"local MaximumTemplateId = #PickaxeTemplates:GetChildren()",
			1
		)

		Source = string.gsub(
			Source,
			"local MaximumTemplateId%s*=%s*#PickaxeTemplates:GetChildren%(%)%s*%-%s*1",
			"local MaximumTemplateId = #PickaxeTemplates:GetChildren()",
			1
		)

		return Source
	end
)

---------------------------------------------------------------------
-- LOCOMOTIVE ORDER + MINING DIESEL NAME
---------------------------------------------------------------------

Patch({"LocomotiveDefinitions"}, function(Source)
	local OrderBlock =
		string.match(
			Source,
			"LocomotiveDefinitions%.Order%s*=%s*%b{}"
		)

	if not OrderBlock
		or not string.find(
			OrderBlock,
			'"IntermediateLocomotive"',
			1,
			true
		) then
		Source = ReplaceOnce(
			Source,
			[[	"StarterLocomotive",
}]],
			[[	"StarterLocomotive",
	"IntermediateLocomotive",
}]],
			"IntermediateLocomotive order entry"
		)
	end

	local DefinitionStart =
		string.find(
			Source,
			"IntermediateLocomotive = {",
			1,
			true
		)

	if DefinitionStart then
		local NameStart, NameEnd =
			string.find(
				Source,
				'DisplayName = "Mini Diesel"',
				DefinitionStart,
				true
			)

		if NameStart then
			Source =
				string.sub(Source, 1, NameStart - 1)
				.. 'DisplayName = "Mining Diesel"'
				.. string.sub(Source, NameEnd + 1)
		end
	end

	return Source
end)

---------------------------------------------------------------------
-- UPGRADE SHOP FIXES
---------------------------------------------------------------------

Patch({"UpgradeShopServer"}, function(Source)
	if not string.find(
		Source,
		'WaitForChild("PickaxeService")',
		1,
		true
	) then
		Source = ReplaceOnce(
			Source,
			[[local TrainService = require(
	ServerScriptService:WaitForChild(
		"TrainService"
	)
)]],
			[[local TrainService = require(
	ServerScriptService:WaitForChild(
		"TrainService"
	)
)

local PickaxeService = require(
	ServerScriptService:WaitForChild(
		"PickaxeService"
	)
)]],
			"PickaxeService require"
		)
	end

	local FirstPrevious =
		string.find(
			Source,
			"local PreviousCarCapacity",
			1,
			true
		)

	if FirstPrevious then
		local SecondStart, SecondEnd =
			string.find(
				Source,
				"local PreviousCarCapacity",
				FirstPrevious + 1,
				true
			)

		if SecondStart then
			local Newline =
				string.find(
					Source,
					"\n",
					SecondEnd + 1,
					true
				) or SecondEnd

			Source =
				string.sub(Source, 1, SecondStart - 1)
				.. string.sub(Source, Newline + 1)
		end
	end

	Source = RemoveIfPresent(
		Source,
		[[	if UpgradeId == "CarCapacity" then

		ApplyCarCapacityUpgrade(Data)
	end

]]
	)

	local PickaxeStart =
		string.find(
			Source,
			'	elseif UpgradeId == "PickaxeDamage" then',
			1,
			true
		)

	if PickaxeStart
		and not string.find(
			Source,
			"PickaxeService.GivePickaxe",
			PickaxeStart,
			true
		) then
		local BranchEnd =
			string.find(
				Source,
				"\n\tend\nreturn true",
				PickaxeStart,
				true
			)

		if not BranchEnd then
			error("Could not locate PickaxeDamage branch end")
		end

		local NewBranch = [[	elseif UpgradeId == "PickaxeDamage" then
		local TemplateId =
			PickaxeService.GetTemplateIdForUpgradeLevel(
				NewLevel
			)

		local GivenSuccessfully,
			PickaxeOrError =
			PickaxeService.GivePickaxe(
				Player,
				TemplateId
			)

		if not GivenSuccessfully then
			return false, PickaxeOrError
		end
]]

		Source =
			string.sub(Source, 1, PickaxeStart - 1)
			.. NewBranch
			.. string.sub(Source, BranchEnd + 1)
	end

	local ShouldReturnStart =
		string.find(
			Source,
			"local ShouldReturnTrain =",
			1,
			true
		)

	if ShouldReturnStart then
		local DuplicateStart =
			string.find(
				Source,
				'\n\tif UpgradeId == "MaximumCars"',
				ShouldReturnStart,
				true
			)

		if DuplicateStart then
			local LeaderstatsStart =
				string.find(
					Source,
					"\n\tlocal Leaderstats =",
					DuplicateStart,
					true
				)

			if not LeaderstatsStart then
				error("Could not locate Leaderstats after duplicate rebuild")
			end

			Source =
				string.sub(Source, 1, DuplicateStart - 1)
				.. "\n"
				.. string.sub(Source, LeaderstatsStart + 1)
		end
	end

	return Source
end)

---------------------------------------------------------------------
-- PLAYER DATA PUBLIC API: MOVE METHODS OUT OF Start()
---------------------------------------------------------------------

Patch(
	{"PlayerDataService", "PlayerDataService."},
	function(Source)
		local StartPosition =
			string.find(
				Source,
				"function PlayerDataService.Start()",
				1,
				true
			)

		if not StartPosition then
			error("Could not locate PlayerDataService.Start")
		end

		local Prefix =
			string.sub(Source, 1, StartPosition - 1)

		local OldAddCash = [[function PlayerDataService.AddCash(Player, Amount)
	local Data = PlayerData[Player]

	if not Data then
		return false
	end

	if typeof(Amount) ~= "number" then
		return false
	end

	Data.Stats.Cash += Amount

	return true
end]]

		local NewAddCash = [[function PlayerDataService.AddCash(Player, Amount)
	local Data = PlayerData[Player]

	if not Data or typeof(Amount) ~= "number" then
		return false
	end

	Data.Stats.Cash += Amount

	local Leaderstats = Player:FindFirstChild("leaderstats")
	local CashValue =
		Leaderstats
		and Leaderstats:FindFirstChild("Cash")

	if CashValue then
		CashValue.Value = Data.Stats.Cash
	end

	return true
end]]

		if string.find(Prefix, OldAddCash, 1, true) then
			Prefix = ReplaceOnce(
				Prefix,
				OldAddCash,
				NewAddCash,
				"leaderstats-aware AddCash"
			)
		end

		local NewTail = [[function PlayerDataService.SetCash(Player, Amount)
	local Data = PlayerData[Player]

	if not Data or typeof(Amount) ~= "number" then
		return false
	end

	Data.Stats.Cash = math.max(Amount, 0)

	local Leaderstats = Player:FindFirstChild("leaderstats")
	local CashValue =
		Leaderstats
		and Leaderstats:FindFirstChild("Cash")

	if CashValue then
		CashValue.Value = Data.Stats.Cash
	end

	return true
end

function PlayerDataService.GetBackpackLoad(Player)
	local Data = PlayerData[Player]

	if not Data then
		return 0
	end

	local Total = 0

	for _, Quantity in Data.Inventory do
		if typeof(Quantity) == "number" then
			Total += Quantity
		end
	end

	return Total
end

function PlayerDataService.GetBackpackCapacity(Player)
	local Data = PlayerData[Player]

	if not Data then
		return 0
	end

	return Data.Stats.BackpackCapacity or 2
end

function PlayerDataService.Start()
	Players.PlayerAdded:Connect(function(Player)
		local LoadedSuccessfully =
			PlayerDataService.LoadPlayer(Player)

		if not LoadedSuccessfully then
			Player:Kick(
				"Your data could not be loaded. Please rejoin to prevent data loss."
			)
		end
	end)

	Players.PlayerRemoving:Connect(function(Player)
		PlayerDataService.SavePlayer(Player)
		PlayerDataService.RemovePlayer(Player)
	end)

	for _, Player in Players:GetPlayers() do
		task.spawn(
			PlayerDataService.LoadPlayer,
			Player
		)
	end

	task.spawn(function()
		while true do
			task.wait(AutoSaveInterval)

			for _, Player in Players:GetPlayers() do
				task.spawn(
					PlayerDataService.SavePlayer,
					Player
				)
			end
		end
	end)

	game:BindToClose(function()
		local SaveThreads = 0
		local ShutdownStart = os.clock()
		local MaximumShutdownWait = 25

		for _, Player in Players:GetPlayers() do
			SaveThreads += 1

			task.spawn(function()
				PlayerDataService.SavePlayer(Player)
				SaveThreads -= 1
			end)
		end

		while SaveThreads > 0
			and os.clock() - ShutdownStart
				< MaximumShutdownWait do

			task.wait()
		end
	end)
end

return PlayerDataService
]]

		return Prefix .. NewTail
	end
)

---------------------------------------------------------------------
-- TRAIN REBUILD: RESTORE OLD TRAIN AFTER UNEXPECTED FAILURE
---------------------------------------------------------------------

Patch({"TrainService"}, function(Source)
	local FunctionStart =
		string.find(
			Source,
			"function TrainService.RebuildPlayerTrain(",
			1,
			true
		)

	local ReturnStart =
		string.find(
			Source,
			"\nreturn TrainService",
			FunctionStart or 1,
			true
		)

	if not FunctionStart or not ReturnStart then
		error("Could not locate RebuildPlayerTrain")
	end

	local NewFunction = [[function TrainService.RebuildPlayerTrain(
	Player
)
	if RebuildLocks[Player] then
		return false,
			"Your train is already being rebuilt."
	end

	RebuildLocks[Player] = true

	local OldTrain
	local OldTrainDetached = false

	local CallSuccess,
		RebuildSuccess,
		Result =
		xpcall(
			function()
				local Data =
					PlayerDataService.GetData(
						Player
					)

				if not Data then
					return false,
						"Player data is not loaded."
				end

				OldTrain =
					TrainService.GetPlayerTrain(
						Player
					)

				if not OldTrain then
					return false,
						"Your train is not currently spawned."
				end

				TrainService.StopTrainPhysics(
					OldTrain
				)

				OldTrain.Parent = nil
				OldTrainDetached = true

				local Spawned,
					NewTrainOrError =
					TrainService.SpawnPlayerTrain(
						Player,
						Data
					)

				if not Spawned then
					OldTrain.Parent = SpawnedTrains
					OldTrainDetached = false

					TrainService.StopTrainPhysics(
						OldTrain
					)

					return false,
						NewTrainOrError
				end

				OldTrain:Destroy()
				OldTrainDetached = false

				return true,
					"Your train was rebuilt at its station."
			end,
			debug.traceback
		)

	RebuildLocks[Player] = nil

	if not CallSuccess then
		if OldTrainDetached
			and OldTrain
			and OldTrain.Parent == nil then

			OldTrain.Parent = SpawnedTrains
			TrainService.StopTrainPhysics(
				OldTrain
			)
		end

		warn(
			"Train rebuild failed for",
			Player.Name,
			RebuildSuccess
		)

		return false,
			"An unexpected error occurred while rebuilding your train."
	end

	return RebuildSuccess,
		Result
end
]]

	return string.sub(Source, 1, FunctionStart - 1)
		.. NewFunction
		.. string.sub(Source, ReturnStart)
end)

---------------------------------------------------------------------
-- FIX REPEATED CAMERA ViewportSize CONNECTIONS
---------------------------------------------------------------------

local function PatchCamera(Source)
	if string.find(
		Source,
		"local ViewportConnection",
		1,
		true
	) then
		return Source
	end

	local ConnectStart =
		string.find(
			Source,
			"local function ConnectCamera()",
			1,
			true
		)

	local WorkspaceSignalStart =
		string.find(
			Source,
			'Workspace:GetPropertyChangedSignal(',
			ConnectStart or 1,
			true
		)

	if not ConnectStart or not WorkspaceSignalStart then
		return Source
	end

	local NewBlock = [[local ViewportConnection

local function ConnectCamera()
	if ViewportConnection then
		ViewportConnection:Disconnect()
		ViewportConnection = nil
	end

	local Camera = Workspace.CurrentCamera

	if Camera then
		ViewportConnection =
			Camera:GetPropertyChangedSignal(
				"ViewportSize"
			):Connect(UpdateResponsiveSizing)
	end

	UpdateResponsiveSizing()
end

]]

	return string.sub(Source, 1, ConnectStart - 1)
		.. NewBlock
		.. string.sub(Source, WorkspaceSignalStart)
end

Patch({"TrainActionClient"}, function(Source)
	return PatchCamera(Source)
end)

Patch({"UpgradeShopClient"}, function(Source)
	return PatchCamera(Source)
end)

---------------------------------------------------------------------
-- DISABLE DUPLICATE LOCOMOTIVE PURCHASE PATH
---------------------------------------------------------------------

local LegacyLocomotiveServer =
	FindSource({"LocomotiveUpgradeServer"})

if LegacyLocomotiveServer
	and LegacyLocomotiveServer:IsA("Script") then
	Backup(LegacyLocomotiveServer)
	LegacyLocomotiveServer.Disabled = true
	LegacyLocomotiveServer:SetAttribute(
		"DisabledReason",
		"UpgradeShopServer is the authoritative locomotive purchase path."
	)
	print(
		"[Mining Train Repair] Disabled LocomotiveUpgradeServer"
	)
end

---------------------------------------------------------------------
-- SAFE SCRIPT RENAMES
---------------------------------------------------------------------

local RenameMap = {
	["PickaxeServer"] = "TrainCargoVisualWatcher",
	["PickaxeService(2)"] = "PickaxeService",
	["lightservice"] = "LightService",
	["LightServiceServer(1)"] = "LightServiceServer",
	["PlayerDataService."] = "PlayerDataService",
	["StationService."] = "StationService",
	["GenerateOre"] = "MineGenerationServer",
	["GenerateOre.Lua"] = "MineGenerationServer",
	["MultiplayerStationServer"] = "PlayerStationServer",
	["StartPlayerData"] = "PlayerDataServer",
}

for OldName, NewName in RenameMap do
	local Object = FindSource({OldName})

	if Object and Object.Name ~= NewName then
		local Existing =
			Object.Parent:FindFirstChild(NewName)

		if Existing and Existing ~= Object then
			WarningCount += 1
			warn(
				"[Mining Train Repair] Could not rename "
					.. GetPath(Object)
					.. "; "
					.. NewName
					.. " already exists."
			)
		else
			Backup(Object)
			Object.Name = NewName
			print(
				"[Mining Train Repair] Renamed "
					.. OldName
					.. " -> "
					.. NewName
			)
		end
	end
end

ChangeHistoryService:SetWaypoint("After Mining Train Repair")

local ChangedCount = 0
for _ in Changed do
	ChangedCount += 1
end

print("============================================================")
print("[Mining Train Repair] Complete")
print("[Mining Train Repair] Changed scripts:", ChangedCount)
print("[Mining Train Repair] Warnings:", WarningCount)
print("[Mining Train Repair] Backups:", GetPath(BackupFolder))
print("Test mining, every upgrade, respawning, train return, and saving.")
print("============================================================")
