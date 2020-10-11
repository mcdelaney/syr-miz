local lfs = require("lfs")
MODULE_FOLDER = lfs.writedir()..[[Scripts\syr-miz\]]
package.path = MODULE_FOLDER .. "?.lua;" .. package.path
local utils = require('utils')

local function deployBlueC130(targetBase)
    -- utils.log("Sending c130 to capture "..targetBase)
    departureBase = "Incirlik"
    BlueCargoDeployZone:AddZone( ZONE_AIRBASE:New( targetBase ) )

    Infantry = SPAWN:New( "blue-stinger-spawn" )
        :OnSpawnGroup(
            function( SpawnGroup )
                CARGO_GROUP:New(SpawnGroup, "Heavy", SpawnGroup:GetName(), 2000, 30)
            end
        )
        :SpawnFromPointVec3(GroundGroup:GetPointVec3():AddX( 50 ):AddZ( 50 ))

    GroundGroup = SPAWN:New( "blue-ground-test" )
        :InitRandomizeZones( { ZONE:FindByName("logizone-Incirlik") } )
        :OnSpawnGroup(
            function( SpawnGroup )
                CARGO_GROUP:New(SpawnGroup, "Heavy", SpawnGroup:GetName(), 2000, 30)
            end
        )
        :Spawn()

    Plane = SPAWN:New("cargo-plane")
        :InitUnControlled(true)
        :SpawnAtAirbase( AIRBASE:FindByName( "Incirlik" ),
                     SPAWN.Takeoff.Parking)

    utils.log("Cargo dispatched...")
end


return {
    deployBlueC130 = deployBlueC130
}