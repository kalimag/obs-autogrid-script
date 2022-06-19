--[[
	Defines a dummy source to position and configure autogrids

	Implemented in separate script because enumerating scene items from
	the same script that defines a Lua source can cause deadlocks.
]]

local AUTOGRID_SOURCE_ID = 'lua_autogrid_source'
local AUTOGRID_SOURCE_SETTING_TAG = 'tag'
local AUTOGRID_SOURCE_SETTING_ALLOW_EMPTY_TAG = 'allow_empty_tag'
local AUTOGRID_SOURCE_SETTING_MAX_ITEMS = 'max_items'
local AUTOGRID_SOURCE_SETTING_PADDING = 'padding'

local obs = obslua
local bit = require('bit')


grid_source = {
	id = AUTOGRID_SOURCE_ID,
	-- OBS_SOURCE_CUSTOM_DRAW: "This capability flag must be used if the source does not use obs_source_draw() to render a single texture."
	-- is this flag unnecessary if we have *no* draw calls?
	--output_flags = bit.bor(obs.OBS_SOURCE_VIDEO, obs.OBS_SOURCE_CUSTOM_DRAW),
	output_flags = obs.OBS_SOURCE_VIDEO,
}

function grid_source.get_name()
	return 'Autogrid'
end

function grid_source.get_properties()
	local props = obs.obs_properties_create()

	obs.obs_properties_set_flags(props, obs.OBS_PROPERTIES_DEFER_UPDATE)

	obs.obs_properties_add_text(props, AUTOGRID_SOURCE_SETTING_TAG, 'Source tag (only sources with #tag in their name)', obs.OBS_TEXT_DEFAULT)
	obs.obs_properties_add_bool(props, AUTOGRID_SOURCE_SETTING_ALLOW_EMPTY_TAG, 'Allow empty tag (may rearrange everything in the scene)')
	obs.obs_properties_add_int(props, AUTOGRID_SOURCE_SETTING_MAX_ITEMS, 'Maximum items in grid (-1 = unlimited)', -1, 99999, 1)
	obs.obs_properties_add_int(props, AUTOGRID_SOURCE_SETTING_PADDING, 'Padding', 0, 99999, 1)

	return props
end

function grid_source.get_defaults(settings)
	obs.obs_data_set_default_int(settings, AUTOGRID_SOURCE_SETTING_MAX_ITEMS, -1)
end

function grid_source.create(settings, source)
	--local data = {}
	--grid_source.update(data, settings)
	return {}
end

--[[function grid_source.update(data, settings)

end]]

--function grid_source.video_render(data, effect) end

function grid_source.get_width(data)
	return 500
end

function grid_source.get_height(data)
	return 500
end



function script_load(settings)
	obs.obs_register_source(grid_source)
end

function script_description(settings)
	return [[
Adds "Autogrid" source to configure layout of grids

Note: The script autogrid.lua must also be loaded
]]
end