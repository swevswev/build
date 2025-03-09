--Services and plr
local plr = game.Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local mouse = plr:GetMouse()

--Events and functions
local PlacementSystemFolder = ReplicatedStorage["Building System"].Placement
	local togglePlacement = PlacementSystemFolder.togglePlacement
local TransformSystemFolder = ReplicatedStorage["Building System"].Transform
	local rotationEvent = TransformSystemFolder.rotationEvent
	local movementEvent = TransformSystemFolder.movementEvent
	local scaleEvent = TransformSystemFolder.scaleEvent
local PlotSystemFolder = ReplicatedStorage["Plot System"]
	local updateOwnedPlotEvent = PlotSystemFolder.updateOwnedPlot

--Modules
local placementRotationModule = require(script.placementRotation)
local boundaryDetectionModule = require(ReplicatedStorage.Modules.boundaryDetection)

local selected = nil
local selectedHitbox = nil
local selectedFilterFolderIndex = 0
local plrPlot = nil

local rotationHandle = plr.PlayerGui:WaitForChild("rotationHandle")
local movementHandle = plr.PlayerGui:WaitForChild("movementHandle")
local scaleHandle = plr.PlayerGui:WaitForChild("scaleHandle")

--Custom mouse targeting
local MAX_RAY_LENGTH = 75
whiteList = {}
local filterFolder = {}

--Booleans grouped by their use
local flags = 
	{
		["Transform"] = 
		{
			active = false,
			{
				rotation = false,
				movement = false,
				scale = false
			}
		},
		["Placement"] = 
		{
			active = false,
			{
				placing = false,
				snap = true,
				rotate = false,
				surfaceSnap = false
			}
		}
	}

local snapSize = .25
local rotationSnap = 5
local rotationDirection = "Y"
local placementRotationCFrame = CFrame.Angles(0,0,0)

function getPlot(plotId)
	local plots = game.Workspace.playerPlots
	for _, plot in ipairs(plots:GetChildren()) do
		if plot:GetAttribute("plotId", plotId) then
			return plot
		end
	end
end

function initializeRaycastFilterList()
	table.clear(filterFolder)
	if plrPlot then
		local plotChildren = plrPlot:GetChildren()
		for _, obj in ipairs(plotChildren) do
			if obj.ClassName ~= "Folder" then
				table.insert(filterFolder, obj)
			end
		end
	end
	table.insert(filterFolder, plr.Character)
end

function place()
	print(selected)
	selected.Parent = plrPlot.whiteList.props
	table.remove(filterFolder, selectedFilterFolderIndex)
	if selected.ClassName == "Model" then
		table.insert(filterFolder, selectedHitbox)
	end
end

function GetAABB(part)
	local abs = math.abs

	local cf = part.CFrame
	local size = part.Size
	local sx, sy, sz = size.X/2, size.Y/2, size.Z/2

	local x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = cf:components() 

	local wsx = abs(R00) * sx + abs(R01) * sy + abs(R02) * sz
	local wsy = abs(R10) * sx + abs(R11) * sy + abs(R12) * sz
	local wsz = abs(R20) * sx + abs(R21) * sy + abs(R22) * sz

	return Vector3.new(wsx, wsy, wsz)
end

local function calcPropPos()
	local mouseTarget = getMouseTargetWithBlackList()
	if mouseTarget then
		local targetedPart = mouseTarget.Instance
		
		local tempCFrame = CFrame.new(mouseTarget.Position.X, mouseTarget.Position.Y, mouseTarget.Position.Z)
		
		if flags["Placement"][1].snap == true then
			tempCFrame = CFrame.new( math.round(tempCFrame.X / snapSize) * snapSize,  math.round(tempCFrame.Y / snapSize) * snapSize,  math.round(tempCFrame.Z / snapSize) * snapSize)
		end
		if flags["Placement"][1].surfaceSnap then
			tempCFrame = CFrame.lookAt(tempCFrame.Position, tempCFrame.Position + mouseTarget.Normal) * CFrame.Angles(0, math.rad(90), 0) --rotational offset for surface snap
		end
		
	
	
		tempCFrame *= placementRotationCFrame
	
		
		local offset = mouseTarget.Normal * GetAABB(selectedHitbox)
		


		return tempCFrame + offset
	end
end

local function moveProp()
	local propPosition =  calcPropPos()
	if propPosition ~= nil then
		selected:PivotTo(selectedHitbox.CFrame:Lerp( calcPropPos() , 1))
	end
end


function clearHandles()
	rotationHandle.Adornee = nil
	movementHandle.Adornee = nil
	scaleHandle.Adornee = nil
end

function clearFlagsInGroup(groupName, omittedFlag)
	print(flags)
	for group, groupFlags in flags do
		if group == groupName then
			for property, value in groupFlags[1] do
				print(groupFlags)
				if property ~= omittedFlag then
					print(property, omittedFlag)
					flags[groupName][1][property] = false
				end
			end
		end
	end
end

