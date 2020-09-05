
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


return { file_exists = file_exists, readState = readState }