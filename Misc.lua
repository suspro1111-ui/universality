-- ══════════════════════════════════════════════════════════
--                   Misc Module
-- ══════════════════════════════════════════════════════════

return function(env)

    -- ════════════════════ Unpack Environment ════════════════════

    local Library              = env.Library
    local ConnectionManager    = env.ConnectionManager
    local ServerHopModule      = env.ServerHopModule
    local Tabs                 = env.Tabs
    local Workspace            = env.Workspace
    local LocalPlayer          = env.LocalPlayer
    local CurrentCamera        = env.CurrentCamera
    local Lighting             = env.Lighting
    local RunService           = env.RunService
    local VirtualUser          = env.VirtualUser
    local TeleportService      = env.TeleportService
    local GuiService           = env.GuiService
    local UserInputService     = env.UserInputService
    local ProximityPromptService = env.ProximityPromptService
    local notify               = env.notify

    local Options = Library.Options

    -- ════════════════════ Helpers ════════════════════

    local function ToggleFeature(feature)
        return function(state)
            if state then
                feature.Start()
            else
                feature.Stop()
            end
        end
    end

    -- ════════════════════ State Tables ════════════════════

    local Misc = {
        Features = {},
        Vars     = {},
    }

    -- Client / session
    Misc.Vars.AntiAfkCM    = ConnectionManager.new()
    Misc.Vars.AntiKickCM   = ConnectionManager.new()
    Misc.Vars.AutoRejoinCM = ConnectionManager.new()

    -- Anti-Lagback
    Misc.Vars.AntiLagbackCM   = ConnectionManager.new()
    Misc.Vars.LastValidCFrame = nil

    Misc.Vars.InstantPromptCM           = ConnectionManager.new()
    Misc.Vars.InstantPromptOldDurations = setmetatable({}, { __mode = "k" })

    -- Player movement
    Misc.Vars.NoclipCM    = ConnectionManager.new()
    Misc.Vars.NoclipParts = setmetatable({}, { __mode = "k" })

    Misc.Vars.InfiniteJumpCM = ConnectionManager.new()

    Misc.Vars.AirSwimCM       = ConnectionManager.new()
    Misc.Vars.OriginalGravity = nil

    -- Character stats
    Misc.Vars.CharStatsCM       = ConnectionManager.new()
    Misc.Vars.CharStatsActive   = false
    Misc.Vars.StatsMethod       = "Set"
    Misc.Vars.OldWalkSpeed      = 0
    Misc.Vars.OldJumpPower      = 0
    Misc.Vars.OriginalWalkSpeed = nil
    Misc.Vars.OriginalJumpPower = nil

    -- Server
    Misc.Vars.ServerHopTxt = "Random Server"

    -- World / Lighting
    Misc.Vars.NoFogCM                     = ConnectionManager.new()
    Misc.Vars.OriginalFogEnd              = nil
    Misc.Vars.OriginalAtmosphereDensities = setmetatable({}, { __mode = "k" })

    Misc.Vars.NoBlurCM              = ConnectionManager.new()
    Misc.Vars.NoBlurOriginalStates  = setmetatable({}, { __mode = "k" })
    Misc.Vars.OriginalGlobalShadows = nil

    -- ════════════════════ Features ════════════════════

    Misc.Features.AntiAfk = {
        Start = function()
            local function simulateInput()
                VirtualUser:Button2Down(Vector2.zero, CurrentCamera.CFrame)
                task.wait()
                VirtualUser:Button2Up(Vector2.zero, CurrentCamera.CFrame)
            end
            Misc.Vars.AntiAfkCM:Add(LocalPlayer.Idled:Connect(simulateInput), "AntiAfk")
        end,
        Stop = function()
            Misc.Vars.AntiAfkCM:Remove("AntiAfk")
        end,
    }

    Misc.Features.AntiKick = {
        Start = function()
            local hookmetamethod    = hookmetamethod    or syn_hookmetamethod
            local getrawmetatable   = getrawmetatable   or syn_getrawmetatable
            local setreadonly       = setreadonly       or syn_setreadonly
            local getnamecallmethod = getnamecallmethod or syn_getnamecallmethod
            local newcclosure       = newcclosure       or syn_newcclosure

            if not hookmetamethod or not getrawmetatable or not setreadonly or not getnamecallmethod or not newcclosure then
                notify("Notifier", "Your executor does not support the required functions for Anti-Kick.", 5)
                return
            end

            local mt = getrawmetatable(game)
            setreadonly(mt, false)
            local oldNamecall = mt.__namecall
            local oldIndex    = mt.__index
            local oldNewIndex = mt.__newindex

            local success, err = pcall(function()
                mt.__namecall = newcclosure(function(self, ...)
                    local method = getnamecallmethod()
                    if (method == "Kick" or method == "kick") and self == LocalPlayer then
                        local caller     = getcallingscript()
                        local callerName = caller and caller.Name or "Unknown"
                        notify("Notifier", "Blocked a kick attempt from: " .. callerName, 4)
                        return
                    end
                    return oldNamecall(self, ...)
                end)

                mt.__index = newcclosure(function(self, index)
                    if (index == "Kick" or index == "kick") and self == LocalPlayer then
                        local caller     = getcallingscript()
                        local callerName = caller and caller.Name or "Unknown"
                        notify("Notifier", "Blocked a kick attempt from: " .. callerName, 4)
                        return function() end
                    end
                    return oldIndex(self, index)
                end)

                mt.__newindex = newcclosure(function(self, index, value)
                    if (index == "Kick" or index == "kick") and self == LocalPlayer then
                        local caller     = getcallingscript()
                        local callerName = caller and caller.Name or "Unknown"
                        notify("Notifier", "Blocked a kick attempt from: " .. callerName, 4)
                        return
                    end
                    return oldNewIndex(self, index, value)
                end)
            end)

            if not success then
                notify("Notifier", "Failed to hook metamethods: " .. tostring(err), 5)
                return
            end

            setreadonly(mt, true)

            Misc.Vars.AntiKickCM:Add(function()
                if mt and oldNamecall and oldIndex and oldNewIndex then
                    pcall(function()
                        setreadonly(mt, false)
                        mt.__namecall = oldNamecall
                        mt.__index    = oldIndex
                        mt.__newindex = oldNewIndex
                        setreadonly(mt, true)
                    end)
                end
            end, "AntiKick")
        end,

        Stop = function()
            Misc.Vars.AntiKickCM:Remove("AntiKick")
        end,
    }

    Misc.Features.AutoRejoin = {
        Start = function()
            local function onError(message)
                if message and message ~= "" then
                    task.wait(1)
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end
            end
            Misc.Vars.AutoRejoinCM:Add(GuiService.ErrorMessageChanged:Connect(onError), "AutoRejoin")
        end,
        Stop = function()
            Misc.Vars.AutoRejoinCM:Remove("AutoRejoin")
        end,
    }

    Misc.Features.AntiLagback = {
        Start = function()
            local function setupCharacter(char)
                if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then
                    hrp = char:WaitForChild("HumanoidRootPart", 5)
                end
                if not hrp then return end

                Misc.Vars.LastValidCFrame = hrp.CFrame
                local isReverting = false

                local positionHistory  = {}
                local MAX_HISTORY      = 20
                local lastRecordTime   = os.clock()
                local RECORD_INTERVAL  = 0.1

                local function recordPosition(pos)
                    if os.clock() - lastRecordTime >= RECORD_INTERVAL then
                        if #positionHistory >= MAX_HISTORY then
                            table.remove(positionHistory, 1)
                        end
                        table.insert(positionHistory, pos)
                        lastRecordTime = os.clock()
                    end
                end

                recordPosition(hrp.CFrame.Position)

                Misc.Vars.AntiLagbackCM:Add(hrp:GetPropertyChangedSignal("CFrame"):Connect(function()
                    if isReverting then return end

                    local newCFrame = hrp.CFrame
                    local newPos    = newCFrame.Position
                    local oldPos    = Misc.Vars.LastValidCFrame.Position
                    local dist      = (newPos - oldPos).Magnitude

                    local NORMAL_MOVE_DIST  = 1.5
                    local MAX_LAGBACK_DIST  = 25
                    local HISTORY_MATCH_DIST = 2.5

                    if dist < NORMAL_MOVE_DIST then
                        Misc.Vars.LastValidCFrame = newCFrame
                        recordPosition(newPos)
                        return
                    end

                    if dist > MAX_LAGBACK_DIST then
                        Misc.Vars.LastValidCFrame = newCFrame
                        recordPosition(newPos)
                        return
                    end

                    local isRubberband = false
                    for i = #positionHistory, 1, -1 do
                        local pastPos = positionHistory[i]
                        if (newPos - pastPos).Magnitude < HISTORY_MATCH_DIST then
                            isRubberband = true
                            break
                        end
                    end

                    local velocity    = hrp.AssemblyLinearVelocity
                    local moveDir     = (newPos - oldPos).Unit
                    local isOpposing  = velocity.Magnitude > 2 and (velocity:Dot(moveDir) < -0.5)
                    local isStandingStill = velocity.Magnitude < 2

                    if isRubberband and (isOpposing or isStandingStill) then
                        isReverting   = true
                        hrp.CFrame    = Misc.Vars.LastValidCFrame
                        isReverting   = false
                    else
                        Misc.Vars.LastValidCFrame = newCFrame
                        recordPosition(newPos)
                    end
                end), "AntiLagbackConn")
            end

            if LocalPlayer.Character then
                setupCharacter(LocalPlayer.Character)
            end

            Misc.Vars.AntiLagbackCM:Add(LocalPlayer.CharacterAdded:Connect(function(newChar)
                task.wait(0.5)
                setupCharacter(newChar)
            end), "AntiLagbackCharAdded")
        end,
        Stop = function()
            Misc.Vars.AntiLagbackCM:Remove("AntiLagbackConn")
            Misc.Vars.AntiLagbackCM:Remove("AntiLagbackCharAdded")
            Misc.Vars.LastValidCFrame = nil
        end,
    }

    Misc.Features.InstantPrompt = {
        Start = function()
            local function onPromptShown(prompt)
                if not Misc.Vars.InstantPromptOldDurations[prompt] then
                    Misc.Vars.InstantPromptOldDurations[prompt] = prompt.HoldDuration
                    prompt.HoldDuration = 0
                end
            end
            Misc.Vars.InstantPromptCM:Add(
                ProximityPromptService.PromptShown:Connect(onPromptShown),
                "InstantPrompt"
            )
        end,
        Stop = function()
            Misc.Vars.InstantPromptCM:Remove("InstantPrompt")
            for prompt, duration in pairs(Misc.Vars.InstantPromptOldDurations) do
                if typeof(prompt) == "Instance" and prompt:IsA("ProximityPrompt") then
                    pcall(function()
                        prompt.HoldDuration = duration
                    end)
                end
            end
            table.clear(Misc.Vars.InstantPromptOldDurations)
        end,
    }

    Misc.Features.Noclip = {
        Start = function()
            local function noclipLoop()
                local char = LocalPlayer.Character
                if not char then return end
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        if not Misc.Vars.NoclipParts[part] then
                            Misc.Vars.NoclipParts[part] = {
                                CanCollide = part.CanCollide,
                                CanQuery   = part.CanQuery,
                                CanTouch   = part.CanTouch,
                            }
                        end
                        part.CanCollide = false
                    end
                end
            end
            Misc.Vars.NoclipCM:Add(RunService.Stepped:Connect(noclipLoop), "NoclipLoop")
        end,
        Stop = function()
            Misc.Vars.NoclipCM:Remove("NoclipLoop")
            for part, original in pairs(Misc.Vars.NoclipParts) do
                if part and part.Parent then
                    pcall(function()
                        part.CanCollide = original.CanCollide
                        part.CanQuery   = original.CanQuery
                        part.CanTouch   = original.CanTouch
                    end)
                end
            end
            table.clear(Misc.Vars.NoclipParts)
        end,
    }

    Misc.Features.InfiniteJump = {
        Start = function()
            Misc.Vars.InfiniteJumpCM:Add(
                UserInputService.JumpRequest:Connect(function()
                    local char     = LocalPlayer.Character
                    local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
                    if humanoid then
                        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                end),
                "InfiniteJump"
            )
        end,
        Stop = function()
            Misc.Vars.InfiniteJumpCM:Remove("InfiniteJump")
        end,
    }

    Misc.Features.AirSwimming = {
        Start = function()
            local char     = LocalPlayer.Character
            local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")

            local charAddedConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
                char     = newChar
                humanoid = newChar:WaitForChild("Humanoid", 5)
            end)
            Misc.Vars.AirSwimCM:Add(charAddedConn, "AirSwimCharAdded")

            Misc.Vars.AirSwimCM:Add(RunService.RenderStepped:Connect(function()
                local c = LocalPlayer.Character
                if c ~= char then
                    char     = c
                    humanoid = c and c:FindFirstChildWhichIsA("Humanoid")
                end
                if not humanoid then return end
                humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing,  false)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,   false)
                humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
            end), "AirSwimUpdate")

            Misc.Vars.AirSwimCM:Add(RunService.Heartbeat:Connect(function()
                local c = LocalPlayer.Character
                if c ~= char then
                    char     = c
                    humanoid = c and c:FindFirstChildWhichIsA("Humanoid")
                end
                if not (c and humanoid) then return end
                local root = c:FindFirstChild("HumanoidRootPart")
                if not root then return end

                local moveDirection = humanoid.MoveDirection
                local isJumping     = UserInputService:IsKeyDown(Enum.KeyCode.Space)
                local isDiving      = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
                                   or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)

                local speed    = humanoid.WalkSpeed > 0 and humanoid.WalkSpeed or 16
                local velocity = moveDirection * speed

                if isJumping then
                    velocity = velocity + Vector3.new(0, speed, 0)
                elseif isDiving then
                    velocity = velocity + Vector3.new(0, -speed, 0)
                end

                if velocity.Magnitude > 0.01 then
                    root.AssemblyLinearVelocity = velocity
                else
                    root.AssemblyLinearVelocity = Vector3.zero
                end
            end), "AirSwimMovement")

            Misc.Vars.OriginalGravity = Workspace.Gravity
            Misc.Vars.AirSwimCM:Add(
                Workspace:GetPropertyChangedSignal("Gravity"):Connect(function()
                    if Workspace.Gravity ~= 0 then
                        Misc.Vars.OriginalGravity = Workspace.Gravity
                        Workspace.Gravity = 0
                    end
                end),
                "GravityListener"
            )
            Workspace.Gravity = 0
        end,

        Stop = function()
            Misc.Vars.AirSwimCM:Remove("AirSwimCharAdded")
            Misc.Vars.AirSwimCM:Remove("AirSwimUpdate")
            Misc.Vars.AirSwimCM:Remove("AirSwimMovement")
            Misc.Vars.AirSwimCM:Remove("GravityListener")

            if Misc.Vars.OriginalGravity then
                Workspace.Gravity         = Misc.Vars.OriginalGravity
                Misc.Vars.OriginalGravity = nil
            end

            local char     = LocalPlayer.Character
            local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
            if humanoid then
                humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing,  true)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,   true)
                humanoid:ChangeState(Enum.HumanoidStateType.Swimming)
            end
        end,
    }

    local function hookHumanoidStats(humanoid)
        Misc.Vars.CharStatsCM:Add(
            humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                if not Misc.Vars.CharStatsActive then return end
                local ws     = humanoid.WalkSpeed
                local method = Misc.Vars.StatsMethod
                local wsVal  = Options.WalkSpeedChanger.Value

                local expectedWs
                if method == "Set" then
                    expectedWs = wsVal
                elseif method == "Addition" then
                    expectedWs = (Misc.Vars.OriginalWalkSpeed or ws) + wsVal
                elseif method == "Multiplication" then
                    expectedWs = (Misc.Vars.OriginalWalkSpeed or ws) * wsVal
                end

                if ws == expectedWs then
                    Misc.Vars.OldWalkSpeed = ws
                    return
                end

                Misc.Vars.OriginalWalkSpeed = ws
                Misc.Features.CharStats.Apply()
            end),
            "CharStatsWalkSpeedChanged"
        )

        Misc.Vars.CharStatsCM:Add(
            humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
                if not Misc.Vars.CharStatsActive then return end
                local jp     = humanoid.JumpPower
                local method = Misc.Vars.StatsMethod
                local jpVal  = Options.JumpPowerChanger.Value

                local expectedJp
                if method == "Set" then
                    expectedJp = jpVal
                elseif method == "Addition" then
                    expectedJp = (Misc.Vars.OriginalJumpPower or jp) + jpVal
                elseif method == "Multiplication" then
                    expectedJp = (Misc.Vars.OriginalJumpPower or jp) * jpVal
                end

                if jp == expectedJp then
                    Misc.Vars.OldJumpPower = jp
                    return
                end

                Misc.Vars.OriginalJumpPower = jp
                Misc.Features.CharStats.Apply()
            end),
            "CharStatsJumpPowerChanged"
        )
    end

    Misc.Features.CharStats = {
        Apply = function()
            if not Misc.Vars.CharStatsActive then return end

            local char     = LocalPlayer.Character
            local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
            if not humanoid then return end

            local method = Misc.Vars.StatsMethod
            local wsVal  = Options.WalkSpeedChanger.Value
            local jpVal  = Options.JumpPowerChanger.Value

            if method == "Set" then
                humanoid.WalkSpeed = wsVal
                humanoid.JumpPower = jpVal
            elseif method == "Addition" then
                humanoid.WalkSpeed = (Misc.Vars.OriginalWalkSpeed or 16) + wsVal
                humanoid.JumpPower = (Misc.Vars.OriginalJumpPower or 50) + jpVal
            elseif method == "Multiplication" then
                humanoid.WalkSpeed = (Misc.Vars.OriginalWalkSpeed or 16) * wsVal
                humanoid.JumpPower = (Misc.Vars.OriginalJumpPower or 50) * jpVal
            end

            Misc.Vars.OldWalkSpeed = humanoid.WalkSpeed
            Misc.Vars.OldJumpPower = humanoid.JumpPower
        end,

        Start = function()
            local char     = LocalPlayer.Character
            local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
            if humanoid then
                Misc.Vars.OriginalWalkSpeed = humanoid.WalkSpeed
                Misc.Vars.OriginalJumpPower = humanoid.JumpPower
                hookHumanoidStats(humanoid)
            end

            Misc.Vars.CharStatsActive = true
            Misc.Features.CharStats.Apply()

            Misc.Vars.CharStatsCM:Add(LocalPlayer.CharacterAdded:Connect(function(newChar)
                local newHumanoid = newChar:WaitForChild("Humanoid")
                Misc.Vars.OriginalWalkSpeed = newHumanoid.WalkSpeed
                Misc.Vars.OriginalJumpPower = newHumanoid.JumpPower
                Misc.Vars.CharStatsCM:Remove("CharStatsWalkSpeedChanged")
                Misc.Vars.CharStatsCM:Remove("CharStatsJumpPowerChanged")
                hookHumanoidStats(newHumanoid)
                Misc.Features.CharStats.Apply()
            end), "CharStatsRespawn")
        end,

        Stop = function()
            Misc.Vars.CharStatsActive = false
            Misc.Vars.CharStatsCM:Remove("CharStatsWalkSpeedChanged")
            Misc.Vars.CharStatsCM:Remove("CharStatsJumpPowerChanged")
            Misc.Vars.CharStatsCM:Remove("CharStatsRespawn")

            local char     = LocalPlayer.Character
            local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
            if humanoid then
                if Misc.Vars.OriginalWalkSpeed then
                    humanoid.WalkSpeed = Misc.Vars.OriginalWalkSpeed
                end
                if Misc.Vars.OriginalJumpPower then
                    humanoid.JumpPower = Misc.Vars.OriginalJumpPower
                end
            end

            Misc.Vars.OldWalkSpeed      = 0
            Misc.Vars.OldJumpPower      = 0
            Misc.Vars.OriginalWalkSpeed = nil
            Misc.Vars.OriginalJumpPower = nil
        end,
    }

    Misc.Features.NoFog = {
        Start = function()
            Misc.Vars.OriginalFogEnd = Lighting.FogEnd
            Lighting.FogEnd = math.huge

            Misc.Vars.NoFogCM:Add(
                Lighting:GetPropertyChangedSignal("FogEnd"):Connect(function()
                    if Lighting.FogEnd ~= math.huge then
                        Misc.Vars.OriginalFogEnd = Lighting.FogEnd
                        Lighting.FogEnd = math.huge
                    end
                end),
                "NoFogEnd"
            )

            local function applyNoFog(child)
                if child:IsA("Atmosphere") then
                    if not Misc.Vars.OriginalAtmosphereDensities[child] then
                        Misc.Vars.OriginalAtmosphereDensities[child] = { Density = child.Density }
                    end
                    child.Density = 0
                    Misc.Vars.NoFogCM:Add(
                        child:GetPropertyChangedSignal("Density"):Connect(function()
                            if child.Density ~= 0 then
                                Misc.Vars.OriginalAtmosphereDensities[child].Density = child.Density
                                child.Density = 0
                            end
                        end),
                        "NoFogAtmosphere_" .. tostring(child)
                    )
                end
            end

            for _, child in ipairs(Lighting:GetChildren()) do
                applyNoFog(child)
            end
            Misc.Vars.NoFogCM:Add(Lighting.ChildAdded:Connect(applyNoFog), "NoFogChildAdded")
        end,

        Stop = function()
            Misc.Vars.NoFogCM:Remove("NoFogEnd")
            Misc.Vars.NoFogCM:Remove("NoFogChildAdded")

            if Misc.Vars.OriginalFogEnd ~= nil then
                Lighting.FogEnd          = Misc.Vars.OriginalFogEnd
                Misc.Vars.OriginalFogEnd = nil
            end

            for atmos, data in pairs(Misc.Vars.OriginalAtmosphereDensities) do
                Misc.Vars.NoFogCM:Remove("NoFogAtmosphere_" .. tostring(atmos))
                if typeof(atmos) == "Instance" and atmos.Parent then
                    pcall(function()
                        atmos.Density = data.Density
                    end)
                end
            end
            table.clear(Misc.Vars.OriginalAtmosphereDensities)
        end,
    }

    Misc.Features.NoBlur = {
        Start = function()
            local function applyNoBlur(child)
                if child:IsA("BlurEffect") then
                    Misc.Vars.NoBlurOriginalStates[child] = child.Enabled
                    child.Enabled = false
                end
            end

            for _, child in ipairs(Lighting:GetChildren()) do
                applyNoBlur(child)
            end
            Misc.Vars.NoBlurCM:Add(Lighting.ChildAdded:Connect(applyNoBlur), "NoBlurChildAdded")
        end,

        Stop = function()
            Misc.Vars.NoBlurCM:Remove("NoBlurChildAdded")
            for blur, originalState in pairs(Misc.Vars.NoBlurOriginalStates) do
                if typeof(blur) == "Instance" and blur.Parent then
                    pcall(function()
                        blur.Enabled = originalState
                    end)
                end
            end
            table.clear(Misc.Vars.NoBlurOriginalStates)
        end,
    }

    Misc.Features.NoShadow = {
        Start = function()
            Misc.Vars.OriginalGlobalShadows = Lighting.GlobalShadows
            Lighting.GlobalShadows = false
        end,
        Stop = function()
            if Misc.Vars.OriginalGlobalShadows ~= nil then
                Lighting.GlobalShadows          = Misc.Vars.OriginalGlobalShadows
                Misc.Vars.OriginalGlobalShadows = nil
            end
        end,
    }

    -- ════════════════════ UI Elements ════════════════════

    local MiscGroupClients = Tabs.Misc:AddLeftGroupbox("General", "squares-unite")

    MiscGroupClients:AddToggle("AntiAfk", {
        Text     = "Anti-AFK",
        Default  = false,
        Tooltip  = "Prevents the game from kicking you for being idle.",
        Callback = ToggleFeature(Misc.Features.AntiAfk),
    })

    MiscGroupClients:AddToggle("AntiKick", {
        Text     = "Anti-Kick",
        Default  = false,
        Tooltip  = "Blocks local scripts anti-cheats from kicking you.",
        Callback = ToggleFeature(Misc.Features.AntiKick),
    })

    MiscGroupClients:AddToggle("AutoRejoin", {
        Text     = "Auto Rejoin",
        Default  = false,
        Tooltip  = "Automatically teleports you back into the game if you disconnect.",
        Callback = ToggleFeature(Misc.Features.AutoRejoin),
    })

    MiscGroupClients:AddToggle("AntiLagback", {
        Text     = "Anti-Lagback",
        Default  = false,
        Tooltip  = "Reverts your position on rubberbanding.",
        Callback = ToggleFeature(Misc.Features.AntiLagback),
    })

    MiscGroupClients:AddToggle("InstantInteracts", {
        Text     = "Instant Interact",
        Default  = false,
        Tooltip  = "Removes the hold delay from ProximityPrompts.",
        Callback = ToggleFeature(Misc.Features.InstantPrompt),
    })

    local MiscGroupPlayer = Tabs.Misc:AddLeftGroupbox("Player", "user-round")

    MiscGroupPlayer:AddToggle("Noclip", {
        Text     = "Noclip",
        Default  = false,
        Tooltip  = "Allows you to walk through walls and objects.",
        Callback = ToggleFeature(Misc.Features.Noclip),
    })

    MiscGroupPlayer:AddToggle("InfiniteJump", {
        Text     = "Infinite Jump",
        Default  = false,
        Tooltip  = "Allows you to jump in mid-air infinitely.",
        Callback = ToggleFeature(Misc.Features.InfiniteJump),
    })

    MiscGroupPlayer:AddToggle("AirSwim", {
        Text     = "Air Swim",
        Default  = false,
        Tooltip  = "Allows you to swim through the air. Disables gravity.",
        Callback = ToggleFeature(Misc.Features.AirSwimming),
    })

    local SliderConfigs = {
        Addition = {
            WalkSpeed = { Min = 0,   Max = 500, Default = 0,  Suffix = "+" },
            JumpPower = { Min = -50, Max = 500, Default = 0,  Suffix = "+" },
        },
        Multiplication = {
            WalkSpeed = { Min = 0, Max = 10, Default = 1, Suffix = "×" },
            JumpPower = { Min = 0, Max = 10, Default = 1, Suffix = "×" },
        },
        Set = {
            WalkSpeed = { Min = 0, Max = 500, Default = 16, Suffix = "" },
            JumpPower = { Min = 0, Max = 500, Default = 50, Suffix = "" },
        },
    }

    local WalkSpeedChanger
    local JumpPowerChanger

    MiscGroupPlayer:AddDropdown("CharStatsMulti", {
        Text     = "Character Stats Method",
        Values   = { "Addition", "Multiplication", "Set" },
        Default  = 3,
        Tooltip  = "Determines how WalkSpeed and JumpPower are calculated.",
        Callback = function(v)
            Misc.Vars.StatsMethod = v

            if not (WalkSpeedChanger and JumpPowerChanger) then return end

            local cfg = SliderConfigs[v]

            WalkSpeedChanger:SetMin(cfg.WalkSpeed.Min)
            WalkSpeedChanger:SetMax(cfg.WalkSpeed.Max)
            WalkSpeedChanger:SetValue(cfg.WalkSpeed.Default)
            WalkSpeedChanger:SetSuffix(cfg.WalkSpeed.Suffix)

            JumpPowerChanger:SetMin(cfg.JumpPower.Min)
            JumpPowerChanger:SetMax(cfg.JumpPower.Max)
            JumpPowerChanger:SetValue(cfg.JumpPower.Default)
            JumpPowerChanger:SetSuffix(cfg.JumpPower.Suffix)

            Misc.Features.CharStats.Apply()
        end,
    })

    WalkSpeedChanger = MiscGroupPlayer:AddSlider("WalkSpeedChanger", {
        Text     = "Walk Speed",
        Default  = 16,
        Min      = 0,
        Max      = 100,
        Rounding = 1,
        Suffix   = "",
        Tooltip  = "Sets the player's movement speed.",
        Callback = function() Misc.Features.CharStats.Apply() end,
    })

    JumpPowerChanger = MiscGroupPlayer:AddSlider("JumpPowerChanger", {
        Text     = "Jump Power",
        Default  = 50,
        Min      = 0,
        Max      = 100,
        Rounding = 1,
        Suffix   = "",
        Tooltip  = "Sets the player's jump height.",
        Callback = function() Misc.Features.CharStats.Apply() end,
    })

    MiscGroupPlayer:AddToggle("CharStatsSet", {
        Text     = "Enable Stats Changer",
        Default  = false,
        Tooltip  = "Applies the selected WalkSpeed and JumpPower values.",
        Callback = ToggleFeature(Misc.Features.CharStats),
    })

    local MiscGroupServer = Tabs.Misc:AddRightGroupbox("Server", "hard-drive")

    MiscGroupServer:AddDropdown("ServerHop", {
        Text     = "Server Hop Options",
        Values   = { "Random Server", "Big Server", "Small Server" },
        Default  = 1,
        Tooltip  = "Choose the type of server to join when hopping.",
        Callback = function(v) Misc.Vars.ServerHopTxt = v end,
    })

    MiscGroupServer:AddButton("ServerHop", {
        Text     = "Server Hop",
        Tooltip  = "Leaves the current game and joins a new server.",
        Function = function()
            local mode = Misc.Vars.ServerHopTxt:lower()
            if mode:match("big") then
                ServerHopModule:GetServers({ ping = false, fps = false, asc = false })
            elseif mode:match("small") then
                ServerHopModule:GetServers({ ping = false, fps = false, asc = true })
            elseif mode:match("random") then
                ServerHopModule:GetServers({ ping = true,  fps = true,  asc = true  })
            end
        end,
    })

    local MiscGroupWorld = Tabs.Misc:AddRightGroupbox("World", "earth")

    MiscGroupWorld:AddToggle("NoFog", {
        Text     = "No Fog",
        Default  = false,
        Tooltip  = "Removes all fog from the game map.",
        Callback = ToggleFeature(Misc.Features.NoFog),
    })

    MiscGroupWorld:AddToggle("NoBlur", {
        Text     = "No Blur",
        Default  = false,
        Tooltip  = "Disables all blur effects from Lighting.",
        Callback = ToggleFeature(Misc.Features.NoBlur),
    })

    MiscGroupWorld:AddToggle("NoShadow", {
        Text     = "No Shadow",
        Default  = false,
        Tooltip  = "Turns off global shadows for better visibility.",
        Callback = ToggleFeature(Misc.Features.NoShadow),
    })

end
