-- Main Script
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Settings
local WebhookURL = ""
local DiscordEnabled = true
local AutoFish = false
local AntiAFK = true
local NotifyElemental = true
local Interval = 5
local lastWeather = ""
local lastElemental = ""

-- Discord
local function sendDiscord(title, desc, color)
    if not DiscordEnabled or WebhookURL == "" then return end
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
            syn.request({Url = WebhookURL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        else
            request({Url = WebhookURL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        end
    end)
end

-- Weather
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

-- Window
local Window = Fluent:CreateWindow({
    Title = "Fish It Weather Detector",
    SubTitle = "Elemental Weather Alert",
    TabWidth = 160,
    Size = UDim2.fromOffset(500, 400),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightShift
})

-- Tabs
local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "fish" }),
    Weather = Window:AddTab({ Title = "Weather", Icon = "cloud" }),
    Discord = Window:AddTab({ Title = "Discord", Icon = "message-square" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- Main Tab
local MainSection = Tabs.Main:AddSection("Features")

MainSection:AddToggle("AutoFish", {
    Title = "Auto Fish",
    Description = "Automatically fish",
    Default = false,
    Callback = function(Value)
        AutoFish = Value
    end
})

MainSection:AddToggle("AntiAFK", {
    Title = "Anti-AFK",
    Description = "Prevent AFK kick",
    Default = true,
    Callback = function(Value)
        AntiAFK = Value
    end
})

local WeatherStatus = MainSection:AddParagraph({
    Title = "Current Weather",
    Value = "Loading..."
})

-- Weather Tab
local WeatherSection = Tabs.Weather:AddSection("Elemental Monitor")

WeatherSection:AddToggle("NotifyElemental", {
    Title = "Notify Elemental Weather",
    Description = "Alert when Fire/Thunder/Ice weather appears",
    Default = true,
    Callback = function(Value)
        NotifyElemental = Value
    end
})

WeatherSection:AddSlider("Interval", {
    Title = "Check Interval",
    Description = "How often to check weather (seconds)",
    Default = 5,
    Min = 1,
    Max = 30,
    Rounding = 0,
    Callback = function(Value)
        Interval = Value
    end
})

WeatherSection:AddButton({
    Title = "Check Weather Now",
    Description = "Check current weather",
    Callback = function()
        local weather = getWeather()
        WeatherStatus:SetValue(weather)
        Fluent:Notify({
            Title = "Weather Check",
            Content = "Current weather: " .. weather,
            Duration = 3
        })
    end
})

-- Discord Tab
local DiscordSection = Tabs.Discord:AddSection("Discord Webhook")

DiscordSection:AddToggle("DiscordEnabled", {
    Title = "Discord Notifications",
    Description = "Send alerts to Discord",
    Default = true,
    Callback = function(Value)
        DiscordEnabled = Value
    end
})

DiscordSection:AddInput("WebhookURL", {
    Title = "Webhook URL",
    Description = "Paste your Discord webhook URL",
    Default = "",
    Numeric = false,
    Finished = false,
    Callback = function(Value)
        if Value ~= "" then
            WebhookURL = Value
            Fluent:Notify({
                Title = "Webhook Saved",
                Content = "Discord webhook updated",
                Duration = 3
            })
        end
    end
})

DiscordSection:AddButton({
    Title = "Test Webhook",
    Description = "Send test message to Discord",
    Callback = function()
        sendDiscord("Test Alert", "Weather Detector is working!", 65280)
        Fluent:Notify({
            Title = "Test Sent",
            Content = "Check your Discord channel",
            Duration = 3
        })
    end
})

-- Save Manager
SaveManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetFolder("FishItWeather/")
SaveManager:BuildConfigSection(Tabs.Settings)

InterfaceManager:SetLibrary(Fluent)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)

-- Main Loop
task.spawn(function()
    while true do
        pcall(function()
            local weather = getWeather()
            WeatherStatus:SetValue(weather)
            
            local etype = checkElemental(weather)
            
            if etype and etype ~= lastElemental and NotifyElemental then
                lastElemental = etype
                local emoji = etype == "fire" and "🔥" or etype == "thunder" and "⚡" or "❄️"
                local title = emoji .. " " .. etype:upper() .. " WEATHER DETECTED!"
                local desc = string.format("**Player:** %s\n**Weather:** %s\n**Element:** %s", Player.Name, weather, etype:upper())
                local color = etype == "fire" and 15158332 or etype == "thunder" and 16766720 or 65280
                
                sendDiscord(title, desc, color)
                
                Fluent:Notify({
                    Title = title,
                    Content = "Weather: " .. weather,
                    Duration = 5
                })
            end
            
            lastElemental = etype or ""
            
            if AutoFish then
                pcall(function()
                    local event = ReplicatedStorage:FindFirstChild("CastLine") or ReplicatedStorage:FindFirstChild("Cast")
                    if event and event:IsA("RemoteEvent") then
                        event:FireServer()
                    end
                end)
            end
        end)
        
        wait(Interval)
    end
end)

-- Anti-AFK
if AntiAFK then
    task.spawn(function()
        while AntiAFK do
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
                wait(1)
                VirtualUser:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
            end)
            wait(240)
        end
    end)
end
