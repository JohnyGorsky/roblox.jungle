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
--   • Steer     — RUDDER model: yaw rate scales with forward speed, so you must be MOVING to turn
--                 (no tank-spin-in-place) and momentum carries the hull through the bend = drift.
--                 Reverse flips the rudder, like a real boat.
--   • Upright   — AlignOrientation (PrimaryAxisOnly) keeps the hull level (anti-capsize) while
--                 leaving yaw free for the steer, per the roblox-physics boat recipe.
-- Input: a VehicleSeat (WASD + default mobile controls; ThrottleFloat/SteerFloat replicate to the
-- server regardless of physics ownership).
-- Authority: SERVER-OWNED. The VehicleSeat auto-hands ownership to the driver on sit; we re-assert
--   SetNetworkOwner(nil) so this server loop reads accurate (un-lagged) Position/velocity and stays
--   exploit-resistant for co-op (decided in Job 003 review, 2026-07-18).
-- Greybox only — real boat model/art swap in at P9. Tune the CONSTANTS for feel.
--
-- NOTE: WATER_Y + CENTERLINE were measured from the actual river sculpt via voxel read-back
-- (Job 003 review, 2026-07-18). If the terrain is re-generated, re-measure and update these. When
-- the river becomes shared data (P5) both the terrain and this will read from it.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- ── tunables ─────────────────────────────────────────────────────────────
local WATER_Y = 12           -- spring target for hull CENTER ≈ true water surface (voxel top ≈ 11.9),
                             -- so our buoyancy cooperates with terrain-water buoyancy instead of fighting it
local HULL_SIZE = Vector3.new(14, 3, 28)
local DENSITY = 0.7
-- Speed knobs. Top speed ≈ THRUST/DRAG, idle downstream drift ≈ CURRENT/DRAG. THRUST is the natural
-- target for a future "boat speed upgrade" (multiply it — e.g. THRUST * speedTier — for a faster engine).
local THRUST = 90000         -- forward force at full throttle → top speed ≈ 45 studs/s
local REVERSE = 45000
local TURN = 1.6             -- max yaw rad/s (only reached at/above TURN_FULL_SPEED)
local TURN_FULL_SPEED = 22   -- forward speed (studs/s) for full rudder authority; less speed = less turn
local CURRENT = 16000        -- downstream push (0 to disable) → idle drift ≈ 8 studs/s
local DRAG = 2000            -- horizontal velocity damping → top speed ≈ THRUST/DRAG
local FLOAT_K = 8            -- buoyancy spring stiffness
local FLOAT_D = 3            -- buoyancy damping
local LEVEL_TORQUE = 4e6     -- upright (anti-capsize) torque cap
local LEVEL_RESP = 25        -- upright responsiveness (5..200)

-- river centerline sampled from the sculpt as {z, x}, upstream → downstream (measured from the
-- water voxels; only points that are actually wet — the very upstream rim at z<-260 is dry grass)
local CENTERLINE: { { number } } = {
	{ -260, 38 }, { -240, 37 }, { -220, 40 }, { -200, 41 }, { -180, 45 },
	{ -160, 50 }, { -140, 54 }, { -120, 60 }, { -100, 65 }, { -80, 70 },
	{ -60, 72 }, { -40, 75 }, { -20, 75 }, { 0, 75 }, { 20, 71 },
	{ 40, 62 }, { 60, 48 }, { 80, 31 }, { 100, 14 }, { 120, -3 },
	{ 140, -16 }, { 160, -23 }, { 180, -24 }, { 200, -20 }, { 220, -11 },
	{ 240, 1 }, { 260, 11 }, { 280, 20 }, { 300, 11 },
}
-- spawn a touch downstream of the upstream rim so the hull starts fully over water, just above surface
local START = Vector3.new(37, WATER_Y + 2, -240)
-- ─────────────────────────────────────────────────────────────────────────

-- unit downstream tangent of the centerline segment containing z (clamped to the sampled range)
local function downstream(z: number): Vector3
	local a, b = CENTERLINE[1], CENTERLINE[2]
	for i = 1, #CENTERLINE - 1 do
		if z <= CENTERLINE[i + 1][1] then
			a, b = CENTERLINE[i], CENTERLINE[i + 1]
			break
		end
		a, b = CENTERLINE[#CENTERLINE - 1], CENTERLINE[#CENTERLINE]
	end
	return Vector3.new(b[2] - a[2], 0, b[1] - a[1]).Unit
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
	hull.CFrame = CFrame.lookAt(START, START + downstream(START.Z)) -- face downstream
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
	local look = hull.CFrame.LookVector
	local t = seat.Throttle -- 1 (W) / -1 (S) / 0
	local s = seat.Steer    -- 1 (D) / -1 (A) / 0
	thrust.Force = look * (t * ((t >= 0) and THRUST or REVERSE))
	current.Force = downstream(pos.Z) * CURRENT
	drag.Force = Vector3.new(-vel.X * DRAG, 0, -vel.Z * DRAG) -- horizontal only; Y left to buoyancy

	-- rudder: turn authority ∝ signed forward speed (0 when stopped; reverse flips it)
	local fwdSpeed = vel:Dot(look)
	local authority = math.clamp(fwdSpeed / TURN_FULL_SPEED, -1, 1)
	steer.AngularVelocity = Vector3.new(0, -s * TURN * authority, 0)
end)

print(("[Boat] built at %s (water y=%d, server-owned)"):format(tostring(START), WATER_Y))
