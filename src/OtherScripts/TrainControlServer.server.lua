local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrainControlEvent = ReplicatedStorage:WaitForChild("TrainControlEvent")

local Controls = script.Parent
local Locomotive = Controls.Parent
local TrainModel = Locomotive.Parent
local Base = Locomotive:WaitForChild("Main")
local Seat = Locomotive:WaitForChild("Seat")

local FWDButton = Controls.FWD.ClickDetector
local REVButton = Controls.REV.ClickDetector
local STOPButton = Controls.STOP.ClickDetector
local Speedometer = Controls.Speedometer.SurfaceGui.TextLabel

local Motors = {}
local SpeedIncrement = 12
local CurrentSpeed = 0
local TopSpeed = Locomotive:GetAttribute("TopSpeed") or Locomotive:GetAttribute("MaximumSpeed") or 7
local OwnerUserId = Locomotive:GetAttribute("OwnerUserId") or TrainModel:GetAttribute("OwnerUserId")
local Train = Base.Parent:GetDescendants()

local IdleSound = script.Parent.AHandle.IdleSound
local Runsound = script.Parent.AHandle.RunSound

for _, Object in Base:GetDescendants() do
	if Object:IsA("HingeConstraint") and Object.Name == "MotorHinge" then
		table.insert(Motors, Object)
	end
end

local function GetOwner()
	return Players:GetPlayerByUserId(OwnerUserId)
end

local function GetOccupyingPlayer()
	local Occupant = Seat.Occupant

	if not Occupant then
		return nil
	end

	return Players:GetPlayerFromCharacter(Occupant.Parent)
end

local function CheckOwner(RequestingPlayer)
	local Owner = GetOwner()
	local OccupyingPlayer = GetOccupyingPlayer()

	return Owner ~= nil
		and RequestingPlayer == Owner
		and OccupyingPlayer == Owner
end

local function ApplySpeed()
	Speedometer.Text = tostring(CurrentSpeed)
	if CurrentSpeed == 0 then
		for _, Hinge in Motors do
			Hinge.AngularVelocity = 0
			Hinge.MotorMaxTorque = 10000
			Runsound.Playing = false
			IdleSound.Playing = true
		end
		return
	end
	for _, Hinge in Motors do
		
		Hinge.AngularVelocity = CurrentSpeed * SpeedIncrement
		Hinge.MotorMaxTorque = CurrentSpeed == 0 and 0 or 1000000
		IdleSound.Playing = false
		Runsound.Playing = true
		Runsound.PlaybackSpeed = (math.abs(CurrentSpeed) / TopSpeed) *2
		
	end
end

local function SpeedUp(RequestingPlayer)
	if not CheckOwner(RequestingPlayer) then
		return
	end

	if CurrentSpeed >= TopSpeed then
		return
	end

	CurrentSpeed += 1
	ApplySpeed()
end

local function SpeedDown(RequestingPlayer)
	if not CheckOwner(RequestingPlayer) then
		return
	end

	if CurrentSpeed <= -TopSpeed then
		return
	end

	CurrentSpeed -= 1
	ApplySpeed()
end

local function StopTrain(RequestingPlayer)
	if RequestingPlayer and not CheckOwner(RequestingPlayer) then
		return
	end

	CurrentSpeed = 0
	ApplySpeed()
end

local function HandleRemoteControl(RequestingPlayer, RequestedLocomotive, Action)
	if RequestedLocomotive ~= Locomotive then
		return
	end

	if Action == "Forward" then
		SpeedUp(RequestingPlayer)
	elseif Action == "Reverse" then
		SpeedDown(RequestingPlayer)
	elseif Action == "Stop" then
		StopTrain(RequestingPlayer)
	end
end

FWDButton.MouseClick:Connect(SpeedUp)
REVButton.MouseClick:Connect(SpeedDown)
STOPButton.MouseClick:Connect(StopTrain)

TrainControlEvent.OnServerEvent:Connect(HandleRemoteControl)

Seat:GetPropertyChangedSignal("Occupant"):Connect(function()
	local Occupant = Seat.Occupant

	if not Occupant then
		StopTrain()
		return
	end

	local OccupyingPlayer = Players:GetPlayerFromCharacter(Occupant.Parent)

	if OccupyingPlayer ~= GetOwner() then
		Occupant.Sit = false
	end
end)

ApplySpeed()