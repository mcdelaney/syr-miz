local lfs = require("lfs")
MODULE_FOLDER = lfs.writedir()..[[Scripts\syr-miz\]]
package.path = MODULE_FOLDER .. "?.lua;" .. package.path
local utils = require('utils')


local function deployGroundForcesByPlane(targetBase)

    local dest_coord = AIRBASE:FindByName(targetBase):GetCoordinate()
    local incirlik = dest_coord:Get2DDistance(AIRBASE:FindByName("Incirlik"):GetCoordinate())
    local ramat = dest_coord:Get2DDistance(AIRBASE:FindByName("Ramat David"):GetCoordinate())

    local departureBase = "Incirlik"
    if (ramat < incirlik ) then
        departureBase = "Ramat David"
    end

    BlueCargoPlaneDeployZone:AddZone( ZONE_AIRBASE:New( targetBase ) )

    GroundGroup = SPAWN:New( "blue-ground-plane-spawn" )
        :InitRandomizeZones( { ZONE:FindByName("logizone-"..departureBase) } )
        :OnSpawnGroup(
            function( SpawnGroup )
                CARGO_GROUP:New(SpawnGroup, "Heavy", SpawnGroup:GetName(), 5000, 500)
            end
        )
        :Spawn()

    Plane = SPAWN:New("blue-cargo-plane")
        :InitUnControlled(true)
        :SpawnAtAirbase( AIRBASE:FindByName( departureBase ),
                     SPAWN.Takeoff.Parking)
    MESSAGE:NewType("Deploying ground forces from "..departureBase.." to "..targetBase, MESSAGE.Type.Information):ToAll()
end


local function deployGroundForcesByHeli(targetBase)
    local dest_coord = AIRBASE:FindByName(targetBase):GetCoordinate()
    local hama = dest_coord:Get2DDistance(AIRBASE:FindByName("Hama"):GetCoordinate())
    local ramat = dest_coord:Get2DDistance(AIRBASE:FindByName("Ramat David"):GetCoordinate())

    local departureBase = "Hama"
    if (ramat < hama ) then
        departureBase = "Ramat David"
    end

    BlueCargoHeliDeployZone:AddZone( ZONE_AIRBASE:New( targetBase ) )

    GroundGroup = SPAWN:New( "blue-ground-heli-spawn" )
        :InitRandomizeZones( { ZONE:FindByName("logizone-"..departureBase) } )
        :OnSpawnGroup(
            function( SpawnGroup )
                CARGO_GROUP:New(SpawnGroup, "Light", SpawnGroup:GetName(), 5000, 50)
            end
        )
        :Spawn()

    Heli = SPAWN:NewWithAlias("blue-cargo-heli", "transport-heli")
    :SpawnAtAirbase( AIRBASE:FindByName( departureBase ),
                     SPAWN.Takeoff.Parking)
        -- :SpawnFromPointVec3(GroundGroup:GetPointVec3():AddX( 30 ):AddZ( 30 ))

end

local function InitBlueGroundPlaneDeployer()
    PlaneCargo = SET_CARGO:New():FilterTypes("Heavy"):FilterStart()
    BlueCargoPlane = SET_GROUP:New():FilterPrefixes("cargo-plane"):FilterStart()

    BlueCargoPlanePickupZone = SET_ZONE:New()
    BlueCargoPlanePickupZone:AddZone(  ZONE_AIRBASE:New( "Incirlik" ) )
    BlueCargoPlanePickupZone:AddZone(  ZONE_AIRBASE:New( "Ramat David" ) )

    BlueCargoPlaneDeployZone = SET_ZONE:New()

    BlueCargoDispatcherPlane = AI_CARGO_DISPATCHER_AIRPLANE:New(
        BlueCargoPlane,
        PlaneCargo,
        BlueCargoPlanePickupZone,
        BlueCargoPlaneDeployZone
    )
    BlueCargoDispatcherPlane:Start()
end


local function InitBlueGroundHeliDeployer()
    HeliCargo = SET_CARGO:New():FilterTypes("Light"):FilterStart()
    BlueCargoHeli = SET_GROUP:New():FilterPrefixes("transport-heli"):FilterStart()

    BlueCargoHeliPickupZone = SET_ZONE:New()
    BlueCargoHeliPickupZone:AddZone(  ZONE_AIRBASE:New( "Incirlik" ) )
    BlueCargoHeliPickupZone:AddZone(  ZONE_AIRBASE:New( "Ramat David" ) )

    BlueCargoHeliDeployZone = SET_ZONE:New()

    BlueCargoDispatcherHeli = AI_CARGO_DISPATCHER_HELICOPTER:New(
        BlueCargoHeli,
        HeliCargo,
        BlueCargoHeliPickupZone,
        BlueCargoHeliDeployZone
    )
    BlueCargoDispatcherHeli:Start()

    GroundDeployBluePlane = MENU_COALITION:New( coalition.side.BLUE, "Deploy C-130 To Base" )
    MENU_COALITION_COMMAND:New( coalition.side.BLUE, "Beirut-Rafic Hariri", GroundDeployBluePlane, deployGroundForcesByPlane, "Beirut-Rafic Hariri" )
    MENU_COALITION_COMMAND:New( coalition.side.BLUE, "Bassel Al-Assad", GroundDeployBluePlane, deployGroundForcesByPlane, "Bassel Al-Assad" )
    MENU_COALITION_COMMAND:New( coalition.side.BLUE, "Damascus", GroundDeployBluePlane, deployGroundForcesByPlane, "Damascus" )

    GroundDeployBlueHeli = MENU_COALITION:New( coalition.side.BLUE, "Deploy CH-59 To Base" )
    MENU_COALITION_COMMAND:New( coalition.side.BLUE, "Aleppo", GroundDeployBlueHeli, deployGroundForcesByHeli, "Aleppo" )
    MENU_COALITION_COMMAND:New( coalition.side.BLUE, "Hatay", GroundDeployBlueHeli, deployGroundForcesByHeli, "Hatay" )
    MENU_COALITION_COMMAND:New( coalition.side.BLUE, "Hama", GroundDeployBlueHeli, deployGroundForcesByHeli, "Hama" )
    MENU_COALITION_COMMAND:New( coalition.side.BLUE, "Beirut-Rafic Hariri", GroundDeployBlueHeli, deployGroundForcesByHeli, "Beirut-Rafic Hariri" )
    MENU_COALITION_COMMAND:New( coalition.side.BLUE, "Al Qusayr", GroundDeployBlueHeli, deployGroundForcesByHeli, "Al Qusayr" )

end


return {
    deployGroundForcesByHeli = deployGroundForcesByHeli,
    deployGroundForcesByPlane = deployGroundForcesByPlane,
    InitBlueGroundPlaneDeployer = InitBlueGroundPlaneDeployer,
    InitBlueGroundHeliDeployer = InitBlueGroundHeliDeployer,
}