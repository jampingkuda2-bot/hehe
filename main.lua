-- Fish It Hub - Fixed
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Window = Fluent:CreateWindow({
    Title = "Fish It Hub",
    SubTitle = "Weather + Admin",
    TabWidth = 160,
    Size = UDim2.fromOffset(550, 500),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightShift
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "fish" }),
    Admin = Window:AddTab({ Title = "Admin", Icon = "zap" }),
    Weather = Window:AddTab({ Title = "Weather", Icon = "cloud" }),
    Discord = Window:AddTab({ Title = "Discord", Icon = "message-square" })
}

local Settings = {
    Webhook = "",
    DiscordEnabled = true,
    AutoFish = false,
    AntiAFK = true,
    NotifyElemental = true,
    TargetRarity = "Mythic",
    LuckAmount = 10000,
    MultiFish = 4
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
    if w:find("fire") or w:find("api") or w:find("flame") then return "fire" end
    if w:find("thunder") or w:find("petir") or w:find("lightning") then return "thunder" end
    if w:find("ice") or w:find("es") or w:find("snow") or w:find("frost") then return "ice" end
    return nil
end

-- Fire Remotes
local function fireRemotes(keyword, value)
    pcall(function()
        for _, v in pairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("RemoteEvent") and v.Name:lower():find(keyword) then
                if value ~= nil then
                    v:FireServer(value)
                else
                    v:FireServer()
                end
            end
        end
    end)
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

-- Admin Tab
Tabs.Admin:AddSection("Rarity Control")

Tabs.Admin:AddDropdown("TargetRarity", {
    Title = "Target Rarity",
    Values = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Exotic", "Secret"},
    Multi = false,
    Default = "Mythic",
    Callback = function(v) Settings.TargetRarity = v end
})

Tabs.Admin:AddButton({
    Title = "Set Rarity",
    Description = "Apply rarity to fish",
    Callback = function()
        fireRemotes("rarity", Settings.TargetRarity)
        Fluent:Notify({
            Title = "✅ Rarity Set",
            Content = Settings.TargetRarity,
            Duration = 3
        })
    end
})

Tabs.Admin:AddSection("Luck Control")

Tabs.Admin:AddInput("LuckAmount", {
    Title = "Luck Amount",
    Description = "Set luck value",
    Default = "10000",
    Numeric = true,
    Finished = true,
    Callback = function(v)
        Settings.LuckAmount = tonumber(v) or 10000
    end
})

Tabs.Admin:AddButton({
    Title = "Set Luck",
    Description = "Apply luck boost",
    Callback = function()
        fireRemotes("luck", Settings.LuckAmount)
        Fluent:Notify({
            Title = "🍀 Luck Set",
            Content = tostring(Settings.LuckAmount),
            Duration = 3
        })
    end
})

Tabs.Admin:AddSection("Multi Fish")

Tabs.Admin:AddInput("MultiFish", {
    Title = "Fish Per Cast",
    Description = "How many fish per cast",
    Default = "4",
    Numeric = true,
    Finished = true,
    Callback = function(v)
        Settings.MultiFish = tonumber(v) or 4
    end
})

Tabs.Admin:AddButton({
    Title = "Set Multi Fish",
    Description = "Set fish amount per cast",
    Callback = function()
        fireRemotes("multi", Settings.MultiFish)
        fireRemotes("amount", Settings.MultiFish)
        Fluent:Notify({
            Title = "🐟 Multi Fish",
            Content = tostring(Settings.MultiFish) .. " fish/cast",
            Duration = 3
        })
    end
})

-- Weather Tab
Tabs.Weather:AddSection("Elemental Monitor")

Tabs.Weather:AddToggle("NotifyElemental", {
    Title = "Notify Elemental Weather",
    Description = "Alert when Fire/Thunder/Ice appears",
    Default = true,
    Callback = function(v) Settings.NotifyElemental = v end
})

-- Discord Tab
Tabs.Discord:AddSection("Webhook")

Tabs.Discord:AddToggle("DiscordEnabled", {
    Title = "Discord Notifications",
    Description = "Send alerts to Discord",
    Default = true,
    Callback = function(v) Settings.DiscordEnabled = v end
})

Tabs.Discord:AddInput("Webhook", {
    Title = "Webhook URL",
    Description = "Paste Discord webhook",
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
                sendDiscord(msg .. "\nWeather: " .. weather)
                Fluent:Notify({
                    Title = msg,
                    Content = weather,
                    Duration = 5
                })
            end
            
            lastElemental = etype or ""
            
            if Settings.AutoFish then
                fireRemotes("cast", nil)
                fireRemotes("fish", nil)
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

-- Loaded notification
Fluent:Notify({
    Title = "Fish It Hub",
    Content = "Script loaded successfully!",
    Duration = 5
})
