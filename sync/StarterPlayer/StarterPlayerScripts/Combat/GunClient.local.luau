--!strict
-- GunClient.local.luau — man the mounted gun (Job 014).
-- Sit in the GunSeat → an over-the-gun aiming CAMERA + mouse aims within the arc (sends clamped
-- yaw/pitch to the server, which rotates the barrel + fires). Click/tap = fire. Crosshair while manning.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local aimRemote = ReplicatedStorage:WaitForChild("GunAim") :: UnreliableRemoteEvent
local fireRemote = ReplicatedStorage:WaitForChild("GunFire") :: RemoteEvent

local YAW_LIMIT = math.rad(80)
local PITCH_MIN, PITCH_MAX = math.rad(-12), math.rad(35)
local SENS = 0.006
local BIND = "GunCam"

local seated = false
local yaw, pitch = 0, 0

-- crosshair
local gui = Instance.new("ScreenGui")
gui.Name = "GunGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
local dot = Instance.new("Frame")
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.Size = UDim2.fromOffset(10, 10)
dot.BackgroundColor3 = Color3.fromRGB(255, 90, 70)
dot.BackgroundTransparency = 0.1
dot.BorderSizePixel = 0
local c = Instance.new("UICorner")
c.CornerRadius = UDim.new(1, 0)
c.Parent = dot
dot.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

local function gunBase(): BasePart?
	local boat = Workspace:FindFirstChild("Boat")
	local b = boat and boat:FindFirstChild("GunBase")
	return if b and b:IsA("BasePart") then b else nil
end

local function update()
	local base = gunBase()
	local cam = Workspace.CurrentCamera
	if not base or not cam then
		return
	end
	local aim = base.CFrame * CFrame.Angles(pitch, yaw, 0)
	local camPos = aim.Position - aim.LookVector * 7 + aim.UpVector * 3
	cam.CFrame = CFrame.lookAt(camPos, aim.Position + aim.LookVector * 60)
	cam.Focus = CFrame.new(aim.Position + aim.LookVector * 60)
end

UserInputService.InputChanged:Connect(function(input: InputObject)
	if not seated or input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	yaw = math.clamp(yaw - input.Delta.X * SENS, -YAW_LIMIT, YAW_LIMIT)
	pitch = math.clamp(pitch - input.Delta.Y * SENS, PITCH_MIN, PITCH_MAX)
	aimRemote:FireServer(yaw, pitch)
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if not seated or gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		fireRemote:FireServer()
	end
end)

local function startGunner()
	seated = true
	yaw, pitch = 0, 0
	gui.Enabled = true
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value, update)
end

local function stopGunner()
	if not seated then
		return
	end
	seated = false
	gui.Enabled = false
	pcall(function()
		RunService:UnbindFromRenderStep(BIND)
	end)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end

local function onCharacter(char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	hum.Seated:Connect(function(active: boolean, seatPart: Seat?)
		if active and seatPart and seatPart.Name == "GunSeat" then
			startGunner()
		else
			stopGunner()
		end
	end)
end

if player.Character then
	onCharacter(player.Character)
end
player.CharacterAdded:Connect(onCharacter)
