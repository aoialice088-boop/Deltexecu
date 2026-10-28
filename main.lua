-- Delta Executor Full Script
-- Game: Roblox
-- Language: Lua
-- Features: Invisibility, Clone, Camera Control, Teleport, AC Bypass

-- CONFIG
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- STATE
local OriginalCFrame = HumanoidRootPart.CFrame
local Clone = nil
local CloneCamera = nil
local IsInvisible = false
local OriginalTransparency = {}
local HitboxOffset = 100 -- Distance to move hitbox

-- STORE ORIGINAL TRANSPARENCY
for _, v in pairs(Character:GetDescendants()) do
    if v:IsA("BasePart") then
        OriginalTransparency[v] = v.Transparency
    end
end

-- INVISIBILITY WITH HITBOX OFFSET
local function SetInvisibility(enabled)
    IsInvisible = enabled
    if enabled then
        -- Make character invisible
        for _, v in pairs(Character:GetDescendants()) do
            if v:IsA("BasePart") then
                v.Transparency = 1
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = 1
            end
        end
        
        -- Move hitbox far away (anti-hit)
        RunService.Heartbeat:Connect(function()
            if IsInvisible and HumanoidRootPart then
                local offset = Vector3.new(0, -HitboxOffset, 0)
                HumanoidRootPart.CFrame = Character:FindFirstChild("HumanoidRootPart").CFrame + offset
            end
        end)
    else
        -- Restore visibility
        for part, trans in pairs(OriginalTransparency) do
            if part and part.Parent then
                part.Transparency = trans
            end
        end
    end
end

-- CREATE CLONE WITH CAMERA
local function CreateClone()
    if Clone then
        Clone:Destroy()
    end
    
    Clone = Character:Clone()
    Clone.Name = "Clone_" .. LocalPlayer.Name
    Clone.Parent = workspace
    
    -- Make clone visible
    for _, v in pairs(Clone:GetDescendants()) do
        if v:IsA("BasePart") then
            v.Transparency = 0
            v.CanCollide = false
        end
    end
    
    -- Setup clone humanoid
    local CloneHumanoid = Clone:FindFirstChild("Humanoid")
    local CloneRoot = Clone:FindFirstChild("HumanoidRootPart")
    
    if CloneHumanoid and CloneRoot then
        -- Clone camera setup
        CloneCamera = Instance.new("Camera")
        CloneCamera.CameraType = Enum.CameraType.Custom
        CloneCamera.CameraSubject = CloneHumanoid
        
        -- Clone movement control
        local CloneMove = Vector3.new(0, 0, 0)
        
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            
            if input.KeyCode == Enum.KeyCode.W then
                CloneMove = CloneMove + Vector3.new(0, 0, -1)
            elseif input.KeyCode == Enum.KeyCode.S then
                CloneMove = CloneMove + Vector3.new(0, 0, 1)
            elseif input.KeyCode == Enum.KeyCode.A then
                CloneMove = CloneMove + Vector3.new(-1, 0, 0)
            elseif input.KeyCode == Enum.KeyCode.D then
                CloneMove = CloneMove + Vector3.new(1, 0, 0)
            end
        end)
        
        UserInputService.InputEnded:Connect(function(input, gameProcessed)
            if input.KeyCode == Enum.KeyCode.W then
                CloneMove = CloneMove - Vector3.new(0, 0, -1)
            elseif input.KeyCode == Enum.KeyCode.S then
                CloneMove = CloneMove - Vector3.new(0, 0, 1)
            elseif input.KeyCode == Enum.KeyCode.A then
                CloneMove = CloneMove - Vector3.new(-1, 0, 0)
            elseif input.KeyCode == Enum.KeyCode.D then
                CloneMove = CloneMove - Vector3.new(1, 0, 0)
            end
        end)
        
        -- Clone update loop
        RunService.RenderStepped:Connect(function()
            if Clone and CloneRoot and CloneHumanoid then
                -- Sync position with real player or offset
                local offset = Vector3.new(5, 0, 5)
                CloneRoot.CFrame = HumanoidRootPart.CFrame * CFrame.new(offset)
                
                -- Apply movement
                if CloneMove.Magnitude > 0 then
                    local moveDir = (workspace.CurrentCamera.CFrame * CFrame.new(CloneMove.X * 10, 0, CloneMove.Z * 10)).Position - CloneRoot.Position
                    moveDir = Vector3.new(moveDir.X, 0, moveDir.Z).Unit
                    CloneHumanoid:Move(moveDir * 16)
                end
            end
        end)
        
        print("✓ Clone created with camera control")
        print("  WASD to move clone")
        print("  Clone follows you with offset")
    end
end

-- TELEPORT FUNCTIONS
local function TeleportToPlayer(playerName)
    local target = Players:FindFirstChild(playerName)
    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        local targetPos = target.Character.HumanoidRootPart.CFrame
        HumanoidRootPart.CFrame = targetPos + Vector3.new(3, 0, 0)
        print("✓ Teleported to " .. playerName)
    else
        print(" Player not found: " .. playerName)
    end
end

local function TeleportToPosition(x, y, z)
    HumanoidRootPart.CFrame = CFrame.new(x, y, z)
    print("✓ Teleported to (" .. x .. ", " .. y .. ", " .. z .. ")")
end

local function BLink(distance)
    local lookVector = workspace.CurrentCamera.CFrame.LookVector
    local newPos = HumanoidRootPart.Position + (lookVector * distance)
    HumanoidRootPart.CFrame = CFrame.new(newPos)
