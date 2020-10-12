local lfs = require("lfs")
MODULE_FOLDER = lfs.writedir()..[[Scripts\syr-miz\]]
package.path = MODULE_FOLDER .. "?.lua;" .. package.path
local utils = require('utils')

local PROFILER_ON = false
local DEBUG_DISPATCH_AA = false
local DEBUG_DISPATCH_AG = false


local function ToggleDebugAA(  )
    if DEBUG_DISPATCH_AA then
      DEBUG_DISPATCH_AA = false
    else
      DEBUG_DISPATCH_AA = true
    end
    A2ADispatcher:SetTacticalDisplay(DEBUG_DISPATCH_AA)
end

local function ToggleDebugAG(  )
    if DEBUG_DISPATCH_AG then
        DEBUG_DISPATCH_AG = false
    else
        DEBUG_DISPATCH_AG = true
    end
    A2GDispatcher:SetTacticalDisplay(DEBUG_DISPATCH_AG)
end

local function ToggleProfiler()
    if PROFILER_ON then
        PROFILER.Stop()
        PROFILER_ON = false
    else
        PROFILER.Start()
        PROFILER_ON = true
    end
end

local function Init()
    RedMissionData = MENU_COALITION:New( coalition.side.RED, "Mission Data" )
    MENU_COALITION_COMMAND:New( coalition.side.RED, "Toggle AA Debug", RedMissionData, ToggleDebugAA )
    MENU_COALITION_COMMAND:New( coalition.side.RED, "Toggle AG Debug", RedMissionData, ToggleDebugAG )
    MENU_COALITION_COMMAND:New( coalition.side.RED, "Toggle Profiler", RedMissionData, ToggleProfiler )
end

return {
    Init = Init
}