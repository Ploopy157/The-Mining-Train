local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local FurnaceGui
local ModalBlocker
local RenderConnection

local function EnsureModalBlocker()
	if not FurnaceGui then
		return
	end

	ModalBlocker =
		FurnaceGui:FindFirstChild(
			"ModalInputBlocker"
		)

	if ModalBlocker
		and not ModalBlocker:IsA("TextButton") then

		ModalBlocker:Destroy()
		ModalBlocker = nil
	end

	if not ModalBlocker then
		ModalBlocker = Instance.new("TextButton")
		ModalBlocker.Name = "ModalInputBlocker"
		ModalBlocker.Size = UDim2.fromScale(1, 1)
		ModalBlocker.Position = UDim2.fromScale(0, 0)
		ModalBlocker.BackgroundTransparency = 1
		ModalBlocker.BorderSizePixel = 0
		ModalBlocker.Text = ""
		ModalBlocker.AutoButtonColor = false
		ModalBlocker.Active = true
		ModalBlocker.Modal = true
		ModalBlocker.Selectable = false
		ModalBlocker.ZIndex = 0
		ModalBlocker.Parent = FurnaceGui
	end
end

local function UpdateMouseState()
	if not FurnaceGui then
		return
	end

	EnsureModalBlocker()

	local IsOpen = FurnaceGui.Enabled

	if ModalBlocker then
		ModalBlocker.Visible = IsOpen
		ModalBlocker.Active = IsOpen
		ModalBlocker.Modal = IsOpen
	end

	if IsOpen then
		UserInputService.MouseBehavior =
			Enum.MouseBehavior.Default

		UserInputService.MouseIconEnabled = true
	end

	if IsOpen and not RenderConnection then
		RenderConnection =
			RunService.RenderStepped:Connect(
				function()
					if not FurnaceGui
						or not FurnaceGui.Enabled then

						return
					end

					if UserInputService.MouseBehavior
						~= Enum.MouseBehavior.Default then

						UserInputService.MouseBehavior =
							Enum.MouseBehavior.Default
					end

					if not UserInputService.MouseIconEnabled then
						UserInputService.MouseIconEnabled = true
					end
				end
			)
	elseif not IsOpen and RenderConnection then
		RenderConnection:Disconnect()
		RenderConnection = nil
	end
end

local function ConnectFurnaceGui(Gui)
	if FurnaceGui == Gui then
		return
	end

	if RenderConnection then
		RenderConnection:Disconnect()
		RenderConnection = nil
	end

	FurnaceGui = Gui
	ModalBlocker = nil

	EnsureModalBlocker()
	FurnaceGui:GetPropertyChangedSignal(
		"Enabled"
	):Connect(UpdateMouseState)

	UpdateMouseState()
end

local ExistingGui =
	PlayerGui:FindFirstChild("FurnaceGui")

if ExistingGui
	and ExistingGui:IsA("ScreenGui") then

	ConnectFurnaceGui(ExistingGui)
end

PlayerGui.ChildAdded:Connect(function(Child)
	if Child.Name == "FurnaceGui"
		and Child:IsA("ScreenGui") then

		ConnectFurnaceGui(Child)
	end
end)
