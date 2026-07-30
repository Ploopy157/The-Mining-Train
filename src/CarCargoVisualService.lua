local CarCargoVisualService = {}

local EmptySlotTransparency = 0.5
local OccupiedSlotTransparency = 0
local LockedSlotTransparency = 1

local CargoVisualFolderName = "CargoVisualSlots"
local CargoSlotPrefix = "CargoSlot_"
local OresFolder = game.ServerStorage.Ores

local function GetSlotNumber(SlotInstance)
	local SlotNumberText = string.match(
		SlotInstance.Name,
		"^" .. CargoSlotPrefix .. "(%d+)$"
	)

	return tonumber(SlotNumberText)
end

local function SetObjectTransparency(
	Object,
	Transparency
)
	if Object:IsA("BasePart") then
		Object.Transparency = Transparency
		Object.CanCollide = false
		Object.CanTouch = false
		Object.CanQuery = false
		return
	end

	if Object:IsA("Decal")
		or Object:IsA("Texture") then
		Object.Transparency = Transparency
	end
end

local function SetSlotTransparency(
	Slot,
	Transparency
)
	SetObjectTransparency(
		Slot,
		Transparency
	)

	for _, Descendant in Slot:GetDescendants() do
		SetObjectTransparency(
			Descendant,
			Transparency
		)
	end
end

local function GetCargoVisualFolder(Car)
	if not Car then
		return nil
	end

	return Car:FindFirstChild(
		CargoVisualFolderName
	)
end

local function GetSlots(Car)
	local CargoVisualFolder =
		GetCargoVisualFolder(Car)

	if not CargoVisualFolder then
		warn(
			"CarCargoVisualService could not find "
				.. CargoVisualFolderName
				.. " inside "
				.. Car:GetFullName()
		)

		return {}
	end

	local Slots = {}

	for _, Child in CargoVisualFolder:GetChildren() do
		local SlotNumber =
			GetSlotNumber(Child)

		if SlotNumber then
			Slots[SlotNumber] = Child
		end
	end

	return Slots
end

local function IsSlotOccupied(
	OccupiedSlots,
	SlotNumber
)
	if typeof(OccupiedSlots) == "number" then
		return SlotNumber <= OccupiedSlots
	end

	if typeof(OccupiedSlots) ~= "table" then
		return false
	end

	if OccupiedSlots[SlotNumber] == true then
		return true
	end

	for _, OccupiedSlotNumber in OccupiedSlots do
		if OccupiedSlotNumber == SlotNumber then
			return true
		end
	end

	return false
end

local function GetOccupiedSlotCount(CarData)
	if typeof(CarData) ~= "table" then
		return 0
	end

	local Inventory = CarData.Inventory

	if typeof(Inventory) ~= "table" then
		return 0
	end

	local OccupiedSlotCount = 0

	for _, CargoAmount in Inventory do
		if typeof(CargoAmount) == "number" then
			OccupiedSlotCount += CargoAmount
		end
	end

	return OccupiedSlotCount
end

local function SaveDefaultAppearance(Object)
	if not Object:IsA("BasePart") then
		return
	end

	if Object:GetAttribute("CargoDefaultAppearanceSaved") then
		return
	end

	Object:SetAttribute(
		"CargoDefaultAppearanceSaved",
		true
	)

	Object:SetAttribute(
		"CargoDefaultColor",
		Object.Color
	)

	Object:SetAttribute(
		"CargoDefaultMaterial",
		Object.Material.Name
	)

	Object:SetAttribute(
		"CargoDefaultMaterialVariant",
		Object.MaterialVariant
	)
end

