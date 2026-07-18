--!strict
-- StagingServer.server.luau — crash-site hub + moored-boat rope START gate (Job 016).
--
-- Inserts a STAGING phase in front of the river run (same place, phased). Players spawn at a greybox
-- crash-site hub (see PlayerCombat), the boat sits MOORED (anchored + tied) with a visible rope, and all
-- threats/progression are gated behind Workspace.RunStarted. Anyone can UNTIE the rope to start: the boat
-- is released and the run begins. Boat driving is unchanged after start.
--
-- Hand-built vs procedural (GROUND-RULES §2): the greybox hub here is a PLACEHOLDER — the human will
-- hand-build the real crash-site hub + startup river; a later job points the procedural generator at
-- HANDOFF_Z. Nothing here is hero art.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))

local WATER_Y = RiverData.WATER_Y
local HUB_Z = RiverData.Z_START + 40 -- level with the boat spawn (BoatServer: positionAt(Z_START+40))
local HUB_SIDE = 1 -- which bank the hub sits on (+X)

-- Where the hand-built startup section ends and the procedural river takes over. DOCUMENTED ONLY for now
-- (the generator still builds from Z_START this POC); a follow-up job will start procedural gen here.
local HANDOFF_Z = RiverData.Z_START + 300 -- luau: keep referenced so the intent is greppable
assert(HANDOFF_Z > RiverData.Z_START)

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat")
local hull = boat:WaitForChild("Hull") :: BasePart

-- run state: not started until someone unties
Workspace:SetAttribute("RunStarted", false)

-- moor the boat (anchored → the constant current can't drift it; claimServerOwnership early-returns on a
-- grounded assembly so this doesn't fight network ownership — same pattern as DockServer's tie)
hull.Anchored = true
boat:SetAttribute("Tied", true)

local area = Instance.new("Folder")
area.Name = "StagingArea"
area.Parent = Workspace

local function block(name: string, size: Vector3, color: Color3, cf: CFrame, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.CFrame = cf
	p.Parent = area
	return p
end

-- ---- PLACEHOLDER greybox hub (replace with the hand-built crash-site hub) ----
local centerX = RiverData.centerlineX(HUB_Z)
local waterEdgeX = centerX + HUB_SIDE * (RiverData.widthAt(HUB_Z) * 0.5)
local platformCenter = Vector3.new(waterEdgeX + HUB_SIDE * 15, WATER_Y + 2.5, HUB_Z)

block("HubPlatform", Vector3.new(36, 1, 46), Color3.fromRGB(120, 110, 92), CFrame.new(platformCenter), Enum.Material.Ground)
block(
	"PlaneWreck",
	Vector3.new(10, 7, 24),
	Color3.fromRGB(150, 150, 160),
	CFrame.new(platformCenter + Vector3.new(HUB_SIDE * 7, 4, -10)) * CFrame.Angles(0, math.rad(20), math.rad(8)),
	Enum.Material.Metal
)
-- gangway from the platform edge toward the boat
local edgePoint = Vector3.new(waterEdgeX, WATER_Y + 2.5, HUB_Z)
block("Gangway", Vector3.new(6, 0.5, 14), Color3.fromRGB(110, 80, 55), CFrame.new(edgePoint - Vector3.new(HUB_SIDE * 3, 0, 0)), Enum.Material.WoodPlanks)

-- pull the moored boat up ALONGSIDE the pier (it spawns mid-channel). Translate only — keep the boat's
-- heading so BoatServer's captured desiredYaw stays valid and it won't snap-rotate when released.
local mooredPos = Vector3.new(waterEdgeX - HUB_SIDE * (hull.Size.X / 2 + 2), WATER_Y + 2, HUB_Z)
local rotOnly = hull.CFrame - hull.CFrame.Position
boat:PivotTo(CFrame.new(mooredPos) * rotOnly)

-- hub spawn point (read by PlayerCombat before the run starts)
local spawnPos = platformCenter + Vector3.new(0, 3, 0)
Workspace:SetAttribute("HubSpawn", spawnPos)

-- mooring post at the water edge + rope hull→post (lifted from DockServer's tie)
local post = block("MooringPost", Vector3.new(1.6, 5, 1.6), Color3.fromRGB(90, 60, 40), CFrame.new(edgePoint + Vector3.new(0, 2, 0)), Enum.Material.Wood)
local a0 = Instance.new("Attachment")
a0.Parent = hull
local a1 = Instance.new("Attachment")
a1.Parent = post -- parent first, then set world position
a1.WorldPosition = post.Position + Vector3.new(0, 1, 0)
local rope = Instance.new("RopeConstraint")
rope.Attachment0 = a0
rope.Attachment1 = a1
rope.Length = (a0.WorldPosition - a1.WorldPosition).Magnitude + 2
rope.Thickness = 0.15
rope.Visible = true
rope.Color = BrickColor.new("Brown")
rope.Parent = hull

-- untie = START (anyone can trigger it)
local prompt = Instance.new("ProximityPrompt")
prompt.Name = "UntiePrompt"
prompt.ActionText = "Untie rope — START"
prompt.ObjectText = "Mooring"
prompt.HoldDuration = 0.8
prompt.RequiresLineOfSight = false
prompt.MaxActivationDistance = 22
prompt.Parent = post

local started = false
local function startRun(_player: Player?)
	if started then
		return
	end
	started = true
	Workspace:SetAttribute("RunStarted", true)
	hull.Anchored = false
	boat:SetAttribute("Tied", false)
	rope:Destroy()
	a0:Destroy()
	a1:Destroy()
	Workspace:SetAttribute("HubSpawn", nil)
	area:Destroy() -- tear down the placeholder hub; from now on respawns land on the boat
	print("[Staging] rope untied — RUN STARTED")
end
prompt.Triggered:Connect(startRun)

-- boat-occupancy readout while staging: "N/M on boat" (published as Boat attributes for the client HUD)
task.spawn(function()
	while not started do
		local half = hull.Size * 0.5
		local onBoat = 0
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local lp = hull.CFrame:PointToObjectSpace(root.Position)
				-- oriented box around the hull, expanded to include the welded back cargo deck (+local Z)
				if math.abs(lp.X) < half.X + 4 and lp.Z < half.Z + 20 and lp.Z > -(half.Z + 4) and math.abs(lp.Y) < 9 then
					onBoat += 1
				end
			end
		end
		boat:SetAttribute("OnBoatCount", onBoat)
		boat:SetAttribute("CrewCount", #Players:GetPlayers())
		task.wait(0.4)
	end
end)

print("[Staging] crash-site hub + moored boat online (untie to start)")
