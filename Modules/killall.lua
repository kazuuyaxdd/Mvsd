local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local Replicated = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local throwStartRemote = Replicated.Remotes:WaitForChild("ThrowStart")
local throwHitRemote = Replicated.Remotes:WaitForChild("ThrowHit")
local shootRemote = Replicated.Remotes:WaitForChild("ShootGun")
local WEAPON_TYPE = { gun = "Gun_Equip", knife = "Knife_Equip" }

local localPlayer = Players.LocalPlayer
local lock = { gun = false, knife = false }
local enemyCache = {}

function updateCache()
	enemyCache = {}
	for _, enemy in pairs(Players:GetPlayers()) do
		task.spawn(function()
			if enemy and enemy ~= localPlayer and enemy.Team and enemy.Team ~= localPlayer.Team then
				if enemy.Character and enemy.Character.Parent == Workspace then
					local targetPart = enemy.Character:FindFirstChild("HumanoidRootPart")
					if targetPart then
						enemyCache[enemy] = targetPart
					end
				end
			end
		end)
	end
end

local function equipWeapon(weaponType)
	local backpack = localPlayer.Backpack
	local character = localPlayer.Character
	if not character or not backpack then
		return false
	end

	for _, tool in pairs(backpack:GetChildren()) do
		if tool:GetAttribute("EquipAnimation") == weaponType then
			character.Humanoid:EquipTool(tool)
			return true
		end
	end
	return false
end

local function killAllKnife()
	local character = localPlayer.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	for _, part in pairs(enemyCache) do
		task.spawn(function()
			if part then
				local origin = hrp.Position
				local direction = (part.Position - origin).Unit
				throwStartRemote:FireServer(origin, direction)
				throwHitRemote:FireServer(part, part.Position)
			end
		end)
	end
end

local function killAllGun()
	local character = localPlayer.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	for _, part in pairs(enemyCache) do
		task.spawn(function()
			if part then
				shootRemote:FireServer(hrp.Position, part.Position, part, part.Position)
			end
		end)
	end
end

if localPlayer.Character then updateCache() end

local Connections = {}

-- Кнопка KillAll теперь работает всегда (не важно держишь предмет или нет)
Connections[0] = Run.Heartbeat:Connect(function()
	if getgenv().killButton.knife then
		equipWeapon(WEAPON_TYPE.knife) -- всегда экипаем
		killAllKnife()
		getgenv().killButton.knife = false
	end

	if getgenv().killButton.gun then
		equipWeapon(WEAPON_TYPE.gun) -- всегда экипаем
		killAllGun()
		getgenv().killButton.gun = false
	end
end)

Connections[1] = Run.Heartbeat:Connect(updateCache)

-- Loop KillAll теперь сам следит, чтобы оружие держалось в руках
Connections[2] = Run.RenderStepped:Connect(function()
	local char = localPlayer.Character
	if not char then return end

	if getgenv().killLoop.gun and not lock.gun then
		if not char:FindFirstChildOfClass("Tool") or char:FindFirstChildOfClass("Tool"):GetAttribute("EquipAnimation") ~= WEAPON_TYPE.gun then
			equipWeapon(WEAPON_TYPE.gun)
		end
		killAllGun()
	end

	if getgenv().killLoop.knife and not lock.knife then
		if not char:FindFirstChildOfClass("Tool") or char:FindFirstChildOfClass("Tool"):GetAttribute("EquipAnimation") ~= WEAPON_TYPE.knife then
			equipWeapon(WEAPON_TYPE.knife)
		end
		killAllKnife()
	end
end)

Connections[3] = localPlayer.CharacterAdded:Connect(function()
	local character = localPlayer.Character
	if not character then return end

	lock.gun = true
	lock.knife = true

	if getgenv().killLoop.gun then
		equipWeapon(WEAPON_TYPE.gun)
	elseif getgenv().killLoop.knife then
		equipWeapon(WEAPON_TYPE.knife)
	end

	local hrp = character:WaitForChild("HumanoidRootPart", 3)
	if not hrp or not localPlayer:GetAttribute("Match") then return end

	local anchoredConnection
	anchoredConnection = hrp:GetPropertyChangedSignal("Anchored"):Connect(function()
		if not hrp.Anchored then
			if getgenv().killLoop.gun then
				lock.gun = false
			elseif getgenv().killLoop.knife then
				lock.knife = false
			end
			if anchoredConnection then anchoredConnection:Disconnect() end
		end
	end)
end)

return Connections
