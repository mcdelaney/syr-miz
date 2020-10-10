local lfs = require("lfs")
MODULE_FOLDER = lfs.writedir()..[[Scripts\syr-miz\]]
package.path = MODULE_FOLDER .. "?.lua;" .. package.path
local utils = require('utils')

-- local function deployBlueC130(depatureBase, targetBase)
--     utils.log("Sending c130 to capture $1 from $2", depatureBase, targetBase)

--     SetDeployZones:AddZone( ZONE_AIRBASE:New( targetBase ) )

--     local depart1 = ZONE_AIRBASE:New(departureBase)

--     SpawnInfantry1 = SPAWN:New( "red-infantry" )
--         :InitLimit( 5, 1 )
--         :InitRandomizePosition(true, 250, 50)
--         :InitRandomizeZones( { depart1 } )
--         :OnSpawnGroup(function( SpawnGroup )
--             CARGO_GROUP:New(SpawnGroup,"InfantryType",SpawnGroup:GetName(), 50 ,5)
--         end)
--         :SpawnScheduled( 10, 0 )
--         :SpawnScheduled( 10, 0 )

--     C130 = SPAWN:New("blue-c130")
--         :InitAirbase(departureBase, SPAWN.Takeoff.Runway)
--         :SpawnScheduled( 10, 0 )

--     utils.log("Cargo dispatched...")
-- end

-- local function deployBlueC130(targetBase)
--     utils.log("Sending c130 to capture "..targetBase)
--     departureBase = "Incirlik"
--     pickupZone = 'pickupzone-'..departureBase
--     departure = AIRBASE:FindByName(departureBase)

--     BlueCargoPickupZone:AddZone( ZONE:New( pickupZone ) )
--     BlueCargoDeployZone:AddZone( ZONE_AIRBASE:New( targetBase ) )

--     GroundGroup = SPAWN:New( "blue-ground-deploy" )
--     :InitLimit(7, 1)
--     :SpawnFromCoordinate(ZONE:FindByName("logizone-"..departureBase):GetPointVec2())
--     -- :SpawnAtAirbase( departure  )
--     -- :Spawn()

--     CargoGroup = CARGO_GROUP:New( GroundGroup, "Armor", "BlueGround", 2000, 10)
--     BlueCargo:AddCargo(CargoGroup)

--     C130 = SPAWN:New("blue-c130")
--         :SpawnAtAirbase( departure)
--         -- :Spawn()
--     BlueCargoPlane:AddGroup(C130)

--     -- CargoPlane = AI_CARGO_AIRPLANE:New(C130, CargoGroup)
--     CargoGroup:Board(C130)

--     -- CargoCarrier = CARGO:New(C130)
--     utils.log("Cargo dispatched...")
-- end

local function deployBlueC130(targetBase)
    utils.log("Sending c130 to capture "..targetBase)
    departureBase = "Incirlik"
    pickupZone = 'pickupzone-'..departureBase

    departure = AIRBASE:FindByName(departureBase)
    dest = AIRBASE:FindByName(targetBase)
    -- BlueCargoPickupZone:AddZone( ZONE:New( pickupZone ) )
    -- BlueCargoDeployZone:AddZone( ZONE_AIRBASE:New( targetBase ) )

    GroundGroup = SPAWN:New( "blue-ground-test" )
    :InitLimit(1, 1)
    :InitRandomizeZones( { ZONE:FindByName("logizone-"..departureBase) } )
    :Spawn()
    -- :SpawnAtAirbase( departure  )
    GroupInstance = GROUP:FindByName(GroundGroup:GetName())
    CargoGroup = CARGO_GROUP:New( GroupInstance, "Vehicles", "BlueGround-1", 150, 10)

    C130 = SPAWN:New("blue-c130")
        :SpawnAtAirbase( departure)
    C130Instance = GROUP:FindByName(C130:GetName())
    CargoPlane = AI_CARGO_AIRPLANE:New(C130, CargoGroup)
    CargoGroup:Board(CargoPlane)
    CargoPlane:Pickup(ZONE_AIRBASE:New(departureBase))

    -- function CargoPlane:OnAfterLoaded( Airplane, From, Event, To, Cargo )
    --     CargoPlane:Deploy(0.2, dest:GetCoordinate(), math.random( 500, 750 ) )
    -- end

    -- CargoCarrier = CARGO:New(C130)
    utils.log("Cargo dispatched...")
end


return {
    deployBlueC130 = deployBlueC130
}