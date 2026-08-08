--[[
  ModMenu — shared in-game UMG settings shell for UE4SS Lua mods.

  Usage:
    local ModMenu = require("ModMenu.ModMenu")
    ModMenu.Init({ title = "My Mod Menu", key = Key.F6 })
    ModMenu.Register({
      id = "MyMod",
      title = "My Mod",
      items = {
        { type = "checkbox", id = "enabled", label = "Enabled", default = false,
          onChange = function(on) end },
        { type = "button", id = "run", label = "Do thing",
          onClick = function() end },
        { type = "dropdown", id = "mode", label = "Mode",
          options = { "A", { label = "Bee", value = "b" } },
          default = "A", onChange = function(value) end },
        { type = "dropdown", id = "item", label = "Item", searchable = true,
          placeholder = "Select item...", maxVisible = 12,
          options = { ... }, onChange = function(value) end },
        { type = "label", label = "Hint text" },
        { type = "separator" },
      },
    })
    ModMenu.SetDock("left") -- or Init({ dock = "left" })

  Per-mod shell: each Lua mod that Init()s gets its own panel + hotkey.
  UObject names / viewport Z are allocated via ModRef shared vars so two mods
  never collide on ModMenu_Root_1 under the same GameInstance.

  Dock presets: Left / Right via header button (session only; no free drag).

  Internals: core/ helpers + widgets/ registry (see README.md).
]]

local UEHelpers = require("UEHelpers.UEHelpers")
local Util = require("ModMenu.core.util")
local Umg = require("ModMenu.core.umg")
local Input = require("ModMenu.core.input")
local Options = require("ModMenu.core.options")
local Widgets = require("ModMenu.widgets.init")
local Dropdown = Widgets.get("dropdown")

local ModMenu = {}

local VIEWPORT_Z_BASE = 1000
local POLL_MS = 50

local VIS_VISIBLE = 0
local VIS_COLLAPSED = 1

--- Process-wide keys (ModRef shared vars). Survive hot-reload; do not store tables/functions.
local SHARED_NEXT_INSTANCE = "ModMenu.NextInstanceId"
local SHARED_OPEN_COUNT = "ModMenu.OpenCount"
--- Claim map: ModMenu.KeyClaim.<keyHint> -> instanceTag (string). Warn-only on clash.
local SHARED_KEY_CLAIM_PREFIX = "ModMenu.KeyClaim."

-- Local aliases for shell chrome / public API.
local Log = Util.Log
local IsValid = Util.IsValid
local ToPlainString = Util.ToPlainString
local ValueKey = Util.ValueKey
local SafeCall = Util.SafeCall
local ConsumeMouseClick = Input.ConsumeMouseClick
local WidgetHovered = Input.WidgetHovered
local Construct = Umg.Construct
local StyleText = Umg.StyleText
local SetLabelText = Umg.SetLabelText
local AddSpacer = Umg.AddSpacer
local CreateTextButton = Umg.CreateTextButton
local NormalizeOptions = Options.NormalizeOptions

local config = {
    title = "Mod Menu",
    key = nil, -- set in Init; default Key.F6
    dock = "right", -- "left" | "right" (session preset; no free drag)
    widthFrac = 0.32,
    topFrac = 0.05,
    bottomFrac = 0.05,
    rightFrac = 0.01, -- edge margin used for both left and right docks
    fontTitle = 32,
    fontHint = 20,
    fontItem = 24,
    fontSection = 26,
    fontDropdown = 22,
    instanceId = nil, -- optional human tag for FNames / Live View (e.g. "TestMod")
}

local sections = {} ---@type table[]
local sectionIndexById = {} ---@type table<string, integer>
local values = {} ---@type table<string, any>

local menuRoot = nil
local contentBox = nil ---@type UVerticalBox?
local panelSlot = nil ---@type UCanvasPanelSlot? kept so SetDock can re-anchor without rebuild
local menuOpen = false
local createAttempts = 0
--- Bumped on every BuildContent — ClearChildren does not free FNames; reuse = zombie widgets.
local contentGen = 0
local pollHandle = nil
local initialized = false
local hooksInstalled = false
local keyBound = false

