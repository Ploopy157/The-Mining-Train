local Players =
	game:GetService("Players")

local Lighting =
	game:GetService("Lighting")

local RunService =
	game:GetService("RunService")

local Workspace =
	game:GetService("Workspace")

local Player =
	Players.LocalPlayer

local MineFolder =
	Workspace:WaitForChild(
		"MineContents"
	)

local GridOrigin =
	MineFolder:GetAttribute(
		"MineOrigin"
	)

if typeof(GridOrigin) ~= "Vector3" then
	GridOrigin =
		MineFolder:GetAttributeChangedSignal(
			"MineOrigin"
		):Wait()

	GridOrigin =
		MineFolder:GetAttribute(
			"MineOrigin"
		)
end

if typeof(GridOrigin) ~= "Vector3" then
	warn(
		"MineDepthLighting has no valid MineOrigin attribute."
	)

	return
end

local MaximumMineDepth = 5000

local DepthLayers = {
	{
		Depth = 0,
		Brightness = 0,
		Contrast = 0,
		Saturation = 0,
		TintColor = Color3.fromRGB(
			255,
			255,
			255
		),
	},

	{
		Depth = 300,
		Brightness = -0.04,
		Contrast = 0.03,
		Saturation = -0.03,
		TintColor = Color3.fromRGB(
			244,
			239,
			230
		),
	},

	{
		Depth = 700,
		Brightness = -0.10,
		Contrast = 0.07,
		Saturation = -0.08,
		TintColor = Color3.fromRGB(
			224,
			225,
			220
		),
	},

	{
		Depth = 1200,
		Brightness = -0.18,
		Contrast = 0.12,
		Saturation = -0.16,
		TintColor = Color3.fromRGB(
			201,
			210,
			216
		),
	},

	{
		Depth = 1850,
		Brightness = -0.28,
		Contrast = 0.18,
		Saturation = -0.24,
		TintColor = Color3.fromRGB(
			178,
			193,
			207
		),
	},

	{
		Depth = 2600,
		Brightness = -0.38,
		Contrast = 0.24,
		Saturation = -0.31,
		TintColor = Color3.fromRGB(
			153,
			170,
			190
		),
	},

	{
		Depth = 3400,
		Brightness = -0.48,
		Contrast = 0.31,
		Saturation = -0.39,
		TintColor = Color3.fromRGB(
			128,
			147,
			174
		),
	},

	{
		Depth = 4200,
		Brightness = -0.58,
		Contrast = 0.38,
		Saturation = -0.47,
		TintColor = Color3.fromRGB(
			106,
			124,
			157
		),
	},

	{
		Depth = MaximumMineDepth,
		Brightness = -0.67,
		Contrast = 0.45,
		Saturation = -0.55,
		TintColor = Color3.fromRGB(
			88,
			105,
			143
		),
	},
}

local ColorCorrection =
	Lighting:FindFirstChild(
		"MineDepthColorCorrection"
	)

if ColorCorrection
	and not ColorCorrection:IsA(
		"ColorCorrectionEffect"
	) then

	ColorCorrection:Destroy()
	ColorCorrection = nil
end

if not ColorCorrection then
	ColorCorrection =
		Instance.new(
			"ColorCorrectionEffect"
		)

	ColorCorrection.Name =
		"MineDepthColorCorrection"

	ColorCorrection.Parent =
		Lighting
end

local CurrentBrightness = 0
local CurrentContrast = 0
local CurrentSaturation = 0
local CurrentTint =
	Color3.new(1, 1, 1)

local function GetDepth()
	local Character =
		Player.Character

	local Root =
		Character
		and Character:FindFirstChild(
			"HumanoidRootPart"
		)

	if not Root then
		return 0
	end

	return math.clamp(
		Root.Position.X
			- GridOrigin.X,
		0,
		MaximumMineDepth
	)
end

local function GetLayerValues(Depth)
	local LowerLayer =
		DepthLayers[1]

	local UpperLayer =
		DepthLayers[
			#DepthLayers
		]

	for Index = 1,
		#DepthLayers - 1 do

		local FirstLayer =
			DepthLayers[Index]

		local SecondLayer =
			DepthLayers[Index + 1]

		if Depth >= FirstLayer.Depth
			and Depth <= SecondLayer.Depth then

			LowerLayer = FirstLayer
			UpperLayer = SecondLayer
			break
		end
	end

	local LayerDistance =
		math.max(
			UpperLayer.Depth
				- LowerLayer.Depth,
			1
		)

	local Alpha =
		math.clamp(
			(
				Depth
				- LowerLayer.Depth
			) / LayerDistance,
			0,
			1
		)

	return {
		Brightness = LowerLayer.Brightness
			+ (
				UpperLayer.Brightness
				- LowerLayer.Brightness
			) * Alpha,

		Contrast = LowerLayer.Contrast
			+ (
				UpperLayer.Contrast
				- LowerLayer.Contrast
			) * Alpha,

		Saturation = LowerLayer.Saturation
			+ (
				UpperLayer.Saturation
				- LowerLayer.Saturation
			) * Alpha,

		TintColor =
			LowerLayer.TintColor:Lerp(
				UpperLayer.TintColor,
				Alpha
			),
	}
end

RunService.RenderStepped:Connect(
	function(DeltaTime)
		local Depth = GetDepth()
		local Target =
			GetLayerValues(Depth)

		local SmoothAlpha =
			1
			- math.exp(
				-DeltaTime * 4
			)

		CurrentBrightness +=
			(
				Target.Brightness
					- CurrentBrightness
			) * SmoothAlpha

		CurrentContrast +=
			(
				Target.Contrast
					- CurrentContrast
			) * SmoothAlpha

		CurrentSaturation +=
			(
				Target.Saturation
					- CurrentSaturation
			) * SmoothAlpha

		CurrentTint =
			CurrentTint:Lerp(
				Target.TintColor,
				SmoothAlpha
			)

		ColorCorrection.Brightness =
			CurrentBrightness

		ColorCorrection.Contrast =
			CurrentContrast

		ColorCorrection.Saturation =
			CurrentSaturation

		ColorCorrection.TintColor =
			CurrentTint
	end
)
