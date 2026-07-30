local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local InfoEvent = ReplicatedStorage:WaitForChild("OreInfoEvent")

local Remotes =
	ReplicatedStorage:WaitForChild(
		"ShopTeleportRemotes"
	)

local TeleportToShop =
	Remotes:WaitForChild("TeleportToShop")

---------------------------------------------------------------------
-- CONFIGURATION
---------------------------------------------------------------------

-- Teleport is allowed only when the player's X is below this.
local MaximumAllowedX = 53

-- Additional vertical clearance above ShopTeleport.
local TeleportHeight = 5

-- Prevent rapid repeated requests.
local TeleportCooldown = 2

local LastTeleportTimes = {}

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------

local function GetCharacterParts(Player)
	local Character = Player.Character
	
	
	if not Character then
		return nil, nil, nil
	end

	local Root =
		Character:FindFirstChild(
			"HumanoidRootPart"
		)

	local Humanoid =
		Character:FindFirstChildOfClass(
			"Humanoid"
		)

	return Character, Root, Humanoid
end

local function GetShopTeleportPart()
	local ShopTeleport =
		Workspace:FindFirstChild(
			"ShopTeleport"
		)

	if ShopTeleport
		and ShopTeleport:IsA("BasePart") then

		return ShopTeleport
	end

	-- Optional fallback locations.
	for _, ShopName in {
		"OreShop",
		"UpgradeShop",
	} do
		local Shop =
			Workspace:FindFirstChild(ShopName)

		if Shop then
			local Target =
				Shop:FindFirstChild(
					"ShopTeleport",
					true
				)
				or Shop:FindFirstChild(
					"TeleportPoint",
					true
				)

			if Target
				and Target:IsA("BasePart") then

				return Target
			end
		end
	end

	return nil
end

local function GetUprightTargetCFrame(
	TargetPart
)
	local TargetPosition =
		TargetPart.Position
		+ Vector3.new(
			0,
			TeleportHeight,
			0
		)

	local LookVector =
		TargetPart.CFrame.LookVector

	local FlatLookVector = Vector3.new(
		LookVector.X,
		0,
		LookVector.Z
	)

	if FlatLookVector.Magnitude < 0.001 then
		FlatLookVector =
			Vector3.new(0, 0, -1)
	else
		FlatLookVector =
			FlatLookVector.Unit
	end

	return CFrame.lookAt(
		TargetPosition,
		TargetPosition + FlatLookVector
	)
end

local function IsOnCooldown(Player)
	local CurrentTime = os.clock()

	local LastTeleportTime =
		LastTeleportTimes[Player] or 0

	local TimeSinceLastTeleport =
		CurrentTime - LastTeleportTime

	if TimeSinceLastTeleport
		< TeleportCooldown then

		local RemainingTime =
			TeleportCooldown
			- TimeSinceLastTeleport

		return true, RemainingTime
	end

	return false, 0
end

---------------------------------------------------------------------
-- TELEPORT
---------------------------------------------------------------------

TeleportToShop.OnServerInvoke = function(Player)
	local OnCooldown, RemainingTime =
		IsOnCooldown(Player)

	if OnCooldown then
		return false, string.format(
			"Shop teleport is available in %.1f seconds.",
			RemainingTime
		)
	end

	local Character, Root, Humanoid =
		GetCharacterParts(Player)

	if not Character or not Root then
		return false,
			"Your character is not ready."
	end
	
	if Character.Humanoid.Sit then
		InfoEvent:FireClient(Player, "Please Stand Up First.")
		return false
	end


	-- Mine begins at X = 53 and extends toward positive X.
	if Root.Position.X >= MaximumAllowedX then
		InfoEvent:FireClient(Player, "You cannot teleport to the shops while inside the mine.")
		return false,
			"You cannot teleport to the shops while inside the mine."
	end

	local ShopTeleport =
		GetShopTeleportPart()

	if not ShopTeleport then
		return false,
			"Workspace.ShopTeleport was not found."
	end

	if Humanoid then
		Humanoid.Sit = false
	end

	Root.AssemblyLinearVelocity =
		Vector3.zero

	Root.AssemblyAngularVelocity =
		Vector3.zero

	Character:PivotTo(
		GetUprightTargetCFrame(
			ShopTeleport
		)
	)

	LastTeleportTimes[Player] =
		os.clock()

	return true,
		"Teleported to the shops."
end

game:GetService("Players").PlayerRemoving:Connect(
	function(Player)
		LastTeleportTimes[Player] = nil
	end
)