--- Stable per Lua-state ModMenu; allocated once via ModRef (or opts.instanceId).
local instanceSerial = nil ---@type integer?
local instanceTag = nil ---@type string?
local viewportZ = VIEWPORT_Z_BASE
--- True while this instance has incremented SHARED_OPEN_COUNT.
local openCountHeld = false

--- Runtime widgets rebuilt each Open / Register-while-open.
local liveControls = {} ---@type table[]

--- Callbacks fired after the menu finishes opening (feature modules use for lazy init).
local onOpenCallbacks = {} ---@type function[]

local function SharedGet(name)
    if ModRef == nil then
        return nil
    end
    local ok, value = pcall(function()
        return ModRef:GetSharedVariable(name)
    end)
    if ok then
        return value
    end
    return nil
end

local function SharedSet(name, value)
    if ModRef == nil then
        return false
    end
    local ok = pcall(function()
        ModRef:SetSharedVariable(name, value)
    end)
    return ok == true
end

local function SanitizeTag(raw)
    local s = tostring(raw or "mod"):gsub("[^%w_]", "_")
    if s == "" then
        s = "mod"
    end
    -- FName-friendly length; keep Live View readable.
    if #s > 48 then
        s = string.sub(s, 1, 48)
    end
    return s
end

--- Allocate a process-wide instance id so UObject names never collide across mods.
local function EnsureInstanceIdentity()
    if instanceSerial ~= nil and instanceTag ~= nil then
        return
    end

    local nextId = SharedGet(SHARED_NEXT_INSTANCE)
    if type(nextId) ~= "number" then
        nextId = 0
    end
    nextId = nextId + 1
    if not SharedSet(SHARED_NEXT_INSTANCE, nextId) then
        -- No ModRef (unexpected): fall back to a local-only id (single-mod safe).
        nextId = (createAttempts > 0 and createAttempts or 1)
        Log("WARNING: ModRef shared vars unavailable — instance id may collide across mods")
    end
    instanceSerial = nextId

    local tag = config.instanceId
    if tag == nil or tostring(tag) == "" then
        tag = "i" .. tostring(instanceSerial)
    end
    instanceTag = SanitizeTag(tag)
    viewportZ = VIEWPORT_Z_BASE + (instanceSerial - 1)

    Log(string.format(
        "Instance identity serial=%d tag=%q viewportZ=%d",
        instanceSerial,
        instanceTag,
        viewportZ
    ))
end

local function ShellNameSuffix()
    EnsureInstanceIdentity()
    return string.format("%s_%d", instanceTag, createAttempts)
end

local function AdjustOpenCount(delta)
    local n = SharedGet(SHARED_OPEN_COUNT)
    if type(n) ~= "number" then
        n = 0
    end
    n = math.max(0, n + delta)
    SharedSet(SHARED_OPEN_COUNT, n)
    return n
end

local function NoteMenuOpened()
    if openCountHeld then
        return
    end
    AdjustOpenCount(1)
    openCountHeld = true
end

local function NoteMenuClosed()
    if not openCountHeld then
        return AdjustOpenCount(0)
    end
    openCountHeld = false
    return AdjustOpenCount(-1)
end

local function EnsureMenuVisible()
    if menuOpen and IsValid(menuRoot) then
        pcall(function()
            menuRoot:SetVisibility(VIS_VISIBLE)
        end)
    end
end

local function IsMenuVisible()
    if not IsValid(menuRoot) then
        return false
    end
    local ok, vis = pcall(function()
        return menuRoot:GetVisibility()
    end)
    return ok and vis == VIS_VISIBLE
end

local function ValidateItem(item, sectionId, index)
    local prefix = string.format("Register(%s) items[%d]", tostring(sectionId), index)
    if type(item) ~= "table" then
        error(prefix .. " must be a table")
    end
    local t = item.type
    local widget = Widgets.get(t)
    if not widget then
        error(prefix .. " unsupported type '" .. tostring(t) .. "' (" .. Widgets.typeList() .. ")")
    end
    if widget.validate then
        widget.validate(item, sectionId, index)
    end
