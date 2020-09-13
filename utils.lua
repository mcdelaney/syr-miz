lfs = require("lfs")
io = require("io")
package.path = MODULE_FOLDER .. "?.lua;" .. package.path
local jsonlib = lfs.writedir() .. "Scripts\\syr-miz\\json.lua"
local json = loadfile(jsonlib)()
logFile = io.open(lfs.writedir()..[[Logs\syr-miz.log]], "w")



local function log(str)
  if str == nil then str = 'nil' end
  if logFile then
      logFile:write(os.date("!%Y-%m-%dT%TZ") .. " | " .. str .."\r\n")
      logFile:flush()
  end
end

local file_exists = function(name)
    if lfs.attributes(name) then
        return true
    else
        return false
    end
end

local readState = function (state_file)
    log("Reading state...")
    local statefile = io.open(state_file, "r")
    local state = statefile:read("*all")
    statefile:close()
    local saved_game_state = json:decode(state)
    return saved_game_state
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


return {
  file_exists = file_exists,
  readState = readState,
  tablefind = tablefind,
  saveTable = saveTable,
  removeValueFromTableIfExists = removeValueFromTableIfExists,
  destroyIfExists = destroyIfExists,
  respawnHAWKFromState = respawnHAWKFromState,
  log = log,
  init_ctld_units = init_ctld_units,
}