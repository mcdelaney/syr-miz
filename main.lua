local io = require("io")
local lfs = require("lfs")
MODULE_FOLDER = lfs.writedir()..[[Scripts\syr-miz\]]
package.path = MODULE_FOLDER .. "?.lua;" .. package.path

-- mist.debug.dump_G("dump.txt")

local slotblock = require("slotblock")
local ctld_config = require("ctld_config")
local logging = require("logging")
local utils = require("utils")
-- local red_ground = require("red_ground")
local blue_ground = require("blue_ground")
local red_menus = require("red_menus")
local blue_menus = require("blue_menus")

BASE_FILE = lfs.writedir() .. "Scripts\\syr-miz\\syr_state.json"
_STATE = {}
_STATE["bases"] = {}
_STATE["slots"] = {}
_STATE["scenery"] = {}
_STATE["ctld_units"] = {}
_STATE["hawks"] = {}
_STATE["dead"] = {}
local INIT = true
local ENABLE_RED_AIR = true
local DEBUG_IADS = false

ATIS = {}

local ContestedBases = {
  "Ramat David",
  "Incirlik",
  "Aleppo",
  "Abu al-Duhur",
  "Hatay",
  "Haifa",
  "Bassel Al-Assad",
  "Beirut-Rafic Hariri",
  "Damascus",
  "Al Qusayr",
  "Hama"
}

local AG_BASES = {
  "Hama",
  "Damascus",
  -- "Al Qusayr",
}

local SceneryTargets = {"damascus-target-1", "damascus-target-2", "damascus-target-3"}
local _NumAirbaseDefenders = 1


local function setBaseRed(baseName, init_ground)
  utils.log("Setting "..baseName.." as red...")
  local logUnitName = "logistic-"..baseName
  local logZone = 'logizone-'..baseName
  ctld.deactivatePickupZone(logZone)
  utils.destroyIfExists(logUnitName, true)

  slotblock.configureSlotsForBase(baseName, "red")
  pcall(function()
    BlueBases:RemoveAirbasesByName(baseName)
  end)
  pcall(function()
    RedBases:AddAirbasesByName(baseName)
  end)

  if init_ground == true then
    for i=1, _NumAirbaseDefenders do
      local grp_name = "defenseBase-"..baseName.."-"..tostring(i)
      local zone_base = ZONE:New(baseName..'-defzone'):GetPointVec2()
      local baseDef = SPAWN:NewWithAlias( "defenseBase", grp_name )
      baseDef:SpawnFromPointVec2(zone_base)
    end
  end

  MESSAGE:New( baseName.." was captured by Red!", 5):ToAll()
end


local function setBaseBlue(baseName, startup)
  utils.log("Setting "..baseName.." as blue...")
  local logUnitName = "logistic-"..baseName
  local logZone = 'logizone-'..baseName
  local logisticCoordZone = ZONE:FindByName(logZone, false)
  if logisticCoordZone ~= nil then
    logisticCoordZone = ZONE_RADIUS:New(logZone, AIRBASE:FindByName(baseName):GetVec2(),1000)

    local logisticCoord = logisticCoordZone:GetPointVec2()
    local logisticUnit = SPAWNSTATIC:NewFromStatic("logisticBase", country.id.USA)
    logisticUnit:SpawnFromCoordinate(logisticCoord, 10, logUnitName)
    table.insert(ctld.logisticUnits, logUnitName)
    ctld.activatePickupZone(logZone)
    if logisticUnit == nil then
      utils.log("Could not find base logistic unit")
    end
  else
    MESSAGE:New("Trigger zone does not exist for "..logZone.."!", 5):ToAll()
  end

  slotblock.configureSlotsForBase(baseName, "blue")
  pcall(function()
    RedBases:RemoveAirbasesByName(baseName)
  end)
  pcall(function()
    BlueBases:AddAirbasesByName(baseName)
  end)
  MESSAGE:New( baseName.." was captured by Blue!", 5):ToAll()

end


RedBases = SET_AIRBASE:New()
BlueBases = SET_AIRBASE:New()

