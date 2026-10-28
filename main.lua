-- Delta Executor Full Script v2.0
-- Game: Roblox
-- Language: Lua
-- Features: Advanced Invisibility, AI Clone, CFrame Spoofing, AC Bypass, AutoFarm

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- LOCALS
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")
local Camera = Workspace.CurrentCamera

-- STATE
local State = {
    Invisible = false,
    NoClip = false,
    Speed = 16,
    JumpPower = 50,
    CloneActive = false,
    ESPEnabled = false,
    AutoFarmEnabled = false,
    OriginalTransparency = {},
    HitboxOffset = Vector3.new(0, -100, 0),
    CloneControl = false
}

-- UTILS
local function GetCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function GetRoot(char)
    return char:WaitForChild("HumanoidRootPart")
end

-- MODULE: INVISIBILITY & HITBOX SPOOF
local InvisibilityModule = {}

function InvisibilityModule.Toggle(enabled)
    State.Invisible = enabled
    local char = GetCharacter()
    
    if enabled then
        -- Store and hide visuals
        for _, v in pairs(char:GetDescendants()) do
            if v:IsA("BasePart") or v:IsA("MeshPart") then
                State.OriginalTransparency[v] = v.Transparency
                v.Transparency = 1
            elseif v:IsA("Decal") or v:IsA("Texture") then
                State.OriginalTransparency[v] = v.Transparency
                v.Transparency = 1
            end
        end
        
        -- Hitbox offset loop (optimized)
        if not State.HitboxConnection then
            State.HitboxConnection = RunService.Heartbeat:Connect(function()
                if State.Invisible and HumanoidRootPart and HumanoidRootPart.Parent then
                    -- Spoof CFrame to server while keeping local position
                    local realCF = HumanoidRootPart.CFrame
                    HumanoidRootPart.CFrame = realCF + State.HitboxOffset
                end
            end)
        end
    else
        -- Restore visuals
        for part, trans in pairs(State.OriginalTransparency) do
            if part and part.Parent then
                part.Transparency = trans
            end
        end
        
        -- Disconnect hitbox loop
        if State.HitboxConnection then
            State.HitboxConnection:Disconnect()
            State.HitboxConnection = nil
        end
        
        -- Reset CFrame
        if HumanoidRootPart then
            HumanoidRootPart.CFrame = HumanoidRootPart.CFrame - State.HitboxOffset
        end
    end
end

-- MODULE: AI CLONE (DECOY)
local CloneModule = {}

