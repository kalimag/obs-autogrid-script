local AUTOGRID_SETTING_DEBUG = 'debug'
local AUTOGRID_SETTING_UPDATE_ALL_VISIBLE_SCENES = 'update_all_visible_scenes'
local AUTOGRID_SETTING_UPDATE_HOTKEY = 'update_hotkey'
local AUTOGRID_HOTKEY_UPDATE = 'lua_autogrid_update_hotkey'

local AUTOGRID_SOURCE_ID = 'lua_autogrid_source'
local AUTOGRID_SOURCE_SETTING_TAG = 'tag'
local AUTOGRID_SOURCE_SETTING_ALLOW_EMPTY_TAG = 'allow_empty_tag'
local AUTOGRID_SOURCE_SETTING_MAX_ITEMS = 'max_items'
local AUTOGRID_SOURCE_SETTING_PADDING = 'padding'
local AUTOGRID_SOURCE_SETTING_POSITION_METHOD = 'position_method'
local AUTOGRID_SOURCE_SETTING_POSITION_METHOD_SCALE_ITEM = 'scale_item'
local AUTOGRID_SOURCE_SETTING_POSITION_METHOD_SET_BOUNDING_BOX = 'set_bounding_box'

local obs = obslua
local bit = require('bit')

local autogrid = {}
local update_hotkey_id
local debug_logging = true
local update_all_visible_scenes = true



local function float_equal(a, b, delta)
	return math.abs(a - b) <= (delta or 0.001)
end

-- Logging
local function dump(value)
	local visited_tables = {}
	local function _dump(value, indent)
		if type(value) == 'string' then
			return string.format('%q', value)
		elseif type(value) == 'table' and not visited_tables[value] then
			visited_tables[value] = true
			local output = ''
			for k,v in pairs(value) do
				any_items = true
				output = output..string.format('%s%s = %s,\n', string.rep('  ', indent + 1), _dump(k, 0), _dump(v, indent + 1))
			end
			if output == '' then return '{}' end
			return '{\n'..output..string.rep('  ', indent)..'}'
		else
			return tostring(value)
		end
	end
	return _dump(value, 0)
end


local function safe_log_format(format, ...)
	local count = select('#', ...)
	if count == 0 then
		return type(format) == 'string' and format or dump(format)
	end

	local arguments = {...}
	-- deal with nil and boolean values which %s can't handle
	for i = 1, count do
		local argval = arguments[i]
		local argtype = type(argval)
		if argtype == 'boolean' then
			arguments[i] = tostring(argval)
		elseif argtype ~= 'string' and argtype ~= 'number' then
			arguments[i] = dump(argval)
		end
	end

	local success, result = pcall(string.format, format, unpack(arguments))
	if success then
		return result
	else
		return string.format('Log error at "%s": %s', tostring(format), tostring(result))
	end
end

local function log(format, ...)
	print(safe_log_format(format, ...))
end

local function log_warn(format, ...)
	log('WARNING: '..format, ...)
end

local function log_error(format, ...)
	log('ERROR: '..format, ...)
end

local function log_debug(format, ...)
	if debug_logging then
		log(format, ...)
	end
end

local function pcall_log(...)
	local success, error = pcall(...)
	if not success then
		log_error(error)
	end
	return success
end

local function source_tostring(source)
	local source_types = {
		[obs.OBS_SOURCE_TYPE_INPUT] = 'OBS_SOURCE_TYPE_INPUT',
		[obs.OBS_SOURCE_TYPE_FILTER] = 'OBS_SOURCE_TYPE_FILTER',
		[obs.OBS_SOURCE_TYPE_TRANSITION] = 'OBS_SOURCE_TYPE_TRANSITION',
		[obs.OBS_SOURCE_TYPE_SCENE] = 'OBS_SOURCE_TYPE_SCENE',
	}

	if not source then return 'nil' end
	local name = obs.obs_source_get_name(source)
	local sourcetype = obs.obs_source_get_type(source)
	local id = obs.obs_source_get_id(source)
	local showing = obs.obs_source_showing(source)
	local active = obs.obs_source_active(source)
	return safe_log_format('%s %s "%s" showing=%s active=%s', source_types[sourcetype], id, name, showing, active)
end



function autogrid.update_grids()
	if update_all_visible_scenes then
		autogrid.update_visible_scenes()
	else
		local scene = obs.obs_frontend_get_current_preview_scene() or obs.obs_frontend_get_current_scene()
		pcall_log(autogrid.process_scene, scene)
		obs.obs_source_release(scene);
	end
end

