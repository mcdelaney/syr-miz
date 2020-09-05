local lfs = require("lfs")
local module_folder = lfs.writedir()..[[Scripts\syr-miz\]]
package.path = module_folder .. "?.lua;" .. package.path
local jsonlib = lfs.writedir() .. "Scripts\\syr-miz\\json.lua"
local json = loadfile(jsonlib)()


local file_exists = function(name)
    if lfs.attributes(name) then
        return true
    else
        return false
    end
end

local readState = function (state_file)
    env.info("Reading state...")
    local statefile = io.open(state_file, "r")
    local state = statefile:read("*all")
    statefile:close()
    local saved_game_state = json:decode(state)
    for k, v in pairs(saved_game_state) do
      env.info(k .."-"..v)
    end
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
      env.info("Removing key for logisticUnit...")
      table.remove(tableRef, key)
  end
end


local saveTable = function(data, file_path)
  env.info("Writing State to " .. file_path)
  local fp = io.open(file_path, 'w')
  fp:write(json:encode(data))
  fp:close()
  env.info("Done writing state.")
end


return {
  file_exists = file_exists,
  readState = readState,
  tablefind = tablefind,
  saveTable = saveTable,
  removeValueFromTableIfExists = removeValueFromTableIfExists
}