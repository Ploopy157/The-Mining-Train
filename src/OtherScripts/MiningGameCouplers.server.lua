-- MADE BY NWSPACEK

local coupler = script.Parent
local CouplerOwner
local DCCPermissions = game:GetService("ServerScriptService"):FindFirstChild("DCCPermissions")
local function GetPermission()
	-- if DCCPermissions isn't found, everything is allowed
	return true
end
if DCCPermissions then
	-- if DCCPermissions is found, get permission
	DCCPermissions = require(DCCPermissions)
	GetPermission = DCCPermissions.GetPermission
end

local Allow = coupler:FindFirstChild("Allow")
local CoupledTo = coupler:FindFirstChild("CoupledTo")
local DelayedTo = coupler:FindFirstChild("DelayedTo")
local remote = coupler:FindFirstChild("ROBLOXInteractionEvent")
local Attachment = coupler:FindFirstChild("Attachment")

if not Allow then
	Allow = Instance.new("BoolValue")
	Allow.Name = "Allow"
	Allow.Value = true
	Allow.Parent = coupler
end
if not CoupledTo then
	CoupledTo = Instance.new("ObjectValue")
	CoupledTo.Name = "CoupledTo"
	CoupledTo.Parent = coupler
end
if not DelayedTo then
	DelayedTo = Instance.new("ObjectValue")
	DelayedTo.Name = "DelayedTo"
	DelayedTo.Parent = coupler
end
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "ROBLOXInteractionEvent"
	remote.Parent = coupler
end
if not Attachment then
	Attachment = Instance.new("Attachment")
	Attachment.Axis = Vector3.new(0,0,-1)
	Attachment.Parent = coupler
end

local Rod -- the rod itself
local RodConnection -- connection to decouple if the rod disappears
local CouplerDestroyConnection -- connection to decouple if the other coupler disappears

local TouchedConnection

local function Recolor()--this makes the indicator change colors
	if CoupledTo.Value then
		coupler.Indicator.Color = BrickColor.new("Bright green") -- green means coupled
	elseif DelayedTo.Value then
		coupler.Indicator.Color = BrickColor.new("Bright blue") -- orange means delayed (will automatically set Allow once delayed coupler is out of range)
	elseif Allow.Value then
		coupler.Indicator.Color = BrickColor.new("Bright yellow") -- yellow means ready to couple
	else
		coupler.Indicator.Color = BrickColor.new("Bright red") -- red means will not couple
	end
end
Recolor()