local SAMS = {}
SAMS["SA6sam"] = SET_GROUP:New():FilterPrefixes("SAM-SA6"):FilterActive(true):FilterOnce()
SAMS["SA2sam"] = SET_GROUP:New():FilterPrefixes("SAM-SA2"):FilterActive(true):FilterOnce()
SAMS["SA3sam"] = SET_GROUP:New():FilterPrefixes("SAM-SA3"):FilterActive(true):FilterOnce()
SAMS["SA10sam"] = SET_GROUP:New():FilterPrefixes("SAM-SA10"):FilterActive(true):FilterOnce()
SAMS["EWR"] = SET_GROUP:New():FilterPrefixes("EWR"):FilterActive(true):FilterStart()


if utils.file_exists(BASE_FILE) then
  _STATE = utils.readState(BASE_FILE)
  if _STATE ~= nil then
    MESSAGE:New("State file found... restoring...", 5):ToAll()
    INIT = false
  end
else
  utils.log("No state file exists..")
end

if INIT then

  for k, sam in pairs(SAMS) do
    pcall(function(_args) utils.prune_enemies(sam, k) end)
  end
else
  for _, unit in pairs(_STATE["dead"]) do
    utils.removeUnit(unit)
  end

  for i, obj in pairs(_STATE["scenery"]) do
    if obj then
      local unit = Unit.getByName(tostring(obj.id))
      if unit then
        utils.log("Destrying object: "..obj.id)
        unit:destroy()
      end
    end
    local vec3 = COORDINATE:New(obj.x, obj.y, obj.z)
    local searchZone = ZONE_RADIUS:New(tostring(i), vec3:GetVec2(), 1)
    searchZone:Scan( Object.Category.SCENERY )

    for SceneryTypeName, SceneryData in pairs( searchZone:GetScannedScenery() ) do
      for SceneryName, SceneryObject in pairs( SceneryData ) do
        local SceneryObject = SceneryObject
        utils.log( "Scenery Destroyed: " .. SceneryObject:GetTypeName())
        SceneryObject:GetDCSObject():destroy()
        vec3:Explosion(200)
      end
    end
  end
end


-- For reach numbered group, for each airbase,
-- Attempt to find the group, destroying it if the airbase is blue, and activating it
--  if the base is red.
for _, base in pairs(ContestedBases) do
  local base_obj = AIRBASE:FindByName(base)
  if base_obj == nil then
    MESSAGE:New("Invalid airbase name in main.lua: " .. base, 5):ToCoalition( coalition.side.BLUE )
  end

  if INIT or _STATE.bases[base] == nil then
    _STATE.bases[base] = base_obj:GetCoalition()
  end
  if _STATE.bases[base] == coalition.side.BLUE then
    setBaseBlue(base)
  else
    setBaseRed(base, true)

  end
end

utils.log("Spawning CTLD units from state")
utils.restoreCtldUnits(_STATE, ctld_config)

SPAWN:New("awacs-Carrier")
  :InitLimit(1, 50)
  :InitRepeatOnLanding()
  :SpawnScheduled(4, 0)

SPAWN:New("awacs-Incirlik")
  :InitLimit(1, 50)
  :InitRepeatOnLanding()
  :SpawnScheduled(4, 0)


redIADS = SkynetIADS:create('SYRIA')

commandCenter1 = StaticObject.getByName('RED-HQ-2')
redIADS:addCommandCenter(commandCenter1)
redIADS:setUpdateInterval(15)
redIADS:addEarlyWarningRadarsByPrefix('EWR')
redIADS:addEarlyWarningRadarsByPrefix("redAWACS")
redIADS:addSAMSitesByPrefix('SAM')
redIADS:getSAMSites():setEngagementZone(SkynetIADSAbstractRadarElement.GO_LIVE_WHEN_IN_SEARCH_RANGE):setGoLiveRangeInPercent(80)
redIADS:getSAMSitesByPrefix("SA-10"):setActAsEW(true)
redIADS:setupSAMSitesAndThenActivate()

