-- made by keta
-- documentation: https://docs.sunc.su/Drawing/
local library = {}

library.config = {
    enabled = true,
    team_check = false,
    team_color = true,
    box = true,
    box_color = Color3.fromRGB(255, 255, 255),
    box_outline = true,
    box_outline_color = Color3.fromRGB(0, 0, 0),
    name = true,
    name_color = Color3.fromRGB(255, 255, 255),
    healthbar = true,
    distance = true,
    distance_color = Color3.fromRGB(255, 255, 255),
    skeleton = true,
    skeleton_color = Color3.fromRGB(255, 255, 255),
    font = 2,
    text_size = 13,
    max_distance = 2500
}

local players = game:GetService("Players")
local run_service = game:GetService("RunService")
local camera = workspace.CurrentCamera
local local_player = players.LocalPlayer
local world_to_viewport_point = camera.WorldToViewportPoint

local pool = {}
pool.cache = {
    Square = {},
    Text = {},
    Line = {}
}

function pool.get(type_name)
    local cache = pool.cache[type_name]
    if #cache > 0 then
        local obj = table.remove(cache)
        obj.Visible = true
        return obj
    end
    return Drawing.new(type_name)
end

function pool.release(obj, type_name)
    obj.Visible = false
    table.insert(pool.cache[type_name], obj)
end

-- constants
local R15_LINKS = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"}, {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"}, {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}, {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"}, {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"}
}

local R6_LINKS = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"}
}

-- esp constructor
local esp_object = {}
esp_object.__index = esp_object

function esp_object.new(player)
    local self = setmetatable({}, esp_object)
    self.player = player
    self.char = nil
    self.root = nil
    self.humanoid = nil
    self.rig_type = "R6"
    
    self.drawings = {
        box = pool.get("Square"),
        box_outline = pool.get("Square"),
        name = pool.get("Text"),
        distance = pool.get("Text"),
        health_bar = pool.get("Square"),
        health_outline = pool.get("Square"),
        skeleton = {} 
    }

    self.drawings.box.Filled = false
    self.drawings.box.Thickness = 1
    self.drawings.box.ZIndex = 2
    
    self.drawings.box_outline.Filled = false
    self.drawings.box_outline.Thickness = 3
    self.drawings.box_outline.ZIndex = 1
    
    self.drawings.health_outline.Filled = true
    self.drawings.health_outline.ZIndex = 1
    self.drawings.health_outline.Color = Color3.new(0,0,0)
    
    self.drawings.health_bar.Filled = true
    self.drawings.health_bar.ZIndex = 2
    
    self.drawings.name.Center = true
    self.drawings.name.Outline = true
    self.drawings.name.ZIndex = 3
    
    self.drawings.distance.Center = true
    self.drawings.distance.Outline = true
    self.drawings.distance.ZIndex = 3

    self:cache_character()
    return self
end

