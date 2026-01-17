-- neighborhaxx
-- made by keta (discord.gg/ZUPzAGNKRZ)

local hashes = {
    "0c33e376905be24a86140c55782474420e64a2944922f4f0dcc7225ea39e11f7b1121bf2dc5847ac927419b90d94760d",
    "5b6e537b4fa1c24aba36f4f102974c0e3d95ff2ab84fd0dcf81cd74828667f98f2d8b05dea863dc25f961e3c00c44016",
    "75ce7ed91b7bc7602330eb7c7cba3cd3636e5250a8b103cb3ed4cddbb6636d81b52acee2419eb5e07d49eac71531afb5"
}

local allowed_call = "ClientCheck"

--// Bypass
for _, hash in pairs(hashes) do
    local retrieved = filtergc("function", {Hash = hash, IgnoreExecutor = true})
    local target_func = retrieved[1]

    if target_func then
        local old_func
        old_func = hookfunction(target_func, function(...)
            local args = { ... }
            if args[1] == allowed_call then
                return old_func(table.unpack(args))
            end
            return true
        end)
    end
end

--// Services
local players = game:GetService("Players")
local user_input_service = game:GetService("UserInputService")
local run_service = game:GetService("RunService")
local workspace = game:GetService("Workspace")

--// Libraries
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()
local esp_library = loadstring(game:HttpGet("https://raw.githubusercontent.com/ketachka/Roblox/refs/heads/main/universal/esp.lua"))()

--// Constants
local local_player = players.LocalPlayer
local camera = workspace.CurrentCamera

--// Configuration Defaults
local config = {
    silent_aim_enabled = false,
    show_fov = false,
    show_snaplines = false,
    visibility_check = false,
    fov_radius = 60,
    target_part = "Head"
}

--// ESP Defaults
local esp_config = esp_library.config
esp_config.enabled = false
esp_config.max_distance = 2000
esp_config.team_check = false
esp_config.team_color = false
esp_config.box = false
esp_config.skeleton = false
esp_config.name = false
esp_config.distance = false
esp_config.healthbar = false

--// UI Initialization
local window = Fluent:CreateWindow({
    Title = "neighborhaxx",
    SubTitle = "| made by keta",
    TabWidth = 200,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl,
})

local tabs = {
    main = window:AddTab({ Title = "Main", Icon = "crosshair" }),
    visuals = window:AddTab({ Title = "Visuals", Icon = "eye" }),
    player = window:AddTab({ Title = "Player", Icon = "user" }),
    settings = window:AddTab({ Title = "Settings", Icon = "settings" })
}

local options = Fluent.Options

--// Drawing Objects
local fov_circle = Drawing.new("Circle")
fov_circle.Thickness = 2
fov_circle.NumSides = 60
fov_circle.Filled = false
fov_circle.Transparency = 1
fov_circle.Color = Color3.fromRGB(255, 255, 255)

local snapline = Drawing.new("Line")
snapline.Thickness = 1.5
snapline.Transparency = 1
snapline.Color = Color3.fromRGB(255, 0, 0)

--// Reusable Raycast Params (Performance Optimization)
local vis_params = RaycastParams.new()
vis_params.FilterType = Enum.RaycastFilterType.Exclude

--- HELPER FUNCTIONS ---

local function is_visible(target_part)
    if not config.visibility_check then return true end
    
    local origin = camera.CFrame.Position
    local direction = target_part.Position - origin
    
    vis_params.FilterDescendantsInstances = {local_player.Character, target_part.Parent}
    local result = workspace:Raycast(origin, direction, vis_params)
    
    return result == nil
end

local function get_closest_target()
    if not config.silent_aim_enabled then return nil end
    
    local target = nil
    local shortest_distance = tonumber(config.fov_radius)
    local mouse_pos = user_input_service:GetMouseLocation()

    for _, player in pairs(players:GetPlayers()) do
        if player ~= local_player and player.Character then
            local char = player.Character
            local part = char:FindFirstChild(config.target_part) or char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChild("Humanoid")
            
            if part and hum and hum.Health > 0 then
                local screen_pos, on_screen = camera:WorldToViewportPoint(part.Position)
                if on_screen then
                    local mag = (Vector2.new(screen_pos.X, screen_pos.Y) - mouse_pos).Magnitude
                    if mag < shortest_distance and is_visible(part) then
                        target = char
                        shortest_distance = mag
                    end
                end
            end
        end
    end
    return target
end

--- UI SECTION: COMBAT ---

local combat_section = tabs.main:AddSection("Combat")

tabs.main:AddToggle("SilentAimEnabled", {Title = "Enable Silent Aim", Default = false }):OnChanged(function() 
    config.silent_aim_enabled = options.SilentAimEnabled.Value 
end)

tabs.main:AddToggle("VisCheck", {Title = "Enable Visibility Check", Default = false }):OnChanged(function() 
    config.visibility_check = options.VisCheck.Value 
end)

tabs.main:AddDropdown("TargetPart", {
    Title = "Target Part",
    Values = {"Head", "Torso", "HumanoidRootPart"},
    Multi = false,
    Default = 1,
}):OnChanged(function(val) config.target_part = val end)

tabs.main:AddSlider("FOVRadius", {
    Title = "FOV Radius",
    Default = 150,
    Min = 10,
    Max = 1000,
    Rounding = 1,
}):OnChanged(function(val) config.fov_radius = val end)

--- UI SECTION: VISUALS ---

local esp_section = tabs.visuals:AddSection("ESP Settings")

tabs.visuals:AddToggle("ESPEnabled", {Title = "Master ESP Switch", Default = false }):OnChanged(function(val) 
    esp_config.enabled = val 
end)

tabs.visuals:AddToggle("ESPBox", {Title = "Box ESP", Default = false }):OnChanged(function(val) 
    esp_config.box = val 
end)

