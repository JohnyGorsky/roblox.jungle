--!strict
-- CargoServer.server.luau — towed trailer (cargo hold) + on-boat fuel/repair stations (Job 013).
--
-- A greybox trailer follows behind the boat (roped) and holds looted cargo: Gasoline, Metal, Ammo
-- (counts, up to CargoMax). Two stations on the boat SPEND that cargo — like feeding the Dead Rails
-- firebox: FUEL station (1 gasoline → refuel the tank) and REPAIR station (1 metal → mend the hull).
-- Ammo is drawn by the weapon (WeaponServer). Server-authoritative. Kinematic tow (greybox); a real
-- physics-tow is a refinement.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))

local TRAILER_SIZE = Vector3.new(12, 2, 14)
local GAP = 9 -- studs between the boat's stern and the trailer
local CARGO_MAX = 10 -- total cargo crates the trailer holds (gamepass raises this later)
local FUEL_PER_GAS = 40 -- tank refill per gasoline crate
local REPAIR_PER_METAL = 25 -- hull HP restored per metal crate
local FOLLOW_K = 6 -- tow lag (lower = more swing/drag)

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat")
local hull = boat:WaitForChild("Hull") :: BasePart
local WATER_Y = RiverData.WATER_Y
-- distance from hull CENTRE to trailer CENTRE = half the hull + the gap + half the trailer
-- (boat faces -Z, so the stern/behind is +Z local)
local TOW_OFFSET = hull.Size.Z / 2 + GAP + TRAILER_SIZE.Z / 2

-- ── the trailer (cargo hold) ────────────────────────────────────────────────
local trailer = Instance.new("Part")
trailer.Name = "Trailer"
trailer.Size = TRAILER_SIZE
trailer.Color = Color3.fromRGB(110, 78, 50)
trailer.Material = Enum.Material.WoodPlanks
trailer.Anchored = true
trailer.CanCollide = false
trailer.CFrame = hull.CFrame * CFrame.new(0, 0, TOW_OFFSET)
trailer:SetAttribute("Gasoline", 0)
trailer:SetAttribute("Metal", 0)
trailer:SetAttribute("Ammo", 3) -- start with a little ammo (crates); WeaponServer reloads rounds from these
trailer:SetAttribute("Rounds", 0) -- loaded rounds
trailer:SetAttribute("CargoMax", CARGO_MAX)
trailer.Parent = Workspace

-- visible tow rope, boat stern → trailer front (boat faces -Z, so the stern is +Z)
local a0 = Instance.new("Attachment")
a0.Position = Vector3.new(0, 0, hull.Size.Z / 2)
a0.Parent = hull
local a1 = Instance.new("Attachment")
a1.Parent = trailer
a1.Position = Vector3.new(0, 1, -TRAILER_SIZE.Z / 2)
local rope = Instance.new("RopeConstraint")
rope.Attachment0, rope.Attachment1 = a0, a1
rope.Visible = true
rope.Color = BrickColor.new("Brown")
rope.Thickness = 0.2
rope.Length = GAP + 1
rope.Parent = hull

-- kinematic tow: trail behind the boat on the water, with a little lag for swing
RunService.Heartbeat:Connect(function(dt: number)
	if not hull.Parent then
		return
	end
	local yaw = select(2, hull.CFrame:ToOrientation())
	local target = hull.CFrame * CFrame.new(0, 0, TOW_OFFSET)
	local goal = Vector3.new(target.Position.X, WATER_Y, target.Position.Z)
	local newPos = trailer.Position:Lerp(goal, 1 - math.exp(-FOLLOW_K * dt))
	trailer.CFrame = CFrame.new(newPos) * CFrame.Angles(0, yaw, 0)
end)

-- ── on-boat stations ────────────────────────────────────────────────────────
local function makeStation(name: string, localCF: CFrame, color: Color3, actionText: string): ProximityPrompt
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(3, 3, 3)
	p.Color = color
	p.Material = Enum.Material.Metal
	p.CanCollide = false
	p.Massless = true
	p.CFrame = hull.CFrame * localCF
	p.Parent = boat
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hull
	weld.Part1 = p
	weld.Parent = p
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name .. "Prompt"
	prompt.ActionText = actionText
	prompt.ObjectText = name
	prompt.HoldDuration = 1.2
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 9
	prompt.Parent = p
	return prompt
end

-- FUEL station: spend 1 gasoline → refuel
makeStation("Fuel Station", CFrame.new(-4, 2, -9), Color3.fromRGB(240, 190, 60), "Refuel").Triggered:Connect(function()
	if (trailer:GetAttribute("Gasoline") :: number? or 0) > 0 then
		trailer:SetAttribute("Gasoline", (trailer:GetAttribute("Gasoline") :: number) - 1)
		local maxF = (boat:GetAttribute("MaxFuel") :: number?) or 100
		boat:SetAttribute("Fuel", math.min(maxF, ((boat:GetAttribute("Fuel") :: number?) or 0) + FUEL_PER_GAS))
	end
end)

-- REPAIR station: spend 1 metal → mend the hull
makeStation("Repair Station", CFrame.new(4, 2, -9), Color3.fromRGB(120, 200, 130), "Repair").Triggered:Connect(function()
	if (trailer:GetAttribute("Metal") :: number? or 0) > 0 then
		trailer:SetAttribute("Metal", (trailer:GetAttribute("Metal") :: number) - 1)
		local maxH = (boat:GetAttribute("MaxHP") :: number?) or 100
		boat:SetAttribute("HP", math.min(maxH, ((boat:GetAttribute("HP") :: number?) or 0) + REPAIR_PER_METAL))
	end
end)

print("[Cargo] trailer + fuel/repair stations online")