UserInputService.InputBegan:Connect(function(input)
	
	if flags["Placement"].active == true then
		if (input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.T or input.KeyCode == Enum.KeyCode.Y) then
			if input.KeyCode == Enum.KeyCode.R then rotationDirection = "Y"
			elseif input.KeyCode == Enum.KeyCode.T then rotationDirection = "X"
			elseif input.KeyCode == Enum.KeyCode.Y then rotationDirection = "Z" end
			
			if flags["Placement"][1].snap == true then
				placementRotationModule.start(selected, rotationDirection, rotationSnap)
			else
				placementRotationModule.start(selected, rotationDirection, 0)
			end
			flags["Placement"][1].rotate = true
		elseif input.KeyCode == Enum.KeyCode.Z then
			placementRotationCFrame = CFrame.Angles(0,0,0)
		elseif input.KeyCode == Enum.KeyCode.X then
			flags["Placement"][1]["snap"] = not flags["Placement"][1]["snap"]
		elseif input.KeyCode == Enum.KeyCode.F then
			flags["Placement"][1].surfaceSnap = not flags["Placement"][1].surfaceSnap
		end
	end
	
end)

UserInputService.InputEnded:Connect(function(input)
	if (input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.T or input.KeyCode == Enum.KeyCode.Y) and flags["Placement"].active == true  then
		placementRotationCFrame *= placementRotationModule.stop()
		flags["Placement"][1].rotate = false
	end
end)

mouse.Button1Down:Connect(function()
	if flags["Placement"].active == true and boundaryDetectionModule.getResult(selected, plrPlot) == true then
		if flags["Placement"][1].rotate == true then
			placementRotationModule.stop()
			flags["Placement"][1].rotate = false
		end
		flags["Placement"].active = false
		boundaryDetectionModule.stop()
		place()
	end
end)

function toggleRotation()
	flags["Transform"].active = true
	clearFlagsInGroup("Transform", "rotation")
	flags["Transform"][1]["rotation"] = not flags["Transform"][1]["rotation"]
	if flags["Transform"][1]["rotation"] == true then
		rotationHandle.Adornee = selectedHitbox
	end
end

function toggleMovement()
	flags["Transform"].active = true
	clearFlagsInGroup("Transform", "movement")
	flags["Transform"][1]["movement"] = not flags["Transform"][1]["movement"]
	if flags["Transform"][1]["movement"] == true then
		movementHandle.Adornee = selectedHitbox
	end
end

function toggleScale()
	flags["Transform"].active = true
	clearFlagsInGroup("Transform", "scale")
	flags["Transform"][1]["scale"] = not flags["Transform"][1]["scale"]
	if flags["Transform"][1]["scale"] == true then
		scaleHandle.Adornee = selectedHitbox
	end
end

movementEvent.Event:Connect(function()
	clearHandles()
	toggleMovement()
end)

rotationEvent.Event:Connect(function()
	clearHandles()
	toggleRotation()
end)

scaleEvent.Event:Connect(function()
	clearHandles()
	toggleScale()
end)


updateOwnedPlotEvent.OnClientEvent:Connect(function(plotId)
	plrPlot = getPlot(plotId)
	table.clear(whiteList)
	table.insert(whiteList, plrPlot.whiteList)
	initializeRaycastFilterList()
end)


togglePlacement.Event:Connect(function(propName, propType)
	local prop = game.ReplicatedStorage.Props:FindFirstChild(propName)
	
	--selected = nil
	if flags["Placement"].active == false then
		selected = prop
		
		if propType ~= "Model" then
			selected = Instance.new("Part")
			selected.Anchored = true
			selected.Size = Vector3.new(2,2,2)
			selected.Shape = Enum.PartType[propType]
		else
			selected = prop:Clone()
		end
		
		
		selected.Parent = plrPlot -- prop holder
		table.insert(filterFolder, selected)
		selectedFilterFolderIndex = #filterFolder
		
		if propType == "Model" then selectedHitbox = selected.hitbox else selectedHitbox = selected end
		boundaryDetectionModule.start(selected, plrPlot)
	else
		boundaryDetectionModule.stop()
	end
	flags["Placement"].active = not flags["Placement"].active
end)

--Mouse raycasting functions
function getMouseTargetWithWhitelist()
	local rayCastParams = RaycastParams.new()
	rayCastParams.FilterType = Enum.RaycastFilterType.Whitelist
	rayCastParams.FilterDescendantsInstances = whiteList
	
	local raycastResult = game.Workspace:Raycast(mouse.UnitRay.Origin, mouse.UnitRay.Direction * MAX_RAY_LENGTH, rayCastParams)
	
	if raycastResult ~= nil then
		return raycastResult
	end
end

--Whitelisted but hitboxes are removed from whitelist
function getMouseTargetWithBlackList()
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = filterFolder
	
	local raycastResult = game.Workspace:Raycast(mouse.UnitRay.Origin, mouse.UnitRay.Direction * MAX_RAY_LENGTH, raycastParams)

	if raycastResult ~= nil then
		return raycastResult
	end
end

RunService.RenderStepped:Connect(function()
	if flags.Transform.active == true or flags.Placement.active == true then
		if flags["Placement"].active == true then
			if flags["Placement"][1].rotate == true then
			else
				moveProp()
			end
		end
	end
end)