do --[[ Create a coupling ]]--
	
	local function GetCouplerOwner(otherCoupler)
		-- sets the network owner of the coupler to the server
		-- and determines who should get control of the coupler after coupling
		if not coupler:CanSetNetworkOwnership() or not otherCoupler:CanSetNetworkOwnership() then
			return
		end

		local owner = coupler:GetNetworkOwner() -- network owner of our coupler
		local otherOwner = otherCoupler:GetNetworkOwner() -- network owner of the other coupler

		local ownerAuto = coupler:GetNetworkOwnershipAuto() -- auto ownership of our coupler
		local otherOwnerAuto = otherCoupler:GetNetworkOwnershipAuto() -- auto ownership of other coupler

		-- set both coupler ownerships to server to perform the coupling
		if coupler:CanSetNetworkOwnership() then
			coupler:SetNetworkOwner(nil)
		end
		if otherCoupler:CanSetNetworkOwnership() then
			coupler:SetNetworkOwner(nil)
		end

		local NewCouplerOwner
		-- nil means set the network owner to the server
		-- false is taken to mean set network ownership auto

		if NewCouplerOwner and otherOwnerAuto then
			-- if both couplers were set to automatic ownership, set automatic ownership
			NewCouplerOwner = false
		elseif ownerAuto then
			-- if this coupler has automatic ownership and the other doesn't, set it to the owner of the other coupler
			NewCouplerOwner = otherOwner
		elseif otherOwnerAuto then
			-- if the other coupler has automatic ownership and this coupler doesn't, set it to the owner of this coupler
			NewCouplerOwner = owner
		else
			-- if neither coupler had automatic ownership, set ownership to the owner of this coupler
			NewCouplerOwner = owner
		end

		return NewCouplerOwner
	end
	
	local function RestoreCouplerOwner(NewCouplerOwner)
		-- sets the ownership or auto ownership of the coupler after coupling
		if coupler:CanSetNetworkOwnership() then
			if NewCouplerOwner == false then
				-- auto ownership
				coupler:SetNetworkOwnershipAuto()
			else
				-- any other kind of ownership (including server)
				coupler:SetNetworkOwner(NewCouplerOwner)
			end
		end
	end
	
	function RemoveTouchedConnection()
		-- disconnect the TouchedConnection because they create a lot of lag with Ro-Gauge trains
		if TouchedConnection then
			TouchedConnection:disconnect()
			TouchedConnection = nil
		end
	end
	
	local function Couple(OtherCoupler)
		if coupler.CollisionGroup == OtherCoupler.CollisionGroup then
		-- set the coupler parts to cancollide false so they don't interfere with each other when coupled
		coupler.CanCollide = false
		OtherCoupler.CanCollide = false
		coupler.CanQuery = true
		OtherCoupler.CanQuery = true
		
		Rod = Instance.new("RodConstraint")
		Rod.Name = "RoGaugeRod"
		Rod.Visible = false
		Rod.Length = coupler.Size.Z/2+OtherCoupler.Size.Z/2
		Rod.Attachment0 = Attachment
		Rod.Attachment1 = OtherCoupler.Attachment
		Rod.Parent = coupler
		CreateRodConnection()		
		CoupledTo.Value = OtherCoupler
		OtherCoupler.CoupledTo.Value = coupler
		CreateCouplerConnection()
		if coupler:FindFirstChild("CoupleSound") then
			coupler.CoupleSound:Play()
		end
		else return end
	end
	
	local function HandleTouched(OtherCoupler)
		if not Allow.Value or CoupledTo.Value then
			-- if we aren't allowing or we are already coupled, ignore
			return
		end
		if OtherCoupler.Name ~= "RoGaugeCoupler" then
			-- if the part is not a RoGaugeCoupler, ignore
			return
		end
		local OtherAllow = OtherCoupler:FindFirstChild("Allow")
		local OtherCoupledTo = OtherCoupler:FindFirstChild("CoupledTo")
		
		if OtherCoupledTo.Value or OtherAllow.Value == false then
			-- if the other coupler is coupled or it is not allowing, ignore
			return
		end
		-- lets couple
		-- set network owner to server to perform coupling
		local NewCouplerOwner = GetCouplerOwner(OtherCoupler)
		-- perform coupling
		Couple(OtherCoupler)
		RemoveTouchedConnection()
		-- set network owner to the deserving party
		RestoreCouplerOwner(NewCouplerOwner)
	end
	
	function AddTouchedConnection()
		if TouchedConnection then
			return
		end
		TouchedConnection = coupler.Touched:connect(HandleTouched)
	end
	AddTouchedConnection()
end

