local io = require("io")
local lfs = require("lfs")
MODULE_FOLDER = lfs.writedir()..[[Scripts\syr-miz\]]
package.path = MODULE_FOLDER .. "?.lua;" .. package.path

local slotblock = require("slotblock")
local ctld_config = require("ctld_config")
local logging = require("logging")
local utils = require("utils")
local blue_ground = require("blue_ground")
local red_menus = require("red_menus")
local blue_menus = require("blue_menus")
local blue_recon = require("blue_recon")
-- local red_ground = require("red_ground")

_MARKERS = {}
_STATE = {}
_STATE["bases"] = {}
_STATE["slots"] = {}
_STATE["scenery"] = {}
_STATE["ctld_units"] = {}
_STATE["hawks"] = {}
_STATE["dead"] = {}
_STATE["marks"] = {}
_STATE["repairable"] = {}
_STATE["deadgroups"] = {}
_STATE["fobs"] = {}

local INIT = true
local ENABLE_RED_AIR = true
local DEBUG_IADS = false

if MISSION_VERSION == nil  then
  MISSION_VERSION = ""
end
BASE_FILE = lfs.writedir() .. "Scripts\\syr-miz\\syr_state"..MISSION_VERSION ..".json"

-- BASE:TraceClass('A2GDispatcher')
-- BASE:TraceOn()


ATIS = {}

if MISSION_VERSION == "South" then

  ContestedBases = {
    "Ramat David",
    "Haifa",
    "Beirut-Rafic Hariri",
    "Damascus",
    -- "Mezzeh",
  }
  AG_BASES = { "Damascus" }

elseif MISSION_VERSION == "North" then

  ContestedBases = {
    "Ramat David",
    "Incirlik",
    "Aleppo",
    "Abu al-Duhur",
    "Hatay",
    "Haifa",
    "Bassel Al-Assad",
    "Hama"
  }
  AG_BASES = {  }