local function RestoreDefaultAppearance(Object)
	if not Object:IsA("BasePart") then
		return
	end

	SaveDefaultAppearance(Object)

	local DefaultColor =
		Object:GetAttribute("CargoDefaultColor")

	local DefaultMaterialName =
		Object:GetAttribute("CargoDefaultMaterial")

	local DefaultMaterialVariant =
		Object:GetAttribute("CargoDefaultMaterialVariant")

	if typeof(DefaultColor) == "Color3" then
		Object.Color = DefaultColor
	end

	if typeof(DefaultMaterialName) == "string" then
		local Success, DefaultMaterial =
			pcall(function()
				return Enum.Material[DefaultMaterialName]
			end)

		if Success and DefaultMaterial then
			Object.Material = DefaultMaterial
		end
	end

	if typeof(DefaultMaterialVariant) == "string" then
		Object.MaterialVariant = DefaultMaterialVariant
	end
end

local function GetOreSamplePart(CargoType)
	local OreSample =
		OresFolder:FindFirstChild(CargoType)

	if not OreSample then
		warn(
			"CarCargoVisualService could not find ore sample:",
			CargoType
		)

		return nil
	end

	if OreSample:IsA("BasePart") then
		return OreSample
	end

	if OreSample:IsA("Model") then
		return OreSample.PrimaryPart
			or OreSample:FindFirstChildWhichIsA(
				"BasePart",
				true
			)
	end

	return OreSample:FindFirstChildWhichIsA(
		"BasePart",
		true
	)
end

local function ApplyOreAppearanceToObject(
	Object,
	OreSamplePart
)
	if not Object:IsA("BasePart") then
		return
	end

	SaveDefaultAppearance(Object)

	Object.Color = OreSamplePart.Color
	Object.Material = OreSamplePart.Material
	Object.MaterialVariant =
		OreSamplePart.MaterialVariant
end

local function ApplyOreAppearanceToSlot(
	Slot,
	CargoType
)
	local OreSamplePart =
		GetOreSamplePart(CargoType)

	if not OreSamplePart then
		return false
	end

	if Slot:IsA("BasePart") then
		ApplyOreAppearanceToObject(
			Slot,
			OreSamplePart
		)
	end

	for _, Descendant in Slot:GetDescendants() do
		ApplyOreAppearanceToObject(
			Descendant,
			OreSamplePart
		)
	end

	return true
end

local function RestoreSlotAppearance(Slot)
	if Slot:IsA("BasePart") then
		RestoreDefaultAppearance(Slot)
	end

	for _, Descendant in Slot:GetDescendants() do
		RestoreDefaultAppearance(Descendant)
	end
end

local function BuildCargoSlotList(CarData)
	local CargoSlotList = {}

	if typeof(CarData) ~= "table"
		or typeof(CarData.Inventory) ~= "table" then
		return CargoSlotList
	end

	local CargoTypes = {}

	for CargoType, CargoAmount in CarData.Inventory do
		if typeof(CargoAmount) == "number"
			and CargoAmount > 0 then
			table.insert(
				CargoTypes,
				tostring(CargoType)
			)
		end
	end

	-- Keeps slot assignment consistent between updates.
	table.sort(CargoTypes)

	for _, CargoType in CargoTypes do
		local CargoAmount =
			math.max(
				0,
				math.floor(
					tonumber(
						CarData.Inventory[CargoType]
					) or 0
				)
			)

		for _ = 1, CargoAmount do
			table.insert(
				CargoSlotList,
				CargoType
			)
		end
	end

	return CargoSlotList
end

function CarCargoVisualService.RefreshCar(
	Car,
	CarData
)
	if not Car then
		return false, "Car was not provided."
	end

	if typeof(CarData) ~= "table" then
		return false, "CarData was not provided."
	end

	local UnlockedSlotCount =
		math.max(
			0,
			math.floor(
				tonumber(CarData.Capacity) or 0
			)
		)

	local CargoSlotList =
		BuildCargoSlotList(CarData)

	local Slots = GetSlots(Car)

	for SlotNumber, Slot in Slots do
		if SlotNumber > UnlockedSlotCount then
			RestoreSlotAppearance(Slot)

			SetSlotTransparency(
				Slot,
				LockedSlotTransparency
			)

			continue
		end

		local CargoType =
			CargoSlotList[SlotNumber]

		if CargoType then
			local AppearanceApplied =
				ApplyOreAppearanceToSlot(
					Slot,
					CargoType
				)

			if AppearanceApplied then
				SetSlotTransparency(
					Slot,
					OccupiedSlotTransparency
				)
			else
				RestoreSlotAppearance(Slot)

				SetSlotTransparency(
					Slot,
					EmptySlotTransparency
				)
			end
		else
			RestoreSlotAppearance(Slot)

			SetSlotTransparency(
				Slot,
				EmptySlotTransparency
			)
		end
	end

	return true