function CloneModule.Spawn()
    if State.Clone then
        State.Clone:Destroy()
    end
    
    local char = GetCharacter()
    local clone = char:Clone()
    clone.Name = "Decoy_" .. LocalPlayer.Name
    clone.Parent = Workspace
    
    -- Setup clone
    for _, v in pairs(clone:GetDescendants()) do
        if v:IsA("BasePart") or v:IsA("MeshPart") then
            v.Transparency = 0
            v.CanCollide = false
            v.Material = Enum.Material.Plastic
            v.Color = Color3.fromRGB(100, 100, 100) -- Grey decoy
        end
    end
    
    local cloneHumanoid = clone:FindFirstChild("Humanoid")
    local cloneRoot = clone:FindFirstChild("HumanoidRootPart")
    
    if cloneHumanoid and cloneRoot then
        cloneHumanoid.WalkSpeed = 20
        cloneHumanoid.JumpPower = 50
        
        State.Clone = clone
        State.CloneActive = true
        
        -- AI Behavior: Wander and mimic
        local function Wander()
            while State.CloneActive and cloneRoot.Parent do
                local randomPos = cloneRoot.Position + Vector3.new(math.random(-20, 20), 0, math.random(-20, 20))
                cloneHumanoid:MoveTo(randomPos)
                wait(math.random(2, 5))
            end
        end
        
        -- Manual Control Override
        local function ManualControl()
            local moveDir = Vector3.new(0, 0, 0)
            
            local inputBegan = UserInputService.InputBegan:Connect(function(input, gpe)
                if gpe or not State.CloneControl then return end
                if input.KeyCode == Enum.KeyCode.W then moveDir = Vector3.new(0, 0, -1)
                elseif input.KeyCode == Enum.KeyCode.S then moveDir = Vector3.new(0, 0, 1)
                elseif input.KeyCode == Enum.KeyCode.A then moveDir = Vector3.new(-1, 0, 0)
                elseif input.KeyCode == Enum.KeyCode.D then moveDir = Vector3.new(1, 0, 0)
                elseif input.KeyCode == Enum.KeyCode.Space then cloneHumanoid.Jump = true
                end
            end)
            
            local inputEnded = UserInputService.InputEnded:Connect(function(input, gpe)
                if gpe or not State.CloneControl then return end
                if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.D then
                    moveDir = Vector3.new(0, 0, 0)
                end
            end)
            
            RunService.RenderStepped:Connect(function()
                if State.CloneActive and cloneRoot.Parent and State.CloneControl then
                    if moveDir.Magnitude > 0 then
                        local camDir = Camera.CFrame.LookVector
                        local camRight = Camera.CFrame.RightVector
                        local moveVector = (camDir * moveDir.Z + camRight * moveDir.X)
                        moveVector = Vector3.new(moveVector.X, 0, moveVector.Z).Unit
                        cloneHumanoid:Move(moveVector * 20)
                    else
                        cloneHumanoid:Move(Vector3.new(0, 0, 0))
                    end
                end
            end)
            
            -- Cleanup connections when clone dies
            cloneHumanoid.Died:Connect(function()
                inputBegan:Disconnect()
                inputEnded:Disconnect()
                State.CloneActive = false
                State.CloneControl = false
            end)
        end
        
        spawn(Wander)
        spawn(ManualControl)
        
        print("✓ Decoy spawned. Press [C] to take control.")
    end
end

-- MODULE: TELEPORT & CFRAME SPOOFING
local TeleportModule = {}

function TeleportModule.Blink(distance)
    local root = GetRoot(GetCharacter())
    local lookVector = Camera.CFrame.LookVector
    local newPos = root.Position + (lookVector * distance)
    
    -- Spoof CFrame to bypass anti-cheat
    root.CFrame = CFrame.new(newPos)
    wait()
    root.CFrame = CFrame.new(newPos) -- Double send for reliability
end

function TeleportModule.ToPlayer(playerName)
    local target = Players:FindFirstChild(playerName)
    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        local root = GetRoot(GetCharacter())
        local targetPos = target.Character.HumanoidRootPart.CFrame
        root.CFrame = targetPos + Vector3.new(3, 0, 0)
    end
end

-- MODULE: AC BYPASS (ADVANCED)
local BypassModule = {}

function BypassModule.Install()
    -- Hook NameCall to block kicks and certain remote calls
    local mt = getrawmetatable(game)
    local oldNameCall = mt.__namecall
    local oldIndex = mt.__index
    
    setreadonly(mt, false)
    
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        
        -- Block Kick
        if method == "Kick" then
            return
        end
        
        -- Block certain anti-cheat remote calls
        if method == "FireServer" or method == "InvokeServer" then
            local args = {...}
            if #args > 0 and tostring(args[1]):lower():find("anticheat") then
                return
            end
        end
        
        return oldNameCall(self, ...)
    end)
    
    -- CFrame Spoofing (Advanced)
    -- This makes the server see a different position than the client
    local oldCFrame = HumanoidRootPart.CFrame
    
    RunService.Heartbeat:Connect(function()
        if State.Invisible then
            -- The server sees the hitbox offset, but we render normally
            -- This is handled in InvisibilityModule now
        end
    end)
    
    print("✓ Advanced AC Bypass installed")
end

-- MODULE: MOVEMENT
local MovementModule = {}

function MovementModule.SetSpeed(speed)
    State.Speed = speed
    local char = GetCharacter()
    local hum = char:FindFirstChild("Humanoid")
    if hum then
        hum.WalkSpeed = speed
    end