else
  ContestedBases = {
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

  AG_BASES = { "Damascus" }

end

ReCapBases = {
  "Beirut-Rafic Hariri",
  "Al Qusayr",
  "Hama",
  "Bassel Al-Assad",
  "Abu al-Duhur",
}

SceneryTargets = {"damascus-target-1", "damascus-target-2", "damascus-target-3"}
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

  local reconZone = ZONE:FindByName(baseName.."-reconzone")
  if reconZone ~= nil then
    local spwn = SPAWN:NewWithAlias("blue-recon", "blue-recon-"..baseName)
      :InitLimit(1, 50)
      :InitRepeat()
      :SpawnAtAirbase( AIRBASE:FindByName(baseName), SPAWN.Takeoff.Air, 12000)

    if spwn ~= nil then
      local reconPatrol = AI_PATROL_ZONE:New( reconZone, 12000, 18000, 150, 400 )
      reconPatrol:SetControllable( spwn )
      reconPatrol:__Start( 2 )
      MESSAGE:New("Spawning reaper drone to patrol from "..baseName, 5):ToAll()
    end
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

RedBases = SET_AIRBASE:New():FilterCoalitions("red"):FilterStart()
BlueBases = SET_AIRBASE:New()
AllBases = SET_AIRBASE:New():FilterStart()

local SAMS = {}
SAMS["SA6sam"] = SET_GROUP:New():FilterPrefixes("SAM-SA6"):FilterActive(true):FilterOnce()
SAMS["SA2sam"] = SET_GROUP:New():FilterPrefixes("SAM-SA2"):FilterActive(true):FilterOnce()
SAMS["SA3sam"] = SET_GROUP:New():FilterPrefixes("SAM-SA3"):FilterActive(true):FilterOnce()
SAMS["SA10sam"] = SET_GROUP:New():FilterPrefixes("SAM-SA10"):FilterActive(true):FilterOnce()
SAMS["EWR"] = SET_GROUP:New():FilterPrefixes("EWR"):FilterActive(true):FilterStart()


if utils.file_exists(BASE_FILE) then
  utils.readState(BASE_FILE)
  if _STATE ~= nil then
    MESSAGE:New("State file found... restoring...", 5):ToAll()
    INIT = false
  end
else
  utils.log("No state file exists..")
end

if INIT and MISSION_VERSION == "" then

  for k, sam in pairs(SAMS) do
    pcall(function(_args) utils.prune_enemies(sam, k) end)
  end
else
  for _, unit in pairs(_STATE["dead"]) do
    local smoke = true
    if _STATE["deadgroups"] ~= nil then
      for _, group in pairs(_STATE["deadgroups"]) do
        if utils.startswith(unit, group) then
          smoke = false
        end
      end
    end
    utils.removeUnit(unit, true)
  end

  utils.log( "Destroying previously killed scenery...")
  for i, obj in pairs(_STATE["scenery"]) do
    if obj then
      local unit = Unit.getByName(tostring(obj.id))
      if unit then
        utils.log("Destrying object: "..obj.id)
        unit:destroy(false)
      end
    end
    local vec3 = COORDINATE:New(obj.x, obj.y, obj.z)
    local searchZone = ZONE_RADIUS:New(tostring(i), vec3:GetVec2(), 1)
    searchZone:Scan( Object.Category.SCENERY )
    for _, SceneryData in pairs( searchZone:GetScannedScenery() ) do
      for _, SceneryObject in pairs( SceneryData ) do

        SceneryObject:GetDCSObject():destroy()
        vec3:Explosion(200)
      end
    end
  end

  for i, markCoord in pairs(_STATE["marks"]) do
    _MARKERS[markCoord["name"]] = MARKER:New(COORDINATE:New(markCoord["x"], markCoord["y"], markCoord["z"]),
                                             markCoord["name"]):ToAll()
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

utils.log("Initializing blue awacs units..")
SPAWN:New("awacs-Carrier")
  :InitLimit(1, 0)
  :InitRepeatOnLanding()
  :InitDelayOff()
  :SpawnScheduled(15, 0)

SPAWN:New("awacs-Incirlik")
  :InitLimit(1, 50)
  :InitRepeatOnLanding()
  :InitDelayOff()
  :SpawnScheduled(15, 0)


TexacoStennis = RECOVERYTANKER:New(UNIT:FindByName("CVN-71"), "Texaco")
TexacoStennis:Start()

utils.log("Iads configuration start...")
redIADS = SkynetIADS:create('SYRIA')

commandCenter1 = StaticObject.getByName('RED-HQ-2')
redIADS:addCommandCenter(commandCenter1)
redIADS:setUpdateInterval(10)
redIADS:addEarlyWarningRadarsByPrefix('EWR')
--redIADS:addEarlyWarningRadarsByPrefix("redAWACS")
redIADS:addSAMSitesByPrefix('SAM')
redIADS:getSAMSites():setEngagementZone(SkynetIADSAbstractRadarElement.GO_LIVE_WHEN_IN_SEARCH_RANGE):setGoLiveRangeInPercent(80)
redIADS:getSAMSitesByPrefix("SA-10"):setActAsEW(true)
redIADS:setupSAMSitesAndThenActivate()
-- redIADS:activate()

SPAWN:New("red-recce")
  :InitLimit(1, 50)
  :InitRepeat()
  :OnSpawnGroup(
    function(groupName)
      local reconZone = ZONE:New("Damascus-reconzone")
      local reconPatrol = AI_PATROL_ZONE:New( reconZone, 12000, 18000, 150, 400 )
      reconPatrol:SetControllable( groupName )
      reconPatrol:__Start( 2 )
    end)
  :InitAirbase("Damascus", SPAWN.Takeoff.Air)
  :SpawnScheduled(5, 0.5)
  :SpawnScheduleStart()

DetectionSetGroup = SET_GROUP:New()
  :FilterPrefixes({ "EWR", "redAWACS" })
  :FilterActive()
  :FilterStart()

Detection = DETECTION_AREAS:New( DetectionSetGroup, 30000 )
Detection:Start()


BorderZone = ZONE_POLYGON:New( "RED-BORDER", GROUP:FindByName( "red-border" ) )

RedCommand_AA = COMMANDCENTER:New( GROUP:FindByName( "REDHQ" ), "REDHQ" )

A2ADispatcher = AI_A2A_DISPATCHER:New( Detection )
A2ADispatcher:SetBorderZone( BorderZone )
A2ADispatcher:SetCommandCenter(RedCommand_AA)
A2ADispatcher:SetEngageRadius()
A2ADispatcher:SetGciRadius(200000)
A2ADispatcher:SetIntercept( 10 )
A2ADispatcher:Start()

if AG_BASES ~= nil then

  RedCommand_AG = COMMANDCENTER:New( GROUP:FindByName( "REDHQ-AG" ), "REDHQ-AG" )
  DetectionSetGroup_G = SET_GROUP:New()
    :FilterPrefixes({ "red-recce" })
    :FilterActive()
    :FilterStart()

  Detection_G = DETECTION_AREAS:New( DetectionSetGroup_G, 20000 )
  Detection_G:Start()

  A2GDispatcher = AI_A2G_DISPATCHER:New( Detection_G )
  A2GDispatcher:AddDefenseCoordinate( "ag-base", AIRBASE:FindByName( "Damascus" ):GetCoordinate() )
  A2GDispatcher:SetDefenseReactivityHigh()
  A2GDispatcher:SetDefaultEngageLimit(3)
  A2GDispatcher:SetDefenseRadius( 100000 )

  A2GDispatcher:SetCommandCenter(RedCommand_AA)
  A2GDispatcher:SetDefaultTakeoffInAir(  )
  A2GDispatcher:Start()
end

-- SetCargoInfantry = SET_CARGO:New():FilterTypes( "InfantryType" ):FilterStart()
-- SetAPC = SET_GROUP:New():FilterPrefixes( "red-apc-convoy" ):FilterStart()
-- SetHeli = SET_GROUP:New():FilterPrefixes( "red-helos" ):FilterStart()
-- SetDeployZones = SET_ZONE:New()
-- SetPickupZones = SET_ZONE:New():FilterPrefixes( "redpickup" ):FilterStart()

-- AICargoDispatcherAPC = AI_CARGO_DISPATCHER_APC:New( SetAPC, SetCargoInfantry, SetPickupZones, SetDeployZones)
-- AICargoDispatcherAPC:Start()

-- AICargoDispatcherHelicopter = AI_CARGO_DISPATCHER_HELICOPTER:New(SetHeli, SetCargoInfantry, SetPickupZones, SetDeployZones)
-- AICargoDispatcherHelicopter:Start()

-- blue_ground.InitBlueGroundPlaneDeployer()
blue_ground.InitBlueGroundHeliDeployer()
utils.log("Restoring base ownership...")
for _, base in pairs(ContestedBases) do

  if ENABLE_RED_AIR and _STATE.bases[base] == coalition.side.RED then
    local zone_name = base.."-capzone"
    local zone = ZONE:FindByName(zone_name)
    if zone == nil then
      zone = ZONE_AIRBASE:New(base, 150000):SetName(zone_name)
    end

    utils.log("Creating A2A Cap group from base: "..base)
    local sqd_cap = base.."-cap"
    local cap_grp = 1
    if base == "Damascus" then
      cap_grp = 2
    end
    A2ADispatcher:SetSquadron( sqd_cap, base, { "su-30-cap", "mig-31-cap", "jf-17-cap" } ) --, 10)
    A2ADispatcher:SetSquadronGrouping( sqd_cap, 2 )
    A2ADispatcher:SetSquadronTakeoffFromParkingHot(sqd_cap)
    A2ADispatcher:SetSquadronLandingNearAirbase( sqd_cap )
    A2ADispatcher:SetSquadronCap( sqd_cap, zone, 5000, 10000, 500, 800, 600, 1200, "BARO")

    A2ADispatcher:SetSquadronCapInterval( sqd_cap, cap_grp, 60*3, 60*7, 1)
    A2ADispatcher:SetSquadronCapRacetrack(sqd_cap, 5000, 10000, 90, 180, 5*60, 10*60)

    utils.log("Creating A2A GCI group from base: "..base)
    local sqd_gci = base.."-gci"
    A2ADispatcher:SetSquadron( sqd_gci, base, {"su-30-gci"} )
    A2ADispatcher:SetSquadronGrouping( sqd_gci, 1 )
    A2ADispatcher:SetSquadronOverhead( sqd_gci, 0.5 )
    A2ADispatcher:SetSquadronTakeoffFromParkingHot(sqd_gci)
    A2ADispatcher:SetSquadronGci( sqd_gci, 600, 900 )

    for _, agBase in pairs(AG_BASES) do
      if agBase == base then

        utils.log("Creating A2G SEAD squadron from base: "..base)
        local sqd_sead = base.."-sead"
        A2GDispatcher:SetSquadron(sqd_sead, base,  { "su-34-sead-b", "jf-17-sead" }, 14 ) --"su-34-sead"
        A2GDispatcher:SetSquadronGrouping( sqd_sead, 2 )
        A2GDispatcher:SetSquadronSead(sqd_sead, 400, 600, 5000, 10000)
        A2GDispatcher:SetSquadronOverhead(sqd_sead, 0.25 )
        A2GDispatcher:SetSquadronLandingNearAirbase( sqd_sead )

        -- A2GDispatcher:SetSquadronSeadPatrol( sqd_sead, ZONE_AIRBASE:New("Ramat David", 50000), 5000, 7500, 400, 800, 400, 1200 )
        -- A2GDispatcher:SetSquadronSeadPatrolInterval( sqd_sead, 2, 30, 250 )

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
        A2GDispatcher:SetSquadronOverhead(sqd_bai, 0.25)
        -- A2GDispatcher:SetSquadronEngageLimit( sqd_bai, 2 )
        -- A2GDispatcher:SetDefaultTakeoffFromParkingHot( sqd_bai )
        A2GDispatcher:SetSquadronLandingNearAirbase( sqd_bai )

      end
    end
  end
  utils.saveTable(_STATE, BASE_FILE)
