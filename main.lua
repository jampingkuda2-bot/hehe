-- Fish It Hub - With UI
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Window = Fluent:CreateWindow({
    Title = "Fish It Hub",
    SubTitle = "Weather Detector",
    TabWidth = 160,
    Size = UDim2.fromOffset(500, 400),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightShift
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "fish" }),
    Weather = Window:AddTab({ Title = "Weather", Icon = "cloud" }),
    Discord = Window:AddTab({ Title = "Discord", Icon = "message-square" })
}

local Settings = {
    Webhook = "",
    DiscordEnabled = true,
    AutoFish = false,
    AntiAFK = true,
    NotifyElemental = true
}

local lastElemental = ""

-- Discord
local function sendDiscord(msg)
    if not Settings.DiscordEnabled or Settings.Webhook == "" then return end
    pcall(function()
        local payload = HttpService:JSONEncode({content = msg})
        if syn then
            syn.request({Url = Settings.Webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        else
            request({Url = Settings.Webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
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
    end)
    return weather
end

local function checkElemental(weather)
    local w = weather:lower()
    if w:find("fire") or w:find("api") then return "fire" end
    if w:find("thunder") or w:find("petir") or w:find("lightning") then return "thunder" end
    if w:find("ice") or w:find("es") or w:find("snow") then return "ice" end
    return nil
end

-- Main Tab
Tabs.Main:AddSection("Features")

Tabs.Main:AddToggle("AutoFish", {
    Title = "Auto Fish",
    Default = false,
    Callback = function(v) Settings.AutoFish = v end
})

Tabs.Main:AddToggle("AntiAFK", {
    Title = "Anti-AFK",
    Default = true,
    Callback = function(v) Settings.AntiAFK = v end
})

Tabs.Main:AddParagraph({
    Title = "Current Weather",
    Value = "Loading..."
})

-- Weather Tab
Tabs.Weather:AddSection("Elemental Monitor")

Tabs.Weather:AddToggle("NotifyElemental", {
    Title = "Notify Elemental Weather",
    Default = true,
    Callback = function(v) Settings.NotifyElemental = v end
})

-- Discord Tab
Tabs.Discord:AddSection("Webhook")

Tabs.Discord:AddToggle("DiscordEnabled", {
    Title = "Discord Notifications",
    Default = true,
    Callback = function(v) Settings.DiscordEnabled = v end
})

Tabs.Discord:AddInput("Webhook", {
    Title = "Webhook URL",
    Default = "",
    Numeric = false,
    Finished = false,
    Callback = function(v)
        if v ~= "" then Settings.Webhook = v end
    end
})

-- Main Loop
task.spawn(function()
    while true do
        pcall(function()
            local weather = getWeather()
            local etype = checkElemental(weather)
            
            if etype and etype ~= lastElemental and Settings.NotifyElemental then
                lastElemental = etype
                local emoji = etype == "fire" and "🔥" or etype == "thunder" and "⚡" or "❄️"
                local msg = emoji .. " " .. etype:upper() .. " Weather!"
                sendDiscord(msg)
                Fluent:Notify({
                    Title = msg,
                    Content = weather,
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
                wait(math.random(8, 15) / 10)
            end
        end)
        wait(5)
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

-- Notify loaded
Fluent:Notify({
    Title = "Fish It Hub",
    Content = "Script loaded successfully!",
    Duration = 5
})
