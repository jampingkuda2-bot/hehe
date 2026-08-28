-- Fish It Weather + Admin Features (Silent)
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Settings
local Settings = {
    WebhookURL = "",
    DiscordEnabled = true,
    AutoFish = false,
    AntiAFK = true,
    NotifyElemental = true,
    Interval = 5,
    -- Admin Settings
    TargetRarity = "Mythic",
    LuckBoost = 1,
    AutoSell = false
}

local lastWeather = ""
local lastElemental = ""
local isMobile = UserInputService.TouchEnabled

-- Discord
local function sendDiscord(title, desc, color)
    if not Settings.DiscordEnabled or Settings.WebhookURL == "" then return end
    pcall(function()
        local payload = HttpService:JSONEncode({
            embeds = {{
                title = title,
                description = desc,
                color = color or 5814783
            }},
            username = "Weather Alert"
        })
        if syn then
            syn.request({Url = Settings.WebhookURL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        else
            request({Url = Settings.WebhookURL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        end
    end)
end

-- Weather Functions
local function getWeather()
    local weather = "Unknown"
    pcall(function()
        local obj = Workspace:FindFirstChild("Weather") or Workspace:FindFirstChild("CurrentWeather") or Workspace:FindFirstChild("ElementalWeather")
        if obj and obj:IsA("StringValue") then
            weather = obj.Value
        end
        local ws = Workspace:FindFirstChild("WeatherSystem")
        if ws then
            local cw = ws:FindFirstChild("CurrentWeather")
            if cw and cw:IsA("StringValue") then
                weather = cw.Value
            end
        end
    end)
    return weather
end

local function checkElemental(weather)
    local w = weather:lower()
    if w:find("fire") or w:find("api") or w:find("flame") then return "fire" end
    if w:find("thunder") or w:find("petir") or w:find("lightning") then return "thunder" end
    if w:find("ice") or w:find("es") or w:find("snow") or w:find("frost") then return "ice" end
    return nil
end

-- Admin Functions (Silent)
local function boostLuck()
    pcall(function()
        -- Coba cari luck value di player
        local luck = Player:FindFirstChild("Luck")
        if luck and luck:IsA("NumberValue") then
            luck.Value = luck.Value + Settings.LuckBoost
        elseif luck and luck:IsA("IntValue") then
            luck.Value = luck.Value + Settings.LuckBoost
        end
        
        -- Coba cari di leaderstats
        local leaderstats = Player:FindFirstChild("leaderstats")
        if leaderstats then
            local luckStat = leaderstats:FindFirstChild("Luck") or leaderstats:FindFirstChild("LuckBoost")
            if luckStat and luckStat:IsA("NumberValue") then
                luckStat.Value = luckStat.Value + Settings.LuckBoost
            elseif luckStat and luckStat:IsA("IntValue") then
                luckStat.Value = luckStat.Value + Settings.LuckBoost
            end
        end
        
        -- Coba remote untuk luck
        local luckRemote = ReplicatedStorage:FindFirstChild("SetLuck") or ReplicatedStorage:FindFirstChild("LuckBoost") or ReplicatedStorage:FindFirstChild("BoostLuck")
        if luckRemote and luckRemote:IsA("RemoteEvent") then
            luckRemote:FireServer(Settings.LuckBoost)
        end
    end)
end

local function setRarity()
    pcall(function()
        -- Coba cari rarity value
        local rarity = Player:FindFirstChild("Rarity") or Player:FindFirstChild("FishRarity")
        if rarity and rarity:IsA("StringValue") then
            rarity.Value = Settings.TargetRarity
        end
        
        -- Coba remote untuk set rarity
        local rarityRemote = ReplicatedStorage:FindFirstChild("SetRarity") or ReplicatedStorage:FindFirstChild("SetFishRarity") or ReplicatedStorage:FindFirstChild("ChangeRarity")
        if rarityRemote and rarityRemote:IsA("RemoteEvent") then
            rarityRemote:FireServer(Settings.TargetRarity)
        end
        
        -- Coba cari inventory system
        local inventory = Player:FindFirstChild("Inventory") or Player:FindFirstChild("FishInventory")
        if inventory then
            for _, fish in pairs(inventory:GetChildren()) do
                if fish:FindFirstChild("Rarity") and fish.Rarity:IsA("StringValue") then
                    fish.Rarity.Value = Settings.TargetRarity
                end
            end
        end
    end)
end

local function autoSell()
    pcall(function()
        local sellRemote = ReplicatedStorage:FindFirstChild("Sell") or ReplicatedStorage:FindFirstChild("SellFish") or ReplicatedStorage:FindFirstChild("SellAll")
        if sellRemote and sellRemote:IsA("RemoteEvent") then
            sellRemote:FireServer()
        end
    end)
end

-- Window
local Window = Fluent:CreateWindow({
    Title = "🎣 Fish It Hub",
    SubTitle = "Weather + Admin",
    TabWidth = 140,
    Size = UDim2.fromOffset(500, 450),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightShift
})

-- Tabs
local Tabs = {
    Main = Window:AddTab({ Title = "🎣 Main", Icon = "fish" }),
    Admin = Window:AddTab({ Title = "⚡ Admin", Icon = "zap" }),
    Weather = Window:AddTab({ Title = "🌋 Weather", Icon = "flame" }),
    Discord = Window:AddTab({ Title = "💬 Discord", Icon = "message-square" }),
    Settings = Window:AddTab({ Title = "⚙️ Settings", Icon = "settings" })
}

-- Main Tab
local MainSection = Tabs.Main:AddSection("Features")

MainSection:AddToggle("AutoFish", {
    Title = "🎣 Auto Fish",
    Description = "Automatically fish",
    Default = false,
    Callback = function(Value)
        Settings.AutoFish = Value
    end
})

MainSection:AddToggle("AntiAFK", {
    Title = "🛡️ Anti-AFK",
    Description = "Prevent AFK kick",
    Default = true,
    Callback = function(Value)
        Settings.AntiAFK = Value
    end
})

local WeatherStatus = MainSection:AddParagraph({
    Title = "🌤️ Weather",
    Value = "Loading..."
})

-- Admin Tab
local AdminSection = Tabs.Admin:AddSection("Rarity Control")

AdminSection:AddDropdown("TargetRarity", {
    Title = "🎯 Target Rarity",
    Description = "Set fish rarity",
    Values = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Exotic", "Secret"},
    Multi = false,
    Default = "Mythic",
    Callback = function(Value)
        Settings.TargetRarity = Value
    end
})

AdminSection:AddButton({
    Title = "⚡ Set Rarity",
    Description = "Apply rarity to fish",
    Callback = function()
        setRarity()
        Fluent:Notify({
            Title = "Rarity Set",
            Content = "Fish rarity set to: " .. Settings.TargetRarity,
            Duration = 3
        })
    end
})

AdminSection:AddSlider("LuckBoost", {
    Title = "🍀 Luck Boost",
    Description = "Increase luck value",
    Default = 1,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(Value)
        Settings.LuckBoost = Value
    end
})

AdminSection:AddButton({
    Title = "🍀 Boost Luck",
    Description = "Apply luck boost",
    Callback = function()
        boostLuck()
        Fluent:Notify({
            Title = "Luck Boosted",
            Content = "Luck increased by: " .. Settings.LuckBoost,
            Duration = 3
        })
    end
})

AdminSection:AddToggle("AutoSell", {
    Title = "💰 Auto Sell",
    Description = "Automatically sell fish",
    Default = false,
    Callback = function(Value)
        Settings.AutoSell = Value
    end
})

-- Weather Tab
local WeatherSection = Tabs.Weather:AddSection("Elemental Monitor")

WeatherSection:AddToggle("NotifyElemental", {
    Title = "🔥 Notify Elemental",
    Description = "Alert when Fire/Thunder/Ice appears",
    Default = true,
    Callback = function(Value)
        Settings.NotifyElemental = Value
    end
})

WeatherSection:AddSlider("Interval", {
    Title = "⏱️ Check Interval",
    Description = "Weather check interval (seconds)",
    Default = 5,
    Min = 1,
    Max = 30,
    Rounding = 0,
    Callback = function(Value)
        Settings.Interval = Value
    end
})

WeatherSection:AddButton({
    Title = "🔄 Check Now",
    Description = "Check current weather",
    Callback = function()
        local weather = getWeather()
        WeatherStatus:SetValue(weather)
        Fluent:Notify({
            Title = "Weather Check",
            Content = "Current: " .. weather,
            Duration = 3
        })
    end
})

-- Discord Tab
local DiscordSection = Tabs.Discord:AddSection("Discord Webhook")

DiscordSection:AddToggle("DiscordEnabled", {
    Title = "🔔 Discord Alerts",
    Description = "Send notifications to Discord",
    Default = true,
    Callback = function(Value)
        Settings.DiscordEnabled = Value
    end
})

DiscordSection:AddInput("WebhookURL", {
    Title = "🔗 Webhook URL",
    Description = "Paste Discord webhook URL",
    Default = "",
    Numeric = false,
    Finished = false,
    Callback = function(Value)
        if Value ~= "" then
            Settings.WebhookURL = Value
            Fluent:Notify({
                Title = "✅ Saved!",
                Content = "Webhook updated",
                Duration = 3
            })
        end
    end
})

DiscordSection:AddButton({
    Title = "📤 Test Webhook",
    Description = "Send test to Discord",
    Callback = function()
        sendDiscord("✅ Test Alert", "Fish It Hub is working!", 65280)
        Fluent:Notify({
            Title = "Test Sent",
            Content = "Check Discord channel",
            Duration = 3
        })
    end
})

-- Save Manager
SaveManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetFolder("FishItHub/")
SaveManager:BuildConfigSection(Tabs.Settings)

InterfaceManager:SetLibrary(Fluent)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)

-- Toggle Icon
local function createToggleIcon()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "FishItToggle"
    ScreenGui.Parent = CoreGui
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local IconButton = Instance.new("TextButton")
    IconButton.Name = "ToggleButton"
    IconButton.Size = UDim2.new(0, isMobile and 45 or 50, 0, isMobile and 45 or 50)
    IconButton.Position = UDim2.new(0, 10, 0.5, 0)
    IconButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    IconButton.BackgroundTransparency = 0.2
    IconButton.BorderSizePixel = 0
    IconButton.Text = "🎣"
    IconButton.TextSize = isMobile and 25 or 30
    IconButton.ZIndex = 10
    IconButton.Parent = ScreenGui
    
    local IconCorner = Instance.new("UICorner")
    IconCorner.CornerRadius = UDim.new(0, 15)
    IconCorner.Parent = IconButton
    
    local IconStroke = Instance.new("UIStroke")
    IconStroke.Color = Color3.fromRGB(255, 100, 100)
    IconStroke.Thickness = 2
    IconStroke.Parent = IconButton
    
    IconButton.MouseButton1Click:Connect(function()
        Window:Toggle()
    end)
    
    -- Draggable
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    IconButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = IconButton.Position
        end
    end)
    
    IconButton.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            IconButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    IconButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

createToggleIcon()

-- Main Loop
task.spawn(function()
    while true do
        pcall(function()
            local weather = getWeather()
            WeatherStatus:SetValue(weather)
            
            local etype = checkElemental(weather)
            
            if etype and etype ~= lastElemental and Settings.NotifyElemental then
                lastElemental = etype
                local emoji = etype == "fire" and "🔥" or etype == "thunder" and "⚡" or "❄️"
                local title = emoji .. " " .. etype:upper() .. " WEATHER DETECTED!"
                local desc = string.format("**Player:** %s\n**Weather:** %s", Player.Name, weather)
                local color = etype == "fire" and 15158332 or etype == "thunder" and 16766720 or 65280
                
                sendDiscord(title, desc, color)
                
                Fluent:Notify({
                    Title = title,
                    Content = "Weather: " .. weather,
                    Duration = 5
                })
            end
            
            lastElemental = etype or ""
            
            if Settings.AutoFish then
                pcall(function()
                    local event = ReplicatedStorage:FindFirstChild("CastLine") or ReplicatedStorage:FindFirstChild("Cast")
                    if event and event:IsA("RemoteEvent") then
                        event:FireServer()
                    end
                end)
            end
            
            if Settings.AutoSell then
                autoSell()
            end
        end)
        
        wait(Settings.Interval)
    end
end)

-- Anti-AFK
if Settings.AntiAFK then
    task.spawn(function()
        while Settings.AntiAFK do
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
                wait(1)
                VirtualUser:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
            end)
            wait(240)
        end
    end)
end
