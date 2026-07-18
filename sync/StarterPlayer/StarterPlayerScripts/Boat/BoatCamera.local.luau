--!strict
-- BoatCamera.local.luau — chase cam for the greybox boat (Job 003).
--
-- Activates ONLY while the local player sits in the Boat's DriverSeat; restores the default camera
-- on dismount. Follows behind+above the hull with look-ahead along velocity, a collision-aware
-- pull-in, speed-based FOV, and a decaying-trauma shake hook. Runs at RenderPriority.Camera with
-- frame-rate-independent smoothing (1 - exp(-k·dt)), per the roblox-camera skill.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local BIND = "BoatCam"
local FOLLOW_DIST = 24
local FOLLOW_HEIGHT = 9
local LOOK_AHEAD = 8
local SMOOTH_K = 6

local hull: BasePart? = nil
local currentPos = Vector3.zero
local trauma = 0

local function isBoatSeat(seat: Instance?): boolean
	if not seat or not seat:IsA("VehicleSeat") then return false end
	if seat.Name ~= "DriverSeat" then return false end
	local parent = seat.Parent
	return parent ~= nil and parent.Name == "Boat"
end

local function update(dt: number)
	local h = hull
	if not h or not h.Parent then return end
	local camera = Workspace.CurrentCamera
	if not camera then return end

	local pos, vel = h.Position, h.AssemblyLinearVelocity
	local flat = Vector3.new(vel.X, 0, vel.Z)
	local ahead = flat.Magnitude > 1 and flat.Unit or h.CFrame.LookVector
	local target = pos + ahead * LOOK_AHEAD
	local desired = pos - h.CFrame.LookVector * FOLLOW_DIST + Vector3.new(0, FOLLOW_HEIGHT, 0)

	-- collision-aware: don't clip through terrain/banks between the boat and the camera
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local filter: { Instance } = { h.Parent :: Instance }
	if player.Character then
		table.insert(filter, player.Character)
	end
	rp.FilterDescendantsInstances = filter
	local hit = Workspace:Raycast(pos, desired - pos, rp)
	if hit then
		desired = hit.Position + (pos - desired).Unit * 1.5
	end

	currentPos = currentPos:Lerp(desired, 1 - math.exp(-SMOOTH_K * dt))
	local cf = CFrame.lookAt(currentPos, target)

	if trauma > 0 then
		local s = trauma * trauma
		local a = math.rad(6) * s
		cf = cf * CFrame.Angles(
			(math.random() * 2 - 1) * a,
			(math.random() * 2 - 1) * a,
			(math.random() * 2 - 1) * a
		)
		trauma = math.max(0, trauma - dt * 1.5)
	end

	camera.CFrame = cf
	camera.Focus = CFrame.new(target)
	camera.FieldOfView = 70 + math.clamp(flat.Magnitude / 8, 0, 15)
end

local function startCam(h: BasePart)
	hull = h
	local camera = Workspace.CurrentCamera
	if camera then
		currentPos = camera.CFrame.Position
		camera.CameraType = Enum.CameraType.Scriptable
	end
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value, update)
end

local function stopCam()
	if hull == nil then return end
	hull = nil
	pcall(function()
		RunService:UnbindFromRenderStep(BIND)
	end)
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
	end
end

local function onCharacter(char: Model)
	local humanoid = char:WaitForChild("Humanoid") :: Humanoid
	humanoid.Seated:Connect(function(active: boolean, seat: Seat?)
		if not (active and seat and isBoatSeat(seat)) then
			stopCam()
			return
		end
		local model = seat.Parent
		if not (model and model:IsA("Model")) then
			return
		end
		local h = model.PrimaryPart or model:FindFirstChild("Hull")
		if h and h:IsA("BasePart") then
			startCam(h)
		end
	end)
end

if player.Character then
	onCharacter(player.Character)
end
player.CharacterAdded:Connect(onCharacter)