end

local function ValidateSection(section)
    if type(section) ~= "table" then
        error("Register() expects a section table")
    end
    if section.id == nil or section.id == "" then
        error("Register() section requires .id")
    end
    if type(section.items) ~= "table" then
        error("Register(" .. tostring(section.id) .. ") requires .items array")
    end
    for i, item in ipairs(section.items) do
        ValidateItem(item, section.id, i)
    end
end

local function StopPoll()
    if pollHandle then
        pcall(function()
            CancelDelayedAction(pollHandle)
        end)
        pollHandle = nil
    end
end

--- Show software cursor + GameAndUI (the mode that worked — white cursor).
--- On deactivate: only return to GameOnly when no other ModMenu instance is open.
---@param active boolean
---@param remainingOpenCount integer|nil when deactivating, open count after this instance released
local function SetMenuInputActive(active, remainingOpenCount)
    local pc = UEHelpers.GetPlayerController()
    if not IsValid(pc) then
        return
    end

    local ok, err = pcall(function()
        local lib = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
        if not IsValid(lib) then
            return
        end
        if active then
            pc.bShowMouseCursor = true
            -- EMouseLockMode::DoNotLock = 0
            lib:SetInputMode_GameAndUIEx(pc, menuRoot, 0, false, false)
        else
            local others = remainingOpenCount
            if type(others) ~= "number" then
                others = SharedGet(SHARED_OPEN_COUNT)
                if type(others) ~= "number" then
                    others = 0
                end
            end
            if others > 0 then
                -- Another mod's shell still open — do not yank GameAndUI / cursor.
                pc.bShowMouseCursor = true
                return
            end
            pc.bShowMouseCursor = false
            lib:SetInputMode_GameOnly(pc, false)
        end
    end)
    if not ok then
        Log("SetInputMode skipped: " .. tostring(err))
    end
end

--- Re-apply GameAndUI after game UI interrupts (amber toast, etc.).
--- Only call on open, after clicks, or when we detect the cursor was stolen — not every tick.
local function ReclaimMenuInput()
    if not menuOpen then
        return
    end
    SetMenuInputActive(true)
end

--- Shared ctx for widget build / poll / apply (after ReclaimMenuInput exists).
local function MakeWidgetCtx()
    return {
        values = values,
        liveControls = liveControls,
        config = config,
        umg = Umg,
        Input = Input,
        ValueKey = ValueKey,
        SafeCall = SafeCall,
        IsValid = IsValid,
        ReclaimMenuInput = ReclaimMenuInput,
        EnsureMenuVisible = EnsureMenuVisible,
    }
end

local function NormalizeDock(side)
    local d = string.lower(tostring(side or "right"))
    if d == "left" then
        return "left"
    end
    return "right"
end

local function DockButtonCaption()
    local side = config.dock == "left" and "Left" or "Right"
    return "Dock: " .. side
end

--- Percentage anchors for left or right dock. rightFrac is the edge margin for both sides.
local function ApplyPercentLayout(slot)
    if slot == nil then
        return
    end
    local edge = config.rightFrac or 0.01
    local width = config.widthFrac or 0.32
    local topFrac = config.topFrac
    local bottomFrac = 1.0 - config.bottomFrac
    local minX
    local maxX
    if config.dock == "left" then
        minX = edge
        maxX = edge + width
    else
        minX = 1.0 - width - edge
        maxX = 1.0 - edge
    end

    pcall(function()
        slot:SetAutoSize(false)
        slot:SetAnchors({
            Minimum = { X = minX, Y = topFrac },
            Maximum = { X = maxX, Y = bottomFrac },
        })
        slot:SetOffsets({ Left = 0, Top = 0, Right = 0, Bottom = 0 })
        slot:SetAlignment({ X = 0.0, Y = 0.0 })
    end)
end

