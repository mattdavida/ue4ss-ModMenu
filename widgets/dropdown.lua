--[[
  ModMenu widget: dropdown (plain + searchable).
]]

local Util = require("ModMenu.core.util")
local Umg = require("ModMenu.core.umg")
local Theme = require("ModMenu.core.theme")
local Options = require("ModMenu.core.options")
local Input = require("ModMenu.core.input")

local Dropdown = {}
Dropdown.type = "dropdown"

local VIS_VISIBLE = 0
local VIS_COLLAPSED = 1

local DROPDOWN_LIST_MAX_HEIGHT = 320
local DROPDOWN_SEARCHABLE_MAX_ROWS = 400

local dropdownRowSerial = 0

local function SyncHeader(ctrl)
    local label = ctrl.selectedLabel
    if ctrl.selectedValue == nil or label == nil or label == "" then
        label = ctrl.placeholder or "Select..."
    end
    Umg.SetLabelText(ctrl.headerLabel, tostring(label))
    Umg.SetLabelText(ctrl.arrowLabel, ctrl.expanded and "▲" or "▼")
end

local function RebuildRows(ctrl)
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
    local fontDropdown = ctrl.fontDropdown or 15
    local optionBg = ctrl.optionBg
    local optionText = ctrl.optionText

    for _, opt in ipairs(ctrl.list or {}) do
        if Options.OptionMatchesFilter(opt.label, filter) then
            matched = matched + 1
            if shown < maxVisible then
                shown = shown + 1
                dropdownRowSerial = dropdownRowSerial + 1
                local btn, lbl = Umg.CreateTextButton(
                    ctrl.listBox,
                    ctrl.namePrefix .. "_Opt" .. tostring(dropdownRowSerial),
                    opt.label,
                    optionBg,
                    optionText,
                    fontDropdown
                )
                ctrl.listBox:AddChildToVerticalBox(btn)
                table.insert(ctrl.optionRows, {
                    button = btn,
                    label = lbl,
                    optLabel = opt.label,
                    optValue = opt.value,
                    wasPressed = false,
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
            Umg.SetLabelText(ctrl.moreLabel, string.format("…%d more — type to narrow", extra))
            pcall(function()
                ctrl.moreLabel:SetVisibility(VIS_VISIBLE)
            end)
        elseif matched == 0 then
            Umg.SetLabelText(ctrl.moreLabel, "No matches")
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

local function SetExpanded(ctrl, expanded)
    ctrl.expanded = expanded and true or false
    pcall(function()
        if ctrl.optionsBox ~= nil then
            ctrl.optionsBox:SetVisibility(ctrl.expanded and VIS_VISIBLE or VIS_COLLAPSED)
        end
    end)
    if ctrl.expanded then
        if ctrl.searchable then
            ctrl.searchFilter = ""
            pcall(function()
                if ctrl.searchBox ~= nil then
                    ctrl.searchBox:SetText(FText(""))
                end
            end)
        end
        RebuildRows(ctrl)
    end
    SyncHeader(ctrl)
end

function Dropdown.collapseAll(liveControls, exceptCtrl)
    for _, ctrl in ipairs(liveControls or {}) do
        if ctrl.kind == "dropdown" and ctrl ~= exceptCtrl then
            SetExpanded(ctrl, false)
        end
    end
end

local function CreatePicker(outer, namePrefix, options, selectedValue, dropOpts, config)
    dropOpts = dropOpts or {}
    config = config or {}
    local searchable = dropOpts.searchable == true
    local placeholder = dropOpts.placeholder or "Select..."
    local maxVisible = dropOpts.maxVisible
        or (searchable and DROPDOWN_SEARCHABLE_MAX_ROWS or 9999)
    local listMaxHeight = dropOpts.listMaxHeight or DROPDOWN_LIST_MAX_HEIGHT
    local allowEmpty = dropOpts.allowEmpty == true or searchable or dropOpts.placeholder ~= nil
    local fontDropdown = config.fontDropdown or 15
    local fontHint = config.fontHint or 14
    local colors = Theme.Of(config)

    local list, labelToValue, valueToLabel = Options.NormalizeOptions(options)
    selectedValue = Util.ToPlainString(selectedValue) or selectedValue
    local selectedLabel = selectedValue ~= nil and valueToLabel[selectedValue] or nil
    if selectedLabel == nil and #list > 0 and not allowEmpty then
        selectedLabel = list[1].label
        selectedValue = list[1].value
    end
    if selectedLabel == nil then
        selectedLabel = placeholder
        selectedValue = nil
    end

    local root = Umg.Construct("/Script/UMG.VerticalBox", outer, namePrefix .. "_Root")

    local headerBtn = Umg.Construct("/Script/UMG.Button", root, namePrefix .. "_Header_Btn")
    pcall(function()
        headerBtn:SetBackgroundColor(colors.dropdownHeaderBg)
        if headerBtn.SetClickMethod then
            headerBtn:SetClickMethod(1)
        end
        if headerBtn.SetTouchMethod then
            headerBtn:SetTouchMethod(1)
        end
    end)
    local headerRow = Umg.Construct("/Script/UMG.HorizontalBox", headerBtn, namePrefix .. "_HeaderRow")

    local valueLabel = Umg.Construct("/Script/UMG.TextBlock", headerRow, namePrefix .. "_Value")
    Umg.StyleText(valueLabel, fontDropdown, colors.dropdownHeaderText)
    Umg.SetLabelText(valueLabel, tostring(selectedLabel))
    local valueSlot = headerRow:AddChildToHorizontalBox(valueLabel)
    pcall(function()
        valueSlot:SetSize({ SizeRule = 1, Value = 1.0 })
        valueSlot:SetPadding({ Left = 10, Top = 8, Right = 6, Bottom = 8 })
        valueSlot:SetVerticalAlignment(2)
    end)

    local arrowLabel = Umg.Construct("/Script/UMG.TextBlock", headerRow, namePrefix .. "_Arrow")
    Umg.StyleText(arrowLabel, fontDropdown, colors.dropdownHeaderText)
    Umg.SetLabelText(arrowLabel, "▼")
    local arrowSlot = headerRow:AddChildToHorizontalBox(arrowLabel)
    pcall(function()
        arrowSlot:SetSize({ SizeRule = 0, Value = 0.0 })
        arrowSlot:SetPadding({ Left = 4, Top = 8, Right = 10, Bottom = 8 })
        arrowSlot:SetVerticalAlignment(2)
    end)

    pcall(function()
        headerBtn:SetContent(headerRow)
    end)
    root:AddChildToVerticalBox(headerBtn)

    local optionsBox = Umg.Construct("/Script/UMG.VerticalBox", root, namePrefix .. "_Opts")
    pcall(function()
        optionsBox:SetVisibility(VIS_COLLAPSED)
    end)

    local searchBox = nil
    if searchable then
        local searchBorder = Umg.Construct("/Script/UMG.Border", optionsBox, namePrefix .. "_SearchBorder")
        pcall(function()
            searchBorder:SetBrushColor(colors.fieldBg)
            searchBorder:SetPadding({ Left = 8, Top = 6, Right = 8, Bottom = 6 })
        end)
        searchBox = Umg.Construct("/Script/UMG.EditableTextBox", searchBorder, namePrefix .. "_Search")
        pcall(function()
            searchBox:SetHintText(FText("Type to filter..."))
            searchBox:SetText(FText(""))
        end)
        Umg.StyleEditableTextBox(searchBox, fontDropdown)
        pcall(function()
            searchBorder:SetContent(searchBox)
        end)
        optionsBox:AddChildToVerticalBox(searchBorder)
        Umg.AddSpacer(optionsBox, namePrefix .. "_SearchPad", 6)
    end

    local sizeBox = Umg.Construct("/Script/UMG.SizeBox", optionsBox, namePrefix .. "_ListSize")
    pcall(function()
        sizeBox:SetMaxDesiredHeight(listMaxHeight)
    end)
    local scrollBox = Umg.Construct("/Script/UMG.ScrollBox", sizeBox, namePrefix .. "_Scroll")
    pcall(function()
        sizeBox:SetContent(scrollBox)
    end)

    local listBox = Umg.Construct("/Script/UMG.VerticalBox", scrollBox, namePrefix .. "_List")
    pcall(function()
        scrollBox:AddChild(listBox)
    end)
    Umg.StyleScrollBox(scrollBox, config)
    optionsBox:AddChildToVerticalBox(sizeBox)

    local moreLabel = nil
    if searchable then
        moreLabel = Umg.Construct("/Script/UMG.TextBlock", optionsBox, namePrefix .. "_More")
        Umg.StyleText(moreLabel, fontHint, colors.dropdownMore)
        Umg.SetLabelText(moreLabel, "")
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
        fontDropdown = fontDropdown,
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
        optionBg = colors.dropdownOptionBg,
        optionText = colors.dropdownOptionText,
        expanded = false,
        headerWasPressed = false,
    }

    -- Option buttons spawn on first expand, not at menu build.
    return root, picker
end

function Dropdown.validate(item, sectionId, index)
    local prefix = string.format("Register(%s) items[%d]", tostring(sectionId), index)
    if item.id == nil or item.id == "" then
        error(prefix .. " requires .id")
    end
    if item.label == nil then
        error(prefix .. " requires .label")
    end
    if type(item.options) ~= "table" or #item.options == 0 then
        error(prefix .. " dropdown requires non-empty .options array")
    end
    local ok, err = pcall(Options.NormalizeOptions, item.options)
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

function Dropdown.seed(sectionId, item, values)
    if not item.id then
        return
    end
    local vkey = tostring(sectionId) .. "." .. tostring(item.id)
    if values[vkey] == nil and item.default ~= nil then
        values[vkey] = item.default
    end
end

function Dropdown.build(ctx)
    local umg = ctx.umg
    local item = ctx.item
    local vkey = ctx.ValueKey(ctx.section.id, item.id)
    local current = ctx.values[vkey]
    if current == nil then
        current = item.default
    end

    local caption = umg.Construct("/Script/UMG.TextBlock", ctx.contentBox, ctx.namePrefix .. "_Cap")
    umg.StyleText(caption, ctx.config.fontHint)
    umg.SetLabelText(caption, item.label)
    ctx.contentBox:AddChildToVerticalBox(caption)

    local root, picker = CreatePicker(ctx.contentBox, ctx.namePrefix, item.options, current, {
        searchable = item.searchable == true,
        placeholder = item.placeholder,
        maxVisible = item.maxVisible,
        listMaxHeight = item.listMaxHeight,
        allowEmpty = item.allowEmpty,
    }, ctx.config)

    ctx.values[vkey] = picker.selectedValue
    ctx.contentBox:AddChildToVerticalBox(root)
    umg.AddSpacer(ctx.contentBox, ctx.namePrefix .. "_Pad", 8)

    table.insert(ctx.liveControls, {
        kind = "dropdown",
        sectionId = ctx.section.id,
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
        fontDropdown = picker.fontDropdown,
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
        optionBg = picker.optionBg,
        optionText = picker.optionText,
        expanded = false,
        headerWasPressed = false,
    })
end

---@param path string
local function SelectOption(ctrl, ctx, row, path)
    Input.DebugClick(path, ctrl, row.button)
    local value = row.optValue
    ctrl.selectedValue = value
    ctrl.selectedLabel = tostring(row.optLabel or value)
    ctx.values[ctrl.valueKey] = value
    SetExpanded(ctrl, false)
    Input.SuppressPressEdge(row)
    Input.SuppressPressEdge(ctrl, "headerWasPressed")
    Input.IgnoreClicks(2)
    ctx.SafeCall(ctrl.item.onChange, value)
    ctx.ReclaimMenuInput()
    ctx.EnsureMenuVisible()
end

---@param path string
local function ToggleHeader(ctrl, ctx, path)
    if Input.WidgetHovered(ctrl.searchBox) then
        return false
    end
    Input.DebugClick(path, ctrl, ctrl.headerBtn)
    local nextExpanded = not ctrl.expanded
    if nextExpanded then
        Dropdown.collapseAll(ctx.liveControls, ctrl)
    end
    SetExpanded(ctrl, nextExpanded)
    if nextExpanded then
        ctx.SafeCall(ctrl.item.onExpand, ctrl.list)
    end
    Input.SuppressPressEdge(ctrl, "headerWasPressed")
    Input.IgnoreClicks(2)
    return true
end

--- Filter text poll while expanded + native UButton press (no LMB latch).
function Dropdown.poll(ctrl, ctx)
    if ctrl.searchable and ctrl.expanded and ctrl.searchBox ~= nil then
        local text = Options.GetWidgetPlainText(ctrl.searchBox)
        if text ~= ctrl.searchFilter then
            ctrl.searchFilter = text
            RebuildRows(ctrl)
        end
    end

    if ctrl.expanded and ctrl.optionRows then
        for _, row in ipairs(ctrl.optionRows) do
            if Input.WidgetPressedEdge(row, row.button) then
                SelectOption(ctrl, ctx, row, "press-edge")
                return
            end
        end
    end
    if Input.WidgetPressedEdge(ctrl, ctrl.headerBtn, "headerWasPressed") then
        ToggleHeader(ctrl, ctx, "press-edge")
    end
end

--- Option-row click (priority over header). Returns true if consumed.
function Dropdown.pollOptionClick(ctrl, ctx)
    if not ctrl.expanded or not ctrl.optionRows then
        return false
    end
    for _, row in ipairs(ctrl.optionRows) do
        if Input.WidgetHovered(row.button) then
            SelectOption(ctrl, ctx, row, "latch-hover")
            return true
        end
    end
    return false
end

--- Header toggle click. Returns true if consumed.
function Dropdown.pollHeaderClick(ctrl, ctx)
    if not (Input.WidgetHovered(ctrl.headerBtn) or Input.WidgetHovered(ctrl.headerLabel)) then
        return false
    end
    return ToggleHeader(ctrl, ctx, "latch-hover")
end

--- LMB latch: option rows first, then header.
function Dropdown.pollClick(ctrl, ctx)
    if Dropdown.pollOptionClick(ctrl, ctx) then
        return true
    end
    return Dropdown.pollHeaderClick(ctrl, ctx)
end

function Dropdown.apply(ctrl, value, _ctx)
    if value == nil then
        ctrl.selectedValue = nil
        ctrl.selectedLabel = ctrl.placeholder or "Select..."
    else
        local label = ctrl.valueToLabel and ctrl.valueToLabel[value] or tostring(value)
        ctrl.selectedValue = value
        ctrl.selectedLabel = tostring(label)
    end
    SyncHeader(ctrl)
end

--- In-place searchable list refresh (SetOptions path).
function Dropdown.refreshLive(ctrl, list, selectedValue, values, vkey)
    local normalized, labelToValue, valueToLabel = Options.NormalizeOptions(list)
    ctrl.list = normalized
    ctrl.labelToValue = labelToValue
    ctrl.valueToLabel = valueToLabel
    if selectedValue == false then
        ctrl.selectedValue = nil
        ctrl.selectedLabel = ctrl.placeholder or "Select..."
    elseif selectedValue ~= nil then
        local plain = Util.ToPlainString(selectedValue) or selectedValue
        ctrl.selectedValue = plain
        ctrl.selectedLabel = valueToLabel[plain] or tostring(plain)
    elseif ctrl.selectedValue ~= nil and valueToLabel[ctrl.selectedValue] == nil then
        ctrl.selectedValue = nil
        ctrl.selectedLabel = ctrl.placeholder or "Select..."
        values[vkey] = nil
    elseif ctrl.selectedValue ~= nil then
        ctrl.selectedLabel = valueToLabel[ctrl.selectedValue] or ctrl.selectedLabel
    end
    ctrl.searchFilter = ""
    pcall(function()
        if ctrl.searchBox ~= nil then
            ctrl.searchBox:SetText(FText(""))
        end
    end)
    if ctrl.expanded then
        RebuildRows(ctrl)
    end
    SyncHeader(ctrl)
end

-- Used by ModMenu SyncDockChrome FName uniqueness when recreating dock label.
function Dropdown.nextRowSerial()
    dropdownRowSerial = dropdownRowSerial + 1
    return dropdownRowSerial
end

return Dropdown
