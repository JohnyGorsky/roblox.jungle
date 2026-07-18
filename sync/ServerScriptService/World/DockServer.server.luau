--!strict
-- DockServer.server.luau — refuel docks along the river (Job 010).
--
-- Streams the seeded docks (RiverData.docksBetween) near the boat: a greybox plank + fuel drum at the
-- bank with a "Refuel" ProximityPrompt. Pull the boat up and hold it → the tank tops up. Server-
-- authoritative (checks the boat is actually beside the dock). Docks well behind are culled.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))

local AHEAD = 1600 -- generate docks this far ahead
local BEHIND = 400 -- cull docks this far behind
local REFUEL_RANGE = 65 -- the boat must be within this of the dock to refuel
local TICK = 0.5

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat")
local hull = boat:WaitForChild("Hull") :: BasePart
local WATER_Y = RiverData.WATER_Y

local docksRoot = Instance.new("Folder")
docksRoot.Name = "Docks"
docksRoot.Parent = Workspace

local placed: { [number]: Model } = {}

local function dockIndex(z: number): number
	return math.floor((z - RiverData.Z_START) / RiverData.DOCK_SPACING + 0.5)
end

local function buildDock(dock: RiverData.Dock, index: number)
	if placed[index] then
		return
	end
	local pos = Vector3.new(dock.x, WATER_Y, dock.z)
	local tangent = RiverData.tangentAtZ(dock.z)

	local model = Instance.new("Model")
	model.Name = "Dock"

	local deck = Instance.new("Part")
	deck.Name = "Deck"
	deck.Anchored = true
	deck.Size = Vector3.new(14, 1, 24)
	deck.Color = Color3.fromRGB(120, 85, 55)
	deck.Material = Enum.Material.WoodPlanks
	deck.CFrame = CFrame.lookAt(pos + Vector3.new(0, 1.5, 0), pos + Vector3.new(0, 1.5, 0) + tangent)
	deck.Parent = model
	model.PrimaryPart = deck

	local drum = Instance.new("Part")
	drum.Name = "FuelDrum"
	drum.Anchored = true
	drum.Shape = Enum.PartType.Cylinder
	drum.Size = Vector3.new(4, 3, 3)
	drum.Color = Color3.fromRGB(205, 60, 50)
	drum.Material = Enum.Material.Metal
	drum.CFrame = deck.CFrame * CFrame.new(0, 2.5, -7) * CFrame.Angles(0, 0, math.rad(90))
	drum.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RefuelPrompt"
	prompt.ActionText = "Refuel"
	prompt.ObjectText = "Fuel Dock"
	prompt.HoldDuration = 2
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 45
	prompt.Parent = drum
	prompt.Triggered:Connect(function()
		if (hull.Position - pos).Magnitude <= REFUEL_RANGE then
			boat:SetAttribute("Fuel", boat:GetAttribute("MaxFuel"))
		end
	end)

	-- tie / untie: holds the boat at the dock so it won't drift off while the crew is ashore
	local tie = Instance.new("ProximityPrompt")
	tie.Name = "TiePrompt"
	tie.ActionText = "Tie Boat"
	tie.ObjectText = "Dock"
	tie.HoldDuration = 0.6
	tie.RequiresLineOfSight = false
	tie.MaxActivationDistance = 45
	tie.Parent = deck
	tie.Triggered:Connect(function()
		if boat:GetAttribute("Tied") then
			hull.Anchored = false
			boat:SetAttribute("Tied", false)
			tie.ActionText = "Tie Boat"
		elseif (hull.Position - pos).Magnitude <= REFUEL_RANGE then
			hull.Anchored = true -- greybox hold; a soft rope/bob is a refinement
			boat:SetAttribute("Tied", true)
			tie.ActionText = "Untie Boat"
		end
	end)

	model.Parent = docksRoot
	placed[index] = model
end

while true do
	local boatZ = hull.Position.Z
	for _, dock in RiverData.docksBetween(boatZ - BEHIND, boatZ + AHEAD) do
		buildDock(dock, dockIndex(dock.z))
	end
	for index, model in placed do
		if boatZ - (RiverData.Z_START + index * RiverData.DOCK_SPACING) > BEHIND then
			model:Destroy()
			placed[index] = nil
		end
	end
	task.wait(TICK)
end
