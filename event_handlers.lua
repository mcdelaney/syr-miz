local lfs = require("lfs")
MODULE_FOLDER = lfs.writedir()..[[Scripts\syr-miz\]]
package.path = MODULE_FOLDER .. "?.lua;" .. package.path
local utils = require('utils')
local blue_ground = require('blue_ground')


local num_spawns = 1
EH1 = EVENTHANDLER:New()
EH1:HandleEvent(EVENTS.MarkRemoved)
EH1:HandleEvent(EVENTS.MarkChange)

function EH1:OnEventMarkChange(EventData)
  if EventData.text == 'deploy-heli' then
    blue_ground.deployGroundForcesByHeli(nil, EventData.MarkCoordinate)
  end
end

function EH1:OnEventMarkRemoved(EventData)
  local new_spawn
  if EventData.text == "tgt" then
    EventData.MarkCoordinate:Explosion(1000)
    return
  elseif utils.startswith(EventData.text, "kill-") then
    local unit_name = string.sub(EventData.text, 6)
    utils.destroyIfExists(unit_name)
    return
  end

  if EventData.text == 'blue-ground' then
    new_spawn = SPAWN:NewWithAlias("blue-ground", "blue-ground-"..tostring(num_spawns))
  elseif EventData.text == 'tank' then
    new_spawn = SPAWN:NewWithAlias("tank-base", "mark-tank-"..tostring(num_spawns))
  elseif EventData.text == 'redtank' then
    new_spawn = SPAWN:NewWithAlias("redtank-base", "mark-redtank-"..tostring(num_spawns))
  elseif EventData.text == 'rapier' then
    new_spawn = SPAWN:NewWithAlias("rapier-base", "mark-rapier-"..tostring(num_spawns))
  elseif EventData.text == 'hawk' then
    new_spawn = SPAWN:NewWithAlias("hawk-base", "mark-hawk-"..tostring(num_spawns))
  elseif EventData.text == 'farp' then
    new_spawn = SPAWNSTATIC:NewFromStatic("farp-static")
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
    setBaseRed(EventData.PlaceName)
  else
    setBaseBlue(EventData.PlaceName)
    -- ground.initRedGroundBaseAttack("Damascus",  EventData.PlaceName)
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