DetectionSetGroup = SET_GROUP:New()
  :FilterPrefixes({"EWR", "redAWACS", "defenseBase"})
  :FilterCoalitions("red")
  :FilterActive(true)
  :FilterStart()
Detection = DETECTION_AREAS:New( DetectionSetGroup, 30000 )
BorderZone = ZONE_POLYGON:New( "RED-BORDER", GROUP:FindByName( "red-border" ) )

redCommand = COMMANDCENTER:New( GROUP:FindByName( "REDHQ" ), "REDHQ" )

A2ADispatcher = AI_A2A_DISPATCHER:New( Detection )
A2ADispatcher:SetBorderZone( BorderZone )
A2ADispatcher:SetCommandCenter(redCommand)
A2ADispatcher:SetEngageRadius()
A2ADispatcher:SetGciRadius()
A2ADispatcher:SetIntercept( 10 )
A2ADispatcher:Start()

redCommand_AG = COMMANDCENTER:New( GROUP:FindByName( "REDHQ-AG" ), "REDHQ-AG" )
DetectionSetGroup_G = SET_GROUP:New()
  :FilterPrefixes({"redAWACS", "su-24-recon", "defenseBase"})
  :FilterActive()
  :FilterStart()

Detection_G = DETECTION_AREAS:New( DetectionSetGroup_G, 1000 )
Detection_G:BoundDetectedZones()
Detection_G:Start()

A2GDispatcher = AI_A2G_DISPATCHER:New( Detection_G )
A2GDispatcher:AddDefenseCoordinate( "ag-base", AIRBASE:FindByName( "Damascus" ):GetCoordinate() )
A2GDispatcher:SetDefenseReactivityHigh()
A2GDispatcher:SetDefenseRadius( 200000 )
A2GDispatcher:SetCommandCenter(redCommand_AG)
A2GDispatcher:Start()

-- SetCargoInfantry = SET_CARGO:New():FilterTypes( "InfantryType" ):FilterStart()
-- SetAPC = SET_GROUP:New():FilterPrefixes( "red-apc-convoy" ):FilterStart()
-- SetHeli = SET_GROUP:New():FilterPrefixes( "red-helos" ):FilterStart()
-- SetDeployZones = SET_ZONE:New()
-- SetPickupZones = SET_ZONE:New():FilterPrefixes( "redpickup" ):FilterStart()

-- AICargoDispatcherAPC = AI_CARGO_DISPATCHER_APC:New( SetAPC, SetCargoInfantry, SetPickupZones, SetDeployZones)
-- AICargoDispatcherAPC:Start()

-- AICargoDispatcherHelicopter = AI_CARGO_DISPATCHER_HELICOPTER:New(SetHeli, SetCargoInfantry, SetPickupZones, SetDeployZones)
-- AICargoDispatcherHelicopter:Start()


blue_ground.InitBlueGroundPlaneDeployer()
blue_ground.InitBlueGroundHeliDeployer()

