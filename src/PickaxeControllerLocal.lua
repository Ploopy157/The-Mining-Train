local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local RunService =
	game:GetService("RunService")

local Player =
	Players.LocalPlayer


local InfoUI = Player.PlayerGui:WaitForChild("HighLightInfo").TextLabel
local Mouse =
	Player:GetMouse()

local MiningEvent =
	ReplicatedStorage:WaitForChild(
		"Mining Event"
	)

local MaximumClickDistance = 10

local EquippedTool = nil
local HitSound = nil
local SwingAnimation = nil
local AnimationTrack = nil

local Swinging = false
local StopSwinging = false
local HitDebounce = false

local ToolConnections = {}

---------------------------------------------------------------------
-- DEFINE HIGHLIGHT
---------------------------------------------------------------------
local TargetHighlight =
	Instance.new("Highlight")

TargetHighlight.Name =
	"MiningTargetHighlight"

TargetHighlight.FillTransparency = 1
TargetHighlight.OutlineTransparency = 0
TargetHighlight.DepthMode =
	Enum.HighlightDepthMode.Occluded

TargetHighlight.Enabled = false
TargetHighlight.Parent =
	Player:WaitForChild("PlayerGui")



local function IsValidMiningTarget(Target)
	if not EquippedTool then
		return false
	end

	if not Target
		or not Target:IsA("BasePart") then

		return false
	end

	if not Target:GetAttribute("Ore") then
		return false
	end

	local Character =
		Player.Character

	if not Character then
		return false
	end

	local HumanoidRootPart =
		Character:FindFirstChild(
			"HumanoidRootPart"
		)

	if not HumanoidRootPart then
		return false
	end

	local Distance =
		(
			HumanoidRootPart.Position
			- Target.Position
		).Magnitude

	return Distance <= MaximumClickDistance
end



local function UpdateTargetHighlight()
	local Target =
		Mouse.Target

	if IsValidMiningTarget(Target) then
		TargetHighlight.Adornee =
			Target

		TargetHighlight.Enabled =
			true
		
		local InfoString = ((Target.Name).." | ".. Target:GetAttribute("Health").." | Value: $"..(Target:GetAttribute("Value")))
		InfoUI.Text = InfoString
		InfoUI.Parent.Enabled = true
	else
		TargetHighlight.Enabled =
			false

		TargetHighlight.Adornee =
			nil
		
		InfoUI.Parent.Enabled = false
	end
end
RunService.RenderStepped:Connect(
	UpdateTargetHighlight
)

local function ClearTargetHighlight()
	TargetHighlight.Enabled = false
	TargetHighlight.Adornee = nil
end

---------------------------------------------------------------------
-- CONNECTION MANAGEMENT
---------------------------------------------------------------------

local function DisconnectToolConnections()
	for _, Connection in ToolConnections do
		Connection:Disconnect()
	end

	table.clear(ToolConnections)
end

local function StopCurrentSwing()
	StopSwinging = true
	Swinging = false
	HitDebounce = false

	if AnimationTrack then
		AnimationTrack:Stop()
	end
end

local function ClearEquippedTool()
	StopCurrentSwing()
	DisconnectToolConnections()
	ClearTargetHighlight()

	EquippedTool = nil
	HitSound = nil
	SwingAnimation = nil
	AnimationTrack = nil
end

---------------------------------------------------------------------
-- TOOL VALIDATION
---------------------------------------------------------------------

local function IsPickaxe(Tool)
	if not Tool:IsA("Tool") then
		return false
	end

	-- Recommended attribute for identifying pickaxes.
	if Tool:GetAttribute("IsPickaxe") == true then
		return true
	end

	-- Compatibility with existing pickaxes.
	return Tool:GetAttribute("Damage") ~= nil
		and Tool:GetAttribute("Cooldown") ~= nil
end

local function GetCooldown()
	if not EquippedTool then
		return 1
	end

	local Cooldown =
		EquippedTool:GetAttribute(
			"Cooldown"
		)

	if typeof(Cooldown) ~= "number"
		or Cooldown <= 0 then

		return 1
	end

	return Cooldown
end



---------------------------------------------------------------------
-- ANIMATION
---------------------------------------------------------------------

local function LoadAnimation()
	if not EquippedTool
		or not SwingAnimation then

		return
	end

	local Character =
		Player.Character

	if not Character then
		return
	end

	local Humanoid =
		Character:FindFirstChildOfClass(
			"Humanoid"
		)

	if not Humanoid then
		return
	end

	local Animator =
		Humanoid:FindFirstChildOfClass(
			"Animator"
		)

	if not Animator then
		Animator =
			Instance.new("Animator")

		Animator.Parent =
			Humanoid
	end

	if AnimationTrack then
		AnimationTrack:Stop()
		AnimationTrack = nil
	end

	AnimationTrack =
		Animator:LoadAnimation(
			SwingAnimation
		)

	AnimationTrack.Priority =
		Enum.AnimationPriority.Action
end

---------------------------------------------------------------------
-- MINING
---------------------------------------------------------------------