end

function CarCargoVisualService.SetSlotOccupied(
	Car,
	SlotNumber,
	IsOccupied,
	UnlockedSlotCount
)
	SlotNumber =
		tonumber(SlotNumber)

	if not SlotNumber then
		return false,
			"SlotNumber must be a number."
	end

	local Slots = GetSlots(Car)
	local Slot = Slots[SlotNumber]

	if not Slot then
		return false,
			"Cargo slot "
				.. tostring(SlotNumber)
				.. " was not found."
	end

	UnlockedSlotCount =
		tonumber(UnlockedSlotCount)
		or math.huge

	if SlotNumber > UnlockedSlotCount then
		SetSlotTransparency(
			Slot,
			LockedSlotTransparency
		)

		return true
	end

	SetSlotTransparency(
		Slot,
		IsOccupied
				and OccupiedSlotTransparency
			or EmptySlotTransparency
	)

	return true
end

function CarCargoVisualService.ClearCar(
	Car,
	UnlockedSlotCount
)
	return CarCargoVisualService.RefreshCar(
		Car,
		UnlockedSlotCount,
		{}
	)
end

local function SerializeValue(
	Value,
	VisitedTables
)
	local ValueType = typeof(Value)

	if ValueType == "nil" then
		return "nil"
	end

	if ValueType == "string" then
		return string.format("%q", Value)
	end

	if ValueType == "number"
		or ValueType == "boolean" then
		return tostring(Value)
	end

	if ValueType == "Instance" then
		return Value:GetFullName()
	end

	if ValueType ~= "table" then
		return tostring(Value)
	end

	VisitedTables = VisitedTables or {}

	if VisitedTables[Value] then
		return "<CircularReference>"
	end

	VisitedTables[Value] = true

	local Keys = {}

	for Key in Value do
		table.insert(Keys, Key)
	end

	table.sort(Keys, function(Left, Right)
		return tostring(Left) < tostring(Right)
	end)

	local SerializedEntries = {}

	for _, Key in Keys do
		table.insert(
			SerializedEntries,
			SerializeValue(Key, VisitedTables)
				.. "="
				.. SerializeValue(Value[Key], VisitedTables)
		)
	end

	VisitedTables[Value] = nil

	return "{"
		.. table.concat(SerializedEntries, ",")
		.. "}"
end

function CarCargoVisualService.GetInventorySignature(
	CarData
)
	if typeof(CarData) ~= "table" then
		return "NoCarData"
	end

	local SignatureParts = {
		"Capacity=" .. tostring(CarData.Capacity or 0),
	}

	local Inventory = CarData.Inventory

	if typeof(Inventory) == "table" then
		local CargoTypes = {}

		for CargoType in Inventory do
			table.insert(
				CargoTypes,
				tostring(CargoType)
			)
		end

		table.sort(CargoTypes)

		for _, CargoType in CargoTypes do
			table.insert(
				SignatureParts,
				CargoType
					.. "="
					.. tostring(Inventory[CargoType])
			)
		end
	end

	return table.concat(
		SignatureParts,
		"|"
	)
end

--compatibility for changed scripts
CarCargoVisualService.UpdateCargoVisuals =
	CarCargoVisualService.RefreshCar

CarCargoVisualService.UpdateCar =
	CarCargoVisualService.RefreshCar

CarCargoVisualService.Update =
	CarCargoVisualService.RefreshCar

return CarCargoVisualService