function esp_object:cache_character()
    local char = self.player.Character
    if not char then return end
    
    self.char = char
    self.root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    self.humanoid = char:FindFirstChild("Humanoid")
    self.rig_type = char:FindFirstChild("UpperTorso") and "R15" or "R6" -- hacky way to get rig type
    
    if self.rig_type == "R15" then
        self:resize_skeleton_pool(#R15_LINKS)
    else
        self:resize_skeleton_pool(#R6_LINKS)
    end
end

function esp_object:resize_skeleton_pool(count)
    local current = #self.drawings.skeleton
    if current < count then
        for i = 1, count - current do
            local line = pool.get("Line")
            line.Thickness = 1
            table.insert(self.drawings.skeleton, line)
        end
    elseif current > count then
        for i = current, count + 1, -1 do
            pool.release(table.remove(self.drawings.skeleton), "Line")
        end
    end
end

function esp_object:destruct()
    pool.release(self.drawings.box, "Square")
    pool.release(self.drawings.box_outline, "Square")
    pool.release(self.drawings.name, "Text")
    pool.release(self.drawings.distance, "Text")
    pool.release(self.drawings.health_bar, "Square")
    pool.release(self.drawings.health_outline, "Square")
    
    for _, line in ipairs(self.drawings.skeleton) do
        pool.release(line, "Line")
    end
    self.drawings.skeleton = {}
end

function esp_object:set_visible(state)
    self.drawings.box.Visible = state and library.config.box
    self.drawings.box_outline.Visible = state and library.config.box and library.config.box_outline
    self.drawings.name.Visible = state and library.config.name
    self.drawings.distance.Visible = state and library.config.distance
    self.drawings.health_bar.Visible = state and library.config.healthbar
    self.drawings.health_outline.Visible = state and library.config.healthbar
    
    local skel_vis = state and library.config.skeleton
    for _, line in ipairs(self.drawings.skeleton) do
        line.Visible = skel_vis
    end
end

function esp_object:update()
    if not self.char or not self.root or not self.humanoid or self.humanoid.Health <= 0 then
        self:set_visible(false)
        return
    end

    local pos, on_screen = world_to_viewport_point(camera, self.root.Position)
    if not on_screen then
        self:set_visible(false)
        return
    end

    local dist = (camera.CFrame.Position - self.root.Position).Magnitude
    if dist > library.config.max_distance then
        self:set_visible(false)
        return
    end
    
    local scale = 1000 / pos.Z
    local width, height = 2 * scale, 3 * scale
    local x, y = pos.X - width / 2, pos.Y - height / 2
    
    local render_color = library.config.team_color and self.player.TeamColor.Color or library.config.box_color
    local skel_color = library.config.team_color and self.player.TeamColor.Color or library.config.skeleton_color

    self:set_visible(true)

    if library.config.box then
        self.drawings.box.Size = Vector2.new(width, height)
        self.drawings.box.Position = Vector2.new(x, y)
        self.drawings.box.Color = render_color
        
        if library.config.box_outline then
            self.drawings.box_outline.Size = Vector2.new(width, height)
            self.drawings.box_outline.Position = Vector2.new(x, y)
            self.drawings.box_outline.Color = library.config.box_outline_color
        end
    end

    if library.config.name then
        self.drawings.name.Text = self.player.DisplayName
        self.drawings.name.Position = Vector2.new(pos.X, y - 16)
        self.drawings.name.Color = library.config.name_color
        self.drawings.name.Font = library.config.font
        self.drawings.name.Size = library.config.text_size
    end

    if library.config.healthbar then
        local health_pct = self.humanoid.Health / self.humanoid.MaxHealth
        local bar_h = height * health_pct
        
        self.drawings.health_outline.Size = Vector2.new(4, height + 2)
        self.drawings.health_outline.Position = Vector2.new(x - 6, y - 1)
        
        self.drawings.health_bar.Size = Vector2.new(2, bar_h)
        self.drawings.health_bar.Position = Vector2.new(x - 5, y + height - bar_h)
        self.drawings.health_bar.Color = Color3.fromHSV(health_pct * 0.3, 1, 1)
    end

    if library.config.distance then
        self.drawings.distance.Text = string.format("[%d]", dist)
        self.drawings.distance.Position = Vector2.new(pos.X, y + height + 2)
        self.drawings.distance.Color = library.config.distance_color
        self.drawings.distance.Font = library.config.font
        self.drawings.distance.Size = library.config.text_size
    end

    if library.config.skeleton then
        local links = self.rig_type == "R15" and R15_LINKS or R6_LINKS
        for i, link in ipairs(links) do
            local p1 = self.char:FindFirstChild(link[1])
            local p2 = self.char:FindFirstChild(link[2])
            local line = self.drawings.skeleton[i]
            
            if p1 and p2 and line then
                local v1, os1 = world_to_viewport_point(camera, p1.Position)
                local v2, os2 = world_to_viewport_point(camera, p2.Position)
                
                if os1 and os2 then
                    line.From = Vector2.new(v1.X, v1.Y)
                    line.To = Vector2.new(v2.X, v2.Y)
                    line.Color = skel_color
                    line.Visible = true
                else
                    line.Visible = false
                end
            elseif line then
                line.Visible = false
            end
        end
    end
end

-- esp manager
local manager = {
    entities = {}
}

function manager.add_player(player)
    if manager.entities[player] then return end
    manager.entities[player] = esp_object.new(player)
    
    player.CharacterAdded:Connect(function()
        task.wait(0.1)
        if manager.entities[player] then
            manager.entities[player]:cache_character()
        end
    end)

    player:GetPropertyChangedSignal("Team"):Connect(function()
        if manager.entities[player] then
            manager.entities[player]:update()
        end
    end)
end

function manager.remove_player(player)
    if manager.entities[player] then
        manager.entities[player]:destruct()
        manager.entities[player] = nil
    end
end

-- connections
for _, p in ipairs(players:GetPlayers()) do
    if p ~= local_player then manager.add_player(p) end
end

players.PlayerAdded:Connect(function(p)
    if p ~= local_player then manager.add_player(p) end
end)

players.PlayerRemoving:Connect(manager.remove_player)

run_service:BindToRenderStep("esp_update", Enum.RenderPriority.Camera.Value + 1, function()
    if not library.config.enabled then 
        for _, obj in pairs(manager.entities) do obj:set_visible(false) end
        return 
    end

    for player, obj in pairs(manager.entities) do
        if library.config.team_check and player.Team == local_player.Team then
            obj:set_visible(false)
        else
            obj:update()
        end
    end
end)

return library