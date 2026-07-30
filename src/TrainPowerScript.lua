local FWDButton = script.Parent.FWD.ClickDetector
local REVButton = script.Parent.REV.ClickDetector
local STOPButton = script.Parent.STOP.ClickDetector
local Speedometer = script.Parent.Speedometer.SurfaceGui.TextLabel
local Base = script.Parent.Parent.Main
local Motors = {}

local SpeedIncrement = 12

local TopSpeed = script.Parent.Parent:GetAttribute("TopSpeed")
local CurrentSpeed = 0
local Player = game.Players:GetPlayerByUserId(script.Parent.Parent.Parent:GetAttribute("OwnerUserId"))
	
local Seat = script.Parent.Parent.Seat


for i, v in pairs(Base:GetChildren()) do
	if v.Name == "MotorHinge" then
		table.insert(Motors, v)
	end
end

local function CheckOwner()
	local Occupant = Seat.Occupant
	local OccupyingPlayer = Occupant and game.Players:GetPlayerFromCharacter(Occupant.Parent)
	if Seat.Occupant and OccupyingPlayer == Player then
		return true
	else 
		print("NOT THE OWNER")
		return false
	end
end

FWDButton.MouseClick:Connect(function()
	if CheckOwner() and CurrentSpeed<TopSpeed then
			CurrentSpeed +=1
			Speedometer.Text = CurrentSpeed
		for i, hinge in Motors do
			hinge.AngularVelocity = CurrentSpeed * SpeedIncrement
			hinge.MotorMaxTorque = 1000000
		end
	end
end)

REVButton.MouseClick:Connect(function()
	if CheckOwner() and CurrentSpeed>(TopSpeed*-1) then
		CurrentSpeed -=1
		Speedometer.Text = CurrentSpeed
		for i, hinge in Motors do
			hinge.AngularVelocity = CurrentSpeed * SpeedIncrement
			hinge.MotorMaxTorque = 1000000
		end
	end
end)

STOPButton.MouseClick:Connect(function()
	if CheckOwner() then
		CurrentSpeed = 0
		Speedometer.Text = CurrentSpeed
		for i, hinge in Motors do
			hinge.AngularVelocity = 0
			hinge.MotorMaxTorque = 0
		end
		
	end
end)

Seat:GetPropertyChangedSignal("Occupant"):Connect(function()
	print("Occupant changed")
	local Occupant = Seat.Occupant

	if not Occupant then
		if CurrentSpeed ~= 0 then
			CurrentSpeed = 0
			Speedometer.Text = tostring(CurrentSpeed)

			for _, Hinge in Motors do
				Hinge.AngularVelocity = 0
				Hinge.MotorMaxTorque = 0
			end
		end
	elseif not CheckOwner() then
		Seat.Disabled = true
		wait(1)
		Seat.Disabled = false
	end
end)