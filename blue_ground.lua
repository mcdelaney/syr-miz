local lfs = require("lfs")
MODULE_FOLDER = lfs.writedir()..[[Scripts\syr-miz\]]
package.path = MODULE_FOLDER .. "?.lua;" .. package.path
local utils = require('utils')
local blue_heli_marks = 0

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


local function deployGroundForcesByHeli(targetBase, targetCoord)
    blue_heli_marks = blue_heli_marks + 1
    local dest_location
    local deployZoneName

    if targetBase == nil then
        dest_location = targetCoord
        deployZoneName = 'heli-deploy-markpoint-'..tostring(blue_heli_marks)
    else
        dest_location = AIRBASE:FindByName(targetBase):GetCoordinate()
        deployZoneName = 'heli-deploy-'..targetBase
    end

    local departureBase = BlueBases:FindNearestAirbaseFromPointVec2(dest_location)
    local logizone =  ZONE:FindByName("logizone-"..departureBase.AirbaseName)
    local departZone = ZONE_AIRBASE:New(departureBase.AirbaseName)

    if targetBase ~= nil then
        utils.log("Targetbase for heli deploy is nil... finding coordinate near road...")
        dest_location = departureBase:GetCoordinate():GetIntermediateCoordinate(dest_location, 0.98):GetClosestPointToRoad()
    end

    -- pcall(function()
    --     destZone = ZONE_RADIUS:FindByName(deployZoneName)
    -- end)

    local destZone = ZONE_RADIUS:New(deployZoneName, dest_location:GetVec2(), 200)

    BlueCargoHeliDeployZone:AddZone( destZone )
    BlueCargoHeliPickupZone:AddZone( departZone )

    GroundGroup = SPAWN:NewWithAlias( "blue-ground-heli-template", "blue-ground-heli-spawn-"..tostring(blue_heli_marks) )
        :OnSpawnGroup(
            function( SpawnGroup )
                CARGO_GROUP:New(SpawnGroup, "Light", SpawnGroup:GetName(), 100, 50)
            end
        )
        :SpawnFromVec2(logizone:GetVec2())

    local heli_spawn_coord = GroundGroup:GetPointVec3():AddX( 500 )
    local heading heli_spawn_coord:HeadingTo(GroundGroup:GetCoordinate())

    Heli = SPAWN:NewWithAlias("blue-cargo-heli", "transport-heli-"..tostring(blue_heli_marks))
        :InitHeading(heading)
        :SpawnFromPointVec3(heli_spawn_coord)

    MESSAGE:NewType( "Spawning heli group for deployment at "..departureBase.AirbaseName,
        MESSAGE.Type.Information ):ToAll()
end

local function InitBlueGroundPlaneDeployer()
    PlaneCargo = SET_CARGO:New():FilterTypes("Heavy"):FilterStart()
    BlueCargoPlane = SET_GROUP:New():FilterPrefixes("cargo-plane"):FilterStart()
    BlueCargoPlanePickupZone = SET_ZONE:New()
    BlueCargoPlaneDeployZone = SET_ZONE:New()
    BlueCargoDispatcherPlane = AI_CARGO_DISPATCHER_AIRPLANE:New(
        BlueCargoPlane,
        PlaneCargo,
        BlueCargoPlanePickupZone,
        BlueCargoPlaneDeployZone
    )
    BlueCargoDispatcherPlane:Start()
    function BlueCargoDispatcherPlane:OneAfterDeployed( From, Event, To, CarrierGroup, DeployZone)
        MESSAGE:NewType( "Group " .. CarrierGroup:GetName() .. " deployed all cargo in zone " .. DeployZone:GetName(),
                         MESSAGE.Type.Information ):ToAll()
        CarrierGroup:Destroy(true)
    end

    GroundDeployBluePlane = MENU_COALITION:New( coalition.side.BLUE, "Deploy C-130 To Base" )
    MENU_COALITION_COMMAND:New( coalition.side.BLUE, "Beirut-Rafic Hariri", GroundDeployBluePlane, deployGroundForcesByPlane, "Beirut-Rafic Hariri" )
    MENU_COALITION_COMMAND:New( coalition.side.BLUE, "Bassel Al-Assad", GroundDeployBluePlane, deployGroundForcesByPlane, "Bassel Al-Assad" )
    MENU_COALITION_COMMAND:New( coalition.side.BLUE, "Damascus", GroundDeployBluePlane, deployGroundForcesByPlane, "Damascus" )
end


local function InitBlueGroundHeliDeployer()
    HeliCargo = SET_CARGO:New():FilterTypes("Light"):FilterStart()
    BlueCargoHeli = SET_GROUP:New():FilterPrefixes("transport-heli"):FilterStart()
    BlueCargoHeliPickupZone = SET_ZONE:New()
    BlueCargoHeliDeployZone = SET_ZONE:New()
    BlueCargoDispatcherHeli = AI_CARGO_DISPATCHER_HELICOPTER:New(
        BlueCargoHeli,
        HeliCargo,
        BlueCargoHeliPickupZone,
        BlueCargoHeliDeployZone
    )

    BlueCargoDispatcherHeli:SetDeployHeight(5, 100)

    function BlueCargoDispatcherHeli:OnAfterLoaded( From, Event, To, CarrierGroup, Cargo, CarrierUnit, PickupZone)
        MESSAGE:NewType( CarrierGroup:GetName() .. " picked up cargo from " .. PickupZone:GetName(),
                         MESSAGE.Type.Information ):ToAll()
        BlueCargoHeliPickupZone:RemoveZonesByName(PickupZone:GetName())
    end

    function BlueCargoDispatcherHeli:OnAfterUnloaded( From, Event, To, CarrierGroup, Cargo, CarrierUnit, PickupZone)
        local ground = Cargo:GetObject()
        local targetBase = RedBases:FindNearestAirbaseFromPointVec2(Cargo:GetPointVec2())
        ground:TaskRouteToZone(ZONE_AIRBASE:New(targetBase.AirbaseName), false, 5, FORMATION.Cone)
        MESSAGE:NewType( "Deployed units marching to " .. targetBase.AirbaseName,
                 MESSAGE.Type.Information ):ToAll()
    end

    function BlueCargoDispatcherHeli:OnAfterDeployed( From, Event, To, CarrierGroup, DeployZone)
        MESSAGE:NewType( CarrierGroup:GetName() .. " deployed cargo to " .. DeployZone:GetName(),
                         MESSAGE.Type.Information ):ToAll()
        CarrierGroup:Destroy()
        BlueCargoHeliDeployZone:RemoveZonesByName(DeployZone:GetName())
    end
    BlueCargoDispatcherHeli:Start()
end


return {
    deployGroundForcesByHeli = deployGroundForcesByHeli,
    deployGroundForcesByPlane = deployGroundForcesByPlane,
    InitBlueGroundPlaneDeployer = InitBlueGroundPlaneDeployer,
    InitBlueGroundHeliDeployer = InitBlueGroundHeliDeployer,
}