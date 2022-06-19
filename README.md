# obs-autogrid-script

Lua script for OBS that can automatically arrange scene items in a grid-like pattern.


## Usage

For technical reasons the script consists of two files: `autogrid.lua` and `autogrid-source.lua`.
*Both* scripts must be added to OBS (`Tools > Scripts`).

When the scripts are loaded, a new source called "Autogrid" can be added to scenes.
This source does not display or do anything, it exists merely to define an area in
which items should be arranged. It does not matter if a grid is copied, scaled or
stretched.

The script rearranges items when the configurable "Update Autogrids" hotkey or the button
inside the script settings is pressed. Items will be repositioned and scaled over the
grids to maximize their size.

Items are arranged based on their order in the source list. The topmost item will be the
top-left item in the grid. Hidden items are ignored.

Multiple grids can be added to a scene. Items will be placed into the topmost grid that has
a matching filter and has not reached its item limit.

Grids will only arrange items that are in the same scene and at the same level of the
hierarchy as the grid. That is, a grid placed directly in the scene will not arrange items
in groups, and a grid inside a group will only arrange items in the same group. A grid
can arrange the groups themselves.

> **Warning** There is no undo support. Make sure to backup your scene collections in case
> the script breaks or does something you don't intend it to.


### Script properties

**Update grids in all visible scenes:** If this setting is disabled, only grids inside the
currently selected scene (or preview scene in studio mode) will be rearranged.
If this setting is enabled, grids in all visible scenes including nested scenes will be
rearranged.


### Autogrid source properties

**Source tag:** Only items that contain `#tag` in their name will be arranged in this grid.

**Allow empty tag:** If this is enabled and the source tag property is empty, the grid will
arrange all items it finds. This checkbox only exists so that adding an autogrid with default
settings to a scene can't accidentally mess up the entire scene.

**Maximum items:** The maximum number of scene items that will be placed in this grid. Excess
items may be arranged in other grids.

**Padding:** Minimum amount of space around each item in the grid.

**Positioning method - Scale item:** Sets the size of the item to fit inside the grid. If the
item has a bounding box, the bounding box is also resized so that it retains the same proportions.

**Positioning method - Set bounding box:** Sets the bounding box size to the size of the grid cell.
Affected by bounding box properties (type and alignment). Does not work properly on rotated items.

> **Note** Do not use different positioning methods for multiple grids in the same scene, that will
> likely have unwanted results. After changing the setting from *Set bounding box* to *Scale item*,
> you should reset the transforms of all items in the grid.
