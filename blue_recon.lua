local io = require("io")
local lfs = require("lfs")
MODULE_FOLDER = lfs.writedir()..[[Scripts\syr-miz\]]
package.path = MODULE_FOLDER .. "?.lua;" .. package.path
local utils = require("utils")

local function InitBlueReconGroup(CC)

    RecceSetGroup = SET_GROUP:New():FilterPrefixes( "blue-recon" ):FilterStart()
    RecceDetection = DETECTION_UNITS:New( RecceSetGroup ):FilterCategories( Unit.Category.GROUND_UNIT )
    RecceDetection:InitDetectRadar(true)
    RecceDetection:InitDetectOptical(true)
    RecceDetection:InitDetectIRST(true)
    RecceDetection:InitDetectVisual(true)
    RecceDetection:Start()

    function RecceDetection:OnAfterDetected( From, Event, To, DetectedUnits )
        env.info("Processing detected units..")
        for _, DetectedUnit in pairs( DetectedUnits ) do
            local DetectedUnitGroup = DetectedUnit:GetGroup()
            if DetectedUnitGroup:CountAliveUnits() == 0 then
                return
            end
            local DetectedName = DetectedUnitGroup:GetName()
            for _, Mark in pairs(_STATE["marks"]) do
                if Mark["name"] == DetectedName then
                    return
                end
            end
            local DetectedCoord = DetectedUnitGroup:GetCoordinate():GetRandomCoordinateInRadius(150, 30)
            local DetectedVec3 = DetectedCoord:GetVec3()
            _MARKERS[DetectedName] = MARKER:New(DetectedCoord, DetectedName):ToAll()
            table.insert(
                _STATE["marks"], {
                    name = DetectedName,
                    x = DetectedVec3.x,
                    y = DetectedVec3.y,
                    z = DetectedVec3.z,
                }
            )
            env.info( "New Detection: "..DetectedName)
            CC:MessageToAll( "New Detection: "..DetectedName.." at: "..DetectedCoord:ToStringLLDDM(), 15, "" )
            utils.saveTable(_STATE, BASE_FILE)
        end
    end
end

return {
    InitBlueReconGroup = InitBlueReconGroup
}