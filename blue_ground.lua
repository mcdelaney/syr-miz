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

    BlueCargoDispatcherHeli:SetDeployHeight(5, 500)


    function BlueCargoDispatcherHeli:OnAfterLoading( From, Event, To, CarrierGroup, Cargo, CarrierUnit, PickupZone )
        local escort_prefix =  "escort"
        local Escort = SPAWN:NewWithAlias("blue-apache", escort_prefix)
            :SpawnInZone(PickupZone, true)

        local PointVec3 = POINT_VEC3:New( 100, 100, 100 )
        local FollowDCSTask = Escort:TaskFollow( CarrierGroup, PointVec3:GetVec3() )
        Escort:SetTask( FollowDCSTask, 1 )
        CarrierGroup:SetState(CarrierGroup, "escort", Escort:GetName())
    end

    function BlueCargoDispatcherHeli:OnAfterLoad( From, Event, To, CarrierGroup, PickupZone)
        MESSAGE:NewType( CarrierGroup:GetName() .. " picked up cargo from " .. PickupZone:GetName(),
                         MESSAGE.Type.Information ):ToAll()
        BlueCargoHeliPickupZone:RemoveZonesByName(PickupZone:GetName())
    end


    function BlueCargoDispatcherHeli:OnAfterUnloading( From, Event, To, CarrierGroup, Cargo, CarrierUnit, PickupZone)

        local EscortGroup = GROUP:FindByName(CarrierGroup:GetState(CarrierGroup, "escort"))
        local targetBase = RedBases:FindNearestAirbaseFromPointVec2(EscortGroup:GetPointVec2())
        if EscortGroup == nil then
            MESSAGE:NewType( "Escort group could not be found!", MESSAGE.Type.Information ):ToAll()
            return
        end

        -- EscortGroup:RouteAirTo(targetBase:GetPointVec3(), POINT_VEC3.RoutePointAltType.BARO,
        --                         POINT_VEC3.RoutePointAction.TurningPoint,
        --                         POINT_VEC3.RoutePointAction.TurningPoint, 300, 1)

        local EngageZone = ZONE_AIRBASE:New(targetBase.AirbaseName, 10000)

        local AICasZone = AI_CAS_ZONE:New( EngageZone, 500, 1000, 100, 500, EngageZone )
        AICasZone:SetControllable( EscortGroup )
        AICasZone:__Start( 1 ) -- They should statup, and start patrolling in the PatrolZone.
        AICasZone:__Engage( 1, 100, 150 )
        -- EscortGroup:EnRouteTaskFac(10000, 1)

    end
    function BlueCargoDispatcherHeli:OnAfterUnloaded( From, Event, To, CarrierGroup, Cargo, CarrierUnit, PickupZone)
        local ground = Cargo:GetObject()
        local targetBase = RedBases:FindNearestAirbaseFromPointVec2(Cargo:GetPointVec2())
        ground:TaskRouteToZone(ZONE_AIRBASE:New(targetBase.AirbaseName), false, 5, FORMATION.Cone)

        -- local EscortSet = SET_GROUP:New():FilterPrefixes("escort"):FilterStart()
        -- local EscortGroup = EscortSet:GetFirst()
        -- EscortGroup:TaskRouteToZone(ZONE_AIRBASE:New(targetBase.AirbaseName,  false, 80, FORMATION.Cone))
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


local function deployGroundForcesByHeli(targetCoord)
    blue_heli_marks = blue_heli_marks + 1

    local deployZoneName = 'heli-deploy-markpoint-'..tostring(blue_heli_marks)
    local departureBase = BlueBases:FindNearestAirbaseFromPointVec2(targetCoord)
    local logizone =  ZONE:FindByName("logizone-"..departureBase.AirbaseName)
    local departZone = ZONE_AIRBASE:New(departureBase.AirbaseName)
    local destZone = ZONE_RADIUS:New(deployZoneName, targetCoord:GetVec2(), 200)

    BlueCargoHeliDeployZone:AddZone( destZone )
    BlueCargoHeliPickupZone:AddZone( departZone )

    GroundGroup = SPAWN:NewWithAlias( "blue-ground-heli-template",
                                      "blue-ground-heli-spawn-"..tostring(blue_heli_marks) )
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

return {
    deployGroundForcesByHeli = deployGroundForcesByHeli,
    deployGroundForcesByPlane = deployGroundForcesByPlane,
    InitBlueGroundPlaneDeployer = InitBlueGroundPlaneDeployer,
    InitBlueGroundHeliDeployer = InitBlueGroundHeliDeployer,
}