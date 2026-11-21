--!strict
-- ServerScriptService/ArcadeChassisRunner.server.luau
-- Activa automáticamente ArcadeChassisController en cualquier vehículo etiquetado como "CombatVehicle"
-- que siga la jerarquía de suspensión arcade (Chassis + Wheels Folder + SpringFL/FR/RL/RR).

local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")

local ArcadeChassisController = require(ServerScriptService:WaitForChild("ArcadeChassisController"))

local function tryAttachArcadeChassis(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	-- Si ya usa motores HingeConstraint tradicionales (DriveMotors), no duplicar física
	if instance:FindFirstChild("DriveMotors") then
		return
	end
	ArcadeChassisController.Attach(instance)
end

for _, vehicle in ipairs(CollectionService:GetTagged("CombatVehicle")) do
	tryAttachArcadeChassis(vehicle)
end

CollectionService:GetInstanceAddedSignal("CombatVehicle"):Connect(tryAttachArcadeChassis)