local function SyncDockChrome()
    for _, ctrl in ipairs(liveControls) do
        if ctrl.kind == "dock" and ctrl.widget ~= nil then
            -- Recreate Button content — SetText on Button children goes stale after a few flips.
            local serial = Dropdown.nextRowSerial()
            pcall(function()
                local label = Construct(
                    "/Script/UMG.TextBlock",
                    ctrl.widget,
                    "ModMenu_DockLbl_" .. tostring(serial)
                )
                StyleText(label, config.fontItem)
                label:SetText(FText(DockButtonCaption()))
                ctrl.widget:SetContent(label)
                ctrl.label = label
            end)
        end
    end
end

local function SetDockInternal(side)
    config.dock = NormalizeDock(side)
    ApplyPercentLayout(panelSlot)
    SyncDockChrome()
    Log("Dock -> " .. config.dock)
end

local function DestroyShell()
    StopPoll()
    local remaining = NoteMenuClosed()
    if IsValid(menuRoot) then
        pcall(function()
            menuRoot:RemoveFromParent()
        end)
        pcall(function()
            menuRoot:RemoveFromViewport()
        end)
    end
    menuRoot = nil
    contentBox = nil
    panelSlot = nil
    liveControls = {}
    menuOpen = false
    SetMenuInputActive(false, remaining)
end

local function BuildContent()
    if not IsValid(contentBox) then
        return
    end

    pcall(function()
        contentBox:ClearChildren()
    end)
    liveControls = {}

    -- Must change every rebuild. Reusing FNames after ClearChildren resurrects zombies —
    -- category (more option rows) breaks harder than language; both are the same control.
    contentGen = contentGen + 1
    local suffix = tostring(contentGen)

    local title = Construct("/Script/UMG.TextBlock", contentBox, "ModMenu_Title_" .. suffix)
    StyleText(title, config.fontTitle)
    SetLabelText(title, config.title)
    contentBox:AddChildToVerticalBox(title)

    local keyName = "F6"
    if config.key ~= nil then
        -- Best-effort display; Key table values are often the VK name string/number.
        keyName = tostring(config.keyHint or "F6")
    end
    local hint = Construct("/Script/UMG.TextBlock", contentBox, "ModMenu_Hint_" .. suffix)
    StyleText(hint, config.fontHint)
    SetLabelText(hint, "[" .. keyName .. "] toggle menu")
    contentBox:AddChildToVerticalBox(hint)

    -- Shell chrome: flip Left/Right dock without rebuilding the panel.
    local dockBtn, dockLbl = CreateTextButton(
        contentBox,
        "ModMenu_Dock_" .. suffix,
        DockButtonCaption()
    )
    contentBox:AddChildToVerticalBox(dockBtn)
    AddSpacer(contentBox, "ModMenu_DockPad_" .. suffix, 8)
    table.insert(liveControls, {
        kind = "dock",
        widget = dockBtn,
        label = dockLbl,
    })

    AddSpacer(contentBox, "ModMenu_HeadPad_" .. suffix, 16)

    if #sections == 0 then
        local empty = Construct("/Script/UMG.TextBlock", contentBox, "ModMenu_Empty_" .. suffix)
        StyleText(empty, config.fontHint)
        SetLabelText(empty, "No mods registered yet.")
        contentBox:AddChildToVerticalBox(empty)
        return
    end

    for sIndex, section in ipairs(sections) do
        local secTitle = Construct(
            "/Script/UMG.TextBlock",
            contentBox,
            string.format("ModMenu_Sec_%s_%s", section.id, suffix)
        )
        StyleText(secTitle, config.fontSection)
        SetLabelText(secTitle, section.title or section.id)
        contentBox:AddChildToVerticalBox(secTitle)
        AddSpacer(contentBox, string.format("ModMenu_SecPad_%s_%s", section.id, suffix), 8)

        local ctx = MakeWidgetCtx()
        ctx.contentBox = contentBox

        for i, item in ipairs(section.items) do
            local namePrefix = string.format("ModMenu_%s_%s_%d_%s", section.id, tostring(item.id or item.type), i, suffix)
            local widget = Widgets.get(item.type)
            if not widget or not widget.build then
                error("BuildContent: no builder for type " .. tostring(item.type))
            end
            ctx.section = section
            ctx.item = item
            ctx.namePrefix = namePrefix
            widget.build(ctx)
        end

        if sIndex < #sections then
            AddSpacer(contentBox, "ModMenu_Between_" .. section.id .. "_" .. suffix, 18)
        end
    end
