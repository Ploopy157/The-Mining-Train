local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Remotes =
	ReplicatedStorage:WaitForChild(
		"ShopTeleportRemotes"
	)

local TeleportToShop =
	Remotes:WaitForChild("TeleportToShop")

local Gui = script.Parent

local ShopButton =
	Gui.MainHudContainer.NavigationRow:WaitForChild("ShopButton")

local RequestInProgress = false

local function ShowMessage(Message)
	-- Use the Train menu status label when available.
	local TrainGui =
		PlayerGui:FindFirstChild("TrainGui")

	local TrainFrame =
		TrainGui
		and TrainGui:FindFirstChild(
			"TrainFrame"
		)

	local StatusLabel =
		TrainFrame
		and TrainFrame:FindFirstChild(
			"StatusLabel"
		)

	if StatusLabel then
		StatusLabel.Text = Message
	end
end

local function SetButtonEnabled(Enabled)
	ShopButton.Active = Enabled
	ShopButton.AutoButtonColor = Enabled

	ShopButton.BackgroundColor3 =
		Enabled
		and Color3.fromRGB(50, 56, 67)
		or Color3.fromRGB(73, 76, 84)
end

ShopButton.Activated:Connect(function()
	if RequestInProgress then
		return
	end

	RequestInProgress = true
	SetButtonEnabled(false)

	local RequestSuccess,
		TeleportSuccess,
		Message =
		pcall(function()
			return TeleportToShop:InvokeServer()
		end)

	RequestInProgress = false
	SetButtonEnabled(true)

	if not RequestSuccess then
		ShowMessage(
			"Unable to contact the teleport server."
		)

		warn(
			"Shop teleport request failed:",
			TeleportSuccess
		)

		return
	end

	if not TeleportSuccess then
		ShowMessage(
			tostring(
				Message
				or "Shop teleport was denied."
			)
		)

		return
	end

	ShowMessage(
		tostring(
			Message
			or "Teleported to the shops."
		)
	)
end)

--local function UpdateResponsiveSizing() 
--	local Camera = Workspace.CurrentCamera

--	if not Camera then
--		return
--	end

--	local Viewport = Camera.ViewportSize

--	local IsSmallScreen =
--		Viewport.X < 760
--		or Viewport.Y < 600

--	if IsSmallScreen then
--		ShopButton.Size =
--			UDim2.fromOffset(60, 60)

--		ShopButton.Position =
--			UDim2.new(
--				1,
--				-10,
--				0.5,
--				-140
--			)
--	else
--		ShopButton.Size =
--			UDim2.fromOffset(72, 72)

--		ShopButton.Position =
--			UDim2.new(
--				1,
--				-16,
--				0.5,
--				-164
--			)
--	end
--end

--local function ConnectCamera()
--	local Camera = Workspace.CurrentCamera

--	if Camera then
--		Camera:GetPropertyChangedSignal(
--			"ViewportSize"
--		):Connect(UpdateResponsiveSizing)
--	end

--	UpdateResponsiveSizing()
--end

--Workspace:GetPropertyChangedSignal(
--	"CurrentCamera"
--):Connect(ConnectCamera)

--ConnectCamera()