for _, base in pairs(ContestedBases) do

  if ENABLE_RED_AIR and _STATE.bases[base] == coalition.side.RED then
    local zone_name = base.."-capzone"
    local zone = ZONE:FindByName(zone_name)
    if zone == nil then
      zone = ZONE_AIRBASE:New(base, 150000):SetName(zone_name)
    end

    utils.log("Creating a2a group from base: "..base)
    local sqd_cap = base.."-cap"
    A2ADispatcher:SetSquadron( sqd_cap, base, { "su-30-cap", "mig-31-cap", "jf-17-cap" } ) --, 10)
    A2ADispatcher:SetSquadronGrouping( sqd_cap, 2 )
    A2ADispatcher:SetSquadronTakeoffFromParkingHot(sqd_cap)
    A2ADispatcher:SetSquadronLandingNearAirbase( sqd_cap )
    A2ADispatcher:SetSquadronCap( sqd_cap, zone, 10000, 25000, 500, 800, 600, 1200, "BARO")
    A2ADispatcher:SetSquadronCapInterval( sqd_cap, 1, 60*3, 60*7, 1)
    A2ADispatcher:SetSquadronCapRacetrack(sqd_cap, 10000, 20000, 90, 180, 5*60, 10*60)

    local sqd_gci = base.."-gci"
    A2ADispatcher:SetSquadron( sqd_gci, base, {"su-30-gci"} )
    A2ADispatcher:SetSquadronGrouping( sqd_gci, 1 )
    A2ADispatcher:SetSquadronOverhead( sqd_gci, 0.5 )
    A2ADispatcher:SetSquadronTakeoffFromParkingHot(sqd_gci)
    A2ADispatcher:SetSquadronGci( sqd_gci, 600, 900 )

    for _, agBase in pairs(AG_BASES) do
      if agBase == base then

        -- local cas_zone = ZONE_AIRBASE:New(base, 10000)
        -- local sqd_cas = base.."-cas"
        -- A2GDispatcher:SetSquadron(sqd_cas, base,  { "ka-50-cas" }, 4 )
        -- A2GDispatcher:SetSquadronGrouping( sqd_cas, 1 )
        -- A2GDispatcher:SetSquadronCasPatrol(sqd_cas, cas_zone) --,  300, 500, 50, 80, 250, 300 )
        -- A2GDispatcher:SetSquadronCasPatrolInterval( sqd_cas, 2, 120, 600, 1 )
        -- A2GDispatcher:SetSquadronOverhead(sqd_cas, 0.15)
        -- -- A2GDispatcher:SetDefaultPatrolTimeInterval(180)
        -- A2GDispatcher:SetDefaultTakeoffInAir( sqd_cas )
        -- A2GDispatcher:SetSquadronLandingNearAirbase( sqd_cas )

        local sqd_sead = base.."-sead"
        A2GDispatcher:SetSquadron(sqd_sead, base,  { "su-34-sead" }, 10 )
        A2GDispatcher:SetSquadronGrouping( sqd_sead, 1 )
        -- A2GDispatcher:SetSquadronEngageLimit( sqd_sead, 2 )

        A2GDispatcher:SetSquadronSead(sqd_sead, 300, 600, 15000, 30000)
        A2GDispatcher:SetSquadronOverhead(sqd_sead, 0.25)
        A2GDispatcher:SetDefaultTakeoffFromParkingHot( sqd_sead )
        A2GDispatcher:SetSquadronLandingNearAirbase( sqd_sead )

        -- local sqd_cas = base.."-cas"
        -- A2GDispatcher:SetSquadron(sqd_cas, base,  { "su-25-cas" },  10)
        -- A2GDispatcher:SetSquadronGrouping( sqd_cas, 2 )
        -- A2GDispatcher:SetSquadronCas(sqd_cas, 250, 600)
        -- A2GDispatcher:SetSquadronOverhead(sqd_cas, 0.15)
        -- A2GDispatcher:SetDefaultTakeoffFromRunway( sqd_cas )
        -- A2GDispatcher:SetSquadronLandingNearAirbase( sqd_cas )

        local sqd_bai = base.."-bai"
        A2GDispatcher:SetSquadron(sqd_bai, base,  { "su-25-cas" },  10)
        A2GDispatcher:SetSquadronGrouping( sqd_bai, 1 )
        A2GDispatcher:SetSquadronBai(sqd_bai, 250, 600)
        A2GDispatcher:SetSquadronOverhead(sqd_bai, 0.15)
        -- A2GDispatcher:SetSquadronEngageLimit( sqd_bai, 2 )
        A2GDispatcher:SetDefaultTakeoffFromParkingHot( sqd_bai )
        A2GDispatcher:SetSquadronLandingNearAirbase( sqd_bai )

      end
    end
  end
  utils.saveTable(_STATE, BASE_FILE)
end

blue_menus.Init()
red_menus.Init()

if DEBUG_IADS then
  local iadsDebug = redIADS:getDebugSettings()
  iadsDebug.IADSStatus = true
  iadsDebug.samWentDark = false
  iadsDebug.contacts = true
  iadsDebug.radarWentLive = true
  iadsDebug.noWorkingCommmandCenter = true
  iadsDebug.ewRadarNoConnection = true
  iadsDebug.addedEWRadar = true
  redIADS:addRadioMenu()
