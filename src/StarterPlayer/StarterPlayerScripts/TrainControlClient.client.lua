local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local TrainControlEvent = ReplicatedStorage:WaitForChild("TrainControlEvent")

local Humanoid = nil
local CurrentLocomotive = nil
local ActiveTouch = nil
local TouchStartPosition = nil
local ThumbstickDirection = 0

local ThumbstickDeadzone = 0.65
local ThumbstickReleaseDeadzone = 0.25
local TouchDragThreshold = 50

local function FindLocomotiveFromSeat(Seat)
	local CurrentObject = Seat

	while CurrentObject and CurrentObject ~= workspace do
		if CurrentObject:IsA("Model") and CurrentObject:GetAttribute("OwnerUserId") ~= nil then
			return CurrentObject
		end

		CurrentObject = CurrentObject.Parent
	end

	return nil
end

local function UpdateCurrentLocomotive()
	if not Humanoid or not Humanoid.SeatPart then
		CurrentLocomotive = nil
		return
	end

	CurrentLocomotive = FindLocomotiveFromSeat(Humanoid.SeatPart)
end

local function SendControl(Action)
	UpdateCurrentLocomotive()

	if not CurrentLocomotive then
		return
	end

	TrainControlEvent:FireServer(CurrentLocomotive, Action)
end

local function HandleKeyboard(Input, GameProcessed)
	if GameProcessed or UserInputService:GetFocusedTextBox() then
		return
	end

	if Input.KeyCode == Enum.KeyCode.W or Input.KeyCode == Enum.KeyCode.Up then
		SendControl("Forward")
	elseif Input.KeyCode == Enum.KeyCode.S or Input.KeyCode == Enum.KeyCode.Down then
		SendControl("Reverse")
	elseif Input.KeyCode == Enum.KeyCode.Space then
		SendControl("Stop")
	end
end

local function HandleThumbstick(Input)
	if Input.KeyCode ~= Enum.KeyCode.Thumbstick1 then
		return
	end

	local VerticalPosition = Input.Position.Y

	if VerticalPosition >= ThumbstickDeadzone then
		if ThumbstickDirection ~= 1 then
			ThumbstickDirection = 1
			SendControl("Forward")
		end
	elseif VerticalPosition <= -ThumbstickDeadzone then
		if ThumbstickDirection ~= -1 then
			ThumbstickDirection = -1
			SendControl("Reverse")
		end
	elseif math.abs(VerticalPosition) <= ThumbstickReleaseDeadzone then
		ThumbstickDirection = 0
	end
end

local function HandleTouchStarted(Input, GameProcessed)
	if GameProcessed or Input.UserInputType ~= Enum.UserInputType.Touch or ActiveTouch then
		return
	end

	ActiveTouch = Input
	TouchStartPosition = Input.Position
end

local function HandleTouchMoved(Input)
	if Input ~= ActiveTouch or not TouchStartPosition then
		return
	end

	local VerticalDrag = Input.Position.Y - TouchStartPosition.Y

	if VerticalDrag <= -TouchDragThreshold then
		SendControl("Forward")
		TouchStartPosition = Input.Position
	elseif VerticalDrag >= TouchDragThreshold then
		SendControl("Reverse")
		TouchStartPosition = Input.Position
	end
end

local function HandleTouchEnded(Input)
	if Input ~= ActiveTouch then
		return
	end

	ActiveTouch = nil
	TouchStartPosition = nil
end

local function SetUpCharacter(Character)
	Humanoid = Character:WaitForChild("Humanoid")
	CurrentLocomotive = nil

	Humanoid:GetPropertyChangedSignal("SeatPart"):Connect(UpdateCurrentLocomotive)

	UpdateCurrentLocomotive()
end

UserInputService.InputBegan:Connect(function(Input, GameProcessed)
	HandleKeyboard(Input, GameProcessed)
	HandleTouchStarted(Input, GameProcessed)
end)

UserInputService.InputChanged:Connect(function(Input)
	if Input.UserInputType == Enum.UserInputType.Gamepad1 then
		HandleThumbstick(Input)
	elseif Input.UserInputType == Enum.UserInputType.Touch then
		HandleTouchMoved(Input)
	end
end)

UserInputService.InputEnded:Connect(HandleTouchEnded)

Player.CharacterAdded:Connect(SetUpCharacter)

if Player.Character then
	SetUpCharacter(Player.Character)
end