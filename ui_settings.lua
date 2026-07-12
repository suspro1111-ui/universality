-- ══════════════════════════════════════════════════════════
--                  UI Settings Module
-- ══════════════════════════════════════════════════════════

return function(ctx)
    local Library         = ctx.Library
    local Tabs            = ctx.Tabs
    local SaveManager     = ctx.SaveManager
    local ThemeManager    = ctx.ThemeManager
    local CM              = ctx.ConnectionManager
    local Options         = Library.Options

    local cloneref        = cloneref or function(obj) return obj end
    local RunService      = cloneref(game:GetService("RunService"))

    -- ════════════════════ Watermark Handler ════════════════════

    --[[
        Watermark Handler
        Draggable latency, telemetry, and framerate tracker module.
    ]]
    local WatermarkLabel = Library:AddDraggableLabel("Universality")
    WatermarkLabel:SetVisible(true)

    local WatermarkCM = CM.new()

    local function StartWatermark()
        local FrameTimer   = tick()
        local FrameCounter = 0
        local FPS          = 60

        WatermarkCM:Add(RunService.RenderStepped:Connect(function()
            FrameCounter = FrameCounter + 1

            if (tick() - FrameTimer) >= 1 then
                FPS          = FrameCounter
                FrameTimer   = tick()
                FrameCounter = 0
            end

            local ping = 0
            pcall(function()
                ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
            end)

            WatermarkLabel:SetText(string.format("Universality | %d fps | %d ms", math.floor(FPS), ping))
            WatermarkLabel:SetVisible(true)
        end), "Watermark")
    end

    local function StopWatermark()
        WatermarkCM:Remove("Watermark")
        WatermarkLabel:SetVisible(false)
    end

    StartWatermark()

    -- ════════════════════ UI Settings Tab ════════════════════

    local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu", "wrench")

    MenuGroup:AddToggle("KeybindMenuOpen", {
        Default  = Library.KeybindFrame.Visible,
        Text     = "Open Keybind Menu",
        Callback = function(value) Library.KeybindFrame.Visible = value end,
    })

    MenuGroup:AddToggle("ShowCustomCursor", {
        Text     = "Custom Cursor",
        Default  = true,
        Callback = function(value) Library.ShowCustomCursor = value end,
    })

    MenuGroup:AddToggle("Show Watermark", {
        Text     = "Show Watermark",
        Default  = true,
        Callback = function(value)
            if value then StartWatermark() else StopWatermark() end
        end,
    })

    MenuGroup:AddDropdown("NotificationSide", {
        Values   = { "Left", "Right" },
        Default  = "Right",
        Text     = "Notification Side",
        Callback = function(value) Library:SetNotifySide(value) end,
    })

    MenuGroup:AddDropdown("DPIDropdown", {
        Values   = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
        Default  = "100%",
        Text     = "DPI Scale",
        Callback = function(value)
            local dpi = tonumber(value:gsub("%%", ""))
            Library:SetDPIScale(dpi)
        end,
    })

    MenuGroup:AddDivider()

    MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
        Default = "RightShift",
        NoUI    = true,
        Text    = "Menu keybind",
    })

    MenuGroup:AddButton("Unload", function() Library:Unload() end)
    Library.ToggleKeybind = Options.MenuKeybind

    -- ════════════════════ Addons Setup ════════════════════

    SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
    SaveManager:BuildConfigSection(Tabs["UI Settings"])
    ThemeManager:ApplyToTab(Tabs["UI Settings"])
    SaveManager:LoadAutoloadConfig()
end