end

-- ANTI-CHEAT BYPASS
local function SetupACBypass()
    -- Anti-kick
    local mt = getrawmetatable(game)
    local oldnamecall = mt.__namecall
    setreadonly(mt, false)
    
    mt.__namecall = newcclosure(function(...)
        local args = {...}
        local method = getnamecallmethod()
        
        -- Block kick calls
        if method == "Kick" then
            return
        end
        
        -- Block certain remote events that detect cheating
        if args[1] and tostring(args[1]):lower():find("anticheat") then
            return
        end
        
        return oldnamecall(...)
    end)
    
    -- Remove character physics (anti-detection)
    RunService.Stepped:Connect(function()
        if Character and Humanoid then
            -- Reset fall counter (anti-noclip detection)
            if Humanoid.FloorMaterial == Enum.Material.Air then
                Humanoid.JumpPower = 0
            end
        end
    end)
    
    print("✓ AC bypass hooks installed")
end

-- SPEED & JUMP
local function SetSpeed(speed)
    if Humanoid then
        Humanoid.WalkSpeed = speed
        print("✓ Speed set to " .. speed)
    end
end

local function SetJumpPower(jump)
    if Humanoid then
        Humanoid.JumpPower = jump
        print("✓ Jump power set to " .. jump)
    end
end

-- NOCLIP
local function SetupNoClip()
    local NoClip = false
    
    RunService.Stepped:Connect(function()
        if NoClip and Character then
            for _, v in pairs(Character:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.CanCollide = false
                end
            end
        end
    end)
    
    UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Z then
            NoClip = not NoClip
            print(NoClip and "✓ NoClip ON" or " NoClip OFF")
        end
    end)
end

-- ESP WALLHACK
local function SetupESP()
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
            
            RunService.RenderStepped:Connect(function()
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local pos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
                    if onScreen then
                        box.Position = Vector2.new(pos.X - 25, pos.Y - 50)
                        box.Size = Vector2.new(50, 100)
                        label.Position = Vector2.new(pos.X, pos.Y - 60)
                    else
                        box.Visible = false
                        label.Visible = false
                    end
                end
            end)
        end
    end
end

-- AUTO FARM (Brainrot Stealer)
local function SetupAutoFarm()
    RunService.Heartbeat:Connect(function()
        -- Find nearest valuable/part to "steal"
        local nearest = nil
        local nearestDist = math.huge
        
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("Part") or v:IsA("Model") then
                local dist = (HumanoidRootPart.Position - v.Position).Magnitude
                if dist < nearestDist and dist < 50 then
                    nearestDist = dist
                    nearest = v
                end
            end
        end
        
        if nearest then
            -- Move towards it
            local direction = (nearest.Position - HumanoidRootPart.Position).Unit
            Humanoid:Move(direction * 16)
        end
    end)
    
    print("✓ AutoFarm started — collecting brainrot")
end

-- GUI MENU
local function CreateMenu()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "DeltaMenu"
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 300, 0, 400)
    Frame.Position = UDim2.new(0, 10, 0, 10)
    Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    Frame.BorderSizePixel = 0
    Frame.Parent = ScreenGui
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.BackgroundColor3 = Color3.fromRGB(139, 92, 246)
    Title.BorderSizePixel = 0
    Title.Text = " N1K DELTA EXECUTOR"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 16
    Title.Font = Enum.Font.GothamBold
    Title.Parent = Frame
    
    -- Toggle buttons
    local function createButton(text, y, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -20, 0, 30)
        btn.Position = UDim2.new(0, 10, 0, y)
        btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 12
        btn.BorderSizePixel = 0
        btn.Parent = Frame
        btn.MouseButton1Click:Connect(callback)
    end
    
    createButton("👻 Invisibility", 50, function()
        SetInvisibility(not IsInvisible)
    end)
    
    createButton("👥 Create Clone", 90, function()
        CreateClone()
    end)
    
    createButton("🔧 AC Bypass", 130, function()
        SetupACBypass()
    end)
    
    createButton("⚡ Speed x10", 170, function()
        SetSpeed(160)
    end)
    
    createButton("🦘 Super Jump", 210, function()
        SetJumpPower(100)
    end)
    
    createButton("📡 ESP", 250, function()
        SetupESP()
    end)
    
    createButton("🧠 AutoFarm Brainrot", 290, function()
        SetupAutoFarm()
    end)
    
    createButton("🌀 Teleport Forward", 330, function()
        BLink(50)
    end)
    
    print("✓ GUI Menu loaded — Press Insert to toggle")
end

-- KEYBINDS
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.Insert then
        -- Toggle menu visibility
        local menu = LocalPlayer.PlayerGui:FindFirstChild("DeltaMenu")
        if menu then
            menu:Destroy()
        else
            CreateMenu()
        end
    end
    
    if input.KeyCode == Enum.KeyCode.LeftControl then
        SetInvisibility(true)
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.LeftControl then
        SetInvisibility(false)
    end
end)

-- AUTOLOAD
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("  💻 N1K DELTA EXECUTOR")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("  [Insert] — Toggle Menu")
print("  [L.Control] — Hold for invisibility")
print("  [Z] — Toggle NoClip")
print("  [WASD] — Move clone (when active)")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- Start features
SetInvisibility(false)
SetupNoClip()
CreateMenu()

print("✓ Script loaded. Have fun breaking things.")