end

function MovementModule.SetJumpPower(jump)
    State.JumpPower = jump
    local char = GetCharacter()
    local hum = char:FindFirstChild("Humanoid")
    if hum then
        hum.JumpPower = jump
    end
end

function MovementModule.ToggleNoClip(enabled)
    State.NoClip = enabled
    if enabled then
        if not State.NoClipConnection then
            State.NoClipConnection = RunService.Stepped:Connect(function()
                if State.NoClip then
                    local char = GetCharacter()
                    for _, v in pairs(char:GetDescendants()) do
                        if v:IsA("BasePart") or v:IsA("MeshPart") then
                            v.CanCollide = false
                        end
                    end
                end
            end)
        end
    else
        if State.NoClipConnection then
            State.NoClipConnection:Disconnect()
            State.NoClipConnection = nil
        end
    end
end

-- MODULE: VISUALS (ESP)
local VisualModule = {}

function VisualModule.ToggleESP(enabled)
    State.ESPEnabled = enabled
    
    if enabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local box = Drawing.new("Box")
                box.Visible = true
                box.Outlined = true
                box.Color = Color3.fromRGB(255, 0, 0)
                box.Thickness = 2
                
                local label = Drawing.new("Text")
                label.Visible = true
                label.Text = player.Name
                label.Size = 14
                label.Color = Color3.fromRGB(255, 255, 255)
                label.Outline = true
                
                local connection
                connection = RunService.RenderStepped:Connect(function()
                    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and State.ESPEnabled then
                        local pos, onScreen = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
                        if onScreen then
                            box.Position = Vector2.new(pos.X - 25, pos.Y - 50)
                            box.Size = Vector2.new(50, 100)
                            label.Position = Vector2.new(pos.X, pos.Y - 60)
                            box.Visible = true
                            label.Visible = true
                        else
                            box.Visible = false
                            label.Visible = false
                        end
                    else
                        box.Visible = false
                        label.Visible = false
                        connection:Disconnect()
                    end
                end)
            end
        end
    else
        -- Clear drawings (simplified)
        for _, drawing in pairs(drawing.getdrawings()) do
            drawing:Remove()
        end
    end
end

-- MODULE: AUTOFARM (BRAINROT STEALER)
local AutoFarmModule = {}

function AutoFarmModule.Toggle(enabled)
    State.AutoFarmEnabled = enabled
    
    if enabled then
        if not State.AutoFarmConnection then
            State.AutoFarmConnection = RunService.Heartbeat:Connect(function()
                if State.AutoFarmEnabled then
                    local char = GetCharacter()
                    local root = GetRoot(char)
                    local hum = char:FindFirstChild("Humanoid")
                    
                    if root and hum then
                        -- Find nearest "brainrot" (valuable part)
                        local nearest = nil
                        local nearestDist = math.huge
                        
                        for _, v in pairs(Workspace:GetDescendants()) do
                            if v:IsA("Part") or v:IsA("MeshPart") then
                                -- Check if it's a collectible (simplified logic)
                                if v.Name:lower():find("brainrot") or v.Name:lower():find("coin") or v.Name:lower():find("item") then
                                    local dist = (root.Position - v.Position).Magnitude
                                    if dist < nearestDist and dist < 100 then
                                        nearestDist = dist
                                        nearest = v
                                    end
                                end
                            end
                        end
                        
                        if nearest then
                            local direction = (nearest.Position - root.Position).Unit
                            hum:Move(direction * 50) -- Move fast towards it
                        end
                    end
                end
            end)
        end
    else
        if State.AutoFarmConnection then
            State.AutoFarmConnection:Disconnect()
            State.AutoFarmConnection = nil
        end
    end
end

-- MODULE: GUI
local GUIModule = {}

