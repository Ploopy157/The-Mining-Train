local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Character = script.Parent
local Humanoid = Character:WaitForChild("Humanoid")

local WalkSpeed = script:GetAttribute("WalkSpeed") or 16
local RunSpeed = script:GetAttribute("RunSpeed") or 50
local SprintThreshold = script:GetAttribute("SprintThreshold") or 0.9

local ShiftHeld = false
local CurrentSpeed = WalkSpeed

local function SetSpeed(NewSpeed)
	if CurrentSpeed == NewSpeed then
		return
	end

	CurrentSpeed = NewSpeed
	Humanoid.WalkSpeed = NewSpeed
end

UserInputService.InputBegan:Connect(function(Input, GameProcessed)
	if GameProcessed then
		return
	end

	if Input.KeyCode == Enum.KeyCode.LeftShift then
		ShiftHeld = true
	end
end)

UserInputService.InputEnded:Connect(function(Input)
	if Input.KeyCode == Enum.KeyCode.LeftShift then
		ShiftHeld = false
	end
end)

RunService.RenderStepped:Connect(function()
	if Humanoid.Health <= 0 then
		return
	end

	local MovementAmount = Humanoid.MoveDirection.Magnitude
	local IsMoving = MovementAmount > 0.05
	local ShouldSprint

	if UserInputService.KeyboardEnabled then
		-- Computers, or another device with a keyboard attached,
		-- must hold Shift to sprint.
		ShouldSprint = ShiftHeld and IsMoving
	else
		-- Console and mobile sprint when the movement stick
		-- is pushed close to its maximum distance.
		ShouldSprint = MovementAmount >= SprintThreshold
	end

	SetSpeed(ShouldSprint and RunSpeed or WalkSpeed)
end)