end

local function CreateShell()
    EnsureInstanceIdentity()
    createAttempts = createAttempts + 1
    local suffix = ShellNameSuffix()

    local outer = UEHelpers.GetGameInstance()
    if not IsValid(outer) then
        outer = UEHelpers.GetPlayerController()
    end
    if not IsValid(outer) then
        error("No GameInstance or PlayerController to parent the widget")
    end

    -- Names must be unique under GameInstance across ALL mods (ModRef-backed tag/serial).
    local hud = Construct("/Script/UMG.UserWidget", outer, "ModMenu_Root_" .. suffix)
    local tree = Construct("/Script/UMG.WidgetTree", hud, "ModMenu_Tree_" .. suffix)
    hud.WidgetTree = tree

    local canvas = Construct("/Script/UMG.CanvasPanel", tree, "ModMenu_Canvas_" .. suffix)
    tree.RootWidget = canvas

    local border = Construct("/Script/UMG.Border", canvas, "ModMenu_Border_" .. suffix)
    pcall(function()
        border:SetBrushColor({ R = 0.05, G = 0.07, B = 0.12, A = 0.92 })
        border:SetPadding({ Left = 20, Top = 18, Right = 20, Bottom = 18 })
    end)

    local vbox = Construct("/Script/UMG.VerticalBox", border, "ModMenu_VBox_" .. suffix)
    border:SetContent(vbox)

    local slot = canvas:AddChildToCanvas(border)
    panelSlot = slot
    if slot then
        ApplyPercentLayout(slot)
    end

    hud:AddToViewport(viewportZ)
    hud:SetVisibility(VIS_COLLAPSED)

    menuRoot = hud
    contentBox = vbox
    BuildContent()

    Log(string.format(
        "Shell ready name=ModMenu_Root_%s z=%d dock=%s (~%.0f%% x ~%.0f%%). Sections: %d",
        suffix,
        viewportZ,
        tostring(config.dock),
        config.widthFrac * 100,
        (1.0 - config.topFrac - config.bottomFrac) * 100,
        #sections
    ))
end

local function EnsureShell()
    if IsValid(menuRoot) and IsValid(contentBox) then
        return true
    end
    local ok, err = pcall(CreateShell)
    if not ok then
        Log("CreateShell failed: " .. tostring(err))
        DestroyShell()
        return false
    end
    return IsValid(menuRoot)
end

local function PollControls()
    local ctx = MakeWidgetCtx()

    -- Continuous polls (search filter, checkbox state).
    for _, ctrl in ipairs(liveControls) do
        local widget = Widgets.get(ctrl.kind)
        if widget and widget.poll then
            widget.poll(ctrl, ctx)
        end
    end

    local clicked = ConsumeMouseClick()
    if not clicked then
        return
    end

    -- Dropdown option rows take priority over headers (hit-test order).
    for _, ctrl in ipairs(liveControls) do
        if ctrl.kind == "dropdown" and Dropdown.pollOptionClick(ctrl, ctx) then
            return
        end
    end

    for _, ctrl in ipairs(liveControls) do
        if ctrl.kind == "dropdown" and Dropdown.pollHeaderClick(ctrl, ctx) then
            return
        elseif ctrl.kind == "dock" and WidgetHovered(ctrl.widget) then
            SetDockInternal(config.dock == "left" and "right" or "left")
            ReclaimMenuInput()
            return
        elseif ctrl.kind == "button" then
            local widget = Widgets.get("button")
            if widget and widget.pollClick and widget.pollClick(ctrl, ctx) then
                return
            end
        end
    end
end

