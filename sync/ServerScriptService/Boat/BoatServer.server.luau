--!strict
-- BoatServer.server.luau — P1 greybox physics boat.
--
-- Builds a placeholder boat at the river start and drives it with REAL forces so it feels
-- like an engine-driven boat (momentum + drift), not "hold-W-and-slide":
--   • Buoyancy  — a spring force floats the hull at the water line (deterministic; does NOT
--                 rely on terrain-water buoyancy, which let the boat sink/fall through).
--   • Thrust    — VectorForce = throttle × hull look-vector (world; at CoM).
--   • Current   — VectorForce pushing downstream along the winding channel.
--   • Drag      — VectorForce opposing horizontal velocity → a finite top speed + engine feel.
--   • Steer     — AngularVelocity yaw; linear momentum carries the boat = drift.
--   • Upright   — AlignOrientation (PrimaryAxisOnly) keeps the hull level (anti-capsize) while
--                 leaving yaw free for the steer, per the roblox-physics boat recipe.
-- Input: a VehicleSeat (WASD + default mobile controls; ThrottleFloat/SteerFloat replicate to the
-- server regardless of physics ownership).
-- Authority: SERVER-OWNED. The VehicleSeat auto-hands ownership to the driver on sit; we re-assert
--   SetNetworkOwner(nil) so this server loop reads accurate (un-lagged) Position/velocity and stays
--   exploit-resistant for co-op (decided in Job 003 review, 2026-07-18).
-- Greybox only — real boat model/art swap in at P9. Tune the CONSTANTS for feel.
--
-- NOTE: WATER_Y + centerline (AMP/FREQ) must match the river sculpt (Job 003). When the river
-- becomes shared data (P5) both the terrain and this will read from it.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- ── tunables ─────────────────────────────────────────────────────────────
local WATER_Y = 12
local START = Vector3.new(-91.5, WATER_Y + 4, -430)  -- river start
local HULL_SIZE = Vector3.new(14, 3, 28)
local DENSITY = 0.7
local THRUST = 120000        -- forward force at full throttle
local REVERSE = 60000
local TURN = 1.6             -- yaw rad/s at full steer
local CURRENT = 22000        -- downstream push (0 to disable)
local DRAG = 2200            -- horizontal velocity damping → top speed ≈ THRUST/DRAG
local FLOAT_K = 8            -- buoyancy spring stiffness
local FLOAT_D = 3            -- buoyancy damping
local LEVEL_TORQUE = 4e6     -- upright (anti-capsize) torque cap
local LEVEL_RESP = 25        -- upright responsiveness (5..200)

local AMP = 110              -- river centerline: x = AMP * sin(z * FREQ)
local FREQ = (2 * math.pi) / 320
-- ─────────────────────────────────────────────────────────────────────────

local function downstream(z: number): Vector3
	local dx = AMP * FREQ * math.cos(z * FREQ)
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

	-- force/velocity anchor at the hull center of mass
	local att = Instance.new("Attachment")
	att.Name = "Root"
	att.Parent = hull

	-- primary axis points along hull-up so AlignOrientation(PrimaryAxisOnly) can hold it level
	local upAtt = Instance.new("Attachment")
	upAtt.Name = "UpAxis"
	upAtt.CFrame = CFrame.Angles(0, 0, math.pi / 2) -- rotate local +X onto hull +Y (up)
	upAtt.Parent = hull

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

	local function force(name: string): VectorForce
		local f = Instance.new("VectorForce")
		f.Name = name
		f.Attachment0 = att
		f.RelativeTo = Enum.ActuatorRelativeTo.World
		f.ApplyAtCenterOfMass = true
		f.Force = Vector3.zero
		f.Parent = hull
		return f
	end
	force("Buoy")
	force("Thrust")
	force("Current")
	force("Drag")

	local steer = Instance.new("AngularVelocity")
	steer.Name = "Steer"
	steer.Attachment0 = att
	steer.RelativeTo = Enum.ActuatorRelativeTo.World
	steer.MaxTorque = 1e7
	steer.AngularVelocity = Vector3.zero
	steer.Parent = hull

	-- keep the hull upright (roll/pitch) without touching yaw → no fight with the steer
	local level = Instance.new("AlignOrientation")
	level.Name = "Level"
	level.Mode = Enum.OrientationAlignmentMode.OneAttachment
	level.Attachment0 = upAtt
	level.PrimaryAxisOnly = true
	level.RigidityEnabled = false
	level.MaxTorque = LEVEL_TORQUE
	level.Responsiveness = LEVEL_RESP
	level.CFrame = CFrame.Angles(0, 0, math.pi / 2) -- target primary axis = world up
	level.Parent = hull

	model.Parent = Workspace
	return model
end

local boat = buildBoat()
local hull = boat.PrimaryPart :: BasePart
local seat = boat:FindFirstChild("DriverSeat") :: VehicleSeat
local buoy = hull:FindFirstChild("Buoy") :: VectorForce
local thrust = hull:FindFirstChild("Thrust") :: VectorForce
local current = hull:FindFirstChild("Current") :: VectorForce
local drag = hull:FindFirstChild("Drag") :: VectorForce
local steer = hull:FindFirstChild("Steer") :: AngularVelocity

-- SERVER-OWNED physics. VehicleSeat hands ownership to the driver on sit; re-assert server ownership
-- so this loop reads accurate state and stays authoritative.
local function claimServerOwnership()
	if hull:IsGrounded() then return end
	local ok = pcall(function()
		hull:SetNetworkOwner(nil)
	end)
	if not ok then
		-- assembly not simulated yet this frame; retry next step
		task.defer(function()
			pcall(function()
				hull:SetNetworkOwner(nil)
			end)
		end)
	end
end
claimServerOwnership()
seat:GetPropertyChangedSignal("Occupant"):Connect(claimServerOwnership)

RunService.Heartbeat:Connect(function()
	local pos = hull.Position
	local vel = hull.AssemblyLinearVelocity
	local mass = hull.AssemblyMass
	local g = Workspace.Gravity

	-- buoyancy: hold the hull at the water line with a spring-damper (only near/below surface)
	if pos.Y < WATER_Y + 5 then
		local spring = mass * ((WATER_Y - pos.Y) * FLOAT_K - vel.Y * FLOAT_D)
		buoy.Force = Vector3.new(0, math.max(mass * g + spring, 0), 0)
	else
		buoy.Force = Vector3.zero
	end

	-- drive
	local t = seat.Throttle -- 1 (W) / -1 (S) / 0
	local s = seat.Steer    -- 1 (D) / -1 (A) / 0
	thrust.Force = hull.CFrame.LookVector * (t * ((t >= 0) and THRUST or REVERSE))
	current.Force = downstream(pos.Z) * CURRENT
	drag.Force = Vector3.new(-vel.X * DRAG, 0, -vel.Z * DRAG) -- horizontal only; Y left to buoyancy
	steer.AngularVelocity = Vector3.new(0, -s * TURN, 0)
end)

print(("[Boat] built at %s (water y=%d, server-owned)"):format(tostring(START), WATER_Y))