function autogrid.update_visible_scenes()
	local scene_sources = obs.obs_frontend_get_scenes()
	if not scene_sources then return end

	for i, scene_source in ipairs(scene_sources) do
		--log_debug('Scene #%d %s', i, source_tostring(scene_source))
		if obs.obs_source_showing(scene_source) then
			pcall_log(autogrid.process_scene, scene_source)
		end
	end
	obs.source_list_release(scene_sources)
end

function autogrid.process_scene(scene_source)
	--log_debug('autogrid.process_scene(%s)', source_tostring(scene_source))

	local scene = obs.obs_group_or_scene_from_source(scene_source)
	if not scene then return end

	local scene_items = obs.obs_scene_enum_items(scene)
	if not scene_items then return end

	local grids = {}
	local handled_items = {}

	for i, item in ipairs(scene_items) do
		local source = obs.obs_sceneitem_get_source(item)
		--log_debug('Item #%d %s', i, source_tostring(source))

		local id = obs.obs_source_get_id(source)
		if id == AUTOGRID_SOURCE_ID and obs.obs_sceneitem_visible(item) then
			table.insert(grids, {
				item = item,
				source = source,
				order = obs.obs_sceneitem_get_order_position(item),
			})
		elseif obs.obs_sceneitem_is_group(item) then
			autogrid.process_scene(source)
		end
	end

	if #grids > 0 then
		-- unsure if order of returned scene items is guaranteed
		table.sort(grids, function(a,b) return a.order > b.order end)

		for _, grid in ipairs(grids) do
			pcall_log(autogrid.process_grid, grid.item, grid.source, scene, scene_items, handled_items)
		end
	end

	obs.sceneitem_list_release(scene_items)
end

function autogrid.process_grid(grid_item, grid_source, scene, scene_items, handled_items)
	local grid_data = autogrid.get_grid_data(grid_source)

	log_debug('process_grid(%s): grid_data=%s', source_tostring(grid_source), grid_data)

	if not grid_data.tag and not grid_data.allow_empty_tag then
		log_warn('Autogrid "%s" has no tag configured and will be ignored', obs.obs_source_get_name(grid_source))
		return
	end

	local tag_pattern = grid_data.tag and ('#'..grid_data.tag..'%f[%A]') -- equivalent to regex \b?

	local grid_item_id = obs.obs_sceneitem_get_id(grid_item)

	local matching_items = {}

	for i, scene_item in ipairs(scene_items) do
		local item_id = obs.obs_sceneitem_get_id(scene_item)

		if item_id ~= grid_item_id and not handled_items[item_id] and obs.obs_sceneitem_visible(scene_item) then 
			local item_source = obs.obs_sceneitem_get_source(scene_item)
			local output_flags = obs.obs_source_get_output_flags(item_source)
			local has_video =  bit.band(output_flags, obs.OBS_SOURCE_VIDEO) ~= 0
			local name = obs.obs_source_get_name(item_source)

			--log_debug('process_grid: item #%d id=%d %s video=%s pattern=%s', i, item_id, source_tostring(item_source), has_video, tag_pattern)

			if has_video and (not tag_pattern or name:match(tag_pattern)) then
				table.insert(matching_items, {
					item = scene_item,
					source = item_source,
					order = obs.obs_sceneitem_get_order_position(scene_item),
					bounds = autogrid.get_item_bounds(scene_item, grid_data.padding),
					name = name,
					item_id = item_id,
				})
			end
		end
	end

	if #matching_items == 0 then return end

	table.sort(matching_items, function(a,b) return a.order > b.order end)

	local grid_bounds = autogrid.get_item_bounds(grid_item)
	autogrid.arrange_scaled(grid_data, grid_bounds, matching_items, handled_items)
end

