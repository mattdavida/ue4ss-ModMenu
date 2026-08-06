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

  Singleton shell: one panel / one hotkey; mods Register sections into it.
  Dock presets: Left / Right via header button (session only; no free drag).
]]

local UEHelpers = require("UEHelpers.UEHelpers")
local Util = require("ModMenu.core.util")
local Umg = require("ModMenu.core.umg")
local Input = require("ModMenu.core.input")
local Options = require("ModMenu.core.options")

local ModMenu = {}

local VIEWPORT_Z = 1000
local POLL_MS = 50

local VIS_VISIBLE = 0
local VIS_COLLAPSED = 1

local dropdownRowSerial = 0 -- unique FNames when rebuilding filtered option rows

-- Local aliases — same call sites as pre-extract (Phase 1: core/ only).
local Log = Util.Log
local IsValid = Util.IsValid
local ToPlainString = Util.ToPlainString
local ValueKey = Util.ValueKey
local SafeCall = Util.SafeCall
local ConsumeMouseClick = Input.ConsumeMouseClick
local IgnoreClicks = Input.IgnoreClicks
local WidgetHovered = Input.WidgetHovered
local Construct = Umg.Construct
local StyleText = Umg.StyleText
local SetLabelText = Umg.SetLabelText
local AddSpacer = Umg.AddSpacer
local CreateLabeledToggle = Umg.CreateLabeledToggle
local CreateTextButton = Umg.CreateTextButton
local NormalizeOptions = Options.NormalizeOptions
local OptionMatchesFilter = Options.OptionMatchesFilter
local GetWidgetPlainText = Options.GetWidgetPlainText

local SUPPORTED_TYPES = {
    checkbox = true,
    button = true,
    dropdown = true,
    label = true,
    separator = true,
}

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

--- Runtime widgets rebuilt each Open / Register-while-open.
local liveControls = {} ---@type table[]

--- Callbacks fired after the menu finishes opening (feature modules use for lazy init).
local onOpenCallbacks = {} ---@type function[]

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

local function CheckboxCaption(item, isOn)
    if item.showState == false then
        return item.label
    end
    return string.format("%s: %s", item.label, isOn and "ON" or "OFF")
end

