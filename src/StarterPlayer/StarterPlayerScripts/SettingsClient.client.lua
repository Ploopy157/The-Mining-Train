local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local ResponsiveGui = require(ReplicatedStorage:WaitForChild("ResponsiveGui"))
local Remotes = ReplicatedStorage:WaitForChild("SettingsRemotes")
local GetSettings = Remotes:WaitForChild("GetSettings")
local SaveSettings = Remotes:WaitForChild("SaveSettings")
local GetStats = Remotes:WaitForChild("GetStats")
local ResetData = Remotes:WaitForChild("ResetData")

local Gui = PlayerGui:WaitForChild("SettingsGui")
local OpenButton = Gui:WaitForChild("OpenButton")
local Dimmer = Gui:WaitForChild("Dimmer")
local Window = Gui:WaitForChild("Window")
local CloseButton = Window.Header:WaitForChild("CloseButton")
local Content = Window:WaitForChild("Content")
local TutorialButton = Content.TutorialSection:WaitForChild("TutorialButton")
local MusicSlider = Content.AudioSection.AudioContent:WaitForChild("MusicSlider")
local SfxSlider = Content.AudioSection.AudioContent:WaitForChild("SfxSlider")
local StatsGrid = Content.StatsSection:WaitForChild("StatsGrid")
local ResetButton = Content.DataSection:WaitForChild("ResetButton")
local ConfirmFrame = Gui:WaitForChild("ConfirmFrame")
local ConfirmTextBox = ConfirmFrame:WaitForChild("ConfirmTextBox")
local CancelResetButton = ConfirmFrame:WaitForChild("CancelButton")
local ConfirmResetButton = ConfirmFrame:WaitForChild("ConfirmButton")

local Settings = {MusicVolume = 0.7, SfxVolume = 0.8}
local IsOpen = false
local ActiveSlider = nil
local SaveSequence = 0

local function GetOrCreateSoundGroup(Name)
	local ExistingGroup = SoundService:FindFirstChild(Name)

	if ExistingGroup and ExistingGroup:IsA("SoundGroup") then
		return ExistingGroup
	end

	local Group = Instance.new("SoundGroup")
	Group.Name = Name
	Group.Parent = SoundService
	return Group
end

local MusicGroup = GetOrCreateSoundGroup("Music")
local SfxGroup = GetOrCreateSoundGroup("SFX")

local function AssignSoundGroup(Sound)
	if not Sound:IsA("Sound") or Sound.SoundGroup then
		return
	end

	local Category = Sound:GetAttribute("SoundCategory")
	local ParentName = Sound.Parent and string.lower(Sound.Parent.Name) or ""

	if Category == "Music" or ParentName == "music" then
		Sound.SoundGroup = MusicGroup
	elseif Category == "SFX" or Category == "SoundEffects" or ParentName == "sfx" or ParentName == "sounds" then
		Sound.SoundGroup = SfxGroup
	end
end

local function FormatNumber(Value)
	Value = tonumber(Value) or 0

	if math.abs(Value) >= 1_000_000_000 then
		return string.format("%.2fB", Value / 1_000_000_000)
	elseif math.abs(Value) >= 1_000_000 then
		return string.format("%.2fM", Value / 1_000_000)
	elseif math.abs(Value) >= 1_000 then
		return string.format("%.1fK", Value / 1_000)
	end

	return tostring(math.floor(Value + 0.5))
end

local function SetSliderVisual(Slider, Value)
	Value = math.clamp(Value, 0, 1)
	Slider.ValueLabel.Text = string.format("%d%%", math.floor(Value * 100 + 0.5))
	Slider.Track.Fill.Size = UDim2.fromScale(Value, 1)
	Slider.Track.Knob.Position = UDim2.fromScale(Value, 0.5)
end

local function ApplyAudio()
	MusicGroup.Volume = Settings.MusicVolume
	SfxGroup.Volume = Settings.SfxVolume
	SetSliderVisual(MusicSlider, Settings.MusicVolume)
	SetSliderVisual(SfxSlider, Settings.SfxVolume)
end

local function QueueSave()
	SaveSequence += 1
	local ThisSequence = SaveSequence

	task.delay(0.35, function()
		if ThisSequence ~= SaveSequence then
			return
		end

		SaveSettings:FireServer({
			MusicVolume = Settings.MusicVolume,
			SfxVolume = Settings.SfxVolume,
		})
	end)
end

