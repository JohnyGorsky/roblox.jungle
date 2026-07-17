--!strict
-- BoatServer.server.luau — P1 greybox physics boat.
--
-- Builds a placeholder boat at the river start and drives it with REAL forces so it
-- feels like an engine-driven boat (momentum + drift), not "hold-W-and-slide":
--   • VectorForce "Thrust"  — throttle × the hull's look-vector (world space, at CoM)
--   • VectorForce "Current" — the river pushes the boat downstream along the channel
--   • AngularVelocity "Steer" — yaw rate; linear momentum carries the boat = drift
-- Input comes from a VehicleSeat (WASD + default mobile controls; auto network-ownership).
-- Buoyancy is provided by Roblox terrain water (hull density < 1). Greybox only — the real
-- boat model + art swap in at P9. Tune the CONSTANTS for feel.
--
-- NOTE: the CENTERLINE constants below must match the river sculpt (Job 003). When the river
-- becomes shared data (P5), both the terrain and this current will read from it.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- ── tunables ─────────────────────────────────────────────────────────────
local START = Vector3.new(-91.5, 9, -430)   -- river start (terrain water surface ~ y=6)
local HULL_SIZE = Vector3.new(14, 3, 28)
local DENSITY = 0.6                           -- < 1 so the hull floats in terrain water
local THRUST = 90000                          -- forward force at full throttle
local REVERSE = 45000                         -- weaker in reverse
local TURN = 1.6                              -- yaw rad/s at full steer
local CURRENT = 20000                         -- downstream push (0 to disable)

-- river centerline: x = AMP * sin(z * FREQ)  (matches the sculpt)
local AMP = 110
local FREQ = (2 * math.pi) / 320
-- ─────────────────────────────────────────────────────────────────────────

-- Unit tangent of the channel at world-z (the "downstream" direction).
local function downstream(z: number): Vector3
	local dx = AMP * FREQ * math.cos(z * FREQ)   -- d/dz of the centerline
	return Vector3.new(dx, 0, 1).Unit
end

local function buildBoat(): Model
	local old = Workspace:FindFirstChild("Boat")
	if old then old:Destroy() end

	local model = Instance.new("Model")
	model.Name = "Boat"

	local hull = Instance.new("Part")
	hull.Name = "Hull"
	hull.Size = HULL_SIZE
	hull.Color = Color3.fromRGB(120, 85, 55)
	hull.Material = Enum.Material.WoodPlanks
	hull.CustomPhysicalProperties = PhysicalProperties.new(DENSITY, 0.3, 0.4)
	hull.CFrame = CFrame.new(START) * CFrame.Angles(0, math.pi, 0) -- face downstream (+Z)
	hull.Parent = model
	model.PrimaryPart = hull

	local att = Instance.new("Attachment")
	att.Name = "Root"
	att.Parent = hull

	-- driver seat: supplies Throttle/Steer and hands the driver network ownership
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(4, 1, 5)
	seat.Color = Color3.fromRGB(60, 45, 30)
	seat.CFrame = hull.CFrame * CFrame.new(0, 2, 0)
	seat.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hull
	weld.Part1 = seat
	weld.Parent = hull

	local thrust = Instance.new("VectorForce")
	thrust.Name = "Thrust"
	thrust.Attachment0 = att
	thrust.RelativeTo = Enum.ActuatorRelativeTo.World
	thrust.ApplyAtCenterOfMass = true
	thrust.Force = Vector3.zero
	thrust.Parent = hull

	local current = Instance.new("VectorForce")
	current.Name = "Current"
	current.Attachment0 = att
	current.RelativeTo = Enum.ActuatorRelativeTo.World
	current.ApplyAtCenterOfMass = true
	current.Force = Vector3.zero
	current.Parent = hull

	local steer = Instance.new("AngularVelocity")
	steer.Name = "Steer"
	steer.Attachment0 = att
	steer.RelativeTo = Enum.ActuatorRelativeTo.World
	steer.MaxTorque = 1e7
	steer.AngularVelocity = Vector3.zero
	steer.Parent = hull

	model.Parent = Workspace
	return model
end

local boat = buildBoat()
local hull = boat.PrimaryPart :: BasePart
local seat = boat:FindFirstChild("DriverSeat") :: VehicleSeat
local thrust = hull:FindFirstChild("Thrust") :: VectorForce
local current = hull:FindFirstChild("Current") :: VectorForce
local steer = hull:FindFirstChild("Steer") :: AngularVelocity

RunService.Heartbeat:Connect(function()
	local t = seat.Throttle -- 1 (W) / -1 (S) / 0
	local s = seat.Steer    -- 1 (D) / -1 (A) / 0
	local mag = (t >= 0) and THRUST or REVERSE
	thrust.Force = hull.CFrame.LookVector * (t * mag)
	current.Force = downstream(hull.Position.Z) * CURRENT
	steer.AngularVelocity = Vector3.new(0, -s * TURN, 0)
end)
