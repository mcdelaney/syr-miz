lfs = require("lfs")
io = require("io")
package.path = MODULE_FOLDER .. "?.lua;" .. package.path
local jsonlib = lfs.writedir() .. "Scripts\\syr-miz\\json.lua"
local json = loadfile(jsonlib)()
logFile = io.open(lfs.writedir()..[[Logs\syr-miz.log]], "w")

local function split(string, sep)
  local fields = {}
  local pattern = string.format("([^%s]+)", sep)
  string:gsub(pattern, function(c)
      fields[#fields + 1] = c
  end)
  return fields
end


local function log(str)
  if str == nil then str = 'nil' end
  if logFile then
      local output = os.date("!%Y-%m-%dT%TZ") .. " | " .. str ..""
      logFile:write(output)
      logFile:flush()
      env.info(output)
  end
end

local file_exists = function(name)
    if lfs.attributes(name) then
        return true
    else
        return false
    end
end


local readState = function (state_file, state_keys)
  log("Reading state...")
  local statefile = io.open(state_file, "r")
  local state = statefile:read("*all")
  statefile:close()
  local saved_game_state = json:decode(state)
  for key, val in pairs(saved_game_state) do
    _STATE[key] = val
  end

end


local function removebyKey(tab, val)
  local i = 1
  for k, _ in pairs (tab) do
      if k == val then
        table.remove(tab, i)
        return tab
      end
      i = i + 1
  end
  if tab == nil then
    return {}
  end
  return tab
end


local tablefind = function(tab, el)
  for index, value in pairs(tab) do
    if value == el then
      return index
    end
  end
end

local removeValueFromTableIfExists = function(tableRef, value)
  local key = tablefind(tableRef, value)
  if key ~= nil then
      log("Removing key for logisticUnit...")
      table.remove(tableRef, key)
  end
end


local saveTable = function(data, file_path)
  local fp = io.open(file_path, 'w')
  fp:write(json:encode(data))
  fp:close()
end


local function destroyIfExists(grp_name, is_static)
  local grp
  if is_static then
    grp = STATIC:FindByName(grp_name, false)
  else
    grp = GROUP:FindByName(grp_name, false)
  end

  if grp ~= nil then
    log('Destroying Object ' .. grp_name)
    grp:Destroy()
  end
end

local function respawnHAWKFromState(_points)
  log("Spawning hawk from state")
  -- spawn HAWK crates around center point
  ctld.spawnCrateAtPoint("blue",551, _points["Hawk pcp"])
  ctld.spawnCrateAtPoint("blue",540, _points["Hawk ln"])
  ctld.spawnCrateAtPoint("blue",545, _points["Hawk sr"])
  ctld.spawnCrateAtPoint("blue",550, _points["Hawk tr"])

  -- spawn a helper unit that will "build" the site
  local _SpawnObject = Spawner( "HawkHelo" )
  local _SpawnGroup = _SpawnObject:SpawnAtPoint({x=_points["Hawk pcp"]["x"], y=_points["Hawk pcp"]["z"]})
  local _unit=_SpawnGroup:getUnit(1)

  -- enumerate nearby crates
  local _crates = ctld.getCratesAndDistance(_unit)
  local _crate = ctld.getClosestCrate(_unit, _crates)
  local terlaaTemplate = ctld.getAATemplate(_crate.details.unit)

  ctld.unpackAASystem(_unit, _crate, _crates, terlaaTemplate)
  _SpawnGroup:destroy()
  log("Done Spawning hawk from state")
end

Spawner = function(grpName)
  local CallBack = {}
  local handleSpawnedGroup = function(spawnedGroup)
      if spawnedGroup and spawnedGroup:getCoalition() == coalition.side.RED then
          --I really want this only to affect red air fighters.
          --I don't think we need to filter by fighters because
          --the larger planes can probably survive in the air
          --for the duration of the mission (~4 hr).
          DisableRTB(spawnedGroup)
      end
  end
  local executeCallBack = function(addedGroup)
      if CallBack.func then
          if not CallBack.args then CallBack.args = {} end
          mist.scheduleFunction(CallBack.func, {addedGroup, unpack(CallBack.args)}, timer.getTime() + 1)
      end
      --Also run any additional handlers when we spawn groups
      handleSpawnedGroup(addedGroup)
  end
  return {
      _spawnAttempts = 0,
      MEName = grpName,
      Spawn = function(self)
          local added_grp = Group.getByName(mist.cloneGroup(grpName, true).name)
          executeCallBack(added_grp)
          return added_grp
      end,
      SpawnAtPoint = function(self, point, noDisperse)
          local vars = {
              groupName = grpName,
              point = point,
              action = "clone",
              disperse = true,
              maxDisp = 1000,
              route = mist.getGroupRoute(grpName, 'task')
          }

          if noDisperse then
              vars.disperse = false
          end

          local new_group = mist.teleportToPoint(vars)
          if new_group then
              local spawned_grp = Group.getByName(new_group.name)
              executeCallBack(spawned_grp)
              return spawned_grp
          else
              if self._spawnAttempts >= 10 then
                  log("Error spawning " .. grpName .. " after " .. self._spawnAttempts .." attempts." )
              else
                  self._spawnAttempts = self._spawnAttempts + 1
                  self:SpawnAtPoint(point, noDisperse)
              end
          end
      end,
      SpawnInZone = function(self, zoneName)
          log("Creating spawn in zone:" .. zoneName)
          local zone = trigger.misc.getZone(zoneName)
          local point = mist.getRandPointInCircle(zone.point, zone.radius)
          return self:SpawnAtPoint(point)
      end,
      OnSpawnGroup = function(self, f, args)
          CallBack.func = f
          CallBack.args = args
      end
  }
end



local init_ctld_units = function(args, coords2D, _country, ctld_unitIndex, key)
  --Spawns the CTLD unit at a given point using the ctld_config templates,
  --returning the unit object so that it can be tracked later.
  --
  --Inputs
  --  args : table
  --    The ctld_config unit template to spawn.
  --    Ex. ctld_config.unit_config["M818 Transport"]
  --  coord2D : table {x,y}
  --    The location to spawn the unit at.
  --  _country : int or str
  --    The country ID that the spawned unit will belong to. Ex. 2='USA'
  --  cltd_unitIndex : table
  --    The table of unit indices to help keep track of unit IDs. This table
  --    will be accessed by keys so that the indices are passed by reference
  --    rather than by value.
  --  key : str
  --    The table entry of cltd_unitIndex that will be incremented after a
  --    unit and group name are assigned.
  --    Ex. key = "Gepard_Index"
  --
  --Outputs
  --  Group_Object : obj
  --    A reference to the spawned group object so that it can be tracked.

      local unitNumber = ctld_unitIndex[key]
      local CTLD_Group = {
          ["visible"] = false,
          ["hidden"] = false,
          ["units"] = {
            [1] = {
              ["type"] = args.type,                           --unit type
              ["name"] = args.name .. unitNumber,             --unit name
              ["heading"] = 0,
              ["playerCanDrive"] = args.playerCanDrive,
              ["skill"] = args.skill,
              ["x"] = coords2D.x,
              ["y"] = coords2D.y,
            },
          },
          ["name"] = args.name .. unitNumber,                 --group name
          ["task"] = {},
          ["category"] = Group.Category.GROUND,
          ["country"] = _country                              --group country
      }

      --Debug
      --trigger.action.outTextForCoalition(2,"CTLD Unit: "..CTLD_Group.name, 30)
      --Increment Index and spawn unit
      ctld_unitIndex[key] = unitNumber + 1
      local _spawnedGroup = mist.dynAdd(CTLD_Group)
      return Group.getByName(_spawnedGroup.name)              --Group object
  end


local function startswith(string, prefix)
    if string:sub(1, #prefix) == prefix then
        return true
    end
    return false
end

local function matchesBaseName(baseName, prefix)
  if prefix == nil then
      return false
  end
  if startswith(baseName, prefix) then
      return true
  end

  -- special case for typos!
  if prefix == "Sukumi" and baseName == "Sukhumi-Babushara" then
      return true
  end

  local baseNameParts = split(baseName, "-")
  local prefixParts = split(prefix, "-")

  if #baseNameParts < #prefixParts then
      return false
  end
  for i = 1, #prefixParts do
      local baseNamePart = baseNameParts[i]
      local groupPrefixPart = prefixParts[i]
      if startswith(baseNamePart, groupPrefixPart) == false then
          return false
      end
  end
  return true
end

local function getBaseAndSideNamesFromGroupName(groupName)
  local blueIndex = string.find(groupName:lower(), " blue ")
  local redIndex = string.find(groupName:lower(), " red ")
  if blueIndex ~= nil then
      return groupName:sub(1, blueIndex - 1), "blue"
  end
  if redIndex ~= nil then
      return groupName:sub(1, redIndex - 1), "red"
  end
end


local function removeUnit (unitName, smoke)
  local grp = GROUP:FindByName(unitName)
  if grp ~= nil then
    grp:Destroy()
  else
    local unit = UNIT:FindByName(unitName)
    if unit then
      local unitPoint = unit:GetCoordinate()
      local unit_country = unit:GetCountry()
      local unit_type = unit:GetTypeName()
      local unit_cat = unit:GetCategoryName()
      local stc = SPAWNSTATIC:NewFromType(unit_type, unit_cat, unit_country)
      unit:Destroy()
      -- env.info("Spawning dead type "..unit:GetTypeName().." - "..unit:GetCategoryName())
      if stc ~= nil then
        stc.InitDead = true
        -- stc:SpawnFromCoordinate(unitPoint)
        env.info("Dead static spawn successful...")
      else
        log("Could not create static unit: "..unit_type.." - "..unit_cat)
      end
      if smoke==true then
        unitPoint:BigSmokeSmall(0.75)
      end
    end
  end
end


local function restoreCtldUnits(_STATE, ctld_config)
  local ctld_unitIndex = ctld_config.unit_index
  for idx, data in ipairs(_STATE["ctld_units"]) do

      local coords2D = { x = data.pos.x, y = data.pos.z}
      local country = 2   --USA

      if data.name == 'mlrs' then
          local key = "M270_Index"
          init_ctld_units(ctld_config.unit_config["MLRS M270"], coords2D, country, ctld_unitIndex, key)
      end

      if data.name == 'M-109' then
          local key = "M109_Index"
          init_ctld_units(ctld_config.unit_config["M109 Paladin"], coords2D, country, ctld_unitIndex, key)
      end

      if data.name == 'abrams' then
          local key = "M1A1_Index"
          init_ctld_units(ctld_config.unit_config["M1A1 Abrams"], coords2D, country, ctld_unitIndex, key)
      end

      if data.name == 'jtac' then
          local key = "JTAC_Index"
          local _spawnedGroup = init_ctld_units(ctld_config.unit_config["HMMWV JTAC"], coords2D, country, ctld_unitIndex, key)

          local _code = table.remove(ctld.jtacGeneratedLaserCodes, 1)
          table.insert(ctld.jtacGeneratedLaserCodes, _code)
          ctld.JTACAutoLase(_spawnedGroup:getName(), _code)
      end

      if data.name == 'ammo' then
          local key = "M818_Index"
          init_ctld_units(ctld_config.unit_config["M818 Transport"], coords2D, country, ctld_unitIndex, key)
      end

      if data.name == 'stinger' then
        local key = "Stinger_Index"
        init_ctld_units(ctld_config.unit_config["Stinger"], coords2D, country, ctld_unitIndex, key)
      end

      if data.name == 'gepard' then
          local key = "Gepard_Index"
          init_ctld_units(ctld_config.unit_config["Flugabwehrkanonenpanzer Gepard"], coords2D, country, ctld_unitIndex, key)
      end

      if data.name == 'vulcan' then
          local key = "Vulcan_Index"
          init_ctld_units(ctld_config.unit_config["M163 Vulcan"], coords2D, country, ctld_unitIndex, key)
      end

      if data.name == 'avenger' then
          local key = "Avenger_Index"
          init_ctld_units(ctld_config.unit_config["M1097 Avenger"], coords2D, country, ctld_unitIndex, key)
      end

      if data.name == 'chaparral' then
          local key = "Chaparral_Index"
          init_ctld_units(ctld_config.unit_config["M48 Chaparral"], coords2D, country, ctld_unitIndex, key)
      end

      if data.name == 'roland' then
          local key = "Roland_Index"
          init_ctld_units(ctld_config.unit_config["Roland ADS"], coords2D, country, ctld_unitIndex, key)
      end

      if data.name == 'ipv' then
        local key = "IPV_Index"
        init_ctld_units(ctld_config.unit_config["IPV LAV-25"], coords2D, country, ctld_unitIndex, key)
    end
  end

  if  _STATE["hawks"] ~= nil then
      for k,v in pairs( _STATE["hawks"]) do
          respawnHAWKFromState(v)
      end
  end
end

local function enumerateCTLD(_STATE)
  local CTLDstate = {}
  log("Enumerating CTLD")
  for _groupname, _groupdetails in pairs(ctld.completeAASystems) do
      local CTLDsite = {}
      for k,v in pairs(_groupdetails) do
          CTLDsite[v['unit']] = v['point']
      end
      CTLDstate[_groupname] = CTLDsite
  end
  _STATE["hawks"] = CTLDstate
  log("Done Enumerating CTLD")
end


local function prune_enemies(Site, name)
  local countTotal=Site:Count()
  local sitesKeep = UTILS.Round(countTotal/100*70, 0)
  local sitesDestroy = countTotal - sitesKeep
  log("Pruning from site " .. name..": "..tostring(sitesDestroy))
    for i = 1, sitesDestroy do
      local grpObj = Site:GetRandom()
      grpObj:Destroy(true)
    end
  log("Total after prune: "..name.." - "..tostring(Site:Count()))
end


local function respawnGroup(grp_name)
  env.info("Respawning group: "..grp_name)
  local group = GROUP:FindByName(grp_name)
  group:Respawn()
  local DeadGroups = mist.utils.deepCopy(_STATE["dead"])
  for _, Dead in pairs(DeadGroups) do
    if startswith(Dead, grp_name) then
      env.info("Removing dead entry for unit: "..Dead)
      for i, Name in pairs(_STATE["dead"]) do
        if Name == Dead then
          table.remove(_STATE["dead"], i)
        end
      end
    end
  end
  for i, val in pairs(_STATE["repairable"]) do
    if val == grp_name then
      table.remove(_STATE["repairable"], i)
    end
  end
  MESSAGE:New( "Red forces have repaired ground unit group: "..grp_name.."!", 10):ToAll()
  saveTable(_STATE, BASE_FILE)
end


local function addRepairable(group_name)
  log("Checking if already marked repairable...")
  local do_ins = true
  for _, val in pairs(_STATE["repairable"]) do
    if val == group_name then
      do_ins = false
    end
  end
  if do_ins == true then
    env.info("Marking group "..group_name.." as repairable...")
    table.insert(_STATE["repairable"], group_name)
  end
end


local function addDeadGroup(group_name)
  local do_ins = true
  for _, existing in pairs(_STATE["deadgroups"]) do
    if existing == group_name then
      do_ins = false
    end
  end
  if do_ins then
    table.insert(_STATE["deadgroups"], group_name)
  end

  for i, val in pairs(_STATE["repairable"]) do
    if val == group_name then
      env.info("Removing group "..group_name.." from repairables...")
      table.remove(_STATE["repairable"], i)
    end
  end

  for i, Mark in pairs(_STATE["marks"]) do
    if Mark["name"] == group_name then
      env.info("Removing marks for: "..group_name)
      table.remove(_STATE["marks"], i)
      _MARKERS[Mark["name"]]:Remove()
    end
  end
  MESSAGE:New(group_name.." has been permanently destroyed!" ,10):ToAll()
end


local function attemptSamRepair()
  log("Attempting sam repair...")
  if _STATE["repairable"] == nil then
    log("No repairable sams found... exiting")
    return
  end

  for i, group in pairs(_STATE["repairable"]) do
    log("Checking for blue units around group: "..group)
    local grp = GROUP:FindByName(group)
    local zone = ZONE_GROUP:New(group, grp, 25000)
    zone:Scan( {Object.Category.UNIT, Object.Category.BASE }, {Unit.Category.AIRPLANE, Unit.Category.GROUND_UNIT, Unit.Category.HELICOPTER})
    if zone:CountScannedCoalitions() == 1 then
      respawnGroup(group)
      return
    else
      log("Scanned coaltions include blue")
    end
  end
  log("No sams found without blue units nearby...")
end


RED_CAP_ATTEMPTS = 1


local function attemptBaseCap()
  log("Evaluating base capture...")
  for _, base in pairs(ReCapBases) do
    local candidate = AIRBASE:FindByName(base)
    if candidate:GetCoalitionName() == "Blue" then
      local zone = ZONE_AIRBASE:New(base, 10000)
      zone:Scan( { Object.Category.UNIT }, { Unit.Category.GROUND_UNIT })
      if zone:GetScannedSetUnit():Count() < 3 then
        log("Creating invasion group to attack base: "..base)
        SPAWN:NewWithAlias("red-basecap", "red-basecap-"..base.."-"..tostring(RED_CAP_ATTEMPTS))
          :InitAirbase( "Damascus", SPAWN.Takeoff.Air)
          :OnSpawnGroup(
            function( SpawnGroup )
                SpawnGroup:TaskRouteToZone(zone, false,  200, FORMATION.Vee)
                -- SpawnGroup:RouteRTB(candidate, 200)
            end
        )
        :Spawn()
        RED_CAP_ATTEMPTS = RED_CAP_ATTEMPTS + 1
        return
      else
        log("Too many blue units inside base zone: "..base)
      end
    else
      log("Base ".. base.." is "..candidate:GetCoalitionName().."...skipping")
    end
  end

end


return {
  file_exists = file_exists,
  restoreCtldUnits = restoreCtldUnits,
  readState = readState,
  tablefind = tablefind,
  saveTable = saveTable,
  prune_enemies = prune_enemies,
  enumerateCTLD = enumerateCTLD,
  removeValueFromTableIfExists = removeValueFromTableIfExists,
  destroyIfExists = destroyIfExists,
  respawnHAWKFromState = respawnHAWKFromState,
  log = log,
  removeUnit = removeUnit,
  startswith = startswith,
  init_ctld_units = init_ctld_units,
  matchesBaseName = matchesBaseName,
  getBaseAndSideNamesFromGroupName = getBaseAndSideNamesFromGroupName,
  removebyKey = removebyKey,
  respawnGroup = respawnGroup,
  addRepairable = addRepairable,
  addDeadGroup = addDeadGroup,
  attemptSamRepair = attemptSamRepair,
  attemptBaseCap = attemptBaseCap,
}