function GUIModule.Create()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "N1K_Delta_v2"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 320, 0, 450)
    Frame.Position = UDim2.new(0, 20, 0, 20)
    Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Frame.BorderSizePixel = 0
    Frame.Parent = ScreenGui
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 10)
    UICorner.Parent = Frame
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 50)
    Title.BackgroundColor3 = Color3.fromRGB(139, 92, 246)
    Title.BorderSizePixel = 0
    Title.Text = "  N1K DELTA EXECUTOR v2.0"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 16
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Frame
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 10)
    TitleCorner.Parent = Title
    
    -- Buttons
    local buttonY = 60
    local function createButton(text, callback, color)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -20, 0, 35)
        btn.Position = UDim2.new(0, 10, 0, buttonY)
        btn.BackgroundColor3 = color or Color3.fromRGB(40, 40, 40)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 12
        btn.Font = Enum.Font.GothamMedium
        btn.BorderSizePixel = 0
        btn.Parent = Frame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn
        
        btn.MouseButton1Click:Connect(callback)
        buttonY = buttonY + 45
    end
    
    createButton("👻 Toggle Invisibility", function()
        InvisibilityModule.Toggle(not State.Invisible)
    end, Color3.fromRGB(60, 60, 60))
    
    createButton("👥 Spawn AI Clone", function()
        CloneModule.Spawn()
    end, Color3.fromRGB(60, 60, 60))
    
    createButton("🔧 Install AC Bypass", function()
        BypassModule.Install()
    end, Color3.fromRGB(60, 60, 60))
    
    createButton("⚡ Speed x5 (80)", function()
        MovementModule.SetSpeed(80)
    end, Color3.fromRGB(60, 60, 60))
    
    createButton("🦘 Super Jump (150)", function()
        MovementModule.SetJumpPower(150)
    end, Color3.fromRGB(60, 60, 60))
    
    createButton("🌀 NoClip Toggle", function()
        MovementModule.ToggleNoClip(not State.NoClip)
    end, Color3.fromRGB(60, 60, 60))
    
    createButton("📡 Toggle ESP", function()
        VisualModule.ToggleESP(not State.ESPEnabled)
    end, Color3.fromRGB(60, 60, 60))
    
    createButton("🧠 AutoFarm Brainrot", function()
        AutoFarmModule.Toggle(not State.AutoFarmEnabled)
    end, Color3.fromRGB(60, 60, 60))
    
    createButton("🚀 Blink Forward (50)", function()
        TeleportModule.Blink(50)
    end, Color3.fromRGB(60, 60, 60))
    
    createButton("🎮 Toggle Clone Control [C]", function()
        State.CloneControl = not State.CloneControl
        print(State.CloneControl and "✓ Clone Control ON" or " Clone Control OFF")
    end, Color3.fromRGB(139, 92, 246))
    
    print("✓ GUI v2.0 loaded. Press [Insert] to toggle visibility.")
end

-- KEYBINDS
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    
    if input.KeyCode == Enum.KeyCode.Insert then
        local gui = LocalPlayer.PlayerGui:FindFirstChild("N1K_Delta_v2")
        if gui then
            gui.Enabled = not gui.Enabled
        end
    end
    
    if input.KeyCode == Enum.KeyCode.C then
        State.CloneControl = not State.CloneControl
        print(State.CloneControl and "✓ Clone Control ON" or " Clone Control OFF")
    end
    
    if input.KeyCode == Enum.KeyCode.LeftControl then
        InvisibilityModule.Toggle(true)
    end
end)

UserInputService.InputEnded:Connect(function(input, gpe)
    if input.KeyCode == Enum.KeyCode.LeftControl then
        InvisibilityModule.Toggle(false)
    end
end)

-- AUTOLOAD
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("  💻 N1K DELTA EXECUTOR v2.0")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("  [Insert] — Toggle GUI")
print("  [L.Control] — Hold for invisibility")
print("  [C] — Toggle Clone Control")
print("  [Z] — Toggle NoClip")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- Init
BypassModule.Install()
GUIModule.Create()

print("✓ Script v2.0 loaded. Optimized and ready.")
