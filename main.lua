local function file_exists(name) --check if the file already exists for writing
  if lfs.attributes(name) then
  return true
  else
  return false end
end

local function prune_enemies(Site, name)
  local countTotal=Site:Count()
  local sitesKeep = UTILS.Round(countTotal/100*75, 0)
  local sitesDestroy = countTotal - sitesKeep
    for i = 1, sitesDestroy do
      local grpObj = Site:GetRandom()
      env.info("Pruning from site " .. name)
      grpObj:Destroy(true)
    end
end

local SAMS = {}
SAMS["SA6sam"] = SET_GROUP:New():FilterPrefixes("SAM-SA6"):FilterActive(true):FilterOnce()
SAMS["SA2sam"] = SET_GROUP:New():FilterPrefixes("SAM-SA2"):FilterActive(true):FilterOnce()
SAMS["SA3sam"] = SET_GROUP:New():FilterPrefixes("SAM-SA3"):FilterActive(true):FilterOnce()
SAMS["SA10sam"] = SET_GROUP:New():FilterPrefixes("SAM-SA10"):FilterActive(true):FilterOnce()
SAMS["EWR"] = SET_GROUP:New():FilterPrefixes("EWR"):FilterActive(true):FilterStart()

for k, sam in pairs(SAMS) do
  prune_enemies(sam, k)
end

-- env.info("Inserting ctld logistic unit...")
-- table.insert(ctld.logisticUnits, "logistic1")
-- ctld.activatePickupZone("logizone1")

redIADS = SkynetIADS:create('SYRIA')
redIADS:setUpdateInterval(15)
redIADS:addEarlyWarningRadarsByPrefix('EWR')
redIADS:addSAMSitesByPrefix('SAM')
redIADS:getSAMSitesByNatoName('SA-2'):setGoLiveRangeInPercent(80)
redIADS:getSAMSitesByNatoName('SA-3'):setGoLiveRangeInPercent(80)
redIADS:getSAMSitesByNatoName('SA-10'):setGoLiveRangeInPercent(80)
redIADS:activate()

-- Define a SET_GROUP object that builds a collection of groups that define the EWR network.
DetectionSetGroup = SET_GROUP:New()
DetectionSetGroup:FilterPrefixes("EWR")
DetectionSetGroup:FilterStart()
-- Setup the detection and group targets to a 30km range!
Detection = DETECTION_AREAS:New( DetectionSetGroup, 10000 )
A2ADispatcher = AI_A2A_DISPATCHER:New( Detection )
A2ADispatcher:SetEngageRadius(180000) -- 100000 is the default value.
A2ADispatcher:SetGciRadius(100000) -- 200000 is the default value.
A2ADispatcher:SetDefaultTakeoffFromParkingCold()
A2ADispatcher:SetDefaultLandingAtEngineShutdown()
BorderZone = ZONE_POLYGON:New( "RED-BORDER", GROUP:FindByName( "SyAF-GCI" ) )
A2ADispatcher:SetBorderZone( BorderZone )
--SQNs
A2ADispatcher:SetSquadron( "54 Squadron", "Marj Ruhayyil", { "54 Squadron" }, 2 ) --mig23
A2ADispatcher:SetSquadronGrouping( "54 Squadron", 2 )
A2ADispatcher:SetSquadronGci( "54 Squadron", 900, 1200 )

A2ADispatcher:SetSquadron( "698 Squadron", "Al-Dumayr", { "698 Squadron" }, 2 ) --mig29a
A2ADispatcher:SetSquadronGrouping( "698 Squadron", 2 )
A2ADispatcher:SetSquadronGci( "698 Squadron", 900, 1200 )

A2ADispatcher:SetSquadron( "695 Squadron", "An Nasiriyah", { "695 Squadron" }, 2 ) --mig23
A2ADispatcher:SetSquadronGrouping( "695 Squadron", 2 )
A2ADispatcher:SetSquadronGci( "695 Squadron", 900, 1200 )

A2ADispatcher:SetSquadron( "Russia GCI", "Bassel Al-Assad", { "Russia GCI" }, 2 ) --su30
A2ADispatcher:SetSquadronGrouping( "Russia GCI", 2 )
A2ADispatcher:SetSquadronGci( "Russia GCI", 900, 1200 )

--A2ADispatcher:SetTacticalDisplay(true)
A2ADispatcher:Start()

-- add the MOOSE SET_GROUP to the IADS
--redIADS:addMooseSetGroup(DetectionSetGroup)

local Zone={}
Zone.Alpha   = ZONE:New("Aleppo")
Zone.Bravo   = ZONE:New("Golan")
local AllZones=SET_ZONE:New():FilterOnce()

SCHEDULER:New( nil, function()
  local mission=AUFTRAG:NewCAS(Zone.Alpha)
  local fg=FLIGHTGROUP:New("2 Squadron-4")
  fg:AddMission(mission)

  local mission=AUFTRAG:NewCAS(Zone.Alpha)
  local fg=FLIGHTGROUP:New("turkishCAS")
  fg:AddMission(mission)

  local mission=AUFTRAG:NewCAS(Zone.Bravo)
  local fg=FLIGHTGROUP:New("976 Squadron AI")
  fg:AddMission(mission)
end, {},4, 900, .8)

SCHEDULER:New( nil, function()
  local mission=AUFTRAG:NewCAS(Zone.Alpha)
  local fg=FLIGHTGROUP:New("825 Squadron-7")
  fg:AddMission(mission)

  local mission=AUFTRAG:NewCAS(Zone.Alpha)
  local fg=FLIGHTGROUP:New("Warthog-6")
  fg:AddMission(mission)

  local mission=AUFTRAG:NewCAS(Zone.Bravo)
  local fg=FLIGHTGROUP:New("767 Squadron")
  fg:AddMission(mission)
end, {},300, 900, .8)


local ContestedBases = { "Aleppo",  "Taftanaz", "Abu al-Duhur" }
local _NumDefenders = 2
local _ZONES = {}

-- For reach numbered group, for each airbase, 
-- Attempt to find the group, destroying it if the airbase is blue, and activating it 
--  if the base is red.
for _, base in pairs(ContestedBases) do
  table.insert(_ZONES, base)
  _ZONES[base] = {}
  local base_obj = AIRBASE:FindByName(base)
  base_obj:HandleEvent(EVENTS.BaseCaptured)
  function base_obj:OnEventBaseCaptured( EventData )
    MESSAGE:NewType( "Base was captured", MESSAGE.Type.Information ):ToAll()
  end

  if base_obj == nil then
    MESSAGE:New("Invalid airbase name in main.lua: " .. base, 25):ToCoalition( coalition.side.BLUE )
  else
    local base_color = base_obj:GetCoalition()
    for i=1,_NumDefenders do
      local grp_name = base .. "-" .. tostring(i)
      if base_color == coalition.side.BLUE then
        local grp = GROUP:FindByName(grp_name)
        if grp ~= nil then
          env.info('Destroying group ' .. grp_name)

          grp:Destroy()
        else
          env.info("Group does not exist: " .. grp)
        end
      else
        env.info("Initializing group " .. grp_name)
        local spawn_grp = SPAWN:New(grp_name)
        if spawn_grp ~= nil then
          spawn_grp:InitLimit(8, 1):SpawnScheduled(600,.9)
          table.insert(_ZONES[base], grp_name)
        else
          env.info("ERROR! Spawn was nil for: " .. grp_name)
        end
      
      end
    end
  end
end