local function TryMineTarget(Target)
	
	
	if not EquippedTool
		or not Target
		or HitDebounce then

		return
	end

	if not Target:IsA("BasePart") then
		return
	end

	if not Target:GetAttribute("Ore") then
		return
	end

	local Character =
		Player.Character

	if not Character then
		return
	end

	local HumanoidRootPart =
		Character:FindFirstChild(
			"HumanoidRootPart"
		)

	if not HumanoidRootPart then
		return
	end

	local Distance =
		(
			HumanoidRootPart.Position
			- Target.Position
		).Magnitude

	if Distance >
		MaximumClickDistance then

		return
	end

	HitDebounce = true

	
	MiningEvent:FireServer(
		Target
	)

	local ToolAtHit =
		EquippedTool

	task.delay(
		GetCooldown(),
		function()
			-- Do not alter the debounce for a newly equipped tool.
			if EquippedTool == ToolAtHit then
				HitDebounce = false
			end
		end
	)
end

local function StartSwinging()
	if Swinging
		or not EquippedTool then

		return
	end

	Swinging = true
	StopSwinging = false

	local ActiveTool =
		EquippedTool

	while Swinging
		and not StopSwinging
		and EquippedTool == ActiveTool
		and ActiveTool.Parent
		== Player.Character do

		local ClickedTarget =
			Mouse.Target

		local Cooldown =
			GetCooldown()

		local HitDelay =
			Cooldown * 0.75

		local RecoveryDelay =
			math.max(
				Cooldown - HitDelay,
				0
			)

		if AnimationTrack then
			local AnimationLength =
				AnimationTrack.Length

			if AnimationLength > 0 then
				local PlaybackSpeed =
					AnimationLength
					/ Cooldown

				AnimationTrack:Play()
				AnimationTrack:AdjustSpeed(
					PlaybackSpeed
				)
			else
				AnimationTrack:Play()
			end
		end

		task.wait(HitDelay)
		-- Complete the current swing even if the player
		-- released the mouse during the animation.
		if EquippedTool ~= ActiveTool
			or ActiveTool.Parent ~= Player.Character then

			break
		end

		if HitSound then
			HitSound:Play()
		end

		TryMineTarget(
			ClickedTarget
		)

		task.wait(
			RecoveryDelay
		)
	end

	if AnimationTrack then
		AnimationTrack:Stop()
	end

	Swinging = false
	HitDebounce = false
end

---------------------------------------------------------------------
-- TOOL SETUP
---------------------------------------------------------------------

local function EquipTool(Tool)
	-- Rest of EquipTool...
	
	 
	if Tool == EquippedTool then
		return
	end

	ClearEquippedTool()

	if not IsPickaxe(Tool) then
		return
	end

	EquippedTool = Tool

	HitSound =
		Tool:FindFirstChild(
			"HitSound"
		)

	SwingAnimation =
		Tool:FindFirstChild(
			"SwingAnim"
		)

	if not HitSound
		or not HitSound:IsA("Sound") then

		warn(
			Tool:GetFullName(),
			"does not contain a HitSound."
		)

		HitSound = nil
	end

	if not SwingAnimation
		or not SwingAnimation:IsA(
			"Animation"
		) then

		warn(
			Tool:GetFullName(),
			"does not contain a SwingAnim."
		)

		SwingAnimation = nil
	end

	LoadAnimation()

	table.insert(
		ToolConnections,
		Tool.Activated:Connect(
			StartSwinging
		)
	)

	table.insert(
		ToolConnections,
		Tool.Deactivated:Connect(
			function()
				StopSwinging = true
			end
		)
	)

	table.insert(
		ToolConnections,
		Tool.AncestryChanged:Connect(
			function()
				if EquippedTool ~= Tool then
					return
				end

				if Tool.Parent
					~= Player.Character then

					ClearEquippedTool()
				end
			end
		)
	)
end

---------------------------------------------------------------------
-- CHARACTER SETUP
---------------------------------------------------------------------

local CharacterConnections = {}

local function DisconnectCharacterConnections()
	for _, Connection in CharacterConnections do
		Connection:Disconnect()
	end

	table.clear(CharacterConnections)
end

local function SetUpCharacter(Character)
	ClearEquippedTool()
	DisconnectCharacterConnections()

	table.insert(
		CharacterConnections,
		Character.ChildAdded:Connect(
			function(Child)
				if IsPickaxe(Child) then
					EquipTool(Child)
				end
			end
		)
	)

	table.insert(
		CharacterConnections,
		Character.ChildRemoved:Connect(
			function(Child)
				if Child == EquippedTool then
					ClearEquippedTool()
				end
			end
		)
	)

	for _, Child in Character:GetChildren() do
		if IsPickaxe(Child) then
			EquipTool(Child)
			break
		end
	end
end

Player.CharacterAdded:Connect(
	SetUpCharacter
)

Player.CharacterRemoving:Connect(
	function()
		ClearEquippedTool()
		DisconnectCharacterConnections()
	end
)

if Player.Character then
	SetUpCharacter(
		Player.Character
	)
end