function autogrid.arrange_scaled(grid_data, grid_bounds, matching_items, handled_items)
	local item_count = math.min(#matching_items, grid_data.max_items)
	if item_count == 0 then return end

	local avg_aspect_ratio = 0
	for i = 1, item_count do
		local item = matching_items[i]
		avg_aspect_ratio = avg_aspect_ratio + (item.bounds.padded_width /item.bounds.padded_height)
	end
	avg_aspect_ratio = avg_aspect_ratio / item_count

	local arrangement = autogrid.get_cell_arrangement(grid_bounds, item_count, avg_aspect_ratio)

	log_debug('arrangement=%s', arrangement)

	local column = 0
	local row = 0
	for i = 1, item_count do
		local item = matching_items[i]

		if grid_data.position_method == AUTOGRID_SOURCE_SETTING_POSITION_METHOD_SET_BOUNDING_BOX then
			autogrid.set_bounding_box(item, column, row, grid_bounds, arrangement.cell_width, arrangement.cell_height, grid_data.padding)
		else
			autogrid.position_item(item, column, row, grid_bounds, arrangement.cell_width, arrangement.cell_height, grid_data.padding)
		end
		handled_items[item.item_id] = true

		column = column + 1
		if column >= arrangement.columns then
			column = 0
			row = row + 1
		end
	end
end

local _position_item_vec2_shared = obs.vec2()
function autogrid.position_item(item, column, row, grid_bounds, cell_width, cell_height, padding)
	local cell_x = grid_bounds.left + cell_width * column
	local cell_y = grid_bounds.top + cell_height * row

	local width_ratio = (cell_width - padding * 2)  / item.bounds.width
	local height_ratio = (cell_height - padding * 2) / item.bounds.height
	local scale_factor = math.min(width_ratio, height_ratio)

	--log_debug('cell_x=%f, cell_y=%f scale_factor=%f', cell_x, cell_y, scale_factor)

	if not float_equal(scale_factor, 1) then
		local scale =_position_item_vec2_shared
		obs.obs_sceneitem_get_scale(item.item, scale)
		scale.x = scale.x * scale_factor
		scale.y = scale.y * scale_factor
		obs.obs_sceneitem_set_scale(item.item, scale)

		if obs.obs_sceneitem_get_bounds_type(item.item) ~= obs.OBS_BOUNDS_NONE then
			obs.obs_sceneitem_get_bounds(item.item, scale)
			scale.x = scale.x * scale_factor
			scale.y = scale.y * scale_factor
			obs.obs_sceneitem_set_bounds(item.item, scale)
		end

		item.bounds = autogrid.get_item_bounds(item.item, padding)
	end

	local offset_x = cell_x - item.bounds.left + (cell_width - item.bounds.width) / 2
	local offset_y = cell_y - item.bounds.top + (cell_height - item.bounds.height) / 2
	if not float_equal(offset_x, 0) or not float_equal(offset_y, 0) then
		local item_pos = _position_item_vec2_shared
		obs.obs_sceneitem_get_pos(item.item, item_pos)
		item_pos.x = item_pos.x + offset_x
		item_pos.y = item_pos.y + offset_y
		log_debug('Adjust "%s" by [%f, %f]', item.name, offset_x, offset_y)
		obs.obs_sceneitem_set_pos(item.item, item_pos)
	end
end

local _override_bounding_box_vec2_shared = obs.vec2()
function autogrid.set_bounding_box(item, column, row, grid_bounds, cell_width, cell_height, padding)
	local cell_x = grid_bounds.left + cell_width * column
	local cell_y = grid_bounds.top + cell_height * row

	if obs.obs_sceneitem_get_bounds_type(item.item) == obs.OBS_BOUNDS_NONE then
		obs.obs_sceneitem_set_bounds_type(item.item, obs.OBS_BOUNDS_SCALE_INNER)
	end

	local bounding_box = _override_bounding_box_vec2_shared
	bounding_box.x = cell_width - padding * 2
	bounding_box.y = cell_height - padding * 2
	obs.obs_sceneitem_set_bounds(item.item, bounding_box)
	item.bounds = autogrid.get_item_bounds(item.item, padding)

	local offset_x = cell_x + padding - item.bounds.left
	local offset_y = cell_y + padding - item.bounds.top
	if not float_equal(offset_x, 0) or not float_equal(offset_y, 0) then
		local item_pos = _position_item_vec2_shared
		obs.obs_sceneitem_get_pos(item.item, item_pos)
		item_pos.x = item_pos.x + offset_x
		item_pos.y = item_pos.y + offset_y
		log_debug('Adjust "%s" by [%f, %f]', item.name, offset_x, offset_y)
		obs.obs_sceneitem_set_pos(item.item, item_pos)
	end
end

function autogrid.get_cell_arrangement(grid_bounds, item_count, avg_aspect_ratio)
	local function get_arrangement(int_columns, int_rows)
		if int_columns * int_rows < item_count then return nil end

		local cell_width = grid_bounds.width / int_columns
		local cell_height = grid_bounds.height / int_rows
		return {
			columns = int_columns,
			rows = int_rows,
			cell_width = cell_width,
			cell_height = cell_height,
			-- how much would we scale an average proportioned item of [width=avg_aspect_ratio height=1] to fit
			avg_scale_factor = math.min(cell_width / avg_aspect_ratio, cell_height --[[/ 1]])
		}
	end

	-- i'm sure there's a smart way to do this but let's just brute force it for now
	local arrangements = {}
	for c = 1, item_count do
		table.insert(arrangements, get_arrangement(c, math.ceil(item_count / c)))
	end

	local best
	for _, arrangement in pairs(arrangements) do
		if not best or arrangement.avg_scale_factor > best.avg_scale_factor then
			best = arrangement
		end
	end

	return best
end

local _get_item_bounds_shared_matrix4 = obs.matrix4()
function autogrid.get_item_bounds(scene_item, padding)
	padding = padding or 0

	local transform = _get_item_bounds_shared_matrix4
	obs.obs_sceneitem_get_box_transform(scene_item, transform)

	local x, y, t = transform.x, transform.y, transform.t
	local tx, ty = t.x, t.y
	local xx, xy = x.x, x.y
	local yx, yy = y.x, y.y

	local bounds = {
		left   = math.min(tx, tx + xx, tx + yx, tx + xx + yx),
		right  = math.max(tx, tx + xx, tx + yx, tx + xx + yx),
		top    = math.min(ty, ty + xy, ty + yy, ty + xy + yy),
		bottom = math.max(ty, ty + xy, ty + yy, ty + xy + yy),
	}
	bounds.width = bounds.right - bounds.left
	bounds.height = bounds.bottom - bounds.top
	bounds.padded_width = bounds.width + padding * 2
	bounds.padded_height = bounds.height + padding * 2
	return bounds
end

function autogrid.get_grid_data(grid_source)
	local settings = obs.obs_source_get_settings(grid_source)
	local data = {
		tag = obs.obs_data_get_string(settings, AUTOGRID_SOURCE_SETTING_TAG),
		allow_empty_tag = obs.obs_data_get_bool(settings, AUTOGRID_SOURCE_SETTING_ALLOW_EMPTY_TAG),
		max_items = obs.obs_data_get_int(settings, AUTOGRID_SOURCE_SETTING_MAX_ITEMS),
		padding = obs.obs_data_get_int(settings, AUTOGRID_SOURCE_SETTING_PADDING),
		position_method = obs.obs_data_get_string(settings, AUTOGRID_SOURCE_SETTING_POSITION_METHOD),
	}
	obs.obs_data_release(settings)

	data.tag = data.tag ~= '' and data.tag:gsub('^#', '')
	data.max_items = data.max_items >= 0 and data.max_items or math.huge

	return data
end

function autogrid.on_update_hotkey(pressed)
	if pressed then
		autogrid.update_grids()
	end
end


function script_load(settings)
	update_hotkey_id = obs.obs_hotkey_register_frontend(AUTOGRID_HOTKEY_UPDATE, 'Update Autogrids', autogrid.on_update_hotkey)
	local update_hotkey_setting = obs.obs_data_get_array(settings, AUTOGRID_SETTING_UPDATE_HOTKEY)
	obs.obs_hotkey_load(update_hotkey_id, update_hotkey_setting)
	obs.obs_data_array_release(update_hotkey_setting)
end

function script_description(settings)
	return [[
Automatically arranges sources in a configurable grid pattern

Set "Update Autogrids" hotkey for ease of use.

Note: The script "autogrid-source.lua" must also be loaded]]
end

function script_properties()
    local props = obs.obs_properties_create()

    obs.obs_properties_add_bool(props, AUTOGRID_SETTING_UPDATE_ALL_VISIBLE_SCENES, 'Update grids in all visible scenes')
    obs.obs_properties_add_bool(props, AUTOGRID_SETTING_DEBUG, 'Debug log (Caution: causes slowdown)')
    obs.obs_properties_add_button(props, 'manual_update', 'Update Grids', autogrid.update_grids)

    return props
end

function script_defaults(settings)
	obs.obs_data_set_default_bool(settings, AUTOGRID_SETTING_UPDATE_ALL_VISIBLE_SCENES, true)
end

function script_save(settings)
	if update_hotkey_id then
		local update_hotkey_setting = obs.obs_hotkey_save(update_hotkey_id)
		obs.obs_data_set_array(settings, AUTOGRID_SETTING_UPDATE_HOTKEY, update_hotkey_setting)
		obs.obs_data_array_release(update_hotkey_setting)
	end
end

function script_update(settings)
	update_all_visible_scenes = obs.obs_data_get_bool(settings, AUTOGRID_SETTING_UPDATE_ALL_VISIBLE_SCENES)
	debug_logging = obs.obs_data_get_bool(settings, AUTOGRID_SETTING_DEBUG)
end