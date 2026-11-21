local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponModels = ReplicatedStorage:WaitForChild("WeaponModels")
local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))

local WeaponMountService = {}

-- Prepara las físicas del modelo del arma para no desestabilizar el auto
local function prepareWeaponPhysics(weaponModel: Model)
	for _, descendant in ipairs(weaponModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true -- Vital para evitar que el auto vuelque
		end
	end
end

-- Elimina un arma previa si ya existe algo en ese punto de anclaje
function WeaponMountService.UnmountWeapon(vehicleModel: Model, mountPointName: string)
	local equippedFolder = vehicleModel:FindFirstChild("EquippedWeapons")
	if not equippedFolder then
		return
	end

	local existingWeapon = equippedFolder:FindFirstChild(mountPointName)
	if existingWeapon then
		existingWeapon:Destroy()
	end
end

-- Ensambla el arma en el Attachment correspondiente
function WeaponMountService.EquipWeapon(vehicleModel: Model, weaponId: string): boolean
	local config = WeaponConfig[weaponId]
	if not config then
		warn("[WeaponMountService] Arma no encontrada en config:", weaponId)
		return false
	end

	local chassis = vehicleModel.PrimaryPart or vehicleModel:FindFirstChild("Chassis") :: BasePart?
	if not chassis or not chassis:IsA("BasePart") then
		warn("[WeaponMountService] El vehículo no tiene Chassis/PrimaryPart definido.")
		return false
	end

	-- Buscar el Attachment en el chasis (ej. "RoofMount")
	local mountAttachment = chassis:FindFirstChild(config.MountPoint)
	if not mountAttachment or not mountAttachment:IsA("Attachment") then
		warn("[WeaponMountService] Falta el Attachment:", config.MountPoint, "en", vehicleModel.Name)
		return false
	end

	local templateModel = WeaponModels:FindFirstChild(weaponId)
	if not templateModel or not templateModel:IsA("Model") then
		warn("[WeaponMountService] Falta el modelo 3D en WeaponModels:", weaponId)
		return false
	end

	-- 1. Limpiar el espacio si ya había un arma en ese soporte
	WeaponMountService.UnmountWeapon(vehicleModel, config.MountPoint)

	-- 2. Crear carpeta contenedora dentro del vehículo si no existe
	local equippedFolder = vehicleModel:FindFirstChild("EquippedWeapons") :: Folder?
	if not equippedFolder then
		equippedFolder = Instance.new("Folder")
		equippedFolder.Name = "EquippedWeapons"
		equippedFolder.Parent = vehicleModel
	end

	-- 3. Clonar y preparar físicas
	local newWeapon = templateModel:Clone()
	newWeapon.Name = config.MountPoint -- Se nombra por el soporte para fácil reemplazo
	newWeapon:SetAttribute("WeaponId", weaponId)
	newWeapon:SetAttribute("Ammo", config.MaxAmmo)
	prepareWeaponPhysics(newWeapon)

	-- 4. Posicionar usando WorldCFrame del Attachment
	local primaryPart = newWeapon.PrimaryPart
	if not primaryPart then
		warn("[WeaponMountService] El modelo", weaponId, "no tiene PrimaryPart asignado.")
		newWeapon:Destroy()
		return false
	end

	newWeapon:PivotTo(mountAttachment.WorldCFrame)
	newWeapon.Parent = equippedFolder

	-- 5. Soldar la base del arma (y subpiezas) al Chassis del vehículo
	for _, part in ipairs(newWeapon:GetDescendants()) do
		if part:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "WeaponMountWeld"
			weld.Part0 = chassis
			weld.Part1 = part
			weld.Parent = part
		end
	end

	return true
end

return WeaponMountService