do --[[ Destroy a coupling ]]--
	local function DelayCouplers()
		local OtherCoupler = CoupledTo.Value
		if not OtherCoupler then
			CoupledTo.Value = nil
			return false
		end
		OtherCoupler.DelayedTo.Value = coupler -- set the other coupler's DelayedTo value
		DelayedTo.Value = CoupledTo.Value -- set this coupler's DelayedTo value

		-- insert a spring connecting the two couplers with zero force
		-- this forces them to be the same mechanism and thus the same network owner
		local s = Instance.new("SpringConstraint")
		s.Name = "RoGaugeSpring"
		s.Damping = 0
		s.MaxForce = 0
		s.Stiffness = 0
		s.Visible = false
		s.Attachment0 = Attachment
		s.Attachment1 = OtherCoupler.Attachment
		s.Parent = coupler
		CoupledTo.Value = nil
		OtherCoupler.CoupledTo.Value = nil
		return true
	end
	
	local function Decouple()
		coupler.CanCollide = true
		Allow.Value = false--this makes it so that it won't re-connect right after you uncouple
		if CoupledTo.Value then
			local OtherCoupler = CoupledTo.Value
			if OtherCoupler:FindFirstChild("RoGaugeRod") then
				-- delete the coupler connection
				OtherCoupler.RoGaugeRod:Destroy()
			end
			if OtherCoupler:FindFirstChild("Allow") then
				-- set it to not couple back up immediately
				OtherCoupler.Allow.Value = false
			end
			if OtherCoupler:FindFirstChild("CoupledTo") then
				-- set it so it isn't coupled
				OtherCoupler.CoupledTo.Value = nil
			end
			if coupler:FindFirstChild("DecoupleSound") then
				coupler.DecoupleSound:Play()
			end
		end
		if RodConnection then
			RodConnection:Disconnect()
			RodConnection = nil
		end
		DestroyCouplerConnection()
		if Rod then
			Rod:Destroy()
		end
		Recolor()
		CoupledTo.Value = nil
		if DelayedTo.Value then
			local OtherCoupler = DelayedTo.Value
			local Halflength = OtherCoupler.Size.Z/2+coupler.Size.Z/2
			while (OtherCoupler.Position-coupler.Position).magnitude < Halflength*1.5 and DelayedTo.Value == OtherCoupler do
				wait()
			end
			if OtherCoupler:FindFirstChild("RoGaugeSpring") then
				OtherCoupler.RoGaugeSpring:Destroy()
			end
			if coupler:FindFirstChild("RoGaugeSpring") then
				coupler.RoGaugeSpring:Destroy()
			end
			DelayedTo.Value = nil
			Allow.Value = true
			Recolor()
		end
		AddTouchedConnection()
	end
	
	local function HandlePlayerInput(player)
		CouplerOwner = coupler.Parent.Parent:GetAttribute("OwnerUserId")
		if player.UserId == CouplerOwner then
	
			-- user input
			if not GetPermission(player,"Coupling") then
				return
			end
	
			if CoupledTo.Value then
				-- if we are coupled, uncoupled
				DelayCouplers()
				Recolor()
			elseif DelayedTo.Value then
				if coupler:FindFirstChild("RoGaugeSpring") then
					coupler.RoGaugeSpring:Destroy()
				end
				DelayedTo.Value = nil
				Allow.Value = false
				Recolor()
			else
				-- otherwise, toggle Allow
				Allow.Value = not Allow.Value
				if Allow.Value then
					AddTouchedConnection()
				else
					RemoveTouchedConnection()
				end
				Recolor()
			end
		else return end
	end	
	
	remote.OnServerEvent:connect(HandlePlayerInput)
	
	function CreateRodConnection()
		if RodConnection then return end
		RodConnection = Rod.AncestryChanged:connect(function(parent,parento)
			if not parento then
				RodConnection:Disconnect()
				RodConnection = nil
				Decouple()
			end
		end)
	end
	
	function CreateCouplerConnection()
		if CouplerDestroyConnection or not CoupledTo.Value then return end
		CouplerDestroyConnection = CoupledTo.Value.AncestryChanged:connect(function(parent,parento)
			if not parento then
				CouplerDestroyConnection:Disconnect()
				CouplerDestroyConnection = nil
				Decouple()
			end
		end)
	end

	function DestroyCouplerConnection()
		if CouplerDestroyConnection then
			CouplerDestroyConnection:disconnect()
			CouplerDestroyConnection = nil
		end
	end
	
	local function GetRod()
		if Rod then return end
		if CoupledTo.Value then
			Rod = CoupledTo.Value:FindFirstChild("RoGaugeRod")
			if Rod then
				CreateRodConnection()
			end
		end
	end
	
	local function CoupledToChanged()
		-- if we get the message to decouple, do so
		if CoupledTo.Value then
			CreateCouplerConnection()
			GetRod()
			Recolor()
		else
			Decouple()
		end
	end
	
	CoupledTo.Changed:connect(CoupledToChanged)
end