tabs.visuals:AddColorpicker("ESPBoxColor", { Title = "Box Color", Default = Color3.fromRGB(0, 255, 255) }):OnChanged(function() 
    esp_config.box_color = options.ESPBoxColor.Value 
end)

tabs.visuals:AddToggle("ESPSkeleton", {Title = "Skeleton ESP", Default = false }):OnChanged(function(val) 
    esp_config.skeleton = val 
end)

tabs.visuals:AddColorpicker("ESPSkelColor", { Title = "Skeleton Color", Default = Color3.fromRGB(255, 255, 255) }):OnChanged(function() 
    esp_config.skeleton_color = options.ESPSkelColor.Value 
end)

tabs.visuals:AddToggle("ESPName", {Title = "Name ESP", Default = false }):OnChanged(function(val) 
    esp_config.name = val 
end)

tabs.visuals:AddColorpicker("ESPNameColor", { Title = "Name Color", Default = Color3.fromRGB(255, 255, 255) }):OnChanged(function() 
    esp_config.name_color = options.ESPNameColor.Value 
end)

tabs.visuals:AddToggle("ESPDist", {Title = "Distance ESP", Default = false }):OnChanged(function(val) 
    esp_config.distance = val 
end)

tabs.visuals:AddToggle("ESPHealth", {Title = "Healthbar", Default = false }):OnChanged(function(val) 
    esp_config.healthbar = val 
end)

local local_visuals = tabs.visuals:AddSection("Local Visuals")

tabs.visuals:AddToggle("ShowFOV", {Title = "Draw FOV Circle", Default = false }):OnChanged(function() 
    config.show_fov = options.ShowFOV.Value 
end)

tabs.visuals:AddColorpicker("FOVColor", { Title = "FOV Color", Default = Color3.fromRGB(255, 255, 255) }):OnChanged(function() 
    fov_circle.Color = options.FOVColor.Value 
end)

tabs.visuals:AddToggle("ShowSnaplines", {Title = "Draw Snaplines", Default = false }):OnChanged(function() 
    config.show_snaplines = options.ShowSnaplines.Value 
end)

tabs.visuals:AddColorpicker("SnaplineColor", { Title = "Snapline Color", Default = Color3.fromRGB(255, 0, 0) }):OnChanged(function() 
    snapline.Color = options.SnaplineColor.Value 
end)

--- UI SECTION: PLAYER ---

local player_attribs = tabs.player:AddSection("Attributes")

tabs.player:AddToggle("EnableWS", {Title = "Enable WalkSpeed", Default = false })
tabs.player:AddSlider("WalkSpeedVal", { Title = "WalkSpeed", Default = 16, Min = 16, Max = 200, Rounding = 1 })

tabs.player:AddToggle("EnableJP", {Title = "Enable JumpPower", Default = false })
tabs.player:AddSlider("JumpPowerVal", { Title = "JumpPower", Default = 50, Min = 50, Max = 300, Rounding = 1 })

tabs.player:AddToggle("EnableGrav", {Title = "Enable Gravity", Default = false })
tabs.player:AddSlider("GravityVal", { Title = "Gravity", Default = 196.2, Min = 0, Max = 200, Rounding = 1 })

--- MAIN LOOPS ---

run_service.RenderStepped:Connect(function()
    local mouse_loc = user_input_service:GetMouseLocation()
    
    --// FOV Update
    fov_circle.Visible = config.show_fov
    fov_circle.Radius = config.fov_radius
    fov_circle.Position = mouse_loc

    --// Snaplines
    local snap_visible = false
    if config.show_snaplines and config.silent_aim_enabled then
        local target = get_closest_target()
        if target then
            local part = target:FindFirstChild(config.target_part) or target:FindFirstChild("HumanoidRootPart")
            if part then
                local screen_pos, on_screen = camera:WorldToViewportPoint(part.Position)
                if on_screen then
                    snapline.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
                    snapline.To = Vector2.new(screen_pos.X, screen_pos.Y)
                    snap_visible = true
                end
            end
        end
    end
    snapline.Visible = snap_visible

    --// Character Modifications
    local char = local_player.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            if options.EnableWS.Value then hum.WalkSpeed = options.WalkSpeedVal.Value end
            if options.EnableJP.Value then
                hum.UseJumpPower = true
                hum.JumpPower = options.JumpPowerVal.Value
            end
        end
    end
    
    if options.EnableGrav.Value then 
        workspace.Gravity = options.GravityVal.Value 
    end
end)

--- HOOKS ---

local gc_retrieved = filtergc("table", { Keys = {"GetMouseLocationData"}, IgnoreExecutor = true })
if gc_retrieved and gc_retrieved[1] then
    local old_get_mouse_data
    old_get_mouse_data = hookfunction(gc_retrieved[1].GetMouseLocationData, function(params, nx, ny)
        if config.silent_aim_enabled then
            local target = get_closest_target()
            if target then
                local root = target:FindFirstChild(config.target_part) or target:FindFirstChild("HumanoidRootPart")
                if root then
                    local vel = root.AssemblyLinearVelocity
                    local pos = root.Position
                    local dist = (pos - camera.CFrame.Position).Magnitude
                    local prediction = vel * (dist / 2500)
                    return pos + prediction
                end
            end
        end
        return old_get_mouse_data(params, nx, ny)
    end)
end

--// Managers
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("neighborhaxx")
SaveManager:BuildConfigSection(tabs.settings)
InterfaceManager:BuildInterfaceSection(tabs.settings)

window:SelectTab(1)

Fluent:Notify({
    Title = "neighborhaxx",
    Content = "Join discord.gg/ZUPzAGNKRZ for updates =D",
    Duration = 5
})