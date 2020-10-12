
BASE:TraceOnOff(true)
BASE:TraceAll(true  )

PlaneCargo = SET_CARGO:New():FilterTypes("Heavy"):FilterStart()
HeliCargo = SET_CARGO:New():FilterTypes("Light"):FilterStart()
BlueCargoPlane = SET_GROUP:New():FilterPrefixes("cargo-plane"):FilterStart()
BlueCargoHeli = SET_GROUP:New():FilterPrefixes("transport-heli"):FilterStart()

BlueCargoPickupZone = SET_ZONE:New()
BlueCargoPickupZone:AddZone(  ZONE_AIRBASE:New( "Incirlik" ) )

BlueCargoDeployZone = SET_ZONE:New()
BlueCargoDeployZone:AddZone( ZONE_AIRBASE:New( "Bassel Al-Assad" ) )

BlueCargoDispatcherPlane = AI_CARGO_DISPATCHER_AIRPLANE:New(
    BlueCargoPlane,
    PlaneCargo,
    BlueCargoPickupZone,
    BlueCargoDeployZone
)
BlueCargoDispatcherPlane:Start()

BlueCargoDispatcherHeli = AI_CARGO_DISPATCHER_HELICOPTER:New(
    BlueCargoHeli,
    HeliCargo,
    BlueCargoPickupZone,
    BlueCargoDeployZone
)
BlueCargoDispatcherHeli:SetHomeZone(ZONE_AIRBASE:New("Incirlik"))
-- BlueCargoDispatcherHeli:SetPickupRadius(1000, 10)
BlueCargoDispatcherHeli:Start()




GroundGroup = SPAWN:New( "blue-ground-test" )
    :InitRandomizeZones( { ZONE:FindByName("logizone-Incirlik") } )
    :OnSpawnGroup(
        function( SpawnGroup )
            CARGO_GROUP:New(SpawnGroup, "Heavy", SpawnGroup:GetName(), 2000, 30)
        end
    )
    :Spawn()

Heli = SPAWN:NewWithAlias("cargo-heli", "transport-heli")
--    :InitUnControlled(true)
    :SpawnFromPointVec3(GroundGroup:GetPointVec3():AddX( 30 ):AddZ( 30 ))

Infantry = SPAWN:New( "blue-stinger-spawn" )
    :OnSpawnGroup(
        function( SpawnGroup )
            CARGO_GROUP:New(SpawnGroup, "Light", SpawnGroup:GetName(), 2000, 30)
        end
    )
    :SpawnFromPointVec3(GroundGroup:GetPointVec3():AddX( 50 ):AddZ( 50 ))

Plane = SPAWN:New("cargo-plane")
    :InitUnControlled(true)
    :SpawnAtAirbase( AIRBASE:FindByName( "Incirlik" ),
                     SPAWN.Takeoff.Parking)