local function SetSliderFromPosition(Slider, ScreenX)
	local Track = Slider.Track
	local Value = math.clamp((ScreenX - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)

	if Slider == MusicSlider then
		Settings.MusicVolume = Value
	else
		Settings.SfxVolume = Value
	end

	ApplyAudio()
	QueueSave()
end

local function BindSlider(Slider)
	Slider.Track.InputBegan:Connect(function(Input)
		if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		ActiveSlider = Slider
		SetSliderFromPosition(Slider, Input.Position.X)
	end)
end

local function UpdateStats()
	local Success, Stats = pcall(function()
		return GetStats:InvokeServer()
	end)

	if not Success or typeof(Stats) ~= "table" then
		warn("Settings menu could not load player stats.")
		return
	end

	local Prefixes = {
		LifetimeMoney = "$",
	}

	local Suffixes = {
		HighestMineDepth = " studs",
		TotalDistanceTraveled = " studs",
	}

	for _, Card in StatsGrid:GetChildren() do
		if not Card:IsA("Frame") then
			continue
		end

		local StatName = Card.Name
		local Value = Stats[StatName] or 0

		Card.Value.Text = 
			(Prefixes[StatName] or "")
			.. FormatNumber(Value)
			.. (Suffixes[StatName] or "")
	end
end

local function SetOpen(Open)
	IsOpen = Open
	Window.Visible = Open
	Dimmer.Visible = Open
	OpenButton.Visible = not Open

	if Open then
		UpdateStats()
	end
end

local function OpenTutorial()
	SetOpen(false)
end

local function SetResetConfirmationVisible(Visible)
	ConfirmFrame.Visible = Visible
	ConfirmTextBox.Text = ""
	ConfirmResetButton.Active = false
	ConfirmResetButton.AutoButtonColor = false
	ConfirmResetButton.BackgroundTransparency = 0.55
end

local function UpdateResetButton()
	local IsConfirmed = string.upper(ConfirmTextBox.Text) == "RESET"
	ConfirmResetButton.Active = IsConfirmed
	ConfirmResetButton.AutoButtonColor = IsConfirmed
	ConfirmResetButton.BackgroundTransparency = IsConfirmed and 0 or 0.55
end

local function ConfirmReset()
	if string.upper(ConfirmTextBox.Text) ~= "RESET" then
		return
	end

	ConfirmResetButton.Active = false
	ConfirmResetButton.Text = "RESETTING..."

	local Success, WasReset, Message = pcall(function()
		return ResetData:InvokeServer("RESET")
	end)

	if not Success or not WasReset then
		ConfirmResetButton.Text = "RESET"
		UpdateResetButton()
		warn("Data reset failed:", Message or WasReset)
	end
end

for _, Descendant in game:GetDescendants() do
	AssignSoundGroup(Descendant)
end

game.DescendantAdded:Connect(AssignSoundGroup)
BindSlider(MusicSlider)
BindSlider(SfxSlider)

UserInputService.InputChanged:Connect(function(Input)
	if not ActiveSlider then
		return
	end

	if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
		SetSliderFromPosition(ActiveSlider, Input.Position.X)
	end
end)

UserInputService.InputEnded:Connect(function(Input)
	if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
		ActiveSlider = nil
	end
end)

OpenButton.Activated:Connect(function()
	SetOpen(true)
end)

CloseButton.Activated:Connect(function()
	SetOpen(false)
end)

Dimmer.Activated:Connect(function()
	SetOpen(false)
end)

TutorialButton.Activated:Connect(OpenTutorial)
ResetButton.Activated:Connect(function()
	SetResetConfirmationVisible(true)
end)

CancelResetButton.Activated:Connect(function()
	SetResetConfirmationVisible(false)
end)

ConfirmTextBox:GetPropertyChangedSignal("Text"):Connect(UpdateResetButton)
ConfirmResetButton.Activated:Connect(ConfirmReset)

UserInputService.InputBegan:Connect(function(Input, GameProcessed)
	if GameProcessed or Input.KeyCode ~= Enum.KeyCode.Escape then
		return
	end

	if ConfirmFrame.Visible then
		SetResetConfirmationVisible(false)
	elseif IsOpen then
		SetOpen(false)
	end
end)

ResponsiveGui.Bind(function(Layout)
	if Layout == ResponsiveGui.Layout.Compact then
		Window.Size = UDim2.new(1, -16, 1, -16)
		Window.Position = UDim2.fromScale(0.5, 0.5)
		OpenButton.Size = UDim2.fromOffset(46, 46)
		OpenButton.Position = UDim2.new(1, -12, 0.5, 118)
		ConfirmFrame.Size = UDim2.new(1, -24, 0, 235)
	elseif Layout == ResponsiveGui.Layout.Medium then
		Window.Size = UDim2.new(0.88, 0, 0.88, 0)
		Window.Position = UDim2.fromScale(0.5, 0.5)
		OpenButton.Size = UDim2.fromOffset(50, 50)
		OpenButton.Position = UDim2.new(1, -18, 0.5, 135)
		ConfirmFrame.Size = UDim2.fromOffset(420, 235)
	else
		Window.Size = UDim2.fromOffset(600, 610)
		Window.Position = UDim2.fromScale(0.5, 0.5)
		OpenButton.Size = UDim2.fromOffset(54, 54)
		OpenButton.Position = UDim2.new(1, -22, 0.5, 150)
		ConfirmFrame.Size = UDim2.fromOffset(420, 235)
	end
end)

local Success, SavedSettings = pcall(function()
	return GetSettings:InvokeServer()
end)

if Success and typeof(SavedSettings) == "table" then
	Settings.MusicVolume = math.clamp(tonumber(SavedSettings.MusicVolume) or Settings.MusicVolume, 0, 1)
	Settings.SfxVolume = math.clamp(tonumber(SavedSettings.SfxVolume) or Settings.SfxVolume, 0, 1)
end

ApplyAudio()
SetOpen(false)
SetResetConfirmationVisible(false)