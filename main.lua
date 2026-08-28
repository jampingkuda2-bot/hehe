-- Fish It Utility Module - Safe Execution
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")

local Config = {
    WebhookURL = "",
    DiscordEnabled = true,
    WeatherNotify = true,
    AutoFish = false,
    AntiAFK = true,
    MinDelay = 0.8,
    MaxDelay = 1.5,
    WeatherCheckInterval = 5,
}

local function randomizedDelay()
    local delayTime = Config.MinDelay + (math.random() * (Config.MaxDelay - Config.MinDelay))
    task.wait(delayTime)
end

local function safeFireRemote(remoteName, ...)
    local success = pcall(function()
        local remote = ReplicatedStorage:FindFirstChild(remoteName)
        if remote and remote:IsA("RemoteEvent") then
            remote:FireServer(...)
        end
    end)
    return success
end

local function sendDiscord(message)
    if not Config.DiscordEnabled or Config.WebhookURL == "" then return end
    pcall(function()
        local payload = HttpService:JSONEncode({
            content = message,
            username = "Fish It Utility"
        })
        if syn then
            syn.request({
                Url = Config.WebhookURL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = payload
            })
        else
            request({
                Url = Config.WebhookURL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = payload
            })
        end
    end)
end

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

local WeatherListener = {}
WeatherListener.lastElemental = ""

function WeatherListener.Start()
    task.spawn(function()
        while true do
            pcall(function()
                local weather = getWeather()
                local etype = checkElemental(weather)

                if etype and etype ~= WeatherListener.lastElemental and Config.WeatherNotify then
                    WeatherListener.lastElemental = etype
                    local emoji = etype == "fire" and "🔥" or etype == "thunder" and "⚡" or "❄️"
                    local msg = emoji .. " " .. etype:upper() .. " Weather Detected!"
                    sendDiscord(msg .. "\nWeather: " .. weather)
                end

                WeatherListener.lastElemental = etype or ""
            end)
            task.wait(Config.WeatherCheckInterval)
        end
    end)
end

local FishingLogic = {}

function FishingLogic.Start()
    task.spawn(function()
        while true do
            if Config.AutoFish then
                pcall(function()
                    safeFireRemote("CastLine")
                    randomizedDelay()
                    safeFireRemote("Fish")
                    randomizedDelay()
                end)
            end
            randomizedDelay()
        end
    end)
end

local AntiAFK = {}

function AntiAFK.Start()
    if not Config.AntiAFK then return end

    task.spawn(function()
        while true do
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
                task.wait(0.5)
                VirtualUser:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
            end)
            task.wait(240)
        end
    end)
end

local function Init()
    WeatherListener.Start()
    FishingLogic.Start()
    AntiAFK.Start()
end

Init()
