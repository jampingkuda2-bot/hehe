-- Fish It Hub
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")

local Window = Fluent:CreateWindow({
    Title = "Fish It Hub",
    SubTitle = "v1.0",
    TabWidth = 160,
    Size = UDim2.fromOffset(550, 550),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightShift
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "fish" }),
    Weather = Window:AddTab({ Title = "Weather", Icon = "cloud" }),
    Discord = Window:AddTab({ Title = "Discord", Icon = "message-square" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- Settings
getgenv().Webhook = ""
getgenv().DiscordEnabled = true
getgenv().AutoFish = false
getgenv().AutoSell = false
getgenv().AutoEquip = false
getgenv().AntiAFK = true
getgenv().NotifyElemental = true
getgenv().NotifyNormal = false
getgenv().CheckInterval = 5
getgenv().lastWeather = ""
getgenv().lastElemental = ""

-- Discord Function
local function sendDiscord(title, desc, color)
    if not getgenv().DiscordEnabled or getgenv().Webhook == "" then return end
    pcall(function()
        local payload = HttpService:JSONEncode({
            embeds = {{
                title = title,
                description = desc,
                color = color or 5814783,
                footer = {text = "Fish It Hub • " .. os.date("%H:%M:%S")}
            }}
        })
        if syn then
            syn.request({Url = getgenv().Webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        else
            request({Url = getgenv().Webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        end
    end)
end

-- Weather Function
local function getWeather()
    local weather = "Unknown"
    pcall(function()
        local obj = Workspace:FindFirstChild("Weather") or Workspace:FindFirstChild("CurrentWeather") or Workspace:FindFirstChild("ElementalWeather") or Workspace:FindFirstChild("IslandWeather")
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
    if w:find("fire") or w:find("api") or w:find("flame") or w:find("burn") or w:find("lava") then return "fire" end
    if w:find("thunder") or w:find("petir") or w:find("lightning") or w:find("electric") or w:find("storm") then return "thunder" end
    if w:find("ice") or w:find("es") or w:find("snow") or w:find("frost") or w:find("freeze") or w:find("cold") then return "ice" end
    return nil
end

-- Main Tab
Tabs.Main:AddSection("Fishing")

Tabs.Main:AddToggle("AutoFish", {
    Title = "Auto Fish",
    Default = false,
    Callback = function(v) getgenv().AutoFish = v end
})

Tabs.Main:AddToggle("AutoSell", {
    Title = "Auto Sell",
    Default = false,
    Callback = function(v) getgenv().AutoSell = v end
})

Tabs.Main:AddToggle("AutoEquip", {
    Title = "Auto Equip Best Rod",
    Default = false,
    Callback = function(v) getgenv().AutoEquip = v end
})

Tabs.Main:AddParagraph({
    Title = "Current Weather",
    Value = "Loading..."
})

-- Weather Tab
Tabs.Weather:AddSection("Elemental Monitor")

Tabs.Weather:AddToggle("NotifyElemental", {
    Title = "Notify Elemental Weather",
    Description = "Alert saat cuaca Fire/Thunder/Ice muncul",
    Default = true,
    Callback = function(v) getgenv().NotifyElemental = v end
})

Tabs.Weather:AddToggle("NotifyNormal", {
    Title = "Notify Normal Weather",
    Description = "Juga notifikasi cuaca normal",
    Default = false,
    Callback = function(v) getgenv().NotifyNormal = v end
})

Tabs.Weather:AddSlider("CheckInterval", {
    Title = "Check Interval",
    Description = "Interval cek cuaca (detik)",
    Default = 5,
    Min = 1,
    Max = 30,
    Rounding = 0,
    Callback = function(v) getgenv().CheckInterval = v end
})

Tabs.Weather:AddButton({
    Title = "Check Weather Now",
    Callback = function()
        local weather = getWeather()
        Fluent:Notify({
            Title = "Weather",
            Content = weather,
            Duration = 3
        })
    end
})

-- Discord Tab
Tabs.Discord:AddSection("Webhook Settings")

Tabs.Discord:AddToggle("DiscordEnabled", {
    Title = "Discord Notifications",
    Default = true,
    Callback = function(v) getgenv().DiscordEnabled = v end
})

Tabs.Discord:AddInput("Webhook", {
    Title = "Webhook URL",
    Default = "",
    Numeric = false,
    Finished = false,
    Callback = function(v)
        if v ~= "" then
            getgenv().Webhook = v
            Fluent:Notify({
                Title = "Webhook Saved",
                Content = "Discord webhook updated",
                Duration = 3
            })
        end
    end
})

Tabs.Discord:AddButton({
    Title = "Test Webhook",
    Callback = function()
        sendDiscord("✅ Test Alert", "Fish It Hub is working!\n**Player:** " .. Player.Name, 65280)
        Fluent:Notify({
            Title = "Test Sent",
            Content = "Check Discord",
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

-- Auto Fish Loop
task.spawn(function()
    while true do
        pcall(function()
            if getgenv().AutoFish then
                local event = ReplicatedStorage:FindFirstChild("CastLine") or ReplicatedStorage:FindFirstChild("Cast") or ReplicatedStorage:FindFirstChild("Fish")
                if event and event:IsA("RemoteEvent") then
                    event:FireServer()
                end
            end
            
            if getgenv().AutoSell then
                local sell = ReplicatedStorage:FindFirstChild("Sell") or ReplicatedStorage:FindFirstChild("SellFish")
                if sell and sell:IsA("RemoteEvent") then
                    sell:FireServer()
                end
            end
            
            if getgenv().AutoEquip then
                pcall(function()
                    local bestRod = nil
                    local bestPower = 0
                    for _, item in pairs(Player.Backpack:GetChildren()) do
                        if item:IsA("Tool") and item.Name:lower():find("rod") then
                            local power = item:GetAttribute("Power") or 0
                            if power > bestPower then
                                bestPower = power
                                bestRod = item
                            end
                        end
                    end
                    if bestRod then
                        Player.Character.Humanoid:EquipTool(bestRod)
                    end
                end)
            end
        end)
        wait(2)
    end
end)

-- Weather Monitor Loop
task.spawn(function()
    while true do
        pcall(function()
            local weather = getWeather()
            local etype = checkElemental(weather)
            
            if etype then
                if etype ~= getgenv().lastElemental and getgenv().NotifyElemental then
                    getgenv().lastElemental = etype
                    local emoji = etype == "fire" and "🔥" or etype == "thunder" and "⚡" or "❄️"
                    local title = emoji .. " " .. etype:upper() .. " WEATHER DETECTED!"
                    local desc = string.format("**Player:** %s\n**Weather:** %s\n**Element:** %s\n**Location:** Elemental Island", Player.Name, weather, etype:upper())
                    local color = etype == "fire" and 15158332 or etype == "thunder" and 16766720 or 65280
                    
                    sendDiscord(title, desc, color)
                    
                    Fluent:Notify({
                        Title = title,
                        Content = weather,
                        Duration = 5
                    })
                end
            else
                getgenv().lastElemental = ""
                
                if getgenv().NotifyNormal and weather ~= getgenv().lastWeather then
                    sendDiscord("🌤️ Weather Changed", "**Weather:** " .. weather, 5814783)
                end
            end
            
            getgenv().lastWeather = weather
        end)
        wait(getgenv().CheckInterval or 5)
    end
end)

-- Anti AFK
task.spawn(function()
    while true do
        pcall(function()
            if getgenv().AntiAFK then
                VirtualUser:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
                wait(1)
                VirtualUser:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
            end
        end)
        wait(180)
    end
end)
