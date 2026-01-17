-- made by keta
-- documentation: https://docs.sunc.su/

-- note: use at own risk! (some features can be easily patched)
if getgenv().config then return getgenv().config end

-- bypasses (only for aimbot to work)
local result = filtergc("table", {
    keys = { "indexInstance", "namecallInstance" }
}, true)

setreadonly(result, false) 

for key, value in pairs(result) do
    result[key] = table.freeze({"kick", function() return false end})
end

setreadonly(result, true)

-- services
local players                = game:GetService("Players")
local run_service            = game:GetService("RunService")
local stats                  = game:GetService("Stats")
local user_input_service     = game:GetService("UserInputService")
local workspace_camera       = workspace.CurrentCamera

-- localization
local local_player                = players.LocalPlayer
local get_players                 = players.GetPlayers
local find_first_ancestor_of_class = game.FindFirstAncestorOfClass
local find_first_child_of_class    = game.FindFirstChildOfClass
local find_first_child             = game.FindFirstChild
local world_to_viewport_point      = workspace_camera.WorldToViewportPoint
local get_mouse_pos                = user_input_service.GetMouseLocation

-- constants
-- note: some constants were derived randomly, expect bugs with prediction xD
local gravity         = 196.2
local muzzle_velocity = 1000
local bullet_drop     = 0.25

-- configuration
local config = {
    default_accent = Color3.fromRGB(0, 255, 255), -- main accent color
    snaplines      = true,
    fov_radius     = 150
}

-- visuals
local fov_circle           = Drawing.new("Circle")
fov_circle.Thickness       = 1
fov_circle.Color           = config.default_accent
fov_circle.Transparency    = 1
fov_circle.Visible         = true
fov_circle.Radius          = config.fov_radius

local snapline             = Drawing.new("Line")
snapline.Thickness         = 1
snapline.Color             = config.default_accent
snapline.Transparency      = 0.8
snapline.Visible           = false

-- helpers
local function get_closest_target()
    local nearest_target    = nil
    local shortest_distance = config.fov_radius
    local mouse_pos         = get_mouse_pos(user_input_service)

    for _, player in pairs(get_players(players)) do
        if player ~= local_player and player.Character then
            local head = find_first_child(player.Character, "Head")
            local hum  = find_first_child_of_class(player.Character, "Humanoid")
            
            if head and hum and hum.Health > 0 then
                local screen_pos, on_screen = world_to_viewport_point(workspace_camera, head.Position)
                
                if on_screen then
                    local player_pos = Vector2.new(screen_pos.X, screen_pos.Y)
                    local dist       = (mouse_pos - player_pos).Magnitude
                    
                    if dist < shortest_distance then
                        nearest_target   = head
                        shortest_distance = dist
                    end
                end
            end
        end
    end
    return nearest_target
end

local function solve_trajectory(target, origin, velocity, drop_scale)
    local root          = find_first_child(target.Parent, "HumanoidRootPart") or target
    local distance      = (target.Position - origin).Magnitude
    local time          = distance / velocity
    
    local target_vel    = root.Velocity
    local predicted_pos = target.Position + (target_vel * time)
    
    local drop_comp     = 0.5 * (gravity * drop_scale) * (time ^ 2)
    local final_pos     = predicted_pos + Vector3.new(0, drop_comp, 0)
    
    return (final_pos - origin).Unit * 1000
end

-- main hook
local old_namecall
old_namecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args   = {...}
    local caller = getcallingscript()

    if not checkcaller() and method == "Raycast" and (self == workspace) and caller.Name == "ACS_Framework" then
        local target = get_closest_target()
        
        -- silent aim
        if target then
            local origin    = args[1]
            local direction = solve_trajectory(target, origin, muzzle_velocity, bullet_drop)
            args[2]         = direction
        end

        -- wallbang
        local result = old_namecall(self, table.unpack(args))

        if result and result.Instance then
            local instance        = result.Instance
            local character_model = find_first_ancestor_of_class(instance, "Model")
            local is_player       = character_model and find_first_child_of_class(character_model, "Humanoid")
            
            if not is_player then
                return nil
            end

            return result
        end
    end
    
    return old_namecall(self, unpack(args))
end))

-- connections
run_service.RenderStepped:Connect(function()
    local mouse_pos = get_mouse_pos(user_input_service)
    
    -- sync FOV circle
    fov_circle.Position     = mouse_pos
    fov_circle.Radius       = config.fov_radius
    fov_circle.Color        = config.default_accent

    -- sync snapline
    snapline.Color          = config.default_accent
    
    local target = get_closest_target()
    if target and config.snaplines then
        local screen_pos, on_screen = workspace_camera:WorldToViewportPoint(target.Position)
        if on_screen then
            snapline.From    = mouse_pos
            snapline.To      = Vector2.new(screen_pos.X, screen_pos.Y)
            snapline.Visible = true
        else
            snapline.Visible = false
        end
    else
        snapline.Visible = false
    end
end)

getgenv().config = config

return config