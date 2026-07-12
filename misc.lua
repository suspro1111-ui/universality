-- ══════════════════════════════════════════════════════════
--                     Misc Module
-- ══════════════════════════════════════════════════════════

return function(ctx)
    local Library         = ctx.Library
    local Tabs            = ctx.Tabs
    local CM              = ctx.ConnectionManager
    local ServerShopMod   = ctx.ServerShopModule

    local cloneref        = cloneref or function(obj) return obj end
    local Workspace       = cloneref(game:GetService("Workspace"))
    local Players         = cloneref(game:GetService("Players"))
    local RunService      = cloneref(game:GetService("RunService"))
    local VirtualUser     = cloneref(game:GetService("VirtualUser"))
    local TeleportService = cloneref(game:GetService("TeleportService"))
    local GuiService      = cloneref(game:GetService("GuiService"))
    local UserInputService= cloneref(game:GetService("UserInputService"))

    local CurrentCamera   = Workspace.CurrentCamera
    local LocalPlayer     = Players.LocalPlayer

    -- ════════════════════ Vars ════════════════════

    local Misc = { Features = {}, Vars = {} }

    Misc.Vars.AntiAfkCM                 = CM.new()
    Misc.Vars.AntiKickCM                = CM.new()
    Misc.Vars.AutoRejoinCM              = CM.new()
    Misc.Vars.InstantPromptCM           = CM.new()
    Misc.Vars.InstantPromptOldDurations = {}
    Misc.Vars.ServerHopTxt              = "Random Server"
    Misc.Vars.NoclipCM                  = CM.new()
    Misc.Vars.NoclipParts               = {}
    Misc.Vars.InfiniteJumpCM            = CM.new()
    Misc.Vars.AirSwimCM                 = CM.new()
    Misc.Vars.OriginalGravity           = nil

    -- ════════════════════ Features ════════════════════

    --[[
        Anti AFK Feature
        Keeps the client session active during inactivity timeouts by listening to LocalPlayer.Idled
        and generating virtual clicks.
    ]]
    Misc.Features.AntiAfk = {
        Start = function()
            local function simulateInput()
                VirtualUser:Button2Down(Vector2.new(0, 0), CurrentCamera.CFrame)
                task.wait()
                VirtualUser:Button2Up(Vector2.new(0, 0), CurrentCamera.CFrame)
            end
            Misc.Vars.AntiAfkCM:Add(LocalPlayer.Idled:Connect(simulateInput), "AntiAfk")
        end,
        Stop = function()
            Misc.Vars.AntiAfkCM:Remove("AntiAfk")
        end
    }

    --[[
        Anti Kick Feature
        Intercepts engine-level Kick actions via deep metamethod hooks.
        Fires localized notifications warning the user of internal script kicks.
    ]]
    Misc.Features.AntiKick = {
        Start = function()
            local original
            original = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                if method:lower() == "kick" and self == LocalPlayer then
                    local callingScript = getcallingscript()
                    local scriptName = callingScript and callingScript.Name or "Unknown"
                    Library:Notify({
                        Title       = "Anti-Kick Notifier",
                        Description = "Successfully blocked a kick attempt from: " .. scriptName,
                        Time        = 4,
                    })
                    return
                end
                return original(self, ...)
            end)
            Misc.Vars.AntiKickCM:Add(function()
                hookmetamethod(game, "__namecall", original)
            end, "AntiKick")
        end,
        Stop = function()
            Misc.Vars.AntiKickCM:Remove("AntiKick")
        end
    }

    --[[
        Auto Rejoin Feature
        Checks error logs from GuiService. On disconnect, it fires rejoin requests.
    ]]
    Misc.Features.AutoRejoin = {
        Start = function()
            local function onerror(message)
                if message and message ~= "" then
                    if LocalPlayer then
                        task.wait(1)
                        TeleportService:Teleport(game.PlaceId, LocalPlayer)
                    end
                end
            end
            Misc.Vars.AutoRejoinCM:Add(GuiService.ErrorMessageChanged:Connect(onerror), "AutoRejoin")
        end,
        Stop = function()
            Misc.Vars.AutoRejoinCM:Remove("AutoRejoin")
        end
    }

    --[[
        Instant Interacts Feature
        Manipulates all ProximityPrompts to allow instant interactions.
    ]]
    Misc.Features.InstantPrompt = {
        Start = function()
            local function Prompt(prompt)
                if not Misc.Vars.InstantPromptOldDurations[prompt] then
                    Misc.Vars.InstantPromptOldDurations[prompt] = prompt.HoldDuration
                    prompt.HoldDuration = 0
                end
            end
            Misc.Vars.InstantPromptCM:Add(game:GetService("ProximityPromptService").PromptShown:Connect(Prompt), "InstantPrompt")
        end,
        Stop = function()
            Misc.Vars.InstantPromptCM:Remove("InstantPrompt")
            for prompt, duration in pairs(Misc.Vars.InstantPromptOldDurations) do
                if typeof(prompt) == "Instance" and prompt:IsA("ProximityPrompt") then
                    pcall(function() prompt.HoldDuration = duration end)
                end
            end
            table.clear(Misc.Vars.InstantPromptOldDurations)
        end
    }

    --[[
        Noclip Feature
        Cycles through character BaseParts on Stepped to suppress collision states.
        Stores original collision values and restores them securely once disabled.
    ]]
    Misc.Features.Noclip = {
        Start = function()
            local function noclipLoop()
                local char = LocalPlayer.Character
                if char then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then
                            if not Misc.Vars.NoclipParts[part] then
                                Misc.Vars.NoclipParts[part] = {
                                    CanCollide = part.CanCollide,
                                    CanQuery   = part.CanQuery,
                                    CanTouch   = part.CanTouch
                                }
                            end
                            part.CanCollide = false
                        end
                    end
                end
            end
            Misc.Vars.NoclipCM:Add(RunService.Stepped:Connect(noclipLoop), "NoclipLoop")
        end,
        Stop = function()
            Misc.Vars.NoclipCM:Remove("NoclipLoop")
            for part, original in pairs(Misc.Vars.NoclipParts) do
                if part and part.Parent then
                    pcall(function() part.CanCollide = original.CanCollide end)
                end
            end
            table.clear(Misc.Vars.NoclipParts)
        end
    }

    --[[
        Infinite Jump Feature
        Forces character Jump states on consecutive JumpRequests, bypasses classic floor verification.
        Uses UserInputService.JumpRequest to support both PC Space keys and Mobile virtual jump UI.
    ]]
    Misc.Features.InfiniteJump = {
        Start = function()
            Misc.Vars.InfiniteJumpCM:Add(UserInputService.JumpRequest:Connect(function()
                local char = LocalPlayer.Character
                local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
                if humanoid then
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end), "InfiniteJump")
        end,
        Stop = function()
            Misc.Vars.InfiniteJumpCM:Remove("InfiniteJump")
        end
    }

    --[[
        AirSwimming Feature
        Alters internal humanoid animation behaviors to continuously loop Swimming states.
        Disables gravity and monitors changes, forcing any updates back to zero while active.
        Includes a drift-prevention connection to halt player sliding when not intentionally moving.
    ]]
    Misc.Features.AirSwimming = {
        Start = function()
            local function updateSwim()
                local char = LocalPlayer.Character
                local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
                if humanoid then
                    humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
                    humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
                    humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
                    humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
                end
            end

            Misc.Vars.AirSwimCM:Add(RunService.RenderStepped:Connect(updateSwim), "AirSwimUpdate")

            local function preventDrift()
                pcall(function()
                    local char = LocalPlayer.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
                    if root and humanoid then
                        local isMoving  = humanoid.MoveDirection ~= Vector3.zero
                        local isJumping = UserInputService:IsKeyDown(Enum.KeyCode.Space)
                        if not (isMoving or isJumping) then
                            root.AssemblyLinearVelocity = Vector3.zero
                        end
                    end
                end)
            end

            Misc.Vars.AirSwimCM:Add(RunService.Heartbeat:Connect(preventDrift), "AirSwimDriftPrevention")

            local function onGravityChanged()
                if Workspace.Gravity ~= 0 then
                    Misc.Vars.OriginalGravity = Workspace.Gravity
                    Workspace.Gravity = 0
                end
            end

            Misc.Vars.OriginalGravity = Workspace.Gravity
            Misc.Vars.AirSwimCM:Add(Workspace:GetPropertyChangedSignal("Gravity"):Connect(onGravityChanged), "GravityListener")
            Workspace.Gravity = 0
        end,
        Stop = function()
            Misc.Vars.AirSwimCM:Remove("AirSwimUpdate")
            Misc.Vars.AirSwimCM:Remove("AirSwimDriftPrevention")
            Misc.Vars.AirSwimCM:Remove("GravityListener")

            if Misc.Vars.OriginalGravity then
                Workspace.Gravity = Misc.Vars.OriginalGravity
                Misc.Vars.OriginalGravity = nil
            end

            local char = LocalPlayer.Character
            local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
            if humanoid then
                humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    }

    -- ════════════════════ Misc Tab UI ════════════════════

    local MiscGroupClients = Tabs.Misc:AddLeftGroupbox("Clients", "squares-unite")

    MiscGroupClients:AddToggle("Anti Afk", {
        Text     = "Enable Anti Afk",
        Default  = false,
        Callback = function(state)
            if state then Misc.Features.AntiAfk.Start() else Misc.Features.AntiAfk.Stop() end
        end,
    })

    MiscGroupClients:AddToggle("Anti Kick", {
        Text     = "Enable Anti Kick",
        Default  = false,
        Callback = function(state)
            if state then Misc.Features.AntiKick.Start() else Misc.Features.AntiKick.Stop() end
        end,
    })

    MiscGroupClients:AddToggle("Auto Rejoin", {
        Text     = "Enable Auto Rejoin",
        Default  = false,
        Callback = function(state)
            if state then Misc.Features.AutoRejoin.Start() else Misc.Features.AutoRejoin.Stop() end
        end,
    })

    MiscGroupClients:AddToggle("Instant Interacts", {
        Text     = "Enable Instant Interacts",
        Default  = false,
        Callback = function(state)
            if state then Misc.Features.InstantPrompt.Start() else Misc.Features.InstantPrompt.Stop() end
        end,
    })

    local MiscGroupPlayer = Tabs.Misc:AddLeftGroupbox("Self", "squares-unite")

    MiscGroupPlayer:AddToggle("Noclip", {
        Text     = "Enable Noclip",
        Default  = false,
        Callback = function(state)
            if state then Misc.Features.Noclip.Start() else Misc.Features.Noclip.Stop() end
        end,
    })

    MiscGroupPlayer:AddToggle("InfiniteJump", {
        Text     = "Enable Infinite Jump",
        Default  = false,
        Callback = function(state)
            if state then Misc.Features.InfiniteJump.Start() else Misc.Features.InfiniteJump.Stop() end
        end,
    })

    MiscGroupPlayer:AddToggle("Air Swim", {
        Text     = "Enable Air Swim",
        Default  = false,
        Callback = function(state)
            if state then Misc.Features.AirSwimming.Start() else Misc.Features.AirSwimming.Stop() end
        end,
    })

    local MiscGroupServer = Tabs.Misc:AddRightGroupbox("Server", "squares-unite")

    MiscGroupServer:AddDropdown("ServerHop", {
        Text     = "ServerHop Options",
        Values   = { "Random Server", "Big Server", "Small Server" },
        Default  = 1,
        Callback = function(v) Misc.Vars.ServerHopTxt = v end,
    })

    MiscGroupServer:AddButton("Serverhop", function()
        local Txt = Misc.Vars.ServerHopTxt:lower()
        if Txt:match("big") then
            ServerShopMod:GetServers({ ping = false, fps = false, asc = false })
        elseif Txt:match("small") then
            ServerShopMod:GetServers({ ping = false, fps = false, asc = true })
        elseif Txt:match("random") then
            ServerShopMod:GetServers({ ping = true,  fps = true,  asc = true  })
        end
    end)
end
