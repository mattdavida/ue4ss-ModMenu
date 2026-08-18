--[[
  ModMenu.shell.build — construct / destroy the UMG tree and rebuild section content.
]]

local UEHelpers = require("UEHelpers.UEHelpers")
local Util = require("ModMenu.core.util")
local Umg = require("ModMenu.core.umg")
local Instance = require("ModMenu.core.instance")
local InputMode = require("ModMenu.core.inputmode")
local Widgets = require("ModMenu.widgets.init")
local Session = require("ModMenu.shell.session")
local Dock = require("ModMenu.shell.dock")
local Collapse = require("ModMenu.shell.collapse")

local Log = Util.Log
local IsValid = Util.IsValid
local Construct = Umg.Construct
local StyleText = Umg.StyleText
local SetLabelText = Umg.SetLabelText
local AddSpacer = Umg.AddSpacer
local CreateTextButton = Umg.CreateTextButton

local M = {}

function M.BuildContent(S)
    if not IsValid(S.contentBox) then
        return
    end

    pcall(function()
        S.contentBox:ClearChildren()
    end)
    Session.ClearLive(S)

    -- Must change every rebuild. Reusing FNames after ClearChildren resurrects zombies —
    -- category (more option rows) breaks harder than language; both are the same control.
    S.contentGen = S.contentGen + 1
    local suffix = tostring(S.contentGen)
    local config = S.config
    local contentBox = S.contentBox

    local title = Construct("/Script/UMG.TextBlock", contentBox, "ModMenu_Title_" .. suffix)
    StyleText(title, config.fontTitle)
    SetLabelText(title, config.title)
    contentBox:AddChildToVerticalBox(title)

    local keyName = tostring(config.keyHint or config.keyName or "F6")
    local hintText = "[" .. keyName .. "] toggle menu"
    if type(config.consoleCommand) == "string" and config.consoleCommand ~= "" then
        hintText = hintText .. " · " .. config.consoleCommand
    end
    local hint = Construct("/Script/UMG.TextBlock", contentBox, "ModMenu_Hint_" .. suffix)
    StyleText(hint, config.fontHint)
    SetLabelText(hint, hintText)
    contentBox:AddChildToVerticalBox(hint)

    -- Shell chrome: flip Left/Right dock without rebuilding the panel.
    local dockBtn, dockLbl = CreateTextButton(
        contentBox,
        "ModMenu_Dock_" .. suffix,
        Dock.Caption(config)
    )
    contentBox:AddChildToVerticalBox(dockBtn)
    AddSpacer(contentBox, "ModMenu_DockPad_" .. suffix, 8)
    table.insert(S.liveControls, {
        kind = "dock",
        widget = dockBtn,
        label = dockLbl,
    })

    AddSpacer(contentBox, "ModMenu_HeadPad_" .. suffix, 16)

    if #S.sections == 0 then
        local empty = Construct("/Script/UMG.TextBlock", contentBox, "ModMenu_Empty_" .. suffix)
        StyleText(empty, config.fontHint)
        SetLabelText(empty, "No mods registered yet.")
        contentBox:AddChildToVerticalBox(empty)
        return
    end

    for sIndex, section in ipairs(S.sections) do
        local collapsed = Collapse.IsCollapsed(S, section)
        local itemParent = contentBox
        if Collapse.IsCollapsible(section) then
            local header = Collapse.BuildHeader(S, section, contentBox, suffix)
            local body = Construct(
                "/Script/UMG.VerticalBox",
                contentBox,
                string.format("ModMenu_SecBody_%s_%s", section.id, suffix)
            )
            contentBox:AddChildToVerticalBox(body)
            Collapse.AttachBody(header, body, collapsed)
            itemParent = body
        else
            local secTitle = Construct(
                "/Script/UMG.TextBlock",
                contentBox,
                string.format("ModMenu_Sec_%s_%s", section.id, suffix)
            )
            StyleText(secTitle, config.fontSection)
            SetLabelText(secTitle, section.title or section.id)
            contentBox:AddChildToVerticalBox(secTitle)
        end
        AddSpacer(itemParent, string.format("ModMenu_SecPad_%s_%s", section.id, suffix), 8)

        -- Always build children. Collapsed sections hide the body (dropdown-style)
        -- so toggling does not rebuild and flicker under a still-down click.
        local ctx = S.makeWidgetCtx()
        ctx.contentBox = itemParent

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

        if sIndex < #S.sections then
            AddSpacer(contentBox, "ModMenu_Between_" .. section.id .. "_" .. suffix, 18)
        end
    end
end

function M.Teardown(S)
    if IsValid(S.menuRoot) then
        pcall(function()
            S.menuRoot:RemoveFromParent()
        end)
        pcall(function()
            S.menuRoot:RemoveFromViewport()
        end)
    end
    S.menuRoot = nil
    S.contentBox = nil
    S.panelSlot = nil
    Session.ClearLive(S)
    S.menuOpen = false
end

--- ClientRestart always destroys the shell. Do not ApplyGameOnly / hide
--- the cursor unless this instance had actually taken input.
function M.Destroy(S, stopPoll)
    if stopPoll then
        stopPoll()
    end
    local wasHoldingInput = S.menuOpen or Instance.IsOpenCountHeld()
    local remaining = Instance.NoteClosed()
    M.Teardown(S)
    if wasHoldingInput then
        InputMode.SetActive(false, remaining)
    end
end

function M.Create(S)
    local config = S.config
    Instance.Ensure(config)
    Instance.BumpCreateAttempts()
    local suffix = Instance.ShellNameSuffix(config)

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

    -- ScrollBox fills the docked panel so long section lists are reachable.
    local scroll = Construct("/Script/UMG.ScrollBox", border, "ModMenu_Scroll_" .. suffix)
    pcall(function()
        scroll:SetAnimateWheelScrolling(true)
        scroll:SetAlwaysShowScrollbar(true)
        scroll:SetAllowOverscroll(false)
        if scroll.SetConsumeMouseWheel then
            scroll:SetConsumeMouseWheel(1) -- EConsumeMouseWheel::Always
        end
        if scroll.SetScrollbarThickness then
            scroll:SetScrollbarThickness({ X = 8, Y = 8 })
        end
    end)
    border:SetContent(scroll)

    local vbox = Construct("/Script/UMG.VerticalBox", scroll, "ModMenu_VBox_" .. suffix)
    pcall(function()
        scroll:AddChild(vbox)
    end)

    local slot = canvas:AddChildToCanvas(border)
    S.panelSlot = slot
    if slot then
        Dock.ApplyPercentLayout(slot, config)
    end

    hud:AddToViewport(Instance.GetViewportZ())
    hud:SetVisibility(Session.VIS_COLLAPSED)

    S.menuRoot = hud
    S.contentBox = vbox
    M.BuildContent(S)

    Log(string.format(
        "Shell ready name=ModMenu_Root_%s z=%d dock=%s (~%.0f%% x ~%.0f%%). Sections: %d",
        suffix,
        Instance.GetViewportZ(),
        tostring(config.dock),
        config.widthFrac * 100,
        (1.0 - config.topFrac - config.bottomFrac) * 100,
        #S.sections
    ))
end

function M.Ensure(S)
    if IsValid(S.menuRoot) and IsValid(S.contentBox) then
        return true
    end
    local ok, err = pcall(M.Create, S)
    if not ok then
        Log("CreateShell failed: " .. tostring(err))
        M.Destroy(S, S.stopPoll)
        return false
    end
    return IsValid(S.menuRoot)
end

return M
