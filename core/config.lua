--[[
  ModMenu.core.config — default Init table, option merge, small normalizers.
]]

local M = {}

function M.New()
    return {
        title = "Mod Menu",
        key = nil, -- set in Init; default Key.F6
        dock = "right", -- "left" | "right" (session preset; no free drag)
        widthFrac = 0.32,
        topFrac = 0.05,
        bottomFrac = 0.05,
        rightFrac = 0.01, -- edge margin used for both left and right docks
        fontTitle = 22,
        fontHint = 14,
        fontItem = 16,
        fontSection = 18,
        fontDropdown = 15,
        instanceId = nil, -- optional human tag for FNames / Live View (e.g. "TestMod")
        canOpen = nil, -- optional fun(): boolean|boolean,string — gate Open / key toggle open
        ignoreLook = false, -- opt-in: SetIgnoreLookInput while open (mouse-look games)
        inputBackend = "ue4ss", -- "ue4ss" | "engine" (opt-in; no auto-detect)
        keyName = nil, -- Unreal FKey name for engine backend (e.g. "F7"); defaults from keyHint
        consoleCommand = nil, -- optional console command (toggle|open|close)
    }
end

function M.NormalizeDock(side)
    local d = string.lower(tostring(side or "right"))
    if d == "left" then
        return "left"
    end
    return "right"
end

function M.NormalizeInputBackend(value)
    if value == nil then
        return "ue4ss"
    end
    if value == "ue4ss" or value == "engine" then
        return value
    end
    error('ModMenu.Init: inputBackend must be "ue4ss" or "engine"')
end

function M.ResolveEngineKeyName(config)
    if type(config.keyName) == "string" and config.keyName ~= "" then
        return config.keyName
    end
    local hint = tostring(config.keyHint or "")
    if hint:match("^[%w]+$") then
        return hint
    end
    return nil
end

--- Merge Init(opts) into config. ctx.instanceUnlocked: instanceId may still be set.
---@param config table
---@param opts table|nil
---@param ctx { instanceUnlocked?: boolean }|nil
function M.ApplyInit(config, opts, ctx)
    opts = opts or {}
    ctx = ctx or {}

    if opts.title ~= nil then config.title = opts.title end
    if opts.key ~= nil then config.key = opts.key end
    if opts.keyHint ~= nil then config.keyHint = opts.keyHint end
    if opts.widthFrac ~= nil then config.widthFrac = opts.widthFrac end
    if opts.topFrac ~= nil then config.topFrac = opts.topFrac end
    if opts.bottomFrac ~= nil then config.bottomFrac = opts.bottomFrac end
    if opts.rightFrac ~= nil then config.rightFrac = opts.rightFrac end
    if opts.dock ~= nil then config.dock = M.NormalizeDock(opts.dock) end
    if opts.fontTitle ~= nil then config.fontTitle = opts.fontTitle end
    if opts.fontHint ~= nil then config.fontHint = opts.fontHint end
    if opts.fontItem ~= nil then config.fontItem = opts.fontItem end
    if opts.fontSection ~= nil then config.fontSection = opts.fontSection end
    if opts.fontDropdown ~= nil then config.fontDropdown = opts.fontDropdown end
    if opts.canOpen ~= nil then
        if opts.canOpen ~= false and type(opts.canOpen) ~= "function" then
            error("ModMenu.Init: canOpen must be a function or false/nil")
        end
        config.canOpen = (type(opts.canOpen) == "function") and opts.canOpen or nil
    end
    if opts.ignoreLook ~= nil then
        config.ignoreLook = opts.ignoreLook == true
    end
    if opts.inputBackend ~= nil then
        config.inputBackend = M.NormalizeInputBackend(opts.inputBackend)
    end
    if opts.keyName ~= nil then
        if type(opts.keyName) ~= "string" or opts.keyName == "" then
            error("ModMenu.Init: keyName must be a non-empty string")
        end
        config.keyName = opts.keyName
    end
    if opts.consoleCommand ~= nil then
        if opts.consoleCommand == false or opts.consoleCommand == "" then
            config.consoleCommand = nil
        elseif type(opts.consoleCommand) ~= "string" then
            error("ModMenu.Init: consoleCommand must be a string or false")
        else
            config.consoleCommand = opts.consoleCommand
        end
    end
    -- Human-readable FName tag (Live View). Locked after first EnsureInstanceIdentity.
    if opts.instanceId ~= nil and ctx.instanceUnlocked then
        config.instanceId = opts.instanceId
    end

    if config.key == nil then
        config.key = Key.F6
        config.keyHint = config.keyHint or "F6"
    end
    config.inputBackend = M.NormalizeInputBackend(config.inputBackend)
end

return M