local function StartPoll()
    StopPoll()
    pollHandle = LoopInGameThreadWithDelay(POLL_MS, function()
        if not menuOpen then
            return
        end
        -- Only reclaim when the game hid our cursor (toast/interrupt) — don't spam SetInputMode.
        local pc = UEHelpers.GetPlayerController()
        if IsValid(pc) and not pc.bShowMouseCursor then
            ReclaimMenuInput()
        end
        PollControls()
    end)
end

local function OpenInternal()
    if not EnsureShell() then
        return
    end
    BuildContent()
    menuRoot:SetVisibility(VIS_VISIBLE)
    menuOpen = true
    NoteMenuOpened()
    SetMenuInputActive(true)
    StartPoll()
    Log(string.format("OPEN tag=%s", tostring(instanceTag)))
    for _, fn in ipairs(onOpenCallbacks) do
        SafeCall(fn)
    end
end

local function CloseInternal()
    StopPoll()
    Input.ClearClickState()
    Dropdown.collapseAll(liveControls, nil)
    if IsValid(menuRoot) then
        menuRoot:SetVisibility(VIS_COLLAPSED)
    end
    menuOpen = false
    local remaining = NoteMenuClosed()
    SetMenuInputActive(false, remaining)
    Log(string.format("CLOSED tag=%s openRemaining=%s", tostring(instanceTag), tostring(remaining)))
end

local function ToggleInternal()
    -- If we think we're open but the shell was hidden/broken by a rebuild, recover to open.
    if menuOpen and IsValid(menuRoot) and IsMenuVisible() then
        CloseInternal()
    else
        OpenInternal()
    end
end

local function InstallHooks()
    if hooksInstalled then
        return
    end
    hooksInstalled = true

    RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
        ExecuteInGameThread(function()
            local wasOpen = menuOpen
            DestroyShell()
            Log("ClientRestart — shell reset")
            if wasOpen then
                OpenInternal()
            end
        end)
    end)
end

--- Advertise our toggle key via ModRef so two mods on the same key log a clear clash.
--- Does not block binding — authors/players decide whether to change keys.
local function ClaimToggleKey(keyHint)
    EnsureInstanceIdentity()
    local hint = tostring(keyHint or "unknown")
    local claimKey = SHARED_KEY_CLAIM_PREFIX .. hint
    local owner = SharedGet(claimKey)
    local me = tostring(instanceTag)

    if type(owner) == "string" and owner ~= "" and owner ~= me then
        -- Single Log() line (Util.Log already prefixes [ModMenu]).
        Log(string.format(
            "KEY CONFLICT: %s already claimed by %q — this menu (%q) shares that bind. "
                .. "Both may toggle together (ok for same-author dual docks); "
                .. "unrelated mods should use different keys.",
            hint,
            owner,
            me
        ))
    elseif type(owner) == "string" and owner == me then
        Log(string.format("Key %s already claimed by this instance (%q)", hint, me))
    else
        Log(string.format("Key %s claimed by %q", hint, me))
    end

    -- Last Init wins the registry slot (still useful: next mod sees the latest owner).
    SharedSet(claimKey, me)
end

local function BindToggleKey()
    if keyBound then
        return
    end
    local key = config.key or Key.F6
    config.key = key
    if config.keyHint == nil and key == Key.F6 then
        config.keyHint = "F6"
    end
    ClaimToggleKey(config.keyHint or tostring(key))
    RegisterKeyBind(key, function()
        ExecuteInGameThread(function()
            ToggleInternal()
        end)
    end)
    keyBound = true
end

