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



return {
  file_exists = file_exists,
  readState = readState,
  tablefind = tablefind,
  saveTable = saveTable,
  removeValueFromTableIfExists = removeValueFromTableIfExists,
  destroyIfExists = destroyIfExists,
  log = log,
}