local function ValidateItem(item, sectionId, index)
    local prefix = string.format("Register(%s) items[%d]", tostring(sectionId), index)
    if type(item) ~= "table" then
        error(prefix .. " must be a table")
    end
    local t = item.type
    if not SUPPORTED_TYPES[t] then
        error(prefix .. " unsupported type '" .. tostring(t) .. "' (checkbox|button|dropdown|label|separator)")
    end
    if t == "separator" then
        return
    end
    if t == "label" then
        if item.label == nil then
            error(prefix .. " label requires .label")
        end
        return
    end
    if item.id == nil or item.id == "" then
        error(prefix .. " requires .id")
    end
    if item.label == nil then
        error(prefix .. " requires .label")
    end
    if t == "checkbox" and item.onChange ~= nil and type(item.onChange) ~= "function" then
        error(prefix .. " onChange must be a function")
    end
    if t == "button" and item.onClick ~= nil and type(item.onClick) ~= "function" then
        error(prefix .. " onClick must be a function")
    end
    if t == "dropdown" then
        if type(item.options) ~= "table" or #item.options == 0 then
            error(prefix .. " dropdown requires non-empty .options array")
        end
        local ok, err = pcall(NormalizeOptions, item.options)
        if not ok then
            error(prefix .. " " .. tostring(err))
        end
        if item.onChange ~= nil and type(item.onChange) ~= "function" then
            error(prefix .. " onChange must be a function")
        end
        if item.maxVisible ~= nil and (type(item.maxVisible) ~= "number" or item.maxVisible < 1) then
            error(prefix .. " maxVisible must be a positive number")
        end
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
local function SetMenuInputActive(active)
    local pc = UEHelpers.GetPlayerController()
    if not IsValid(pc) then
        return
    end
    pc.bShowMouseCursor = active and true or false

    local ok, err = pcall(function()
        local lib = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
        if not IsValid(lib) then
            return
        end
        if active then
            -- EMouseLockMode::DoNotLock = 0
            lib:SetInputMode_GameAndUIEx(pc, menuRoot, 0, false, false)
        else
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
            dropdownRowSerial = dropdownRowSerial + 1
            pcall(function()
                local label = Construct(
                    "/Script/UMG.TextBlock",
                    ctrl.widget,
                    "ModMenu_DockLbl_" .. tostring(dropdownRowSerial)
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

local LIGHT_ROW_BG = { R = 0.88, G = 0.90, B = 0.94, A = 1.0 }
local LIGHT_ROW_TEXT = { R = 0.06, G = 0.07, B = 0.10, A = 1.0 }
local HEADER_BG = { R = 0.22, G = 0.28, B = 0.40, A = 1.0 }
local HEADER_TEXT = { R = 0.98, G = 0.98, B = 1.0, A = 1.0 }
--- Visible viewport height for dropdown option lists (scroll for the rest).
local DROPDOWN_LIST_MAX_HEIGHT = 320
--- Soft cap so a full unfiltered DB cannot spawn thousands of buttons at once.
local DROPDOWN_SEARCHABLE_MAX_ROWS = 400

--- Rebuild visible option rows (full list for plain dropdowns; filtered cap for searchable).
local function RebuildDropdownRows(ctrl)
    if ctrl == nil or ctrl.listBox == nil then
        return
    end
    pcall(function()
        ctrl.listBox:ClearChildren()
    end)
    ctrl.optionRows = {}

    local maxVisible = ctrl.maxVisible or 12
    local filter = ctrl.searchFilter or ""
    local matched = 0
    local shown = 0

    for _, opt in ipairs(ctrl.list or {}) do
        if OptionMatchesFilter(opt.label, filter) then
            matched = matched + 1
            if shown < maxVisible then
                shown = shown + 1
                dropdownRowSerial = dropdownRowSerial + 1
                local btn, lbl = CreateTextButton(
                    ctrl.listBox,
                    ctrl.namePrefix .. "_Opt" .. tostring(dropdownRowSerial),
                    opt.label,
                    LIGHT_ROW_BG,
                    LIGHT_ROW_TEXT,
                    config.fontDropdown
                )
                ctrl.listBox:AddChildToVerticalBox(btn)
                table.insert(ctrl.optionRows, {
                    button = btn,
                    label = lbl,
                    optLabel = opt.label,
                    optValue = opt.value,
                })
            end
        end
    end

    if ctrl.scrollBox ~= nil then
        pcall(function()
            ctrl.scrollBox:ScrollToStart()
        end)
    end

    if ctrl.moreLabel ~= nil then
        local extra = matched - shown
        if extra > 0 then
            SetLabelText(ctrl.moreLabel, string.format("…%d more — type to narrow", extra))
            pcall(function()
                ctrl.moreLabel:SetVisibility(VIS_VISIBLE)
            end)
        elseif matched == 0 then
            SetLabelText(ctrl.moreLabel, "No matches")
            pcall(function()
                ctrl.moreLabel:SetVisibility(VIS_VISIBLE)
            end)
        else
            pcall(function()
                ctrl.moreLabel:SetVisibility(VIS_COLLAPSED)
            end)
        end
    end
end

--- Reusable select. searchable=true → filter box + scrollable rows.
--- Value TextBlock is a sibling of the header button (Button-child SetText goes stale).
local function CreateDropdown(outer, namePrefix, options, selectedValue, dropOpts)
    dropOpts = dropOpts or {}
    local searchable = dropOpts.searchable == true
    local placeholder = dropOpts.placeholder or "Select..."
    local maxVisible = dropOpts.maxVisible
        or (searchable and DROPDOWN_SEARCHABLE_MAX_ROWS or 9999)
    local listMaxHeight = dropOpts.listMaxHeight or DROPDOWN_LIST_MAX_HEIGHT
    local allowEmpty = dropOpts.allowEmpty == true or searchable or dropOpts.placeholder ~= nil

    local list, labelToValue, valueToLabel = NormalizeOptions(options)
    selectedValue = ToPlainString(selectedValue) or selectedValue
    local selectedLabel = selectedValue ~= nil and valueToLabel[selectedValue] or nil
    if selectedLabel == nil and #list > 0 and not allowEmpty then
        selectedLabel = list[1].label
        selectedValue = list[1].value
    end
    if selectedLabel == nil then
        selectedLabel = placeholder
        selectedValue = nil
    end

    local root = Construct("/Script/UMG.VerticalBox", outer, namePrefix .. "_Root")

    -- Traditional select: one button, value left + arrow right on the same row.
    local headerBtn = Construct("/Script/UMG.Button", root, namePrefix .. "_Header_Btn")
    pcall(function()
        headerBtn:SetBackgroundColor(HEADER_BG)
    end)
    local headerRow = Construct("/Script/UMG.HorizontalBox", headerBtn, namePrefix .. "_HeaderRow")

    local valueLabel = Construct("/Script/UMG.TextBlock", headerRow, namePrefix .. "_Value")
    StyleText(valueLabel, config.fontDropdown, HEADER_TEXT)
    SetLabelText(valueLabel, tostring(selectedLabel))
    local valueSlot = headerRow:AddChildToHorizontalBox(valueLabel)
    pcall(function()
        -- ESlateSizeRule::Fill = 1 so the label takes remaining width.
        valueSlot:SetSize({ SizeRule = 1, Value = 1.0 })
        valueSlot:SetPadding({ Left = 10, Top = 8, Right = 6, Bottom = 8 })
        valueSlot:SetVerticalAlignment(2) -- Center
    end)

    local arrowLabel = Construct("/Script/UMG.TextBlock", headerRow, namePrefix .. "_Arrow")
    StyleText(arrowLabel, config.fontDropdown, HEADER_TEXT)
    SetLabelText(arrowLabel, "▼")
    local arrowSlot = headerRow:AddChildToHorizontalBox(arrowLabel)
    pcall(function()
        arrowSlot:SetSize({ SizeRule = 0, Value = 0.0 }) -- Auto
        arrowSlot:SetPadding({ Left = 4, Top = 8, Right = 10, Bottom = 8 })
        arrowSlot:SetVerticalAlignment(2)
    end)

    pcall(function()
        headerBtn:SetContent(headerRow)
    end)
    root:AddChildToVerticalBox(headerBtn)

    local optionsBox = Construct("/Script/UMG.VerticalBox", root, namePrefix .. "_Opts")
    pcall(function()
        optionsBox:SetVisibility(VIS_COLLAPSED)
    end)

    local searchBox = nil
    if searchable then
        -- Match option-row colors: light field + dark typed text (white-on-light was unreadable).
        local searchBorder = Construct("/Script/UMG.Border", optionsBox, namePrefix .. "_SearchBorder")
        pcall(function()
            searchBorder:SetBrushColor(LIGHT_ROW_BG)
            searchBorder:SetPadding({ Left = 8, Top = 6, Right = 8, Bottom = 6 })
        end)
        searchBox = Construct("/Script/UMG.EditableTextBox", searchBorder, namePrefix .. "_Search")
        pcall(function()
            searchBox:SetHintText(FText("Type to filter..."))
            searchBox:SetText(FText(""))
            searchBox:SetForegroundColor(LIGHT_ROW_TEXT)
        end)
        pcall(function()
            local style = searchBox.WidgetStyle
            if style == nil then
                return
            end
            local dark = LIGHT_ROW_TEXT
            local hint = { R = 0.35, G = 0.38, B = 0.45, A = 1.0 }
            local bg = LIGHT_ROW_BG
            if style.ForegroundColor ~= nil then
                style.ForegroundColor = { SpecifiedColor = dark, ColorUseRule = 0 }
            end
            if style.BackgroundColor ~= nil then
                style.BackgroundColor = bg
            end
            if style.FocusedForegroundColor ~= nil then
                style.FocusedForegroundColor = { SpecifiedColor = dark, ColorUseRule = 0 }
            end
            if style.TextStyle ~= nil then
                if style.TextStyle.ColorAndOpacity ~= nil then
                    style.TextStyle.ColorAndOpacity = { SpecifiedColor = dark, ColorUseRule = 0 }
                end
                if style.TextStyle.Font ~= nil and style.TextStyle.Font.Size ~= nil then
                    style.TextStyle.Font.Size = config.fontDropdown
                end
            end
            if style.HintTextStyle ~= nil then
                if style.HintTextStyle.ColorAndOpacity ~= nil then
                    style.HintTextStyle.ColorAndOpacity = { SpecifiedColor = hint, ColorUseRule = 0 }
                end
                if style.HintTextStyle.Font ~= nil and style.HintTextStyle.Font.Size ~= nil then
                    style.HintTextStyle.Font.Size = config.fontDropdown
                end
            end
        end)
        pcall(function()
            searchBorder:SetContent(searchBox)
        end)
        optionsBox:AddChildToVerticalBox(searchBorder)
        AddSpacer(optionsBox, namePrefix .. "_SearchPad", 6)
    end

    -- SizeBox caps viewport height; ScrollBox lets the user reach rows below the fold.
    local sizeBox = Construct("/Script/UMG.SizeBox", optionsBox, namePrefix .. "_ListSize")
    pcall(function()
        sizeBox:SetMaxDesiredHeight(listMaxHeight)
    end)
    local scrollBox = Construct("/Script/UMG.ScrollBox", sizeBox, namePrefix .. "_Scroll")
    pcall(function()
        -- EConsumeMouseWheel::Always when focused/hovered — best-effort across builds.
        scrollBox:SetAnimateWheelScrolling(true)
        scrollBox:SetAlwaysShowScrollbar(true)
        scrollBox:SetAllowOverscroll(false)
        if scrollBox.SetConsumeMouseWheel then
            scrollBox:SetConsumeMouseWheel(1)
        end
        if scrollBox.SetScrollbarThickness then
            scrollBox:SetScrollbarThickness({ X = 8, Y = 8 })
        end
    end)
    pcall(function()
        sizeBox:SetContent(scrollBox)
    end)

    local listBox = Construct("/Script/UMG.VerticalBox", scrollBox, namePrefix .. "_List")
    pcall(function()
        scrollBox:AddChild(listBox)
    end)
    optionsBox:AddChildToVerticalBox(sizeBox)

    local moreLabel = nil
    if searchable then
        moreLabel = Construct("/Script/UMG.TextBlock", optionsBox, namePrefix .. "_More")
        StyleText(moreLabel, config.fontHint, { R = 0.7, G = 0.75, B = 0.85, A = 1.0 })
        SetLabelText(moreLabel, "")
        pcall(function()
            moreLabel:SetVisibility(VIS_COLLAPSED)
        end)
        optionsBox:AddChildToVerticalBox(moreLabel)
    end

    root:AddChildToVerticalBox(optionsBox)

    local picker = {
        namePrefix = namePrefix,
        list = list,
        labelToValue = labelToValue,
        valueToLabel = valueToLabel,
        selectedValue = selectedValue,
        selectedLabel = selectedLabel,
        placeholder = placeholder,
        searchable = searchable,
        maxVisible = maxVisible,
        searchFilter = "",
        searchBox = searchBox,
        scrollBox = scrollBox,
        listBox = listBox,
        moreLabel = moreLabel,
        headerBtn = headerBtn,
        headerLabel = valueLabel,
        arrowLabel = arrowLabel,
        optionsBox = optionsBox,
        optionRows = {},
        expanded = false,
        headerWasPressed = false,
    }

    RebuildDropdownRows(picker)
    return root, picker
end

local function SyncDropdownHeader(ctrl)
    local label = ctrl.selectedLabel
    if ctrl.selectedValue == nil or label == nil or label == "" then
        label = ctrl.placeholder or "Select..."
    end
    SetLabelText(ctrl.headerLabel, tostring(label))
    SetLabelText(ctrl.arrowLabel, ctrl.expanded and "▲" or "▼")
end

local function SetDropdownExpanded(ctrl, expanded)
    ctrl.expanded = expanded and true or false
    pcall(function()
        if ctrl.optionsBox ~= nil then
            ctrl.optionsBox:SetVisibility(ctrl.expanded and VIS_VISIBLE or VIS_COLLAPSED)
        end
    end)
    if ctrl.expanded and ctrl.searchable then
        ctrl.searchFilter = ""
        pcall(function()
            if ctrl.searchBox ~= nil then
                ctrl.searchBox:SetText(FText(""))
            end
        end)
        RebuildDropdownRows(ctrl)
    end
    SyncDropdownHeader(ctrl)
end

local function CollapseAllDropdowns(exceptCtrl)
    for _, ctrl in ipairs(liveControls) do
        if ctrl.kind == "dropdown" and ctrl ~= exceptCtrl then
            SetDropdownExpanded(ctrl, false)
        end
    end
end

local function PollSearchableDropdowns()
    for _, ctrl in ipairs(liveControls) do
        if ctrl.kind == "dropdown" and ctrl.searchable and ctrl.expanded and ctrl.searchBox ~= nil then
            local text = GetWidgetPlainText(ctrl.searchBox)
            if text ~= ctrl.searchFilter then
                ctrl.searchFilter = text
                RebuildDropdownRows(ctrl)
            end
        end
    end
end

local function DestroyShell()
    StopPoll()
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

        for i, item in ipairs(section.items) do
            local namePrefix = string.format("ModMenu_%s_%s_%d_%s", section.id, tostring(item.id or item.type), i, suffix)

            if item.type == "separator" then
                AddSpacer(contentBox, namePrefix .. "_Sep", 14)
            elseif item.type == "label" then
                local label = Construct("/Script/UMG.TextBlock", contentBox, namePrefix)
                StyleText(label, config.fontHint)
                SetLabelText(label, item.label)
                contentBox:AddChildToVerticalBox(label)
                AddSpacer(contentBox, namePrefix .. "_Pad", 6)
                if item.id then
                    table.insert(liveControls, {
                        kind = "label",
                        sectionId = section.id,
                        item = item,
                        widget = label,
                        valueKey = ValueKey(section.id, item.id),
                    })
                end
            elseif item.type == "checkbox" then
                local vkey = ValueKey(section.id, item.id)
                local current = values[vkey]
                if current == nil then
                    current = item.default and true or false
                    values[vkey] = current
                end
                local check, label = CreateLabeledToggle(
                    contentBox,
                    namePrefix,
                    CheckboxCaption(item, current),
                    current
                )
                contentBox:AddChildToVerticalBox(check)
                AddSpacer(contentBox, namePrefix .. "_Pad", 8)
                table.insert(liveControls, {
                    kind = "checkbox",
                    sectionId = section.id,
                    item = item,
                    widget = check,
                    label = label,
                    valueKey = vkey,
                })
            elseif item.type == "button" then
                local button = CreateTextButton(contentBox, namePrefix, item.label)
                contentBox:AddChildToVerticalBox(button)
                AddSpacer(contentBox, namePrefix .. "_Pad", 8)
                table.insert(liveControls, {
                    kind = "button",
                    sectionId = section.id,
                    item = item,
                    widget = button,
                    wasPressed = false,
                })
            elseif item.type == "dropdown" then
                local vkey = ValueKey(section.id, item.id)
                local current = values[vkey]
                if current == nil then
                    current = item.default
                end

                local caption = Construct("/Script/UMG.TextBlock", contentBox, namePrefix .. "_Cap")
                StyleText(caption, config.fontHint)
                SetLabelText(caption, item.label)
                contentBox:AddChildToVerticalBox(caption)

                local root, picker = CreateDropdown(contentBox, namePrefix, item.options, current, {
                    searchable = item.searchable == true,
                    placeholder = item.placeholder,
                    maxVisible = item.maxVisible,
                    listMaxHeight = item.listMaxHeight,
                    allowEmpty = item.allowEmpty,
                })
                values[vkey] = picker.selectedValue
                contentBox:AddChildToVerticalBox(root)
                AddSpacer(contentBox, namePrefix .. "_Pad", 8)

                table.insert(liveControls, {
                    kind = "dropdown",
                    sectionId = section.id,
                    item = item,
                    widget = root,
                    valueKey = vkey,
                    namePrefix = picker.namePrefix,
                    list = picker.list,
                    labelToValue = picker.labelToValue,
                    valueToLabel = picker.valueToLabel,
                    selectedLabel = picker.selectedLabel,
                    selectedValue = picker.selectedValue,
                    placeholder = picker.placeholder,
                    searchable = picker.searchable,
                    maxVisible = picker.maxVisible,
                    searchFilter = picker.searchFilter,
                    searchBox = picker.searchBox,
                    scrollBox = picker.scrollBox,
                    listBox = picker.listBox,
                    moreLabel = picker.moreLabel,
                    headerBtn = picker.headerBtn,
                    headerLabel = picker.headerLabel,
                    arrowLabel = picker.arrowLabel,
                    optionsBox = picker.optionsBox,
                    optionRows = picker.optionRows,
                    expanded = false,
                    headerWasPressed = false,
                })
            end
        end

        if sIndex < #sections then
            AddSpacer(contentBox, "ModMenu_Between_" .. section.id .. "_" .. suffix, 18)
        end
    end
end

local function CreateShell()
    createAttempts = createAttempts + 1
    local suffix = tostring(createAttempts)

    local outer = UEHelpers.GetGameInstance()
    if not IsValid(outer) then
        outer = UEHelpers.GetPlayerController()
    end
    if not IsValid(outer) then
        error("No GameInstance or PlayerController to parent the widget")
    end

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

    hud:AddToViewport(VIEWPORT_Z)
    hud:SetVisibility(VIS_COLLAPSED)

    menuRoot = hud
    contentBox = vbox
    BuildContent()

    Log(string.format(
        "Shell ready dock=%s (~%.0f%% x ~%.0f%%). Sections: %d",
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
    PollSearchableDropdowns()

    local clicked = ConsumeMouseClick()

    -- Dropdown options take priority over headers when expanded (hit-test order).
    if clicked then
        for _, ctrl in ipairs(liveControls) do
            if ctrl.kind == "dropdown" and ctrl.expanded and ctrl.optionRows then
                for _, row in ipairs(ctrl.optionRows) do
                    if WidgetHovered(row.button) then
                        local value = row.optValue
                        ctrl.selectedValue = value
                        ctrl.selectedLabel = tostring(row.optLabel or value)
                        values[ctrl.valueKey] = value
                        SetDropdownExpanded(ctrl, false)
                        -- Swallow mouse-up so it doesn't immediately re-toggle the header.
                        IgnoreClicks(1)
                        SafeCall(ctrl.item.onChange, value)
                        ReclaimMenuInput()
                        EnsureMenuVisible()
                        clicked = false
                        break
                    end
                end
            end
            if not clicked then
                break
            end
        end
    end

    if clicked then
        for _, ctrl in ipairs(liveControls) do
            -- Value label + arrow button are both part of the select hit target.
            -- Skip when hovering the search box so typing/clicking filter doesn't toggle.
            if ctrl.kind == "dropdown"
                and not WidgetHovered(ctrl.searchBox)
                and (WidgetHovered(ctrl.headerBtn) or WidgetHovered(ctrl.headerLabel))
            then
                local nextExpanded = not ctrl.expanded
                if nextExpanded then
                    CollapseAllDropdowns(ctrl)
                end
                SetDropdownExpanded(ctrl, nextExpanded)
                clicked = false
                break
            elseif ctrl.kind == "dock" and WidgetHovered(ctrl.widget) then
                SetDockInternal(config.dock == "left" and "right" or "left")
                ReclaimMenuInput()
                clicked = false
                break
            elseif ctrl.kind == "button" and WidgetHovered(ctrl.widget) then
                SafeCall(ctrl.item.onClick)
                ReclaimMenuInput()
                ExecuteWithDelay(200, function()
                    ReclaimMenuInput()
                end)
                clicked = false
                break
            end
        end
    end

    -- Checkboxes still use state polling (reliable with labeled CheckBox).
    for _, ctrl in ipairs(liveControls) do
        if ctrl.kind == "checkbox" and IsValid(ctrl.widget) then
            local ok, checked = pcall(function()
                return ctrl.widget:IsChecked()
            end)
            if ok and checked ~= values[ctrl.valueKey] then
                values[ctrl.valueKey] = checked
                SetLabelText(ctrl.label, CheckboxCaption(ctrl.item, checked))
                SafeCall(ctrl.item.onChange, checked)
                ReclaimMenuInput()
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
    SetMenuInputActive(true)
    menuOpen = true
    StartPoll()
    Log("OPEN")
    for _, fn in ipairs(onOpenCallbacks) do
        SafeCall(fn)
    end
end

local function CloseInternal()
    StopPoll()
    Input.ClearClickState()
    CollapseAllDropdowns(nil)
    if IsValid(menuRoot) then
        menuRoot:SetVisibility(VIS_COLLAPSED)
    end
    SetMenuInputActive(false)
    menuOpen = false
    Log("CLOSED")
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

local function BindToggleKey()
    if keyBound then
        return
    end
    local key = config.key or Key.F6
    config.key = key
    if config.keyHint == nil and key == Key.F6 then
        config.keyHint = "F6"
    end
    RegisterKeyBind(key, function()
        ExecuteInGameThread(function()
            ToggleInternal()
        end)
    end)
    keyBound = true
end

--- Initialize / configure the singleton shell. Safe to call multiple times.
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

    if config.key == nil then
        config.key = Key.F6
        config.keyHint = config.keyHint or "F6"
    end

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
        "Init — title=%q key=%s dock=%s",
        tostring(config.title),
        tostring(config.keyHint or config.key),
        tostring(config.dock)
    ))
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
        if item.type == "checkbox" and item.id then
            local vkey = ValueKey(copy.id, item.id)
            if values[vkey] == nil then
                values[vkey] = item.default and true or false
            end
        elseif item.type == "dropdown" and item.id then
            local vkey = ValueKey(copy.id, item.id)
            if values[vkey] == nil and item.default ~= nil then
                values[vkey] = item.default
            end
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
            for _, ctrl in ipairs(liveControls) do
                if ctrl.kind == "label" and ctrl.valueKey == vkey and IsValid(ctrl.widget) then
                    SetLabelText(ctrl.widget, item.label)
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
    for _, ctrl in ipairs(liveControls) do
        if ctrl.valueKey == vkey and ctrl.kind == "checkbox" and IsValid(ctrl.widget) then
            pcall(function()
                ctrl.widget:SetIsChecked(value and true or false)
            end)
            SetLabelText(ctrl.label, CheckboxCaption(ctrl.item, value and true or false))
        elseif ctrl.valueKey == vkey and ctrl.kind == "dropdown" then
            if value == nil then
                ctrl.selectedValue = nil
                ctrl.selectedLabel = ctrl.placeholder or "Select..."
            else
                local label = ctrl.valueToLabel and ctrl.valueToLabel[value] or tostring(value)
                ctrl.selectedValue = value
                ctrl.selectedLabel = tostring(label)
            end
            SyncDropdownHeader(ctrl)
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
                local _, labelToValue, valueToLabel = NormalizeOptions(list)
                live.list = list
                live.labelToValue = labelToValue
                live.valueToLabel = valueToLabel
                if selectedValue == false then
                    live.selectedValue = nil
                    live.selectedLabel = live.placeholder or "Select..."
                elseif selectedValue ~= nil then
                    local plain = ToPlainString(selectedValue) or selectedValue
                    live.selectedValue = plain
                    live.selectedLabel = valueToLabel[plain] or tostring(plain)
                elseif live.selectedValue ~= nil and valueToLabel[live.selectedValue] == nil then
                    live.selectedValue = nil
                    live.selectedLabel = live.placeholder or "Select..."
                    values[vkey] = nil
                elseif live.selectedValue ~= nil then
                    live.selectedLabel = valueToLabel[live.selectedValue] or live.selectedLabel
                end
                live.searchFilter = ""
                pcall(function()
                    if live.searchBox ~= nil then
                        live.searchBox:SetText(FText(""))
                    end
                end)
                RebuildDropdownRows(live)
                SyncDropdownHeader(live)
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
