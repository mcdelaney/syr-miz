local logging = require("logging")
-- local missionUtils = require("missionUtils")
local utils = require("utils")

local M = {}

-- These values must match what's in Hooks\RSRSlotBlocker.lua
M.slotEnabled = 0
M.slotDisabled = 99 -- see Hooks\RSRSlotBlocker.lua for the reason for this value

local log = logging.Logger:new("SlotBlocker", "info")

M.clientGroupNames = {}

function M.isClientGroup(group)
    -- returns true if any unit in the group is a Client, otherwise false
    for _, unit in ipairs(group.units) do
        if unit.skill == "Client" then
            return true
        end
    end
    return false
end

function M.iterCountries(mission, countryCallback)
    for sideName, coalition in pairs(mission.coalition) do
        if coalition.country ~= nil then
            for _, country in ipairs(coalition.country) do
                countryCallback(sideName, country)
            end
        end
    end
end


function M.iterGroups(mission, groupCallback)
    M.iterCountries(mission, function(sideName, country)
        if country.plane ~= nil then
            for _, groups in pairs(country.plane) do
                for _, group in ipairs(groups) do
                    groupCallback(group, sideName)
                end
            end
        end
        if country.helicopter ~= nil then
            for _, groups in pairs(country.helicopter) do
                for _, group in ipairs(groups) do
                    groupCallback(group, sideName)
                end
            end
        end
    end)
end

M.iterGroups(env.mission, function(group)
    if M.isClientGroup(group) then
        local groupName = env.getValueDictByKey(group.name)
        table.insert(M.clientGroupNames, groupName)
    end
end)

local function disableSlot(groupName)
    log:info("Disabling group '$1'", groupName)
    trigger.action.setUserFlag(groupName, M.slotDisabled)
end

local function enableSlot(groupName)
    log:info("Enabling group '$1'", groupName)
    trigger.action.setUserFlag(groupName, M.slotEnabled)
end

local function blockAllSlots()
    log:info("Blocking all slots")
    for _, groupName in pairs(M.clientGroupNames) do
        local _disableSlot = true
        if utils.startswith(groupName, "Carrier") then
            log:info("Not blocking carrier group '$1'", groupName)
            _disableSlot = false
        end

        if _disableSlot then
            disableSlot(groupName)
        end
    end
end

function M.onMissionStart()
    trigger.action.setUserFlag("SSB", 100)
    blockAllSlots()
end

function M.configureSlotsForBase(baseName, sideName)
    log:info("Configuring slots for $1 as owned by $2", baseName, sideName)
    for _, groupName in pairs(M.clientGroupNames) do
        local groupBaseName, groupSideName = utils.getBaseAndSideNamesFromGroupName(groupName)
        if groupBaseName ~= nil and groupSideName ~= nil then
            if utils.matchesBaseName(baseName, groupBaseName) then
                if groupSideName == sideName then
                    enableSlot(groupName)
                else
                    disableSlot(groupName)
                end
            else
                log:info("Slot does not match basename for $1", groupBaseName)
            end
        end
    end
end

return M