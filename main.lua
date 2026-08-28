-- Fish It Hub - Real Admin
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Window = Fluent:CreateWindow({
    Title = "Fish It Hub",
    SubTitle = "Real Admin Features",
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
    -- Admin
    TargetRarity = "Mythic",
    LuckAmount = 10000,
    MultiFish = 4,
    AutoSell = false,
    AutoRarity = false,
    AutoLuck = false
}

local lastElemental = ""

-- Discord
local function sendDiscord(title, desc, color)
    if not Settings.DiscordEnabled or Settings.Webhook == "" then return end
    pcall(function()
        local payload = HttpService:JSONEncode({
            embeds = {{
                title = title,
                description = desc,
                color = color or 5814783
            }}
        })
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

-- Real Admin Functions (Fire Remote Events)
local function getAllRemotes()
    local remotes = {}
    pcall(function()
        for _, v in pairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                table.insert(remotes, v)
            end
        end
    end)
    return remotes
end

local function fireRemote(remoteName, ...)
    pcall(function()
        local remote = ReplicatedStorage:FindFirstChild(remoteName)
        if remote and remote:IsA("RemoteEvent") then
            remote:FireServer(...)
        elseif remote and remote:IsA("RemoteFunction") then
            remote:InvokeServer(...)
        end
    end)
end

local function setRarityReal()
    pcall(function()
        -- Coba berbagai remote untuk set rarity
        fireRemote("SetRarity", Settings.TargetRarity)
        fireRemote("SetFishRarity", Settings.TargetRarity)
        fireRemote("ChangeRarity", Settings.TargetRarity)
        fireRemote("UpdateRarity", Settings.TargetRarity)
        fireRemote("SetFish", Settings.TargetRarity)
        
        -- Coba cari remote yang berkaitan dengan rarity
        for _, remote in pairs(getAllRemotes()) do
            if remote.Name:lower():find("rarity") then
                if remote:IsA("RemoteEvent") then
                    remote:FireServer(Settings.TargetRarity)
                elseif remote:IsA("RemoteFunction") then
                    remote:InvokeServer(Settings.TargetRarity)
                end
            end
        end
        
        -- Set langsung ke player data
        local rarity = Player:FindFirstChild("Rarity") or Player:FindFirstChild("FishRarity")
        if rarity and rarity:IsA("StringValue") then
            rarity.Value = Settings.TargetRarity
        end
        
        Fluent:Notify({
            Title = "✅ Rarity Set",
            Content = "Set to: " .. Settings.TargetRarity,
            Duration = 3
        })
    end)
end

local function setLuckReal()
    pcall(function()
        -- Coba berbagai remote untuk set luck
        fireRemote("SetLuck", Settings.LuckAmount)
        fireRemote("UpdateLuck", Settings.LuckAmount)
        fireRemote("LuckBoost", Settings.LuckAmount)
        fireRemote("AddLuck", Settings.LuckAmount)
        fireRemote("SetLuckBoost", Settings.LuckAmount)
        
        -- Coba cari remote yang berkaitan dengan luck
        for _, remote in pairs(getAllRemotes()) do
            if remote.Name:lower():find("luck") then
                if remote:IsA("RemoteEvent") then
                    remote:FireServer(Settings.LuckAmount)
                elseif remote:IsA("RemoteFunction") then
                    remote:InvokeServer(Settings.LuckAmount)
                end
            end
        end
        
        -- Set langsung
        local luck = Player:FindFirstChild("Luck")
        if luck and luck:IsA("NumberValue") then
            luck.Value = Settings.LuckAmount
        elseif luck and luck:IsA("IntValue") then
            luck.Value = Settings.LuckAmount
        end
        
        local leaderstats = Player:FindFirstChild("leaderstats")
        if leaderstats then
            local luckStat = leaderstats:FindFirstChild("Luck")
            if luckStat and luckStat:IsA("NumberValue") then
                luckStat.Value = Settings.LuckAmount
            elseif luckStat and luckStat:IsA("IntValue") then
                luckStat.Value = Settings.LuckAmount
            end
        end
        
        Fluent:Notify({
            Title = "🍀 Luck Set",
            Content = "Luck: " .. Settings.LuckAmount,
            Duration = 3
        })
    end)
end

local function setMultiFish()
    pcall(function()
        -- Coba remote untuk multi fish
        fireRemote("SetMultiFish", Settings.MultiFish)
        fireRemote("MultiFish", Settings.MultiFish)
        fireRemote("SetFishAmount", Settings.MultiFish)
        fireRemote("FishMultiplier", Settings.MultiFish)
        
        -- Coba cari remote untuk multi
        for _, remote in pairs(getAllRemotes()) do
            if remote.Name:lower():find("multi") or remote.Name:lower():find("amount") or remote.Name:lower():find("count") then
                if remote:IsA("RemoteEvent") then
                    remote:FireServer(Settings.MultiFish)
                elseif remote:IsA("RemoteFunction") then
                    remote:InvokeServer(Settings.MultiFish)
                end
            end
        end
        
        Fluent:Notify({
            Title = "🐟 Multi Fish",
            Content = "Fish per cast: " .. Settings.MultiFish,
            Duration = 3
        })
    end)
end

local function sellFish()
    pcall(function()
        fireRemote("Sell", true)
        fireRemote("SellFish", true)
        fireRemote("SellAll", true)
        
        for _, remote in pairs(getAllRemotes()) do
            if remote.Name:lower():find("sell") then
                if remote:IsA("RemoteEvent") then
                    remote:FireServer(true)
                elseif remote:IsA("RemoteFunction") then
                    remote:InvokeServer(true)
                end
            end
        end
    end)
end

local function autoFish()
    pcall(function()
        fireRemote("CastLine")
        fireRemote("Cast")
        fireRemote("Fish")
        fireRemote("StartFishing")
        
        for _, remote in pairs(getAllRemotes()) do
            if remote.Name:lower():find("cast") or remote.Name:lower():find("fish") then
                if remote:IsA("RemoteEvent") then
                    remote:FireServer()
                elseif remote:IsA("RemoteFunction") then
                    remote:InvokeServer()
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
    Callback = setRarityReal
})

Tabs.Admin:AddToggle("AutoRarity", {
    Title = "Auto Set Rarity",
    Default = false,
    Callback = function(v) Settings.AutoRarity = v end
})

Tabs.Admin:AddSection("Luck Control")

Tabs.Admin:AddInput("LuckAmount", {
    Title = "Luck Amount",
    Default = "10000",
    Numeric = true,
    Finished = true,
    Callback = function(v)
        Settings.LuckAmount = tonumber(v) or 10000
    end
})

Tabs.Admin:AddButton({
    Title = "Set Luck",
    Callback = setLuckReal
})

Tabs.Admin:AddToggle("AutoLuck", {
    Title = "Auto Set Luck",
    Default = false,
    Callback = function(v) Settings.AutoLuck = v end
})

Tabs.Admin:AddSection("Multi Fish")

Tabs.Admin:AddInput("MultiFish", {
    Title = "Fish Per Cast",
    Default = "4",
    Numeric = true,
    Finished = true,
    Callback = function(v)
        Settings.MultiFish = tonumber(v) or 4
    end
})

Tabs.Admin:AddButton({
    Title = "Set Multi Fish",
    Callback = setMultiFish
})

Tabs.Admin:AddToggle("AutoSell", {
    Title = "Auto Sell",
    Default = false,
    Callback = function(v) Settings.AutoSell = v end
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
                sendDiscord(emoji .. " " .. etype:upper() .. " Weather!", "**Player:** " .. Player.Name .. "\n**Weather:** " .. weather, etype == "fire" and 15158332 or etype == "thunder" and 16766720 or 65280)
                Fluent:Notify({
                    Title = emoji .. " " .. etype:upper() .. " Weather!",
                    Content = weather,
                    Duration = 5
                })
            end
            
            lastElemental = etype or ""
            
            if Settings.AutoFish then
                autoFish()
            end
            
            if Settings.AutoRarity then
                setRarityReal()
            end
            
            if Settings.AutoLuck then
                setLuckReal()
            end
            
            if Settings.AutoSell then
                sellFish()
            end
        end)
        wait(2)
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
