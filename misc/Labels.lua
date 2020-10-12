-- Label parameters
-- Copyright (C) 2018, Eagle Dynamics.



-- labels =  0  -- NONE
-- labels =  1  -- FULL
-- labels =  2  -- ABBREVIATED
labels =  3  -- DOT ONLY

-- Off: No labels are used
-- Full: As we have now
-- Abbreviated: Only red or blue dot and unit type name based on side
-- Dot Only: Only red or blue dot based on unit side



local IS_DOT 		 = labels and labels ==  3
local IS_ABBREVIATED = labels and labels ==  2

AirOn			 		= true
GroundOn 		 		= false
NavyOn		 	 		= false
WeaponOn 		 		= false
labels_format_version 	= 1 -- labels format vesrion
---------------------------------
-- Label text format symbols
-- %N - name of object
-- %D - distance to object
-- %P - pilot name
-- %n - new line
-- %% - symbol '%'
-- %x, where x is not NDPn% - symbol 'x'
-- %C - extended info for vehicle's and ship's weapon systems
------------------------------------------
-- Example
-- labelFormat[5000] = {"Name: %N%nDistance: %D%n Pilot: %P",position,0,0}
-- up to 5km label is:
--       Name: Su-33
--       Distance: 30km
--       Pilot: Pilot1


-- alignment options
--"RightBottom"
--"LeftTop"
--"RightTop"
--"LeftCenter"
--"RightCenter"
--"CenterBottom"
--"CenterTop"
--"CenterCenter"
--position


-- labels font properties {font_file_name, font_size_in_pixels, text_shadow_offset_x, text_shadow_offset_y, text_blur_type}
-- text_blur_type = 0 - none
-- text_blur_type = 1 - 3x3 pixels
-- text_blur_type = 2 - 5x5 pixels
font_properties =  {"DejaVuLGCSans.ttf", 11, 0, 0, 0}

local aircraft_symbol_near  =  "." --U+02C4
local aircraft_symbol_far   =  "." --U+02C4

local ground_symbol_near    = "ˉ"  --U+02C9
local ground_symbol_far     = "ˉ"  --U+02C9

local navy_symbol_near      = "˜"  --U+02DC
local navy_symbol_far       = "˜"  --U+02DC

local weapon_symbol_near    = "ˈ"  --U+02C8
local weapon_symbol_far     = "ˈ"  --U+02C8

local function dot_symbol(blending,opacity)
    return {"˙","CenterBottom", blending or 1.0 , opacity  or 0.1}
end

-- Text shadow color in {red, green, blue, alpha} format, volume from 0 up to 255
-- alpha will by multiplied by opacity value for corresponding distance
local text_shadow_color = {128, 128, 128, 255}
local text_blur_color 	= {0, 0, 255, 255}
local position = "CenterCenter"

local EMPTY = {"", position, 1, 1, 0, 0}

AirFormat = {
--[distance]		= {format, alignment, color_blending_k, opacity, shift_in_pixels_x, shift_in_pixels_y}
[2000]	= EMPTY,
[1000]	= {aircraft_symbol_near			, position	,0.75	, 0.7	, 0, 4 },
[2500]	= {aircraft_symbol_near			, position	,0.50	, 0.7	, 0, 4 },
[5000]	= {aircraft_symbol_near			, position	,0.25	, 0.7	, 0, 4 },
[10000]	= {aircraft_symbol_near			, position	,0.00	, 0.5	, 0, 4 },
[20000]	= {aircraft_symbol_far			, position	,0.00	, 0.25	, 0, 4 },
[30000]	= dot_symbol(0,0.1),
}

GroundFormat = {
--[distance]		= {format , alignment, color_blending_k, opacity, shift_in_pixels_x, shift_in_pixels_y}
[10]	= EMPTY,
[1000]	= {ground_symbol_near			,position	,0.75	, 0.7	, 0, -3 },
[2500]	= {ground_symbol_near			,position	,0.50	, 0.7	, 0, -3 },
[5000]	= {ground_symbol_near			,position	,0.25	, 0.5	, 0, -3 },
[10000]	= {ground_symbol_far			,position	,0.00	, 0.25	, 0, -3 },
[20000]	=  dot_symbol(0.0, 0.1),
}

NavyFormat = {
--[distance]		= {format, alignment, color_blending_k, opacity, shift_in_pixels_x, shift_in_pixels_y}
[10]	= EMPTY,
[5000]	= {navy_symbol_near				,position	,0.75	, 0.7	, 0, -3 },
[7500]	= {navy_symbol_near				,position	,0.50	, 0.7	, 0, -3 },
[10000]	= {navy_symbol_near				,position	,0.25	, 0.7	, 0, -3 },
[10000]	= {navy_symbol_near				,position	,0.00	, 0.5	, 0, -3 },
[20000]	= {navy_symbol_far 				,position	,0.00	, 0.25	, 0, -3 },
[40000]	= dot_symbol(0.0,0.1),
}

WeaponFormat = {
--[distance]		= {format ,alignment, color_blending_k, opacity, shift_in_pixels_x, shift_in_pixels_y}
[5]	    = EMPTY,
[1000]	= {weapon_symbol_near			,position	,0.75	, 0.7	, 0, -3 },
[2500]	= {weapon_symbol_near			,position	,0.50	, 0.7	, 0, -3 },
[5000]	= {weapon_symbol_near			,position	,0.25	, 0.7	, 0, -3 },
[10000]	= {weapon_symbol_far			,position	,0.00	, 0.5	, 0, -3 },
[20000]	= {weapon_symbol_far			,position	,0.00	, 0.25	, 0, -3 },
}

PointFormat = {
[1e10]	= {"%N%n%D", position},
}

-- Colors in {red, green, blue} format, volume from 0 up to 255
ColorAliesSide   = {150, 150, 150}
ColorEnemiesSide = {150, 150, 150}
ColorUnknown     = {150, 150, 150} -- will be blend at distance with coalition color

ShadowColorNeutralSide 	= {0,0,0,0}
ShadowColorAliesSide	= {0,0,0,0}
ShadowColorEnemiesSide 	= {0,0,0,0}
ShadowColorUnknown 		= {0,0,0,0}

BlurColorNeutralSide 	= {50 ,50 ,50 ,255}
BlurColorAliesSide		= {50 ,50 ,50 ,255}
BlurColorEnemiesSide	= {50 ,50 ,50 ,255}
BlurColorUnknown		= {50 ,50 ,50 ,255}
