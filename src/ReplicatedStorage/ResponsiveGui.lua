local Workspace = game:GetService("Workspace")

local ResponsiveGui = {}

ResponsiveGui.Layout = {
	Compact = "Compact",
	Medium = "Medium",
	Desktop = "Desktop",
}

local CurrentCamera = nil
local ViewportConnection = nil
local CameraConnection = nil
local Callbacks = {}
local LastLayout = nil
local LastViewport = Vector2.zero

local function GetLayout(Viewport)
	if Viewport.X < 760 or Viewport.Y < 430 then
		return ResponsiveGui.Layout.Compact
	end

	if Viewport.X < 1100 or Viewport.Y < 650 then
		return ResponsiveGui.Layout.Medium
	end

	return ResponsiveGui.Layout.Desktop
end

local function Update()
	CurrentCamera = Workspace.CurrentCamera

	if not CurrentCamera then
		return
	end

	local Viewport = CurrentCamera.ViewportSize
	local Layout = GetLayout(Viewport)

	LastViewport = Viewport
	LastLayout = Layout

	for _, Callback in Callbacks do
		local Success, ErrorMessage = pcall(Callback, Layout, Viewport)

		if not Success then
			warn("Responsive GUI callback failed:", ErrorMessage)
		end
	end
end

local function ConnectCamera()
	if ViewportConnection then
		ViewportConnection:Disconnect()
		ViewportConnection = nil
	end

	CurrentCamera = Workspace.CurrentCamera

	if CurrentCamera then
		ViewportConnection = CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(Update)
	end

	Update()
end

function ResponsiveGui.Bind(Callback)
	assert(typeof(Callback) == "function", "ResponsiveGui.Bind requires a function")

	table.insert(Callbacks, Callback)

	if LastLayout then
		task.defer(Callback, LastLayout, LastViewport)
	end

	local IsConnected = true

	return function()
		if not IsConnected then
			return
		end

		IsConnected = false

		local Index = table.find(Callbacks, Callback)

		if Index then
			table.remove(Callbacks, Index)
		end
	end
end

function ResponsiveGui.GetWindowSize(Layout, DesktopSize, MediumSize)
	if Layout == ResponsiveGui.Layout.Compact then
		return UDim2.new(1, -24, 1, -24)
	end

	if Layout == ResponsiveGui.Layout.Medium then
		return MediumSize or UDim2.new(0.9, 0, 0.9, 0)
	end

	return DesktopSize
end

function ResponsiveGui.GetLayout()
	return LastLayout
end

CameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(ConnectCamera)
ConnectCamera()

return ResponsiveGui