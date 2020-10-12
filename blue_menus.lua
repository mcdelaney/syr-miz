local lfs = require("lfs")
MODULE_FOLDER = lfs.writedir()..[[Scripts\syr-miz\]]
package.path = MODULE_FOLDER .. "?.lua;" .. package.path
local utils = require('utils')


local function ShowStatus(  )
    for i, name in pairs(SceneryTargets) do
      local Zone = ZONE:New( name )
      Zone:Scan( Object.Category.SCENERY )
      for SceneryTypeName, SceneryData in pairs( Zone:GetScannedScenery() ) do
        for SceneryName, SceneryObject in pairs( SceneryData ) do
          local SceneryObject = SceneryObject
          MESSAGE:NewType( "Targets: " .. SceneryObject:GetTypeName() .. ", Coord LL DMS: " .. SceneryObject:GetCoordinate():ToStringLLDMS(),
            MESSAGE.Type.Information ):ToAll()
        end
      end
    end
end

local function Init()
    BlueMissionData = MENU_COALITION:New( coalition.side.BLUE, "Mission Data" )
    MENU_COALITION_COMMAND:New( coalition.side.BLUE, "Show Objectives", BlueMissionData, ShowStatus )
end

return {
    Init = Init
}