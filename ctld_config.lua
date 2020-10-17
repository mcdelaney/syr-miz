local io = require("io")
local lfs = require("lfs")
MODULE_FOLDER = lfs.writedir()..[[Scripts\syr-miz\]]
package.path = MODULE_FOLDER .. "?.lua;" .. package.path

local utils = require("utils")

local ctld_config = {}

ctld_config.unit_config = {
	["MLRS M270"] = {
		["type"] = "MLRS",
		["name"] = "CTLD_MLRS_M270 #",
		["playerCanDrive"] = true,
		["uncontrollable"] = false,
		["skill"] = "Excellent",
	},

	["M109 Paladin"] = {
		["type"] = "M-109",
		["name"] = "CTLD_M109 #",
		["playerCanDrive"] = true,
		["uncontrollable"] = false,
		["skill"] = "Excellent",
	},

	["M1A1 Abrams"] = {
		["type"] = "M-1 Abrams",
		["name"] = "CTLD_M1A1 #",
		["playerCanDrive"] = true,
		["uncontrollable"] = false,
		["skill"] = "Excellent",
	},

	["HMMWV JTAC"] = {
		["type"] = "Hummer",
		["name"] = "CTLD_JTAC #",
		["playerCanDrive"] = true,
		["uncontrollable"] = false,
		["skill"] = "Excellent",
	},

	["M818 Transport"] = {
		["type"] = "M 818",
		["name"] = "CTLD_M818 #",
		["playerCanDrive"] = true,
		["uncontrollable"] = false,
		["skill"] = "Excellent",
	},

	["Flugabwehrkanonenpanzer Gepard"] = {
		["type"] = "Gepard",
		["name"] = "CTLD_Gepard #",
		["playerCanDrive"] = true,
		["uncontrollable"] = false,
		["skill"] = "Excellent",
	},

	["M163 Vulcan"] = {
		["type"] = "Vulcan",
		["name"] = "CTLD_Vulcan #",
		["playerCanDrive"] = true,
		["uncontrollable"] = false,
		["skill"] = "Excellent",
	},

	["M1097 Avenger"] = {
		["type"] = "M1097 Avenger",
		["name"] = "CTLD_Avenger #",
		["playerCanDrive"] = true,
		["uncontrollable"] = false,
		["skill"] = "Excellent",
	},

	["M48 Chaparral"] = {
		["type"] = "M48 Chaparral",
		["name"] = "CTLD_Chaparral #",
		["playerCanDrive"] = true,
		["uncontrollable"] = false,
		["skill"] = "Excellent",
	},
	["Roland ADS"] = {
		["type"] = "Roland ADS",
		["name"] = "CTLD_Roland #",
		["playerCanDrive"] = true,
		["skill"] = "Excellent",
    },
    ["Stinger"] = {
		["type"] = "Soldier stinger",
		["name"] = "CTLD_Stinger #",
		["playerCanDrive"] = false,
		["skill"] = "Excellent",
	},
	["IFV LAV-25"] = {
		["type"] = "IFV LAV-25",
		["name"] = "CTLD_IFV #",
		["playerCanDrive"] = false,
		["skill"] = "Excellent",
	}
}


ctld.addCallback(function(_args)
	if _args.action and _args.action == "unpack" then
		local name
		local groupname = _args.spawnedGroup:getName()

	  if string.match(groupname, "Soldier stinger") then
		  name = "stinger"
		else
		  name = groupname:lower()
		end

		local coord = GROUP:FindByName(groupname):GetCoordinate()
		table.insert(_STATE["ctld_units"], {
				name=name,
				pos={x=coord.x, y=coord.y, z=coord.z}
			})

		utils.enumerateCTLD(_STATE)
		utils.saveTable(_STATE, BASE_FILE)
	end
  end)


ctld_config.unit_index = {
	M270_Index = 1,
	M109_Index = 1,
	M1A1_Index = 1,
	JTAC_Index = 1,
	M818_Index = 1,
	Gepard_Index = 1,
	Vulcan_Index = 1,
	Avenger_Index = 1,
	Chaparral_Index = 1,
    Roland_Index = 1,
	Stinger_Index = 1,
	IFV_Index = 1,
}

return ctld_config

