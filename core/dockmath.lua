--[[
  ModMenu.core.dockmath — viewport fractions for a docked panel. No UMG.
]]

local M = {}

--- rightFrac = thickness-edge gap; widthFrac = thickness; topFrac/bottomFrac = long-axis margins.
---@return { minX: number, maxX: number, minY: number, maxY: number }
function M.PercentRect(config)
    local edge = config.rightFrac or 0.01
    local thick = config.widthFrac or 0.32
    local longMin = config.topFrac or 0
    local longMax = 1.0 - (config.bottomFrac or 0)
    local dock = config.dock
    if dock == "top" then
        return { minX = longMin, maxX = longMax, minY = edge, maxY = edge + thick }
    end
    if dock == "bottom" then
        return {
            minX = longMin,
            maxX = longMax,
            minY = 1.0 - thick - edge,
            maxY = 1.0 - edge,
        }
    end
    if dock == "left" then
        return { minX = edge, maxX = edge + thick, minY = longMin, maxY = longMax }
    end
    return {
        minX = 1.0 - thick - edge,
        maxX = 1.0 - edge,
        minY = longMin,
        maxY = longMax,
    }
end

return M
