--[[
	Defines a dummy source to position and configure autogrids

	Implemented in separate script because enumerating scene items from
	the same script that defines a Lua source can cause deadlocks.
]]

local AUTOGRID_SOURCE_ID = 'lua_autogrid_source'
local AUTOGRID_SOURCE_SETTING_TAG = 'tag'
local AUTOGRID_SOURCE_SETTING_ALLOW_EMPTY_TAG = 'allow_empty_tag'
local AUTOGRID_SOURCE_SETTING_MAX_ITEMS = 'max_items'
local AUTOGRID_SOURCE_SETTING_ARRANGE_LOCKED_ITEMS = 'arrange_locked_items'
local AUTOGRID_SOURCE_SETTING_TRUE = 'true'
local AUTOGRID_SOURCE_SETTING_FALSE = 'false'
local AUTOGRID_SOURCE_SETTING_DEFAULT = 'default'
local AUTOGRID_SOURCE_SETTING_PADDING = 'padding'
local AUTOGRID_SOURCE_SETTING_RESIZE_METHOD = 'resize_method'
local AUTOGRID_SOURCE_SETTING_RESIZE_METHOD_SCALE_ITEM = 'scale_item'
local AUTOGRID_SOURCE_SETTING_RESIZE_METHOD_SET_BOUNDING_BOX = 'set_bounding_box'

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
	local prop
	local props = obs.obs_properties_create()

	--obs.obs_properties_set_flags(props, obs.OBS_PROPERTIES_DEFER_UPDATE)

	prop = obs.obs_properties_add_text(props, AUTOGRID_SOURCE_SETTING_TAG, 'Source tag', obs.OBS_TEXT_DEFAULT)
	obs.obs_property_set_long_description(prop, 'Only items that contain this #tag anywhere in their name will be arranged in this grid.')

	prop = obs.obs_properties_add_bool(props, AUTOGRID_SOURCE_SETTING_ALLOW_EMPTY_TAG, 'Allow empty tag')
	obs.obs_property_set_long_description(prop, [[If this is enabled and the source tag property is empty, the grid will arrange all items it finds.
This checkbox only exists so that adding an autogrid with default settings to a scene can't accidentally mess up the entire scene.]])

	obs.obs_properties_add_int(props, AUTOGRID_SOURCE_SETTING_MAX_ITEMS, 'Maximum items in grid (-1 = unlimited)', -1, 99999, 1)

	prop = obs.obs_properties_add_list(props, AUTOGRID_SOURCE_SETTING_ARRANGE_LOCKED_ITEMS, 'Arrange locked items', obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(prop, '(Script default)', AUTOGRID_SOURCE_SETTING_DEFAULT)
	obs.obs_property_list_add_string(prop, 'Yes', AUTOGRID_SOURCE_SETTING_TRUE)
	obs.obs_property_list_add_string(prop, 'No', AUTOGRID_SOURCE_SETTING_FALSE)

	obs.obs_properties_add_int(props, AUTOGRID_SOURCE_SETTING_PADDING, 'Padding', 0, 99999, 1)

	prop = obs.obs_properties_add_list(props, AUTOGRID_SOURCE_SETTING_RESIZE_METHOD, 'Resize mode', obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
	obs.obs_property_list_add_string(prop, 'Resize item', AUTOGRID_SOURCE_SETTING_RESIZE_METHOD_SCALE_ITEM)
	obs.obs_property_list_add_string(prop, 'Set bounding box', AUTOGRID_SOURCE_SETTING_RESIZE_METHOD_SET_BOUNDING_BOX)
	obs.obs_property_set_long_description(prop, [[Do not use different resize modes for multiple grids in the same scene.
After changing from "Set bounding box" to "Resize item", bounding boxes must be manually reset.]])

	return props
end

function grid_source.get_defaults(settings)
	obs.obs_data_set_default_int(settings, AUTOGRID_SOURCE_SETTING_MAX_ITEMS, -1)
	obs.obs_data_set_default_string(settings, AUTOGRID_SOURCE_SETTING_ARRANGE_LOCKED_ITEMS, AUTOGRID_SOURCE_SETTING_DEFAULT)
	obs.obs_data_set_default_string(settings, AUTOGRID_SOURCE_SETTING_RESIZE_METHOD, AUTOGRID_SOURCE_SETTING_RESIZE_METHOD_SCALE_ITEM)
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