--- Initialize / configure this mod's shell. Safe to call multiple times.
---@param opts table|nil
function ModMenu.Init(opts)
    opts = opts or {}
    if opts.title ~= nil then config.title = opts.title end
    if opts.key ~= nil then config.key = opts.key end
    if opts.keyHint ~= nil then config.keyHint = opts.keyHint end
    if opts.widthFrac ~= nil then config.widthFrac = opts.widthFrac end
    if opts.topFrac ~= nil then config.topFrac = opts.topFrac end
    if opts.bottomFrac ~= nil then config.bottomFrac = opts.bottomFrac end
    if opts.rightFrac ~= nil then config.rightFrac = opts.rightFrac end
    if opts.dock ~= nil then config.dock = NormalizeDock(opts.dock) end
    if opts.fontTitle ~= nil then config.fontTitle = opts.fontTitle end
    if opts.fontHint ~= nil then config.fontHint = opts.fontHint end
    if opts.fontItem ~= nil then config.fontItem = opts.fontItem end
    if opts.fontSection ~= nil then config.fontSection = opts.fontSection end
    -- Human-readable FName tag (Live View). Locked after first EnsureInstanceIdentity.
    if opts.instanceId ~= nil and instanceTag == nil then
        config.instanceId = opts.instanceId
    end

    if config.key == nil then
        config.key = Key.F6
        config.keyHint = config.keyHint or "F6"
    end

    EnsureInstanceIdentity()
    Umg.SetDefaults({ fontItem = config.fontItem })
    InstallHooks()
    BindToggleKey()
    Input.InstallMouseClickLatch(function()
        return menuOpen == true
    end)
    initialized = true
    -- Re-apply dock if shell already exists (Init can be called again).
    ApplyPercentLayout(panelSlot)
    SyncDockChrome()
    Log(string.format(
        "Init — title=%q key=%s dock=%s instance=%q serial=%s z=%d",
        tostring(config.title),
        tostring(config.keyHint or config.key),
        tostring(config.dock),
        tostring(instanceTag),
        tostring(instanceSerial),
        viewportZ
    ))
end

--- Process-wide instance tag used in UObject names (e.g. ModMenu_Root_TestMod_1).
---@return string|nil
function ModMenu.GetInstanceId()
    return instanceTag
end

---@return integer|nil
function ModMenu.GetInstanceSerial()
    return instanceSerial
end

--- Pin the panel to the left or right edge (session only; no free drag).
---@param side string "left"|"right"
function ModMenu.SetDock(side)
    SetDockInternal(side)
end

---@return string
function ModMenu.GetDock()
    return config.dock
end