end


local num_spawns = 1
EH1 = EVENTHANDLER:New()

EH1:HandleEvent(EVENTS.MarkChange)
function EH1:OnEventMarkChange(EventData)
  if EventData.text == 'deploy-heli' or EventData.Text == 'heli-deploy' then
    blue_ground.deployGroundForcesByHeli(EventData.MarkCoordinate)
  end
end

EH1:HandleEvent(EVENTS.MarkRemoved)
function EH1:OnEventMarkRemoved(EventData)
  if EventData.text == "tgt" then
    EventData.MarkCoordinate:Explosion(1000)
    return
  elseif utils.startswith(EventData.text, "kill-") then
    local unit_name = string.sub(EventData.text, 6)
    utils.destroyIfExists(unit_name)
    return
  end

  local new_spawn
  if EventData.text == 'bluetank' then
    new_spawn = SPAWN:NewWithAlias("tank-base", "mark-tank-"..tostring(num_spawns))
  elseif EventData.text == 'redtank' then
    new_spawn = SPAWN:NewWithAlias("redtank-base", "mark-redtank-"..tostring(num_spawns))
  elseif EventData.text == 'rapier' then
    new_spawn = SPAWN:NewWithAlias("rapier-base", "mark-rapier-"..tostring(num_spawns))
  elseif EventData.text == 'hawk' then
    new_spawn = SPAWN:NewWithAlias("hawk-base", "mark-hawk-"..tostring(num_spawns))
  elseif EventData.text == 'red-convoy' then
    SPAWN:NewWithAlias("red-apc-convoy", "red-apc-convoy-"..tostring(num_spawns))
  end

  new_spawn:SpawnFromCoordinate(EventData.MarkCoordinate)
  num_spawns = num_spawns + 1
end

EH1:HandleEvent(EVENTS.BaseCaptured)
function EH1:OnEventBaseCaptured(EventData)
  if _STATE.bases[EventData.PlaceName] == EventData.IniCoalition then
    return
  end
  _STATE.bases[EventData.PlaceName] = EventData.IniCoalition
  if EventData.IniCoalition == coalition.side.RED then
    setBaseRed(EventData.PlaceName, false)
  else
    setBaseBlue(EventData.PlaceName)
  end
  utils.saveTable(_STATE, BASE_FILE)
end


EH1:HandleEvent(EVENTS.Dead)
function EH1:OnEventDead(EventData)
  if EventData.IniCoalition == coalition.side.RED then
    if EventData.IniGroupName ~= nil then
      utils.log("Marking object dead: "..EventData.IniGroupName.." - "..EventData.IniUnitName)
    end
    if _STATE["dead"] == nil then
      _STATE["dead"] = { EventData.IniUnitName }
    else
      table.insert(_STATE["dead"], EventData.IniUnitName)
    end
    utils.saveTable(_STATE, BASE_FILE)
    return
  end

  if EventData.IniUnit and EventData.IniObjectCategory==Object.Category.SCENERY then
    if EventData.IniUnitName ~= nil then
      local Scenery_Point = EventData.initiator:getPoint()
      local Scenery_Coordinate = COORDINATE:NewFromVec3(Scenery_Point)
      local insdata = { x=Scenery_Coordinate.x, y=Scenery_Coordinate.y, z=Scenery_Coordinate.z, id=EventData.IniDCSUnit }
      if _STATE["scenery"] then
        table.insert(_STATE["scenery"], insdata)
      else
        _STATE["scenery"] = insdata
      end
      utils.saveTable(_STATE, BASE_FILE)
      return
    end
    for id, name in pairs(SceneryTargets) do
      if EventData.IniUnitName ~= nil and EventData.IniUnitName == id then
        MESSAGE:New(name.." Destoyed!").ToAll()
        table.remove(SceneryTargets, id)
      end
    end
    utils.saveTable(_STATE, BASE_FILE)
    return
  end
end