end
BLUEHQ = GROUP:FindByName("BLUEHQ")
BLUECC = COMMANDCENTER:New( BLUEHQ, "BLUEHQ" )
blue_recon.InitBlueReconGroup(BLUECC)

blue_menus.Init()
red_menus.Init()

RedSamRepair = SCHEDULER:New( nil, utils.attemptSamRepair, {}, 25*60, 10*60, 0.25 )
-- BaseCapAttempt = SCHEDULER:New( nil, utils.attemptBaseCap, {}, 10*60, 30*60, 0.25 )

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

utils.log("Initializing event handlers...")
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
  utils.log("Destroying markpoint target...")
  if EventData.text == "tgt" then
    EventData.MarkCoordinate:Explosion(1000)
    return
  elseif utils.startswith(EventData.text, "test-") then
    local grp = GROUP:FindByName(string.sub(EventData.text, 6))
    local unit = grp:GetFirstUnitAlive()
    env.info("Destroying unit: "..unit:GetName())
    local unitPoint = unit:GetCoordinate()
    local unit_country = unit:GetCountry()
    unit:Destroy()
    local stc = SPAWNSTATIC:NewFromType(unit:GetTypeName(), unit:GetCategoryName(), unit_country)
    if stc ~= nil then
      stc.InitDead = true
      stc:SpawnFromCoordinate(unitPoint)
    end
    return
  elseif utils.startswith(EventData.text, "kill-") then
    local unit_name = string.sub(EventData.text, 6)
    utils.destroyIfExists(unit_name)
    return
  elseif EventData.text == "smoke" then
    env.info("Smoking coordinate")
    EventData.MarkCoordinate:BigSmokeHuge(0.75)
    return
  elseif EventData.text == "respawn" then
    utils.attemptSamRepair()
    return
  elseif utils.startswith(EventData.text, "respawn-") then
    local grp_name = string.sub(EventData.text, 9)
    utils.respawnGroup(grp_name)
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
  else
    return
  end

  new_spawn:SpawnFromCoordinate(EventData.MarkCoordinate)
  num_spawns = num_spawns + 1
end

EH1:HandleEvent(EVENTS.BaseCaptured)
function EH1:OnEventBaseCaptured(EventData)
  if _STATE.bases[EventData.PlaceName] == EventData.IniCoalition then
    return
  end
  local not_contested = true
  for _, Base in pairs(ContestedBases) do
    if Base == EventData.PlaceName then
      not_contested = false
    end
  end
  if not_contested == true then
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

    local deadGroup = UNIT:FindByName(EventData.IniUnitName):GetGroup()

    if deadGroup == nil or deadGroup:CountAliveUnits() == 0 then
      -- Add to deadgroups table if not already added
     utils.addDeadGroup(EventData.IniGroupName)
    else
      utils.addRepairable(EventData.IniGroupName)
      env.info("Not removing group.."..deadGroup:GetName().." from table.. has "..deadGroup:CountAliveUnits().." remaining units...")
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

