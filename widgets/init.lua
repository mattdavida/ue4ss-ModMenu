--[[
  ModMenu widget registry.

  Add a new type:
    1. Create widgets/<type>.lua exporting { type, validate?, seed?, build, poll?, pollClick?, apply? }
    2. register(require("ModMenu.widgets.<type>")) below
    3. Document fields in README

  widgets/*.lua are auto-bundled; core/ and shell/ still need a MODULES row
  in tools/bundle.mjs.

  ctx fields (build / poll / pollClick / apply):
    values, liveControls, config, umg, Input, ValueKey, SafeCall, IsValid,
    ReclaimMenuInput, EnsureMenuVisible, contentBox, section, item, namePrefix,
    layout (nil or "horizontal" inside a row)
]]

local registry = {} ---@type table<string, table>
local order = {} ---@type string[]

local function register(mod)
    if type(mod) ~= "table" or type(mod.type) ~= "string" then
        error("widgets.init: register() expects a module with .type")
    end
    if registry[mod.type] == nil then
        table.insert(order, mod.type)
    end
    registry[mod.type] = mod
end

register(require("ModMenu.widgets.separator"))
register(require("ModMenu.widgets.label"))
register(require("ModMenu.widgets.button"))
register(require("ModMenu.widgets.checkbox"))
register(require("ModMenu.widgets.dropdown"))
register(require("ModMenu.widgets.number"))
register(require("ModMenu.widgets.textinput"))
register(require("ModMenu.widgets.row"))
register(require("ModMenu.widgets.fold"))

local M = {}

function M.get(typeName)
    return registry[typeName]
end

function M.has(typeName)
    return registry[typeName] ~= nil
end

--- @return string comma-separated type names for error messages
function M.typeList()
    return table.concat(order, "|")
end

return M