--- Register or replace a mod section.
---@param section table
function ModMenu.Register(section)
    if not initialized then
        ModMenu.Init({})
    end
    ValidateSection(section)

    local copy = {
        id = section.id,
        title = section.title or section.id,
        items = section.items,
    }

    -- Seed defaults into values store.
    for _, item in ipairs(copy.items) do
        local widget = Widgets.get(item.type)
        if widget and widget.seed then
            widget.seed(copy.id, item, values)
        end
    end

    local existing = sectionIndexById[copy.id]
    if existing then
        sections[existing] = copy
        Log("Updated section: " .. copy.id)
    else
        table.insert(sections, copy)
        sectionIndexById[copy.id] = #sections
        Log("Registered section: " .. copy.id .. " (" .. tostring(#copy.items) .. " items)")
    end

    if menuOpen then
        ExecuteInGameThread(function()
            local ok, err = pcall(function()
                if EnsureShell() then
                    BuildContent()
                    EnsureMenuVisible()
                    Input.ClearClickState()
                end
            end)
            if not ok then
                Log("Register rebuild failed: " .. tostring(err))
                EnsureMenuVisible()
            end
        end)
    end
end

---@param sectionId string
---@param itemId string
---@return any
function ModMenu.Get(sectionId, itemId)
    return values[ValueKey(sectionId, itemId)]
end

--- Update a label item's text (by id) in the section + live widget if present.
---@param sectionId string
---@param itemId string
---@param text string
---@return boolean
function ModMenu.SetLabel(sectionId, itemId, text)
    local idx = sectionIndexById[sectionId]
    if not idx then
        return false
    end
    local section = sections[idx]
    for _, item in ipairs(section.items) do
        if item.id == itemId and item.type == "label" then
            item.label = tostring(text)
            local vkey = ValueKey(sectionId, itemId)
            local ctx = MakeWidgetCtx()
            local labelWidget = Widgets.get("label")
            for _, ctrl in ipairs(liveControls) do
                if ctrl.kind == "label" and ctrl.valueKey == vkey and IsValid(ctrl.widget) then
                    if labelWidget and labelWidget.apply then
                        labelWidget.apply(ctrl, item.label, ctx)
                    end
                end
            end
            return true
        end
    end
    return false
end

--- Set a value and sync a live checkbox/dropdown if present.
---@param sectionId string
---@param itemId string
---@param value any
function ModMenu.Set(sectionId, itemId, value)
    local vkey = ValueKey(sectionId, itemId)
    values[vkey] = value
    local ctx = MakeWidgetCtx()
    for _, ctrl in ipairs(liveControls) do
        if ctrl.valueKey == vkey then
            local widget = Widgets.get(ctrl.kind)
            if widget and widget.apply then
                widget.apply(ctrl, value, ctx)
            end
        end
    end
end

--- Replace dropdown options.
--- Searchable dropdowns refresh rows in place when live; others rebuild the panel.
---@param sectionId string
---@param itemId string
---@param options table
---@param selectedValue any|nil pass false to clear selection
---@return boolean
function ModMenu.SetOptions(sectionId, itemId, options, selectedValue)
    local idx = sectionIndexById[sectionId]
    if not idx then
        return false
    end
    local section = sections[idx]
    for _, item in ipairs(section.items) do
        if item.id == itemId and item.type == "dropdown" then
            if type(options) ~= "table" or #options == 0 then
                error("SetOptions requires non-empty options array")
            end
            local list = NormalizeOptions(options)
            item.options = list
            local vkey = ValueKey(sectionId, itemId)
            if selectedValue == false then
                values[vkey] = nil
                item.default = nil
            elseif selectedValue ~= nil then
                local plain = ToPlainString(selectedValue) or selectedValue
                values[vkey] = plain
                item.default = plain
            end

            -- Prefer in-place refresh for searchable lists (category filter, etc.).
            local live = nil
            for _, ctrl in ipairs(liveControls) do
                if ctrl.kind == "dropdown" and ctrl.valueKey == vkey then
                    live = ctrl
                    break
                end
            end

            if menuOpen and live and live.searchable and live.listBox ~= nil then
                Dropdown.refreshLive(live, list, selectedValue, values, vkey)
                Log(string.format(
                    "SetOptions(%s.%s) refreshed searchable list (%d options)",
                    tostring(sectionId),
                    tostring(itemId),
                    #list
                ))
                return true
            end

            if menuOpen then
                ExecuteInGameThread(function()
                    local ok, err = pcall(function()
                        if EnsureShell() then
                            BuildContent()
                            EnsureMenuVisible()
                            Input.ClearClickState()
                        end
                    end)
                    if not ok then
                        Log("SetOptions rebuild failed: " .. tostring(err))
                        EnsureMenuVisible()
                    else
                        Log(string.format(
                            "SetOptions(%s.%s) rebuilt UI with %d options",
                            tostring(sectionId),
                            tostring(itemId),
                            #list
                        ))
                    end
                end)
            end
            return true
        end
    end
    return false
end

--- Register a callback invoked each time the menu opens (after shell is visible).
---@param fn function
function ModMenu.OnOpen(fn)
    if type(fn) ~= "function" then
        error("ModMenu.OnOpen expects a function")
    end
    table.insert(onOpenCallbacks, fn)
end

function ModMenu.Open()
    if not initialized then
        ModMenu.Init({})
    end
    ExecuteInGameThread(OpenInternal)
end

function ModMenu.Close()
    ExecuteInGameThread(CloseInternal)
end

function ModMenu.Toggle()
    if not initialized then
        ModMenu.Init({})
    end
    ExecuteInGameThread(ToggleInternal)
end

function ModMenu.IsOpen()
    return menuOpen == true
end

--- List registered section ids (debug / tooling).
---@return string[]
function ModMenu.ListSections()
    local ids = {}
    for _, section in ipairs(sections) do
        table.insert(ids, section.id)
    end
    return ids
end

return ModMenu
