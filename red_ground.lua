local lfs = require("lfs")
MODULE_FOLDER = lfs.writedir()..[[Scripts\syr-miz\]]
package.path = MODULE_FOLDER .. "?.lua;" .. package.path
local utils = require('utils')

local SetDeployZones = SET_ZONE:New()


local function initRedGroundBaseAttack(depatureBase, targetBase)

    -- utils.log"Creating spawn for red ground attack at "..depatureBase)
    SetDeployZones:AddZone( ZONE_AIRBASE:New( targetBase ) )

    local depart1 = ZONE:New('redpickup-'..depatureBase.."-1")

    SpawnInfantry1 = SPAWN:New( "red-infantry" )
        :InitLimit( 5, 1 )
        :InitRandomizePosition(true, 250, 50)
        :InitRandomizeZones( { depart1 } )
        :OnSpawnGroup(function( SpawnGroup )
            CARGO_GROUP:New(SpawnGroup,"InfantryType",SpawnGroup:GetName(), 50 ,5)
        end)
        :SpawnScheduled( 10, 0 )

    CarrierSpawn1 = SPAWN:New(
            "red-helos"
        )
        :InitLimit( 6, 1 )
        :InitRandomizeZones({ depart1 })
        :SpawnScheduled( 10, 0 )

    --  CarrierSpawn2 = SPAWN:New(
    --         "red-apc-convoy"
    --     )
    --     :InitLimit( 6, 1 )
    --     :InitRandomizeZones({ depart2 })
    --     :SpawnScheduled( 10, 0 )

    utils.log("Red ground attack convoy created...")
end


return {
    initRedGroundBaseAttack = initRedGroundBaseAttack
}